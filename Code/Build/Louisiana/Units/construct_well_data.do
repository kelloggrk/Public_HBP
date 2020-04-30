*************************************************
*												*
* Merges together various well level sources	*
*  creates a master well level file				*
*												*
*************************************************
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
global welldir = "$dbdir/IntermediateData/Louisiana/Wells"
global codedir = "$hbpdir/code/build/Louisiana"
global logdir = "$codedir/LogFiles"
global cpidir = "$dbdir/RawData/data/PriceDayrate"


log using "$logdir/construct_well_data_log.txt", replace text



* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
* DATA that is at the Well_Serial_Num level -- where well Serial Number uniquely identifies observations

clear
tempfile ONG
save "`ONG'", emptyok
foreach parish in Bienville Bossier Caddo DeSoto Natchitoches RedRiver Sabine Webster {
	use "${dnrdir}/ONG_WELL_PARISH_`parish'.dta", clear
	keep Parish_Code-Product_Type_Code_Description Original_Completion_Date Last_Recompletion_Date Luw* Bottom_Hole_G_L* Proposed_*_Depth
	ds, has(type string)
	foreach var of varlist `r(varlist)' {
		replace `var' = trim(`var')
	}
	duplicates drop
	gen from_ONG = 1
	order Well_Serial_Num from_ONG
	append using "`ONG'"
	tempfile ONG
	save "`ONG'"
	duplicates report Well_Serial_Num //
}
	* fixes a few mis-typed locations
	tab1 Township Range Section, m
	replace Range    = "14W" if Range   =="142"
	replace Range    = "05W" if Range   =="05E"
	replace Range    = "09W" if Range   =="9W" // to make consistent
	replace Township = "15N" if Township=="15H"
	replace Township = "19N" if Township=="N19"
	tempfile ONG
	save "`ONG'"


clear
tempfile Haynesville
save "`Haynesville'", emptyok
foreach parish in Bienville Bossier Caddo DeSoto Natchitoches RedRiver Sabine Webster {
	use "${dnrdir}/HAYNESVILLE_SHALE_WELLS_`parish'.dta", clear
	keep Well_Serial_Num Measured_Depth	True_Vertical_Depth	Upper_Perforation Lower_Perforation Perforation_Length G_Laty G_Longx
	ds, has(type string)
	foreach var of varlist `r(varlist)' {
		replace `var' = trim(`var')
	}
	gen from_HayShaleWells = 1
	foreach var of varlist Measured_Depth	True_Vertical_Depth	Upper_Perforation Lower_Perforation Perforation_Length G_Laty G_Longx {
		rename `var' Hay`var'
	}
	order Well_Serial from_HayShaleWells
	append using "`Haynesville'"
	tempfile Haynesville
	save "`Haynesville'"
}

clear
tempfile PerfSands
save "`PerfSands'", emptyok
foreach parish in Bienville Bossier Caddo DeSoto Natchitoches RedRiver Sabine Webster {
	use "${dnrdir}/WELL_PERFS_AND_SAND_`parish'.dta", clear
	rename Well_Serial_Number Well_Serial_Num
	keep Well_Serial_Num Perforation_Completion_Date Upper_Perforation Lower_Perforation Perforations_Field_Id Sand_Sand Sand_Reservoir
	ds, has(type string)
	foreach var of varlist `r(varlist)' {
		replace `var' = trim(`var')
	}
	gen Perforation_Completion_DateR = date(Perforation_Completion_Date,"DMY")
	format 	Perforation_Completion_DateR %td
	drop Perforation_Completion_Date
	tab Sand_Sand, m
	order Well_Serial_Num Perforation_Completion_DateR
	sort Well_Serial_Num Perforation_Completion_DateR
	gen Perf_parish = "`parish'"
	append using "`PerfSands'"
	tempfile PerfSands
	save "`PerfSands'"
}
	drop Perf_parish
	tab Sand_Sand
	bysort Well_Serial_Num (Perforation_Completion_Date Upper_Perforation Lower_Perforation Perforations_Field_Id Sand_Sand Sand_Reservoir): gen j = _n
	ds Well_Serial_Num j, not
	local reshape_list `r(varlist)'
	reshape wide `reshape_list', i(Well_Serial_Num) j(j)
	gen from_PerfSands = 1
	order Well_Serial_Num from_PerfSands
	tempfile PerfSands
	save "`PerfSands'"
	duplicates report Well_Serial_Num

* Top hole locations
use "${welldir}/louisiana_topholes_DNR.dta", clear
	rename well_seria Well_Serial_Num
	keep Well_Serial_Num surface_l1 surface_lo
	rename surface_l1 surface_lat
	rename surface_lo surface_lon
	tostring Well_Serial_Num, replace
	gen from_topholes = 1
	order Well_Serial_Num from_topholes
	tempfile topholes
	save "`topholes'"


