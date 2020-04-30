/*
This file loads the raw cpi data and converts it to .dta
*/


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
global rawdir = "$dbdir/RawData/orig/PriceDayrate"
global outdir = "$dbdir/RawData/data/PriceDayrate"
global codedir = "$hbpdir/code/build/PriceDayrate"
global logdir = "$codedir/LogFiles"


// Create a plain text log file to record output
// Log file has same name as do-file
log using "$logdir/LoadCPI_log.txt", replace text


// Load CPI data and convert to long format
import excel "$rawdir/SeriesReport-20180708172351_d2a36c.xlsx", sheet("BLS Data Series") firstrow clear
drop N O
gen temp = _n
order temp
drop if temp<=9		// drops header rows
rename B CPI1
rename C CPI2
rename D CPI3
rename E CPI4
rename F CPI5
rename G CPI6
rename H CPI7
rename I CPI8
rename J CPI9
rename K CPI10
rename L CPI11
rename M CPI12
rename CPIAllUrbanConsumersCurrent Year
drop if inlist(temp,10,11)	// drops last header rows
drop temp
destring Year CPI*, replace
drop if Year==.
sort Year
reshape long CPI, i(Year) j(Month)
gen CPIDec14 = -99
replace CPIDec14 = CPI if Year==2014 & Month==12
egen CPIDec2014 = max(CPIDec14)
drop CPIDec14
sort Year Month
label variable CPI "CPI, all urban, all goods less energy, not seasonally adjusted"
saveold "$outdir/CPI.dta", version(14) replace



// Close out the log file
log close
