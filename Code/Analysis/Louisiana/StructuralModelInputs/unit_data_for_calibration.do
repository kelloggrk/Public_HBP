* Exports .csvs with unit data and the time path of acreage leased, 
* for use in the matlab model

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
global structoutdir = "$dbdir/IntermediateData/StructuralEstimationData"
global codedir = "$hbpdir/Code/Build/Louisiana/Units"
global logdir = "$hbpdir/code/build/Louisiana/Logfiles"
global subsampledir = "$dbdir/IntermediateData/Louisiana/SubsampledUnits"
global logdir = "$hbpdir/Code/Analysis/Louisiana/LogFiles"

// Create log file
log using "$logdir/unit_data_for_calibration_log.txt", replace text

********************************************************************************


// Reads in data:
use "$subsampledir/unit_data_with_prod.dta", clear

********************************************************************************
* First, unit-level data extract for structural estimation

keep if flag_sample_descript == 1

// First spud dates into year/quarter:
gen first_spud_year = year(first_spud)
gen first_spud_quarter = quarter(first_spud)
replace first_spud_year = 0 if missing(first_spud_year)
replace first_spud_quarter = 0 if missing(first_spud_quarter)

// first lease to expire dates into year and quarter:
gen first_lease_expire_year = year(leaseExpireExtFirst)
gen first_lease_expire_quarter = quarter(leaseExpireExtFirst)

// first date of leasing
preserve

// First gets the unit start date
keep unitID acres_leased_* 
reshape long acres_leased_, i(unitID) j(year_qtr) string
rename acres_leased_ acres_leased
gen year = real(substr(year_qtr,1,4))
gen quarter = real(substr(year_qtr,6,1))
sum year quarter
gen yq = yq(year, quarter)
format yq %tq
keep if acres_leased>0 & acres_leased<.
egen first_date_leasing = min(yq), by(unitID)
keep if yq==first_date_leasing
rename year unit_start_year
rename quarter unit_start_quarter
keep unitID unit_start_*
tempfile unit_start_date
save "`unit_start_date'"

// Next gets the max acreage leased -- scaling factor
restore
preserve
keep unitID acres_leased_????Q?
reshape long acres_leased_, i(unitID) j(year_qtr) string
rename acres_leased_ acres_leased
egen max_acres_leased = max(acres_leased), by(unitID)
keep unitID max_acres_leased
duplicates drop
tempfile unit_max_acres_leased
save "`unit_max_acres_leased'"


// Then merges it back in:
restore
merge 1:1 unitID using "`unit_start_date'"
drop _merge
merge 1:1 unitID using "`unit_max_acres_leased'"
drop _merge


// Exports unit-level data:
export delimited unitID av_royalty_firstExpire first_spud_year first_spud_quarter ///
	first_lease_expire_year first_lease_expire_quarter unit_start_year unit_start_quarter ///
	unit_phi max_acres_leased late_over_normal_leasing ///
	wells_2mi wells_5mi wells_7mi wells_10mi wells_in_caliper ///
	unit_start_year year_first_leased quarter_first_leased ///
	year_spudded increasing_acreage any_acres_leased_2010_2013 ///
	using "$structoutdir/unit_chars.csv", replace delimiter(",") nolabel
	
	
********************************************************************************	
// Now for unit-by-quarter data on fraction leased:
// fraction leased at any given point:
keep unitID av_royalty_firstExpire first_spud_year first_spud_quarter ///
	first_lease_expire_year first_lease_expire_quarter max_acres_leased ///
	acres_leased_????Q? unit_start_year unit_start_quarter

// keeps only if start date of unit is before start date of acreage for estimation
drop unit_start_year unit_start_quarter

// reshapes, extracts year and quarter:
reshape long acres_leased_, i(unitID) j(year_qtr) string
rename acres_leased_ acres_leased
gen year = real(substr(year_qtr,1,4))
gen quarter = real(substr(year_qtr,6,1))
sum year quarter

// rescales so that we assume 100% of the acreage gets leased
gen fraction_leased = acres_leased/max_acres_leased

// reshapes to be wide
keep unitID year quarter fraction_leased
rename fraction_leased fraction_leased_
reshape wide fraction_leased_, j(unitID) i(year quarter)

// keeps only if after 2010 Q1
keep if year >= 2010

// adds in a row that is is the unitID
gen n = _n
local N_plus_one = _N+1
set obs `N_plus_one'
foreach var of varlist fraction_leased_* {
	local unitID = real(subinstr("`var'","fraction_leased_","",1))
	replace `var' = `unitID' in `N_plus_one'
}
replace year = 0 in `N_plus_one'
replace quarter = 0 in `N_plus_one'
replace n = 0 in `N_plus_one'
sort n
drop n

// Exports
export delimited year quarter fraction_leased_* using ///
	"$structoutdir/fraction_leased.csv", replace delimiter(",")

	



