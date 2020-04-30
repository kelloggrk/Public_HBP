/*****************************************************
Create well-level time series of production data that are suitable for passing
into matlab for estimating the production decline curve
Key intermediate step is addressing recompletions
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
global proddir = "$dbdir/IntermediateData/Louisiana/DIProduction"
global codedir = "$hbpdir/code/build/Louisiana"
global texdir = "$hbpdir/Paper/Figures/single_numbers_tex"
global intdataLAdir = "$dbdir/IntermediateData/Louisiana"
global logdir = "$hbpdir/Code/Analysis/Louisiana/LogFiles"

// Create log file
log using "$logdir/create_well_timeseries_log.txt", replace text

********************************************************************************

* Production time series data:
    use "$proddir/HPDIProduction.dta", clear
	tempfile prod_timeseries
	save "`prod_timeseries'", replace
	
	
* Well identifiers:
	use "${intdataLAdir}/well_unit_xwalk_master.dta", clear
	tempfile well_units
	save "`well_units'"
	
	
* Opens well-level data, turns it into time series data of well events
    use "${dbdir}/IntermediateData/Louisiana/Wells/master_wells.dta", clear

    * important sample restriction
    keep if is_haynesville & DIC_drilltype == "H"
    
    * lateral variables:
    egen max_lat_length = rowmax(lateral_length_?)
    egen min_lat_length = rowmin(lateral_length_?)
    gen dif_lat_length = max_lat_length - min_lat_length
    gen perc_dif_lat_length = min_lat_length / max_lat_length
    sum dif_lat_length perc_dif_lat_length, detail
    count if perc_dif_lat_length > .99 & perc_dif_lat_length<=1
    local numer = r(N)
    count if perc_dif_lat_length<=1
    di `numer'/r(N)

    * checking on duplicates
    duplicates report Well_Serial_Num
    duplicates report API_Num
	
    * drops vars that are missing for all observations
    qui ds, has(format %td)
    foreach var of varlist Upper_Perforation* Lower_Perforation* ///
            Perforations_Field_Id* Sand_Sand* Sand_Reservoir* ///
            `r(varlist)' {
        count if ~missing(`var')
        if r(N)==0 drop `var'
    }

    describe DIC_compdate*
    describe Upper_Perforation*
    describe Perforation_Completion_DateR*
    describe completion_date_*

    * Preps to reshape long, for merging in completion dates
    local i = 1
    qui ds, has(format %td)
    foreach var of varlist `r(varlist)' {
		di "`var'"
        gen event_date_`i' = `var'
        format event_date_`i' %td
        gen event_type_`i' = "`var'"
        local i = `i'+1
    }

    * reshapes long:
    keep event_date_* event_type_* API_Num Well_Serial_Num entity_id max_lateral_length
    reshape long event_date_ event_type_, i(API_Num Well_Serial_Num entity_id) j(j)
    drop if missing(event_date)
    drop j

    * changes to monthly-level observations:
    gen ym = ym(year(event_date_),month(event_date_))
    format ym %tm
    duplicates report API_Num Well_Serial_Num entity_id ym
    bysort API_Num Well_Serial_Num entity_id max_lateral_length ym (event_date_): gen j = _n
    tab j
    reshape wide event_type_ event_date_, i(API_Num Well_Serial_Num entity_id ym) j(j)
	duplicates report entity_id ym
	duplicates report entity_id ym if ~missing(entity_id)
	duplicates report Well_Serial_Num ym
	duplicates report API_Num ym
	
    describe max_lateral_length
	drop max_lateral_length
    tempfile well_events
    save "`well_events'"


	
	********************************************************************************************
	********************************************************************************************
	
	* Now well info and well event time series together -- a way to pass in Well_Serial_Num and API_Num
	use "`prod_timeseries'"
		qui describe, varlist
		local time_series_vars `r(varlist)'
	merge m:1 entity_id using "`well_units'"
	keep if _merge==3 // only production data that matches to relevant wells
		drop _merge
		keep `time_series_vars' Well_Serial_Num API_Num
		// effectively adds in Well_Serial_Num and API_Num -- useful for later merging
	order Well_Serial_Num entity_id API_Num
	save "`prod_timeseries'", replace
	
	* Now merges production time series and well event info together
	merge 1:1 Well_Serial_Num entity_id API_Num ym using "`well_events'"
	drop _merge
	tempfile combined_timeseries
	save "`combined_timeseries'", replace
	
	* Now merges on top the other well-id info that is relevant
	* Basically is adding in well-level info on top of everything else
	use "`well_units'"
	merge 1:m Well_Serial_Num entity_id API_Num using "`combined_timeseries'"
	keep if _merge == 3 //drops a very small number of cases where _merge==2
	drop _merge

	* saves:
    save "${dbdir}/IntermediateData/Louisiana/DIProduction/haynesville_well_time_series.dta", replace

	********************************************************************************************
	* Outputs data for production estimation -- csv form
	
	keep if flag_hay_wells_for_prod_est==1

	rename Original_Completion_Date welllevel_orig_completion_date
	rename Spud_Date welllevel_orig_spud_date
	
	egen tag_API = tag(API_Num)
    label define binary 0 " " 1 "X"
    local outcomes
    foreach var of varlist event_type_? {
        levelsof `var', local(added_outcomes)
        local outcomes : list outcomes | added_outcomes
    }
	
    foreach outcome in `outcomes' {
		di "`outcome'"
        qui gen `outcome' = 0
        foreach var of varlist event_type_? {
            qui replace `outcome' = 1 if `var'=="`outcome'"
        }
        label values `outcome' binary
    }

	describe welllevel_orig_spud_date welllevel_orig_completion_date
	
	
    corr DIC_compdate1 Original_Completion_Date Perforation_Completion_DateR1 Pr_comp_date completion_date_1
    egen first_comp_not_RA = rowmax(DIC_compdate1 Original_Completion_Date Pr_comp_date Perforation_Completion_DateR1)
    sum first_comp_not_RA if completion_date_1 == 1

    corr DIC_compdate? Last_Recompletion_Date Original_Completion_Date Perforation_Completion_DateR? Pr_comp_date completion_date_?

    egen any_completion = rowmax(DIC_compdate? Last_Recompletion_Date Original_Completion_Date Perforation_Completion_DateR? Pr_comp_date /* completion_date_? */ )
    label values any_completion binary

    egen total_completion = total(any_completion), by(API_Num)
    tab total_completion if tag_API

    * For any date (ym) and well, find the first date for which gas was produced:
    gen pos_gas = gas>0 & gas<.
    egen first_ym_gas_temp = min(ym) if pos_gas==1, by(API_Num)
    egen first_ym_gas = mean(first_ym_gas_temp), by(API_Num)
    drop first_ym_gas_temp
    gen is_first_ym_gas = ym==first_ym_gas

    * finds the last date for which gas was produced
    egen last_ym_gas_temp = max(ym) if pos_gas==1, by(API_Num)
    egen last_ym_gas = mean(last_ym_gas_temp), by(API_Num)
    drop last_ym_gas_temp
    gen is_last_ym_gas = ym==last_ym_gas

    * finds next date for which there was a completion after gas started producing
    egen next_comp_after_gas_temp = min(ym) if any_completion==1 & ym>first_ym_gas, by(API_Num)
    egen next_comp_after_gas = mean(next_comp_after_gas_temp), by(API_Num)
    drop next_comp_after_gas_temp
    gen is_next_comp_after_gas = ym == next_comp_after_gas

    * compares time to next completion with total amount of time producing gas
    gen time_length_pos_gas = last_ym_gas - first_ym_gas
    gen time_length_gas2comp = next_comp_after_gas - first_ym_gas
    gen min_time = min(time_length_pos_gas, time_length_gas2comp)
    sum min_time if tag_API, detail

    * Preps for final data:
    gen first_date = first_ym_gas
    gen last_date = min(last_ym_gas, next_comp_after_gas - 1)
    gen recompletion = next_comp_after_gas-1 <= last_ym_gas
	
    keep if ym>=first_date & ym<=last_date
    keep API_Num Well_Serial_Num ym gas recompletion max_lateral_length

    sum gas // includes zeros
    count if missing(gas)
    egen miss_gas = max(missing(gas)), by(API_Num)
    drop miss_gas
    tsset Well_Serial_Num ym
    count
    tsfill
    count

	* Drop missing/zero months of gas production
	drop if mi(gas) | gas == 0

	* Generate t variable
	bys Well_Serial_Num (ym): gen t = _n

	* Generate cumulative production
	bys Well_Serial_Num (t): gen cumul_gas = sum(gas)

	* Normalize by lateral length, drop if length < 400m (clear break there)
	egen tag = tag(Well_Serial_Num)
	summ max_lateral_length if tag == 1, d

	* Scale to 1485m (average of mean and median)
	gen scale = 1485/max_lateral_length
	replace gas = gas * scale
	replace cumul_gas = cumul_gas * scale

	rename (gas cumul_gas) (norm_gas norm_cumul_gas)

	* August 2019: Flag for first production starts after 2010:
	gen after_2010 = year(dofm(ym))>=2010 & year(dofm(ym))<.

	* In-text number about recompletion
	egen tag_serial = tag(Well_Serial_Num)
	sum recompletion if tag_serial
	gen recomp_mean = r(mean)
	replace recomp_mean = round(recomp_mean*100,1)
	outsheet recomp_mean using "${texdir}/recompletion_pct.tex" in 1, replace nonames
	drop recompletion recomp_mean tag_serial
	
    * Saves data for inputting into Matlab decline estimation code
	keep API_Num Well_Serial_Num t norm_cumul_gas norm_gas max_lateral_length 
	order API_Num Well_Serial_Num t norm_cumul_gas norm_gas max_lateral_length 

	destring API_Num, replace
	format API_Num %21.0f
	
	* Make sure to get full precision!
	format norm_cumul_gas norm_gas max_lateral_length %21.0g
	sort Well_Serial_Num t
    outsheet using "${dbdir}/IntermediateData/Louisiana/DIProduction/time_series_4_decline_estimation.csv", comma names replace


	
	
