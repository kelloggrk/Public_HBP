#!/bin/sh

#-------------------------------------------------------------------------------
# Name:        create_maps.sh
# Purpose:     This file is a script for all scripts that generate maps of units, 
#			well drilling, and production in the paper
#
# Author:      Evan and Eric
#
# Created:     
#-------------------------------------------------------------------------------
#
# This is the descriptive portion of each script run:
# ------------------------------------------------------
### RScript $CODEDIR/Maps/productivity_maps.R

# INPUTS:
# HBP/IntermediateData/Louisiana/temp/units_sf.rds

# OUTPUTS:
# HBP/Paper/Figures/unit_productivity.pdf
# HBP/Paper/Beamer_Figures/unit_mean_productivity.pdf
# HBP/Paper/Figures/unit_productivity.pdf
# HBP/Paper/Beamer_Figures/unit_mean_productivity.pdf
# ------------------------------------------------------
### RScript $CODEDIR/Maps/spatial_wellheads_lateral_units.R

# INPUTS:
# HBP/RawData/orig/Louisiana/County/la_counties.shp
# HBP/RawData/orig/Louisiana/DNR/BOTTOM_HOLE_LINE.shp
# HBP/RawData/orig/Louisiana/DNR/Haynesville_shale_units.shp
# HBP/RawData/orig/Louisiana/DNR/dnr_wells.shp

# OUTPUTS:
# HBP/Paper/Figures/haynesville_hlegs_operator_map.pdf
# ------------------------------------------------------
### RScript $CODEDIR/Maps/unit_subsampling.R

# INPUTS:
# HBP/IntermediateData/Louisiana/Wells/hay_wells_with_prod.dta")
# HBP/IntermediateData/Louisiana/DescriptiveUnits/master_unit_shapefile_urbanity.shp")
# HBP/IntermediateData/Louisiana/SubsampledUnits/unit_data_sample_flags.dta")
# HBP/RawData/orig/Louisiana/County/la_counties.shp")

# OUTPUTS:
# HBPPaper/Figures/haynesville_units_in_sample.pdf')
# HBP/Paper/Figures/well_count_in_haynesville_units.pdf')
# HBP/Paper/Beamer_Figures/well_count_in_haynesville_units.pdf')
# HBP/Paper/Figures/single_numbers_tex/unit_count_in_sample.tex')
# ------------------------------------------------------

# Variables CODEDIR, OS, and STATA exported from analysis_script.sh

RScript $CODEDIR/Maps/productivity_maps.R &&
RScript $CODEDIR/Maps/spatial_wellheads_lateral_units.R &&
RScript $CODEDIR/Maps/unit_subsampling.R

# Clean up log files
rm *.log

exit
