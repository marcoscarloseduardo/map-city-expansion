
# 1.LOAD LIBRARIES
#--------------------------
libs <- c(
  "tidyverse", "sf", "osmdata", "tmaptools",
  "stringi", "terra", "httr", "XML"
)

# install missing libraries
installed_libs <- libs %in% rownames(installed.packages())
if (any(installed_libs == F)) {
  install.packages(libs[!installed_libs])
}

invisible(lapply(libs, library, character.only = T))


# 2. GET BUILT-UP DATA FOR CITY
#-------------------------------------------------------
# city to find out. "City, District, Provincia, Country"
city_obj <- "Coronel Suarez, Partido de Coronel Suarez, Provincia de Buenos Aires, Argentina" # Objetive city. "City, District, Provincia, Country"
city_title <- strsplit(city_obj, ",")[[1]]
city_title <- paste(city_title[1], city_title[length(city_title)], sep = ",")

radius <- 6 # Kms are of interest around the city

geo_coded <- geocode_OSM(stri_trans_general(city_obj, "Latin-ASCII"))

lon_obj <- geo_coded$coords[1]
lat_obj <- geo_coded$coords[2]

# Convert lat and lon values into a tif file identifier string
convert_coordinates <- function(lat, lon) {
  
  # Determine if the latitude is North or South
  lat_dir <- ifelse(lat >= 0, "N", "S")
  
  # determine if the longitude is East or West
  lon_dir <- ifelse(lon >= 0, "E", "W")
  
  # convert latitude and longitude to integer multiples of 10
  lat_int <- floor(abs(lat) / 10) * 10
  lon_int <- ceiling(abs(lon) / 10) * 10
  lon_int <- sprintf("%03d", lon_int)
  
  # Create the final string
  result <- paste(lat_int, lat_dir, "_", lon_int, lon_dir, sep = "")
  
  return(result)
}

coord_string <- convert_coordinates(lat_obj, lon_obj)

crsLONGLAT <- "+proj=longlat +datum=WGS84 +no_defs +ellps=WGS84 +towgs84=0,0,0"

l <- paste0("https://glad.umd.edu/users/Potapov/GLCLUC2020/Built-up_change_2000_2020/Change_",coord_string,".tif")

builtup_data <- terra::rast(l)
terra::crs(builtup_data) <- crsLONGLAT


# 3. GET CITY BOUNDARIES FROM OSM DATA
#--------------------------------------
# define longlat projection
city_border <- osmdata::getbb(
  city_obj,
  format_out = "sf_polygon"
) |>
  sf::st_set_crs(crsLONGLAT) |>
  sf::st_transform(crsLONGLAT)


#city_border <- st_geometry(city_border$polygon) # useful when the sf object has multipolygons
#  sf::st_set_crs(crsLONGLAT) |>
#  sf::st_transform(crsLONGLAT)

#city_border <- city_border[-1, ]  # useful when the sf object has 2 polygons
#city_border <- city_border[2]     # useful to choose the 2nd polygon

plot(city_border)

#terra::plot(builtup_data)
#plot(city_border, add = T)


# 4. CROP CITY RASTER
# 4.a. METHOD 1: POLYGON
#-------------------
crop_builtup_data_with_polygon <- function() {
  city_vect <- terra::vect(city_border)
  city_raster <- terra::crop(builtup_data, city_vect)
  city_raster_cropped <- terra::mask(
    city_raster, city_vect
  )
  return(city_raster_cropped)
}

city_raster_cropped <- crop_builtup_data_with_polygon()
terra::plot(city_raster_cropped)

# 4.b. METHOD 2: BOUNDING BOX
#-----------------------
bbox <- sf::st_bbox(city_border)
bbox_poly <- sf::st_sfc(
  sf::st_polygon(list(cbind(
    c(
      bbox["xmin"], bbox["xmax"],
      bbox["xmax"], bbox["xmin"], bbox["xmin"]
    ),
    c(
      bbox["ymin"], bbox["ymin"],
      bbox["ymax"], bbox["ymax"], bbox["ymin"]
    )
  ))),
  crs = crsLONGLAT
)

crop_builtup_data_with_bbox <- function() {
  city_vect <- terra::vect(bbox_poly)
  city_raster <- terra::crop(builtup_data, city_vect)
  city_raster_cropped <- terra::mask(
    city_raster, city_vect
  )
  return(city_raster_cropped)
}

city_raster_cropped <- crop_builtup_data_with_bbox()
terra::plot(city_raster_cropped)

# 4.c. MAKE BUFFER AROUND CITY
# METHOD 3: BUFFER
#----------------------------
get_buffer <- function() {
  city_cents <- sf::st_centroid(city_border)
  city_circle <- sf::st_buffer(
    city_cents,
    dist = units::set_units(radius, km)
  ) |>
    sf::st_set_crs(crsLONGLAT) |>
    sf::st_transform(crs = crsLONGLAT)
  
  return(city_circle)
}

city_circle <- get_buffer()

