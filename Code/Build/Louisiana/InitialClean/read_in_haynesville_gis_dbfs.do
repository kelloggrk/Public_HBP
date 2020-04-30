/*********************************************************
Read in well and unit data from DNR and 
DrillingInfo shapefiles
*********************************************************/

clear all
set more off
set matsize 2000
capture log close

di "`c(pwd)'"
* Set local git directory and local dropbox directory
*
* Calling the path file works only if the working directory is nested in the repo
* This will be the case when the file is called via any scripts in the repo.
* Otherwise you must cd to at least the home of the repository in Stata before running.
pathutil split "`c(pwd)'"
while "`s(filename)'" != "HBP" && "`s(filename)'" != "hbp" {
  cd ..
  pathutil split "`c(pwd)'"
  if "`s(filename)'" == "/" {
    break
  }
}

do "globals.do"

// Input and output directories
global rawdir = "$dbdir/RawData/orig/Louisiana"
global welldir = "$dbdir/IntermediateData/Louisiana/Wells"
global leasedir = "$dbdir/IntermediateData/Louisiana/Leases"
global unitdir = "$dbdir/IntermediateData/Louisiana/Units"
global tempdir = "$dbdir/IntermediateData/Louisiana/temp"
global codedir = "$hbpdir/code/build/Louisiana"
global logdir = "$codedir/Logfiles"


// Create a plain text log file to record output
// Log file has same name as do-file
log using "$logdir/read_in_haynesville_gis_dbfs_log.txt", replace text

/********** DI Completions **********/
shp2dta using "$rawdir/DI/LA-Completion-19000101-20151231.shp", ///
						data("$tempdir/temp.dta") ///
						coord("$tempdir/temp2.dta") replace

use "$tempdir/temp.dta", clear
drop _ID
foreach v of varlist * {
	local vname = lower("`v'")
	rename `v' `vname'
}
compress
duplicates drop

* Format dates
foreach v of varlist *date* {
	tostring `v', gen(temp)
	replace `v' = date(temp, "YMD")
	format `v' %td
	drop temp
	}
save "$welldir/louisiana_completions_DI.dta", replace

/*********** DI Wells **********/
shp2dta using "$rawdir/DI/LA-Well-19000101-20151231.shp", ///
						data(${tempdir}/temp.dta) ///
						coord(${tempdir}/temp2.dta) replace
use "$tempdir/temp.dta", clear
drop _ID
foreach v of varlist * {
	local vname = lower("`v'")
	rename `v' `vname'
}
compress
duplicates drop

* Format dates
foreach v of varlist *date* {
	tostring `v', gen(temp)
	replace `v' = date(temp, "YMD")
	format `v' %td
	drop temp
	}
save "$welldir/louisiana_wells_DI.dta", replace

/*********** DNR Haynesville units ***********/
shp2dta using "$rawdir/DNR/Haynesville_shale_units.shp", ///
						data(${tempdir}/temp.dta) ///
						coord(${tempdir}/temp2.dta) replace
use "$tempdir/temp.dta", clear
drop _ID
foreach v of varlist * {
	local vname = lower("`v'")
	rename `v' `vname'
}
gen unitFID = _n-1
compress

* Drop a couple weird perfect duplicates
bys unit_order unit_name field operator_n shape_area shape_len (unitFID): keep if _n == _N
save "$unitdir/haynesville_units_DNR.dta", replace

/************ DNR Wells ***********/
shp2dta using "$rawdir/DNR/dnr_wells.shp", ///
						data(${tempdir}/temp.dta) ///
						coord(${tempdir}/temp2.dta) replace
use "$tempdir/temp.dta", clear
drop _ID
foreach v of varlist * {
	local vname = lower("`v'")
	rename `v' `vname'
}

* Format dates
foreach v of varlist permit_dat spud_date effective_ well_stat2 original_c last_recom last_test_ sip_assign orphan_st2 scout_repo gis_upd_da {
	tostring `v', gen(temp)
	replace `v' = date(temp, "YMD")
	format `v' %td
	drop temp
	}

* Drop long string variables: mostly notes, urls
drop source_are source_of_ comments location upper_perf lower_perf scout_deta
compress
duplicates drop
save "$welldir/louisiana_topholes_DNR.dta", replace

/************ DNR Bottom Holes ***********/
shp2dta using "$rawdir/DNR/BOTTOM_HOLE.shp", ///
						data(${tempdir}/temp.dta) ///
						coord(${tempdir}/temp2.dta) replace
use "$tempdir/temp.dta", clear
drop _ID
foreach v of varlist * {
	local vname = lower("`v'")
	rename `v' `vname'
}
foreach v of varlist effective_ create_dat end_date update_dat {
	tostring `v', gen(temp)
	replace `v' = date(temp, "YMD")
	format `v' %td
	drop temp
	}

* Drop long string variables: mostly notes, urls
drop hyperlink doc_access
compress
duplicates drop
save "$welldir/louisiana_bottomholes_DNR.dta", replace

/************ DNR Drilling "Lines" ***********/
shp2dta using "$rawdir/DNR/BOTTOM_HOLE_LINE.shp", ///
						data(${tempdir}/temp.dta) ///
						coord(${tempdir}/temp2.dta) replace
use "$tempdir/temp.dta", clear
drop _ID
foreach v of varlist * {
	local vname = lower("`v'")
	rename `v' `vname'
}
foreach v of varlist effective_ create_dat end_date update_dat {
	tostring `v', gen(temp)
	replace `v' = date(temp, "YMD")
	format `v' %td
	drop temp
	}

* Drop long string variables: mostly notes, urls
drop hyperlink doc_access
compress
duplicates drop
save "$welldir/louisiana_legs_DNR.dta", replace

/*********** Clean up ***********/
erase "${tempdir}/temp.dta"
erase "${tempdir}/temp2.dta"
cap log close
exit, clear
