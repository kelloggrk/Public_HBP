*************************************************
*
* Code for dealing with area downweighting prior to clustering
* The main idea here is to group the leases into different
* groups based on similar traits. We go through those groups
* and find proximity measures seeing whether actually grouping
* leases up that way gets us leases that are close together
* geographically or not.
*
* We create three groups, group A, B, and C. Group C is a final
* group and we actually go ahead an downweight these and never end
* up clustering those leases downstream. Group C will identify
* whether a group of leases was likely all leased at the same time
* with the same grantee and similar proximity and very large area.*
*
* The other main issue addressed in this file is that we identify
* likely duplicates here that sometimes occur across units
* (groups A and B). Those will never be caught within the clustering
* algorithm because we only cluster within unit. In this file we go ahead
* and downweight those leases only across units and not within.
*
* The resulting dataset is fed into clustering which will cluster
* all group A, B, and non-grouped leases.
*
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
global leasedir = "$dbdir/IntermediateData/Louisiana/Leases"
global unitdir = "$dbdir/IntermediateData/Louisiana/DescriptiveUnits"
global codedir = "$hbpdir/code/build/Louisiana"
global logdir = "$codedir/Logfiles"

// Create a plain text log file to record output
// Log file has same name as do-file
log using "$logdir/area_downweighting_log.txt", replace text

****
use "$leasedir/louisiana_leases_DI_csvs_cleaned.dta", clear

* Generate id upfront so sort order isn't arbitrary
gen ID_drop = _n

drop if missing(area)

****
*Code to categorize different types of acreage
gen mult_40 = mod(area,40)==0
gen mult_5 = mod(area,5)==0
gen decimal_1 = mod(area,1)!=0
gen decimal_2 = mod(area*10,1)!=0
gen     area_size_bin = 1 if area<40
replace area_size_bin = 2 if area>=40 & area<320
replace area_size_bin = 3 if area>=320 & area<640
replace area_size_bin = 4 if area>=640 & area<1920
replace area_size_bin = 5 if area>=1920 & area<.
* This is flexible:
* first whether has unusual enough acreage for case 2 / B below
gen unusual_acreage_B = (decimal_2 & area_size_bin==1) | ///
                    (decimal_1 & area_size_bin==2) | ///
                    (~mult_5   & area_size_bin==3) | ///
                    (~mult_40  & area_size_bin==4) | ///
                area_size_bin==5
* next, whether has unusual enough acreage for case 3 / C below
gen unusual_acreage_C = (decimal_2 & area_size_bin==1) | ///
                    (decimal_1 & area_size_bin==2) | ///
                    (~mult_5   & area_size_bin==3) | ///
                    (~mult_40  & area_size_bin==4) | ///
                area_size_bin==5

replace township = "-"+township if strpos(township,"S")
destring township, ignore("SN") replace
replace range = "-"+range if strpos(range,"W")
destring range, ignore("EW") replace
destring section, replace

tempfile  downweighted_lease_data
save "`downweighted_lease_data'"
use "${unitdir}/master_units.dta"

ren total_area total_section_area
keep township range section total_section_area
duplicates drop

merge 1:m township range section using "`downweighted_lease_data'", nogen keep(2 3)
replace total_section_area=640 if total_section_area==.


*********
* Cleaning up recordno prior to group_A
count if missing(page) & ~missing(vol) & missing(recordno)
count if missing(recordno)
count if ~missing(vol) & ~missing(page) & missing(recordno)
tostring recordno, replace
replace recordno = "" if recordno=="." // dealing with missing cases -- missing real (.) will get converted to string (".") -- which Stata considers to not be missing
gen recordno_old = recordno
replace recordno = string(vol,"%13.0f") + "/" + string(page) if ~missing(vol) & ~missing(page) & missing(recordno)


