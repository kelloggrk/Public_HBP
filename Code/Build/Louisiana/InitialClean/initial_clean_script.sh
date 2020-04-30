#!/bin/sh

#-------------------------------------------------------------------------------
# Name:        initial_clean.sh
# Purpose:     This file is a script for initial cleaning of raw
#              data files for wells, units, and leases used in this project
#
# Author:      Nadia
#
# Created:     10/12/2017
#-------------------------------------------------------------------------------
#
# This is the descriptive portion of each script run:
# ------------------------------------------------------
### do $CODEDIR/Louisiana/InitialClean/read_in_haynesville_gis_dbfs.do
#
# INPUTS:
# HBP/RawData/orig/Louisiana/DI/LA-Completion-190000101-20151231.shp
# HBP/RawData/orig/Louisiana/DI/LA-Well-190000101-20151231.shp
# HBP/RawData/orig/Louisiana/DNR/Haynesville_shale_units.shp
# HBP/RawData/orig/Louisiana/DNR/dnr_wells.shp
# HBP/RawData/orig/Louisiana/DNR/BOTTOM_HOLE.shp
# HBP/RawData/orig/Louisiana/DNR/BOTTOM_HOLE_LINE.shp
#
# OUTPUTS:
# HBP/IntermediateData/Louisiana/Wells/louisiana_completions_DI.dta
# HBP/IntermediateData/Louisiana/Wells/louisiana_wells_DI.dta
# HBP/IntermediateData/Louisiana/Units/haynesville_units_DNR.dta
# HBP/IntermediateData/Louisiana/Wells/louisiana_topholes_DNR.dta
# HBP/IntermediateData/Louisiana/Wells/louisiana_bottomholes_DNR.dta
# HBP/IntermediateData/Louisiana/Wells/louisiana_legs_DNR.dta
# ------------------------------------------------------
### do $CODEDIR/Louisiana/InitialClean/read_in_haynesville_lease_csvs.do
#
# INPUTS:
# HBP/RawData/orig/Louisiana/DI/Louisiana_leases_csv/*.csv
#
# OUTPUT:
# HBP/IntermediateData/Louisiana/Leases/louisiana_leases_DI_csvs.dta
# ------------------------------------------------------
### do $CODEDIR/Louisiana/InitialClean/clean_production_data.do
#
# INPUTS:
# HBP/RawData/orig/Louisaian/DI/ProductionData/HPDIProduction.csv
#
# OUTPUT:
# HBP/IntermediateData/Louisiana/DIProduction/HPDIProduction.dta
# ------------------------------------------------------
### do $CODEDIR/Louisiana/InitialClean/clean_DI_completion_production_data.do
#
# INPUTS:
# HBP/IntermediateData/Louisiana/Wells/louisiana_completions_DI.dta
# HBP/RawData/orig/Louisana/DI/ProductionData/HPDIHeader.csv
#
# OUTPUTS:
# HBP/IntermediateData/Louisiana/DNR/DICompletion.dta
# HBP/IntermediateData/Louisiana/DNR/HPDIAPINos.dta
# HBP/IntermediateData/Louisiana/DNR/Prod_header.dta
# ------------------------------------------------------
### do $CODEDIR/Louisiana/InitialClean/clean_well_csvs.do
#
# INPUTS:
# HBP/RawData/orig/Louisiana/DNR/*.csv
#
# OUTPUTS:
# HBP/IntermediateData/Louisiana/DNR/*.dta
#
# ------------------------------------------------------
### do $CODEDIR/Louisiana/InitialClean/Haynesville_well_costs_merge.do
#
# INPUTS:
# HBP/RawData/orig/Louisiana/DNR/WellCosts/lucas_wellcosts_data.xlsx
# HBP/RawData/orig/Louisiana/DNR/WellCosts/welllist_for_cost_input.csv
# HBP/RawData/orig/Louisiana/DNR/WellCosts/patterson_wellcosts_data.xlsx
#
# OUTPUTS:
# HBP/RawData/data/Louisiana/DNR/WellCosts/wellcosts_data.dta
#
# ------------------------------------------------------
### do $CODEDIR/Louisiana/InitialClean/consolidate_grant_pengyu_welldata.do
#
# INPUTS:
# HBP/RawData/orig/Louisiana/DNR/WellInputs/GrantWellData.xlsx
# HBP/RawData/orig/Louisiana/DNR/WellInputs/GrantWellData2.xlsx
# HBP/RawData/orig/Louisiana/DNR/WellInputs/PengyuWellData.csv
# HBP/RawData/orig/Louisiana/DNR/WellInputs/PengyuWellData2.csv
#
# OUTPUTS:
# HBP/RawData/data/Louisiana/DNR/WellInputs/GrantPengyuFracInputs.dta
#
# ------------------------------------------------------
### do $CODEDIR/Louisiana/InitialClean/haynesville_well_inputs_merge.do
#
# INPUTS:
# HBP/RawData/data/Louisiana/DNR/WellInputs/GrantPengyuFracInputs.dta
# HBP/RawData/orig/Louisiana/DNR/WellInputs/patterson_well_completion_data.csv
#
# OUTPUTS:
# HBP/RawData/data/Louisiana/DNR/WellInputs/ra_frac_inputs_cleaned.dta
#-------------------------------------------------------

