/*****************************************************
 Read in DI raw monthly production data , save as .dta
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
global rawdir = "$dbdir/RawData/orig/Louisiana/DNR"
global dnrdir = "$dbdir/IntermediateData/Louisiana/DNR"
global outdir = "$dbdir/IntermediateData/Louisiana/Wells"
global proddir = "$dbdir/IntermediateData/Louisiana/DIProduction"
global codedir = "$hbpdir/code/build/Louisiana"
global logdir = "$codedir/LogFiles"

log using "$logdir/clean_production_data_log.txt", replace text

/**********************/
insheet using "${dbdir}/RawData/orig/Louisiana/DI/ProductionData/HPDIProduction.csv", comma names clear
drop days // always equal to 0

gen year = real(substr(prod_date,7,4))
gen month = real(substr(prod_date,1,2))
gen ym = ym(year, month)
format ym %tm

gen Pr_prod_date = mdy(real(substr(prod_date,1,2)),real(substr(prod_date,4,2)),real(substr(prod_date,7,4)))
format Pr_prod_date %td
drop prod_date
ren Pr_prod_date prod_date
duplicates report entity_id prod_date

save "$proddir/HPDIProduction.dta", replace

capture log close
exit, clear
