/*
lease_summary_statistics.do -- outputs lease summary statistics table and 
single number tex files

*/

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
global leasedir = "$dbdir/IntermediateData/Louisiana/Leases"
global welldir = "$dbdir/IntermediateData/Louisiana/Wells"
global intdataLAdir = "$dbdir/IntermediateData/Louisiana"
global figdir = "$hbpdir/Paper/Figures"
global scratchfigdir = "$dbdir/Scratch/figures"
global codedir = "$hbpdir/Code/Analysis/Louisiana"
global logdir = "$codedir/LogFiles"
global logdir = "$hbpdir/Code/Analysis/Louisiana/LogFiles"

// Create log file
log using "$logdir/lease_summary_statistics_log.txt", replace text

********************************************************************************

set scheme tufte



/**************************************************************************
		PART 1: Program that pulls together section data
***************************************************************************/


cap program drop section_data
program define section_data
	version 14.1
	use "$unitdir/unit_data_with_prod.dta", clear
end

section_data // opens the unit data


	tempfile sample_sections
	save "`sample_sections'", replace

describe subsample*

/**************
* Leases
****************/


use "$leasedir/Clustering/clustered_at_90th_percentile_final.dta", replace
* Lease start date:
gen leaseStart = effdate
gen exprym = ym(year(original_exprdate),month(original_exprdate))
gen exprday = day(original_exprdate)
replace leaseStart = mdy(month(dofm(exprym - termmo)), exprday, year(dofm(exprym - termmo))) if mi(leaseStart)
replace leaseStart = instdate if mi(leaseStart)
drop exprym exprday

* Lease expiration date:
gen leaseExpire = original_exprdate
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

/*	Sample restrictions */
* THIS is similar to collapse_leases2section.do
tab insttype
keep if inlist(insttype,"LEASE","MEMO OF LEASE","LEASE EXTENSION","LEASE AMENDMENT")
drop if leaseStart < td(01jan2002) | leaseStart > td(31dec2015)
drop if instdate == original_exprdate
drop if leaseStart == leaseExpire

duplicates report leaseGroup township range section
duplicates report leaseGroup

sum area if area>0 & area<., detail
egen sd_area = sd(area), by(leaseGroup)
sum sd_area, detail


egen TRS_count = total(1), by(leaseGroup)
gen area_new = area/TRS_count


merge m:1 section township range using "`sample_sections'"
	keep if _merge == 3
	drop _merge



* variables included:
egen tag_lease = tag(leaseGroup)
duplicates report leaseGroup

egen lease_in_descript_subsample = max(flag_sample_descript), by(leaseGroup) // e.g., at least part of the lease is in our sample of sections
tab lease_in_descript_subsample if tag_lease



gen year_leaseStart = year(leaseStart)
label var year_leaseStart "Year lease starts"
gen year_leaseExpire = year(leaseExpire)
label var year_leaseExpire "Year lease ends"

label var termmo "Primary term length (months)"

gen has_ext = (leaseExpireExt - leaseExpire > 0) if leaseExpireExt - leaseExpire<.
tab has_ext optext // I prefer has_ext because
label var has_ext "Has extension clause"

gen exttermmo_pos = exttermmo if has_ext==1
label var exttermmo_pos "Extension length (months)"

gen extbonus_acre = extbonus/area
label var extbonus_acre "Extension bonus in $/acre"

label var bonus "Bonus in $"

gen royalty_100 = royalty*100
label var royalty_100 "Royalty rate"



gen area_pos = area if area>0 & area<.
label var area_pos "Area in acres"




label var has_ext "Indicator: Has extension clause"


