/*****************************************************
 Read in DI completion data and production "header" data
 Clean and save as dta
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
global welldir = "$dbdir/IntermediateData/Louisiana/Wells"
global codedir = "$hbpdir/code/build/Louisiana"
global logdir = "$codedir/LogFiles"

log using "$logdir/clean_DI_completion_production_data_log.txt", replace text

/************* Clean and examine DI completion data **************/

	use "${welldir}/louisiana_completions_DI.dta", clear
	
	* keeps only observations in Haynesville parishes
	keep if inlist(county,"Bienville","Bossier","Caddo","De Soto","Natchitoches","Red River","Sabine","Webster")
	keep serialno spuddate compdate drillstart drilltype
	duplicates drop
	
	* why duplicate serial numbers?
	duplicates report serialno
	egen tag_serialno = tag(serialno)
	egen serialno_countobs = total(1), by(serialno)
	tab serialno_countobs if tag_serialno // up to 9, but 98.5% are 3 or fewer
	
	* makes drill start date a date variable
	tostring drillstart, replace
	gen drillstart2 = mdy(real(substr(drillstart,5,2)),real(substr(drillstart,7,2)),real(substr(drillstart,1,4)))
	format drillstart2 %td
	codebook drillstart2 // 10th perc in 2001; 90th perc in 2008
	drop drillstart
	rename drillstart2 drillstart
	
	* however, drillstart is basically the same as spud, so drop it eventually
	* looks at spud date
	replace spuddate = -99999 if mi(spuddate)
	bys serialno: egen sd = sd(spuddate)
	sort serialno spuddate
	list serialno spuddate if sd > 0 & !mi(sd), clean sepby(serialno)
	// while some variation, none for cases where spud dates are recent (e.g., 2000 or later)
	drop sd
	
	* completion dates
	replace compdate = -99999 if mi(compdate)
	egen sd = sd(compdate), by(serialno)
	sort serialno compdate
	gen pos_sd = sd>0 & sd<.
	sum pos_sd if tag_serialno // 33.7% have multiple completion dates
	drop sd pos_sd
	replace compdate = . if compdate==-99999
	
	* variation in drilltype
	foreach var of varlist drilltype  {
		egen tag_within = tag(serialno `var')
		egen count_within = total(tag_within), by(serialno)
		tab count_within if tag_serialno
			// drilltype: 0.02% are serial numbers where there are both horizontal and vertical completions listed
			// welltype: 0.86% have 2 or more welltypes listed. Not sure what these codes are anyways
		drop tag_within count_within
	}
	
	* drops observations where all completions / spuds were pre-2000
	egen max_compdate = max(compdate), by(serialno)
	egen max_spuddate = max(spuddate), by(serialno)
	drop if max_compdate < td(01jan2000) | max_spuddate < td(01jan2000)
	drop max_compdate max_spuddate
	tab serialno_countobs if tag_serialno // Now only up to 6, up to 9, but 98.4% are 4 or fewer
	
	* looks at max, min comps, range of them
	foreach var of varlist spuddate compdate drilltype drillstart {
		egen tag_within = tag(serialno `var')
		egen count_within = total(tag_within), by(serialno)
		di "`var'"
		tab count_within if tag_serialno
		drop tag_within count_within
	}
	
	* no variation in drilltype
	* up to 4 different values for drillstart, but drillstart is basically the same as spud
	* reshapes to wide to have one observation per serialno
	keep serialno spuddate compdate drilltype
	duplicates drop
	bysort serialno (spuddate compdate drilltype ): gen j = _n
	reshape wide compdate , i(serialno spuddate drilltype) j(j)
	gen from_DIComp = 1
	foreach var of varlist drilltype spuddate compdate? {
		rename `var' DIC_`var'
	}
	order from_DIComp serialno DIC_*
	rename serialno Well_Serial_Num
	duplicates report
	tempfile DICompletion
	save "`DICompletion'"
	save "$dnrdir/DICompletion.dta", replace


* Production entity_id API_Num match -- NOTICE THIS ONE HAS MORE API_Nums than in the header file
	insheet using "${dbdir}/RawData/orig/Louisiana/DI/ProductionData/HPDIAPINos.csv", clear
		rename all_api_no API_Num
		tostring API_Num, replace format(%20.0f)
		codebook API_Num // length is 12
		codebook API_Num if length(API_Num)==12
		codebook API_Num if length(API_Num)!=12
		replace API_Num = API_Num+"00" if length(API_Num)==12
		replace API_Num = "" if API_Num=="0"
		
	save "${dnrdir}/HPDIAPINos.dta", replace
	
	
* Production header data
	* Note that all_api_no found in HPDIAPINos.csv are the same as api_no in HPDIHeader.csv
	insheet using "${dbdir}/RawData/orig/Louisiana/DI/ProductionData/HPDIHeader.csv", comma names clear
		duplicates report api_no if length(api_no)>1 // not unique
		duplicates report entity_id // unique
		replace api_no = subinstr(api_no,"-","",.)
		replace api_no = api_no+"00" if length(api)!=1

	replace county = trim(subinstr(county,"(LA)","",.))
	gen is_haynesville_county = inlist(county,"WEBSTER","SABINE","RED RIVER", ///
		"NATCHITOCHES","DE SOTO","CADDO","BOSSIER","BIENVILLE")
	gen is_haynesville_location = ///
			( inlist(twp,"07N","08N","09N") |  ///
			 inlist(twp,"N19","10N","11N","12N","13N","14N","15N")  | ///
			 inlist(twp,"16N","17N","18N","19N","20N","21N")) &                ///
			(inlist(rng,"8W","08W","9W","09W","10W","11W","12W","13W") | ///
			 inlist(rng,"14W","15W","16W","17W","18W","19W", "07W"))
	tab is_haynesville_county is_haynesville_location
	tab county if is_haynesville_location==1 & is_haynesville_county==0 // CLAIBORNE--not too far from Shreveport
	keep if length(api)>1
	duplicates report api

	encode pden_type, gen(pden_typeR)


	keep entity_id pden_typeR api_no twp rng section is_haynesville_* ///
		comp_date spud_date liq_daily gas_daily liq_cum gas_cum ///
		first_liq first_gas first_wtr first12_liq first12_gas first12_wtr ///
		first_prod_date last_prod_date latest_liq latest_gas latest_wtr ///
		peak_gas peak_liq first6_liq first6_gas first6_wtr ///
		first24_liq first24_gas first24_wtr peak_liq_daily peak_gas_daily

	duplicates report api_no // some duplicates
	*keep if is_haynesville_location
	
	duplicates report api_no // some duplicatese still
	* However API_Num=="17015248450000" is the only one with real problems
	* where we find that it is appearing multiple times in the production header data
	* and is also associated with multiple serial numbers in the ONG data
	* browse  if api_no=="17015248450000"
	/*
		prod_comp_date	prod_spud_date
						14apr2014
		10sep2014	    14apr2014

		first_prod_date	last_prod_date
		01-01-2015		01-01-2015
		09-01-2014		10-01-2015
		*/

	* based on looking at below for the rest of the data where api_no=="17015248450000"
	* seems clear that we should drop the cases where shows no range in production
	* and where prod_comp_date of the production header data matches DIC_compdate1 (10sep2014)

	drop if api_no=="17015248450000" & missing(comp_date)
	
	* gets rid of cases where there are multiple api numbers reported. Shouldn't matter for
	* Haynesville (already got that one dropped)
	egen count_api_no = total(1), by(api_no)
	duplicates report api_no
	duplicates report api_no if is_haynesville_location
	duplicates report api_no if is_haynesville_county
	duplicates report api_no if gas_cum>0 & gas_cum<. & (liq_cum<=0 | liq_cum==.)
	duplicates report api_no if gas_cum>0 & gas_cum<. & (liq_cum<=0 | liq_cum==.) & (is_haynesville_location | is_haynesville_county)
		// still some duplicates, but much fewer
	sort entity_id api_no
	by entity_id (api_no): gen to_keep_for_unique_API = _n==1
	
	/*
	sort api_no
	egen tag_api = tag(api_no)
	tab count_api_no if tag_api // 96.99% have only one observation
	*/

	* how different are these observations
	*ds, has(type numeric)

	* reformats and renames so that these can all be looked at together
	foreach var of varlist comp_date spud_date {
		gen Pr_`var' = mdy(real(substr(`var',1,2)),real(substr(`var',4,2)),real(substr(`var',7,4)))
		format Pr_`var' %td
		drop `var'
	}
	ds api_no Pr_* count_api_no entity_id, not
	foreach var of varlist `r(varlist)' {
		rename `var' Pr_`var'
	}
	rename api_no API_Num

	gen from_Prod_header = 1
	order from_Prod_header API_Num count_api_no Pr_*date Pr_pden_typeR Pr_twp Pr_rng Pr_section
	save "$dnrdir/Prod_header.dta", replace

	capture log close
	
