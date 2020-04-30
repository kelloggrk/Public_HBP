/*****************************************************
 Read in DI csv leasing data
 Very basic clean and save as dta
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
while "`s(filename)'" != "HBP" && "`s(filename)'" != "hbp" {
  cd ..
  pathutil split "`c(pwd)'"
}

do "globals.do"

// Input and output directories
global rawdir = "$dbdir/RawData/orig/Louisiana/DI/Louisiana_leases_csv"
global leasedir = "$dbdir/IntermediateData/Louisiana/Leases"
global tempdir = "$dbdir/IntermediateData/Louisiana/temp"
global codedir = "$hbpdir/code/build/Louisiana"
global logdir = "$codedir/Logfiles"

// Create log file
log using "$logdir/read_in_haynesville_lease_csvs_log.txt", replace text

/*----------------------------------------------------------------

	PART 1: IMPORT AND APPEND CSV'S

----------------------------------------------------------------*/
local files : dir "$rawdir" files "*.csv"
local iter = 0
foreach file of local files {
	local iter = `iter' + 1
	insheet using "$rawdir/`file'", comma nonames clear
	drop in 1
	capture confirm variable v28
                if !_rc {
                     	rename (v1-v28) (grantor grantee	volpage insttype county legal instdate ///
						termmo royalty recdate effdate area bonus exprdate optext	///
						extbonus	exttermmo blm state nominated alsgrantee granteesht	///
						grantoradr granteeadr calls recordno latitude longitude)
						drop nominated
                }
				else {
                    	rename (v1-v27) (grantor grantee	volpage insttype county legal instdate ///
						termmo royalty recdate effdate area bonus exprdate optext	///
						extbonus	exttermmo blm state alsgrantee granteesht	///
						grantoradr granteeadr calls recordno latitude longitude)
 						}

	save "$tempdir/temp_`iter'.dta", replace
	}

use   "$tempdir/temp_1.dta", clear
erase "$tempdir/temp_1.dta"
foreach i of numlist 2/`iter' {
	append using "$tempdir/temp_`i'.dta"
	erase        "$tempdir/temp_`i'.dta"
}

/*----------------------------------------------------------------

	PART 2: FORMAT VARIABLES

----------------------------------------------------------------*/
* PUT ALL STRING VARS IN ALL CAPS
foreach v of varlist grant* alsgrantee county insttype optext blm state legal {
	replace `v' = trim(upper(`v'))
}

* CREATE BINARY VARIABLES WHERE APPROPRIATE
replace blm = "1" if blm == "TRUE"
replace blm = "0" if blm == "FALSE"
replace state = "1" if state == "TRUE"
replace state = "0" if state == "FALSE"
replace optext = "1" if optext == "TRUE"
replace optext = "0" if optext == "FALSE"

* EXTRACT T/R/S
split legal, parse(",")
gen section = trim(subinstr(legal1,"S:","",.))
gen township = trim(subinstr(legal2,"T:","",.))
gen range = trim(subinstr(legal3,"R:","",.))

drop legal legal1 legal2 legal3

* DESTRING NUMERICAL VARS
destring blm state optext termmo royalty area bonus extbonus exttermmo latitude longitude, replace

* FORMAT DATE VARIABLES
foreach v of varlist instdate recdate effdate exprdate {
	gen test = date(`v',"MDY")
	drop `v'
	rename test `v'
	format `v' %td
}

compress
codebook
save "$leasedir/louisiana_leases_DI_csvs.dta", replace
capture log close
exit, clear
