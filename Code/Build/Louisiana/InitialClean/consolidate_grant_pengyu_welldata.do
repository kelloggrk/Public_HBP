/*********************************************************
This file takes in both Pengyu's and Grant's hand-entered data and consolidates
the 4 files into one
*********************************************************/

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
global rawdir = "$dbdir/RawData/orig/Louisiana/DNR/WellInputs"
global outdir = "$dbdir/RawData/data/Louisiana/DNR/WellInputs"
global codedir = "$hbpdir/code/build/Louisiana"
global logdir = "$codedir/Logfiles"

log using "$logdir/consolidate_grant_pengyu_welldata_log.txt", replace text

/*********************************************************
IMPORT GRANT'S FIRST SPREADSHEET
CLEAN UP DATA AND CREATE THE LIST OF API NUMBERS
*********************************************************/

	import excel "$rawdir/GrantWellData.xlsx", case(lower) firstrow clear
	recast float water
	// Normalizing water volume's datatype.
	format %td most comp_date
	// Formats the data using %td for normalized visualisation.
	format api %13.0f
	gen datasource = "grant1"
	tempfile grant1
	duplicates report well_serial_num completion
	save "`grant1'"
	duplicates report well api town rang sec sea mos imp completion
	duplicates report well if missing(completion) // no duplicates
	duplicates report well if ~missing(completion) // some duplicates

	keep well api
	duplicates drop
	tempfile updateapi1
	save "`updateapi1'" // will be used because Pengyu's API numbers were corrupted

/*********************************************************
IMPORT PENGYU'S FIRST SPREADSHEET
CLEAN UP DATA AND MERGE WITH CORRECT API NUMBERS
*********************************************************/

	insheet using "$rawdir/PengyuWellData.csv", clear
	// v16 is simply an unnamed varaible that is added to flag data
	gen flagged = ~missing(v16)
	codebook v16 if ~missing(v16)
	drop v16
	// The two completion dates were initially coded using str9 type in Stata.
	// The following 10 lines change the data types to float and format them using %td.
	gen most_1 = date(most_recent_comp_approx, "DM20Y")
	format %td most_1
	order most_1, after(most_recent_comp_approx)
	drop most_recent_comp_approx
	rename most_1 most_recent_comp_approx

	gen comp_1=date(comp_date,"DM20Y")
	format %td comp_1
	drop comp_date
	rename comp_1 comp_date
	// The variable for number of completions was initially coded using str59.
	// The following 4 lines change number of completions from str type to int type so that
	// this variable can be used for merging.
	encode completion, gen(comp2)
	drop completion
	rename comp2 completion
	order completion, after(from)

	format api %13.0f
	duplicates report well_serial_num completion // this is where the duplicates are coming in

	* merges with corrected api numbers from grant's
	merge m:1 well_serial_num using "`updateapi1'", force update replace nogen

	sort search_order
	format api %13.0f
	gen datasource = "pengyu1"
	tempfile pengyu1
	save "`pengyu1'", replace
	duplicates report well if missing(completion) // no duplicates
	duplicates report well if ~missing(completion) // some duplicates

/*********************************************************
IMPORT GRANT'S SECOND SPREADSHEET AND PERFORM A SIMILAR
ROUTINE AS GRANT'S FIRST SPREADSHEET
*********************************************************/

	import excel "$rawdir/GrantWellData2.xlsx", case(lower) firstrow clear
	* Since water volume used double as data type, so there is no need to worry
	* about losing accuracy from merging.
	format %td most comp_date
	// Formats the data using %td for normalized visualization.
	gen datasource = "grant2"
	duplicates report well_serial_num completion

	tempfile grant2
	save "`grant2'", replace
	duplicates report well if missing(completion) // no duplicates
	duplicates report well if ~missing(completion) // some duplicates

	keep well api
	duplicates drop
	tempfile updateapi2
	save "`updateapi2'", replace

/*********************************************************
IMPORT PENGYU'S SECOND SPREADSHEET AND PERFORM A SIMILAR
ROUTINE AS PENGYU'S FIRST SPREADSHEET
*********************************************************/

	insheet using "$rawdir/PengyuWellData2.csv", clear
	tab v16 if !missing(v16)
	gen flagged = ~missing(v16)
	drop v16
	// The comments column is dropped for merging.
	recast double water
	// Normalize the data type for water volume.
	gen most_2 = date(most_recent_comp_approx, "DM20Y")
	format %td most_2
	order most_2, after(most_recent_comp_approx)
	drop most_recent_comp_approx
	rename most_2 most_recent_comp_approx

	gen comp_2=date(comp_date,"MD20Y")
	format %td comp_2
	drop comp_date
	rename comp_2 comp_date
	duplicates report well_serial_num completion

	merge m:1 well_serial_num using "`updateapi2'", force update replace nogen
	sort search_order completion
	gen datasource = "pengyu2"
	tempfile pengyu2
	save "`pengyu2'", replace
	duplicates report well if missing(completion) // no duplicates
	duplicates report well if ~missing(completion) // some duplicates

