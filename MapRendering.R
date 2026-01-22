############################################################################
############################################################################
#  Map rendering using RayShader
#
#  Written by Niklas Blanadet
#  Last updated 20260
#
############################################################################
############################################################################

############################################################################
# SCRIPT SETUP
# 
# Set up the appropriate packages and data sources

library(tidyverse)    # General data manipulation tools
library(sf)           # General spatial manipulation tools
library(terra)        # Raster manipulation tools
library(lidR)         # LIDAR manipulation tools
library(gstat)        # Geostatistical data modeling package (used to determine tree tops)
library(rstac)
library(RCSF)         # Needed for some of the LIDAR algorithms

# Mapping libraries
library(rayshader)    # For making cool looking plots with DTM's
library(ambient)
library(lidRviewer)   # Better LIDAR viewer

# WD and LAS data path 
# setwd("C:/Users/nblan/OneDrive/Desktop/Projects/Mendocino/MendocinoTreeMapping")
setwd("C:/Users/nblan/Desktop/Research/MendocinoTreeMapping") # Desktop


las_data_path <- paste0("C:/LIDARData/MendocinoTreeMapping")
las_output_path <- paste0("C:/LIDARData/MendocinoTreeMapping/LIDAROutput")

dem_path <- paste0("C:/Users/nblan/Desktop/Research/MendocinoTreeMapping_Data/")

# For Desktop
dem <- rast(paste0(dem_path, "dem_knnidw.tif"))

plot(dem)
plot_dtm3d(dem)

# Let's use rayshade!

# First, convert into a matrix

elmat <- raster_to_matrix(dem)

# Now let's make plots! I will comment on all the changes I make

elmat |> 
  sphere_shade(texture = "imhof1") |>
  # add_water(detect_water(elmat), color = "desert") |>
  add_shadow(ray_shade(elmat), 0.5) |>
  add_shadow(ambient_shade(elmat, maxsearch = 30), 0) |>
  # plot_map() |>
  plot_3d(
    elmat, 
    zscale = 0, 
    fov = 0, 
    theta = 45, 
    zoom = 0.75, 
    phi = 45, 
    windowsize = c(1000, 800), 
    water = TRUE,  
    waterdepth = 10, 
    watercolor = "lightblue", 
    wateralpha = 0.5
  )

############################################################################