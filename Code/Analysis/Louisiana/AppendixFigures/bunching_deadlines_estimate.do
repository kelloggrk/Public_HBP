* Runs bunching regressions, exporting a .tex table of estimates and
* figures showing the estimates for the baseline specification

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
global unitdir = "$dbdir/IntermediateData/Louisiana/SubsampledUnits"
global figdir = "$hbpdir/Paper/Figures"
global beamerfigdir = "$hbpdir/Paper/Beamer_Figures"
global logdir = "$hbpdir/Code/Analysis/Louisiana/LogFiles"

// Create log file
log using "$logdir/bunching_deadlines_estimate_log.txt", replace text

********************************************************************************

use "$unitdir/unit_data_with_prod.dta", replace
set scheme tufte
************************************************************************************
* labels variables
	label var first_permit "first permit"
	label var first_spud "first spud"
	label var first_comp "first completion"
	label var first_spudDI "first spud (DI)"
	label var first_compDI "first completion (DI)"
	label var first_compRA "first completion (RA)"

	label var leaseExpireFirst "first lease expiration"
	label var leaseExpireP10  "10th percentile lease expiration"
	label var leaseExpireP25  "25th percentile lease expiration"
	label var leaseExpireMed  "median lease expiration"
	label var leaseExpireP75  "75th percentile lease expiration"
************************************************************************************
* Some more variables:
	egen group_TR = group(township range)
	gen year_spud = year(first_spud)
	gen ym_spud = ym(year(first_spud),month(first_spud))
	gen time_to_spud = (first_spud - leaseExpireFirst+365.25*3)/(30.4375*3)
	replace time_to_spud = . if time_to_spud<0
	replace time_to_spud = . if subsample_v1!=1
	gen z = floor(time_to_spud) - 12   

