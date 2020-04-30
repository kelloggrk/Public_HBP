/*
This file estimates the parameters of the transition process for prices
and dayrates
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
global rawdir = "$dbdir/IntermediateData/PriceDayrate"
global outdir = "$dbdir/IntermediateData/PriceDayrate"
global codedir = "$hbpdir/code/build/PriceDayrate"
global logdir = "$codedir/LogFiles"
global texdir = "$hbpdir/Paper/Figures/single_numbers_tex"

// Create a plain text log file to record output
// Log file has same name as do-file
log using "$logdir/PriceDayrateTransitions_log.txt", replace text



// Load price and dayrate data
use "$rawdir/PricesAndDayrates_Quarterly.dta", clear

// Keep only data before 2010, when Haynesville drilling really boomed
keep if year<2010

// Start with oil: regress expected log price change on current price
sort year quarter
gen t = _n
tsset t
gen DLo = log(CLprice2) - log(CLprice1)
newey DLo CLprice1, lag(3)		// no significant mean reversion
local b1_oil = 0

* Data pre-2003 show expected mean reversion, consistent with Kellogg AER (2014)
newey DLo CLprice1 if year<=2003, lag(3)


// Now natural gas: regress expected log price change on current price
gen DLg = log(NGprice2) - log(NGprice1)
newey DLg NGprice1, lag(3)		// moderate mean reversion
local b0_gas = _b[_cons]
local b1_gas = _b[NGprice1]
predict plog_gas

* Some mean reversion is seasonality. But overall mean reversion small regardless
xi: newey DLg NGprice1 i.quarter, lag(3)
drop _I* DLo DLg



// Get oil and gas price volatility and covariance
* start with oil---treat oil as random walk given insignificant mean reversion
gen err_oil = log(CLprice1) - log(l.CLprice1)
sum err_oil
local Sig_o = r(sd)				// oil price volatility, on average
local b0_oil = -`Sig_o'^2 / 2	// ensures oil is random walk in levels

* now gas
gen err_gas = log(NGprice1) - (log(l.NGprice1) + l.plog_gas)
sum err_gas
local Sig_g = r(sd)				// gas price volatility, on average
drop plog_gas

* covariance between oil and gas
pwcorr err_o err_g
local Rho_og = r(rho)			// corr between oil and gas shocks



// Dayrates---allow for mean reversion proportional to that for gas
local b0_dr = `b0_gas'
sum NGprice1
local mean_g = r(mean)
sum dayrate
local mean_d = r(mean)
local b1_dr = `b1_gas' * `mean_g' / `mean_d'		// rescaling

* dayrate volatility and covar between oil and gas
gen ld = log(dayrate)
gen err_d = ld - l.ld
sum err_d
local Sig_d = r(sd)				// dayrate volatility
pwcorr err_o err_d
local Rho_od = r(rho)			// corr between oil price and dayrate
pwcorr err_g err_d
local Rho_gd = r(rho)			// corr between gas price and dayrate


// Create file for export
keep if t==1
gen b0_oil = `b0_oil'
gen b1_oil = `b1_oil'
gen b0_gas = `b0_gas'
gen b1_gas = `b1_gas'
gen b0_dr = `b0_dr'
gen b1_dr = `b1_dr'
gen Sig_oil = `Sig_o'
gen Sig_gas = `Sig_g'
gen Sig_dr = `Sig_d'
gen Rho_og = `Rho_og'
gen Rho_od = `Rho_od'
gen Rho_gd = `Rho_gd'

keep b0* b1* Sig* Rho*
export delimited using "$outdir/PriceTransitionCoefs.csv", delim(",") replace

// compute long-run mean prices
gen lr_gas = -(b0_gas + Sig_gas^2/2) / b1_gas
replace lr_gas = round(lr_gas,0.01)
gen lr_oil = -(b0_oil + Sig_oil^2/2) / b1_oil
replace lr_oil = round(lr_oil,0.01)
gen lr_dr = -(b0_dr + Sig_dr^2/2) / b1_dr
replace lr_dr = round(lr_dr,1)


outsheet lr_gas using "${texdir}/long_run_mean_gas.tex" in 1, replace nonames
outsheet lr_dr using "${texdir}/long_run_mean_dayrate.tex" in 1, replace nonames

// Close out the log file
log close

clear all
