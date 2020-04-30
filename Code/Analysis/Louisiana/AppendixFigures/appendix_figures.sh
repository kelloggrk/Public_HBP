#!/bin/sh

#-------------------------------------------------------------------------------
# Name:        apendix_figures.sh
# Purpose:     Runs scripts for bunching estimates
#
# Author:      Evan and Eric
#
# Created:     
#-------------------------------------------------------------------------------
#
# This is the descriptive portion of each script run:
# ------------------------------------------------------
### do $CODEDIR/AppendixFigures/examining_missing_area.do
#
# INPUTS:
# HBP/IntermediateData/Louisiana/Leases/louisiana_leases_DI_csvs.dta
#
# OUTPUTS:
# HBP/Paper/Figures/missing_lease_area.pdf
# HBP/Paper/Beamer_Figures/missing_lease_area.pdf
# ------------------------------------------------------
### do $CODEDIR/AppendixFigures/bunching_deadlines_estimate.do
#
# INPUTS:
# HBP/IntermediateData/Louisiana/SubsampledUnits/unit_data_with_prod.dta
#
# OUTPUTS:
# HBP/Paper/Figures/section_descript/drill_bunching_allsections.pdf
# HBP/Paper/Beamer_Figures/section_descript/drill_bunching_allsections.pdf
# HBP/Paper/Figures/section_descript/drill_bunching_regression.tex
# ------------------------------------------------------

# Variables CODEDIR, OS, and STATA exported from analysis_script.sh

# Missing lease area analysis as well as bunching analysis:
if [ "$OS" = "Unix" ]; then
    if [ "$STATA" = "SE" ]; then
      stata-se -e do $CODEDIR/AppendixFigures/examining_missing_area.do &&
      stata-se -e do $CODEDIR/AppendixFigures/bunching_deadlines_estimate.do
    elif [ "$STATA" = "MP" ]; then
      stata-mp -b do $CODEDIR/AppendixFigures/examining_missing_area.do &&
      stata-mp -b do $CODEDIR/AppendixFigures/bunching_deadlines_estimate.do
    fi
elif [ "$OS" = "Windows" ]; then
    if [ "$STATA" = "SE" ]; then
      stataSE-64 -e do $CODEDIR/AppendixFigures/examining_missing_area.do &&
      stataSE-64 -e do $CODEDIR/AppendixFigures/bunching_deadlines_estimate.do
    elif [ "$STATA" = "MP" ]; then
      stataMP-64 -e do $CODEDIR/AppendixFigures/examining_missing_area.do &&
      stataMP-64 -e do $CODEDIR/AppendixFigures/bunching_deadlines_estimate.do
    fi
fi


# Clean up log files
rm *.log

exit