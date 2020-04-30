#!/bin/sh

#-------------------------------------------------------------------------------
# Name:        descriptives_script.sh
# Purpose:     Runs scripts for computing summary statistics and running the
#		bunching analyses. Outputs pdf figures, tex tables, and
#		tex single number files
#
# Author:      Nadia
#
# Created:     10/12/2017
#-------------------------------------------------------------------------------
#
# This is the descriptive portion of each script run:
# ------------------------------------------------------
### do $CODEDIR/UnitDescriptives/descriptive_unit_level.do
#
# INPUTS:
# HBP/IntermediateData/Louisiana/SubsampledUnits/unit_data_with_prod.dta
#
# OUTPUTS: large number of figures and tex files for the data and
#		bunching sections of the paper
# HBP/Paper/Figures/section_descript/*.pdf
# HBP/Paper/Beamer_Figures/section_descript/*.pdf
# HBP/Paper/Figures/single_numbers_tex/*.tex
# ------------------------------------------------------
### do $CODEDIR/UnitDescriptives/lease_summary_statistics.do
#
# INPUTS:
# HBP/IntermediateData/Louisiana/SubsampledUnits/unit_data_with_prod.dta
# HBP/IntermediateData/Louisiana/Leases/Clustering/clustered_at_90th_percentile_final.dta
#
# OUTPUTS:
# HBP/Paper/Figures/lease_descript/descript_table_lease.tex
# HBP/Paper/Figures/single_numbers_tex/*.tex
# ------------------------------------------------------
### do $CODEDIR/UnitDescriptives/price_dayrate_descriptive.do
#
# INPUTS:
# HBP/IntermediateData/PriceDayrate/PricesAndDayrates_Monthly.dta
#
# OUTPUTS:
# HBP/Paper/Figures/single_numbers_tex/*.tex
# ------------------------------------------------------
### do $CODEDIR/UnitDescriptives/well_descriptives.do
#
# INPUTS:
# HBP/IntermediateData/Louisiana/wells/hay_wells_with_prod.dta
#
# OUTPUTS:
# HBP/Paper/Figures/well_descript/descript_table_wells.tex
# HBP/Paper/Figures/single_numbers_tex/*.tex
# ------------------------------------------------------

# Variables CODEDIR, OS, and STATA exported from analysis_script.sh

if [ "$OS" = "Unix" ]; then
    if [ "$STATA" = "SE" ]; then
      stata-se -e do $CODEDIR/UnitDescriptives/descriptive_unit_level.do &&
      stata-se -e do $CODEDIR/UnitDescriptives/lease_summary_statistics.do
      stata-se -b do $CODEDIR/UnitDescriptives/price_dayrate_descriptive.do &&
      stata-se -b do $CODEDIR/UnitDescriptives/well_descriptives.do
    elif [ "$STATA" = "MP" ]; then
      stata-mp -b do $CODEDIR/UnitDescriptives/descriptive_unit_level.do &&
      stata-mp -b do $CODEDIR/UnitDescriptives/lease_summary_statistics.do
      stata-mp -b do $CODEDIR/UnitDescriptives/price_dayrate_descriptive.do &&
      stata-mp -b do $CODEDIR/UnitDescriptives/well_descriptives.do
    fi
elif [ "$OS" = "Windows" ]; then
    if [ "$STATA" = "SE" ]; then
      stataSE-64 -e do $CODEDIR/UnitDescriptives/descriptive_unit_level.do &&
      stataSE-64 -e do $CODEDIR/UnitDescriptives/lease_summary_statistics.do &&
      stataSE-64 -e do $CODEDIR/UnitDescriptives/price_dayrate_descriptive.do &&
      stataSE-64 -e do $CODEDIR/UnitDescriptives/well_descriptives.do
    elif [ "$STATA" = "MP" ]; then
      stataMP-64 -e do $CODEDIR/UnitDescriptives/descriptive_unit_level.do &&
      stataMP-64 -e do $CODEDIR/UnitDescriptives/lease_summary_statistics.do &&
      stataMP-64 -e do $CODEDIR/UnitDescriptives/price_dayrate_descriptive.do &&
      stataMP-64 -e do $CODEDIR/UnitDescriptives/well_descriptives.do
    fi
fi


# Clean up log files
rm *.log

exit
