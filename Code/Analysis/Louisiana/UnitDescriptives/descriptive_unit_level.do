*
*  Takes section-level data created by construct_section_4_descript.do
*  Creates some descriptives, including figures showing drilling timing
*
*

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
global scratchfigdir = "$dbdir/Scratch/figures"
global logdir = "$hbpdir/Code/Analysis/Louisiana/LogFiles"

// Create log file
log using "$logdir/descriptive_unit_level_log.txt", replace text

********************************************************************************

use "$unitdir/unit_data_with_prod.dta", clear
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

	
	gen time_to_spud = (first_spud - leaseExpireFirst)/30.4375
	replace time_to_spud = . if time_to_spud<-36
	replace time_to_spud = . if time_to_spud>60
	replace time_to_spud = . if flag_sample_descript!=1
	gen orig_val = -36
	stset time_to_spud, origin(orig_val) // is probably not necessary (?)
	
	* for all units (not just descriptive sample)
	gen time_to_spud_au = (first_spud - leaseExpireFirst)/30.4375
	replace time_to_spud_au = . if time_to_spud_au<-36
	replace time_to_spud_au = . if time_to_spud_au>60
	
	
	
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


		gen big_operator_flag = 1 if unitOperator == "Chesapeake Operating Inc." | ///
		unitOperator == "Petrohawk Operating Company" | ///
		unitOperator == "Encana Oil and Gas USA Inc."
		
		replace big_operator_flag = 0 if big_operator_flag == . & unitOperator != ""

		gen oper_chesapeake = unitOperator == "Chesapeake Operating Inc." if ~missing(unitOperator)
		gen oper_petrohawk = unitOperator == "Petrohawk Operating Company" if ~missing(unitOperator)
		gen oper_encana = unitOperator == "Encana Oil and Gas USA Inc." if ~missing(unitOperator)
		gen oper_othbig = max(oper_petrohawk, oper_encana)

		* Save descriptive statistics for units in analysis sample	
		sutex2 DNR_section_poly_acres year_leaseStartFirst year_leaseExpireFirst /*av_royalty_100*/ HayWellCount_spud  year_spud /*ProdS_first12_gas_1000*/ if flag_sample_descript, ///
			varlabels percentiles(5 50 95) digits(1) tabular ///
			saving("${figdir}/section_descript/descript_table_section_flag_sample_descript.tex") replace

			* outputs individual numbers from above table:
			qui sum year_leaseExpireFirst if flag_sample_descript, detail
				local later_lease_expire = r(p95)
					file open foo using "${figdir}/single_numbers_tex/later_lease_expire.tex", write replace
					file write foo "`later_lease_expire'"
					file close foo
				local earlier_lease_expire = r(p5)
					file open foo using "${figdir}/single_numbers_tex/earlier_lease_expire.tex", write replace
					file write foo "`earlier_lease_expire'"
					file close foo
				local median_lease_expire = r(p50)
					file open foo using "${figdir}/single_numbers_tex/median_lease_expire.tex", write replace
					file write foo "`median_lease_expire'"
					file close foo
			count if ~missing(HayWellCount_spud) & flag_sample_descript==1
				local numer = r(N)
					file open foo using "${figdir}/single_numbers_tex/count_with_hay_spud.tex", write replace
					file write foo "`numer'"
					file close foo
			count if flag_sample_descript==1
				local denom = r(N)
				local frac_with_hay = round(100*`numer'/`denom')
					file open foo using "${figdir}/single_numbers_tex/frac_with_hay_spud.tex", write replace
					file write foo "`frac_with_hay'"
					file close foo
			forvalues i=1/4 {
				if `i'!=4 count if HayWellCount_spud==`i' & flag_sample_descript==1
				if `i'==4 count if HayWellCount_spud>=`i' & HayWellCount_spud<. & flag_sample_descript==1
					local number_`i' = r(N)
					local frac_with_`i' = round(100*`number_`i''/`numer')
						file open foo using "${figdir}/single_numbers_tex/frac_`i'_well_cond_hay_spud.tex", write replace
						file write foo "`frac_with_`i''"
						file close foo
			}
			sum HayWellCount_spud if flag_sample_descript==1
				local hay_well_max = r(max)
						file open foo using "${figdir}/single_numbers_tex/hay_well_max.tex", write replace
						file write foo "`hay_well_max'"
						file close foo
			sum year_spud if flag_sample_descript==1, detail
				local later_year_spud = r(p95)
					file open foo using "${figdir}/single_numbers_tex/later_year_spud.tex", write replace
					file write foo "`later_year_spud'"
					file close foo
				local earlier_year_spud = r(p5)
					file open foo using "${figdir}/single_numbers_tex/earlier_year_spud.tex", write replace
					file write foo "`earlier_year_spud'"
					file close foo
		/* Commented out scratch figures
		sutex2 DNR_section_poly_acres year_leaseStartFirst year_leaseExpireFirst /*av_royalty_100*/ HayWellCount_spud  year_spud /*ProdS_first12_gas_1000*/ if flag_sample_descript & big_operator_flag == 1, ///
			varlabels percentiles(5 50 95) digits(1) tabular ///
			saving("${scratchfigdir}/descript_table_section_big_operator_flag_sample_descript.tex") replace
		sutex2 DNR_section_poly_acres year_leaseStartFirst year_leaseExpireFirst /*av_royalty_100*/ HayWellCount_spud  year_spud /*ProdS_first12_gas_1000*/ if flag_sample_descript & big_operator_flag == 0, ///
			varlabels percentiles(5 50 95) digits(1) tabular ///
			saving("${scratchfigdir}/descript_table_section_small_operator_flag_sample_descript.tex") replace
		*/

