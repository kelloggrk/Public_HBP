***************************************************************
* Merges Haynesville and all well data to Haynesville units
* using well lateral intersection info created in 
* spatial_haynesville_bottom_lateral_sections.R
***************************************************************

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
global rawdir = "$dbdir/RawData/orig/Louisiana/DI/ProductionData"
global outdir = "$dbdir/IntermediateData/Louisiana"
global codedir = "$hbpdir/code/build/Louisiana"
global logdir = "$codedir/Logfiles"
global scratchfigdir = "$dbdir/Scratch/neighbor_explore_figures"

log using "$logdir/clean_well_laterals_x_units_log.txt", replace text

***************************************************************

use "${outdir}/Wells/master_wells.dta", clear

* Restricting it to Haynesville wells that are completed and have well leg info
count
count if is_haynesville==1
count if is_haynesville==1 & Original_Completion_Date!=.
count if is_haynesville==1 & Original_Completion_Date!=. & weighted_lon!=.
count if is_haynesville==1 & Original_Completion_Date!=. & weighted_lon!=. & Pr_has_prod_data==1
count if is_haynesville==1 & Original_Completion_Date!=. & weighted_lon!=. & Pr_has_prod_after_2010==1

*** NOTE: THIS IS THE SAME RESTRICTION AS IN collapse_wells2units.do ~line 65 ***
*** (Keep these consistent) ***
keep if is_haynesville==1 & Original_Completion_Date!=. & weighted_lon!=. & Pr_has_prod_data==1
count

duplicates report Well_Serial_Num

tempfile master_hay_wells_no_units
save "`master_hay_wells_no_units'", replace


********************************************************************************

use "${outdir}/DescriptiveUnits/longest_legs_to_units.dta", clear

bysort WELL_SERIA: egen desired_rank = rank(isect_length), unique

* this is for the well to section matching, we only consider the lateral as
* holing a unit by production if it intersects with the unit by more than 300 m
count								
count if desired_rank>=2			
count if isect_length<300			
count if desired_rank>=2 & isect_length<300
drop if desired_rank>=2 & isect_length<300
count

ren WELL_SERIA Well_Serial_Num

ren EFFECTIVE_ effective_date

replace effective_date=. if effective_date == 0

duplicates report Well_Serial_Num
duplicates report Well_Serial_Num sectionFID

* match up only the laterals to the haynesville wells
merge m:1 Well_Serial_Num using "`master_hay_wells_no_units'"
keep if _merge==3
drop _merge

* duplicates checks
duplicates report Well_Serial_Num
duplicates report Well_Serial_Num sectionFID

* save the laterals x section data for just the haynesville wells
drop weighted_lon weighted_lat SECTN TOWNSHIP RANGE

tempfile haynesville_wells_lateral_units
save "`haynesville_wells_lateral_units'", replace


	

********************************************************************************
	
* Merges in well leg midpoint info to data
use "${outdir}/DescriptiveUnits/weighted_leg_centroids_to_units.dta", clear
duplicates report WELL_SERIA

ren sectionFID sectionFID_mid // this is the sectionFID of the 
ren WELL_SERIA Well_Serial_Num

merge 1:m Well_Serial_Num using "`haynesville_wells_lateral_units'"
keep if inlist(_merge,2,3) 
drop _merge

* create the wells x section dataset for haynesville only wells
save "${outdir}/DescriptiveUnits/haynesville_wells_x_units.dta", replace


********************************************************************************
* Now for all wells -- both Haynesville and not -- uses tophole and bottom hole

use "${outdir}/DescriptiveUnits/bottomholes_to_units.dta", clear
drop EFFECTIV // this is a date variable that we don't need
	 
merge m:1 WELL_SERIA sectionFID SECTN TOWNSHIP RANGE using "${outdir}/DescriptiveUnits/topholes_to_units.dta"
gen has_tophole_location = inlist(_merge,2,3)
gen has_bottomhole_location = inlist(_merge,1,3)
drop _merge
drop EFFECTIV // this is a date variable that we don't need

ren WELL_SERIA Well_Serial_Num
merge m:1 Well_Serial_Num using "${outdir}/Wells/master_wells.dta"
drop if _merge==1
drop _merge

* tophole, bottomhole matching for all wells in the dataset
save "${outdir}/DescriptiveUnits/all_wells_x_units.dta", replace

duplicates report Well_Serial_Num
duplicates report Well_Serial_Num township range section

capture log close
exit

