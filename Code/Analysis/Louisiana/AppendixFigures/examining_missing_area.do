* Code that outputs a figure showing the frequency of lease observations
* with zero or missing acreage

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
global leasedir = "$dbdir/IntermediateData/Louisiana/Leases"
global figdir = "$hbpdir/Paper/Figures"
global beamerfigdir = "$hbpdir/Paper/Beamer_Figures"
global logdir = "$hbpdir/Code/Analysis/Louisiana/LogFiles"

// Create log file
log using "$logdir/examining_missing_area_log.txt", replace text

********************************************************************************

* Opens the fairly-raw lease data:

use "${leasedir}/louisiana_leases_DI_csvs.dta", clear

tab county if inlist(county,"BIENVILLE","BOSSIER","CADDO","DE SOTO","NATCHITOCHES","RED RIVER","SABINE","WEBSTER")
keep if inlist(county,"BIENVILLE","BOSSIER","CADDO","DE SOTO","NATCHITOCHES","RED RIVER","SABINE","WEBSTER")

gen acres_missing = missing(area)
gen acres_miss0 = missing(area) | area==0

sum acres_miss0 if instdate >= mdy(1,1,2003) & instdate <= mdy(1,1,2015) // 9%

gen ym = ym(year(instdate), month(instdate))

format ym %tm
codebook ym
egen tag_ym = tag(ym)
egen mean_miss_acres0 = mean(acres_miss0), by(ym)
label var mean_miss_acres0 "Probability missing or zero acreage"

egen total_lease = total(1), by(ym)
label var total_lease "Total observations"

egen total_leases_w_area = total(area>0 & area<.), by(ym)
label var total_leases_w_area "Total observations with positive area"

gen year_mfrac = year(instdate) + (month(instdate) - 1)/12

sort ym

graph set window fontface "Times New Roman"
twoway area total_lease         year_mfrac if tag_ym & instdate >= mdy(1,1,2003) & ///
			instdate <= mdy(1,1,2015), yaxis(2) color(cranberry*0.5) lwidth(none) || ///
	   area total_leases_w_area year_mfrac if tag_ym & instdate >= mdy(1,1,2003) & ///
			instdate <= mdy(1,1,2015), yaxis(2) color(navy) lwidth(none) || ///
	   line mean_miss_acres0 year_mfrac    if tag_ym & instdate >= mdy(1,1,2003) & ///
			instdate <= mdy(1,1,2015), yaxis(1) lpattern(line) lwidth(medthick) lcolor(black) ///
		legend(order(3 2 1) rows(3) lab(2 "positive acreage") ///
		lab(1 "missing or zero acreage") lab(3 "fraction missing or zero")) ///
		graphregion(color(white)) bgcolor(white) ytitle("Fraction missing or zero", axis(1)) ///
		ytitle("Number of observations", axis(2)) xlab(2003(2)2015) xtitle("Year")

gr export "${figdir}/lease_descript/missing_lease_area.pdf", as(pdf) replace

graph set window fontface default
twoway area total_lease         year_mfrac if tag_ym & instdate >= mdy(1,1,2003) & ///
			instdate <= mdy(1,1,2015), yaxis(2) color(cranberry*0.5) lwidth(none) || ///
	   area total_leases_w_area year_mfrac if tag_ym & instdate >= mdy(1,1,2003) & ///
			instdate <= mdy(1,1,2015), yaxis(2) color(navy) lwidth(none) || ///
	   line mean_miss_acres0 year_mfrac    if tag_ym & instdate >= mdy(1,1,2003) & ///
			instdate <= mdy(1,1,2015), yaxis(1) lpattern(line) lwidth(medthick) lcolor(black) ///
		legend(order(3 2 1) rows(3) lab(2 "positive acreage") ///
		lab(1 "missing or zero acreage") lab(3 "fraction missing or zero")) ///
		graphregion(color(white)) bgcolor(white) ytitle("Fraction missing or zero", axis(1)) ///
		ytitle("Number of observations", axis(2)) xlab(2003(2)2015) xtitle("Year")

gr export "${beamerfigdir}/lease_descript/missing_lease_area.pdf", as(pdf) replace

clear all
