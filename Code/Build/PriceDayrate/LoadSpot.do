/* This file loads in Henry Hub Natural Gas spot prices. */

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
log using "$logdir/LoadSpot_log.txt", replace text

* Gas prices
import excel "$rawdir/NG_PRI_FUT_S1_M.xls", sheet("Data 1") firstrow clear
rename Back Datestr
rename Data P_Gas_Nom
drop C D
drop if Date=="Sourcekey" | Date=="Date"
gen Date=date(Datestr,"DMY")
format %dmCY Date
gen Year=year(Date)
gen Month=month(Date)
drop Datestr
destring P_Gas_Nom, replace
drop if Date==.		// last row
drop Date
sort Year Month
label variable P_Gas_Nom "Nominal HH spot price, USD/mmBtu"
save "$outdir/HHSpotPrices.dta", replace
