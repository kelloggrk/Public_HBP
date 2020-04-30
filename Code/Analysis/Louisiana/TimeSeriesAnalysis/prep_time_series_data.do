/*
merges together data on drilling, leasing, prices, and production for making time
series plots in haynesville_time_series_plot.R
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
while "`s(filename)'" != "HBP" {
  cd ..
  pathutil split "`c(pwd)'"
}

do "globals.do"

global EIAdatadir = "${dbdir}/IntermediateData/EIAData"
global outputdir = "${dbdir}/Scratch/figures"
global welldir = "${dbdir}/IntermediateData/Louisiana/Wells"
global unitdir = "${dbdir}/IntermediateData/Louisiana/SubsampledUnits"

global leasedir = "${dbdir}/IntermediateData/Louisiana/Leases"
global proddir = "${dbdir}/IntermediateData/Louisiana/DIProduction"
global pddir = "${dbdir}/IntermediateData/PriceDayrate"
global figdir = "${hbpdir}/Paper/Figures"
global logdir = "$hbpdir/Code/Analysis/Louisiana/LogFiles"

// Create log file
log using "$logdir/prep_neighbors_log.txt", replace text

********************************************************************************

set scheme tufte


**********************
* markers for what units are in our data
**********************
use "${unitdir}/unit_data_sample_flags.dta", clear
codebook section township range // range is negative numbers, township is positive numbers, section is numbers
keep if flag_sample_descript==1
keep section township range
tempfile sample
save "`sample'", replace


***********************
* Lease data:
***********************
use "$leasedir/Clustering/clustered_at_90th_percentile_final.dta", clear

merge m:1 township range section using "`sample'"
keep if inlist(_merge,3)
drop _merge

gen Year = year(startdate)
gen Month = month(startdate)
gen leasenum = 1
egen Hay_Lease_Count = sum(leasenum), by(Year Month)

gen primary_term = (cluster_exprdate - startdate)/365.25

gen ext_term = exttermmo/12 if exttermmo>0 & exttermmo<.
gen has_ext_term = ~missing(exttermmo) & exttermmo>0
egen royalty_mean = mean(royalty), by(Year Month)
egen primaryterm_mean = mean(primary_term), by(Year Month)
egen has_ext_mean = mean(has_ext), by(Year Month)
egen ext_term_mean = mean(ext_term), by(Year Month)

// Here we want to do a cumulative unit-area leased
bysort section_id (Year Month) : gen cumulative_area = sum(area_final)
gen cumulative_percentage = cumulative_area/total_section_area
gen half_area_leased = 1 if cumulative_percentage >= .5 & cumulative_percentage[_n-1]<.5
replace half_area_leased = 0 if half_area_leased == .
egen half_areas_leased = sum(half_area_leased), by(Year Month)


keep Year Month Hay_Lease_Count royalty_mean primaryterm_mean has_ext_mean ///
	ext_term_mean half_areas_leased
duplicates drop
duplicates report Year Month // no duplicates
tempfile data_with_leases
save "`data_with_leases'"

***********************
* Haynesville well time series data -- produced by create_well_timeseries.do
***********************

use "$proddir/haynesville_well_time_series.dta", clear

merge m:1 township range section using "`sample'"
keep if inlist(_merge,3)
drop _merge

gen Year = year(prod_date)
gen Month = month(prod_date)
drop if Year==.
egen monthly_production = sum(gas), by(Year Month)
keep Year Month monthly_production
replace monthly_production = monthly_production * 1.037 //making monthly production into mmbtu
replace monthly_production = monthly_production/1e6 //changing into units of millions
duplicates drop
duplicates report Year Month // no duplicates
merge 1:1 Year Month using "`data_with_leases'", nogen
save "`data_with_leases'", replace

***********************
* Haynesville unit data -- date of first lease
***********************
use "$unitdir/unit_data_with_prod.dta", clear

merge m:1 township range section using "`sample'"
keep if inlist(_merge,3)
drop _merge

gen Year = year(leaseStartFirst)
gen Month = month(leaseStartFirst)
gen leasenum = 1
egen First_Lease_In_Section = sum(leasenum), by(Year Month)
keep Year Month First_Lease_In_Section
duplicates drop
duplicates report Year Month // no duplicates
merge 1:1 Year Month using "`data_with_leases'", nogen
save "`data_with_leases'", replace

***********************
* Haynesville unit data -- date of first spud
***********************
use "$unitdir/unit_data_with_prod.dta", clear

merge m:1 township range section using "`sample'"
keep if inlist(_merge,3)
drop _merge

gen Year = year(first_spud)
gen Month = month(first_spud)
gen spudnum = 1
egen First_Spud_In_Section = sum(spudnum), by(Year Month)
keep Year Month First_Spud_In_Section
duplicates drop
duplicates report Year Month // no duplicates
merge 1:1 Year Month using "`data_with_leases'", nogen
save "`data_with_leases'", replace


***********************
* Haynesville well data -- total number of Haynesville wells
***********************
use "$welldir/hay_wells_with_prod.dta", clear

keep if flag_sample_descript == 1

keep if disc_prod_1!=. & Original_Completion_Date!=.
gen Year = year(Spud_Date)
gen Month = month(Spud_Date)
gen wellnum = 1
egen Hay_Well_Count = sum(wellnum), by(Year Month)
label var Hay_Well_Count "Leases Signed in Haynesville Parishes"
keep Year Month Hay_Well_Count
duplicates drop
duplicates report Year Month
merge 1:1 Year Month using "`data_with_leases'", nogen
save "`data_with_leases'", replace

***********************
* Price data
***********************
use "$pddir/PricesAndDayrates_Monthly.dta", clear
duplicates report Year Month
merge 1:1 Year Month using "`data_with_leases'", nogen


* Fills in some zeros
sort Year Month
gen ym = ym(Year, Month)
sum ym if ~missing(Hay_Well_Count)
replace Hay_Well_Count  = 0 if missing(Hay_Well_Count) & ym >= r(min)
drop ym

drop if Year==2066
gen Hay_Well_Count_tenth = Hay_Well_Count/10
save "$welldir/haynesville_rig_data_for_graphing.dta", replace