************************************************************************************
* Descriptive Statistics:

		* For full sample of sections
		gen year_leaseExpireFirst = year(leaseExpireFirst)
		label var year_leaseExpireFirst "Year first lease expires"
		gen year_leaseStartFirst = year(leaseStartFirst)
		label var year_leaseStartFirst "Year first lease starts"
		gen av_royalty_100 = av_royalty_firstExpire*100
		label var av_royalty_100 "Acreage-weighted average royalty"
		label var year_spud "Year of first Hay. spud"
		gen HayWellCount_spud = HayWellCount if ~missing(year_spud)
		label var HayWellCount_spud "Number of Hay. wells"
		gen ProdS_first12_gas_1000 = ProdS_first12_gas/1000
		label var ProdS_first12_gas_1000 "Gas production of first Hay well"
		label var DNR_section_poly_acres "Section acres"

		egen c = total(1), by(z) // count of number of cases where spud happend z quarters after start date
		keep c z
		duplicates drop

		drop if z==.
        gen was_already_in_data = 1
        tsset z
        tsfill // fills in observations for possible integer values of z between max and min z
        replace was_already_in_data = 0 if was_already_in_data == .
        replace c = 0 if was_already_in_data == 0
        drop was_already_in_data

		* Marks the cases that are around (right before or after) the lease expiration or the lease extension expiration
		gen pre_2 = z==-2
		gen pre_1 = z==-1
		gen post_1 = z==0
		gen post_2 = z==1
		gen pre_ext2 = z==6
		gen pre_ext1 = z==7
		gen post_ext1 = z==8
		gen post_ext2 = z==9

		* creates polynomial in z (time in quarters from start to spud)
		forvalues i=2/21 {
			gen z_`i' = z^`i'
		}
		drop if z==.

		eststo clear

		* Main regression used for graph
		newey2 c z z_2 z_3 z_4 z_5 z_6 z_7 z_8 z_9 pre_2 pre_1 post_1 post_2 ///
			pre_ext2 pre_ext1 post_ext1 post_ext2, lag(2)
		
		gen predicted_well_count = _b[_cons] + _b[z]*z + _b[z_2]*z_2 + _b[z_3]*z_3 + _b[z_4]*z_4 + _b[z_5]*z_5 + _b[z_6]*z_6 + _b[z_7]*z_7 + _b[z_8]*z_8 + _b[z_9]*z_9

		graph set window fontface "Times New Roman"
		sc c z, msymbol(circle) msize(small) mcolor(green*.6) mfcolor(green*.6) legend(off) || ///
		sc c z if z>=-2 & z <=1, msymbol(circle) msize(small) mcolor(navy) mfcolor(navy) legend(off)|| ///
		sc c z if z>=6 & z <=9, msymbol(circle) msize(small) mcolor(navy) mfcolor(navy) legend(off) || ///
		line c z, lpattern(solid) lwidth(vthing) ///
		lcolor(navy*0.3) legend(off) sort||line predicted_well_count z, xtitle("Time in quarters since first lease expiration") ytitle("Number of wells spudded") lpattern(dot) lwidth(normal) ///
		legend(on label(1 "Wells spudded") label(3 "Bunching fixed effects quarters") label(5 "Polynomial fit excluding bunching fixed effects") ///
		order(1 3 5)) sort xline(-0.5, lwidth(vthin) lcolor(gs8)) xline(7.5, lwidth(vthin) lcolor(gs8)) xlabel(-12(8)20)
		gr export "${figdir}/section_descript/drill_bunching_allsections.pdf", as(pdf) replace

		graph set window fontface default
		sc c z, msymbol(circle) msize(small) mcolor(green*.6) mfcolor(green*.6) legend(off) || ///
		sc c z if z>=-2 & z <=1, msymbol(circle) msize(small) mcolor(navy) mfcolor(navy) legend(off)|| ///
		sc c z if z>=6 & z <=9, msymbol(circle) msize(small) mcolor(navy) mfcolor(navy) legend(off) || ///
		line c z, lpattern(solid) lwidth(vthing) ///
		lcolor(navy*0.3) legend(off) sort||line predicted_well_count z, xtitle("Time in quarters since first lease expiration") ytitle("Number of wells spudded") lpattern(dot) lwidth(normal)  ///
		legend(on label(1 "Wells spudded") label(3 "Bunching fixed effects quarters") label(5 "Polynomial fit excluding bunching fixed effects") ///
		order(1 3 5)) sort xline(-0.5, lwidth(vthin) lcolor(gs8)) xline(7.5, lwidth(vthin) lcolor(gs8)) xlabel(-12(8)20)
		gr export "${beamerfigdir}/section_descript/drill_bunching_allsections.pdf", as(pdf) replace
	
		predict c_z if e(sample)
		corr c c_z if e(sample)
		di r(rho)^2
		estadd local R2 = "0"+string(round(r(rho)^2,.01))
		estadd local hasfe ""
		estadd local qol "X"
		estadd local qoqol ""
		estimates store reg1

		test pre_2 pre_1 post_1 post_2

			estadd scalar p_beta_1_4 = r(p)
		test pre_ext2 pre_ext1 post_ext1 post_ext2
			estadd scalar p_beta_5_8 = r(p)
		test pre_2 pre_1 post_1 post_2 pre_ext2 pre_ext1 post_ext1 post_ext2
			estadd scalar p_beta_1_8 = r(p)

		gen log_c = ln(c)

		* regression with log(count)
		newey2 log_c z z_2 z_3 z_4 z_5 z_6 z_7 z_8 z_9 pre_2 pre_1 post_1 post_2 ///
			pre_ext2 pre_ext1 post_ext1 post_ext2, lag(2) force
		predict logc_z if e(sample)
		corr log_c logc_z if e(sample)
		di r(rho)^2
		estadd local R2 = "0"+string(round(r(rho)^2,.01))
		estadd local hasfe ""
		estadd local qol "X"
		estadd local qoqol ""
		estimates store reg2
		
		local for_latex = round(_b[pre_1],.01) // write magnitude to paper
		cap erase "$figdir/single_numbers_tex/bunching_logpts.tex"
		file open temp_file using "$figdir/single_numbers_tex/bunching_logpts.tex", write
		file write temp_file "`for_latex'"
		file close temp_file
		
		* similar, but polynomial of degree 7:
		reg c z z_2 z_3 z_4 z_5 z_6 z_7 pre_2 pre_1 post_1 post_2 pre_ext2 pre_ext1 post_ext1 post_ext2, robust
		test pre_2 pre_1 post_1 post_2
		test pre_ext2 pre_ext1 post_ext1 post_ext2

		* similar, but polynomial of degree 5:
		reg c z z_2 z_3 z_4 z_5 pre_2 pre_1 post_1 post_2 pre_ext2 pre_ext1 post_ext1 post_ext2, robust
		test pre_2 pre_1 post_1 post_2
		test pre_ext2 pre_ext1 post_ext1 post_ext2

		* similar, but polynomial of degree 3:
		reg c z z_2 z_3 pre_2 pre_1 post_1 post_2 pre_ext2 pre_ext1 post_ext1 post_ext2, robust
		test pre_2 pre_1 post_1 post_2
		test pre_ext2 pre_ext1 post_ext1 post_ext2


		use "$unitdir/unit_data_with_prod.dta", replace
		
set scheme tufte
************************************************************************************
* labels variables
	label var first_permit "first permit"
	label var first_spud "first spud"
	label var first_comp "first completion"
	label var first_spudDI "first spud (DI)"
	label var first_compDI "first completion (DI)"
	label var first_compRA "first completion (RA)"

	label var leaseExpireFirst "first lease expiration"
	label var leaseExpireP10  "10th percentile lease expiration"
	label var leaseExpireP25  "25th percentile lease expiration"
	label var leaseExpireMed  "median lease expiration"
	label var leaseExpireP75  "75th percentile lease expiration"
************************************************************************************
* Some more variables:
	egen group_TR = group(township range)
	gen year_spud = year(first_spud)
	gen ym_spud = ym(year(first_spud),month(first_spud))
	gen time_to_spud = (first_spud - leaseExpireFirst+365.25*3)/(30.4375*3)
	replace time_to_spud = . if time_to_spud<0
	replace time_to_spud = . if subsample_v1!=1
	gen s = ym(year(first_spud),(quarter(first_spud)*3-2))
	label var s "quarter of lease expiration id"
	replace s = . if subsample_v1!=1
	gen z = floor(time_to_spud) - 12

