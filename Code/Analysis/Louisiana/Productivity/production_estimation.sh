#!/bin/sh

#-------------------------------------------------------------------------------
# Name:        production_estimation.sh
# Purpose:     This file is a script for all scripts related to the 
# 			   decline curve and production function estimation
#
# Author:      Evan
#
# Created:     2/7/2020
#-------------------------------------------------------------------------------
#
# This is the descriptive portion of each script run:
# ------------------------------------------------------
### matlab -nosplash -wait -nodesktop -r "cd $CODEDIR/Productivity/; EstimateDecline; exit"
#
# INPUTS: 
# HBP/IntermediateData/Louisiana/DIProduction/time_series_4_decline_estimation.csv
#
# AUXILIARY SCRIPTS: 	
# DeclineFcn_EstD1.m
# DeclineFcn_FixD1.m
# LifetimeProd.m
#
# OUTPUTS:
# HBP/IntermediateData/Louisiana/DIProduction/disc_prod_patzek.csv
# ------------------------------------------------------
### do $$CODEDIR/Productivity/merge_discprod_to_wells.do
#
# INPUTS:
# HBP/IntermediateData/Louisiana/DIProduction/disc_prod_patzek.csv
#
# OUTPUTS:
# HBP/IntermediateData/Louisiana/Wells/hay_wells_with_prod.dta
# ------------------------------------------------------
###  RScript $CODEDIR/Productivity/productivity_estimation.R
# 
# INPUTS:
# HBP/IntermediateData/Louisiana/DescriptiveUnits/master_unit_shapefile_urbanity.shp
# HBP/IntermediateData/Louisiana/SubsampledUnits/unit_data_sample_flags.dta
# HBP/IntermediateData/Louisiana/Wells/hay_wells_with_prod.dta
# HBP/IntermediateData/Louisiana/DescriptiveUnits/haynesville_wells_x_units.dta
# HBP/IntermediateData/PriceDayrate/PricesAndDayrates_Quarterly.dta
#
# AUXILIARY SCRIPTS:
# productivity_helpers.R
#
# OUTPUTS:
# HBP/IntermediateData/Louisiana/temp/units_sf.rds
# HBP/IntermediateData/Louisiana/ImputedProductivity/imputed_unit_centroid_productivity.dta
# HBP/IntermediateData/Louisiana/ImputedProductivity/imputed_well_productivity.dta
# HBP/IntermediateData/CalibrationCoefs/P_w.csv
# HBP/IntermediateData/CalibrationCoefs/cobb_douglas.csv
#
# ------------------------------------------------------
### do CODEDIR/Productivity/merge_productivity_to_unit_data.do
# INPUTS:
# HBP/IntermediateData/Louisiana/SubsampledUnits/unit_data_sample_flags.dta
# HBP/IntermediateData/Louisiana/ImputedProductivity/imputed_unit_centroid_productivity.dta
# HBP/IntermediateData/Louisiana/SubsampledUnits/unit_data_sample_flags.dta
#
# OUTPUTS:
# HBP/IntermediateData/Louisiana/SubsampledUnits/unit_data_with_prod.dta
#
#-------------------------------------------------------

# Variables CODEDIR, OS, and STATA exported from analysis_script.sh


# decline estimation
matlab -nosplash -wait -nodesktop -r "cd $CODEDIR/Productivity/; EstimateDecline; exit"


# merges present value discounted production back into master_wells.dta
if [ "$OS" = "Unix" ]; then
    if [ "$STATA" = "SE" ]; then
      stata-se -e do $CODEDIR/Productivity/merge_discprod_to_wells.do
    elif [ "$STATA" = "MP" ]; then
      stata-mp do $CODEDIR/Productivity/merge_discprod_to_wells.do
    fi
elif [ "$OS" = "Windows" ]; then
    if [ "$STATA" = "SE" ]; then
      stataSE-64 -e do $CODEDIR/Productivity/merge_discprod_to_wells.do
    elif [ "$STATA" = "MP" ]; then
      stataMP-64 -e do $CODEDIR/Productivity/merge_discprod_to_wells.do
    fi
fi


# productivity estimation
RScript $CODEDIR/Productivity/productivity_estimation.R
 
 
# merges unit-level productivity estimation back into unit data
if [ "$OS" = "Unix" ]; then
    if [ "$STATA" = "SE" ]; then
      stata-se -e do $CODEDIR/Productivity/merge_productivity_to_unit_data.do
    elif [ "$STATA" = "MP" ]; then
      stata-mp do $CODEDIR/Productivity/merge_productivity_to_unit_data.do
    fi
elif [ "$OS" = "Windows" ]; then
    if [ "$STATA" = "SE" ]; then
      stataSE-64 -e do $CODEDIR/Productivity/merge_productivity_to_unit_data.do
    elif [ "$STATA" = "MP" ]; then
      stataMP-64 -e do $CODEDIR/Productivity/merge_productivity_to_unit_data.do
    fi
fi

# Clean up log files
rm *.log

exit