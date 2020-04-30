#!/bin/sh

#-------------------------------------------------------------------------------
# Name:        time_series_script.sh
# Purpose:     Runs scripts for generating the time series plot of gas
#		prices, leasing, and drilling
#
# Author:      Eric
#
# Created:     
#-------------------------------------------------------------------------------
#
# This is the descriptive portion of each script run:
# ------------------------------------------------------
### do $CODEDIR/TimeSeriesAnalysis/prep_time_series_data.do

# INPUTS:
# HBP/IntermediateData/Louisiana/SubsampledUnits/unit_data_sample_flags.dta
# HBP/IntermediateData/Louisiana/Louisiana/Leases/Clustering/clustered_at_90th_percentile_final.dta
# HBP/IntermediateData/Louisiana/DIProduction/haynesville_well_time_series.dta
# HBP/IntermediateData/Louisiana/SubsampledUnits/unit_data_with_prod.dta
# HBP/IntermediateData/Louisiana/Wells/hay_wells_with_prod.dta
# HBP/IntermediateData/Louisiana/PriceDayrate/PricesAndDayrates_Monthly.dta
#
# OUTPUTS:
# HBP/IntermediateData/Louisiana/Wells/haynesville_rig_data_for_graphing.dta
# ------------------------------------------------------
### RScript $CODEDIR/TimeSeriesAnalysis/haynesville_time_series_plot.R
# INPUTS:
# HBP/IntermediateData/Louisiana/Wells/haynesville_rig_data_for_graphing.dta
#
# OUTPUTS
# HBP/Paper/Figures/haynesville_time_series_plot.pdf
# ------------------------------------------------------

# Variables CODEDIR, OS, and STATA exported from analysis_script.sh

if [ "$OS" = "Unix" ]; then
    if [ "$STATA" = "SE" ]; then
      stata-se -e do $CODEDIR/TimeSeriesAnalysis/prep_time_series_data.do
    elif [ "$STATA" = "MP" ]; then
      stata-mp -b do $CODEDIR/TimeSeriesAnalysis/prep_time_series_data.do
    fi
elif [ "$OS" = "Windows" ]; then
    if [ "$STATA" = "SE" ]; then
      stataSE-64 -e do $CODEDIR/TimeSeriesAnalysis/prep_time_series_data.do
    elif [ "$STATA" = "MP" ]; then
      stataMP-64 -e do $CODEDIR/TimeSeriesAnalysis/prep_time_series_data.do
    fi
fi


RScript $CODEDIR/TimeSeriesAnalysis/haynesville_time_series_plot.R


# Clean up log files
rm *.log

exit