************************************************************
/* Commented out code for computing lessee and operator shares
* Grantee and operator. Makes Latex tables of shares and cross-tabs.

* Grantees
	// recall that area_final is area of lease within TRS:
egen grantee_area = sum(area_final), by(alsgrantee)
gen big_grantee_flag = 1 if grantee_area > 42000
replace big_grantee_flag = 0 if big_grantee_flag == .
tab alsgrantee if big_grantee_flag==1 [iweight=area_final]
* CHESAPEAKE PETROHAWK, PRIDE O&G, R&R ROYALTY, SAMSON

count if flag_sample_descript
tab alsgrantee if flag_sample_descript==1 [iweight=area_final], sort
egen tag_grantee = tag(alsgrantee) if flag_sample_descript==1
egen area_grantee = total(area_final*flag_sample_descript) if flag_sample_descript, by(alsgrantee)
count if ~missing(area_grantee)
sum area_final if flag_sample_descript==1
di r(mean)*r(N)
gen share_grantee = area_grantee / ( r(mean)*r(N))
gen share2_grantee = share_grantee^2
total share_grantee share2_grantee if flag_sample_descript & tag_grantee
sum share2_grantee if flag_sample_descript & tag_grantee
local grantee_hhi = round(r(mean)*r(N),.001)
local grantee_hhi 0`grantee_hhi'
di "`grantee_hhi'"

* writes a file
cap erase "$figdir/single_numbers_tex/lessee_hhi.tex"
cap file close lessee_hhi
file open lessee_hhi using "$figdir/single_numbers_tex/lessee_hhi.tex", write
file write lessee_hhi "`grantee_hhi'"
file close lessee_hhi


gen grantee_mod = proper(alsgrantee) if share_grantee>=0.02 & share_grantee<.
replace grantee_mod = subinstr(grantee_mod, "Sgs", "SGS", 1)
replace grantee_mod = subinstr(grantee_mod, "O&G", "O\&G", .)
replace grantee_mod = "Others" if share_grantee<0.02
tab grantee_mod if flag_sample_descript == 1 [iweight=area_final], sort nofreq
egen tag_grantee_mod = tag(grantee_mod) if flag_sample_descript
replace tag_grantee_mod = 0 if missing(tag_grantee_mod)

// For making into Latex Table:
egen area_grantee_mod = total(area_final*flag_sample_descript) if flag_sample_descript, by(grantee_mod)
sum area_final if flag_sample_descript == 1
gen share_grantee_mod = area_grantee_mod/( r(mean)*r(N) )
gen for_sort = share_grantee_mod
replace for_sort = -share_grantee_mod if grantee_mod == "Others"

gsort -tag_grantee_mod -for_sort
list grantee_mod share_grantee_mod if tag_grantee_mod

gen     for_latex = "\begin{tabular}{l c}\midrule\midrule" in 1
replace for_latex = "\multicolumn{1}{c}{Leasee Name} & Share  \\ \midrule" in 2

local in_while = 1
local n = 1
while `in_while' ==1 {

	local position = `n'+3

	*di grantee_mod[`n'] "   " share_grantee_mod[`n']
	local grantee_name = grantee_mod[`n']

	local grantee_share "`: di %5.3f share_grantee_mod[`n']'"
	di "`grantee_name'  `grantee_share'"

	replace for_latex = "`grantee_name' & `grantee_share' \\" in `position'

	*if `n'>=10 local still_grantee_mod = 0

	local n = `n'+1

	if tag_grantee_mod[`n']==0 local in_while = 0

}
di `position' "   " `n'

local position = `position'+1
replace for_latex = "\midrule HHI: & `grantee_hhi' \\ " in `position'
local position = `position'+1
replace for_latex = "\midrule \end{tabular}" in `position'

list for_latex if ~missing(for_latex), noobs clean

drop for_latex for_sort



* Operators:
tab unitOperator if flag_sample_descript==1 [iweight=area_final], sort
codebook unitOperator if flag_sample_descript & ~missing(alsgrantee)
gen operator_mod = unitOperator
replace operator_mod = "Missing/no unit" if missing(unitOperator) & flag_sample_descript==1
egen tag_operator = tag(operator_mod) if flag_sample_descript==1
egen area_operator = total(area_final*flag_sample_descript) if flag_sample_descript, by(operator_mod)
sum area_final if flag_sample_descript==1
di r(mean)*r(N)
gen share_operator = area_operator / ( r(mean)*r(N))
gen share2_operator = share_operator^2
total share_operator share2_operator if flag_sample_descript & tag_operator
sum share2_operator if flag_sample_descript & tag_operator
local operator_hhi = round(r(mean)*r(N),.001)
local operator_hhi 0`operator_hhi'
di "`operator_hhi'"

* writes a file
cap erase "$figdir/single_numbers_tex/operator_hhi.tex"
cap file close operator_hhi
file open operator_hhi using "$figdir/single_numbers_tex/operator_hhi.tex", write
file write operator_hhi "`operator_hhi'"
file close operator_hhi


tab operator_mod if flag_sample_descript [iweight=area_final], sort
gen operator_mod2 = operator_mod if share_operator >= 0.02 & share_operator<. & operator_mod!="Missing/no unit" & flag_sample_descript==1
replace operator_mod2 = word(operator_mod2,1)
replace operator_mod2 = "Others" if (share_operator < 0.02 | operator_mod=="Missing/no unit") & flag_sample_descript==1
replace operator_mod2 = subinstr(operator_mod2,",","",.)
tab operator_mod2
egen tag_operator_mod2 = tag(operator_mod2) if flag_sample_descript

tab operator_mod2 if flag_sample_descript [iweight=area_final], sort
egen area_operator_mod2 = total(area_final*flag_sample_descript) if flag_sample_descript, by(operator_mod2)
sum area_final if flag_sample_descript == 1
gen share_operator_mod2 = area_operator_mod2/( r(mean)*r(N) )
gen for_sort = share_operator_mod2
replace for_sort = -share_operator_mod2 if operator_mod2 == "Others"

gsort -tag_operator_mod2 -for_sort
list operator_mod2 share_operator_mod2 if tag_operator_mod2

gen     for_latex = "\begin{tabular}{l c}\midrule\midrule" in 1
replace for_latex = "\multicolumn{1}{c}{ } & Share  \\ \midrule" in 2


di "`operator_hhi'"

local in_while = 1
local n = 1
while `in_while' ==1 {

	local position = `n'+3
	local operator_name = operator_mod2[`n']
	local operator_share "`: di %5.3f share_operator_mod2[`n']'"

	replace for_latex = "`operator_name' & `operator_share' \\" in `position'
	local n = `n'+1

	if tag_operator_mod2[`n']==0 local in_while = 0

}

local position = `position'+1
replace for_latex = "\midrule HHI: & `operator_hhi' \\ " in `position'
local position = `position'+1
replace for_latex = "\midrule \end{tabular}" in `position'

list for_latex if ~missing(for_latex), noobs clean

drop for_latex for_sort



* Grantees and operators together
tab grantee_mod operator_mod2 if flag_sample_descript [iweight=area_final], nofreq row
tab grantee_mod operator_mod2 if flag_sample_descript [iweight=area_final], nofreq col

* for Latex:
preserve
keep if flag_sample_descript == 1
egen total_area_grantee_operator = total(area_final), by(grantee_mod operator_mod2)
keep grantee_mod operator_mod2 total_area_grantee_operator share_operator_mod2 share_grantee_mod
duplicates drop

duplicates report grantee_mod operator_mod2
* fills in missing observations:
	encode grantee_mod, gen(Rgrantee_mod)
	encode operator_mod2, gen(Roperator_mod2)
	drop grantee_mod operator_mod2
	tsset Rgrantee_mod Roperator_mod2
	gen orig_data = 1
	count
	tsfill, full
	count
	decode Rgrantee_mod, gen(grantee_mod)
	decode Roperator_mod2, gen(operator_mod2)
	drop Rgrantee_mod Roperator_mod2
	tab grantee_mod operator_mod2

	replace orig_data = 0 if missing(orig_data)
	replace total_area_grantee_operator = 0 if orig_data==0
	egen mean_share_operator = mean(share_operator_mod2), by(operator_mod2)
	egen mean_share_grantee  = mean(share_grantee_mod)  , by(grantee_mod)
	replace share_operator_mod2 = mean_share_operator if orig_data==0
	replace share_grantee_mod   = mean_share_grantee  if orig_data==0
	drop orig_data mean_share_operator mean_share_grantee
	sort grantee_mod operator_mod2


egen tag_operator = tag(operator_mod2)
count if tag_operator
local operator_count = r(N)
egen tag_grantee = tag(grantee_mod)
count if tag_grantee
local grantee_count = r(N)
di `operator_count' "  " `grantee_count'

tab grantee_mod operator_mod2
gen grantee_sort = share_grantee_mod
replace grantee_sort = -grantee_sort if grantee_mod == "Others"
gen operator_sort = share_operator_mod2
replace operator_sort = -operator_sort if operator_mod2 == "Others"
gsort -grantee_sort -operator_sort

foreach string in Pride Audubon Honeycutt SGS Long {
	replace grantee_mod = "`string'" if strpos(grantee_mod,"`string'")
}


forvalues j = 1/`operator_count' {
	local col_c `col_c' c
}
local col_c `col_c' | c
di "`col_c'"
local row_mostly_ands { } & Operators:
forvalues j = 1/`operator_count' {

	if `j'<`operator_count' local row_mostly_ands `row_mostly_ands' &
	if `j'==`operator_count' local row_mostly_ands `row_mostly_ands' & Lessee
}
local row_mostly_ands `row_mostly_ands' \\
di "`row_mostly_ands'"

gen     for_latex = "\begin{tabular}{l | `col_c'} \midrule\midrule" in 1
replace for_latex = "`row_mostly_ands'" in 2
replace for_latex = "Lessees: " in 3
forvalues n = 1/`operator_count' {
	local column_heading = operator_mod2[`n']
	replace for_latex = for_latex + " & `column_heading'" if _n==3
}
replace for_latex = for_latex + " & share" if _n==3
replace for_latex = for_latex + " \\ \midrule" if _n==3
list for_latex if ~missing(for_latex)
egen total_for_operator = total(total_area_grantee_operator), by(operator_mod2)


forvalues i=1/`grantee_count' {

	local position = `i'+3
	di "NEW ROW:"

	local n1 = `operator_count'*(`i'-1)+1
	qui replace for_latex = grantee_mod[`n1'] in `position'

	forvalues j = 1/`operator_count' {

		local n2 = `operator_count'*(`i'-1)+`j'

		local share = total_area_grantee_operator[`n2']/total_for_operator[`n2']
		local share "`: di %5.3f `share''"


		* replace for_latex = for_latex + " & "

		di "    " grantee_mod[`n2'] "   " operator_mod2[`n2'] "  " "`share'"

		if grantee_mod[`n2']==operator_mod2[`n2'] & operator_mod2[`n2']!="Others" {
			qui replace for_latex = for_latex + " & \textbf{`share'}" in  `position'
		}
		else {
			qui replace for_latex = for_latex + " & `share'" in  `position'
		}
	}

	local share_grantee = share_grantee_mod[`n1']
	local share_grantee "`: di %5.3f `share_grantee''"
	di "  Right column: `share_grantee'"

	qui replace for_latex = for_latex + " & `share_grantee' \\" in `position'
}

local position = `position' + 1
replace for_latex = " Total" in `position'
forvalues n = 1/`operator_count' {
	local column_heading = operator_mod2[`n']
	replace for_latex = for_latex + " & 1" in `position'
}
replace for_latex = for_latex + " & \\" in `position'
local position = `position' + 1
replace for_latex = "\midrule Oper. share" in `position'
forvalues n = 1/`operator_count' {
	local op_share = share_operator_mod2[`n']
	di "`op_share'"
	local op_share2 "`: di %5.3f `op_share''"
	*di "`op_share2'"
	replace for_latex = for_latex + " & `op_share2'" in `position'
}
replace for_latex = for_latex + "\\" in `position'
local position = `position' + 1
replace for_latex = "\midrule \midrule \end{tabular}" in `position'
list for_latex if ~missing(for_latex), noobs clean

outsheet for_latex using "$figdir/lease_descript/lessee_operator_crosstab.tex" if ~missing(for_latex), replace nonames noquote

restore
drop tag_grantee-share_operator_mod2

* End of code to make latex tabulations
****************************************



gen big_operator_flag = 1 if unitOperator == "Chesapeake Operating Inc." | ///
unitOperator == "Petrohawk Operating Company" | ///
unitOperator == "Encana Oil and Gas USA Inc."
replace big_operator_flag = 0 if big_operator_flag == . & unitOperator != ""

*/


