/*********************************************************
Read in DNR csv well files and convert to Stata
*********************************************************/

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
global rawdir = "$dbdir/RawData/orig/Louisiana/DNR"
global dnrdir = "$dbdir/IntermediateData/Louisiana/DNR"
global outdir = "$dbdir/IntermediateData/Louisiana/Wells"
global codedir = "$hbpdir/code/build/Louisiana"
global logdir = "$codedir/LogFiles"

log using "$logdir/clean_well_csvs_log.txt", replace text

* First turns DNR data into Stata data sets

* List of csv files from DNR
#delimit ;
local csv_file_list

	HAYNESVILLE_SHALE_WELLS_Bienville.csv
	HAYNESVILLE_SHALE_WELLS_Bossier.csv
	HAYNESVILLE_SHALE_WELLS_Caddo.csv
	HAYNESVILLE_SHALE_WELLS_DeSoto.csv
	HAYNESVILLE_SHALE_WELLS_Natchitoches.csv
	HAYNESVILLE_SHALE_WELLS_RedRiver.csv
	HAYNESVILLE_SHALE_WELLS_Sabine.csv
	HAYNESVILLE_SHALE_WELLS_Webster.csv

	WELL_TEST_DATA_PARISH_Bienville.csv
	WELL_TEST_DATA_PARISH_Bossier.csv
	WELL_TEST_DATA_PARISH_Caddo.csv
	WELL_TEST_DATA_PARISH_DeSoto.csv
	WELL_TEST_DATA_PARISH_Natchitoches.csv
	WELL_TEST_DATA_PARISH_RedRiver.csv
	WELL_TEST_DATA_PARISH_Sabine.csv
	WELL_TEST_DATA_PARISH_Webster.csv

	WELL_PERFS_AND_SAND_Bienville.csv
	WELL_PERFS_AND_SAND_Bossier.csv
	WELL_PERFS_AND_SAND_Caddo.csv
	WELL_PERFS_AND_SAND_DeSoto.csv
	WELL_PERFS_AND_SAND_Natchitoches.csv
	WELL_PERFS_AND_SAND_RedRiver.csv
	WELL_PERFS_AND_SAND_Sabine.csv
	WELL_PERFS_AND_SAND_Webster.csv

	ONG_WELL_PARISH_Bienville.csv
	ONG_WELL_PARISH_Bossier.csv
	ONG_WELL_PARISH_Caddo.csv
	ONG_WELL_PARISH_DeSoto.csv
	ONG_WELL_PARISH_Natchitoches.csv
	ONG_WELL_PARISH_RedRiver.csv
	ONG_WELL_PARISH_Sabine.csv
	ONG_WELL_PARISH_Webster.csv

	;
#delimit cr

* Read in and save as Stata .dta files
foreach csv in `csv_file_list' {

	di "`csv'"
	insheet using "${rawdir}/`csv'", comma clear

	* gets variable names
	qui describe
	local k = r(k)
	forvalues i=1/`k' {
		local v_orig = v`i'[2]
		if ~inlist("`v_orig'","Product type (10 - Oil) (20- Gas)", "Luw Code (Latest)") {
			local v`i'_name = subinstr(trim(v`i'[2])," ","_",.)
			* local v`i'_name = substr( `"`v`i'_name'"' , 1 , 32 )
			local v`i'_name = substr( "`v`i'_name'" , 1 , 32 ) // max length of variable is 32 characters
			rename v`i' `v`i'_name'
		}
		if "`v_orig'"=="Product type (10 - Oil) (20- Gas)" rename v`i' Product_type
		if "`v_orig'"=="Luw Code (Latest)" rename v`i' Luw_Code_Latest
	}

	drop in 1/2 // header rows
	local N = _N
	drop in `N' // footer row

	* drops a few more observations for special cases:
	if strpos("`csv'","ONG_WELL_PARISH") drop if strpos(Field_Name,"Number of Fields:")
	if strpos("`csv'","HAYNESVILLE_SHALE_WELLS") {
		drop if strpos(Well_Serial_Num,"Number of Wells:")
	}
	if strpos("`csv'","ONG_WELL_HISTORY_ALL_DATRNG")  drop if strpos(Well_Serial_Num,"Number of Wells:")
	if strpos("`csv'","WELL_SCOUT_REPORT_HISTORY") {
		drop if strpos(Report_Date,"Number of Tickets:")
		drop if strpos(Well_Serial_Num,"Number of Wells")
	}
	if strpos("`csv'","WELL_PERFS_AND_SAND") drop if strpos(Well_Serial_Number,"Number of Wells:")
	if strpos("`csv'","WELL_TEST_DATA_PARISH") {
		drop if strpos(WELL_TEST_Well_Serial_Num,"Number of Wells:")
		drop if strpos(Report_Type,"Number of Report Types:")
	}
	compress

	* saves
	local dta = subinstr("`csv'",".csv",".dta",1)
	save "${dnrdir}/`dta'", replace


}

capture log close