# Variables CODEDIR, OS, and STATA exported from build_script.sh

if [ "$OS" = "Unix" ]; then
    if [ "$STATA" = "SE" ]; then
      stata-se -e do $CODEDIR/Louisiana/InitialClean/read_in_haynesville_gis_dbfs.do &&
      stata-se -e do $CODEDIR/Louisiana/InitialClean/read_in_haynesville_lease_csvs.do &&
      stata-se -e do $CODEDIR/Louisiana/InitialClean/clean_production_data.do &&
      stata-se -e do $CODEDIR/Louisiana/InitialClean/clean_DI_completion_production_data.do &&
      stata-se -e do $CODEDIR/Louisiana/InitialClean/clean_well_csvs.do &&
      stata-se -e do $CODEDIR/Louisiana/InitialClean/Haynesville_well_costs_merge.do &&
      stata-se -e do $CODEDIR/Louisiana/InitialClean/consolidate_grant_pengyu_welldata.do &&
      stata-se -e do $CODEDIR/Louisiana/InitialClean/haynesville_well_inputs_merge.do 
    elif [ "$STATA" = "MP" ]; then
      stata-mp do $CODEDIR/Louisiana/InitialClean/read_in_haynesville_gis_dbfs.do &&
      stata-mp do $CODEDIR/Louisiana/InitialClean/read_in_haynesville_lease_csvs.do &&
      stata-mp do $CODEDIR/Louisiana/InitialClean/clean_production_data.do &&
      stata-mp do $CODEDIR/Louisiana/InitialClean/clean_DI_completion_production_data.do &&
      stata-mp do $CODEDIR/Louisiana/InitialClean/clean_well_csvs.do &&
      stata-mp do $CODEDIR/Louisiana/InitialClean/Haynesville_well_costs_merge.do &&
      stata-mp do $CODEDIR/Louisiana/InitialClean/consolidate_grant_pengyu_welldata.do &&
      stata-mp do $CODEDIR/Louisiana/InitialClean/haynesville_well_inputs_merge.do 
    fi
elif [ "$OS" = "Windows" ]; then
    if [ "$STATA" = "SE" ]; then
      stataSE-64 -e do $CODEDIR/Louisiana/InitialClean/read_in_haynesville_gis_dbfs.do &&
      stataSE-64 -e do $CODEDIR/Louisiana/InitialClean/read_in_haynesville_lease_csvs.do &&
      stataSE-64 -e do $CODEDIR/Louisiana/InitialClean/clean_production_data.do &&
      stataSE-64 -e do $CODEDIR/Louisiana/InitialClean/clean_DI_completion_production_data.do &&
      stataSE-64 -e do $CODEDIR/Louisiana/InitialClean/clean_well_csvs.do &&
      stataSE-64 -e do $CODEDIR/Louisiana/InitialClean/Haynesville_well_costs_merge.do &&
      stataSE-64 -e do $CODEDIR/Louisiana/InitialClean/consolidate_grant_pengyu_welldata.do &&
      stataSE-64 -e do $CODEDIR/Louisiana/InitialClean/haynesville_well_inputs_merge.do 
    elif [ "$STATA" = "MP" ]; then    
      stataMP-64 -e do $CODEDIR/Louisiana/InitialClean/read_in_haynesville_gis_dbfs.do &&
      stataMP-64 -e do $CODEDIR/Louisiana/InitialClean/read_in_haynesville_lease_csvs.do &&
      stataMP-64 -e do $CODEDIR/Louisiana/InitialClean/clean_production_data.do &&
      stataMP-64 -e do $CODEDIR/Louisiana/InitialClean/clean_DI_completion_production_data.do &&
      stataMP-64 -e do $CODEDIR/Louisiana/InitialClean/clean_well_csvs.do &&
      stataMP-64 -e do $CODEDIR/Louisiana/InitialClean/Haynesville_well_costs_merge.do &&
      stataMP-64 -e do $CODEDIR/Louisiana/InitialClean/consolidate_grant_pengyu_welldata.do &&
      stataMP-64 -e do $CODEDIR/Louisiana/InitialClean/haynesville_well_inputs_merge.do 
    fi
fi

# Clean up log files
rm *.log

exit
