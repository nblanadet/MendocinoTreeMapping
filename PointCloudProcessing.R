############################################################################
############################################################################
#  Vegetation LIDAR Point Cloud Processing for Jug Handle State Natural Reserve
#  and Jackson Demonstration State Forest 
#
#  Written by Niklas Blanadet
#  Last updated 20260112
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
library(lidRviewer)   # Better LIDAR viewer

# WD and LAS data path 
setwd("C:/Users/nblan/OneDrive/Desktop/Projects/Mendocino/MendocinoTreeMapping")

las_data_path <- paste0("C:/LIDARData/MendocinoTreeMapping")
las_output_path <- paste0("C:/LIDARData/MendocinoTreeMapping/LIDAROutput")

############################################################################
# REPROJECTING THE POINT CLOUDS

# The point clouds are originally downloaded from the USGS - these are LIDAR
# point clouds collected in 2018. However, they are originally in feet, and therefore
# we want to convert them into meters before moving on. 

# There are several ways to do this. One is with a catalog, but the function (st_transform()) 
# doesn't work with catalogs. So we are just going to use a for loop. 

# Find the output directory for the files. Create beforehand if you haven't already
conversion_output_directory <- paste0(las_output_path, "01_converted_m", sep="") 
# Get a list of the files
raw_files_ft <- list.files(paste0(las_data_path, "/LIDARPointClouds"), pattern = "\\.la[sz]$", full.names = TRUE)

# Define the source CRS and target CRS
source_crs <- "EPSG:6418+6360"
target_crs <- "EPSG:6417+5703"

# write the for loop that will create our converted files
for (f in raw_files_ft) {
  
  message("Processing: ", basename(f))
  
  las <- readLAS(f)
  if (is.empty(las)) next
  
  # assign correct source CRS
  # st_crs(las) <- source_crs
  
  # reproject CRS
  las_m <- st_transform(las, crs = target_crs)
  
  out_file <- file.path(conversion_output_directory, basename(f))
  writeLAS(las_m, out_file)
}

############################################################################
# Removing Noise and Classifying Ground

# We are going to process the LIDAR point clouds by removing noisy points and 
# reclassifying the ground points. 
# The current point cloud actually does a decent job with the ground classification
# already. Classifying the ground on my personal computer also takes too long, 
# so the ground classification will happen on the cluster. Therefore, on this computer, 
# I am only going to remove the noisy points. I will then later compare the point clouds
# created on my computer with the ones with the re-classified ground points on the cluster, 
# and use whichever point cloud looks best. 

# So I am actually going to start by creating a noise-free copy, and then 
# we will classify the ground later on the cluster. 

process_ctg1 <- readLAScatalog(paste0(las_output_path, "/01_converted_m"))

# ---------- 1) Classify NOISE and write updated files ----------
opt_output_files(process_ctg1) <- paste0(las_output_path, "/02_classified_noise/{ORIGINALFILENAME}")
opt_laz_compression(process_ctg1) <- TRUE

# Example SOR params; tune k/m to your data
classify_noise(process_ctg1, sor(k = 15, m = 10))

# ---------- 2) Classify GROUND on the noise-classified catalog ----------
process_ctg2 <- readLAScatalog(paste0(las_output_path, "/03_classified_noise"))

# (Optional) tune chunking/buffer for ground algorithms
opt_chunk_size(process_ctg2)   <- 0  # meters, example
opt_chunk_buffer(process_ctg2) <- 0.01

# Choose a ground algorithm (PMF or CSF are common)
# PMF example:
# alg <- pmf(ws = 3, th = 1.0)   # tune to your site / point density
# or CSF example:
# Please note - I used the cluster to run this algorithm - settings are: 
# 2 cores, 100 gb RAM per core
# Took 6 hours
alg <- csf(cloth_resolution = 0.5, class_threshold = 0.5, rigidness = 1, sloop_smooth = TRUE)

opt_output_files(process_ctg2) <- paste0(las_output_path, "/03_classified_noise_ground/{ORIGINALFILENAME}")
classify_ground(process_ctg2, alg)  # writes files with BOTH noise (7/18) and ground (2)

# At this point: files in 02_classified_noise_ground have
# - noise points labeled (usually class 7 and/or 18)
# - ground points labeled (class 2)
# - all other classes preserved.

# ---------- 3) (Optional) Write a NOISE-FREE copy ----------
# process_ctg3 <- readLAScatalog(paste0(las_output_path, "/03_classified_noise_ground")) # uncommnent this if you are going to use the catalog with re-classified ground
process_ctg3 <- readLAScatalog(paste0(las_output_path, "/02_classified_noise"))
opt_output_files(process_ctg3) <- paste0(las_output_path, "/04_noise_free/{ORIGINALFILENAME}")

# Drop noise classes on read while copying
opt_filter(process_ctg3) <- "-drop_classification 7 18"
# opt_laz_compression(process_ctg3) <- TRUE
opt_independent_files(process_ctg3) <- TRUE
opt_chunk_size(process_ctg3) <- 0
opt_chunk_buffer(process_ctg3) <- 0.01

# copy filtered chunks to disk; skip empty ones
copy_fun <- function(chunk) {
  las <- readLAS(chunk)          # <- turn LAScluster into a LAS (or NULL)
  if (is.null(las)) return(NULL) # empty after filters -> must return NULL
  # if you like, you can also guard with:
  if (is.empty(las)) return(NULL)
  las                             # returning a LAS lets lidR write it to disk
}
catalog_apply(process_ctg3, copy_fun)


















