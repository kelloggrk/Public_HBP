* Merges estimated lifetime production with Haynesville well data:

clear all
set more off
capture log close

* Set local git directory and local dropbox directory

* Calling the path file works only if the working directory is nested in the repo
* This will be the case when the file is called via any scripts in the repo.
* Otherwise you must cd to at least the home of the repository in Stata before running.
pathutil split "`c(pwd)'"
while "`s(filename)'" != "HBP" {
  cd ..
  pathutil split "`c(pwd)'"
}

do "globals.do"

// Input and output directories
global figdir = "$hbpdir/Paper/Figures"
global scratchfigdir = "$dbdir/Scratch/figures"
global finalunitdir = "$dbdir/IntermediateData/Louisiana/FinalUnits"
global subsampledir = "$dbdir/IntermediateData/Louisiana/SubsampledUnits"
global ccdir = "$dbdir/IntermediateData/CalibrationCoefs"
global welldir = "$dbdir/IntermediateData/Louisiana/wells"
global proddir = "$dbdir/IntermediateData/Louisiana/DIProduction"
global scratch = "$dbdir/Scratch"
global intdataLAdir = "$dbdir/IntermediateData/Louisiana"
global logdir = "$hbpdir/Code/Analysis/Louisiana/LogFiles"

// Create log file
log using "$logdir/merge_discprod_to_wells_log.txt", replace text

********************************************************************************

* Reads in present value discounted total production
insheet using "${proddir}/disc_prod_patzek.csv", comma clear

* Converts from MCF to mmbtu:
foreach var of varlist disc_prod_? {
	replace `var' = `var'*1.037
}

* Preps and saves:
rename well_id Well_Serial_Num
tempfile temp
save "`temp'"

* Reads in well data:
use "${intdataLAdir}/well_unit_xwalk_master.dta"
	drop township range section // keeps Township Range Section

* Merges in discounted production:
merge 1:1 Well_Serial_Num using "`temp'"

* Saves:
save "${welldir}/hay_wells_with_prod.dta", replace

exit