/*********************************************************
COMBINE ALL FOUR FILES NOW AND FIX ANY DISCREPANCIES
WITH THE LIST OF WELLS WE ORIGINALLY WANT IN THE DATASET
*********************************************************/

	use "`grant1'", clear
	append using "`grant2'"
	append using "`pengyu1'"
	append using "`pengyu2'"

	* fixes one observation where the well has two cases where completion==2
	replace completion=3 if comp_date==td(01may2015) & well_serial_num==241337
	* fixes one observation where section is recorded incorrectly
	* should be 36, not 16 for Well_Serial_Num==242774
	replace section = 36 if section==16 & well_serial_num==242774

	* which files have flags?
	tab datasource flagged, m // grant1 and grant2 have flags, pengyu1 and pengyu2 do not
		 *code that shows there is a 1:1 mapping between well_serial_num and api_num
		* is there a 1:1 mapping between an api number and a well_serial_num?

/*********************************************************
THE FOLLOWING SECTION IS USEFUL IN THE LOG FILES IF WE
WANT TO SEE SOME CHECKS ON THE MERGED FILE
*********************************************************/

		egen tag_serial = tag(well_serial_num)
		egen tag_api = tag(api_num)
		egen tag_aw = tag(api_num well_serial_num)
		egen tot_tag_in_serial = total(tag_aw), by(well_serial_num)
		tab tot_tag_in_serial if tag_serial   // all equal to 1
		egen tot_tag_in_api = total(tag_aw), by(api_num)
		tab tot_tag_in_api if tag_api         // all equal to 1
		drop tag_serial tag_api tag_aw tot_tag_in_serial tot_tag_in_api
		* looking at how many well serial numbers have completion data:
		egen tag_serial = tag(well_serial_num)
		duplicates report well_serial_num completion // only one duplicate
		duplicates tag well_serial_num completion, gen(duptag)
		duplicates report well_serial_num
		egen has_completion = max(completion!=.), by(well_serial_num)
		tab has_completion if tag_serial // all have at least one completion
		egen tot_completion = total(completion!=.), by(well_serial_num)
		tab tot_completion if tag_serial
		// ranges from 1 to 5
		tab tot_completion completion
		// this is very interesting. Shows that some wells have multiple completions that are listed as
		// completion = 6 or 7 -- associated with having only 1 total completion. So shouldn't these have completion = 1?
		// there seems to be one well_serial_num that seems to have two completion values -- 1 and 3 (but not 2)
		// similarly, there seems to be one well_serial_num that has two completion values = 2 and one = 1 -- this is case where duptag=1
		tab tot_completion completion if duptag
		drop tag_serial has_completion tot_completion
		* any wells that were in the search documents but not included?
		sort search_order
		egen tag_search_order = tag(search_order)
		sum search_order if tag_search_order
		di r(N)					// 2,754
		di r(max) - r(min) + 1  // 3,535 -- so 1-2,754/3,535 = 22% not in data bcause either has no frac input data or wasn't searched for
		drop tag_search_order
		* looks at whether completion numbers are relatively closely related to search order
		sort well_serial completion comp_date
		gen pre = well_serial==well_serial[_n-1] & !missing(completion) & !missing(completion[_n-1])
		gen post = well_serial==well_serial[_n+1] & !missing(completion) & !missing(completion[_n+1])
		gen comp_date_dif_neg = (comp_date - comp_date[_n-1])<=0 if pre
		sum comp_date_dif_neg if pre
		tab comp_date_dif_neg if pre
		*browse well_serial completion comp_date comp_date_dif_neg if pre | post
		sum well_serial if comp_date_dif_neg==1
		list well_serial completion comp_date if well_serial_num==r(mean)
		drop pre post comp_date_dif_neg

/*********************************************************
PERFORM SOME FINAL CLEANUPS TO THE ENTIRE DATASET
*********************************************************/

		* want to condition on whether it was on their list of well serial numbers
		gen from_RA_comp = 1
		replace completion = . if inlist(completion,6,7) // a few rogue cases
		egen has_RA_compinfo = max(completion!=.), by(well_serial_num)
		drop if has_RA_compinfo & completion == .
		tab has_RA_compinfo // only six well serial numbers where no completion data recorded by
		// RAs even though was included in the list for them to look at
		// so keep those observations--even though completion==.
		* and drop these cases because they are few and because it is a pain to reshape if completion==.
		drop if completion==.
		drop from_RA_comp has_RA_compinfo
		format api %14.0f
		keep well_serial_num api_num township range section completion watervolumeingallons numberofstages datatype hassandinfo comp_date flagged
		order well_serial_num api_num township range section completion comp_date flagged watervolumeingallons numberofstages datatype hassandinfo
		compress
		reshape wide comp_date flagged watervolumeingallons numberofstages datatype hassandinfo , i(well_serial_num api_num township range section) j(completion)
		* renames variables so that it is clear that they came from the RA frac inputs data
		ds well_serial_num, not
		foreach var of varlist `r(varlist)' {
			rename `var' RA_`var'
		}
		gen from_RAFracInputs = 1
		order from_RAFracInputs
		gen Well_Serial_Num = string(well_serial_num)
		duplicates report well_serial_num // should be none
		drop well_serial_num

		// save the final dataset
		saveold "$outdir/GrantPengyuFracInputs", replace

		// close out the log file
		capture log close
