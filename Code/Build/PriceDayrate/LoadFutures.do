/*
This file loads NYMEX futures price data
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
log using "$logdir/LoadFutures_log.txt", replace text


// Load Bloomberg futures data; keep 12 & 15 month crude and nat gas futures
import excel "$rawdir/bbg_cl_ng.xlsx", clear
keep AS AT AU BE BF BG DM DN DO DY DZ EA
rename AS CL12date
rename AT CL12price
rename AU CL12vol
rename BE CL15date
rename BF CL15price
rename BG CL15vol
rename DM NG12date
rename DN NG12price
rename DO NG12vol
rename DY NG15date
rename DZ NG15price
rename EA NG15vol
tempfile temp_futures
save "`temp_futures'"

// Loop over each of the four contracts, saving daily data
foreach c in CL12 CL15 NG12 NG15 {
	use "`temp_futures'", clear
	keep `c'date `c'price `c'vol
	rename `c'date date
	rename `c'price price
	rename `c'vol vol
	gen temp = _n
	drop if temp<=2		// drop header rows

	// convert date string to date, and price and volume strings to numeric
	rename date datestr
	gen Date = date(datestr,"MDY")
	format Date %dd_m_CY
	destring price, replace force
	destring vol, replace force
	drop if vol==. | price==.
	drop temp datestr
	drop if vol==0

	// sort and save
	order Date price vol
	sort Date
	saveold "$outdir/Futures_`c'.dta", version(14) replace
}


// Close out the log file
log close
