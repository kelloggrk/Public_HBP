#-------------------------------------------------------------------------------
# Name:        imputed_unit_robustness_check.R
# Purpose:     Given the unit shapefile, clean up the section identifiers and
#              give each unit urbanity estimations
#-------------------------------------------------------------------------------
#
# ---------------------------------------------------------------------------
# Description: First go through the imputed unit shapefile and check on
# discrepancies in section/township/range identifiers (no duplicates).
#
# Then add flags to the imputed unit shapefile to eventually
# tease out the urbanity of each section as coded in census blocks and
# how much of each section is impervious land cover from the
# National Land Cover Database.
#
# ---------------------------------------------------------------------------

library(rgdal)
library(readstata13)
library(magrittr)
library(dplyr)
library(tidyr)
library(lubridate)
library(RColorBrewer)
library(tiff)
library(raster)
library(sp)
library(sf)
library(gstat)
library(foreign)
library(ggthemes)
library(pracma)
library(splines)
library(stargazer)
library(xtable)
library(sandwich)
library(lmtest)
library(gtools)
library(smoothr)
library(rmapshaper)
library(lwgeom)
library(mapview)
library(readr)

# clear the workspace
rm(list=ls())
root <- getwd()
# recursively get up to the base of the repo where the filepaths are located
while ((basename(root) != "HBP")&(basename(root) != "hbp")) {
  root <- dirname(root)
}
source(file.path(root, "data.R"))

# input filenames
censusblock_shp <- paste(dropbox, "/RawData/orig/Louisiana/CensusBlock/gz_2010_22_150_00_500k.shp", sep="")
censusblock_csv <- paste(dropbox, "/RawData/orig/Louisiana/CensusBlock/DEC_10_SF1_P2_with_ann.csv", sep="")
imputed_units_shp <- paste(dropbox, "/IntermediateData/Louisiana/Units/imputed_units_shapefile.shp", sep="")
units <- paste(dropbox, "/RawData/orig/Louisiana/DNR/Haynesville_shale_units.shp", sep="")
impervious_raster_file <- paste(dropbox, "/RawData/orig/Louisiana/ImperviousRaster/nlcd_impervious_2001_la.tif", sep="")
# output filenames
final_units_shp_urbanity <- paste(dropbox, "/IntermediateData/Louisiana/DescriptiveUnits/master_unit_shapefile_urbanity.shp", sep="")
final_units_dta <- paste(dropbox, "/IntermediateData/Louisiana/DescriptiveUnits/master_units.dta", sep="")

# Census urbanity to merge with units
censusblock_sf <- st_read(censusblock_shp) %>%
  st_transform(26915)

censusblock_urbanity <- read.csv(file = censusblock_csv, skip = 1, header=TRUE) %>%
  rename(GEO_ID = Id) %>%
  rename(total = Total.) %>%
  rename(urban = Urban.) %>%
  mutate(percent_urban = urban/total) %>%
  dplyr::select(GEO_ID, percent_urban) %>%
  merge(censusblock_sf, all.y = TRUE) %>%
  st_as_sf(.)

# Read in our unit file
units_shp <- st_read(imputed_units_shp) %>%
  st_transform(26915) %>%
  mutate(total_area = st_area(.))

# Check that unitID is in correct format
units_shp$unitID_S <- as.character(units_shp$unitID)
units_shp$unitID_R <- as.numeric(units_shp$unitID)
units_shp$unitID[1:10]      # 1 2 3 4 5 6 7 8 9 10
units_shp$unitID_R[1:10]    # 1, 1112, 2223, 2629, 2740, ... --> 
  # becomes correct if use as.numeric at end of unit_section_merge.R
units_shp$unitID_S[1:10]    # "1", "2", "3", "4", ...
units_shp$unitID_S <- NULL
units_shp$unitID_R <- NULL

# Read in DNR Haynesville unit shapefile for comparison
units_sf <- st_read(units) %>%
  st_transform(26915) %>%
  mutate(unit_area = st_area(.)) %>%
  mutate(unitID = rownames(.))
names(units_sf)

units_hello <- units_shp %>%
  dplyr::select(section, townshp, range)
units_hello$geometry = NULL
units_hello$section[duplicated(units_hello)]
units_hello$townshp[duplicated(units_hello)]
units_hello$range[duplicated(units_hello)]

################################

units_shp[which(units_shp$unitID==796),names(units_shp) %in% c("unitID","section","townshp","range")]
# section townshp range unitID                       geometry
# 796       6      15   -12    796 POLYGON ((447625.3 3576368,...

################################
# Manually fix a bunch of units

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==796, 1, section))

units_shp <- units_shp %>%
  filter(unitID!=1280) %>%
  filter(unitID!=1281) %>%
  filter(unitID!=1361) %>%
  filter(unitID!=1362) %>%
  filter(unitID!=1457) %>%
  filter(unitID!=1719) %>%
  filter(unitID!=1466) %>%
  filter(unitID!=2018) %>%
  filter(unitID!=93) %>%
  filter(unitID!=1120) %>%
  filter(unitID!=5) %>%
  filter(unitID!=3147) %>%
  filter(unitID!=2895) %>%
  filter(unitID!=3193)

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==1358, 4, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==1366, 3, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==1166, 4, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==68, 35, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==1937, 7, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==1995, 2, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==538, 34, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==1991, 25, section))

