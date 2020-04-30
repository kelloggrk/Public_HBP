#!/bin/sh

#-------------------------------------------------------------------------------
# Name:        model_inputs.sh
# Purpose:     Runs scripts for generating inputs for the structural model
#
# Author:      Evan
#
# Created:     
#-------------------------------------------------------------------------------
#
# This is the descriptive portion of each script run:
# ------------------------------------------------------
### do $CODEDIR/StructuralModelInputs/drill_costs_projection.do
#
# INPUTS:
# HBP/IntermediateData/CalibrationCoefs/P_w.csv
# HBP/IntermediateData/PriceDayrate/PricesAndDayrates_Monthly.dta
# HBP/IntermediateData/Louisana/Wells/hay_wells_with_prod.dta
# HBP/IntermediateData/Louisiana/ImputedProductivity/imputed_well_productivity.dta
#
# OUTPUTS:
# HBP/IntermediateData/CalibrationCoefs/CostCoefsProj.csv
# HBP/IntermediateData/StructuralEstimationData/CostProjectionData.csv
# ------------------------------------------------------
### do $CODEDIR/StructuralModelInputs/unit_data_for_calibration.do
#
# INPUTS:
# HBP/IntermediateData/Louisiana/SubsampledUnits/unit_data_with_prod.dta
#
# OUTPUTS:
# HBP/IntermediateData/StructuralEstimationData/unit_chars.csv
# HBP/IntermediateData/StructuralEstimationData/fraction_leased.csv"
# ------------------------------------------------------

# Variables CODEDIR, OS, and STATA exported from analysis_script.sh

if [ "$OS" = "Unix" ]; then
    if [ "$STATA" = "SE" ]; then
       stata-se -e do $CODEDIR/StructuralModelInputs/drill_costs_projection.do &&
       stata-se -e do $CODEDIR/StructuralModelInputs/unit_data_for_calibration.do
    elif [ "$STATA" = "MP" ]; then
       stata-mp -b do $CODEDIR/StructuralModelInputs/drill_costs_projection.do &&
       stata-mp -b do $CODEDIR/StructuralModelInputs/unit_data_for_calibration.do
    fi
elif [ "$OS" = "Windows" ]; then
    if [ "$STATA" = "SE" ]; then
       stataSE-64 -e do $CODEDIR/StructuralModelInputs/drill_costs_projection.do &&
       stataSE-64 -e do $CODEDIR/StructuralModelInputs/unit_data_for_calibration.do
    elif [ "$STATA" = "MP" ]; then
       stataMP-64 -e do $CODEDIR/StructuralModelInputs/drill_costs_projection.do &&
       stataMP-64 -e do $CODEDIR/StructuralModelInputs/unit_data_for_calibration.do
    fi
fi

# Clean up log files
rm *.log

exit