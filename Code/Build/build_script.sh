#!/bin/sh

#-------------------------------------------------------------------------------
# Name:        build_script.sh
# Purpose:     This file is the high-level script for running the full dataset build
#		It calls five sub-scripts, each in its own subfolder of /Build/
#
#		Loads, cleans, and merges data in Dropbox/HBP/RawData/orig, saving
#		output to Dropbox/HBP/IntermediateData
#
# Author:      Ryan
#
# Created:     18 April, 2020
#-------------------------------------------------------------------------------


# DEFINE PATHS, OPERATING SYSTEM, AND STATA VERSION
if [ "$HOME" == "/Users/ericlewis" ]; then
        CODEDIR=$HOME/Documents/EconResearch2/HBP/Code/Build
    	OS="Unix"
    	STATA="SE"
elif [ "$HOME" == "/c/Users/Ryan Kellogg" ]; then
        CODEDIR=C:/Work/HBP/Code/Build
    	OS="Windows"
    	STATA="MP"
elif [ "$HOME" == "/c/Users/Evan" ]; then
        CODEDIR=$HOME/Economics/Research/HBP/Code/Build
    	OS="Windows"
    	STATA="SE"
fi


# EXPORT VARIABLES TO BUILD SUB-SCRIPTS
export CODEDIR
export OS
export STATA


# RUN THE BUILD
bash -x $CODEDIR/Louisiana/InitialClean/initial_clean_script.sh |& tee initial_clean_script_out.txt
bash -x $CODEDIR/PriceDayrate/pricedayrate_script.sh |& tee price_dayrate_script_out.txt
bash -x $CODEDIR/Louisiana/Spatial/initial_spatial_clean.sh |& tee initial_spatial_clean_out.txt
bash -x $CODEDIR/Louisiana/downweighting_leases/clustering_script.sh |& tee clustering_script_out.txt
bash -x $CODEDIR/Louisiana/Units/collapse_to_unit_level.sh |& tee collapse_to_unit_level_out.txt


# CLEAN UP LOG FILES
rm *.log

exit