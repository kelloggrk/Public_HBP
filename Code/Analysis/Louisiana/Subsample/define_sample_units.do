/*****************************************************
Create flags that will be used to define the analysis sample of units
and later the calibration sample of units
*****************************************************/

clear all
set more off
capture log close

* Set local git directory and local dropbox directory

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
global figdir = "$hbpdir/Paper/Figures"
global scratchfigdir = "$dbdir/Scratch/figures"
global finalunitdir = "$dbdir/IntermediateData/Louisiana/FinalUnits"
global subsampledir = "$dbdir/IntermediateData/Louisiana/SubsampledUnits"
global ccdir = "$dbdir/IntermediateData/CalibrationCoefs"
global logdir = "$hbpdir/Code/Analysis/Louisiana/LogFiles"

// Create log file
log using "$logdir/define_sample_units_log.txt", replace text

********************************************************************************

use "${finalunitdir}/unit_data_4_descript.dta", clear

********************************************************************************
* Additional variable definition	
		
	format first_spud %td
	gen quarter_spudded = quarter(first_spud)
	gen year_spudded = year(first_spud)

	gen quarter_first_leased = quarter(leaseStartFirst)
	gen year_first_leased = year(leaseStartFirst)
	
	gen tq = yq(year_spudded, quarter_spudded)
	format tq %tq
	label var tq "quarter first spudded"

	gen spud_count = 1
	egen units_spudded = sum(spud_count), by(tq)

************************************************************************************
* Sample restriction:


	* drops obsevations that are not in Haynesville map and that are not approximately 640 acres
	keep if from_unit_hay_convexhull
	
	* whether is not too weird of a shape of unit:
	gen about_640_acres = DNR_section_poly_acres>=580 & DNR_section_poly_acres<=680

	* marker for whether has a Haynesville well (that was actually drilled)
	gen has_HayWell = Hay_spud>=1 & Hay_spud<.
		// notice this excludes wells that are permitted but undrilled
		// contrast to HayWellCount which includes {permitted and undrilled}
	order has_HayWell, after(from_well)
	sum has_HayWell // 30% have at least one Haynesville well
	tab has_HayWell if from_lease, m

	// create for whether it is a Haynseville unit (from the Haynesville unit shapefile)
	gen is_Haynesville_unit = 1 if unit_origin==1
	tab is_Haynesville_unit, m
	
	

************************************************************************************
* Some sample restriction exploration:


	* whether has leasing prior to 2007 (e.g., 2002 to 2007)
	egen sum_lease = rowtotal(unitLeaseStart_y??)
	sum sum_lease
	gen has_anylease = sum_lease>0 & sum_lease<.
	egen sum_pre2007 = rowtotal(unitLeaseStart_y02 unitLeaseStart_y03 ///
		unitLeaseStart_y04 unitLeaseStart_y05 unitLeaseStart_y06 unitLeaseStart_y07)
	egen sum_pre2006 = rowtotal(unitLeaseStart_y02 unitLeaseStart_y03 ///
		unitLeaseStart_y04 unitLeaseStart_y05 unitLeaseStart_y06)
	egen sum_pre2005 = rowtotal(unitLeaseStart_y02 unitLeaseStart_y03 ///
		unitLeaseStart_y04 unitLeaseStart_y05)
	egen sum_pre2004 = rowtotal(unitLeaseStart_y02 unitLeaseStart_y03 ///
		unitLeaseStart_y04)
	forvalues year = 2004(1)2007 {
		gen has_pre`year' = sum_pre`year'>0 & sum_pre`year'<. if has_anylease==1
	} // e.g., has_pre2004 means that it had leasing in 2002, 2003, or 2004
	

	* whether has any leasing during relevant calibration estimation time periods:
	egen any_acres_leased_2010_2013 = rowtotal(acres_leased_2010Q? ///
		acres_leased_2011Q? acres_leased_2012Q? acres_leased_2013Q?)
	replace any_acres_leased_2010_2013 = any_acres_leased_2010_2013>0 & ///
		any_acres_leased_2010_2013<.

	gen hasNHayprod2006 = NHay_prod2006>0 & NHay_prod2006<.
	gen hasNHayprod2007 = NHay_prod2007>0 & NHay_prod2007<.
	tab hasNHayprod2006 hasNHayprod2007, m
	
	* Any well drilled before the Haynesville well?
	gen nonHaySpud_before_HaySpud = first_spud>NHay_firstspud & first_spud<. & NHay_firstspud<.

