#-------------------------------------------------------------------------------
# Name:        unit_section_merge.R
# Purpose:     Given a sparse unit shapefile, fill in all the holes and
#              identify all imputed units in the grid
#
#-------------------------------------------------------------------------------
#
# ---------------------------------------------------------------------------
# Description:
#
# This file fills in holes and merges together sections and units to create
# a master shapefile that will be used for our build and all descriptives
#
# The new shapefile will have units in places where the units exist.
# If the units do not exist, it would use sections as long as the sections are nicely shaped.
# If sections do not exist or are not nicely shaped we would need to impute the likely potential unit, following the same grid pattern
# We also include geographic restrictions here on both location and area of units
# We geographically restrict for now to the interior of the convex hull of the original unit shapefile.
# ---------------------------------------------------------------------------
library(dplyr)
library(tidyr)
library(rgdal)
library(sp)
library(sf)

# clear the workspace
rm(list=ls())
root <- getwd()
# recursively get up to the base of the repo where the filepaths are located
while ((basename(root) != "HBP")&(basename(root) != "hbp")) {
  root <- dirname(root)
}
source(file.path(root, "data.R"))

# -----------------------------------------------------------------------------
# set all our path variables
rawOrigPath <- paste(dropbox, "/RawData/orig/Louisiana/DNR", sep="")
rawDataPath <- paste(dropbox, "/RawData/data/Louisiana/DNR", sep="")
# Files which are read in
counties_shp <- paste(dropbox, "/RawData/orig/Louisiana/County/tl_2010_22_county10.shp", sep="")
# Files which are written out
counties_out <- paste(dropbox, "/RawData/data/Louisiana/County/la_counties.shp", sep="")

# -----------------------------------------------------------------------------
shp_in <- st_read(counties_shp)
la_shp <- shp_in %>% 
  st_transform(26915) %>%
  dplyr::select(STATEFP10,COUNTYFP10,COUNTYNS10,GEOID10,NAME10) %>% 
  filter(NAME10 %in% c("Bienville","Bossier","Natchitoches","Webster","Sabine","Red River","De Soto","Caddo")) %>%
  rename_all(., ~sub("10","",.)) %>%
  mutate(AFFGEOID = paste0("0500000US",STATEFP,COUNTYFP))

st_write(obj=la_shp, dsn=counties_out, delete_dsn=TRUE)
