#!/bin/sh

#-------------------------------------------------------------------------------
# Name:        initial_spatial_clean.sh
# Purpose:     Builds the unit-level shapefile
#
# Author:      Nadia
#
# Created:     10/12/2017
#-------------------------------------------------------------------------------
#
# This is the descriptive portion of each script run:
# ------------------------------------------------------
#
### RScript $CODEDIR/Louisiana/Spatial/import_haynesville_counties.R
# INPUTS:
# HBP/RawData/orig/Louisiana/County/tl_2010_22_county10.shp
# OUTPUTS:
# HBP/RawData/orig/Louisiana/County/la_counties.shp
# ------------------------------------------------------
#
### RScript $CODEDIR/Louisiana/Spatial/unit_section_merge.R
# INPUTS:
# HBP/RawData/orig/Louisiana/DNR/dnr_wells.shp
# HBP/RawData/orig/Louisiana/DNR/Sections_1to100_000.shp
# HBP/RawData/orig/Louisiana/DNR/Haynesville_shale_units.shp
# HBP/RawData/orig/Louisiana/County/la_counties.shp
#
# OUTPUTS:
# HBP/IntermediateData/Louisiana/Units/imputed_units_shapefile.shp
#
# UTILITIES:
# RScript $CODEDIR/Louisiana/Spatial/identify_trs.R
# ------------------------------------------------------
#
### RScript $CODEDIR/Louisiana/Spatial/imputed_unit_robustness_check.R
# INPUTS:
# HBP/RawData/data/Louisiana/CensusBlock/gz_2010_22_150_00_500k.shp
# HBP/RawData/data/Louisiana/CensusBlock/DEC_10_SF1_P2_with_ann.csv
# HBP/IntermediateData/Louisiana/Units/imputed_units_shapefile.sh
# HBP/RawData/orig/Louisiana/DNR/Haynesville_shale_units.shp
# HBP/RawData/orig/Louisiana/ImperviousRaster/nlcd_impervious_2001_la.tif
#
# OUTPUTS:
# HBP/IntermediateData/Louisiana/DescriptiveUnits/master_unit_shapefile_urbanity.shp
# HBP/IntermediateData/Louisiana/DescriptiveUnits/master_units.dta
# ------------------------------------------------------
#
### RScript $CODEDIR/Louisiana/Spatial/spatial_haynesville_bottom_lateral_sections.R
# INPUTS:
# HBP/IntermediateData/Louisiana/DescriptiveUnits/master_unit_shapefile_urbanity.shp
# HBP/RawData/orig/Louisiana/DNR/dnr_wells.shp
# HBP/RawData/orig/Louisiana/DNR/BOTTOM_HOLE.shp
# HBP/RawData/orig/Louisiana/DNR/BOTTOM_HOLE_LINE.shp
#
# OUTPUTS:
# HBP/IntermediateData/Louisiana/DescriptiveUnits/bottomholes_to_units.dta
# HBP/IntermediateData/Louisiana/DescriptiveUnits/legs_to_units.dta
# HBP/IntermediateData/Louisiana/DescriptiveUnits/leg_centroids_to_units.dta
# HBP/IntermediateData/Louisiana/DescriptiveUnits/weighted_leg_centroids_to_units.dta
# HBP/IntermediateData/Louisiana/Wells/well_legs.dta
# HBP/IntermediateData/Louisiana/DescriptiveUnits/longest_legs_to_units.dta
# HBP/IntermediateData/Louisiana/DescriptiveUnits/first_completion_legs_to_units.dta
# HBP/IntermediateData/Louisiana/DescriptiveUnits/topholes_to_units.dta
# HBP/IntermediateData/Louisiana/Wells/well_legs_centroids.dta
# HBP/IntermediateData/Louisiana/Wells/bottomholes.dta
# HBP/IntermediateData/Louisiana/Wells/well_legs_weighted_centroids.dta
# ------------------------------------------------------

# Variables CODEDIR, OS, and STATA exported from build_script.sh

RScript $CODEDIR/Louisiana/Spatial/import_haynesville_counties.R &&
RScript $CODEDIR/Louisiana/Spatial/unit_section_merge.R &&
RScript $CODEDIR/Louisiana/Spatial/imputed_unit_robustness_check.R &&
RScript $CODEDIR/Louisiana/Spatial/spatial_haynesville_bottom_lateral_sections.R 

# Clean up log files
rm *.log

exit
