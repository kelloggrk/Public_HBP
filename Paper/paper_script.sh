#!/bin/sh

#-------------------------------------------------------------------------------
# Name:        paper_script.sh
# Purpose:     Compiles the pdf of the paper
#
# Author:      Ryan
#
# Created:     18 April, 2020
#-------------------------------------------------------------------------------


# DEFINE PATH
if [ "$HOME" = "/Users/ericlewis" ]; then
        CODEDIR=$HOME/Documents/EconResearch2/HBP/Paper/Tex
elif [ "$HOME" = "/c/Users/Ryan Kellogg" ]; then
        CODEDIR=C:/Work/HBP/Paper/Tex
elif [ "$HOME" = "/c/Users/Evan" ]; then
        CODEDIR=$HOME/Economics/Research/HBP/Paper/Tex
fi


# COMPILE PAPER
cd $CODEDIR
pdflatex -output-directory=$CODEDIR HKL_primaryterms.tex
bibtex HKL_primaryterms
pdflatex -output-directory=$CODEDIR HKL_primaryterms.tex
pdflatex -output-directory=$CODEDIR HKL_primaryterms.tex
pdflatex -output-directory=$CODEDIR HKL_primaryterms.tex


#clean up log files
rm *.log

exit
