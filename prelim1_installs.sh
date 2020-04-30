#!/bin/sh

#-------------------------------------------------------------------------------
# Name:        prelim1_installs.sh
# Purpose:     Installs Stata and R packages
#
# Author:      Ryan
#
# Created:     16 April, 2020
#-------------------------------------------------------------------------------


if [ "$HOME" == "/Users/ericlewis" ]; then
        CODEDIR=$HOME/Documents/EconResearch2/HBP/Code
    	OS="Unix"
    	STATA="SE"
elif [ "$HOME" == "/c/Users/Ryan Kellogg" ]; then
        CODEDIR=C:/Work/HBP/Code
    	OS="Windows"
    	STATA="MP"
elif [ "$HOME" == "/c/Users/Evan" ]; then
        CODEDIR=$HOME/Documents/Economics/HBP/Code
    	OS="Windows"
    	STATA="SE"
fi

# Stata installs
if [ "$OS" = "Unix" ]; then
    if [ "$STATA" = "SE" ]; then
      stata-se -e do $CODEDIR/stata_installs.do
    elif [ "$STATA" = "MP" ]; then
      stata-mp -e do $CODEDIR/stata_installs.do
    fi
elif [ "$OS" = "Windows" ]; then
    if [ "$STATA" = "SE" ]; then
      stataSE-64 -e do $CODEDIR/stata_installs.do
    elif [ "$STATA" = "MP" ]; then
      stataMP-64 -e do $CODEDIR/stata_installs.do
    fi
fi

# R installs
Rscript -e 'install.packages(c("cluster", "cowplot", "dendextend", "feather", "foreign", "ggthemes", "gstat", "gtools", "lattice", "latticeExtra", "leafem", "lfe", "lmtest", "lubridate", "lwgeom", "magrittr", "maptools", "mapview", "pillar", "plyr", "pracma", "raster", "RColorBrewer", "readstata13", "rgdal", "rgeos", "rmapshaper", "sandwich", "sf", "smoothr", "sp", "stargazer", "tidyverse", "tiff", "viridis", "xtable"), repos = "https://cran.rstudio.com/", type = "binary")'

# Clean up log files
rm *.log

exit
