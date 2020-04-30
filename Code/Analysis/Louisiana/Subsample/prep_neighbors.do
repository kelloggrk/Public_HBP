/*****************************************************
Create unit-level dataset with information on the number of 
neighbors with the same vs different operator
*****************************************************/

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

// Input and output directories
global unitdir = "$dbdir/IntermediateData/Louisiana/DescriptiveUnits"
global sampdir = "$dbdir/IntermediateData/Louisiana/SubsampledUnits"
global logdir = "$hbpdir/Code/Analysis/Louisiana/LogFiles"

// Create log file
log using "$logdir/prep_neighbors_log.txt", replace text

********************************************************************************

foreach datasource in 1p2 1p7 {
	use "$unitdir/units_with_`datasource'_neighbors.dta", clear
	duplicates report unitID
	duplicates report unitID unitID_neighbor

	egen count_neighbor_units_`datasource' = total(1), by(unitID)
	egen count_has_neighbor_`datasource' = total(OPERATO_neighbor != "NA"), by(unitID)
	egen count_same_neigbor_`datasource' = total(OPERATO == OPERATO_neighbor & ///
		OPERATO_neighbor != "NA"), by(unitID)
		
	keep unitID count_neighbor_units_`datasource' count_has_neighbor_`datasource' count_same_neigbor_`datasource'
	duplicates drop
	
	tempfile `datasource'
	save "``datasource''", replace
}

use "`1p2'"
merge 1:1 unitID using "`1p7'"
drop _merge

save "$sampdir/units_with_neighbor_stats.dta", replace










