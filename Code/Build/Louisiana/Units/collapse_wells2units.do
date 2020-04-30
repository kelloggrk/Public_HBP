clear all
set more off

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
global rawdir = "$dbdir/RawData/orig/Louisiana/DI/ProductionData"
global outdir = "$dbdir/IntermediateData/Louisiana"
global codedir = "$hbpdir/Code/Build/Louisiana/Units"



* First decides whether to use tophole
use "${outdir}/DescriptiveUnits/haynesville_wells_x_units.dta", clear
reshape wide SECTN TOWNSHIP RANGE sectionFID isect_length, i(Well_Serial_Num) j(desired_rank)
keep Well_Serial_Num
tempfile haynesville_wells_ids
save "`haynesville_wells_ids'"

* finds just the non-Haynseville wells -- more precisely, non-Haynesville wells plus
*  Haynesville "wells" that never had completion or production or location
use "${outdir}/DescriptiveUnits/all_wells_x_units.dta", clear

merge m:1 Well_Serial_Num using "`haynesville_wells_ids'"
keep if _merge==1
drop _merge
tempfile wells_no_haynesville
save "`wells_no_haynesville'"

	gen is_not_hay_append = 1
append using "${outdir}/DescriptiveUnits/haynesville_wells_x_units.dta"
	replace is_not_hay_append = 0 if missing(is_not_hay_append)
	tab is_not_hay_append is_haynesville, m
	// these are not a 1:1 match, because the haynesville_wells_x_units.dta
	// is actually more restrictive: It is not only limited to the is_haynesvile==1, 
	// but also has dropped those that do not have production, do not have completion,
	// and/or do not have a well leg location


tempfile TRS_master_wells
save "`TRS_master_wells'"

	
	duplicates report Well_Serial_Num Township Range Section 
	duplicates report Well_Serial_Num
	count	

	* Next limits to those that are Haynesville, have completion, have weighted_long
	*  and have production -- these are the legit Haynesville wells that hold by production
	
	*** NOTE: THIS IS THE SAME RESTRICTION AS IN clean_well_laterals_x_units.do ~line 46 ***
	*** (Keep these consistent) ***
	
	keep if is_haynesville==1 & Original_Completion_Date!=. & weighted_lon!=. & Pr_has_prod_data==1

	duplicates report Well_Serial_Num Township Range Section // duplicates because currently at well x TRS x well leg level
	
	
	keep Well_Serial_Num Township Range Section ///
		Permit_Date Spud_Date Original_Completion_Date DIC_spuddate ///
		DIC_compdate1 completion_date_1 water_volume* has_sand_info_* ///
		Pr_first12* Pr_first6* Pr_first24* well_cost
	duplicates report Well_Serial_Num Township Range Section
	duplicates report Well_Serial_Num
	
	duplicates drop // drops the multiple laterals, so only one observation per well serial num x unit
	duplicates report Well_Serial_Num Township Range Section // no duplicates 
	
	
	egen HayWellCount = total(1), by(Section Township Range)
	egen Hay_spud = total(~missing(Spud_Date)), by(Section Township Range)
	corr HayWellCount Hay_spud 
	

	* first dates:
	egen first_permit = min(Permit_Date)                         , by(Township Range Section)
	egen first_spud = min(Spud_Date)                             , by(Township Range Section)
	egen first_comp = min(Original_Completion_Date)              , by(Township Range Section)
	egen first_spudDI = min(DIC_spuddate)                        , by(Township Range Section)
	egen first_compDI = min(DIC_compdate1)                       , by(Township Range Section)
	egen first_compRA = min(completion_date_1)                   , by(Township Range Section)

	* total wells that got to various stages:
	egen count_permit = total(~missing(Permit_Date))             , by(Township Range Section)
	egen count_spud   = total(~missing(Spud_Date))               , by(Township Range Section)
	egen count_comp   = total(~missing(Original_Completion_Date)), by(Township Range Section)
	egen count_spudDI = total(~missing(DIC_spuddate))            , by(Township Range Section)
	egen count_compDI = total(~missing(DIC_compdate1))           , by(Township Range Section)
	egen count_compRA = total(~missing(completion_date_1))       , by(Township Range Section)
	
	* water variables -- from RA water entry
	egen RA_water_all = rowtotal(water_volume_*), missing
	gen water_RA1_temp = water_volume_1 if completion_date_1==first_compRA
	egen water_RA1 = mean(water_RA1_temp), by(Township Range Section)
	gen well_cost_RA1_temp = well_cost if completion_date_1 == first_compRA
	egen well_cost_RA1 = mean(well_cost_RA1_temp), by(Township Range Section)
	gen water_RA2_temp = water_volume_1 if completion_date_1==first_compRA
	egen water_RA2 = mean(water_RA2_temp), by(Township Range Section)
	label var water_RA1 "Water volume 1st well completed, method 1"
	label var water_RA2 "Water volume 1st well completed, method 2"

	egen RA_sand_max = rowmax(has_sand_info_*)
	gen sand_RA1_temp = RA_sand_max if completion_date_1==first_compRA
	egen sand_RA1 = mean(sand_RA1_temp), by(Township Range Section)
	gen sand_RA2_temp = has_sand_info_1 if completion_date_1==first_compRA
	egen sand_RA2 = mean(sand_RA2_temp), by(Township Range Section)
	label var sand_RA1 "Has sand info 1st well completed, method 1"
	label var sand_RA2 "Has sand info 1st well completed, method 2"

	* tag one obs in each TRS to help with diagnostics later
	egen tag_TRS = tag(Township Range Section)

	* Production
	ds Pr_first12* Pr_first6* Pr_first24* , has(type numeric)

	foreach var of varlist `r(varlist)' {
		local newvarstub = subinstr("`var'","Pr_","",1)
		gen ProdC_`newvarstub'_temp = `var' if first_comp==Original_Completion_Date
		gen ProdS_`newvarstub'_temp = `var' if first_spud==Spud_Date

		egen ProdC_`newvarstub' = mean(ProdC_`newvarstub'_temp), by(Township Range Section)
		egen ProdS_`newvarstub' = mean(ProdS_`newvarstub'_temp), by(Township Range Section)

		egen ProdC_sd_`newvarstub' = sd(ProdC_`newvarstub'_temp), by(Township Range Section)
		egen ProdS_sd_`newvarstub' = sd(ProdS_`newvarstub'_temp), by(Township Range Section)

		drop ProdC_`newvarstub'_temp ProdS_`newvarstub'_temp

		di "`newvarstub'"
		corr ProdC_`newvarstub' ProdS_`newvarstub' if tag_TRS
	}

	sum Prod?_sd_* if tag_TRS

	drop Prod?_sd_*
	order ProdC* ProdS*, last


	* Collapse to Township/Range/Section level
	preserve
	keep Township Range Section HayWellCount first_permit-count_compRA water_RA? sand_RA? ProdC* ProdS* Hay_spud well_cost_RA1
	duplicates drop
	duplicates report Township Range Section // no duplicates


	tempfile hay_well_sum
	save "`hay_well_sum'", replace

	* Next outputs Haynesville - unit match crosswalk -- for later reference
	restore
	keep Township Range Section Well_Serial_Num Permit_Date Spud_Date Original_Completion_Date
	duplicates drop
	duplicates report Well_Serial_Num
	sort Well_Serial_Num Township Range Section
	count if missing(Well_Serial_Num)
	compress
	save "${outdir}/Serial_Unit_xwalk_Hay_HBP.dta", replace
	
	