************************************************************************************
* Descriptive Statistics:

		* For full sample of sections
		gen year_leaseExpireFirst = year(leaseExpireFirst)
		label var year_leaseExpireFirst "Year first lease expires"
		gen year_leaseStartFirst = year(leaseStartFirst)
		label var year_leaseStartFirst "Year first lease starts"
		gen av_royalty_100 = av_royalty_firstExpire*100
		label var av_royalty_100 "Acreage-weighted average royalty"
		label var year_spud "Year of first Hay. spud"
		gen HayWellCount_spud = HayWellCount if ~missing(year_spud)
		label var HayWellCount_spud "Number of Hay. wells"
		gen ProdS_first12_gas_1000 = ProdS_first12_gas/1000
		label var ProdS_first12_gas_1000 "Gas production of first Hay well"
		label var DNR_section_poly_acres "Section acres"

		egen c_zs = total(1), by(z s)
		keep c_zs z s
		duplicates drop

		drop if z==.
        gen was_already_in_data = 1
        tsset s z
        tsfill
        replace was_already_in_data = 0 if was_already_in_data == .
        replace c_zs = 0 if was_already_in_data == 0
        drop was_already_in_data

		gen pre_2 = z==-2
		gen pre_1 = z==-1
		gen post_1 = z==0
		gen post_2 = z==1
		gen pre_ext2 = z==6
		gen pre_ext1 = z==7
		gen post_ext1 = z==8
		gen post_ext2 = z==9

		forvalues i=2/21 {
			gen z_`i' = z^`i'
			gen s_`i' = s^`i'
		}
		drop if z==.

		gen log_c_zs = ln(c_zs)

		* observations aggregated to lease-quarter by calendar-quarter
		newey2 c_zs z z_2 z_3 z_4 z_5 z_6 z_7 z_8 z_9 pre_2 pre_1 post_1 post_2 ///
			pre_ext2 pre_ext1 post_ext1 post_ext2, lag(2)
		predict c_zsp1 if e(sample)
		corr c_zs c_zsp1 if e(sample)
		di r(rho)^2
		estadd local R2 = "0"+string(round(r(rho)^2,.01))
		estadd local hasfe ""
		estadd local qol ""
		estadd local qoqol "X"
		estimates store reg3
			
		* log(count), observations aggregated to lease-quarter by calendar-quarter
		newey2 log_c_zs z z_2 z_3 z_4 z_5 z_6 z_7 z_8 z_9 pre_2 pre_1 post_1 post_2 ///
			pre_ext2 pre_ext1 post_ext1 post_ext2, lag(2) force
		predict logc_zsp1 if e(sample)
		corr log_c_zs logc_zsp1 if e(sample)
		di r(rho)^2
		estadd local R2 = "0"+string(round(r(rho)^2,.01))
		estadd local hasfe ""
		estadd local qol ""
		estadd local qoqol "X"
		estimates store reg4
		
		* observations aggregated to lease-quarter by calendar-quarter, calendar quarter FE
		xi: newey2 c_zs z z_2 z_3 z_4 z_5 z_6 z_7 z_8 z_9 pre_2 pre_1 post_1 post_2 ///
			pre_ext2 pre_ext1 post_ext1 post_ext2 i.s, lag(2)
		predict c_zsp2 if e(sample)
		corr c_zs c_zsp2 if e(sample)
		di r(rho)^2
		estadd local R2 = "0"+string(round(r(rho)^2,.01))
		estadd local hasfe "X"
		estadd local qol ""
		estadd local qoqol "X"
		estimates store reg5

		* log(count), observations aggregated to lease-quarter by calendar-quarter, calendar quarter FE
		xi: newey2 log_c_zs z z_2 z_3 z_4 z_5 z_6 z_7 z_8 z_9 pre_2 pre_1 post_1 post_2 ///
			pre_ext2 pre_ext1 post_ext1 post_ext2 i.s, lag(2) force
		predict logc_zsp2 if e(sample)
		corr log_c_zs logc_zsp2 if e(sample)
		di r(rho)^2
		estadd local R2 = "0"+string(round(r(rho)^2,.01))
		estadd local hasfe "X"
		estadd local qol ""
		estadd local qoqol "X"
		estimates store reg6

		#delimit ;
		esttab reg1 reg2 reg3 reg4 reg5 reg6 
			using "${figdir}/section_descript/drill_bunching_regression.tex" ,
			order(pre_2 pre_1 post_1 post_2 pre_ext2 pre_ext1 post_ext1 post_ext2)
			keep(pre_2 pre_1 post_1 post_2 pre_ext2 pre_ext1 post_ext1 post_ext2)
			b(%8.2f) se(%8.2f) nogaps mtitles("count " "log(count)" " count " "log(count)" " count " "log(count)")
			nonumbers replace obslast scalars("qol Quarter of lease " "qoqol Quarter by quarter of lease " "hasfe Fixed effects " "R2 R Squared" )
			se compress label nonotes /*star(* .1 ** .05 *** .01)*/ nostar;
		#delimit cr

clear all
