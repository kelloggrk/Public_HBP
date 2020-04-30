
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

use "${outdir}/Leases/Clustering/clustered_at_90th_percentile_final.dta", clear
gen collapse_exprdate = original_exprdate

* Lease start date:
gen leaseStart = effdate
gen exprym = ym(year(collapse_exprdate),month(collapse_exprdate))
gen exprday = day(collapse_exprdate)
replace leaseStart = mdy(month(dofm(exprym - termmo)), exprday, year(dofm(exprym - termmo))) if mi(leaseStart)
replace leaseStart = instdate if mi(leaseStart)
drop exprym exprday

* Lease expiration date:
gen leaseExpire = collapse_exprdate
gen startym = ym(year(leaseStart),month(leaseStart))
gen startday = day(leaseStart)
replace leaseExpire = mdy(month(dofm(startym + termmo)), startday, year(dofm(startym + termmo))) if mi(leaseExpire)
drop startym startday

* Lease extension end date:
gen exprym = ym(year(leaseExpire),month(leaseExpire))
gen exprday = day(leaseExpire)
gen leaseExpireExt = mdy(month(dofm(exprym + exttermmo)), exprday, year(dofm(exprym + exttermmo))) if optext == 1
drop exprym exprday

* Make this equal to original expiry if no extension option in lease
* or no extension length information in lease
replace leaseExpireExt = leaseExpire if optext == 0 | exttermmo == 0


tab insttype
keep if inlist(insttype,"LEASE","MEMO OF LEASE","LEASE EXTENSION","LEASE AMENDMENT")

drop if leaseStart < td(01jan2002) | leaseStart > td(31dec2015)

drop if instdate == collapse_exprdate
drop if leaseStart == leaseExpire




egen TRS_count = total(1), by(leaseGroup)
gen area_new = area_final

count if missing(area) // 12,989
egen group_TRS = group(township range section)