******
* Program to look at how close observations are within a group (location-wise):
capture program drop proximity_measure
program define proximity_measure
	tempfile og_leases
	save "`og_leases'"
	tempfile relevant_leases
	qui egen maxlat_`1' = max(latitude), by(group_`1')
	qui egen minlat_`1' = min(latitude), by(group_`1')
	qui egen maxlon_`1' = max(longitude), by(group_`1')
	qui egen minlon_`1' = min(longitude), by(group_`1')
	qui gen lat_spread`1' = maxlat_`1'-minlat_`1'
	qui gen lon_spread`1' = maxlon_`1'-minlon_`1'
	qui keep if lat_spread`1' > 0 | lon_spread`1' > 0
	qui drop if latitude == . | longitude == .
	qui drop if area == . | area == 0
	qui drop if missing(group_`1')
	qui drop maxlat_`1' minlat_`1' maxlon_`1' minlon_`1' lat_spread`1' lon_spread`1'
	qui gen obsnum = _n 			//# helps to quickly ID unique rows
	qui save "`relevant_leases'"
	qui ren latitude latitude1
	qui ren longitude longitude1
	qui ren obsnum obsnum1
	qui joinby group_`1' using "`relevant_leases'"
	qui drop if obsnum==obsnum1 // drops cases where self-matches
	qui geodist latitude longitude latitude1 longitude1, gen(dist_`1')
	qui egen minproximity_`1' = min(dist_`1'), by(group_`1' obsnum)		//# for computing max of min proximity
	qui egen maxminproximity_`1' = max(minproximity_`1'), by(group_`1') //# for computing max of min proximity
	qui egen maxproximity_`1' = max(dist_`1'), by(group_`1') 			//# renamed variable from proximity_`1' to maxproximity_`1'
	qui keep group_`1' maxproximity_`1' maxminproximity_`1'
	qui duplicates drop
	qui merge 1:m group_`1' using "`og_leases'", nogen

	* Summarizes results
	qui egen tag_`1' = tag(group_`1')
	qui egen count_`1' = total(1) if ~missing(group_`1'), by(group_`1')
	sum *proximity*`1' if tag_`1' & count_`1'>1, detail
	qui drop tag_`1' count_`1'

end

****************************
* VaryingStartDates
* Runs code to determine what leases if any are likely extensions
* ends with
* replace group = group+"E1" if is the first extension
* replace group = group+"E2" if is the second extension
* drop if is a lease that we think is rogue

* clean up lease start dates
gen startdate = effdate if ~missing(effdate)
replace startdate = instdate if missing(effdate)
format startdate %td

capture program drop VaryingStartDates
program define VaryingStartDates
	local AfterInst 183
	local BeforeExp 183
	
	*Step 0:
	replace group_`1' = group_`1'+" " if ~missing(group_`1')
	
	*Step 1: Finds earliest leases
	qui egen firststart = min(startdate) if ~missing(group_`1'), by(group_`1')
	
	*Step 2: Finds all leases that start within `AfterInst' days of the first lease
	qui gen flag_among_first = 1 if startdate>=firststart & startdate<=firststart+`AfterInst' & ~missing(group_`1')
	
	*Step 3: Finds the typical lenth of leases that have flag_among_first
	qui gen leaselength_among_first = cluster_exprdate - startdate if flag_among_first & ~missing(group_`1')
	qui egen averageleaselength = median(leaselength_among_first) if ~missing(group_`1'), by(group_`1')
	qui replace averageleaselength = floor(averageleaselength) if ~missing(group_`1')     // in case has decimal points
	
	*Step 4: Marks anything that starts too late as likely a separate lease
	qui gen first_pred_expr_date = firststart + averageleaselength if ~missing(group_`1')
	qui replace group_`1' = group_`1' + "E" if startdate>first_pred_expr_date - `BeforeExp' & startdate>firststart+`AfterInst' & startdate<. & ~missing(group_`1')
	drop firststart flag_among_first leaselength_among_first averageleaselength first_pred_expr_date

	* Now does a to circle through all of the remaining cases
	local Estring = "E"
	qui count if strpos(group_`1',"`Estring'")
	local boolean = r(N)
	while `boolean'>0 {
		qui gen has_Estring = strpos(group_`1',"`Estring'")!=0 & ~missing(group_`1')
		// e.g., if `Ecount' = 4, will create EEEE
		* Step 1:
		qui egen firststart = min(startdate) if has_Estring, by(group_`1')
		* Step 2
		qui gen flag_among_first = 1 if startdate>=firststart & startdate<=firststart+`AfterInst' & has_Estring
		*Step 3
		qui gen leaselength_among_first = cluster_exprdate - startdate if flag_among_first & has_Estring
		qui egen averageleaselength = median(leaselength_among_first) if has_Estring, by(group_`1')
		qui replace averageleaselength = floor(averageleaselength) if has_Estring    // in case has decimal points
		*Step 4: Marks anything that starts too late as likely a separate lease
		qui gen first_pred_expr_date = firststart + averageleaselength if has_Estring
		qui replace group_`1' = group_`1' + "E" if startdate>first_pred_expr_date - `BeforeExp' & startdate>firststart+`AfterInst' & startdate<. & has_Estring & ~missing(group_`1')
		drop firststart flag_among_first leaselength_among_first averageleaselength first_pred_expr_date has_Estring

		* checks Boolean
		local Estring = "`Estring'"+"E"
		qui count if strpos(group_`1', "`Estring'")
		local boolean = r(N)

	}

end

* quick diagnostic program to look at total number of observations within each group
program define check_count
	qui egen tag_`1' = tag(group_`1') if ~missing(group_`1')
	qui egen count_`1' = total(1) if ~missing(group_`1'), by(group_`1')
	sum count_`1' if tag_`1' & count_`1'>1, detail
	drop tag_`1' count_`1'
end

* quick diagnostic program to look at "extensions" guessed at from VaryingStartDates
program define check_Es
	quietly {
		egen tag_`1' = tag(group_`1') if ~missing(group_`1')
		gen group_orig_`1' = trim(word(group_`1', 1))
		gen extension_`1'   = trim(word(group_`1', 2))
		gen no_E    = strpos(extension_`1',"E")==0
		gen is_E    = strpos(extension_`1',"E"  ) !=0 & strpos(extension_`1',"EE"  )==0
		gen is_EE   = strpos(extension_`1',"EE" ) !=0 & strpos(extension_`1',"EEE" )==0
		gen is_EEE  = strpos(extension_`1',"EEE") !=0 & strpos(extension_`1',"EEEE")==0
		egen has_0   = max(no_E  ), by(group_orig_`1')
		egen has_E   = max(is_E  ), by(group_orig_`1')
		egen has_EE  = max(is_EE ), by(group_orig_`1')
		egen has_EEE = max(is_EEE), by(group_orig_`1')
		gen has_0_E = has_0 & has_E
		gen has_E_EE = has_E & has_EE
		gen has_EE_EEE = has_EE & has_EEE
	}
	sum has_0 has_E has_EE has_EEE has_*_E* if tag_`1'
	qui drop tag_`1' group_orig_`1' extension_`1' no_E is_E* has_0 has_E* has_*_E*
end

*****
* program to count sections
cap program drop count_sections
program define count_sections
	* `1' is the group variable and is the argument
	egen tag_group_section = tag(`1' township range section)
	egen total_section_in_group = total(tag_group_section), by(`1')
	egen total_obs_in_group = total(1), by(`1')
	gen ratio_obs_2_sections = total_obs_in_group/total_section_in_group
	egen tag_group = tag(`1')
	sum ratio_obs_2_sections if tag_group & ~missing(`1'), detail

	drop tag_group_section total_section_in_group total_obs_in_group ratio_obs_2_sections tag_group
end





********
* Working through the various cases:
* case 1 / group A (by county and record number)

egen group_A = group(county recordno) if ~missing(recordno)
tostring group_A, replace
replace group_A = "" if group_A=="." 
replace group_A = trim(group_A)

check_count A
proximity_measure A
VaryingStartDates A
check_Es A
check_count A
count_sections group_A

* case 2 / group B (by grantor, grantee, and area)
egen group_B = group(grantor alsgrantee area), missing
tostring group_B, replace
replace group_B = "" if group_B=="." 

check_count B
proximity_measure B
VaryingStartDates B
check_Es B
check_count B
count_sections group_B

* case 3 / group C (by just grantee and area)
* this case is the one we ultimately want to use
egen group_C = group(alsgrantee area) if unusual_acreage_C
tostring group_C, replace
replace group_C = "" if group_C=="." 

check_count C
VaryingStartDates C
check_Es C
check_count C
count_sections group_C

**************
* Now cleans up groups based on what we've learned from group_A, group_B, and group_C analysis


* Because VaryingStartDates and proximity_measure can potentially break these into smaller groups, need to
* regenerate count_*, tag_*, and *** variables

foreach j in A B C {
	egen count_`j' = total(1) if ~missing(group_`j'), by(group_`j')
	bys group_`j' (ID_drop): gen tag_`j' = (_n==1) * (~missing(group_`j'))
}

* Denotes what group it is:
gen group_final = "C"+group_C     if ~(missing(group_C)|count_C==1 )
replace group_final = "A"+group_A if  (missing(group_C)|count_C==1) & ~(missing(group_A)|count_A==1)
replace group_final = "B"+group_B if  (missing(group_C)|count_C==1) &  (missing(group_A)|count_A==1) & ~(missing(group_B)|count_B==1)

egen count_final = total(1) if ~missing(group_final)
bys group_final (ID_drop): gen tag_final = (_n==1) * (~missing(group_final))

* Counts number of sections within a group -- uses the total number of sections to downweight...
*  for group_A and group_B cases, but not group_C
*  This is because group_A and group_B cases will be further modified by agglomerative clustering
*  but group_C will be an alternate to agglomerative clustering
bys group_final township range section (ID_drop): gen tag_TRS = (_n==1)*!mi(group_final)
egen count_TRS_in_group = total(tag_TRS), by(township range section)

* computes total area over all observations and then over all sections within a group:
egen total_group_area_final     = sum(total_section_area)         if ~missing(group_final), by(group_final)
egen total_group_area_final_TRS = sum(total_section_area*tag_TRS) if ~missing(group_final), by(group_final)

* computes weight:
gen weight_final     = total_section_area/total_group_area_final     if substr(group_final,1,1)=="C"
replace weight_final = total_section_area/total_group_area_final_TRS if inlist(substr(group_final,1,1),"A","B")
replace weight_final = 1 if missing(weight_final) & missing(group_final)
replace weight_final = 1 if missing(weight_final)

* revised weight
gen area_revised = area*weight_final

// NEEDS TO BE DEFINED FOR ONLY CASES THAT ARE NOT GROUP-C

sort township range section area
egen group_trsa = group(township range section area), missing
// should this be based on area_revised instead? Probably not


bys group_trsa (ID_drop): gen tag_trsa = (_n==1)
egen count_trsa = total(1), by(group_trsa)

egen section_reported_area = sum(area_revised*tag_trsa), by(township range section)
bys township range section (ID_drop): gen tag_section_id = (_n==1)

gen tag_area_reported_too_big = 0
replace tag_area_reported_too_big = 1 if section_reported_area > total_section_area
sum tag_area_reported_too_big if tag_section_id

sort ID_drop
gen unique_id = _n
egen section_id = group(township range section)
drop ID_drop

save "${leasedir}/louisiana_leases_csvs_preliminary_downweight.dta", replace
capture log close
exit, clear