************************************************************************************
* creates some binary "treatment" variables: indicator variables on lease heterogeneity
	* whether one well or 2+ wells drilled
	gen multi_wells = Hay_spud>=2 if Hay_spud>=1 & Hay_spud<.
	gen time_to_spud_single = time_to_spud if multi_wells==0 & flag_sample_descript_wdrilling==1
	gen time_to_spud_multi = time_to_spud if multi_wells==1 & flag_sample_descript_wdrilling==1
	gen time_to_spud_sample = time_to_spud if flag_sample_descript_wdrilling==1

	egen productivity_quartile=xtile(unit_phi_mean), n(4)
	egen productivity_tercile=xtile(unit_phi_mean), n(3)
	egen productivity_med=xtile(unit_phi_mean), n(2)
	gen time_to_spud_lowprod = time_to_spud if productivity_med==1
	gen time_to_spud_highprod = time_to_spud if productivity_med==2
	gen time_to_spud_lowtercile = time_to_spud if productivity_tercile==1
	gen time_to_spud_medtercile = time_to_spud if productivity_tercile==2
	gen time_to_spud_hightercile = time_to_spud if productivity_tercile==3
	gen time_to_spud_lowquartile = time_to_spud if productivity_quartile==1
	gen time_to_spud_highquartile = time_to_spud if productivity_quartile==4

		* how is multi_well being correlated with production?
		sum Prod?_first* if flag_sample_descript_wdrilling, detail // liq are almost zero. Focus on gas and water. Water maybe, although
		foreach var of varlist Prod?_first*gas {
			di "`var'"
			qui gen log_`var' = log(`var')
			reg log_`var' multi_wells if flag_sample_descript_wdrilling, noheader
			qui drop log_`var'
		}
		foreach var of varlist Prod?_first*wtr {
			di "`var'"
			qui gen log_`var' = log(`var')
			reg log_`var' multi_wells if flag_sample_descript_wdrilling, noheader
			qui drop log_`var'
		}

		foreach var of varlist Prod?_first*gas {
			di "`var'"
			qui gen log_`var' = log(`var')
			qui reg log_`var' multi_wells i.group_TR i.year_spud if flag_sample_descript_wdrilling
			di _b[multi_wells]
			test multi_wells
			qui drop log_`var'
		}
		foreach var of varlist Prod?_first*gas {
			di "`var'"
			qui gen log_`var' = log(`var')
			qui reg log_`var' multi_wells i.year_spud if flag_sample_descript_wdrilling
			di _b[multi_wells]
			test multi_wells
			qui drop log_`var'
		}


	* Whether has high production
		qui sum ProdS_first12_gas if flag_sample_descript_wdrilling, detail
		gen high_gas_prod = ProdS_first12_gas>r(p50) if flag_sample_descript_wdrilling & ProdS_first12_gas>0 & ProdS_first12_gas<.
		tab high_gas_prod multi_wells if flag_sample_descript_wdrilling, m chi2
		tab high_gas_prod multi_wells if flag_sample_descript_wdrilling, chi2
		pwcorr high_gas_prod multi_wells if flag_sample_descript_wdrilling, sig // 18% correlation, significant at 1% level
		qui reg high_gas_prod multi_wells i.group_TR i.year_spud if flag_sample_descript_wdrilling
			di _b[multi_wells]
			test multi_wells  
		qui reg high_gas_prod multi_wells i.year_spud if flag_sample_descript_wdrilling
			di _b[multi_wells]
			test multi_wells  
		qui reg high_gas_prod multi_wells i.ym_spud if flag_sample_descript_wdrilling
			di _b[multi_wells]
			test multi_wells  
		qui reg high_gas_prod multi_wells if flag_sample_descript_wdrilling
			di _b[multi_wells]
			test multi_wells  

		gen ProdS_first12_gasY = ProdS_first12_gas if flag_sample_descript_wdrilling
		egen xb = median(ProdS_first12_gasY), by(ym_spud)
			gen high_gas_prod2 = ProdS_first12_gasY-xb>0 if flag_sample_descript_wdrilling
			drop xb ProdS_first12_gasY

		* now same thing, but includes zeros
		codebook ProdS_first12_gas if flag_sample_descript_wdrilling
		* counts missings as zeros
		gen ProdS_first12_gasZ = ProdS_first12_gas if flag_sample_descript_wdrilling
		replace ProdS_first12_gasZ = 0 if missing(ProdS_first12_gas) & flag_sample_descript_wdrilling
		qui sum ProdS_first12_gasZ if flag_sample_descript_wdrilling, detail
		gen high_gas_prod3 = ProdS_first12_gasZ>r(p50) if flag_sample_descript_wdrilling

		egen xb = median(ProdS_first12_gasZ), by(ym_spud)
			gen high_gas_prod4 = ProdS_first12_gasZ-xb>0 if flag_sample_descript_wdrilling
			drop xb

		sum  high_gas_prod high_gas_prod? multi_wells if flag_sample_descript_wdrilling
		corr high_gas_prod high_gas_prod? multi_wells if flag_sample_descript_wdrilling

		drop group_TR year_spud ym_spud


	* whether section has an "extension" or not
	foreach stub in First P10 P25 Med P75 {
		gen has2yearExt`stub' = 1 if leaseExpireExt`stub'>=leaseExpire`stub'+720 & ///
			leaseExpireExt`stub'<=leaseExpire`stub'+740
		replace has2yearExt`stub' = 0 if leaseExpireExt`stub'>=leaseExpire`stub'-10 & ///
			leaseExpireExt`stub'<=leaseExpire`stub'+10
	}
		foreach var of varlist has2yearExt* {
			qui sum `var' if flag_sample_descript_wdrilling
			di "`var': Mean="  %5.2fc r(mean)
		}

	gen time_to_spud_hasext = time_to_spud if has2yearExtFirst==1 & flag_sample_descript_wdrilling==1
	gen time_to_spud_noext = time_to_spud if has2yearExtFirst==0 & flag_sample_descript_wdrilling==1

	egen tag_tq = tag(tq)
	/* Commented out scratch figures
	twoway line units_spudded tq if flag_sample_descript_wdrilling==1 & tag_tq==1, sort
	graph export "${scratchfigdir}/section_descript/units_spudded_quarterly.pdf", replace
	*/
	
	* number of neighbors 
	gen frac_neighbor_match_1p2 = count_same_neigbor_1p2/count_has_neighbor_1p2
	gen frac_neighbor_match_1p7 = count_same_neigbor_1p7/count_has_neighbor_1p7
	sum frac_neighbor_match_1p? if flag_sample_descript==1, detail
	tab frac_neighbor_match_1p2 if flag_sample_descript_wdrilling==1
	gen neighbor_gt50_match_1p2 = frac_neighbor_match_1p2 >= 0.5 if frac_neighbor_match_1p2 <.
	gen neighbor_gt50_match_1p7 = frac_neighbor_match_1p7 >= 0.5 if frac_neighbor_match_1p7 <.
	
	
	/* Commented out scratch figures
	sum *royalty* if flag_sample_descript_wdrilling
	corr *royalty* if flag_sample_descript_wdrilling
	hist av_royalty_firstExpire if flag_sample_descript_wdrilling, start(0) width(.01) ///
		title("Acreage-weighted average royalty") graphregion(color(white)) ///
		bgcolor(white) subtitle("Calculated at time when first least expires")
	graph export "${scratchfigdir}/section_descript/hist_royalty_LeaseExpire.pdf", replace

	* Some descriptives on quantiles of lease dates
	twoway scatter leaseExpireFirst leaseExpireP10 if flag_sample_descript_wdrilling & year(leaseExpireFirst)<2019
		graph export "${scratchfigdir}/section_descript/datecompare_First_P10.pdf", replace
	gen dif_P10First = leaseExpireP10-leaseExpireFirst
	label var dif_P10First "Difference between 10th and First lease expiration dates"
	cumul dif_P10First if flag_sample_descript_wdrilling, gen(cdf_dif_P10First)
	label var cdf_dif_P10First "CDF"
	sort cdf_dif_P10First
	line cdf_dif_P10First dif_P10First if flag_sample_descript_wdrilling
		graph export "${scratchfigdir}/section_descript/cdf_P10_minus_First.pdf", replace
	*/
	
	
