#!/bin/sh

#-------------------------------------------------------------------------------
# Name:        hbp_bash_file.sh
# Purpose:     Calls every file that cleans raw data from start to finish
#              and eventually compiles all latex for the paper including figures
#
# Author:      Ryan
#
# Created:     18 April, 2020
#-------------------------------------------------------------------------------


# DEFINE PATH
if [ "$HOME" = "/Users/ericlewis" ]; then
        CODEDIR=$HOME/Documents/EconResearch2/HBP
elif [ "$HOME" = "/c/Users/Ryan Kellogg" ]; then
        CODEDIR=C:/Work/HBP
elif [ "$HOME" = "/c/Users/Evan" ]; then
        CODEDIR=$HOME/Economics/Research/HBP
fi

# PRELIMINARIES: STATA AND R INSTALLS; CLEAR OUTPUT FOLDERS
bash -x $CODEDIR/prelim1_installs.sh |& tee prelim1_installs_out.txt
bash -x $CODEDIR/prelim2_folders.sh |& tee prelim2_folders_out.txt

# RUN THE BUILD
bash -x $CODEDIR/Code/Build/build_script.sh |& tee build_script_out.txt

# RUN THE ANALYSIS SAMPLE SCRIPTS
bash -x $CODEDIR/Code/Analysis/Louisiana/analysis_script.sh |& tee analysis_script_out.txt

# RUN THE COMPUTATIONAL MODEL CALIBRATION AND SIMULATION SCRIPTS
bash -x $CODEDIR/Code/Analysis/Model/model_cal_script.sh |& tee model_cal_script_out.txt
bash -x $CODEDIR/Code/Analysis/Model/model_sim_script.sh |& tee model_sim_script_out.txt

# COMPILE THE PAPER
bash -x $CODEDIR/Paper/paper_script.sh |& tee paper_script_out.txt

#clean up log files
rm *.log

exit
