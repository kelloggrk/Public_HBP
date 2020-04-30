* Inputs data on wells' production, cost, and inputs, and data on prices and dayrates
* Outputs projection of costs on dayrate, and csv of well-level data

clear all
set more off
capture log close

* Set local git directory and local dropbox directory
*
* Calling the path file works only if the working directory is nested in the repo
* This will be the case when the file is called via any scripts in the repo.
* Otherwise you must cd to at least the home of the repository in Stata before running.
pathutil split "`c(pwd)'"
while "`s(filename)'" != "HBP" {
  cd ..
  pathutil split "`c(pwd)'"
}

do "globals.do"

// Input and output directories
global rawdir = "$dbdir/RawData/orig/Louisiana/DNR"
global intdir = "$dbdir/IntermediateData"
global dnrdir = "$intdir/Louisiana/DNR"
global welldir = "$intdir/Louisiana/Wells"
global proddir = "$intdir/Louisiana/ImputedProductivity"
global codedir = "$hbpdir/code/build/Louisiana"
global logdir = "$codedir/LogFiles"
global pddir = "$intdir/PriceDayrate"
global outdir = "$intdir/StructuralEstimationData"
global coefsdir = "$intdir/CalibrationCoefs"
global logdir = "$hbpdir/Code/Analysis/Louisiana/LogFiles"

// Create log file
log using "$logdir/drill_costs_projection_log.txt", replace text

********************************************************************************

* Reads in water price estimated in productivity_estimation.R
insheet using "${coefsdir}/P_w.csv", clear
local waterprice = p_w[1]

* Reads in day rate
use "${pddir}/PricesAndDayrates_Quarterly.dta", clear

keep year quarter dayrate

rename year date_year
rename quarter date_qtr

tempfile dayrates
save "`dayrates'"

* Reads in well data
use "${welldir}/hay_wells_with_prod.dta", clear

gen spud_date_month = month(Spud_Date)
gen spud_date_qtr = quarter(Spud_Date)
gen spud_date_year = year(Spud_Date)

gen comp_date_month = month(Original_Completion_Date)
gen comp_date_qtr = quarter(Original_Completion_Date)
gen comp_date_year = year(Original_Completion_Date)

ren spud_date_qtr date_qtr
ren spud_date_year date_year

merge m:1 date_year date_qtr using "`dayrates'", nogen
ren dayrate dayrate_spuddate
ren date_qtr spud_date_qtr 
ren date_year spud_date_year 


* Project well costs on dayrate
gen well_cost_no_water = well_cost - `waterprice'*water_volume_1
reg well_cost_no_water dayrate_spuddate
gen thetaDR_Proj = _b[dayrate_spuddate]
gen thetaD_Proj = _b[_cons]
gen rmse_Proj = e(rmse)

* Export initial values of dayrate coefficients
outsheet thetaDR_Proj thetaD_Proj rmse_Proj using "${coefsdir}/CostCoefsProj.csv" ///
	in 1, names replace comma

* Export data for water price estimation
keep if !mi(well_cost) & flag_hay_wells_for_prod_est
drop _merge

merge 1:1 Well_Serial_Num using "$proddir/imputed_well_productivity.dta"
count if _merge != 3
keep if !mi(phi_well)
keep if _merge==3

* Export data to Matlab:
outsheet Well_Serial_Num unitID ///
		spud_date_qtr spud_date_year well_cost ///
		water_volume_1 phi_well ///
		using "${outdir}/CostProjectionData.csv", ///
		names replace comma
		
clear all

