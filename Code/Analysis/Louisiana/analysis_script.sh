#!/bin/bash

#-------------------------------------------------------------------------------
# Name:        analysis_script.sh
# Purpose:     This file is the high-level script for creating the analysis subsample,
#		generating summary statistics, all maps of wells and units, 
#		conducting the bunching analyses, and generating inputs
#		to the computational model
#
# Author:      Ryan
#
# Created:     18 April, 2020
#-------------------------------------------------------------------------------


# DEFINE PATHS, OPERATING SYSTEM, AND STATA VERSION
if [ "$HOME" == "/Users/ericlewis" ]; then
        CODEDIR=$HOME/Documents/EconResearch2/HBP/Code/Analysis/Louisiana
   	OS="Unix"
   	STATA="SE"
elif [ "$HOME" == "/c/Users/Ryan Kellogg" ]; then
        CODEDIR=C:/Work/HBP/Code/Analysis/Louisiana
    	OS="Windows"
    	STATA="MP"
elif [ "$HOME" == "/c/Users/Evan" ]; then
        CODEDIR=$HOME/Economics/Research/HBP/Code/Analysis/Louisiana
    	OS="Windows"
    	STATA="SE"
fi


# EXPORT VARIABLES TO ANALYSIS SUB-SCRIPTS
export CODEDIR
export OS
export STATA


# RUN THE ANALYSES
$CODEDIR/Subsample/subsampling.sh |& tee subsampling_out.txt
$CODEDIR/Productivity/production_estimation.sh |& tee production_estimation_out.txt
$CODEDIR/Maps/create_maps.sh |& tee create_maps_out.txt
$CODEDIR/UnitDescriptives/descriptives_script.sh |& tee descriptives_script_out.txt
$CODEDIR/TimeSeriesAnalysis/time_series_script.sh |& tee time_series_script_out.txt
$CODEDIR/StructuralModelInputs/model_inputs.sh |& tee model_inputs_out.txt
$CODEDIR/AppendixFigures/appendix_figures.sh |& tee appendix_figures_out.txt


# CLEAN UP LOG FILES
rm *.log

exit