units_shp <- units_shp %>%
  mutate(range = ifelse(unitID==2160, -12, range))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==1296, 28, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==2828, 27, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==1836, 31, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3086, 36, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==448, 32, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3089, 31, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==106, 33, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3210, 31, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3211, 30, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3212, 19, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3217, 30, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3218, 19, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3219, 18, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3220, 7, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3221, 6, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3222, 31, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3223, 30, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3224, 19, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3225, 18, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3226, 6, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3242, 32, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3231, 32, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3232, 29, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3233, 20, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3237, 29, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3238, 20, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3239, 17, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3240, 8, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3241, 5, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3243, 29, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3244, 20, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3247, 33, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==736, 34, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==616, 35, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3248, 28, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3249, 21, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==1852, 22, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3254, 28, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3255, 4, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3256, 33, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3257, 28, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3260, 27, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3213, 18, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3234, 17, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3250, 16, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==123, 10, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3267, 12, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3214, 7, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3235, 8, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3251, 9, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3276, 36, section)) %>%
  mutate(range = ifelse(unitID==3276, -12, range))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3270, 31, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3272, 32, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3273, 33, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3274, 34, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3275, 35, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3279, 31, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3281, 32, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==2831, 27, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==2828, 24, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3089, 36, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3092, 31, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==2842, 19, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3210, 36, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3211, 25, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3212, 24, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3215, 19, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3218, 6, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3236, 20, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==2227, 5, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3228, 18, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3225, 31, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3229, 6, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3226, 30, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3231, 30, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3233, 6, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3238, 8, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3252, 21, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3235, 29, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3237, 17, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3213, 31, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3253, 16, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3234, 32, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3253, 33, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3261, 3, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3266, 2, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3271, 1, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3245, 32, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3213, 33, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3227, 19, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3246, 29, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3248, 29, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3232, 19, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3249, 20, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3253, 16, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3250, 33, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3258, 4, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3241, 20, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3244, 5, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3259, 33, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3247, 20, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3260, 28, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3262, 34, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3256, 33, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3263, 27, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3213, 31, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3267, 35, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3216, 18, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3270, 12, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3242, 17, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3272, 36, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3239, 32, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3274, 5, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3277, 34, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3273, 31, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3278, 35, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3275, 32, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3281, 6, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3282, 31, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3279, 36, section)) %>%
  mutate(range = ifelse(unitID==3279, -12, range))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3284, 32, section))

units_shp <- units_shp %>%
  mutate(section = ifelse(unitID==3276, 33, section))

units_shp <- units_shp %>%
  mutate(range = ifelse(range==-15 & townshp==8, -14, range))


####################################
# Merge urbanity and imperviousness 

unit_block_intersection <- st_intersection(units_shp, censusblock_urbanity) %>%
  mutate(intersecting_area = st_area(.)) %>%
  mutate(area_weight = as.numeric(intersecting_area)/as.numeric(total_area)) %>%
  mutate(weighted_urbanity = percent_urban * area_weight) %>%
  dplyr::select(section, townshp, range, weighted_urbanity)

units_with_urbanity <- unit_block_intersection
units_with_urbanity$geometry = NULL
units_with_urbanity <- units_with_urbanity %>%
  group_by(section, townshp, range) %>%
  summarise(total_urbanity = sum(weighted_urbanity))

impervious_raster <- raster(impervious_raster_file)

units_sp <- as(units_shp, "Spatial")
units_extracted <- raster::extract(impervious_raster, units_sp)

imperviousness <- mapply(mean, units_extracted)
units_with_raster<- cbind(units_shp, imperviousness)

plot(units_with_raster[,8])

units_with_raster_urbanity <- units_with_raster %>%
  right_join(units_with_urbanity, by=c("section", "townshp", "range"))

plot(impervious_raster)

# Pull unit information from DNR, merge onto our units
units_no_geom <- units_sf
units_no_geom$geometry=NULL

units_with_raster_urbanity <- units_with_raster_urbanity %>%
  merge(units_no_geom, by=c('unitID'), all.x=TRUE)
units_centroids_sf <- units_shp %>%
  st_centroid(.)

# Get lat/lon for centroid
units_centroid_coords <- do.call(rbind, st_geometry(units_centroids_sf)) %>%
  as_tibble() %>% setNames(c("lon","lat"))

units_with_raster_urbanity <- dplyr::bind_cols(units_with_raster_urbanity, units_centroid_coords) %>%
  dplyr::rename(section_lat = lat) %>%
  dplyr::rename(section_lon = lon) %>%
  dplyr::rename(unit_origin = unt_rgn) %>%
  dplyr::rename(township = townshp) %>%
  dplyr::rename(DNR_section_poly_acres = ply_r_c) %>%
  mutate(total_area = total_area/4046.856)
  
units_with_raster_urbanity <- units_with_raster_urbanity %>% 
                                st_transform(26915) %>%
                                st_difference(.)

units_with_raster_nogeom <- units_with_raster_urbanity
units_with_raster_nogeom$geometry=NULL

if (file.exists(final_units_shp_urbanity))
  #Delete file if it exists
  file.remove(final_units_shp_urbanity)
st_write(units_with_raster_urbanity, final_units_shp_urbanity)
write.dta(units_with_raster_nogeom, final_units_dta)


