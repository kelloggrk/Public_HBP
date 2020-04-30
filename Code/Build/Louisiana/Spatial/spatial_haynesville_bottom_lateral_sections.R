#-------------------------------------------------------------------------------
# Name: spatial_haynesville_bottom_lateral_sections.R Purpose: Given the final
# unit-level dataset, match up all bottom laterals in a deterministic way 
#-------------------------------------------------------------------------------
# ---------------------------------------------------------------------------
# Description: This file first
# takes in as input the final polygon shapefile of units we have created,
# cleaned, and identified. Then we map all the well laterals onto the unit-level
# shapefile. The problem is that there are often many well laterals (completions)
# per well serial number.  This is due to the multiple completions that happen in
# each well and make things very difficult in pinning down exactly which unit
# each well is considered to be in. We get around this by matching wells to units
# in many different ways.  We match all bottom holes to units, all topholes to
# units, all intersecting laterals to units, all weighted midpoints of laterals
# to units, all first completions to units, and all longest completions to units.
# ---------------------------------------------------------------------------

library(rgdal)
library(raster)
library(maptools)
library(readstata13)
library(foreign)
library(magrittr)
library(sp)
library(latticeExtra)
library(lattice)
library(ggplot2)
library(sf)
library(dplyr)
library(rgeos)


# clear the workspace
rm(list=ls())
root <- getwd()
# recursively get up to the base of the repo where the filepaths are located
while ((basename(root) != "HBP")&(basename(root) != "hbp")) {
  root <- dirname(root)
}
source(file.path(root, "data.R"))

# Specify all input filenames
sections <- paste(dropbox, "/IntermediateData/Louisiana/DescriptiveUnits/master_unit_shapefile_urbanity.shp",
  sep = "")
well_legs_prj <- paste(dropbox, "/RawData/orig/Louisiana/DNR/BOTTOM_HOLE_LINE.shp",
  sep = "")
bottom_prj <- paste(dropbox, "/RawData/orig/Louisiana/DNR/BOTTOM_HOLE.shp",
  sep = "")
tophole_prj <- paste(dropbox, "/RawData/orig/Louisiana/DNR/dnr_wells.shp", sep = "")

# Specify all output filenames
bottom2sections_dta <- paste(dropbox, "/IntermediateData/Louisiana/DescriptiveUnits/bottomholes_to_units.dta",
  sep = "")
leg2sections_dta <- paste(dropbox, "/IntermediateData/Louisiana/DescriptiveUnits/legs_to_units.dta",
  sep = "")
legcentroids2sections_dta <- paste(dropbox, "/IntermediateData/Louisiana/DescriptiveUnits/leg_centroids_to_units.dta",
  sep = "")
weighted_legscentroids2sections_dta <- paste(dropbox, "/IntermediateData/Louisiana/DescriptiveUnits/weighted_leg_centroids_to_units.dta",
  sep = "")
well_legs_dta <- paste(dropbox, "/IntermediateData/Louisiana/Wells/well_legs.dta",
  sep = "")
legs_max_lat_out <- paste(dropbox, "/IntermediateData/Louisiana/DescriptiveUnits/longest_legs_to_units.dta",
  sep = "")
legs_first_completion_out <- paste(dropbox, "/IntermediateData/Louisiana/DescriptiveUnits/first_completion_legs_to_units.dta",
  sep = "")
top2sections_dta <- paste(dropbox, "/IntermediateData/Louisiana/DescriptiveUnits/topholes_to_units.dta",
  sep = "")
well_legs_centroids_dta <- paste(dropbox, "/IntermediateData/Louisiana/Wells/well_legs_centroids.dta",
  sep = "")
bottom_dta <- paste(dropbox, "/IntermediateData/Louisiana/Wells/bottomholes.dta",
  sep = "")
well_legs_weighted_centroids_dta <- paste(dropbox, "/IntermediateData/Louisiana/Wells/well_legs_weighted_centroids.dta",
  sep = "")

# counties Create the county raster file
raster_path <- paste(dropbox, "/RawData/orig/Louisiana/County/la_counties.shp", sep = "")
county_raster <- readOGR(dsn = raster_path)
new_county_raster <- spTransform(county_raster, CRS("+init=epsg:4267 +proj=longlat +ellps=clrk66 +datum=NAD27"))

county_sf <- st_read(raster_path) %>% st_transform(26915)

# Read in all the already reprojected sections, well legs, and bottomholes
sections_sf <- st_read(sections)
sections_sf <- sections_sf %>% st_transform(26915) %>%
  rename(SECTN = section) %>% rename(TOWNSHIP = townshp) %>% rename(RANGE = range) %>%
  rename(sectionFID = unitID) %>% dplyr::select(geometry, sectionFID, SECTN, TOWNSHIP,
  RANGE)


# tease out only sections in haynesville counties
relevant_sections_sf <- st_intersection(county_sf, sections_sf) %>% dplyr::select(SECTN,
  TOWNSHIP, RANGE, sectionFID, geometry)