* weighted average (centroid) of the midpoints of the legs of the wells
use "${dbdir}/IntermediateData/Louisiana/Wells/well_legs_weighted_centroids.dta", clear
	ren WELL_SERIA Well_Serial_Num
	tostring Well_Serial_Num, replace
	gen from_weighted_centroid = 1
	tempfile weighted_centroid
	save "`weighted_centroid'"

* Bottom hole and well legs:
	use "${welldir}/well_legs_centroids.dta", clear
	merge 1:1 WELL_SERIA BHC_SEQ_NU using "${welldir}/bottomholes.dta", nogen
	ren WELL_SERIA Well_Serial_Num
	tostring Well_Serial_Num, replace
	ren EFFECTIVE_ effective_date
	bysort Well_Serial_Num: egen desired_rank = rank(BHC_SEQ_NU), unique
	replace desired_rank = 1 if desired_rank==.

	drop index
	ren BHC_SEQ_NU lateral_completion_ID_
	ren midpoint_lon lateral_midpoint_lon_
	ren midpoint_lat lateral_midpoint_lat_
	ren lateral_length lateral_length_
	ren effective_date lateral_effective_date_
	* we basically want to establish all the lateral information for each possible completion (from bottomholes_R.dta and well_legs_centroids_R.dta)
	reshape wide lateral_length_ lateral_effective_date_ lateral_completion_ID_ lateral_BH_lon_ lateral_BH_lat_ lateral_midpoint_lon_ lateral_midpoint_lat_, i(Well_Serial_Num) j(desired_rank)
	egen max_lateral_length = rowmax(lateral_length_*)
	gen from_lateral = 1
	order from_lateral lateral_length_* lateral_effective_date_* lateral_completion_ID_* lateral_BH_lon_* lateral_BH_lat* lateral_midpoint_lon_* lateral_midpoint_lat_*, last

	duplicates report Well_Serial_Num // no duplicates
	
	tempfile well_legs_and_BH
	save "`well_legs_and_BH'"
	
	
	
******************************************************************************************
* Well-level production

use "$proddir/HPDIProduction.dta", clear
	keep entity_id gas liq year month
	egen has_prod_data = max(gas>0 & gas<.), by(entity_id)
	egen has_prod_after_2010  = max(gas>0 & gas<. & year>=2010 & year<.), by(entity_id)
	egen has_prod_before_2010 = max(gas>0 & gas<. & year<= 2009), by(entity_id)
	keep entity_id has_prod_after_2010 has_prod_before_2010 has_prod_data
	gen from_prod_tsdata = 1
	duplicates drop // entity_id uniquely identifies observations
	ds entity_id from_prod_tsdata, not
	foreach var of varlist `r(varlist)' {
		rename `var' Pr_`var'
	}
	tempfile prod_timeseries_summary
	save "`prod_timeseries_summary'", replace

merge 1:1 entity_id using "${dnrdir}/Prod_header.dta", nogen
	replace from_prod_tsdata = 0 if missing(from_prod_tsdata)
	
	tab2 from*, m
	drop if missing(API_Num) 
		// drops cases that are in time series production data but not in header data
		// Important because we need API in order to be able to merge in
	tab2 from*, m

	duplicates report API_Num // some duplicates because Serial number is more precise than API
	
	order entity_id API_Num
	
	tempfile prod_data_summary
	save "`prod_data_summary'", replace
	

******************************************************************************************
* Merge together the data that is at the well serial number level	
	
* Merges all well-level data together -- for where Well Serial Number is the unit of observation
	use "`ONG'"
	merge 1:1 Well_Serial_Num using "`Haynesville'", nogenerate
	merge 1:1 Well_Serial_Num using "`PerfSands'", nogenerate
	merge 1:1 Well_Serial_Num using "`topholes'", nogenerate
	merge 1:1 Well_Serial_Num using "`weighted_centroid'", nogenerate
	merge 1:1 Well_Serial_Num using "`well_legs_and_BH'", nogenerate
	merge 1:1 Well_Serial_Num using "${dnrdir}/DICompletion.dta", nogenerate
	merge 1:1 Well_Serial_Num using "$dbdir/RawData/data/Louisiana/DNR/WellInputs/ra_frac_inputs_cleaned.dta", nogenerate
	merge 1:1 Well_Serial_Num using "$dbdir/RawData/data/Louisiana/DNR/WellCosts/wellcosts_data.dta", nogen
	
	* Markers for where data is coming from:
	describe from*
	foreach var of varlist from* {
		replace `var' = 0 if missing(`var')
	}
	
	keep if from_ONG==1 // want the DNR observations to be the base level of what the data is
	
	* saves:
	tempfile wells_serial_level
	save "`wells_serial_level'", replace
	
	
	