* Summary statistics table
		sutex2 year_leaseStart year_leaseExpire termmo royalty_100 ///
			has_ext exttermmo_pos area_pos if lease_in_descript_subsample & tag_lease, ///
			varlabels percentiles(5 50 95) digits(1) tabular ///
			saving("$figdir/lease_descript/descript_table_lease.tex") replace
			
				sum year_leaseStart year_leaseExpire termmo royalty_100 ///
				has_ext exttermmo_pos area_pos if lease_in_descript_subsample & tag_lease, detail

		* Outputs some single numbers from the table for using in text
			count if lease_in_descript_subsample & tag_lease
				local lease_count = strofreal( r(N), "%6.0fc")
					file open foo using "${figdir}/single_numbers_tex/lease_count.tex", write replace
					file write foo "`lease_count'"
					file close foo
			sum year_leaseStart if lease_in_descript_subsample & tag_lease, detail
				local earlier_lease_start = r(p5)
					file open foo using "${figdir}/single_numbers_tex/earlier_lease_start.tex", write replace
					file write foo "`earlier_lease_start'"
					file close foo
				local later_lease_start = r(p95)
					file open foo using "${figdir}/single_numbers_tex/later_lease_start.tex", write replace
					file write foo "`later_lease_start'"
					file close foo
			qui tab termmo if lease_in_descript_subsample & tag_lease, sort matcell(matcell) matrow(matrow)
				local most_common_termmo = strofreal(matrow[1,1],"%7.0fc")
				di strofreal(matrow[1,1],"%7.0fc")
					file open foo using "${figdir}/single_numbers_tex/most_common_termmo.tex", write replace
					file write foo "`most_common_termmo'"
					file close foo
			sum royalty_100 if lease_in_descript_subsample & tag_lease, detail
				local higher_royalty = round(r(p95))
					file open foo using "${figdir}/single_numbers_tex/higher_royalty.tex", write replace
					file write foo "`higher_royalty'"
					file close foo
				local lower_royalty = round(r(p5))
					file open foo using "${figdir}/single_numbers_tex/lower_royalty.tex", write replace
					file write foo "`lower_royalty'"
					file close foo
			qui tab royalty_100 if lease_in_descript_subsample & tag_lease, sort matcell(matcell) matrow(matrow)
				local most_common_royalty = matrow[1,1]
					file open foo using "${figdir}/single_numbers_tex/most_common_royalty.tex", write replace
					file write foo "`most_common_royalty'"
					file close foo
			sum has_ext if lease_in_descript_subsample & tag_lease
				local frac_with_ext_clause = round(r(mean)*100)
					file open foo using "${figdir}/single_numbers_tex/frac_with_ext_clause.tex", write replace
					file write foo "`frac_with_ext_clause'"
					file close foo
			tab exttermmo_pos if exttermmo_pos>0 & exttermmo_pos<. & lease_in_descript_subsample & tag_lease, matrow(matrow)
				local most_common_exttermmo = matrow[1,1]
					file open foo using "${figdir}/single_numbers_tex/most_common_exttermmo.tex", write replace
					file write foo "`most_common_exttermmo'"
					file close foo
			sum area_pos if area_pos>0 & area_pos<. & lease_in_descript_subsample & tag_lease, detail
				local lower_area = strofreal(round(r(p5),.01),"%09.2fc")
					file open foo using "${figdir}/single_numbers_tex/lower_area.tex", write replace
					file write foo "`lower_area'"
					file close foo
				local mean_area = round(r(mean))
					file open foo using "${figdir}/single_numbers_tex/mean_area.tex", write replace
					file write foo "`mean_area'"
					file close foo
				local higher_area = round(r(p95),10)
					file open foo using "${figdir}/single_numbers_tex/higher_area.tex", write replace
					file write foo "`higher_area'"
					file close foo
				
				
					
			
			egen tot_lease_in_section = total(lease_in_descript_subsample & tag_lease), by(township range section)
			egen tag2_TRS = tag(township range section)
			egen TRS_has_sample = max(lease_in_descript_subsample & tag_lease), by(township range section)
			sum tot_lease_in_section if tag2_TRS & TRS_has_sample, detail
				local av_lease_in_TRS = round(r(mean))
					file open foo using "${figdir}/single_numbers_tex/leases_per_section.tex", write replace
					file write foo "`av_lease_in_TRS'"
					file close foo
			drop tot_lease_in_section tag2_TRS TRS_has_sample
		
		
	
	
				
				
		/* commented out scratch tables	and figures		
		sutex2 year_leaseStart year_leaseExpire termmo royalty_100 ///
			has_ext exttermmo_pos area_pos if lease_in_descript_subsample & big_operator_flag==1 & tag_lease, ///
			varlabels percentiles(5 50 95) digits(1) tabular ///
			saving("${scratchfigdir}/descript_table_lease_big_operator.tex") replace
				sum year_leaseStart year_leaseExpire termmo royalty_100 ///
				has_ext exttermmo_pos area_pos if lease_in_descript_subsample & tag_lease, detail

		sutex2 year_leaseStart year_leaseExpire termmo royalty_100 ///
			has_ext exttermmo_pos area_pos if lease_in_descript_subsample & big_operator_flag==0 & tag_lease, ///
			varlabels percentiles(5 50 95) digits(1) tabular ///
			saving("${scratchfigdir}/descript_table_lease_small_operator.tex") replace
				sum year_leaseStart year_leaseExpire termmo royalty_100 ///
				has_ext exttermmo_pos area_pos if lease_in_descript_subsample & tag_lease, detail

		sutex2 year_leaseStart year_leaseExpire termmo royalty_100 ///
			has_ext exttermmo_pos area_pos if lease_in_descript_subsample & big_grantee_flag==1 & tag_lease, ///
			varlabels percentiles(5 50 95) digits(1) tabular ///
			saving("${scratchfigdir}/descript_table_lease_big_grantee.tex") replace
				sum year_leaseStart year_leaseExpire termmo royalty_100 ///
				has_ext exttermmo_pos area_pos if lease_in_descript_subsample & tag_lease, detail

		sutex2 year_leaseStart year_leaseExpire termmo royalty_100 ///
			has_ext exttermmo_pos area_pos if lease_in_descript_subsample & big_grantee_flag==0 & tag_lease, ///
			varlabels percentiles(5 50 95) digits(1) tabular ///
			saving("${scratchfigdir}/descript_table_lease_small_grantee.tex") replace
				sum year_leaseStart year_leaseExpire termmo royalty_100 ///
				has_ext exttermmo_pos area_pos if lease_in_descript_subsample & tag_lease, detail

		sutex2 year_leaseStart year_leaseExpire termmo royalty_100 ///
			has_ext exttermmo_pos if lease_in_descript_subsample & tag_lease ///
			& area>0 & area<. [aweight=area], ///
			varlabels percentiles(5 50 95) digits(1) tabular ///
			saving("${scratchfigdir}/descript_table_leaseACREW.tex") replace

		sum year_leaseStart year_leaseExpire termmo royalty_100 ///
			has_ext exttermmo_pos if lease_in_descript_subsample & tag_lease ///
			& area>0 & area<. [aweight=area], detail

		* Start dates
		gen ym = ym(year(leaseStart),month(leaseStart))
		label var ym "Lease start date"

		bys ym: gen ym_lease_starts = _N
		bys ym: egen ym_lease_area = sum(area)
		egen ym_tag = tag(ym)

		* Royalty rates
		gen round_royalty = 10000*royalty*inlist(royalty,0.125, 0.1667, 0.1875, 0.2, 0.225, 0.25)
		label def roundlbl 1250 "12.5%" 1667 "16.7%" 1875 "18.75%" 2000  ///
						   "20%" 2250 "22.5%" 2500 "25%" 0 "Other/Missing"

		tab round_royalty

		* Presence of extension
		replace exttermmo = 0 if mi(exttermmo)
		gen ext_yrs = exttermmo/12
		tab ext_yrs

		* Extension bonus info?
		gen mi_extbonus = mi(extbonus)
		summ extbonus, d
		tab mi_extbonus if exttermmo > 0

		* Area
		gen area_640 = min(area,640)
		label var area_640 "Acres, censored at 640"
		summ area_640 if area > 0, d

		sort area
		gen area_lease_cdf = _n/_N
		label var area_lease_cdf "CDF, no. lease documents"

		gen area_sum = sum(area)
		gen area_sum_cdf = area_sum/area_sum[_N]
		label var area_sum_cdf "CDF, total area"

		* CDF of area by documents
		line area_lease_cdf area_640, sort ///
			xline(40 80 120 160 320 640, lpattern(-) lcolor(gs12))	///
			xlabel(40 80 120 160 320 640) ///
			title("CDF, number of documents")
			gr export "$scratchfigdir/lease_descript/area_cdf_leasedoc.pdf", as(pdf) replace

		* CDF of area by cumulative area
		line area_sum_cdf area_640, sort ///
			xline(40 80 120 160 320 640, lpattern(-) lcolor(gs12)) ///
			xlabel(40 80 120 160 320 640) ///
			title("CDF, total area")

			gr export "$scratchfigdir/lease_descript/area_cdf_area.pdf", as(pdf) replace

		*/