# start the well leg matching algorithm process
well_legs_sf <- st_read(well_legs_prj) %>% st_transform(26915) %>% mutate(index = rownames(.)) %>%
  mutate(lateral_length = st_length(geometry)) %>% dplyr::select(WELL_SERIA, BHC_SEQ_NU,
  geometry, lateral_length, EFFECTIVE_, index)

# find the longest completion
well_legs_max_sf <- aggregate(well_legs_sf$lateral_length, by = list(well_legs_sf$WELL_SERIA),
  max) %>% dplyr::rename(WELL_SERIA = Group.1, max_lat = x)

# find the earliest completion
well_legs_first_date_sf <- aggregate(well_legs_sf$EFFECTIVE_, by = list(well_legs_sf$WELL_SERIA),
  min) %>% dplyr::rename(WELL_SERIA = Group.1, min_effective_date = x)

# keep track of longest and earliest completion
augmented_well_data <- merge(well_legs_sf, well_legs_max_sf, by = "WELL_SERIA", all.x = TRUE) %>%
  merge(well_legs_first_date_sf, by = "WELL_SERIA", all.x = TRUE)

# replace effective dates with 0 for some formatting issues when moving to stata
augmented_well_data_date_fix <- augmented_well_data %>% mutate(EFFECTIVE_ = ifelse(is.na(EFFECTIVE_),
  0, EFFECTIVE_)) %>% mutate(min_effective_date = ifelse(is.na(min_effective_date),
  0, min_effective_date))

# create datasets of just all well data with longest lat length and one with
# first completion
well_legs_max_only_sf <- filter(augmented_well_data, as.numeric(lateral_length) ==
  as.numeric(max_lat))
well_legs_first_only_sf <- filter(augmented_well_data_date_fix, as.numeric(EFFECTIVE_) ==
  as.numeric(min_effective_date))

# checking that all well serial numbers are accounted for in these new data sets
# length(unique(well_legs_max_only_sf$WELL_SERIA))
# length(unique(well_legs_first_only_sf$WELL_SERIA))

# if earliest lateral doesn't exist, just use max lateral
well_legs_first_only_max_lat <- aggregate(well_legs_first_only_sf$lateral_length,
  by = list(well_legs_first_only_sf$WELL_SERIA), max) %>% dplyr::rename(WELL_SERIA = Group.1,
  max_lat_2 = x)
well_legs_max_earliest_lat <- aggregate(well_legs_max_only_sf$EFFECTIVE_, by = list(well_legs_max_only_sf$WELL_SERIA),
  min) %>% dplyr::rename(WELL_SERIA = Group.1, min_date_2 = x)
well_legs_first_only_sf <- merge(well_legs_first_only_sf, well_legs_first_only_max_lat,
  by = "WELL_SERIA", all.x = TRUE)
well_legs_first_only_sf <- filter(well_legs_first_only_sf, as.numeric(lateral_length) ==
  as.numeric(max_lat_2))

well_legs_max_only_sf <- merge(well_legs_max_only_sf, well_legs_max_earliest_lat,
  by = "WELL_SERIA", all.x = TRUE) %>% mutate(EFFECTIVE_ = ifelse(is.na(EFFECTIVE_),
  0, EFFECTIVE_)) %>% mutate(min_date_2 = ifelse(is.na(min_date_2), 0, min_date_2))

well_legs_max_only_sf <- filter(well_legs_max_only_sf, as.numeric(EFFECTIVE_) ==
  as.numeric(min_date_2))
# once again, still 13402 unique wells
# length(unique(well_legs_first_only_sf$WELL_SERIA))
# length(unique(well_legs_max_only_sf$WELL_SERIA))

# delete all the others
# well_legs_first_only_sf$BHC_SEQ_NU<-NULL
well_legs_first_only_sf$max_lat <- NULL
well_legs_first_only_sf$max_lat_2 <- NULL
well_legs_first_only_sf$min_effective_date <- NULL
well_legs_first_only_sf$BHC_SEQ_NU <- NULL
well_legs_first_only_sf$index <- NULL
well_legs_first_only_sf <- unique(well_legs_first_only_sf)

# intersect the well legs and the sections
wells_first_sections_intersect <- st_intersection(well_legs_first_only_sf, sections_sf) %>%
  mutate(isect_length = st_length(geometry))
wells_first_sections_intersect$geometry <- NULL

write.dta(data = wells_first_sections_intersect, file = legs_first_completion_out)

well_legs_max_only_sf$min_date_2 <- NULL
well_legs_max_only_sf$max_lat <- NULL
well_legs_max_only_sf$min_effective_date <- NULL
well_legs_max_only_sf$BHC_SEQ_NU <- NULL
well_legs_max_only_sf$index <- NULL
well_legs_max_only_sf <- unique(well_legs_max_only_sf)

wells_max_lat_sections_intersect <- st_intersection(well_legs_max_only_sf, sections_sf) %>%
  mutate(isect_length = st_length(geometry))
wells_max_lat_sections_intersect$geometry <- NULL

write.dta(data = wells_max_lat_sections_intersect, file = legs_max_lat_out)

