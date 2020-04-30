/*
This file loads the raw rig dayrate data and converts it to .dta
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
log using "$logdir/LoadDayrates_log.txt", replace text


********************************************
// Load dayrate data and wrangle it
// We want dayrates for the ArkLaTx region, for depth ratings of 10000-12999 ft
// Start with older dayrate data; quarterly through Q2 2013
import excel "$rawdir/RigDayrates.xlsx", clear
gen Ind = _n
order Ind
keep if inlist(Ind,1,2,10)		// keeps headers and ArkLaTx 10000-12999 ft
local firstyear = 1990	// store first year of data
drop if Ind==1
drop Ind A-R DG    // drop early years with no data and July 2013
gen Ind = _n
order Ind

// Destring quarters and dayrates
replace DE = "55" if Ind==1		// convert May 2013 to "55"
replace DF = "66" if Ind==1		// convert June 2013 to "66"
foreach var of varlist S-DF {
	replace `var' = substr(`var',2,1) if Ind==1
	destring `var', replace
}

// Average May and June 2013 to get Q2 2013 (there are no April 2013 data)
gen DG = (DE + DF) / 2
replace DG = 2 if Ind==1 		// 2nd quarter
drop DE DF

// Transpose data
drop Ind
xpose, clear
rename v1 quarter
rename v2 dayrate

// Put years back in data
gen Ind = _n
gen fyear = `firstyear'
order Ind fyear
gen year = fyear + ceil((Ind-1)/4)

keep year quarter dayrate
order year quarter dayrate

// Save old data
tempfile tempdrold
save "`tempdrold'"




********************************************
// Load new dayrate data; quarterly through Q3 2013 - Q3 2017
import excel "$rawdir/Ryan Kellogg Chicago U custom day rates.xlsx", clear
gen Ind = _n
order Ind
keep if inlist(Ind,1,2,10)		// keeps headers and ArkLaTx 10000-12999 ft
local firstyear = 2013	// store first year of data
drop if Ind==1
drop Ind A-C AZ   // drop June 2013 and Oct 2017
gen Ind = _n
order Ind

// Convert text months to month numbers
// Patch fix double months
// destring
foreach var of varlist D-AY {
	replace `var' = "1" if `var'=="January"
	replace `var' = "2" if `var'=="February"
	replace `var' = "3" if `var'=="March"
	replace `var' = "4" if `var'=="April"
	replace `var' = "5" if `var'=="May"
	replace `var' = "5" if `var'=="May "
	replace `var' = "6" if `var'=="June"
	replace `var' = "7" if `var'=="July"
	replace `var' = "8" if `var'=="August"
	replace `var' = "9" if `var'=="September"
	replace `var' = "10" if `var'=="October"
	replace `var' = "11" if `var'=="November"
	replace `var' = "12" if `var'=="December"
	replace `var' = "11" if `var'=="11-12 2013"
	replace `var' = "7" if `var'=="July/August"
	replace `var' = "11" if `var'=="Nov/Dec"
	destring `var', replace
}

// Create duplicate variables for the double months and reorder
gen HH = H
gen OO = O
gen RR = R
order Ind D-H HH I-O OO P-R RR

// Transpose data
drop Ind
xpose, clear
rename v1 month
rename v2 dayrate

// Put years back in data
gen Ind = _n
gen fyear = `firstyear'
order Ind fyear
gen year = fyear + ceil((Ind-6)/12)

// Average to quarterly
drop Ind fyear
gen quarter  = 1
replace quarter = 2 if inlist(month,4,5,6)
replace quarter = 3 if inlist(month,7,8,9)
replace quarter = 4 if inlist(month,10,11,12)
drop month
sort year quarter
collapse(mean) dayrate, by(year quarter)
order year quarter dayrate

// Append with old data
append using "`tempdrold'"
sort year quarter
label variable dayrate "nominal dayrate, ArkLaTx, 10000'-12999'"

// Save
saveold "$outdir/RigDayrates.dta", version(14) replace


// Close out the log file
log close
