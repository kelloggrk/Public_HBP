* Creates summary statistics and single-number tex files for wells

clear all
set more off
capture log close

* Set local git directory and local dropbox directory
*
* Calling the path file works only if the working directory is nested in the repo
* This will be the case when the file is called via any scripts in the repo.
* Otherwise you must cd to at least the home of the repository in Stata before running.
pathutil split "`c(pwd)'"
while "`s(filename)'" != "HBP" && "`s(filename)'" != "hbp" {
  cd ..
  pathutil split "`c(pwd)'"
}

do "globals.do"

global figdir = "$hbpdir/Paper/Figures"
global scratchfigdir = "$dbdir/Scratch/figures"
global finalunitdir = "$dbdir/IntermediateData/Louisiana/FinalUnits"
global subsampledir = "$dbdir/IntermediateData/Louisiana/SubsampledUnits"
global ccdir = "$dbdir/IntermediateData/CalibrationCoefs"
global welldir = "$dbdir/IntermediateData/Louisiana/wells"
global proddir = "$dbdir/IntermediateData/Louisiana/DIProduction"
global scratch = "$dbdir/Scratch"
global intdataLAdir = "$dbdir/IntermediateData/Louisiana"
global pricedir = "$dbdir/IntermediateData/PriceDayrate"
global logdir = "$hbpdir/Code/Analysis/Louisiana/LogFiles"

// Create log file
log using "$logdir/well_descriptives_log.txt", replace text

********************************************************************************

* Opens up well data

use "${welldir}/hay_wells_with_prod.dta"

* has disc_prod_1, well_cost water_volume_1
replace disc_prod_1  = disc_prod_1 / 1000000 
replace well_cost = well_cost / 1000000
replace water_volume = water_volume_1 / 1000000
gen spud_year = year(Spud_Date)
gen completion_year = year(Original_Completion_Date)


label var disc_prod_1 "PV total production (millions mmBtu)"
label var well_cost "Accounting well cost (millions, Dec 2014\$)"
label var water_volume_1 "Water volume (millions of gallons)" 
label var spud_year "Well spud year"
label var completion_year "Well completion year"

sum disc_prod_1 well_cost water_volume_1 spud_year completion_year
corr well_cost Spud_Date

sutex2 spud_year completion_year well_cost water_volume_1 disc_prod_1, ///
	varlabels percentiles(10 50 90) digits(1) tabular ///
	saving("$figdir/well_descript/descript_table_wells.tex") replace

* Outputs percentiles separately
sum disc_prod_1, detail
foreach dd in 10 50 90 {
	local p`dd' = round(r(p`dd')*10)/10
	if `p`dd''>0 & `p`dd''<1 local p`dd' 0`p`dd''
	cap erase "$figdir/single_numbers_tex/well_prod_p`dd'.tex"
	file open prod_p`dd' using "$figdir/single_numbers_tex/well_prod_p`dd'.tex", write
	file write prod_p`dd' "`p`dd''"
	file close prod_p`dd'
}
sum well_cost, detail
foreach dd in 10 50 90 {
	local p`dd' = round(r(p`dd')*10)/10
	if `p`dd''>0 & `p`dd''<1 local p`dd' 0`p`dd''
	cap erase "$figdir/single_numbers_tex/well_cost_p`dd'.tex"
	file open cost_p`dd' using "$figdir/single_numbers_tex/well_cost_p`dd'.tex", write
	file write cost_p`dd' "`p`dd''"
	file close cost_p`dd'
}
sum spud_year, detail
foreach dd in 10 /* 50 */ 90 {
	local p`dd' = r(p`dd')
	cap erase "$figdir/single_numbers_tex/spud_year_p`dd'.tex"
	file open spud_p`dd' using "$figdir/single_numbers_tex/spud_year_p`dd'.tex", write
	file write spud_p`dd' "`p`dd''"
	file close spud_p`dd'
}
sum water_volume_1, detail
foreach dd in 10 50 90 {
	local p`dd' = round(r(p`dd')*10)/10
	if `p`dd''>0 & `p`dd''<1 local p`dd' 0`p`dd''
	cap erase "$figdir/single_numbers_tex/well_water_p`dd'.tex"
	file open water_p`dd' using "$figdir/single_numbers_tex/well_water_p`dd'.tex", write
	file write water_p`dd' "`p`dd''"
	file close water_p`dd'
}

	


