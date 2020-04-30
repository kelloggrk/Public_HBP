#!/bin/sh

#-------------------------------------------------------------------------------
# Name:        subsampling.sh
# Purpose:     This file is a script for flagging sample restrictions and generating
#		time series of well-level production data
#
# Author:      Evan, Ryan, Eric
#
# ---------------------------------------------------------------------------
#
# This is the descriptive portion of each script run:
# ------------------------------------------------------
### do $CODEDIR/Subsample/define_sample_units.do
#
# INPUTS:
# HBP/IntermediateData/Louisiana/FinalUnits/unit_data_4_descript.dta
# OUTPUTS:
# HBP/IntermediateData/Louisiana/SubsampledUnits/unit_data_sample_flags.dta
# -------------------------------------------------------
### do $CODEDIR/Subsample/units_sample_defs_to_wells.do
#
# INPUTS:
# HBP/IntermediateData/Louisiana/SubsampledUnits/unit_data_sample_flags.dta
# HBP/IntermediateData/Louisiana/Serial_Unit_xwalk_Hay_HBP.dta
# HBP/IntermediateData/Louisiana/Wells/master_wells.dta
# OUTPUTS:
# HBP/IntermediateData/Louisiana/well_unit_xwalk_master.dta
# -------------------------------------------------------
### do $CODEDIR/Subsample/create_well_timeseries.do
#
# INPUTS:
# HBP/IntermediateData/Louisiana/DIProduction/HPDIProduction.dta
# HBP/IntermediateData/Louisiana/well_unit_xwalk_master.dta.dta
# HBP/IntermediateData/Louisiana/Wells/master_wells.dta
# OUTPUTS:
# HBP/IntermediateData/Louisiana/DIProduction/haynesville_well_time_series.dta
# HBP/IntermediateData/Louisiana/DIProduction/time_series_4_decline_estimation.csv
# -------------------------------------------------------
### RScript $CODEDIR/Subsample/identify_neighboring_operators.R
#
# INPUTS:
# HBP/IntermediateData/Louisiana/DescriptiveUnits/master_unit_shapefile_urbanity.shp
# OUTPUTS:
# HBP/IntermediateData/Louisiana/DescriptiveUnits/units_with_lp2_neighbors.dta
# HBP/IntermediateData/Louisiana/DescriptiveUnits/units_with_lp7_neighbors.dta
# -------------------------------------------------------
### do $CODEDIR/Subsample/prep_neighbors.do
#
# INPUTS:
# HBP/IntermediateData/Louisiana/DescriptiveUnits/units_with_lp2_neighbors.dta
# HBP/IntermediateData/Louisiana/DescriptiveUnits/units_with_lp7_neighbors.dta
# OUTPUTS:
# HBP/IntermediateData/Louisiana/SubsampledUnits/units_with_neighbor_stats.dta
# -------------------------------------------------------

# Variables CODEDIR, OS, and STATA exported from analysis_script.sh

if [ "$OS" = "Unix" ]; then
    if [ "$STATA" = "SE" ]; then
      stata-se do $CODEDIR/Subsample/define_sample_units.do &&
      stata-se do $CODEDIR/Subsample/units_sample_defs_to_wells.do &&
      stata-se do $CODEDIR/Subsample/create_well_timeseries.do
    elif [ "$STATA" = "MP" ]; then
      stata-mp do $CODEDIR/Subsample/define_sample_units.do &&
      stata-mp do $CODEDIR/Subsample/units_sample_defs_to_wells.do &&
      stata-mp do $CODEDIR/Subsample/create_well_timeseries.do
    fi
elif [ "$OS" = "Windows" ]; then
    if [ "$STATA" = "SE" ]; then
      stataSE-64 -e do $CODEDIR/Subsample/define_sample_units.do &&
      stataSE-64 -e do $CODEDIR/Subsample/units_sample_defs_to_wells.do &&
      stataSE-64 -e do $CODEDIR/Subsample/create_well_timeseries.do
    elif [ "$STATA" = "MP" ]; then
      stataMP-64 -e do $CODEDIR/Subsample/define_sample_units.do &&
      stataMP-64 -e do $CODEDIR/Subsample/units_sample_defs_to_wells.do &&
      stataMP-64 -e do $CODEDIR/Subsample/create_well_timeseries.do
    fi
fi

# neighbor analysis -- finds operators of nearby units
RScript $CODEDIR/Subsample/identify_neighboring_operators.R

# neighboring operator counts
if [ "$OS" = "Unix" ]; then
    if [ "$STATA" = "SE" ]; then
      stata-se do $CODEDIR/Subsample/prep_neighbors.do
    elif [ "$STATA" = "MP" ]; then
      stata-mp do $CODEDIR/Subsample/prep_neighbors.do
    fi
elif [ "$OS" = "Windows" ]; then
    if [ "$STATA" = "SE" ]; then
      stataSE-64 -e do $CODEDIR/Subsample/prep_neighbors.do
    elif [ "$STATA" = "MP" ]; then
      stataMP-64 -e do $CODEDIR/Subsample/prep_neighbors.do
    fi
fi

# Clean up log files
rm *.log

exit