******************************************************************************	
* Sample definition for descriptive stuff


	local ifcond ~missing(leaseExpireFirst) & nonHaySpud_before_HaySpud==0 & ///
		hasNHayprod2007==0 & missing(NHay_firstspud) & is_Haynesville_unit==1 & ///
		about_640_acres 
	
	gen subsample_v1  = `ifcond' & ~missing(first_spud) & has_pre2004==0
	gen subsample_v2  = `ifcond' & ~missing(first_spud) & has_pre2005==0
	gen subsample_v1A = `ifcond'                        & has_pre2004==0
	gen subsample_v2A = `ifcond'                        & has_pre2005==0
	
	
	* Labels:
	label var subsample_v1 "Descriptive subsample, has Haynesville drilling"	
	label var subsample_v2 "Alternative: Descriptive subsample, has Haynesville drilling"	

	label var subsample_v1A "Descriptive subsample, including with no Haynesville drilling"	
	label var subsample_v2A "Alternative: Descriptive subsample, including with no Haynesville drilling"	
	
gen byte flag_sample_descript = subsample_v1A
gen byte flag_sample_descript_wdrilling = subsample_v1	

tab flag_sample_descript, m 			// no missings
tab flag_sample_descript_wdrilling, m   // no missings

sum has_anylease if flag_sample_descript == 1 // all equal 1



********************************************************************************
* Identifying whether any lease has acreage leased that increases after 2010
tempfile temp
save "`temp'"

keep unitID acres_leased_201?Q?
reshape long acres_leased_, i(unitID) j(qtr_str) string
gen qtr = yq(real(substr(qtr_str,1,4)),real(substr(qtr_str,6,1)))
format qtr %tq

sort unitID qtr
gen ascending_acreage = acres_leased_ > acres_leased_[_n-1] & unitID == unitID[_n-1]
egen ascending_acreage_max = max(ascending_acreage), by(unitID)

keep unitID ascending_acreage_max
duplicates drop
rename ascending_acreage_max increasing_acreage

tempfile increasing_acreage
save "`increasing_acreage'"

use "`temp'"
merge 1:1 unitID using "`increasing_acreage'"

	
********************************************************************************	
* Sample flags for calibration sample:
gen first_spud_year = year(first_spud)
gen first_spud_quarter = quarter(first_spud)
replace first_spud_year = 0 if missing(first_spud)
replace first_spud_quarter = 0 if missing(first_spud)

// Date of first lease expire
describe leaseExpireExtFirst
gen first_lease_expire_year = year(leaseExpireExtFirst)
gen first_lease_expire_quarter = quarter(leaseExpireExtFirst)

gen late_over_normal_leasing =  acres_leased_postExtExp / acres_leased_preExtExp
gen flag_late_stage_leasing = late_over_normal_leasing > 0.8
sum flag_late_stage_leasing // about 10%

tab flag_late_stage_leasing increasing_acreage, m
tab flag_late_stage_leasing increasing_acreage if ///
	flag_sample_descript == 1 & year(first_spud)>=2010 ///
	& yq(year_first_leased, quarter_first_leased) < yq(year_spudded, quarter_spudded) ///
	& any_acres_leased_2010_2013==1
	
********************************************************************************
* Final prep:
order flag_sample_descript flag_sample_descript_wdrilling ///	
	, after(range)
	
drop first_spud_year first_spud_quarter first_lease_expire_year ///
	first_lease_expire_quarter flag_late_stage_leasing
	
********************************************************************************
save "${subsampledir}/unit_data_sample_flags.dta", replace
	
	


