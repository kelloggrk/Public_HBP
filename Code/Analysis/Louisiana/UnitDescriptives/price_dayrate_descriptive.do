* This file creates single number files for natural gas futures prices and dayrate

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
log using "$logdir/price_dayrate_descriptives_log.txt", replace text

********************************************************************************

use "$pricedir/PricesAndDayrates_Monthly.dta", clear
rename Year year

sum NGprice1 if year>=2009 & year<=2013, detail
	foreach output in mean max min {
		local `output'_NG12 = round(r(`output')*100)/100
		cap erase "$figdir/single_numbers_tex/NG12_`output'.tex"
		file open foo_handle using "$figdir/single_numbers_tex/NG12_`output'.tex", write
		file write foo_handle "``output'_NG12'"
		file close foo_handle
	}
sum dayrate if year>=2009 & year<=2013, detail
	foreach output in mean max min {
		local `output'_dayrate = round(r(`output'))
		local `output'_dayrate = string(``output'_dayrate', "%6.0fc")
		cap erase "$figdir/single_numbers_tex/dayrate_`output'.tex"
		file open foo_handle using "$figdir/single_numbers_tex/dayrate_`output'.tex", write
		file write foo_handle "``output'_dayrate'"
		file close foo_handle
	}
	
	