********************************************************************	
* study timing of spud vs lease expiration
	foreach stub in First P10 P25 Med P75 {
		gen dif_start_expire_`stub' = leaseExpire`stub' - leaseStart`stub'
	}
	describe dif_start_expire_*
	foreach var of varlist dif_start_expire_* {
		qui count if abs(`var'-3*365.25)<=15 & flag_sample_descript_wdrilling
		local numer = r(N)
		qui count if ~missing(`var') & flag_sample_descript_wdrilling
		local denom = r(N)
		di "`var' :  " `numer'/`denom' // 87% to 90%
	}
	drop dif_start_expire_*

	* How long does it take for the section to get leased?
	gen dif_time_75_25 = leaseExpireP75-leaseExpireP25
	gen dif_time_50_first = leaseExpireMed-leaseExpireFirst

	sum dif_time_75_25 if flag_sample_descript, detail
	gen long_to_expire_7525 = dif_time_75_25 > r(p50) if flag_sample_descript & ~missing(dif_time_75_25)

	sum dif_time_50_first if flag_sample_descript, detail
	gen long_to_expire_50f = dif_time_50_first > r(p50) if flag_sample_descript & ~missing(dif_time_50_first)

	corr long_to_expire* if flag_sample_descript

	gen dif_date_temp = first_spud - leaseExpireFirst
	reg dif_date long_to_expire_7525 if flag_sample_descript
	reg dif_date long_to_expire_50f if flag_sample_descript
	gen time_to_spud_long_to_expire_50f = time_to_spud if long_to_expire_50f==1 & flag_sample_descript==1
	gen time_to_spud_not_50f = time_to_spud if long_to_expire_50f!=1 & flag_sample_descript==1

	gen time_to_spud_big_operator = time_to_spud if big_operator_flag == 1 & flag_sample_descript == 1
	gen time_to_spud_small_operator = time_to_spud if big_operator_flag == 0 & flag_sample_descript == 1

	gen time_to_spud_chesapeake = time_to_spud if oper_chesapeake==1 & flag_sample_descript == 1
	gen time_to_spud_not_chesapeake = time_to_spud if oper_chesapeake==0 & flag_sample_descript == 1
	gen time_to_spud_othbig = time_to_spud if (oper_petrohawk==1 | oper_encana==1) & flag_sample_descript == 1
	
	gen time_to_spud_noper_gt50_1p2 = time_to_spud if neighbor_gt50_match_1p2==1 & flag_sample_descript == 1
	gen time_to_spud_noper_lt50_1p2 = time_to_spud if neighbor_gt50_match_1p2==0 & flag_sample_descript == 1
	gen time_to_spud_noper_gt50_1p7 = time_to_spud if neighbor_gt50_match_1p7==1 & flag_sample_descript == 1
	gen time_to_spud_noper_lt50_1p7 = time_to_spud if neighbor_gt50_match_1p7==0 & flag_sample_descript == 1

	* same, but for all units
	gen time_to_spud_noper_gt50_1p2_au = time_to_spud_au if neighbor_gt50_match_1p2==1
	gen time_to_spud_noper_lt50_1p2_au = time_to_spud_au if neighbor_gt50_match_1p2==0
	gen time_to_spud_noper_gt50_1p7_au = time_to_spud_au if neighbor_gt50_match_1p7==1
	gen time_to_spud_noper_lt50_1p7_au = time_to_spud_au if neighbor_gt50_match_1p7==0

	codebook time_to_spud_noper_?t50_1p2*
	

		* Histogram of spud dates
		graph set window fontface "Times New Roman"
		twoway (hist time_to_spud if flag_sample_descript_wdrilling, ///
		lcolor(dkgreen*0.6) fcolor(dkgreen*0.4)  start(-40) width(2) ///
		xline(0 24) xtitle("Months since first lease expiration") ytitle("Drilling activity") graphregion(color(white)) bgcolor(white) title(""))
		gr export "${figdir}/section_descript/drill_allsections.pdf", as(pdf) replace

		graph set window fontface default
		twoway (hist time_to_spud if flag_sample_descript_wdrilling, ///
		lcolor(dkgreen*0.6) fcolor(dkgreen*0.4) start(-40) width(2) ///
		xline(0 24) xtitle("Months since first lease expiration") ytitle("Drilling activity") graphregion(color(white)) bgcolor(white) title(""))
		gr export "${beamerfigdir}/section_descript/drill_allsections.pdf", as(pdf) replace
	
		* Kernel of spud dates, all sections
		graph set window fontface "Times New Roman"
		kdens time_to_spud_sample if flag_sample_descript_wdrilling, gen(allsd allsx) ci(allsb_l allsb_u) kernel(epan) level(95) usmooth(0.2) bw(2.74)
		twoway (rarea allsb_u allsb_l allsx, fcolor(navy*0.5) lpattern(solid) lwidth(vvthin)) ///
		(line allsd allsx, lpattern(solid) ///
		xline(0 24) xtitle("Months since first lease expiration") ytitle("Monthly probability of drilling") graphregion(color(white)) bgcolor(white) title("") ///
		legend(on colfirst label(1 "95% CI") label(2 "All sections") rows(2)))
		gr export "${figdir}/section_descript/drillprob_allsections_kdensity.pdf", as(pdf) replace

		graph set window fontface default
		kdens time_to_spud_sample if flag_sample_descript_wdrilling, kernel(epan) level(95) usmooth(0.2) bw(2.74) ci(allb_l allb_u) gen(alld allx)
		twoway (rarea allb_u allb_l allx, fcolor(navy*0.5) lpattern(solid) lwidth(vvthin)) ///
		(line alld allx, lpattern(solid) ///
		xline(0 24) xtitle("Months since first lease expiration") ytitle("Monthly probability of drilling") graphregion(color(white)) bgcolor(white) title("") ///
		legend(on colfirst label(1 "95% CI") label(2 "All sections") rows(2)))
		gr export "${beamerfigdir}/section_descript/drillprob_allsections_kdensity.pdf", as(pdf) replace


		* Single-well vs. multi-well sections
		graph set window fontface "Times New Roman"
		kdens time_to_spud_single if flag_sample_descript, gen(singlesd singlesx) ci(singlesb_l singlesb_u) kernel(epan) level(95) usmooth(0.2) bw(2.74)
		kdens time_to_spud_multi  if flag_sample_descript, gen(multisd  multisx)  ci(multisb_l  multisb_u)  kernel(epan) level(95) usmooth(0.2) bw(2.74)
		twoway (rarea multisb_u multisb_l multisx, fcolor(navy*0.5) lpattern(solid) lwidth(vvthin)) ///
		(rarea singlesb_u singlesb_l singlesx, fcolor(cranberry*0.3) lpattern(solid) lwidth(vvthin)) ///
		(line multisd multisx, lpattern(dash)) ///
		(line singlesd singlesx, lpattern(solid) ///
		xline(0 24) xtitle("Months since first lease expiration") ytitle("Monthly probability of drilling") graphregion(color(white)) bgcolor(white)  title("") ///
		legend(on colfirst label(1 "95% CI") label(2 "95% CI") label(3 "Sections with multiple wells") label(4 "Sections with one well")  rows(2) order(3 4 1 2)))
		gr export "${figdir}/section_descript/drillprob_by_section_wellcount_kdensity.pdf", as(pdf) replace

		graph set window fontface default
		kdens time_to_spud_single if flag_sample_descript, gen(singled singlex) ci(singleb_l singleb_u) kernel(epan) level(95) usmooth(0.2) bw(2.74)
		kdens time_to_spud_multi  if flag_sample_descript, gen(multid  multix)  ci(multib_l  multib_u)  kernel(epan) level(95) usmooth(0.2) bw(2.74)
		twoway (rarea multib_u multib_l multix, fcolor(navy*0.5) lpattern(solid) lwidth(vvthin)) ///
		(rarea singleb_u singleb_l singlex, fcolor(cranberry*0.3) lpattern(solid) lwidth(vvthin)) ///
		(line multid multix, lpattern(dash)) ///
		(line singled singlex, lpattern(solid) ///
		xline(0 24) xtitle("Months since first lease expiration") ytitle("Monthly probability of drilling") graphregion(color(white)) bgcolor(white)  title("") ///
		legend(on colfirst label(1 "95% CI") label(2 "95% CI") label(3 "Sections with multiple wells") label(4 "Sections with one well")  rows(2) order(3 4 1 2)))
		gr export "${beamerfigdir}/section_descript/drillprob_by_section_wellcount_kdensity.pdf", as(pdf) replace

		
		* with and without extension
		graph set window fontface "Times New Roman"
		kdens time_to_spud_hasext if flag_sample_descript, gen(hasextsd hasextsx) ci(hasextsb_l hasextsb_u) kernel(epan) level(95) usmooth(0.2) bw(2.74)
		kdens time_to_spud_noext if flag_sample_descript, gen(noextsd noextsx) ci(noextsb_l noextsb_u) kernel(epan) level(95) usmooth(0.2) bw(2.74)
		twoway (rarea hasextsb_u hasextsb_l hasextsx, fcolor(navy*0.5) lpattern(solid) lwidth(vvthin)) ///
		(rarea noextsb_u noextsb_l noextsx, fcolor(cranberry*0.3) lpattern(solid) lwidth(vvthin)) ///
		(line hasextsd hasextsx, lpattern(dash)) ///
		(line noextsd noextsx, lpattern(solid) ///
		xline(0 24) xtitle("Months since first lease expiration") ytitle("Monthly probability of drilling") graphregion(color(white)) bgcolor(white)  title("") ///
		legend(on colfirst label(1 "95% CI") label(2 "95% CI") label(3 "Sections with extension") label(4 "Sections with no extension")  rows(2) order(3 4 1 2)))
		gr export "${figdir}/section_descript/drillprob_by_section_ext_kdensity.pdf", as(pdf) replace

		graph set window fontface default
		kdens time_to_spud_hasext if flag_sample_descript, gen(hasextd hasextx) ci(hasextb_l hasextb_u) kernel(epan) level(95) usmooth(0.2) bw(2.74)
		kdens time_to_spud_noext if flag_sample_descript, gen(noextd noextx) ci(noextb_l noextb_u) kernel(epan) level(95) usmooth(0.2) bw(2.74)
		twoway (rarea hasextb_u hasextb_l hasextx, fcolor(navy*0.5) lpattern(solid) lwidth(vvthin)) ///
		(rarea noextb_u noextb_l noextx, fcolor(cranberry*0.3) lpattern(solid) lwidth(vvthin)) ///
		(line hasextd hasextx, lpattern(dash)) ///
		(line noextd noextx, lpattern(solid) ///
		xline(0 24) xtitle("Months since first lease expiration") ytitle("Monthly probability of drilling") graphregion(color(white)) bgcolor(white)  title("") ///
		legend(on colfirst label(1 "95% CI") label(2 "95% CI") label(3 "Sections with extension") label(4 "Sections with no extension")  rows(2) order(3 4 1 2)))
		gr export "${beamerfigdir}/section_descript/drillprob_by_section_ext_kdensity.pdf", as(pdf) replace

		
		* top tercile vs. bottom tercile production
		graph set window fontface "Times New Roman"
		kdens time_to_spud_hightercile if flag_sample_descript, gen(hightercd hightercx) ci(hightercb_l hightercb_u) kernel(epan) level(95) usmooth(0.2) bw(2.74)
		kdens time_to_spud_lowtercile if flag_sample_descript, gen(lowtercd lowtercx) ci(lowtercb_l lowtercb_u) kernel(epan) level(95) usmooth(0.2) bw(2.74)
		twoway (rarea hightercb_u hightercb_l hightercx, fcolor(navy*0.5) lpattern(solid) lwidth(vvthin)) ///
		(rarea lowtercb_u lowtercb_l lowtercx, fcolor(cranberry*0.3) lpattern(solid) lwidth(vvthin)) ///
		(line hightercd hightercx, lpattern(dash)) ///
		(line lowtercd lowtercx, lpattern(solid) ///
		xline(0 24) xtitle("Months since first lease expiration") ytitle("Monthly probability of drilling") graphregion(color(white)) bgcolor(white)  title("") ///
		legend(on colfirst label(1 "95% CI") label(2 "95% CI")  label(3 "Sections with productivity > 66%") label(4 "Sections with productivity < 33%") rows(2) order(3 4 1 2)))
		gr export "${figdir}/section_descript/drillprob_by_section_tercilesprod_kdensity.pdf", as(pdf) replace

		graph set window fontface default
		kdens time_to_spud_hightercile if flag_sample_descript, gen(hightercsd hightercsx) ci(hightercsb_l hightercsb_u) kernel(epan) level(95) usmooth(0.2) bw(2.74)
		kdens time_to_spud_lowtercile if flag_sample_descript, gen(lowtercsd lowtercsx) ci(lowtercsb_l lowtercsb_u) kernel(epan) level(95) usmooth(0.2) bw(2.74)
		twoway (rarea hightercsb_u hightercsb_l hightercsx, fcolor(navy*0.5) lpattern(solid) lwidth(vvthin)) ///
		(rarea lowtercsb_u lowtercsb_l lowtercsx, fcolor(cranberry*0.3) lpattern(solid) lwidth(vvthin)) ///
		(line hightercsd hightercsx, lpattern(dash)) ///
		(line lowtercsd lowtercsx, lpattern(solid) ///
		xline(0 24) xtitle("Months since first lease expiration") ytitle("Monthly probability of drilling") graphregion(color(white)) bgcolor(white)  title("") ///
		legend(on colfirst label(1 "95% CI") label(2 "95% CI")  label(3 "Sections with productivity > 66%") label(4 "Sections with productivity < 33%") rows(2) order(3 4 1 2)))
		gr export "${beamerfigdir}/section_descript/drillprob_by_section_tercilesprod_kdensity.pdf", as(pdf) replace
		
		/* Commented out scratch figures
		* big versus smaller operators
		graph set window fontface default
		kdens time_to_spud_big_operator if flag_sample_descript, gen(bigopd bigopx) ci(bigopb_l bigopb_u) kernel(epan) level(95) usmooth(0.2) bw(2.74)
		kdens time_to_spud_small_operator if flag_sample_descript, gen(smallopd smallopx) ci(smallopb_l smallopb_u) kernel(epan) level(95) usmooth(0.2) bw(2.74)
		twoway (rarea bigopb_u bigopb_l bigopx, fcolor(navy*0.5) lpattern(solid) lwidth(vvthin)) ///
		(rarea smallopb_u smallopb_l smallopx, fcolor(cranberry*0.3) lpattern(solid) lwidth(vvthin)) ///
		(line bigopd bigopx, lpattern(dash)) ///
		(line smallopd smallopx, lpattern(solid) ///
		xline(0 24) xtitle("Months since first lease expiration") ytitle("Monthly probability of drilling") graphregion(color(white)) bgcolor(white)  title("") ///
		legend(on colfirst label(1 "95% CI") label(2 "95% CI")  label(3 "Sections with big unit operators") label(4 "Sections with small unit operators") rows(2) order(3 4 1 2)))
		gr export "${scratchfigdir}/section_descript/drillprob_by_section_operatorsize_kdensity.pdf", as(pdf) replace

		
		* chesapeake vs others
		graph set window fontface default
		kdens time_to_spud_chesapeake if flag_sample_descript, gen(chesopd chesopx) ci(chesopb_l chesopb_u) kernel(epan) level(95) usmooth(0.2) bw(2.74)
		kdens time_to_spud_not_chesapeake if flag_sample_descript, gen(nonchesopd nonchesopx) ci(nonchesopb_l nonchesopb_u) kernel(epan) level(95) usmooth(0.2) bw(2.74)
		twoway (rarea chesopb_u chesopb_l chesopx, fcolor(navy*0.5) lpattern(solid) lwidth(vvthin)) ///
		(rarea nonchesopb_u nonchesopb_l nonchesopx, fcolor(cranberry*0.3) lpattern(solid) lwidth(vvthin)) ///
		(line chesopd chesopx, lpattern(dash)) ///
		(line nonchesopd nonchesopx, lpattern(solid) ///
		xline(0 24) xtitle("Months since first lease expiration") ytitle("Monthly probability of drilling") graphregion(color(white)) bgcolor(white)  title("") ///
		legend(on colfirst label(1 "95% CI") label(2 "95% CI")  label(3 "Chesapeake sections") label(4 "Non-Chesapeake sections") rows(2) order(3 4 1 2)))
		gr export "${scratchfigdir}/section_descript/drillprob_by_section_chesapeake_kdensity.pdf", as(pdf) replace

		* other non-chesapeake
		kdens time_to_spud_othbig     if flag_sample_descript, gen(othbigopd othbigopx) ci(othbigopb_l othbigopb_u) kernel(epan) level(95) usmooth(0.2) bw(2.74)
		kdens time_to_spud_small   if flag_sample_descript, gen(othsmallopd othsmallopx) ci(othsmallopb_l othsmallopb_u) kernel(epan) level(95) usmooth(0.2) bw(2.74)

		* chesapeake vs other big vs small:
		graph set window fontface default
		twoway (rarea chesopb_u chesopb_l chesopx, fcolor(navy*0.5) lpattern(solid) lwidth(vvthin)) ///
		(rarea othbigopb_u othbigopb_l othbigopx, fcolor(cranberry*0.3) lpattern(solid) lwidth(vvthin)) ///
		(rarea othsmallopb_u othsmallopb_l othsmallopx, fcolor(dkgreen*0.3) lpattern(solid) lwidth(vvthin)) ///
		(line chesopd chesopx, lpattern(dash)) ///
		(line othbigopd othbigopx, lpattern(solid)) ///
		(line smallopd smallopx, lpattern(dot) ///
		xline(0 24) xtitle("Months since first lease expiration") ytitle("Monthly probability of drilling") graphregion(color(white)) bgcolor(white)  title("") ///
		legend(on colfirst label(1 "95% CI") label(2 "95% CI") label(3 "95% CI")  label(4 "Chesapeake") label(5 "Encana and Petrohawk") label(6 "Small operators") rows(3) order(4 5 6 1 2 3)))
		gr export "${scratchfigdir}/section_descript/drillprob_by_section_operators_kdensity.pdf", as(pdf) replace
		*/

		* Whether takes a long time to get to 50% expirations
		kdens time_to_spud_long_to_expire_50f if flag_sample_descript, gen(explongd explongx) ci(explongb_l explongb_u) kernel(epan) level(95) usmooth(0.2) bw(2.74)
		kdens time_to_spud_not_50f            if flag_sample_descript, gen(expshrtd expshrtx) ci(expshrtb_l expshrtb_u) kernel(epan) level(95) usmooth(0.2) bw(2.74)

		graph set window fontface default
		twoway (rarea explongb_u explongb_l explongx, fcolor(navy*0.5) lpattern(solid) lwidth(vvthin)) ///
		(rarea expshrtb_u expshrtb_l expshrtx, fcolor(cranberry*0.3) lpattern(solid) lwidth(vvthin)) ///
		(line explongd explongx, lpattern(dash)) ///
		(line expshrtd expshrtx, lpattern(solid) ///
		xline(0 24) xtitle("Months since first lease expiration") ytitle("Monthly probability of drilling") graphregion(color(white)) bgcolor(white)  title("") ///
		legend(on colfirst label(1 "95% CI") label(2 "95% CI")  label(3 "Longer time to 50% of leases expiring") label(4 "Shorter time to 50% of leases expiring") rows(2) order(3 4 1 2)))
		gr export "${beamerfigdir}/section_descript/drillprob_by_lease_length_leaseExpireFirst_first_spud.pdf", as(pdf) replace
		
		graph set window fontface "Times New Roman"
		twoway (rarea explongb_u explongb_l explongx, fcolor(navy*0.5) lpattern(solid) lwidth(vvthin)) ///
		(rarea expshrtb_u expshrtb_l expshrtx, fcolor(cranberry*0.3) lpattern(solid) lwidth(vvthin)) ///
		(line explongd explongx, lpattern(dash)) ///
		(line expshrtd expshrtx, lpattern(solid) ///
		xline(0 24) xtitle("Months since first lease expiration") ytitle("Monthly probability of drilling") graphregion(color(white)) bgcolor(white)  title("") ///
		legend(on colfirst label(1 "95% CI") label(2 "95% CI")  label(3 "Longer time to 50% of leases expiring") label(4 "Shorter time to 50% of leases expiring") rows(2) order(3 4 1 2)))
		gr export "${figdir}/section_descript/drillprob_by_lease_length_leaseExpireFirst_first_spud.pdf", as(pdf) replace
	


		* Whether 50%+ of neighbors (defined over the 1.2 mile and 1.7 mile radius) are the same operator
		* 1.2 miles first
		kdens time_to_spud_noper_gt50_1p2 if flag_sample_descript, gen(gt50_1p2d gt50_1p2x) ci(gt50_1p2b_l gt50_1p2b_u) kernel(epan) level(95) usmooth(0.2) bw(2.74)		
		kdens time_to_spud_noper_lt50_1p2 if flag_sample_descript, gen(lt50_1p2d lt50_1p2x) ci(lt50_1p2b_l lt50_1p2b_u) kernel(epan) level(95) usmooth(0.2) bw(2.74)		
		
		graph set window fontface default
		twoway ///
		(rarea gt50_1p2b_u gt50_1p2b_l gt50_1p2x, fcolor(navy*0.5)      lpattern(solid) lwidth(vvthin)) ///
		(rarea lt50_1p2b_u lt50_1p2b_l lt50_1p2x, fcolor(cranberry*0.3) lpattern(solid) lwidth(vvthin)) ///
		(line gt50_1p2d gt50_1p2x, lpattern(dash)) ///
		(line lt50_1p2d lt50_1p2x, lpattern(solid) ///
		xline(0 24) xtitle("Months since first lease expiration") ytitle("Monthly probability of drilling") graphregion(color(white)) bgcolor(white)  title("") ///
		legend(on colfirst label(1 "95% CI") label(2 "95% CI")  label(3 "{&ge} 50% of neighbors are same operator") label(4 "< 50% of neighbors are same operator") rows(2) order(3 4 1 2)))
		gr export "${beamerfigdir}/section_descript/drillprob_neighb_50p_1p2.pdf", as(pdf) replace
		
		graph set window fontface "Times New Roman"
		twoway ///
		(rarea gt50_1p2b_u gt50_1p2b_l gt50_1p2x, fcolor(navy*0.5)      lpattern(solid) lwidth(vvthin)) ///
		(rarea lt50_1p2b_u lt50_1p2b_l lt50_1p2x, fcolor(cranberry*0.3) lpattern(solid) lwidth(vvthin)) ///
		(line gt50_1p2d gt50_1p2x, lpattern(dash)) ///
		(line lt50_1p2d lt50_1p2x, lpattern(solid) ///
		xline(0 24) xtitle("Months since first lease expiration") ytitle("Monthly probability of drilling") graphregion(color(white)) bgcolor(white)  title("") ///
		legend(on colfirst label(1 "95% CI") label(2 "95% CI")  label(3 "{&ge} 50% of neighbors are same operator") label(4 "< 50% of neighbors are same operator") rows(2) order(3 4 1 2)))
		gr export "${figdir}/section_descript/drillprob_neighb_50p_1p2.pdf", as(pdf) replace
		
		
		
		* 1.2 miles -- all units
		kdens time_to_spud_noper_gt50_1p2_au, gen(gt50_1p2_au_d gt50_1p2_au_x) ci(gt50_1p2_au_b_l gt50_1p2_au_b_u) kernel(epan) level(95) usmooth(0.2) bw(2.74)		
		kdens time_to_spud_noper_lt50_1p2_au, gen(lt50_1p2_au_d lt50_1p2_au_x) ci(lt50_1p2_au_b_l lt50_1p2_au_b_u) kernel(epan) level(95) usmooth(0.2) bw(2.74)		

		graph set window fontface default
		twoway ///
		(rarea gt50_1p2_au_b_u gt50_1p2_au_b_l gt50_1p2_au_x, fcolor(navy*0.5)      lpattern(solid) lwidth(vvthin)) ///
		(rarea lt50_1p2_au_b_u lt50_1p2_au_b_l lt50_1p2_au_x, fcolor(cranberry*0.3) lpattern(solid) lwidth(vvthin)) ///
		(line gt50_1p2_au_d gt50_1p2_au_x, lpattern(dash)) ///
		(line lt50_1p2_au_d lt50_1p2_au_x, lpattern(solid) ///
		xline(0 24) xtitle("Months since first lease expiration") ytitle("Monthly probability of drilling") graphregion(color(white)) bgcolor(white)  title("") ///
		legend(on colfirst label(1 "95% CI") label(2 "95% CI")  label(3 "{&ge} 50% of neighbors are same operator") label(4 "< 50% of neighbors are same operator") rows(2) order(3 4 1 2)))
		gr export "${beamerfigdir}/section_descript/drillprob_neighb_50p_1p2_allunits.pdf", as(pdf) replace
		
		graph set window fontface "Times New Roman"
		twoway ///
		(rarea gt50_1p2_au_b_u gt50_1p2_au_b_l gt50_1p2_au_x, fcolor(navy*0.5)      lpattern(solid) lwidth(vvthin)) ///
		(rarea lt50_1p2_au_b_u lt50_1p2_au_b_l lt50_1p2_au_x, fcolor(cranberry*0.3) lpattern(solid) lwidth(vvthin)) ///
		(line gt50_1p2_au_d gt50_1p2_au_x, lpattern(dash)) ///
		(line lt50_1p2_au_d lt50_1p2_au_x, lpattern(solid) ///
		xline(0 24) xtitle("Months since first lease expiration") ytitle("Monthly probability of drilling") graphregion(color(white)) bgcolor(white)  title("") ///
		legend(on colfirst label(1 "95% CI") label(2 "95% CI")  label(3 "{&ge} 50% of neighbors are same operator") label(4 "< 50% of neighbors are same operator") rows(2) order(3 4 1 2)))
		gr export "${figdir}/section_descript/drillprob_neighb_50p_1p2_allunits.pdf", as(pdf) replace
		
		
		* 1.7 next:
		kdens time_to_spud_noper_gt50_1p7 if flag_sample_descript, gen(gt50_1p7d gt50_1p7x) ci(gt50_1p7b_l gt50_1p7b_u) kernel(epan) level(95) usmooth(0.2) bw(2.74)		
		kdens time_to_spud_noper_lt50_1p7 if flag_sample_descript, gen(lt50_1p7d lt50_1p7x) ci(lt50_1p7b_l lt50_1p7b_u) kernel(epan) level(95) usmooth(0.2) bw(2.74)		

		/* Commented out scratch figures
		graph set window fontface default
		twoway ///
		(rarea gt50_1p7b_u gt50_1p7b_l gt50_1p7x, fcolor(navy*0.5)      lpattern(solid) lwidth(vvthin)) ///
		(rarea lt50_1p7b_u lt50_1p7b_l lt50_1p7x, fcolor(cranberry*0.3) lpattern(solid) lwidth(vvthin)) ///
		(line gt50_1p7d gt50_1p7x, lpattern(dash)) ///
		(line lt50_1p7d lt50_1p7x, lpattern(solid) ///
		xline(0 24) xtitle("Months since first lease expiration") ytitle("Monthly probability of drilling") graphregion(color(white)) bgcolor(white)  title("") ///
		legend(on colfirst label(1 "95% CI") label(2 "95% CI")  label(3 "{&ge} 50% of neighbors are same operator") label(4 "< 50% of neighbors are same operator") rows(2) order(3 4 1 2)))
		gr export "${scratchfigdir}/section_descript/drillprob_neighb_50p_1p7.pdf", as(pdf) replace

		* 1.7 -- all units
		kdens time_to_spud_noper_gt50_1p7_au, gen(gt50_1p7_au_d gt50_1p7_au_x) ci(gt50_1p7_au_b_l gt50_1p7_au_b_u) kernel(epan) level(95) usmooth(0.2) bw(2.74)		
		kdens time_to_spud_noper_lt50_1p7_au, gen(lt50_1p7_au_d lt50_1p7_au_x) ci(lt50_1p7_au_b_l lt50_1p7_au_b_u) kernel(epan) level(95) usmooth(0.2) bw(2.74)		
		
		twoway ///
		(rarea gt50_1p7_au_b_u gt50_1p7_au_b_l gt50_1p7_au_x, fcolor(navy*0.5)      lpattern(solid) lwidth(vvthin)) ///
		(rarea lt50_1p7_au_b_u lt50_1p7_au_b_l lt50_1p7_au_x, fcolor(cranberry*0.3) lpattern(solid) lwidth(vvthin)) ///
		(line gt50_1p7_au_d gt50_1p7_au_x, lpattern(dash)) ///
		(line lt50_1p7_au_d lt50_1p7_au_x, lpattern(solid) ///
		xline(0 24) xtitle("Months since first lease expiration") ytitle("Monthly probability of drilling") graphregion(color(white)) bgcolor(white)  title("") ///
		legend(on colfirst label(1 "95% CI") label(2 "95% CI")  label(3 "{&ge} 50% of neighbors are same operator") label(4 "< 50% of neighbors are same operator") rows(2) order(3 4 1 2)))
		gr export "${scratchfigdir}/section_descript/drillprob_neighb_50p_1p7_allunits.pdf", as(pdf) replace
		*/
		

************************************************************************************
* Looks at water inputs and gas production as a function of number of wells drilled
*  and drilling date relative to lease expiration date
	* creates new variables
	//egen group_TR = group(township range)
	gen year_spud = year(first_spud)
	gen ym_spud = ym(year(first_spud),month(first_spud))

	foreach var of varlist water_RA1 water_RA2 ProdS_first12_gas ProdC_first12_gas ProdC_first6_gas ProdS_first12_gas ProdS_first24_gas ProdS_first6_gas well_cost_RA1 {
		cap drop has_`var'
		gen has_`var' = ~missing(`var')
		cap drop log_`var'
		gen log_`var' = log(`var')
	}
	* Note that water_RA1 and water_RA2 are alternative measures of the same thing--water use for first Haynesville well completed
	* water_RA1 is the water used in the initial frac job. water_RA2 is all water used.
	* ProdC and ProdS are often similar but slightly different.
	* ProdC takes the production of the first well in the section to be completed
	* ProdS takes the production of the first well in the section to be spudded
	corr has_water_RA1 has_water_RA2 if flag_sample_descript_wdrilling // 97%+ correlation
	corr log_water_RA1 log_water_RA2 if flag_sample_descript_wdrilling  // 97%+ correlation
	corr has_Prod?_first*_gas if flag_sample_descript_wdrilling  // 99%+ correlation
	corr log_Prod?_first*_gas if flag_sample_descript_wdrilling  // 90-97% correlation. About 97% when comparing the C to the S.



	* Examining well-specific outcomes of first well (e.g., production, water inputs) as a function of drill time relative to first expiration date
		gen difdate = first_spud - leaseExpireFirst
		replace difdate = . if abs(difdate)>365.25*5

		gen n=_n
		local i = 1
		foreach var of varlist log_water_RA1 log_water_RA2 log_ProdC_first*_gas log_ProdS_first12_gas log_ProdS_first24_gas well_cost_RA1 log_well_cost_RA1 {

			cap drop newvar_x* newvar_s*
			local i = `i'+1

			lpoly `var' difdate if abs(difdate)<(3*365) & flag_sample_descript_wdrilling, gen(newvar_x newvar_s) nograph
			lpoly `var' difdate if abs(difdate)<(3*365) & difdate<0  & flag_sample_descript_wdrilling, gen(newvar_x1 newvar_s1) nograph
			lpoly `var' difdate if abs(difdate)<(3*365) & difdate>=0 & flag_sample_descript_wdrilling, gen(newvar_x2 newvar_s2) nograph
				qui sum n if ~missing(newvar_x1)
				local max1 = r(max)
			replace newvar_x1 = newvar_x2[_n-`max1'-1] if _n>`max1'
			replace newvar_s1 = newvar_s2[_n-`max1'-1] if _n>`max1'
				qui sum newvar_s1

				qui sum newvar_s
				local ymax = r(max)
				local ymin = r(min)
				local ydif = `ymax' - `ymin'

			if "`var'"=="log_water_RA1" local ytitle "log first frac water input"
			if "`var'"=="log_water_RA2" local ytitle "log total water"
			if "`var'"=="log_ProdC_first12_gas" local ytitle "log first 12 months gas production"
			if "`var'"=="log_ProdC_first6_gas"  local ytitle "log first 6 months gas production"
			if "`var'"=="log_ProdS_first12_gas"  local ytitle "log first 12 months gas production"
			if "`var'"=="log_ProdS_first24_gas"  local ytitle "log first 24 months gas production"
			if "`var'"=="well_cost_RA1" local ytitle "total well cost"
			if "`var'"=="log_well_cost_RA1" local ytitle "log well cost"

			graph set window fontface "Times New Roman"
			twoway line newvar_s1 newvar_x1, xline(0) lcolor(navy)|| ///
				scatter `var' difdate if abs(difdate)<3*365 & `var'<`ymax' + 2*`ydif' & ///
					`var'>`ymin' - 2*`ydif' & flag_sample_descript_wdrilling, msize(tiny) graphregion(color(white)) bgcolor(white) ///
					legend(off) xtitle("first spud - first lease expiration in days") ytitle("`ytitle'") xline(0, lcolor(cranberry)) mcolor(maroon) mfcolor(maroon) msymbol(circle)


			graph set window fontface default

			twoway line newvar_s1 newvar_x1, xline(0) lcolor(navy)|| ///
				scatter `var' difdate if abs(difdate)<3*365 & `var'<`ymax' + 2*`ydif' & ///
					`var'>`ymin' - 2*`ydif' & flag_sample_descript_wdrilling, msize(tiny) graphregion(color(white)) bgcolor(white) ///
					legend(off) xtitle("first spud - first lease expiration in days") ytitle("`ytitle'") xline(0, lcolor(cranberry)) mcolor(maroon) mfcolor(maroon) msymbol(circle)

			graph set window fontface "Times New Roman"
			twoway line newvar_s newvar_x, lcolor(navy) || ///
				scatter `var' difdate if abs(difdate)<3*365 & `var'<`ymax' + 3*`ydif' & ///
				`var'>`ymin' - 3*`ydif' & flag_sample_descript_wdrilling, msize(tiny) graphregion(color(white)) bgcolor(white) ///
				legend(off) xtitle("first spud - first lease expiration in days") ytitle("`ytitle'") mcolor(maroon) mfcolor(maroon) msymbol(circle)

			if inlist("`var'","log_ProdC_first12_gas","log_water_RA2","log_well_cost_RA1")  {
				graph export "${figdir}/section_descript/scatter_lpoly_`var'.pdf", replace
			}
			/* Commented out scratch figures
			if !inlist("`var'","log_ProdC_first12_gas","log_water_RA2","log_well_cost_RA1")  {
				graph export "${scratchfigdir}/section_descript/scatter_lpoly_`var'.pdf", replace
			}
			*/

			graph set window fontface default
			twoway line newvar_s newvar_x, lcolor(navy) || ///
				scatter `var' difdate if abs(difdate)<3*365 & `var'<`ymax' + 3*`ydif' & ///
				`var'>`ymin' - 3*`ydif' & flag_sample_descript_wdrilling, msize(tiny) graphregion(color(white)) bgcolor(white) ///
				legend(off) xtitle("first spud - first lease expiration in days") ytitle("`ytitle'") mcolor(maroon) mfcolor(maroon) msymbol(circle)
			if inlist("`var'","log_ProdC_first12_gas","log_water_RA2","log_well_cost_RA1")  {
				graph export "${beamerfigdir}/section_descript/scatter_lpoly_`var'.pdf", replace
			}

		}