# plot
ggplot() +
  geom_sf(
    data = city_border, color = "steelblue",
    fill = "transparent", size = 1.5,
    inherit.aes = FALSE
  ) +
  geom_sf(
    data = city_circle, color = "firebrick",
    fill = "transparent", size = 1.5,
    inherit.aes = FALSE
  ) +
  theme_void() +
  theme(panel.grid.major = element_line("transparent"))


crop_builtup_data <- function() {
  city_vect <- terra::vect(city_circle)
  city_raster <- terra::crop(builtup_data, city_vect)
  city_raster_cropped <- terra::mask(
    city_raster, city_vect
  )
  return(city_raster_cropped)
}

city_raster_cropped <- crop_builtup_data()
terra::plot(city_raster_cropped)


# 5. IMAGE TO DATA.FRAME
#-----------------------
raster_to_df <- function() {
  city_df <- terra::as.data.frame(
    city_raster_cropped,
    xy = T
  )
  
  return(city_df)
}

city_df <- raster_to_df()
#head(city_df)
names(city_df)[3] <- "value"

# define categorical values
city_df$cat <- round(city_df$value, 0)
city_df$cat <- factor(city_df$cat,
                        labels = c("no construido", "nuevo", "existente")
)

# 6. GET CITY ROADS FROM OSM DATA
#---------------------------------
road_tags <- c(
  "motorway", "trunk", "primary", "secondary",
  "tertiary", "motorway_link", "trunk_link", 
  "primary_link", "secondary_link", "tertiary_link"
)

get_osm_roads <- function() {
  bbox <- sf::st_bbox(city_border)
  roads <- bbox |>
    opq() |>
    add_osm_feature(
      key = "highway",
      value = road_tags
    ) |>
    osmdata::osmdata_sf()
  
  return(roads)
}

roads <- get_osm_roads()
city_roads <- roads$osm_lines |>
  sf::st_set_crs(crsLONGLAT) |>
  sf::st_transform(crs = crsLONGLAT)

ggplot() +
  geom_sf(
    data = city_circle, fill = "transparent",
    color = "steelblue", size = 1.2,
    inherit.aes = FALSE
  ) +
  geom_sf(
    data = city_roads,
    color = "firebrick", inherit.aes = FALSE
  ) +
  theme_void() +
  theme(panel.grid.major = element_line("transparent"))

# 7. CROP CITY ROADS WITH BUFFER
#--------------------------------
city_roads_cropped <- sf::st_intersection(
  city_roads, city_circle
)

ggplot() +
  geom_sf(
    data = city_circle,
    color = "steelblue", fill = NA,
    size = 1.2, inherit.aes = FALSE
  ) +
  geom_sf(
    data = city_roads_cropped, fill = "transparent",
    color = "firebrick", inherit.aes = FALSE
  ) +
  theme_void() +
  theme(panel.grid.major = element_line("transparent"))


# 8. MAP
#-------
colrs <- c(
  "black", "gold", "steelblue"
)

p <- ggplot() +
  geom_raster(
    data = city_df,
    aes(x = x, y = y, fill = cat),
    alpha = 1
  ) +
  geom_sf(
    data = city_roads_cropped,
    color = "black",
    size = .1,
    alpha = 1,
    fill = "transparent"
  ) +
  scale_fill_manual(
    name = "",
    values = colrs,
    drop = F
  ) +
  guides(
    fill = guide_legend(
      direction = "horizontal",
      keyheight = unit(1.5, units = "mm"),
      keywidth = unit(35, units = "mm"),
      title.position = "top",
      title.hjust = .5,
      label.hjust = .5,
      nrow = 1,
      byrow = T,
      reverse = F,
      label.position = "top"
    )
  ) +
  theme_minimal() +
  theme(
    axis.line = element_blank(),
    axis.text.x = element_blank(),
    axis.text.y = element_blank(),
    axis.ticks = element_blank(),
    axis.title.x = element_blank(),
    axis.title.y = element_blank(),
    legend.position = c(.5, 1.05),
    legend.text = element_text(size = 12, color = "white"),
    legend.title = element_text(size = 14, color = "white"),
    legend.spacing.y = unit(0.25, "cm"),
    panel.grid.major = element_line(color = "black", linewidth = 0.2),
    panel.grid.minor = element_blank(),
    plot.title = element_text(size = 18, color = "grey80", hjust = .5, vjust = 2),
    plot.caption = element_text(size = 6, color = "grey90", hjust = 1, vjust = 2, lineheight = 0.7),
    plot.margin = unit(c(t = 1, r = 0, b = 0, l = 0), "lines"),
    plot.background = element_rect(fill = "black", color = NA),
    panel.background = element_rect(fill = "black", color = NA),
    legend.background = element_rect(fill = "black", color = NA),
    legend.key = element_rect(colour = "white"),
    panel.border = element_blank()
  ) +
  labs(
    x = "",
    y = NULL,
    title = city_title,
    subtitle = "",
    caption = paste0("Radio: ",radius," km\n
                      Data: GLAD Built-up Change Data & ©OpenStreetMap contributors\n
                      ©2023 Carlos Marcos (https://github.com/marcoscarloseduardo)")
  )

ggsave(
  filename = paste0(city_obj,"_city_built_up2.png"),
  width = 6, height = 6, dpi = 2400,
  device = "png", p
)
