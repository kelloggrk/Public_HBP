* Merge imputed unit-level productivity estimates to the other unit-level data
* Also merges in neighbor operator information

clear all
set more off
capture log close

* Set local git directory and local dropbox directory
*
* Calling the path file works only if the working directory is nested in the repo
* This will be the case when the file is called via any scripts in the repo.
* Otherwise you must cd to at least the home of the repository in Stata before running.
pathutil split "`c(pwd)'"
while "`s(filename)'" != "HBP" {
  cd ..
  pathutil split "`c(pwd)'"
}

do "globals.do"

global subsampledir = "$dbdir/IntermediateData/Louisiana/SubsampledUnits"
global impproddir = "$dbdir/IntermediateData/Louisiana/ImputedProductivity"
global logdir = "$hbpdir/Code/Analysis/Louisiana/LogFiles"

// Create log file
log using "$logdir/merge_productivity_to_unit_data_log.txt", replace text

********************************************************************************

* Opens up unit data with subsample flags:
use "${subsampledir}/unit_data_sample_flags.dta", replace
drop _merge
describe unitID
duplicates report unitID

* Merges with the imputed productivity:
merge 1:1 unitID using "${impproddir}/imputed_unit_centroid_productivity.dta"
list unitID _merge if inlist(_merge,1,2)

keep if inlist(_merge,1,3)
drop _merge


* Merges with neighbor operator info stats:
merge 1:1 unitID using "${subsampledir}/units_with_neighbor_stats.dta"
keep if inlist(_merge,1,3)
drop _merge

* Saves:
save "${subsampledir}/unit_data_with_prod.dta", replace

exit
