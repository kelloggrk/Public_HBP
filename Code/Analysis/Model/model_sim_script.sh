#!/bin/sh

#-------------------------------------------------------------------------------
# Name:        model_sim_script.sh
# Purpose:     This file runs the matlab scripts that find the optimal 
#		royalty-pri term combo, and run all counterfactual simulations
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
### matlab -nosplash -wait -nodesktop -r "cd $CODEDIR; optroypriterm; exit"
#
# INPUTS:
# HBP/IntermediateData/CalibrationCoefs/cobb_douglas.csv
# HBP/IntermediateData/CalibrationCoefs/P_w_final.csv
# HBP/IntermediateData/CalibrationCoefs/CostCoefsFinal.csv
# HBP/IntermediateData/CalibrationCoefs/thetaDA_final.csv
# HBP/IntermediateData/IntermediateData/CalibrationCoefs/epsScale_final.csv
#
# OUTPUTS:
# HBP/IntermediateData/SimResults/optroyaltypriterm.csv
# HBP/IntermediateData/SimResults/optroyaltypriterm_sensitivity.csv
#
# ------------------------------------------------------
### varPriTerm.m, varyLC.m, varyRoyalty.m, varyRent.m, varyPriTerm_multwells.m
# all use same INPUTS:
# HBP/IntermediateData/CalibrationCoefs/cobb_douglas.csv
# HBP/IntermediateData/CalibrationCoefs/P_w_final.csv
# HBP/IntermediateData/CalibrationCoefs/CostCoefsFinal.csv
# HBP/IntermediateData/CalibrationCoefs/thetaDA_final.csv
# HBP/IntermediateData/IntermediateData/CalibrationCoefs/epsScale_final.csv
# HBP/IntermediateData/SimResults/optroyaltypriterm.csv
#
# varyPriTerm_multwells additionally uses:
# HBP/IntermediateData/StructuralEstimationData/Wellsperunit.csv
#
# OUTPUTS are figures sent to HBP/Paper/Figures/simulations/ and to
# HBP/Paper/Beamer_Figures/simulations/, csvs of main results sent to
# HBP/Paper/Figures/simulations/,
# and Matlab workspaces sent to HBP/IntermediateData/SimResults/
#
# ------------------------------------------------------
### resultsOut.m
#
# INPUTS: csvs of main results output in HBP/Paper/Figures/simulations/
# HBP/IntermediateData/IntermediateData/CalibrationCoefs/epsScale_final.csv
# HBP/IntermediateData/SimResults/optroyaltypriterm.csv
# HBP/IntermediateData/SimResults/optroyaltypriterm_sensitivity.csv
# HBP/IntermediateData/SimResults/var*.csv
#
# OUTPUTS: 
# HBP/IntermediateData/SimResults/sensitivitytable.tex
# single number .tex files to HBP/Paper/Figures/single_numbers_tex/simresults/*.tex
#
# ------------------------------------------------------
### RScript $CODEDIR/map_sample_units.R
#
# INPUTS:
# HBP/IntermediateData/CalibrationCoefs/unitestsampleIDs.csv
# HBP/IntermediateData/Louisiana/DescriptiveUnits/master_unit_shapefile_urbanity.shp
#
# OUTPUTS:
# HBP/Paper/Figures/final_estimation_sample_unit_map.pdf
#-------------------------------------------------------
# The simulation model itself is held in matlab objects hbpmodel.m, 
# hbpmodelsim.m, and hbpmodelwaterest.m that are not directly called here.
#   - hbpmodel.m is the superclass used for calibration
#   - hbpmodelsim.m is a subclass used for simulating counterfactuals
#   - hbpmodelwaterest.m is a subclass used for estimating P_w
# simsetup.m is a utility program used to instantiate all counterfacual simulations
# testloop.m is a high-level utility program to quickly run specific model cases
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
matlab -nosplash -wait -nodesktop -r "cd $CODEDIR; optroypriterm; exit"
matlab -nosplash -wait -nodesktop -r "cd $CODEDIR; varyPriTerm; exit"
matlab -nosplash -wait -nodesktop -r "cd $CODEDIR; varyLC; exit"
matlab -nosplash -wait -nodesktop -r "cd $CODEDIR; varyRoyalty; exit"
matlab -nosplash -wait -nodesktop -r "cd $CODEDIR; varyPriTerm_multwells; exit"
matlab -nosplash -wait -nodesktop -r "cd $CODEDIR; resultsOut; exit"
RScript $CODEDIR/map_sample_units.R &&

# Clean up log files
rm *.log

exit
