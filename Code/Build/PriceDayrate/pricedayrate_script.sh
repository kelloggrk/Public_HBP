#!/bin/sh

#-------------------------------------------------------------------------------
# Name:        pricedayrate_script.sh
# Purpose:     This file is a script for initial cleaning of raw
#              data files for gas prices and dayrates used in this project
#
# Author:      Nadia
#
# Created:     
#-------------------------------------------------------------------------------
#
# This is the descriptive portion of each script run:
# ------------------------------------------------------
### do $CODEDIR/PriceDayrate/LoadCPI.do
#
# INPUT:
# HBP/RawData/orig/PriceDayrate/SeriesReport-20180708172351_d2a36c.xlsx
#
# OUTPUT:
# HBP/RawData/data/PriceDayrate/CPI.dta
# ------------------------------------------------------
### do $CODEDIR/PriceDayrate/LoadDayrates.do
#
# INPUTS:
# HBP/RawData/orig/PriceDayrate/RigDayrates.xlsx
# HBP/RawData/orig/PriceDayrate/Ryan Kellogg Chicago U custom day rates.xlsx
#
# OUTPUT:
# HBP/RawData/data/PriceDayrate/RigDayrates.dta
# ------------------------------------------------------
### do $CODEDIR/PriceDayrate/LoadFutures.do
#
# INPUT:
# HBP/RawData/orig/bbg_cl_ng.xlsx
#
# OUPUTS:
# HBP/RawData/data/PriceDayrate/Futures_*.dta
# ------------------------------------------------------
### do $CODEDIR/PriceDayrate/LoadSpot.do
#
# INPUT:
# HBP/RawData/orig/EIA/NG_PRI_FUT_S1_M.xls (Data 1 sheet)
#
# OUTPUT:
# HBP/RawData/data/PriceDayrate/HHSpotPrices.dta
# ------------------------------------------------------
### do $CODEDIR/PriceDayrate/MergePriceDayrate.do
#
# INPUTS:
# HBP/RawData/data/PriceDayrate/CPI.dta
# HBP/RawData/data/PriceDayrate/RigDayrates.dta
# HBP/RawData/data/PriceDayrate/Futures_*.dta
# HBP/RawData/data/PriceDayrate/HHSpotPrices.dta
#
# OUTPUTS:
# HBP/IntermediateData/PriceDayrate/PricesAndDayrates_Monthly.dta
# HBP/IntermediateData/PriceDayrate/PricesAndDayrates_Quarterly.dta
# HBP/IntermediateData/PriceDayrate/PricesAndDayrates_Quarterly.csv
# ------------------------------------------------------
### stata-mp do $CODEDIR/PriceDayrate/PriceDayrateTransitions.do
#
# INPUT:
# HBP/IntermediateData/PriceDayrate/PricesAndDayrates_Quarterly.dta
#
# OUTPUT:
# HBP/IntermediateData/PriceDayrate/PriceTransitionCoefs.csv
# HBP/Paper/Figures/single_numbers_tex/long_run_mean_gas.tex
# HBP/Paper/Figures/single_numbers_tex/long_run_mean_dayrate.tex
#
# ------------------------------------------------------

# Variables CODEDIR, OS, and STATA exported from build_script.sh

if [ "$OS" = "Unix" ]; then
    if [ "$STATA" = "SE" ]; then
      stata-se -e do $CODEDIR/PriceDayrate/LoadCPI.do &&
      stata-se -e do $CODEDIR/PriceDayrate/LoadDayrates.do &&
      stata-se -e do $CODEDIR/PriceDayrate/LoadFutures.do &&
      stata-se -e do $CODEDIR/PriceDayrate/LoadSpot.do &&
      stata-se -e do $CODEDIR/PriceDayrate/MergePriceDayrate.do &&
      stata-se -e do $CODEDIR/PriceDayrate/PriceDayrateTransitions.do
    elif [ "$STATA" = "MP" ]; then
      stata-mp do $CODEDIR/PriceDayrate/LoadCPI.do &&
      stata-mp do $CODEDIR/PriceDayrate/LoadDayrates.do &&
      stata-mp do $CODEDIR/PriceDayrate/LoadFutures.do &&
      stata-mp do $CODEDIR/PriceDayrate/LoadSpot.do &&
      stata-mp do $CODEDIR/PriceDayrate/MergePriceDayrate.do &&
      stata-mp do $CODEDIR/PriceDayrate/PriceDayrateTransitions.do
    fi
elif [ "$OS" = "Windows" ]; then
    if [ "$STATA" = "SE" ]; then
      stataSE-64 -e do $CODEDIR/PriceDayrate/LoadCPI.do &&
      stataSE-64 -e do $CODEDIR/PriceDayrate/LoadDayrates.do &&
      stataSE-64 -e do $CODEDIR/PriceDayrate/LoadFutures.do &&
      stataSE-64 -e do $CODEDIR/PriceDayrate/LoadSpot.do &&
      stataSE-64 -e do $CODEDIR/PriceDayrate/MergePriceDayrate.do &&
      stataSE-64 -e do $CODEDIR/PriceDayrate/PriceDayrateTransitions.do
    elif [ "$STATA" = "MP" ]; then
      stataMP-64 -e do $CODEDIR/PriceDayrate/LoadCPI.do &&
      stataMP-64 -e do $CODEDIR/PriceDayrate/LoadDayrates.do &&
      stataMP-64 -e do $CODEDIR/PriceDayrate/LoadFutures.do &&
      stataMP-64 -e do $CODEDIR/PriceDayrate/LoadSpot.do &&
      stataMP-64 -e do $CODEDIR/PriceDayrate/MergePriceDayrate.do &&
      stataMP-64 -e do $CODEDIR/PriceDayrate/PriceDayrateTransitions.do
    fi
fi

# Clean up log files
rm *.log

exit
