# City Built-Up Area Analysis

This R script allows you to analyze built-up areas in a specific city using open data sources. It includes functions for obtaining and processing built-up area data, extracting city boundaries from OpenStreetMap, and generating plots to visualize the results.

The Global Land Analysis & Discovery (GLAD) group created these data using the following process:
- Built-up land encompasses artificial land surfaces associated with infrastructure, commercial, and residential land uses. At Landsat's spatial resolution, they classify the built-up land category to include pixels containing man-made surfaces, even when these surfaces don't dominate the pixel.
- The GLAD group employed the CNN (U-Net) algorithm, calibrated with building outlines and road data from OpenStreetMap, to map the global extent of built-up areas for the years 2000 and 2020.
- They generated per-pixel class presence probabilities for 2000 and 2020, utilizing validation data to refine the final thresholds for depicting extents in those years and the gain in built-up lands between 2000 and 2020.
- This provisional product, created by the GLAD group, does not map the loss of built-up lands, as it represents a small proportion of the year 2000 class area

When interpreting the maps, it's important to note that they only identify new areas allocated for construction, not the reconstruction of spaces that previously had buildings. This perspective focuses on the horizontal expansion of cities rather than their vertical growth, providing insights into urban development patterns and changes over time.

## Getting Started

1. **Load Libraries:** Install and load the required R packages using the following code:

   ```R
   # 1. LOAD LIBRARIES
   #--------------------------
   # ... (library installation code)
   libs <- c("tidyverse", "sf", "osmdata", "tmaptools", "stringi", "terra", "httr", "XML")
   # ... (loading code)
   invisible(lapply(libs, library, character.only = TRUE))

## Get Built-Up Data for a City:
Define the city of interest and its coordinates. The script allows you to choose different methods to crop the built-up area data, including using a polygon, bounding box, or a buffer around the city.

## Get City Boundaries from OSM Data:
Extract city boundaries from OpenStreetMap using the specified city object.

## Crop City Raster
Use one of the available methods (polygon, bounding box, or buffer) to crop the built-up area raster data.

## Image to Data Frame:
Convert the cropped raster data into a data frame and define categorical values.

## Get City Roads from OSM Data:
Retrieve city road data from OpenStreetMap and visualize it.

## Crop City Roads with Buffer:
Use a buffer to crop the city road data.

## Generate a Map:
Create a map that visualizes the city's built-up areas, roads, and other information.

## Example Plot:
Trenque Lauquen, Buenos Aires Province, Argentina
![City Built-Up Area Plot](https://raw.githubusercontent.com/marcoscarloseduardo/map-city-expansion/main/Trenque%20Lauquen%2C%20Partido%20de%20Trenque%20Lauquen%2C%20Provincia%20de%20Buenos%20Aires%2C%20Argentina_city_built_up2.png)

## Usage
You can adapt and modify this script to analyze built-up areas in different cities. Follow the comments and documentation within the script for details on each step.

## Author
This script was created by Carlos Marcos based on [Milos Makes Maps](@milos_agathon) tutorial.A function was developed to identify the TIFF file associated with the city of interest, and solutions were added to handle cases where there are multiple polygons in OSM for city identification or other imported sf objects such as multipolygons.

## License
This project is licensed under the MIT License.

## Acknowledgments
[OpenStreetMap contributors](https://www.openstreetmap.org/)
[GLAD Built-up Change Data](https://glad.umd.edu/)
