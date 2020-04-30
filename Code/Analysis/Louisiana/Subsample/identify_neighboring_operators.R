# Find neighbors of each unit and identify their operators

library(rgdal)
library(readstata13)
library(foreign)
library(magrittr)
library(ggplot2)
library(sf)
library(dplyr)
library(sp)
library(tidyverse)

# clear the workspace
rm(list=ls())
root <- getwd()
# recursively get up to the base of the repo where the filepaths are located
while (basename(root) != "HBP") {
  root <- dirname(root)
}

# Source helper functions
source(file.path(root, "data.R"))

# Specify all input filenames
units_in  <- paste0(dropbox, "/IntermediateData/Louisiana/DescriptiveUnits/master_unit_shapefile_urbanity.shp")

units_sf <- st_read(units_in) %>% 
  st_transform(26915) %>% 
  st_as_sf() %>%
  mutate(OPERATO = as.character(OPERATO))

unit_centroids <- st_centroid(units_sf) %>% select(unitID, OPERATO, section, townshp, range)

# Find neighbors within 1.2, 1.7 miles
# specify where to write out the circular buffers to
outfile_1p2_circular_buffer <- paste(dropbox, "/IntermediateData/Louisiana/DescriptiveUnits/units_with_1p2_neighbors.dta", sep="")
outfile_1p7_circular_buffer <- paste(dropbox, "/IntermediateData/Louisiana/DescriptiveUnits/units_with_1p7_neighbors.dta", sep="")
# create the buffers (1609.344 meters = 1 mile)
miledist_1p2 = 1609.344*1.2
miledist_1p7 = 1609.344*1.7

unit_buffer_1p2 <- st_buffer(unit_centroids, miledist_1p2)
unit_buffer_1p7 <- st_buffer(unit_centroids, miledist_1p7)

# do the intersection and eventually clean all the variable names that 
# R automatically generates for both buffer sizes
buffer_shpfile_intersect_1p2 <- st_intersection(unit_buffer_1p2, unit_centroids) %>%
  rename(unitID_neighbor = unitID.1,
         OPERATO_neighbor = OPERATO.1,
         section_neighbor = section.1,
         townshp_neighbor = townshp.1,
         range_neighbor = range.1) %>%
  filter(unitID != unitID_neighbor) %>%
  arrange(unitID, unitID_neighbor) %>%
  as_tibble()
rownames(buffer_shpfile_intersect_1p2) <- NULL

buffer_shpfile_intersect_1p7 <- st_intersection(unit_buffer_1p7, unit_centroids) %>%
  rename(unitID_neighbor = unitID.1,
         OPERATO_neighbor = OPERATO.1,
         section_neighbor = section.1,
         townshp_neighbor = townshp.1,
         range_neighbor = range.1) %>%
  filter(unitID != unitID_neighbor) %>%
  arrange(unitID, unitID_neighbor) %>%
  as_tibble()
rownames(buffer_shpfile_intersect_1p7) <- NULL

# get rid of geometry
buffer_shpfile_intersect_1p2$geometry <- NULL
buffer_shpfile_intersect_1p7$geometry <- NULL

# write to stata
write.dta(buffer_shpfile_intersect_1p2, outfile_1p2_circular_buffer)
write.dta(buffer_shpfile_intersect_1p7, outfile_1p7_circular_buffer)


