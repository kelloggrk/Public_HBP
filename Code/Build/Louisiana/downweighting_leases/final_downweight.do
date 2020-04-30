* Code to construct area downweights after the clustering algorithm has run.

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
global indir = "$dbdir/IntermediateData/Louisiana/Leases/Clustering"
global codedir = "$hbpdir/Code/Build/Louisiana"
global logdir = "$codedir/Logfiles"

* logfile for this
log using "$logdir/final_downweighting_log.txt", replace text

* user input 2,3,4 are the year, month, and day of calibration date, respectively
local folderlist clustered_at_85th_percentile clustered_at_90th_percentile clustered_at_95th_percentile
local count = 0
foreach dir in `folderlist' {
    * cd into the directory that contains all of the quarter-level clustering output
    cd "$indir/`dir'"
    * create a local list of all files in the directory we produced quarter-level clustering from
    local files : dir . files "*.dta"
    local filedates : subinstr local files "leased_during_" "", all     
    local filedates : subinstr local filedates ".dta" "", all           
    local filedates : subinstr local filedates `"""' "", all           
    local filedates : list sort filedates                              
	cd "$hbpdir"		
	
    use "$leasedir/louisiana_leases_csvs_preliminary_downweight.dta"
    tempfile final_clustered
    save "`final_clustered'"
	
    * this local variable is used to cycle through and name each clustered variable in our final datset
    * think of it as a counter that goes through the for loop
    local quarter = 0
	di "`filedates'"
    foreach filedate in `filedates' {
		local quarter = `filedate'
        di "`quarter'"
        di "leased_during_`filedate'.dta"
		use "$indir/`dir'/leased_during_`filedate'.dta", clear
		* Decoding all strings from R
		decode insttype, gen(inst2)
		drop insttype
		ren inst2 insttype
		decode grantor, gen(grantor2)
		drop grantor
		ren grantor2 grantor
		decode grantor_orig, gen(grantor_orig2)
		drop grantor_orig
		ren grantor_orig2 grantor_orig
		decode alsgrantee, gen(alsgrantee2)
		drop alsgrantee
		ren alsgrantee2 alsgrantee
		decode recordno, gen(recordno2)
		drop recordno
		ren recordno2 recordno
		decode group_final, gen(group_final2)
		drop group_final
		ren group_final2 group_final

        * drop a few variables to deal with some R and Stata string type mismatching
        drop grantor
        drop grantor_orig
        drop alsgrantee
        drop area

        egen count_duplicate_agglom`quarter' = total(1), by(duplicate_group_id)
        * generate area_revised_2 in order to evaluate further_downweight weight variables
        * which is this quarter's downweighted area via clustering
        gen area_revised_2 = area_revised*(1/count_duplicate_agglom`quarter')
        * create the actual clustered weight variable that is quarter-specific
        gen clustered_downweight_`quarter' = 1/count_duplicate_agglom`quarter'
        * create a variable that captures area leased in a section once clustering has taken place
        egen total_area_revised_2 = total(area_revised_2), by(township range section)
        * use this to create the further_downweight variable that is also quarter-specific
        gen further_downweight_`quarter' = total_section_area/total_area_revised_2 if total_area_revised_2 > total_section_area
        replace further_downweight_`quarter' = 1 if total_section_area >= total_area_revised_2
        * finally, merge this in with the parent datafile and then continue
        merge 1:1 unique_id using "`final_clustered'", nogen force
        save "`final_clustered'", replace
    }
    order *, sequential
    cap drop tag_TRS

    * average all of the quarter-specific clustered downweights and further downweights
    egen av_clustered_downweight = rmean(clustered_downweight*)
	egen av_inverse_clustered_downweight = rmean(count_duplicate_agglom*)
	gen av_clustered_downweight_inverse = 1/av_inverse_clustered_downweight

    * Now loops over observations to find total area for a selection of dates
    cap drop tag_TRS
	gen max_frac_area = 0
	gen max_frac_area_inverse = 0
    forvalues yyyy = 2005/2016 {
        if `yyyy'<2016 local mm_range 1(3)10
        if `yyyy'==2016 local mm_range 1/1
        forvalues mm = `mm_range' {
            local check_date = mdy(`mm',1,`yyyy')
            local R_date = `check_date' - mdy(1,1,1970) + mdy(1,1,1960)
            di  `R_date'

            egen arealeased_`R_date' = total(area_revised*av_clustered_downweight*(startdate<=`check_date' & cluster_exprdate>=`check_date')), by(township range section)
            egen arealeased_inverse_`R_date'= total(area_revised*av_clustered_downweight_inverse*(startdate<=`check_date' & cluster_exprdate>=`check_date')), by(township range section)

			gen fracleased_`R_date' = arealeased_`R_date'/total_section_area
			gen fracleased_inverse_`R_date' = arealeased_inverse_`R_date'/total_section_area
            drop arealeased_`R_date'
			drop arealeased_inverse_`R_date'
			di "`yyyy'"
			egen tag_TRS = tag(township range section) if (startdate<=`check_date' & cluster_exprdate>=`check_date')
			sum fracleased_`R_date' if tag_TRS, detail
			sum fracleased_inverse_`R_date' if tag_TRS, detail
			drop tag_TRS
            replace max_frac_area = max(max_frac_area, fracleased_`R_date')
			replace max_frac_area_inverse = max(max_frac_area, fracleased_inverse_`R_date')

        }
    }
    egen tag_TRS = tag(township range section)
    sum max_frac_area if tag_TRS, detail
	sum max_frac_area_inverse if tag_TRS, detail

    * Final weight
    gen final_downweight = av_clustered_downweight/max(1,max_frac_area)
    gen area_final = area_revised*final_downweight
	
	di "$indir/`dir'_final.dta"
    save "$indir/`dir'_final.dta", replace
}

capture log close
exit
