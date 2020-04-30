#!/bin/sh

#-------------------------------------------------------------------------------
# Name:        collapse_to_unit_level.sh
# Purpose:     Creates master files for wells, units and for
#		intersections of wells, leases, and units
#
# Author:      Nadia
#
# Created:     
#-------------------------------------------------------------------------------
#
# This is the descriptive portion of each script run:
# ------------------------------------------------------
### do $CODEDIR/Louisiana/Units/construct_well_data.do &&
#
# INPUTS:
# HBP/IntermediateData/Louisiana/DNR/ONG_WELL_PARISH_*.dta
# HBP/IntermediateData/Louisiana/DNR/HAYNESVILLE_SHALE_WELLS_*.dta
# HBP/IntermediateData/Louisiana/DNR/WELL_PERFS_AND_SAND_*.dta
# HBP/IntermediateData/Louisiana/DNR/Prod_header.dta
# HBP/IntermediateData/Louisiana/DNR/DICompletion.dta
# HBP/IntermediateData/Louisiana/Wells/louisiana_topholes_DNR.dta
# HBP/IntermediateData/Louisiana/Wells/well_legs_weighted_centroids.dta
# HBP/IntermediateData/Louisiana/Wells/bottomholes.dta
# HBP/IntermediateData/Louisiana/DIProduction/HPDIProduction.dta
# HBP/RawData/data/Louisiana/DNR/WellInputs/ra_frac_inputs_cleaned.dta
# HBP/RawData/data/Louisiana/DNR/WellCosts/wellcosts_data.dta
#
# OUTPUTS:
# HBP/IntermediateData/Louisiana/Wells/master_wells.dta
#
# ------------------------------------------------------
### do $CODEDIR/Louisiana/Units/clean_well_laterals_x_units.do &&
#
# INPUTS:
# HBP/IntermediateData/Louisiana/Wells/master_wells.dta
# HBP/IntermediateData/Louisiana/DescriptiveUnits/longest_legs_to_units.dta
# HBP/IntermediateData/Louisiana/DescriptiveUnits/weighted_leg_centroids_to_units.dta
# HBP/IntermediateData/Louisiana/DescriptiveUnits/bottomholes_to_units.dta
# HBP/IntermediateData/Louisiana/DescriptiveUnits/topholes_to_units.dta
#
# OUTPUTS:
# HBP/IntermediateData/Louisiana/DescriptiveUnits/haynesville_wells_x_units.dta
# HBP/IntermediateData/Louisiana/DescriptiveUnits/all_wells_x_units.dta
# ------------------------------------------------------
### do $CODEDIR/Louisiana/Units/clean_master_units.do &&
#
# INPUT:
# HBP/IntermediateData/Louisiana/DescriptiveUnits/master_units.dta
#
# OUTPUT:
# HBP/IntermediateData/Louisiana/DescriptiveUnits/cleaned_master_units.dta
# ------------------------------------------------------
### do $CODEDIR/Louisiana/Units/construct_units_4_descript.do
#
# INPUTS:
# HBP/IntermediateData/Louisiana/Leases/Clustering/clustered_at_90th_percentile_final.dta
# HBP/IntermediateData/Louisiana/DescriptiveUnits/haynesville_wells_x_units.dta
# HBP/IntermediateData/Louisiana/DescriptiveUnits/all_wells_x_units.dta
# HBP/IntermediateData/Louisiana/DescriptiveUnits/cleaned_master_units.dta
#
# OUTPUTS:
# HBP/IntermediateData/Louisiana/Leases/lease_tempfile.dta
# HBP/IntermediateData/Louisiana/Serial_Unit_xwalk_Hay_HBP.dta
# HBP/IntermediateData/FinalUnits/unit_data_4_descript.dta
#
# UTILITIES:
# $CODEDIR/Louisiana/Units/collapse_leases2units.do
# $CODEDIR/Louisiana/Units/collapse_wells2units.do
# ------------------------------------------------------

# Variables CODEDIR, OS, and STATA exported from build_script.sh

if [ "$OS" = "Unix" ]; then
    if [ "$STATA" = "SE" ]; then
      stata-se -e do $CODEDIR/Louisiana/Units/construct_well_data.do &&
      stata-se -e do $CODEDIR/Louisiana/Units/clean_well_laterals_x_units.do &&
      stata-se -e do $CODEDIR/Louisiana/Units/clean_master_units.do &&
      stata-se -e do $CODEDIR/Louisiana/Units/construct_units_4_descript.do
    elif [ "$STATA" = "MP" ]; then
      stata-mp do $CODEDIR/Louisiana/Units/construct_well_data.do &&
      stata-mp do $CODEDIR/Louisiana/Units/clean_well_laterals_x_units.do &&
      stata-mp do $CODEDIR/Louisiana/Units/clean_master_units.do &&
      stata-mp do $CODEDIR/Louisiana/Units/construct_units_4_descript.do
    fi
elif [ "$OS" = "Windows" ]; then
    if [ "$STATA" = "SE" ]; then
      stataSE-64 -e do $CODEDIR/Louisiana/Units/construct_well_data.do &&
      stataSE-64 -e do $CODEDIR/Louisiana/Units/clean_well_laterals_x_units.do &&
      stataSE-64 -e do $CODEDIR/Louisiana/Units/clean_master_units.do &&
      stataSE-64 -e do $CODEDIR/Louisiana/Units/construct_units_4_descript.do
    elif [ "$STATA" = "MP" ]; then
      stataMP-64 -e do $CODEDIR/Louisiana/Units/construct_well_data.do &&
      stataMP-64 -e do $CODEDIR/Louisiana/Units/clean_well_laterals_x_units.do &&
      stataMP-64 -e do $CODEDIR/Louisiana/Units/clean_master_units.do &&
      stataMP-64 -e do $CODEDIR/Louisiana/Units/construct_units_4_descript.do
    fi
fi


# Clean up log files
rm *.log

exit
