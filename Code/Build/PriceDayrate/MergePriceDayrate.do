/*
This file merges oil and gas price data with dayrates and CPI. Exports
deflated datasets at monthly and quarterly levels
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
global rawdir = "$dbdir/RawData/data/PriceDayrate"
global outdir = "$dbdir/IntermediateData/PriceDayrate"
global codedir = "$hbpdir/code/build/PriceDayrate"
global logdir = "$codedir/LogFiles"

// Create a plain text log file to record output
// Log file has same name as do-file
log using "$logdir/MergePriceDayrate_log.txt", replace text



// Load CPI data and save as tempfile ready for merging
use "$rawdir/CPI.dta", clear
rename Year year
rename Month month
gen quarter = 1
replace quarter = 2 if inlist(month,4,5,6)
replace quarter = 3 if inlist(month,7,8,9)
replace quarter = 4 if inlist(month,10,11,12)
order year month quarter
sort year month
tempfile temp_CPI
save "`temp_CPI'"


// Load dayrates and save tempfile
use "$rawdir/RigDayrates.dta", clear
sort year quarter
tempfile temp_dayrate
save "`temp_dayrate'"


// Load each futures dataset. Aggregate to monthly. Loop over gas and oil
foreach c in CL12 CL15 NG12 NG15 {
	use "$rawdir/Futures_`c'.dta", clear
	gen year = year(Date)
	gen month = month(Date)
	drop Date
	collapse (mean) price (count) vol, by(year month)
	drop if year<=1992 		// low trade frequencies
	egen my = max(year)
	egen mm = max(month) if year==my
	drop if year==my & month==mm	// incomplete last month of obs
	drop my mm vol
	rename price `c'price
	sort year month
	tempfile temp_futures_`c'
	save "`temp_futures_`c''"
}

// Merge all files together
use "`temp_CPI'", clear
foreach c in CL12 CL15 NG12 NG15 {
	merge 1:1 year month using "`temp_futures_`c''"
	keep if _merge==3
	drop _merge
}
sort year quarter
merge m:1 year quarter using "`temp_dayrate'"
keep if _merge==3
drop _merge

sort year quarter
ren year Year
ren month Month
merge 1:1 Year Month using "${rawdir}/HHSpotPrices.dta", nogen
ren Year year
ren Month month
// Deflate everything to Dec 2014
* get avg monthly inflation---needed to get right rates of futures price growth
* do this by getting earliest and latest cpis in the data
gen ym = year*12 + month
egen Mym = max(ym)
egen mym = min(ym)
gen temp = 0
replace temp = CPI if ym==mym
egen minCPI = max(temp)
drop temp
gen temp = 0
replace temp = CPI if ym==Mym
egen maxCPI = max(temp)
drop temp
gen Inf = (maxCPI/minCPI)^(1/(Mym-mym))
drop ym-maxCPI

* deflate futures growth rates by 3 months of inflation
foreach c in NG CL {
	replace `c'15price = `c'15price / Inf^3
}
drop Inf

* make all data real Dec 2014
foreach var of varlist CL12price-P_Gas_Nom {
  di "`var'"
	replace `var' = `var' * CPIDec2014 / CPI
}
ren P_Gas_Nom P_Gas

* final renaming and labeling
label variable dayrate "dayrate, ArkLaTx, 10000'-12999', real $2014"
rename CL12price CLprice1
rename CL15price CLprice2
rename NG12price NGprice1
rename NG15price NGprice2

foreach c in CL NG {
	label variable `c'price1 "12 month `c' futures price, real $2014"
	label variable `c'price2 "15 month `c' futures price, real $2014"
}
label variable year ""
label variable CPI "CPI, all urban, all goods less energy, not seasonally adjusted"


* Save monthly and quarterly datasets
sort year month
ren year Year
ren month Month
save "$outdir/PricesAndDayrates_Monthly.dta", replace
ren Year year
ren Month month

sort year quarter
drop month
collapse (mean) CPI-dayrate, by(year quarter)
label variable dayrate "dayrate, ArkLaTx, 10000'-12999', real $2014"
foreach c in CL NG {
	label variable `c'price1 "12 month `c' futures price, real $2014"
	label variable `c'price2 "15 month `c' futures price, real $2014"
}
label variable CPI "CPI, all urban, all goods less energy, not seasonally adjusted"
saveold "$outdir/PricesAndDayrates_Quarterly.dta", version(14) replace

* Save .csv version of quarterly data that matlab can ingest
keep year quarter CLprice1 NGprice1 dayrate
export delimited using "$outdir/PricesAndDayrates_Quarterly.csv", delim(",") replace



// Close out the log file
log close

clear all
