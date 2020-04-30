/*****************************************************
Create crosswalk between well dataset and unit data with sample flags
*****************************************************/

clear all
set more off
capture log close


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
global intdataLAdir = "$dbdir/IntermediateData/Louisiana"
global ccdir = "$dbdir/IntermediateData/CalibrationCoefs"
global logdir = "$hbpdir/Code/Analysis/Louisiana/LogFiles"

// Create log file
log using "$logdir/units_sample_defs_to_wells_log.txt", replace text

********************************************************************************

* Opens the unit data with flags:
use "${subsampledir}/unit_data_sample_flags.dta", clear
	keep unitID flag_sample_descript flag_sample_descript_wdrilling ///
	township range section
tempfile units_short
save "`units_short'"


* Opens the Haynesville well data that was defined in collapse_wells2section.do
use "${intdataLAdir}/Serial_Unit_xwalk_Hay_HBP.dta", clear
	* preps for merging: changes township range and section to be appropriate format / name
	rename Township township
	rename Range range
	rename Section section
	count if ~strpos(township,"N") // 0
	count if ~strpos(range,"W") // 0
	replace township = subinstr(township,"N","",.)
	destring township, replace
	replace range = "-"+subinstr(range,"W","",.)
	destring range, replace
	
	duplicates report Well_Serial_Num
	
	keep Well_Serial_Num township range section
	tempfile hay_wells
	save "`hay_wells'"
	
	
* Opens up the master well data:
	use "${dbdir}/IntermediateData/Louisiana/Wells/master_wells.dta", clear
		drop township range section
		merge 1:1 Well_Serial_Num using "`hay_wells'"
		tab _merge

		keep if _merge==3
		drop _merge 
		sum is_haynesville

		gen flag_hay_wells_in_descript = 1
		gen flag_hay_wells_for_prod_est = ~missing(max_lateral_length) & max_lateral_length >= 300
		sum flag*

		* checks other things are good
		tab DIC_drilltype, m 
		tab DIC_drilltype if flag_hay_wells_for_prod_est==1, m 
		
		
	keep Well_Serial_Num Township Range Section entity_id ///
		API_Num township range section well_cost ///
		flag_hay_wells_in_descript flag_hay_wells_for_prod_est ///
		max_lateral_length weighted_lat weighted_lon water_volume_1 ///
		Spud_Date Original_Completion_Date
	
	tempfile well_serials
	save "`well_serials'", replace
	
* Merges with unit data sample
merge m:1 township range section using "`units_short'"

	keep if inlist(_merge,1,3)
	drop _merge
	
	tab1 flag_sample_*, m

	order Well_Serial_Num Township Range Section entity_id ///
		API_Num unitID township range section well_cost ///
		flag_sample_descript flag_sample_descript_wdrilling ///
		flag_hay_wells_in_descript ///
		flag_hay_wells_for_prod_est max_lateral_length ///
		weighted_lat weighted_lon water_volume_1 Original_Completion_Date Spud_Date

	keep Well_Serial_Num Township Range Section entity_id ///
		API_Num unitID township range section well_cost ///
		flag_sample_descript flag_sample_descript_wdrilling ///
		flag_hay_wells_in_descript ///
		flag_hay_wells_for_prod_est max_lateral_length ///
		weighted_lat weighted_lon water_volume_1 Original_Completion_Date Spud_Date

	duplicates report Well_Serial_Num
	
* Saves
save "${intdataLAdir}/well_unit_xwalk_master.dta", replace



exit