well_legs_to_export <- well_legs_sf
well_legs_to_export$geometry <- NULL
write.dta(well_legs_to_export, well_legs_dta)

well_legs_centroids_sf <- st_read(well_legs_prj) %>% st_transform(26915) %>% mutate(index = rownames(.)) %>%
  mutate(lateral_length = st_length(geometry)) %>% dplyr::select(WELL_SERIA, BHC_SEQ_NU,
  EFFECTIVE_, geometry, index, lateral_length) %>% st_centroid(.)

# tease out lat/lon for weighted midpoint
well_centroid_coords <- do.call(rbind, st_geometry(well_legs_centroids_sf)) %>% as_tibble() %>%
  setNames(c("lon", "lat"))

well_legs_centroids_sf <- dplyr::bind_cols(well_legs_centroids_sf, well_centroid_coords) %>%
  dplyr::rename(midpoint_lat = lat) %>% dplyr::rename(midpoint_lon = lon)
well_legs_centroids_sf$geometry <- NULL
write.dta(well_legs_centroids_sf, well_legs_centroids_dta)
well_legs_centroids_sf$BHC_SEQ_NU <- NULL
well_legs_centroids_sf$EFFECTIVE_ <- NULL
well_legs_centroids_sf$index <- NULL

# perform all the weighting
# remove unit from lateral_length
well_legs_centroids_sf <- data.frame(well_legs_centroids_sf) %>% 
    mutate(lateral_length=as.numeric(lateral_length))
well_legs_weighted_centroids <- well_legs_centroids_sf %>% dplyr::group_by(WELL_SERIA) %>%
  dplyr::summarise(weighted_lat = weighted.mean(midpoint_lat, lateral_length),
                   weighted_lon = weighted.mean(midpoint_lon, lateral_length))
write.dta(well_legs_weighted_centroids, well_legs_weighted_centroids_dta)

# get rid of the current geometries and then recast the weighted midpoints as
# geometry objects
well_legs_weighted_centroids_sf <- st_as_sf(well_legs_weighted_centroids, coords = c("weighted_lon",
  "weighted_lat"), crs = 26915)
well_legs_weighted_centroids_df <- do.call(rbind, st_geometry(well_legs_weighted_centroids_sf)) %>%
  as_tibble() %>% setNames(c("weighted_lon", "weighted_lat"))

well_legs_weighted_centroids_sf <- sf:::cbind.sf(well_legs_weighted_centroids_sf,
  well_legs_weighted_centroids_df)

# perform the intersection
well_legs_weighted_centroids_sections_intersect <- st_intersection(well_legs_weighted_centroids_sf,
  sections_sf)

# do a bit of bottomhole analysis
bottom_sf <- st_read(bottom_prj) %>% st_transform(26915) %>% mutate(index = rownames(.)) %>%
  dplyr::select(WELL_SERIA, geometry, EFFECTIVE_, index, BHC_SEQ_NU)

bottom_sf_coords <- do.call(rbind, st_geometry(bottom_sf)) %>% as_tibble() %>% setNames(c("lon",
  "lat"))

bottom_sf_cleaned <- dplyr::bind_cols(bottom_sf, bottom_sf_coords) %>% dplyr::rename(lateral_BH_lat_ = lat) %>%
  dplyr::rename(lateral_BH_lon_ = lon)

bottom_sf_cleaned$EFFECTIVE_ <- NULL
bottom_sf_cleaned$index <- NULL
bottom_sf_cleaned$geometry <- NULL

write.dta(bottom_sf_cleaned, bottom_dta)

topholes_sf <- st_read(tophole_prj) %>% st_transform(26915) %>% dplyr::select(WELL_SERIA,
  EFFECTIVE_, geometry)

# intersect the bottomholes and sections
bottom_sections_intersect <- st_intersection(bottom_sf, relevant_sections_sf)

top_sections_intersect <- st_intersection(topholes_sf, relevant_sections_sf)

# intersect the well legs and the sections
wells_sections_intersect <- st_intersection(well_legs_sf, sections_sf) %>% mutate(isect_length = st_length(geometry)) %>%
  mutate(rec_type = "well_legs_prj")

# uncomment to get a plot of all wells x sections in the paper ggplot() +
# geom_sf(data = sections_sf, fill = 'pink', size = 0.1) + geom_sf(data =
# wells_sections_intersect, colour = 'blue')

# clean up geometry objects before writing to .dta files
bottom_sections_intersect$geometry <- NULL
top_sections_intersect$geometry <- NULL
wells_sections_intersect$geometry <- NULL
well_legs_weighted_centroids_sections_intersect$geometry <- NULL

# Note that when writing to stata files, all strings get encoded and thus needed
# to be decoded before any transformations occur in stata
write.dta(data = bottom_sections_intersect, file = bottom2sections_dta)
write.dta(data = top_sections_intersect, file = top2sections_dta)
write.dta(data = wells_sections_intersect, file = leg2sections_dta)
write.dta(data = well_legs_weighted_centroids_sections_intersect, file = weighted_legscentroids2sections_dta)
