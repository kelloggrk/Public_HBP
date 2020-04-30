#!/bin/sh

#-------------------------------------------------------------------------------
# Name:        model_cal_script.sh
# Purpose:     This file runs the matlab scripts that: calibrate the water price, 
#		drlg cost projection, number of wells, shock variance, 
#		and drilling cost addition
#
# Author:      Ryan
#
# Created:     18 April, 2020
#-------------------------------------------------------------------------------
#
# This is the descriptive portion of each script run:
# ------------------------------------------------------
# ALL MATLAB SCRIPTS CALL THE FOLLOWING SOURCE FILES EACH TIME THE MODEL
# OBJECT IS INSTANTIATED (VIA THE SUPERCLASS hbpmodel.m)
# HBP/IntermediateData/PriceDayrate/PricesAndDayrates_Quarterly.csv
# HBP/IntermediateData/PriceDayrate/PriceTransitionCoefs.csv
# HBP/IntermediateData/PriceDayrate/StateSpacePDTrans.csv (file written if ~exist)
# HBP/IntermediateData/PriceDayrate/PDTrans.csv (file written if ~exist)
# HBP/IntermediateData/StructuralEstimationData/fraction_leased.csv
# HBP/IntermediateData/StructuralEstimationData/unit_chars.csv
#
# ALL MATLAB SCRIPTS WRITE THE FOLLOWING OUTPUT FILES EACH TIME THE MODEL
# OBJECT IS INSTANTIATED (VIA THE SUPERCLASS hbpmodel.m)
# HBP/IntermediateData/CalibrationCoefs/unitestsampleinfo.csv
# HBP/IntermediateData/CalibrationCoefs/unitestsampleIDs.csv
# ------------------------------------------------------
#
# INPUTS AND OUTPUTS FOR SPECIFIC FILES, IN ADDITION TO THE ABOVE
### matlab -nosplash -wait -nodesktop -r "cd $CODEDIR; estimateP_w; exit"
#
# INPUTS:
# HBP/IntermediateData/CalibrationCoefs/cobb_douglas.csv
# HBP/IntermediateData/CalibrationCoefs/P_w.csv
# HBP/IntermediateData/CalibrationCoefs/CostCoefsProj.csv
# HBP/IntermediateData/StructuralEstimationData/CostProjectionData.csv
#
# OUTPUTS:
# HBP/IntermediateData/CalibrationCoefs/P_w_final.csv
# HBP/IntermediateData/CalibrationCoefs/CostCoefsFinal.csv
# HBP/IntermediateData/CalibrationCoefs/Profits_mean_dist.csv
# HBP/IntermediateData/CalibrationCoefs/Wellsperunit.csv
#
# ------------------------------------------------------
### matlab -nosplash -wait -nodesktop -r "cd $CODEDIR; runML; exit"
#
# INPUTS:
# HBP/IntermediateData/CalibrationCoefs/cobb_douglas.csv
# HBP/IntermediateData/CalibrationCoefs/P_w_final.csv
# HBP/IntermediateData/CalibrationCoefs/CostCoefsFinal.csv
# HBP/IntermediateData/StructuralEstimationData/CostCoefsProj.csv
# HBP/IntermediateData/StructuralEstimationData/Wellsperunit.csv
#
# OUTPUTS:
# HBP/IntermediateData/CalibrationCoefs/epsScale_final.csv
# HBP/IntermediateData/CalibrationCoefs/thetaDA_final.csv
# HBP/IntermediateData/CalibrationCoefs/runMLout.csv
# HBP/Paper/Figures/estimation/SimActDrillingVsTime.pdf
# HBP/Paper/Beamer_Figures/estimation/SimActDrillingVsTime.pdf
# HBP/Paper/Figures/estimation/SimActDrillingVsUnitProd.pdf
# HBP/Paper/Beamer_Figures/estimation/SimActDrillingVsUnitProd.pdf
#
# ------------------------------------------------------
### matlab -nosplash -wait -nodesktop -r "cd $CODEDIR; calibrationOut; exit"
#
# INPUTS:
# HBP/IntermediateData/CalibrationCoefs/unitestsampleinfo.csv
# HBP/IntermediateData/CalibrationCoefs/Wellsperunit.csv
# HBP/IntermediateData/CalibrationCoefs/AverageWater.csv
#
# OUTPUTS:
# HBP/Paper/Figures/calibration_summary.tex
# HBP/Paper/Figures/single_numbers_tex/calibration/*.tex
# ------------------------------------------------------
# The simulation model itself is held in matlab objects hbpmodel.m, 
# hbpmodelsim.m, and hbpmodelwaterest.m that are not directly called here.
#   - hbpmodel.m is the superclass used for calibration
#   - hbpmodelsim.m is a subclass used for simulating counterfactuals
#   - hbpmodelwaterest.m is a subclass used for estimating P_w
#-------------------------------------------------------

# DEFINE PATHS
if [ "$HOME" == "/Users/ericlewis" ]; then
        CODEDIR=$HOME/Documents/EconResearch2/HBP/Code/Analysis/Model
elif [ "$HOME" == "/c/Users/Ryan Kellogg" ]; then
        CODEDIR=C:/Work/HBP/Code/Analysis/Model
elif [ "$HOME" == "/c/Users/Evan" ]; then
        CODEDIR=$HOME/Economics/Research/HBP/Code/Analysis/Model
fi

# RUN MODEL
matlab -nosplash -wait -nodesktop -r "cd $CODEDIR; estimateP_w; exit"
matlab -nosplash -wait -nodesktop -r "cd $CODEDIR; runML; exit"
matlab -nosplash -wait -nodesktop -r "cd $CODEDIR; calibrationOut; exit"


# Clean up log files
rm *.log

exit
