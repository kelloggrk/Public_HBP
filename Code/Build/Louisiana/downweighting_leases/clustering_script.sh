#!/bin/bash

#-------------------------------------------------------------------------------
# Name:        clustering_script.sh
# Purpose:     Calls every aspect of the clustering algorithm
#		Caution: takes roughly half a day to run
#		Workhorse script is calibrating_dendrogram_height.R
#
# Author:      Nadia
#
# Created:     04/06/2018
#-------------------------------------------------------------------------------
#
# This is the descriptive portion of each script run:
# ------------------------------------------------------
### do $CODEDIR/Louisiana/downweighting_leases/clean_lease_csv_dta.do
#
# INPUT:
# HBP/IntermediateData/Louisiana/Leases/louisiana_leases_DI_csvs.dta
#
# OUTPUT:
# HBP/IntermediateData/Louisiana/Leases/louisiana_leases_DI_csvs_cleaned.dta
# ------------------------------------------------------
### do $CODEDIR/Louisiana/downweighting_leases/area_downweighting.do
#
# INPUTS:
# HBP/IntermediateData/Louisiana/Leases/louisiana_leases_DI_csvs_cleaned.dta
# HBP/IntermediateData/Louisiana/DescriptiveUnits/master_units.dta
#
# OUTPUT:
# HBP/IntermediateData/Louisiana/Leases/louisiana_leases_csvs_preliminary_downweight.dta
# ------------------------------------------------------
### Rscript $CODEDIR/Louisiana/downweighting_leases/cleaning_duplicate_leases_for_stringmatch.R
#
# INPUT:
# HBP/IntermediateData/Louisiana/Leases/louisiana_leases_csvs_preliminary_downweight.dta
#
# OUTPUTS: .feather files for low-storage transfer between R and Python
# 	These files are stored in a .gitignored part of the repo
# HBP/ClusteringData/louisiana_leases_DI_csvs_for_clustering.feather
# HBP/ClusteringData/Feathered_sectionlevel_dfs/feathered_df_*.feather
# ------------------------------------------------------
### python(3) $CODEDIR/Louisiana/downweighting_leases/string_dissim.py
#
# INPUTS:
# HBP/ClusteringData/Feathered_sectionlevel_dfs/feathered_df_*.feather
#
# OUTPUTS:
# HBP/ClusteringData/Feathered_stringmatched_sectionlevel_dfs/feathered_df_*_stringmatched.feather
# ------------------------------------------------------
### Rscript $CODEDIR/Louisiana/downweighing_leases/calibrating_dendrogram_height.R
#
# INPUTS:
# HBP/ClusteringData/louisiana_leases_DI_csvs_for_clustering.feather
# HBP/ClusteringData/Feathered_stringmatched_sectionlevel_dfs/feathered_df_*_stringmatched.feather
#
# OUTPUTS:
# HBP/IntermediateData/Louisiana/Leases/Clustering/clustered_at_85th_percentile/leased_during_*.dta
# HBP/IntermediateData/Louisiana/Leases/Clustering/clustered_at_90th_percentile/leased_during_*.dta
# HBP/IntermediateData/Louisiana/Leases/Clustering/clustered_at_95th_percentile/leased_during_*.dta
# HBP/Paper/Figures/single_numbers_tex/cluster_threshold_90.tex
# ------------------------------------------------------
### do $CODEDIR/Louisiana/downweighting_leases/final_downweight.do
#
# INPUTS:
# HBP/IntermediateData/Louisiana/Leases/louisiana_leases_csvs_preliminary_downweight.dta
# HBP/IntermediateData/Louisiana/Leases/Clustering/clustered_at_85th_percentile/leased_during_*.dta
# HBP/IntermediateData/Louisiana/Leases/Clustering/clustered_at_90th_percentile/leased_during_*.dta
# HBP/IntermediateData/Louisiana/Leases/Clustering/clustered_at_95th_percentile/leased_during_*.dta
#
# OUTPUTS:
# HBP/IntermediateData/Louisiana/Leases/Clustering/clustered_at_85th_percentile_final.dta
# HBP/IntermediateData/Louisiana/Leases/Clustering/clustered_at_90th_percentile_final.dta
# HBP/IntermediateData/Louisiana/Leases/Clustering/clustered_at_95th_percentile_final.dta
# ------------------------------------------------------

# Variables CODEDIR, OS, and STATA exported from build_script.sh

if [ "$OS" = "Unix" ]; then
	if [ "$STATA" = "SE" ]; then
		stata-mp -b do $CODEDIR/Louisiana/downweighting_leases/clean_lease_csv_dta.do &&
		stata-mp -b do $CODEDIR/Louisiana/downweighting_leases/area_downweighting.do
		echo "hey"
	elif [ "$STATA" = "MP" ]; then
		stata-se -e -b do $CODEDIR/Louisiana/downweighting_leases/clean_lease_csv_dta.do &&
		stata-se -e do $CODEDIR/Louisiana/downweighting_leases/area_downweighting.do
	fi
elif [ "$OS" = "Windows" ]; then
	if [ "$STATA" = "SE" ]; then
		stataSE-64 -e do $CODEDIR/Louisiana/downweighting_leases/clean_lease_csv_dta.do &&
		stataSE-64 -e do $CODEDIR/Louisiana/downweighting_leases/area_downweighting.do
	elif [ "$STATA" = "MP" ]; then
		stataMP-64 -e do $CODEDIR/Louisiana/downweighting_leases/clean_lease_csv_dta.do &&
		stataMP-64 -e do $CODEDIR/Louisiana/downweighting_leases/area_downweighting.do
	fi	
fi
echo $'Stata scripts done'

Rscript $CODEDIR/Louisiana/downweighting_leases/cleaning_duplicate_leases_for_stringmatch.R &&

if [ $OS = "Unix" ]; then
	python3 $CODEDIR/Louisiana/downweighting_leases/string_dissim.py
elif [ $OS = "Windows" ]; then
	python $CODEDIR/Louisiana/downweighting_leases/string_dissim.py
fi

echo $'Running main clustering algorithm'
Rscript $CODEDIR/Louisiana/downweighting_leases/calibrating_dendrogram_height.R

echo $'Now running final_downweight.do'
if [ $OS = "Unix" ]; then
	if [ "$STATA" = "SE" ]; then
		stata-mp -b do $CODEDIR/Louisiana/downweighting_leases/final_downweight.do
	elif [ "$STATA" = "MP" ]; then
		stata-se -e do $CODEDIR/Louisiana/downweighting_leases/final_downweight.do
	fi
elif [ $OS = "Windows" ]; then
	if [ "$STATA" = "SE" ]; then
		stataSE-64 -e do $CODEDIR/Louisiana/downweighting_leases/final_downweight.do
	elif [ "$STATA" = "MP" ]; then
		stataMP-64 -e do $CODEDIR/Louisiana/downweighting_leases/final_downweight.do
	fi
fi

#clean up log files
rm *.log

exit