* Next, non-Haynesville wells:
use "`TRS_master_wells'", clear

	* Count of Haynesville wells (including ones that are only permitted: not very useful b/c permits)
	egen has_HHayWellCount = max(is_haynesville==1), by(Township Range Section)
	keep if ~is_haynesville

	* Looks at field names
	tab Field_Name if sand_cottonvalley, sort

	* Whether producing in a given year
	gen Pr_first_prod_year = real(substr(Pr_first_prod_date,7,4))
	gen Pr_last_prod_year  = real(substr(Pr_last_prod_date ,7,4))

	forvalues year=2000(1)2008 {
		gen prod`year' = Pr_first_prod_year<=`year' & Pr_last_prod_year>=`year' & ~missing(Pr_first_prod_year) & ~missing(Pr_last_prod_year)
	}
	forvalues year=2000(1)2008 {
		egen NHay_prod`year' = total(prod`year'), by(Township Range Section)
	}

	* first date spudded, both for all wells, productive wells, and particular-formation wells
		egen NHay_spudpre2007 = total((year(Spud_Date)<=2007)), by(Township Range Section)
		egen NHay_spud_2000_2007 = total((year(Spud_Date)<=2007) & year(Spud_Date)>=2000), by(Township Range Section)

			gen Spud_Date_post2000 = Spud_Date if year(Spud_Date)>=2000 & year(Spud_Date)<.
		egen NHay_firstspud = min(Spud_Date_post2000), by(Township Range Section)
			gen Spud_Date_post2000_prod =  Spud_Date if year(Spud_Date)>=2000 & year(Spud_Date)<. & ~missing(Pr_first_prod_year)
		egen NHay_firstspud_prod = min(Spud_Date_post2000_prod)
			gen Spud_Date_CV = Spud_Date if year(Spud_Date)>=2000 & year(Spud_Date)<. & sand_cottonvalley
		egen NHay_firstspud_CV = min(Spud_Date_CV), by(Township Range Section)
			gen Spud_Date_HOSS = Spud_Date if year(Spud_Date)>=2000 & year(Spud_Date)<. & sand_hosston
		egen NHay_firstspud_HOSS = min(Spud_Date_HOSS), by(Township Range Section)
			gen Spud_Date_NAC = Spud_Date if year(Spud_Date)>=2000 & year(Spud_Date)<. & sand_nacatoch
		egen NHay_firstspud_NAC = min(Spud_Date_NAC), by(Township Range Section)
			gen sand_OTHER = ~sand_cottonvalley & ~sand_hosston & ~sand_nacatoch
			gen Spud_Date_OTH = Spud_Date if year(Spud_Date)>=2000 & year(Spud_Date)<. & sand_OTHER
		egen NHay_firstspud_OTH = min(Spud_Date_OTH), by(Township Range Section)

	* Collapses and saves
		keep Township Range Section NHay_prod200? NHay_spudpre2007 NHay_spud_2000_2007 NHay_firstspud*
		duplicates drop
		duplicates report Township Range Section
	
	* merges:
		merge 1:1 Township Range Section using "`hay_well_sum'"
		drop _merge
		erase "`hay_well_sum'"
		