* Calculate total acreage in effect by each quarter. New as of July 2019 *
forvalues year=2002/2015 {
	forvalues quarter = 1/4 {
		if `quarter'==1 local month jan
		if `quarter'==2 local month apr
		if `quarter'==3 local month jul
		if `quarter'==4 local month oct
		local date 01`month'`year'
		local i = td(`date')
	
		* Acres leased where we assume that extension option is exercised
		egen acres_leasedEXT_`year'Q`quarter' = ///
			total(area_new * (leaseStart<=`i' & leaseExpireExt>=`i')), ///
			by(township range section)
	
		* Acres leased where we do not assume that extension option is exercised
		egen acres_leased_`year'Q`quarter' = ///
			total(area_new * (leaseStart<=`i' & leaseExpire>=`i')), ///
			by(township range section)
	
	
	}
}
	


* mean, median and percentile dates, acreage weighted -- not possible to do with egen, therefore write a loop
	foreach var of varlist leaseStart leaseExpire leaseExpireExt {
		foreach type in Mean Med P10 P25 P75 First {
			qui gen `var'`type' = .
		}
	}
	qui gen leaseExpireExtFirst_WhenStarted = .
	qui sum group_TRS
	local trs_max = r(max)



	* Note: This loop takes a longish time to run:
	forvalues i=1/`trs_max' {
		if `i'/30 == floor(`i'/30) {
			local thingtodisplay = round(`i'/`trs_max'*100,.1)
			di `thingtodisplay' "% " _continue
		}

		* notice that by using aweights, we are implicitly dropping
		* observations where area_new=0 or area_new=.
		qui summarize leaseStart if group_TRS==`i' [aweight=area_new], detail
		qui replace leaseStartFirst = r(min) if group_TRS==`i'

		qui summarize leaseExpire if group_TRS==`i' [aweight=area_new], detail
		qui replace leaseExpireMean = r(mean) if group_TRS==`i'
		qui replace leaseExpireMed = r(p50) if group_TRS==`i'
		qui replace leaseExpireP10 = r(p10) if group_TRS==`i'
		qui replace leaseExpireP25 = r(p25) if group_TRS==`i'
		qui replace leaseExpireP75 = r(p75) if group_TRS==`i'
		qui replace leaseExpireFirst = r(min) if group_TRS==`i'

		qui summarize leaseExpireExt if group_TRS==`i' [aweight=area_new], detail
		qui replace leaseExpireExtMean = r(mean) if group_TRS==`i'
		qui replace leaseExpireExtMed = r(p50) if group_TRS==`i'
		qui replace leaseExpireExtP10 = r(p10) if group_TRS==`i'
		qui replace leaseExpireExtP25 = r(p25) if group_TRS==`i'
		qui replace leaseExpireExtP75 = r(p75) if group_TRS==`i'

		qui replace leaseExpireExtFirst = r(min) if group_TRS==`i'

		* Finds the start date for the leases where leaseExpireExtFirst = leaseExpireExt
		qui gen is_first_to_expire = leaseExpireExtFirst == leaseExpireExt & ///
			~missing(leaseExpireExtFirst) if group_TRS==`i'
		
		qui summarize leaseStart if is_first_to_expire==1 & group_TRS==`i' [aweight=area_new]
		qui replace leaseExpireExtFirst_WhenStarted = round(r(mean)) if group_TRS==`i'
		
		drop is_first_to_expire
		
		
	}

* Calculates total new lease acreage leased both before the expiration date of the
* first-lease-to-expire (when including extensions) as well as after
egen acres_leased_preExtExp = ///
			total(area_new * (leaseStart<=leaseExpireExtFirst)), ///
			by(township range section)
egen acres_leased_postExtExp = ///
			total(area_new * (leaseStart>leaseExpireExtFirst & ~missing(leaseStart))), ///
			by(township range section)

* mean royalty
	gen royalty_alt = royalty
	replace royalty_alt = . if royalty==0
	egen tot_royalty = total(royalty_alt*area_new*(leaseStart<=leaseExpireFirst & leaseExpire>=leaseExpireFirst & ~missing(royalty_alt))), by(township range section)
	egen tot_acre =    total(            area_new*(leaseStart<=leaseExpireFirst & leaseExpire>=leaseExpireFirst & ~missing(royalty_alt))), by(township range section)
	gen av_royalty_firstExpire = tot_royalty/tot_acre
	drop tot_royalty tot_acre

	egen tot_royalty = total(royalty_alt*area_new*(leaseStart<=leaseExpireExtFirst & leaseExpire>=leaseExpireExtFirst & ~missing(royalty_alt))), by(township range section)
	egen tot_acre =    total(            area_new*(leaseStart<=leaseExpireExtFirst & leaseExpire>=leaseExpireExtFirst & ~missing(royalty_alt))), by(township range section)
	gen av_royalty_firstExpireExt = tot_royalty/tot_acre
	drop tot_royalty tot_acre

	sum av_royalty* if tag_TRS, detail

/* Calculates acreage of lease starts by year and month */
qui describe, varlist
forvalues year=2002/2015 {
	local yr = substr("`year'",3,2)

		egen unitLeaseStart_y`yr' = total(area_new * (year(leaseStart)==`year')), by(township range section)
		label var unitLeaseStart_y`yr' "Total acreage with leasing starting in `year'"
		
		egen unitLeaseExp_y`yr' = total(area_new * (year(leaseExpire)==`year')), by(township range section)
		label var unitLeaseExp_y`yr' "Total acreage with lease primary terms expiring in `year'"

		egen leaseExpireExt_y`yr' = total(area_new * (year(leaseExpireExt)==`year')), by(township range section)
		label var leaseExpireExt_y`yr' "Total acreage with lease primary terms + any extension expiring in `year'"

}
order `r(varlist)' unitLeaseStart_* unitLeaseExp_* leaseExpireExt_* 





format leaseStartMean-leaseExpireExtFirst %td

/* Generate a variable roughly capturing the number of unique leases and average lease size */
	egen leaseUnitTag = tag(leaseGroup), missing
	egen grantorUnitTag = tag(section township range grantor), missing
	bys township range section: egen unitNumLeases = sum(leaseUnitTag)
	bys township range section: egen unitNumGrantors = sum(grantorUnitTag)
	drop leaseUnitTag grantorUnitTag


* Collapse to the unit level
	keep township range section unitNumLeases unitNumGrantors leaseStartMean-leaseExpireExtFirst  ///
		leaseExpireExtFirst_WhenStarted ///
		unitLeaseStart_* unitLeaseExp_* leaseExpireExt_*  av_royalty_firstExpire    ///
		acres_leased_????Q? acres_leased_preExtExp acres_leased_postExtExp
		

	duplicates drop
	duplicates report township range section