******************************************************************************************
* Some variable definition -- find out whether is in Haynesville, plus also does some date variables

	use "`wells_serial_level'", clear

	* Dates
	ds *Date*, has(type string)
	local DateVars `r(varlist)'
	foreach var of varlist `DateVars' {
		qui describe, varlist
		local all_vars_in_order `r(varlist)'
		gen `var'R = date(`var',"DMY")
		format `var'R %td
		drop `var'
		rename `var'R `var'
		order `all_vars_in_order'
	}

	* Whether Haynesville -- imputed from 3 different sources
	gen is_haynesville = 0
	* assumed yes if well name starts with HA or HAY:
	gen is_haynesville_wellname = 0
	replace is_haynesville_wellname = 1 if inlist(word(Well_Name,1),"HA","HAY","JUR")

	* assumed yes if from Haynesville well file:
	* assumed yes if HA or HAY or HAYNESVILLE appears in Sand_Sand variables
	gen imp_sand_haynesville=0

	* Finds the formation that the well targets:
	foreach var of varlist Sand_Sand* {
		replace `var' = " "+trim(`var')+" "
		replace `var' = subinstr(`var',","," , ",.)
		replace `var' = subinstr(`var',"&"," & ",.)
		replace `var' = subinstr(`var',"."," . ",.)
		replace `var' = subinstr(`var',"/"," / ",.)
		replace `var' = subinstr(`var',"  "," ",.)
		replace `var' = subinstr(`var',"  "," ",.)
		replace `var' = subinstr(`var',"  "," ",.)
		replace `var' = subinstr(`var',"  "," ",.)
	}

	gen sand_cottonvalley = 0
	gen sand_hosston = 0
	gen sand_nacatoch = 0
	gen sand_paluxy = 0
	gen sand_woodbine = 0
	gen sand_haynesville = 0
	foreach var of varlist Sand_Sand* {
		qui replace sand_cottonvalley = 1 if strpos(`var',"COTTON VALLEY") | strpos(`var'," CV ") | strpos(`var', " LCV ")
		qui replace sand_hosston = 1 if strpos(`var',"HOSSTON") | strpos(`var'," HOSS ")
		qui replace sand_nacatoch = 1 if strpos(`var',"NACATOC") | strpos(`var'," NAC ")
		qui replace sand_paluxy = 1 if strpos(`var',"PALUXY") | strpos(`var'," PXY ") | strpos(`var'," PLXY ")
		qui replace sand_haynesville = 1 if (strpos(`var',"HAYNESVILLE") | strpos(`var',"HA ")) & ///
		~strpos(`var',"CHA") & ///
			~strpos(`var',"SAMANTHA") & ///
			~strpos(`var',"HAYGOOD") & ///
			~strpos(`var',"HACATOCH") & ///
			~strpos(`var',"HAGGARD") & ///
			~strpos(`var',"HALL") & ///
			~strpos(`var',"HARKRIDER") & ///
			~strpos(`var',"NACAHATOSH") & ///
			~strpos(`var',"NACHAT") & ///
			`var'!="SHALE"
	}

	replace is_haynesville=1 if (is_haynesville_wellname==1 | from_HayShaleWells==1 | ///
		sand_haynesville==1) & Spud_Date!=.

	gen is_haynesville_date = 0
	replace is_haynesville_date = 1 if (is_haynesville_wellname==1 | from_HayShaleWells==1 | ///
		sand_haynesville==1) & Spud_Date >= date("01Sep2006", "DMY") & Spud_Date!=.

	* turns numeric variables stored as strings into string variables
	* Note: does not replace strings as numeric if they cannot be converted
	ds, has(type string)
	foreach var of varlist `r(varlist)' {
		if "`var'"!="API_Num" destring `var', replace
	}


	* turns numeric variables stored as strings into string variables
	* Note: does not replace strings as numeric if they cannot be converted
	ds, has(type string)
	foreach var of varlist `r(varlist)' {
		if "`var'"!="API_Num" destring `var', replace
	}

	* Saves
	sort Well_Serial_Num

	save "`wells_serial_level'", replace

	
	
******************************************************************	
* Merges in production data which is also at the API_Num level
	/* Note: here we need to be careful because both the "`wells_serial_level'"
		and the production data both have the case where API_Num does not uniquely
		observations. Therefore we first choose a subset of the wells_serial_level
		data which are relevant (is_haynesville==1) to help reduce the scope of the 
		many to many matching problem */

	* marks API duplicates in prod data -- cases where API can be matched to multiple entity_id's
	use "`prod_data_summary'", clear
	duplicates report entity_id
	duplicates report API_Num
	egen count_api_per_entity = total(1), by(API_Num)
	save "`prod_data_summary'", replace
	count
	
	* marks duplicates in serial data -- cases where API can be matched to multiple Serial Nums
	use "`wells_serial_level'"
	count
	duplicates report Well_Serial_Num
	duplicates report API_Num
	egen count_api_per_serial = total(1) ///
		if real(API_Num)!=0, by(API_Num) // # Mark this #1
	egen count_api_per_serial_hay = total(is_haynesville) ///
		if real(API_Num)!=0, by(API_Num)
	tab count_api_per_serial count_api_per_serial_hay
	save "`wells_serial_level'", replace
	
	* Marks a subset that are Haynesville wells 
	keep if is_haynesville==1
	keep API_Num
	duplicates drop
	tempfile haynesville_apis
	save "`haynesville_apis'", replace
	
	* Now marks the part of prod_data_summary that is Haynesville
	merge 1:m API_Num using "`prod_data_summary'"
	tab _merge
	keep if inlist(_merge,2,3)
	gen is_haynesville_API = _merge==3
	drop _merge
	count

	duplicates report API_Num
	egen count_api_per_entity_id_hay = total(is_haynesville_API), by(API_Num)
	
	keep if is_haynesville_API==1 // keeps only the _merge == 3 cases
		// only interested in production data if it can be potentially 
		// linked to a Haynesville-related well
	
	save "`prod_data_summary'", replace
	
	
	* now joinbys together
	use "`wells_serial_level'"
	joinby API_Num using "`prod_data_summary'", unmatched(both)
	
	tab _merge 
	gen from_prod_data = inlist(_merge,2,3)
	
	
	tab count_api_per_serial count_api_per_entity_id, m
	tab count_api_per_serial_hay count_api_per_entity_id, m

* First deal with the cases where count_api_per_serial>=2 & count_api_per_entity_id_hay==1:
	egen mean_is_haynesville_temp = mean(is_haynesville) if ///
		count_api_per_serial>=2 & count_api_per_serial<. & count_api_per_entity_id_hay==1, ///
		by(API_Num)
	sum mean_is_haynesville_temp if (count_api_per_serial>=2 & count_api_per_serial<. & count_api_per_entity_id_hay==1)
	drop mean_is_haynesville_temp

* Now deals with the cases where count_api_per_entity_id_hay==2 & count_api_per_serial==1
	
	tab1 API_Num Well_Serial_Num entity_id if count_api_per_entity_id_hay==2 & count_api_per_serial==1
	sort API_Num
	list API_Num Well_Serial_Num entity_id if count_api_per_entity_id_hay==2 & count_api_per_serial==1, sepby(API_Num)
	sort entity_id
	list API_Num Well_Serial_Num entity_id if count_api_per_entity_id_hay==2 & count_api_per_serial==1, sepby(entity_id)

	sort API_Num 
	list API_Num Well_Serial_Num entity_id Pr_pden_typeR if count_api_per_entity_id_hay==2 & count_api_per_serial==1, sepby(entity_id)
	drop if count_api_per_entity_id_hay==2 & count_api_per_serial==1 & Pr_pden_typeR == 1
	
	count
	
* Variables to keep from the prod data: entity_id -- helps for later matching
* all of the Pr_variables from the header data		
	order Well_Serial_Num API_Num entity_id
	drop count_api_per_entity is_haynesville_API count_api_per_entity_id_hay ///
		from_prod_data Pr_to_keep_for_unique_API Pr_is_haynesville_county ///
		Pr_is_haynesville_location Pr_twp Pr_rng Pr_section Pr_twp count_api_no ///
		_merge count_api_per_serial count_api_per_serial_hay
		
* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
* Nominal to real conversion of well drilling cost -- to December 2014 dollars
* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

	count if missing(Spud_Date) & ~missing(well_cost)
	tab Original_Completion_Date if missing(Spud_Date) & ~missing(well_cost)
	gen time_spud_2_completion = Original_Completion_Date - Spud_Date
	sum time_spud_2_completion, detail
	drop time_spud_2_completion
	tab Original_Completion_Date if missing(Spud_Date) & ~missing(well_cost)
	gen Year = year(Spud_Date)
	gen Month = month(Spud_Date)
	replace Year  =  year(Original_Completion_Date - 31) if missing(Year)  & ~missing(Original_Completion_Date)
	replace Month = month(Original_Completion_Date - 31) if missing(Month) & ~missing(Original_Completion_Date)
	merge m:1 Year Month using "$cpidir/CPI.dta"
	drop if _merge==2
	replace well_cost = well_cost*CPIDec2014/CPI
	drop _merge CPIDec2014 CPI Year Month
		
		
* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
* Cleans up and saves
* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

	* drops variables that are missing for all observations
	foreach var of varlist _all {
		qui count if missing(`var')
		if r(N) == _N {
			di "`var' dropped"
			drop `var'
		}
	}

	* Saves:
	save "${dbdir}/IntermediateData/Louisiana/Wells/master_wells.dta", replace
	
	
	capture log close
	exit, clear

	
