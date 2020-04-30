************************************************************************************
*
* constructs a unit-level database. Merges together:
*    (1) well level data collapsed to unit level
*    (2) lease level data collapsed to unit level
*    (3) unit data
*
************************************************************************************

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

// Input and output directories
global outdir = "$dbdir/IntermediateData/Louisiana/"
global codedir = "$hbpdir/Code/Build/Louisiana/Units"
global logdir = "$hbpdir/code/build/Louisiana/Logfiles"

log using "$logdir/construct_units_4_descript_log.txt", replace text

************************************************************************************

* Leases data collapsed to the unit level
	clear
	do "${codedir}/collapse_leases2units.do"
	duplicates report township range section
	* prep for merging:
	gen from_leases = 1
	order from_leases
	tempfile leases
	save "`leases'"
	save "${outdir}/Leases/lease_tempfile.dta", replace
	
* Well data collapsed to the section level.
		clear

		do "${codedir}/collapse_wells2units.do"
		* reformats/renames township, section, and range variables preparatory to merging
		duplicates report Township Range Section
		rename Section section
		rename Township township
		rename Range range
		*replace range = substr(range,2,.)
		replace range = "-"+range if substr(range,3,1)=="W" & ~missing(range)
		destring range, ignore("EW") replace
		*replace township = substr(township,2,.)
		replace township = "-"+township if substr(township,3,1)=="S" & ~missing(township)
		destring township, ignore("SN") replace
		destring section, replace
		duplicates report township section range
		* prep for merging
		gen from_well = 1
		order from_well
		tempfile wells
		save "`wells'", replace


* Unit data
	use "${outdir}/DescriptiveUnits/cleaned_master_units.dta", clear

		gen from_unit_hay_convexhull = 1
		
		merge 1:1 township range section using "`wells'", nogenerate
		duplicates report township range section
		merge 1:1 township range section using "`leases'", nogenerate
		
		replace unit_origin = 0 if missing(unit_origin)
		
		replace from_unit_hay_convexhull = 0 if missing(from_unit)
		replace from_leases = 0 if missing(from_leases)
		replace from_well = 0 if missing(from_well)

		* quick descriptives
		tab2 from_*, m

		* do a little cleaning of unitOperator names
		replace unitOperator = "Chesapeake Operating Inc." if unitOperator == "Chesapeake"
		replace unitOperator = "Goodrich Petroleum Company, L.L.C." if unitOperator == "Goodrich Petroleum Comapny, L.L.C."
		replace unitOperator = "KCS Resources, Inc." if unitOperator == "KCS Resources, L.L.C."
		replace unitOperator = "XTO Energy" if unitOperator == "XTO Energy, Inc."

		* Saves
		save "${outdir}/FinalUnits/unit_data_4_descript.dta", replace
		
capture log close
		
