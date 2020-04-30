/*********************************************************
This file takes in both Will's and Grant/Pengyu's hand-entered data, hand checks each
discrepancy against the pdfs, and executes replace commands to fix all discrepancies
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

log using "$logdir/haynesville_well_inputs_merge_log.txt", replace text

// Import GrantPengyu's merged input data
use "$outdir/GrantPengyuFracInputs.dta"
// Renaming GrantPengyu variable
ren Well_Serial_Num well_serial_num
order well_serial_num
tempfile temp_GrantPengyuFracInputs
// Save as a temporary .dta file
save "`temp_GrantPengyuFracInputs'"

clear all

// Import statement for Will Patterson's second entry .csv file
import delimited "$rawdir/patterson_well_completion_data.csv"

// destring date
gen patterson_completion_date_ = date(subinstr(comp_date, "/","-",.), "MD20Y")

// sorting
sort well_serial_num completion

// droping unwanted variables
drop comp_date
drop search_order
drop flagged
drop v17

// renaming variables to match grantpegnyu format
rename watervolumeingallons will_water_volume_
rename numberofstages will_number_of_stages_
rename datatype will_data_type_
rename hassandinfo has_sand_info_

// fixing duplicate well number completion number conflict
replace completion=2 if well_serial_num == 241134 & will_water_volume_==0
replace completion=2 if well_serial_num == 241341 & will_water_volume_==0
replace completion=2 if well_serial_num == 241033 & will_water_volume_==0
replace completion=2 if well_serial_num == 240948 & will_water_volume_==0
replace completion=2 if well_serial_num == 240457 & will_water_volume_==0
replace completion=2 if well_serial_num == 238819 & will_water_volume_==0
replace completion=2 if well_serial_num == 238107 & will_water_volume_==0
replace completion=2 if well_serial_num == 237457 & will_water_volume_==0
replace completion=2 if well_serial_num == 234022 & will_water_volume_==0
replace completion=2 if well_serial_num == 241328 & will_water_volume_==5135928
replace completion=2 if well_serial_num == 241691 & will_water_volume_==0

// deleting second completion for well 241486
drop if well_serial_num==241486 & will_number_of_stages_==6

// reshape wide to merge
reshape wide will_water_volume_ will_number_of_stages_ will_data_type_ has_sand_info_ patterson_completion_date_, i(well_serial_num)j(completion)

// making serial number a string
tostring well_serial_num , gen(new_well_serial_num) format (%02.0f)
drop well_serial_num
rename new_well_serial_num well_serial_num

// merging patterson with grant_pengyu
merge 1:1 well_serial_num using "`temp_GrantPengyuFracInputs'"

// formating Will's variables to be in same format as Grant/Pengyu's
format will_water_volume_1 %10.0g
format will_water_volume_2 %10.0g
format will_water_volume_3 %10.0g
format will_water_volume_4 %10.0g
format will_water_volume_5 %10.0g
recast float RA_watervolumeingallons1, force
recast float RA_watervolumeingallons2
recast float RA_watervolumeingallons3
recast float RA_watervolumeingallons4
recast float RA_watervolumeingallons5

// to find missing data from grant_pengyu: drop if _merge==3

************** Fix discrepancies  **************************************************
* Each segment has a comment block with code used to identify discrepancies
* Each segment then makes the checks and enters the data
* This is done by order of completion (a well's 1st completion, 2nd completion, etc.)

/*
	gen flag_water_volume_1 = 0
	replace flag_water_volume_1 = 1 if will_water_volume_1 !=RA_watervolumeingallons1
	drop if flag_water_volume_1 == 0
	order well_serial_num will_water_volume_1 RA_watervolumeingallons1
*/

replace RA_watervolumeingallons1 = will_water_volume_1 if well_serial_num== "231883"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "234017"
replace RA_watervolumeingallons1 = will_water_volume_1 if well_serial_num== "235057"
replace RA_watervolumeingallons1 = will_water_volume_1 if well_serial_num== "235554"
replace RA_watervolumeingallons1 = will_water_volume_1 if well_serial_num== "236727"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "236902"
replace RA_watervolumeingallons1 = will_water_volume_1 if well_serial_num== "236989"
replace RA_watervolumeingallons1 = will_water_volume_1 if well_serial_num== "237156"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "237195"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "237289"
replace RA_watervolumeingallons1 = will_water_volume_1 if well_serial_num== "237465"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "237643"
replace RA_watervolumeingallons1 = will_water_volume_1 if well_serial_num== "237669"
replace RA_watervolumeingallons1=1302252 if well_serial_num== "237764"
replace will_water_volume_1=1302252 if well_serial_num== "237764"
replace RA_watervolumeingallons1=1171440 if well_serial_num== "237838"
replace will_water_volume_1=1171440 if well_serial_num== "237838"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "238169"
replace RA_watervolumeingallons1 = will_water_volume_1 if well_serial_num== "238186"
replace RA_watervolumeingallons1 = will_water_volume_1 if well_serial_num== "238212"
replace RA_watervolumeingallons1 = will_water_volume_1 if well_serial_num== "238485"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "238620"
replace RA_watervolumeingallons1 = will_water_volume_1 if well_serial_num== "238715"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "238773"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "239055"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "239161"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "239383"
replace RA_watervolumeingallons1=3403063 if well_serial_num== "239385"
replace will_water_volume_1=3403063 if well_serial_num== "239385"
replace RA_watervolumeingallons1 = will_water_volume_1 if well_serial_num== "239459"
replace RA_watervolumeingallons1 = will_water_volume_1 if well_serial_num== "239477"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "239521"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "239539"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "239563"
replace RA_watervolumeingallons1 = will_water_volume_1 if well_serial_num== "239589"
replace RA_watervolumeingallons1 = will_water_volume_1 if well_serial_num== "239595"
replace RA_watervolumeingallons1 = will_water_volume_1 if well_serial_num== "239598"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "239624"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "239653"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "239656"
replace RA_watervolumeingallons1 = will_water_volume_1 if well_serial_num== "239663"
replace will_water_volume_1=3719306 if well_serial_num== "239718"
replace RA_watervolumeingallons1=3719306 if well_serial_num== "239718"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "239719"
replace RA_watervolumeingallons1 = will_water_volume_1 if well_serial_num== "239782"
replace RA_watervolumeingallons1 = will_water_volume_1 if well_serial_num== "239804"
replace RA_watervolumeingallons1 = will_water_volume_1 if well_serial_num== "239817"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "239894"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "239920"
replace RA_watervolumeingallons1 = will_water_volume_1 if well_serial_num== "239925"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "239987"
replace RA_watervolumeingallons1 = will_water_volume_1 if well_serial_num== "240029"
replace RA_watervolumeingallons1 = will_water_volume_1 if well_serial_num== "240034"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "240043"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "240050"
replace RA_watervolumeingallons1 = will_water_volume_1 if well_serial_num== "240075"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "240115"
replace RA_watervolumeingallons1 = will_water_volume_1 if well_serial_num== "240117"
replace RA_watervolumeingallons1 = will_water_volume_1 if well_serial_num== "240128"
replace RA_watervolumeingallons1 = will_water_volume_1 if well_serial_num== "240160"
replace RA_watervolumeingallons1 = will_water_volume_1 if well_serial_num== "240185"
replace RA_watervolumeingallons1 = will_water_volume_1 if well_serial_num== "240236"
replace RA_watervolumeingallons1 = will_water_volume_1 if well_serial_num== "240237"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "240301"
replace RA_watervolumeingallons1 = will_water_volume_1 if well_serial_num== "240322"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "240324"
replace RA_watervolumeingallons1 = will_water_volume_1 if well_serial_num== "240342"
replace RA_watervolumeingallons1 = will_water_volume_1 if well_serial_num== "240347"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "240388"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "240494"
replace RA_watervolumeingallons1 = will_water_volume_1 if well_serial_num== "240547"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "240609"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "240624"
replace RA_watervolumeingallons1 = will_water_volume_1 if well_serial_num== "240632"
replace RA_watervolumeingallons1 = will_water_volume_1 if well_serial_num== "240638"
replace RA_watervolumeingallons1 = will_water_volume_1 if well_serial_num== "240653"
replace RA_watervolumeingallons1 = will_water_volume_1 if well_serial_num== "240725"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "240921"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "240924"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "240929"
replace RA_watervolumeingallons1 = will_water_volume_1 if well_serial_num== "240934"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "240989"
replace will_water_volume_1=13157197 if well_serial_num== "240996"
replace RA_watervolumeingallons1=13157197 if well_serial_num== "240996"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "241097"
replace RA_watervolumeingallons1 = will_water_volume_1 if well_serial_num== "241171"
replace RA_watervolumeingallons1 = will_water_volume_1 if well_serial_num== "241223"
replace RA_watervolumeingallons1 = will_water_volume_1 if well_serial_num== "241248"
replace RA_watervolumeingallons1 = will_water_volume_1 if well_serial_num== "241255"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "241269"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "241285"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "241359"
replace RA_watervolumeingallons1 = will_water_volume_1 if well_serial_num== "241370"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "241478"
replace RA_watervolumeingallons1 = will_water_volume_1 if well_serial_num== "241492"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "241495"
replace RA_watervolumeingallons1 = will_water_volume_1 if well_serial_num== "241511"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "241539"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "241610"
replace RA_watervolumeingallons1 = will_water_volume_1 if well_serial_num== "241632"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "241671"
replace RA_watervolumeingallons1 = will_water_volume_1 if well_serial_num== "241691"
replace RA_watervolumeingallons1 = will_water_volume_1 if well_serial_num== "241818"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "241909"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "242055"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "242179"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "242187"
replace RA_watervolumeingallons1 = will_water_volume_1 if well_serial_num== "242213"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "242220"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "242280"
replace RA_watervolumeingallons1 = will_water_volume_1 if well_serial_num== "242334"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "242351"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "242430"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "242433"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "242434"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "242451"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "242454"
replace RA_watervolumeingallons1 = will_water_volume_1 if well_serial_num== "242524"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "242621"
replace RA_watervolumeingallons1 = will_water_volume_1 if well_serial_num== "242670"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "242774"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "242797"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "242822"
replace RA_watervolumeingallons1 = will_water_volume_1 if well_serial_num== "242854"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "242877"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "242923"
replace RA_watervolumeingallons1 = will_water_volume_1 if well_serial_num== "242961"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "243040"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "243150"
replace RA_watervolumeingallons1 = will_water_volume_1 if well_serial_num== "243255"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "243271"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "243303"
replace will_water_volume_1=2457966 if well_serial_num== "243497"
replace RA_watervolumeingallons1=2457966 if well_serial_num== "243497"
replace RA_watervolumeingallons1 = will_water_volume_1 if well_serial_num== "243502"
replace RA_watervolumeingallons1 = will_water_volume_1 if well_serial_num== "243570"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "243626"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "243639"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "243657"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "243707"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "243731"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "243740"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "243828"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "243839"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "243910"
replace RA_watervolumeingallons1 = will_water_volume_1 if well_serial_num== "244214"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "244350"
replace RA_watervolumeingallons1 = will_water_volume_1 if well_serial_num== "244554"
replace RA_watervolumeingallons1 = will_water_volume_1 if well_serial_num== "244901"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "245693"
replace RA_watervolumeingallons1 = will_water_volume_1 if well_serial_num== "245727"
replace RA_watervolumeingallons1 = will_water_volume_1 if well_serial_num== "245728"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "245977"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "246413"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "246778"
replace RA_watervolumeingallons1 = will_water_volume_1 if well_serial_num== "246779"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "246977"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "247117"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "247127"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "247187"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "247404"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "247610"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "248128"
replace RA_watervolumeingallons1 = will_water_volume_1 if well_serial_num== "248248"
replace RA_watervolumeingallons1 = will_water_volume_1 if well_serial_num== "248795"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "248901"
replace RA_watervolumeingallons1 = will_water_volume_1 if well_serial_num== "248914"
replace RA_watervolumeingallons1 = will_water_volume_1 if well_serial_num== "248915"
replace will_water_volume_1 = RA_watervolumeingallons1 if well_serial_num== "248926"

/************** Fix discrepancies resulting from the following code block *************
	gen flag_water_volume_2 = 0
	replace flag_water_volume_2 = 1 if will_water_volume_2 !=RA_watervolumeingallons2
	drop if flag_water_volume_2 == 0
	order well_serial_num will_water_volume_2 RA_watervolumeingallons2
**************************************************************************************/

replace will_water_volume_2 = RA_watervolumeingallons2 if well_serial_num== "237156"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "237195"
replace will_water_volume_2 = RA_watervolumeingallons2 if well_serial_num== "237359"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "237461"
replace will_water_volume_2 = RA_watervolumeingallons2 if well_serial_num== "237524"
replace will_water_volume_2 = RA_watervolumeingallons2 if well_serial_num== "237677"
replace will_water_volume_2 = RA_watervolumeingallons2 if well_serial_num== "237838"
replace will_water_volume_2 = RA_watervolumeingallons2 if well_serial_num== "237942"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "238131"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "238281"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "238372"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "238427"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "238445"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "238485"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "238490"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "238493"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "238585"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "238618"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "238640"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "238660"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "238702"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "238708"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "238771"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "238819"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "238820"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "238852"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "238878"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "238883"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "238891"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "238892"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "238911"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "238962"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "238967"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "239022"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "239038"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "239044"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "239046"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "239051"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "239052"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "239055"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "239056"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "239089"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "239106"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "239169"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "239226"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "239226"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "239233"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "239250"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "239311"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "239312"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "239351"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "239358"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "239359"
replace will_water_volume_2 = RA_watervolumeingallons2 if well_serial_num== "239433"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "239454"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "239467"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "239471"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "239477"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "239486"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "239490"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "239504"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "239516"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "239536"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "239547"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "239553"
replace will_water_volume_2 = RA_watervolumeingallons2 if well_serial_num== "239574"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "239580"
replace will_water_volume_2 = RA_watervolumeingallons2 if well_serial_num== "239589"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "239624"
replace will_water_volume_2 = RA_watervolumeingallons2 if well_serial_num== "239685"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "239767"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "239770"
replace will_water_volume_2=8013054 if well_serial_num== "239786"
replace RA_watervolumeingallons2=8013054 if well_serial_num== "239786"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "239817"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "239965"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "239977"
replace will_water_volume_2 = RA_watervolumeingallons2 if well_serial_num== "240122"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "240247"
replace will_water_volume_2 = RA_watervolumeingallons2 if well_serial_num== "240324"
replace will_water_volume_2 = RA_watervolumeingallons2 if well_serial_num== "240345"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "240369"
replace will_water_volume_2 = RA_watervolumeingallons2 if well_serial_num== "240432"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "240440"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "240551"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "240552"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "240586"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "240600"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "240613"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "240708"
replace will_water_volume_2 = RA_watervolumeingallons2 if well_serial_num== "240724"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "240844"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "240898"

// there is missing information for well 240913, so I am edditing the stimulation volume and number of stages to = "."
replace will_water_volume_2 = RA_watervolumeingallons2 if well_serial_num== "240913"
replace will_number_of_stages_2=. if well_serial_num== "240913"

replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "240959"

// I am adding a completion for this well to my data, because I missed the second PDF for this well
replace will_water_volume_3=4521678 if well_serial_num== "240962"
replace will_number_of_stages_3=10 if well_serial_num== "240962"
replace has_sand_info_3 = has_sand_info_1 if well_serial_num== "240962"
replace will_data_type_3 = will_data_type_1 if well_serial_num== "240962"
replace patterson_completion_date_3 = RA_comp_date2 if well_serial_num== "240962"

replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "240962"
replace will_water_volume_2 = RA_watervolumeingallons2 if well_serial_num== "240973"
replace will_water_volume_2 = RA_watervolumeingallons2 if well_serial_num== "240989"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "241000"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "241046"
replace will_water_volume_2 = RA_watervolumeingallons2 if well_serial_num== "241072"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "241139"
replace will_water_volume_2 = RA_watervolumeingallons2 if well_serial_num== "241174"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "241205"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "241224"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "241285"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "241286"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "241288"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "241310"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "241318"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "241351"
replace will_water_volume_2 = RA_watervolumeingallons2 if well_serial_num== "241478"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "241494"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "241495"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "241496"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "241500"
replace will_water_volume_2 = RA_watervolumeingallons2 if well_serial_num== "241505"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "241525"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "241600"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "241624"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "241649"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "241663"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "241669"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "241670"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "241671"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "241672"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "241673"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "241674"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "241686"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "241687"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "241688"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "241689"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "241690"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "241691"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "241692"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "241700"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "241737"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "241817"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "241818"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "241823"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "241831"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "241843"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "241852"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "241853"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "241854"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "241903"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "242006"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "242037"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "242052"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "242150"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "242157"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "242207"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "242213"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "242218"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "242322"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "242350"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "242351"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "242390"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "242393"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "242395"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "242422"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "242423"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "242433"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "242443"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "242619"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "242670"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "242676"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "242690"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "242692"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "242767"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "242772"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "242773"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "242774"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "242797"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "242848"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "242849"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "242888"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "242895"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "242895"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "242937"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "242986"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "242987"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "242988"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "243092"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "243134"
replace will_water_volume_2 = RA_watervolumeingallons2 if well_serial_num== "243150"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "243197"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "243260"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "243392"
replace will_water_volume_2 = RA_watervolumeingallons2 if well_serial_num== "243657"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "243722"
replace will_water_volume_2 = RA_watervolumeingallons2 if well_serial_num== "243943"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "244276"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "244338"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "245688"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "245858"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "245867"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "245902"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "245927"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "245959"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "245960"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "247074"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "247605"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "247964"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "247965"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "248114"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "248115"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "248248"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "248249"
replace will_water_volume_2 = RA_watervolumeingallons2 if well_serial_num== "248901"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "248921"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "242901"
replace RA_watervolumeingallons2 = will_water_volume_2 if well_serial_num== "239228"

/*
gen flag_water_volume_3 = 0
replace flag_water_volume_3 = 1 if will_water_volume_3 !=RA_watervolumeingallons3
drop if flag_water_volume_3 == 0
order well_serial_num will_water_volume_3 RA_watervolumeingallons3
*/

replace RA_watervolumeingallons3 = will_water_volume_3 if well_serial_num== "235535"
replace will_water_volume_3 = RA_watervolumeingallons3 if well_serial_num== "236902"
replace will_water_volume_3 = RA_watervolumeingallons3 if well_serial_num== "237156"
replace will_water_volume_3=1886472 if well_serial_num== "237258"
replace RA_watervolumeingallons3=1886472 if well_serial_num== "237258"

// I need to remove an extra stage I created in my data for well 237643 by replacing it will the data from 3rd completion with the data from the 4th, and the date from the 4th with the data from the 5th, and then dropping the data from the 5th completion
replace will_water_volume_3 = will_water_volume_4 if well_serial_num== "237643"
replace has_sand_info_3 = has_sand_info_4 if well_serial_num== "237643"
replace will_data_type_3 = will_data_type_4 if well_serial_num== "237643"
replace will_number_of_stages_3 = will_number_of_stages_4 if well_serial_num== "237643"
replace patterson_completion_date_3 = patterson_completion_date_4 if well_serial_num== "237643"
replace will_water_volume_4 = will_water_volume_5 if well_serial_num== "237643"
replace has_sand_info_4 = has_sand_info_5 if well_serial_num== "237643"
replace will_data_type_4 = will_data_type_5 if well_serial_num== "237643"
replace will_number_of_stages_4 = will_number_of_stages_5 if well_serial_num== "237643"
replace patterson_completion_date_4 = patterson_completion_date_5 if well_serial_num== "237643"
replace will_water_volume_5 =. if well_serial_num== "237643"
replace has_sand_info_5 =. if well_serial_num== "237643"
replace will_data_type_5 =. if well_serial_num== "237643"
replace will_number_of_stages_5 =. if well_serial_num== "237643"
replace patterson_completion_date_5 =. if well_serial_num== "237643"

replace RA_watervolumeingallons3 = will_water_volume_3 if well_serial_num== "237643"
replace will_water_volume_3 = RA_watervolumeingallons3 if well_serial_num== "237669"
replace will_water_volume_3 = RA_watervolumeingallons3 if well_serial_num== "237838"
replace RA_watervolumeingallons3 = will_water_volume_3 if well_serial_num== "238481"
replace RA_watervolumeingallons3 = will_water_volume_3 if well_serial_num== "239642"
replace RA_watervolumeingallons3 = will_water_volume_3 if well_serial_num== "239708"
replace RA_watervolumeingallons3 = will_water_volume_3 if well_serial_num== "239770"
replace will_water_volume_3=1990880 if well_serial_num== "239817"
replace RA_watervolumeingallons3=1990880 if well_serial_num== "239817"
replace RA_watervolumeingallons3 = will_water_volume_3 if well_serial_num== "239829"
replace RA_watervolumeingallons3 = will_water_volume_3 if well_serial_num== "239879"
replace RA_watervolumeingallons3 = will_water_volume_3 if well_serial_num== "239965"
replace will_water_volume_3=2245908 if well_serial_num== "240247"
replace RA_watervolumeingallons3=2245908 if well_serial_num== "240247"
replace RA_watervolumeingallons3 = will_water_volume_3 if well_serial_num== "240330"
replace RA_watervolumeingallons3 = will_water_volume_3 if well_serial_num== "240369"
replace RA_watervolumeingallons3 = will_water_volume_3 if well_serial_num== "240440"
replace RA_watervolumeingallons3 = will_water_volume_3 if well_serial_num== "240551"
replace RA_watervolumeingallons3 = will_water_volume_3 if well_serial_num== "240552"
replace RA_watervolumeingallons3 = will_water_volume_3 if well_serial_num== "240586"
replace RA_watervolumeingallons3 = will_water_volume_3 if well_serial_num== "240600"
replace RA_watervolumeingallons3 = will_water_volume_3 if well_serial_num== "240613"
replace RA_watervolumeingallons3 = will_water_volume_3 if well_serial_num== "240618"
replace RA_watervolumeingallons3 = will_water_volume_3 if well_serial_num== "240708"
replace RA_watervolumeingallons3 = will_water_volume_3 if well_serial_num== "240730"
replace RA_watervolumeingallons3 = will_water_volume_3 if well_serial_num== "240844"
replace RA_watervolumeingallons3 = will_water_volume_3 if well_serial_num== "240898"
replace RA_watervolumeingallons3 = will_water_volume_3 if well_serial_num== "240962"
replace RA_watervolumeingallons3 = will_water_volume_3 if well_serial_num== "241049"
replace RA_watervolumeingallons3 = will_water_volume_3 if well_serial_num== "241139"
replace RA_watervolumeingallons3 = will_water_volume_3 if well_serial_num== "241205"
replace RA_watervolumeingallons3 = will_water_volume_3 if well_serial_num== "242157"
replace RA_watervolumeingallons3 = will_water_volume_3 if well_serial_num== "243401"
replace RA_watervolumeingallons3 = will_water_volume_3 if well_serial_num== "243570"

/*
gen flag_water_volume_4 = 0
replace flag_water_volume_4 = 1 if will_water_volume_4 !=RA_watervolumeingallons4
drop if flag_water_volume_4 == 0
order well_serial_num will_water_volume_4 RA_watervolumeingallons4
*/

replace RA_watervolumeingallons4 = will_water_volume_4 if well_serial_num== "235535"
replace will_water_volume_4 = RA_watervolumeingallons4 if well_serial_num== "236902"
replace will_water_volume_4 = RA_watervolumeingallons4 if well_serial_num== "236989"
replace RA_watervolumeingallons4 = will_water_volume_4 if well_serial_num== "237643"

// for well 239642, I am correcting the stimulation volume for the 3rd completion
replace RA_watervolumeingallons3 =0 if well_serial_num== "239642"
replace will_water_volume_3 =0 if well_serial_num== "239642"
replace RA_watervolumeingallons4 =. if well_serial_num== "239642"
replace RA_watervolumeingallons4 = will_water_volume_4 if well_serial_num== "239817"
replace RA_watervolumeingallons4 = will_water_volume_4 if well_serial_num== "240600"
replace RA_watervolumeingallons4 = will_water_volume_4 if well_serial_num== "240730"

/*
gen flag_water_volume_5 = 0
replace flag_water_volume_5 = 1 if will_water_volume_5 !=RA_watervolumeingallons5
drop if flag_water_volume_5 == 0
order well_serial_num will_water_volume_5 RA_watervolumeingallons5
*/

replace RA_watervolumeingallons5 = will_water_volume_5 if well_serial_num== "237643"

/*
gen flag_number_of_stages_1 = 0
replace flag_number_of_stages_1 = 1 if will_number_of_stages_1 !=RA_numberofstages1
drop if flag_number_of_stages_1 == 0
order well_serial_num will_number_of_stages_1 RA_numberofstages1
*/

replace will_number_of_stages_1 = RA_numberofstages1 if well_serial_num== "197702"
replace will_number_of_stages_1 = RA_numberofstages1 if well_serial_num== "231883"
replace will_number_of_stages_1 = RA_numberofstages1 if well_serial_num== "231996"
replace will_number_of_stages_1 = RA_numberofstages1 if well_serial_num== "234017"
replace RA_numberofstages1 = will_number_of_stages_1 if well_serial_num== "235057"
replace will_number_of_stages_1 = RA_numberofstages1 if well_serial_num== "235535"
replace RA_numberofstages1 =1 if well_serial_num== "235554"
replace will_number_of_stages_1 =1 if well_serial_num== "235554"
replace RA_numberofstages1 =1 if well_serial_num== "236727"
replace will_number_of_stages_1 =1 if well_serial_num== "236727"
replace will_number_of_stages_1 = RA_numberofstages1 if well_serial_num== "236831"
replace will_number_of_stages_1 = RA_numberofstages1 if well_serial_num== "236989"
// correcting stimulation volume mistake for well 237465
replace RA_watervolumeingallons1=0 if well_serial_num== "236989"
replace will_water_volume_1=0 if well_serial_num== "236989"
replace will_number_of_stages_1 = RA_numberofstages1 if well_serial_num== "237465"
replace RA_numberofstages1 = will_number_of_stages_1 if well_serial_num== "237643"
// correcting stimulation volume mistake for well 237643
replace RA_watervolumeingallons1=0 if well_serial_num== "237643"
replace will_water_volume_1=0 if well_serial_num== "237643"
replace RA_numberofstages1 = will_number_of_stages_1 if well_serial_num== "237717"
replace RA_numberofstages1 = will_number_of_stages_1 if well_serial_num== "237727"
replace will_number_of_stages_1 = RA_numberofstages1 if well_serial_num== "237949"
replace will_number_of_stages_1 = RA_numberofstages1 if well_serial_num== "238250"
replace will_number_of_stages_1 = RA_numberofstages1 if well_serial_num== "238300"
replace will_number_of_stages_1 = RA_numberofstages1 if well_serial_num== "238301"
replace will_number_of_stages_1 = RA_numberofstages1 if well_serial_num== "238403"
replace will_number_of_stages_1 = RA_numberofstages1 if well_serial_num== "238492"
replace RA_numberofstages1 = will_number_of_stages_1 if well_serial_num== "238660"
replace will_number_of_stages_1 = RA_numberofstages1 if well_serial_num== "238773"
replace RA_numberofstages1 = will_number_of_stages_1 if well_serial_num== "238852"
replace RA_numberofstages1 = will_number_of_stages_1 if well_serial_num== "238959"
replace will_number_of_stages_1 = RA_numberofstages1 if well_serial_num== "238961"
replace will_number_of_stages_1 = RA_numberofstages1 if well_serial_num== "238986"
replace will_number_of_stages_1 = RA_numberofstages1 if well_serial_num== "239046"
replace will_number_of_stages_1 = RA_numberofstages1 if well_serial_num== "239055"
replace will_number_of_stages_1 = RA_numberofstages1 if well_serial_num== "239292"
replace RA_numberofstages1 = will_number_of_stages_1 if well_serial_num== "239320"
replace will_number_of_stages_1 = RA_numberofstages1 if well_serial_num== "239351"
replace RA_numberofstages1 = will_number_of_stages_1 if well_serial_num== "239360"
replace will_number_of_stages_1 = RA_numberofstages1 if well_serial_num== "239385"
replace will_number_of_stages_1 = RA_numberofstages1 if well_serial_num== "239442"
replace RA_numberofstages1 = will_number_of_stages_1 if well_serial_num== "239459"
replace RA_numberofstages1 = will_number_of_stages_1 if well_serial_num== "239496"
replace will_number_of_stages_1 = RA_numberofstages1 if well_serial_num== "239506"
replace will_number_of_stages_1 = RA_numberofstages1 if well_serial_num== "239521"
replace will_number_of_stages_1 = RA_numberofstages1 if well_serial_num== "239535"
replace will_number_of_stages_1 = RA_numberofstages1 if well_serial_num== "239539"
replace RA_numberofstages1 = will_number_of_stages_1 if well_serial_num== "239547"
replace will_number_of_stages_1 = RA_numberofstages1 if well_serial_num== "239579"
replace will_number_of_stages_1 = RA_numberofstages1 if well_serial_num== "239589"
replace will_number_of_stages_1 = RA_numberofstages1 if well_serial_num== "239598"
replace will_number_of_stages_1 = RA_numberofstages1 if well_serial_num== "239599"
replace will_number_of_stages_1 = RA_numberofstages1 if well_serial_num== "239675"
replace RA_numberofstages1 = will_number_of_stages_1 if well_serial_num== "239679"
replace will_number_of_stages_1 = RA_numberofstages1 if well_serial_num== "239691"
replace RA_numberofstages1 = will_number_of_stages_1 if well_serial_num== "239764"
replace RA_numberofstages1 = will_number_of_stages_1 if well_serial_num== "239804"
replace will_number_of_stages_1 = RA_numberofstages1 if well_serial_num== "239840"
replace will_number_of_stages_1 = RA_numberofstages1 if well_serial_num== "239852"
replace will_number_of_stages_1 = RA_numberofstages1 if well_serial_num== "239925"
replace will_number_of_stages_1 = RA_numberofstages1 if well_serial_num== "239942"
replace will_number_of_stages_1 = RA_numberofstages1 if well_serial_num== "240049"
replace will_number_of_stages_1 = RA_numberofstages1 if well_serial_num== "240050"
replace will_number_of_stages_1 = RA_numberofstages1 if well_serial_num== "240054"
replace will_number_of_stages_1 = RA_numberofstages1 if well_serial_num== "240066"
replace will_number_of_stages_1 = RA_numberofstages1 if well_serial_num== "240120"
replace will_number_of_stages_1 = RA_numberofstages1 if well_serial_num== "240150"
replace will_number_of_stages_1 = RA_numberofstages1 if well_serial_num== "240170"
replace RA_numberofstages1 = will_number_of_stages_1 if well_serial_num== "240195"
replace will_number_of_stages_1 = RA_numberofstages1 if well_serial_num== "240196"
replace RA_numberofstages1 = will_number_of_stages_1 if well_serial_num== "240207"
replace RA_numberofstages1 = will_number_of_stages_1 if well_serial_num== "240231"
replace will_number_of_stages_1 = RA_numberofstages1 if well_serial_num== "240246"
replace RA_numberofstages1 = will_number_of_stages_1 if well_serial_num== "240254"
replace will_number_of_stages_1 = RA_numberofstages1 if well_serial_num== "240324"
replace RA_numberofstages1 = will_number_of_stages_1 if well_serial_num== "240347"
replace will_number_of_stages_1 = RA_numberofstages1 if well_serial_num== "240348"
replace will_number_of_stages_1 = RA_numberofstages1 if well_serial_num== "240388"
replace will_number_of_stages_1 = RA_numberofstages1 if well_serial_num== "240455"
replace will_number_of_stages_1 = RA_numberofstages1 if well_serial_num== "240466"
replace will_number_of_stages_1 = RA_numberofstages1 if well_serial_num== "240547"
replace will_number_of_stages_1 = RA_numberofstages1 if well_serial_num== "240789"
replace will_number_of_stages_1 = RA_numberofstages1 if well_serial_num== "240905"
replace will_number_of_stages_1 = RA_numberofstages1 if well_serial_num== "240913"
replace will_number_of_stages_1 = RA_numberofstages1 if well_serial_num== "240989"
replace will_number_of_stages_1 = RA_numberofstages1 if well_serial_num== "241192"
replace RA_numberofstages1 = will_number_of_stages_1 if well_serial_num== "241223"
replace RA_numberofstages1 = will_number_of_stages_1 if well_serial_num== "241632"
replace RA_numberofstages1 = will_number_of_stages_1 if well_serial_num== "242047"
replace RA_numberofstages1 = will_number_of_stages_1 if well_serial_num== "242169"
replace RA_numberofstages1 = will_number_of_stages_1 if well_serial_num== "242516"
replace RA_numberofstages1 = will_number_of_stages_1 if well_serial_num== "242680"
replace RA_numberofstages1 = will_number_of_stages_1 if well_serial_num== "243503"
replace will_number_of_stages_1 = RA_numberofstages1 if well_serial_num== "243639"
replace will_number_of_stages_1 = RA_numberofstages1 if well_serial_num== "243657"
replace RA_numberofstages1 = will_number_of_stages_1 if well_serial_num== "247117"
replace will_number_of_stages_1 = RA_numberofstages1 if well_serial_num== "247227"
replace will_number_of_stages_1 = RA_numberofstages1 if well_serial_num== "248248"
replace will_number_of_stages_1 = RA_numberofstages1 if well_serial_num== "248466"
replace will_number_of_stages_1 = RA_numberofstages1 if well_serial_num== "248954"

/*
gen flag_number_of_stages_2 = 0
replace flag_number_of_stages_2 = 1 if will_number_of_stages_2 !=RA_numberofstages2
drop if flag_number_of_stages_2 == 0
order well_serial_num will_number_of_stages_2 RA_numberofstages2 will_number_of_stages_3
*/

replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "235535"
replace will_number_of_stages_2 = RA_numberofstages2 if well_serial_num== "237156"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "237359"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "237524"
replace will_number_of_stages_2 = RA_numberofstages2 if well_serial_num== "237838"
replace will_number_of_stages_3 = RA_numberofstages3 if well_serial_num== "237838"
replace will_number_of_stages_2 = RA_numberofstages2 if well_serial_num== "237942"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "238131"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "238281"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "238372"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "238427"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "238445"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "238485"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "238490"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "238493"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "238585"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "238618"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "238640"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "238660"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "238702"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "238708"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "238771"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "238819"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "238820"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "238878"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "238883"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "238891"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "238892"
replace will_number_of_stages_2 = RA_numberofstages2 if well_serial_num== "238911"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "238962"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "238967"
replace will_number_of_stages_2 = RA_numberofstages2 if well_serial_num== "238986"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "239022"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "239038"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "239044"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "239046"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "239051"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "239052"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "239055"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "239056"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "239089"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "239106"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "239169"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "239226"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "239228"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "239233"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "239250"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "239311"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "239312"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "239351"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "239358"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "239359"
replace will_number_of_stages_2 = RA_numberofstages2 if well_serial_num== "239433"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "239454"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "239467"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "239471"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "239477"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "239486"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "239490"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "239504"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "239516"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "239536"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "239547"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "239553"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "239580"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "239589"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "239624"
replace will_number_of_stages_2 = RA_numberofstages2 if well_serial_num== "239685"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "239767"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "239770"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "239817"
replace RA_numberofstages3 = will_number_of_stages_3 if well_serial_num== "239817"
replace will_number_of_stages_3 = RA_numberofstages2 if well_serial_num== "239965"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "239965"
replace will_number_of_stages_2 = RA_numberofstages2 if well_serial_num== "240122"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "240247"
replace will_number_of_stages_2 = RA_numberofstages2 if well_serial_num== "240324"
replace will_number_of_stages_2 = RA_numberofstages2 if well_serial_num== "240345"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "240440"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "240551"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "240552"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "240586"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "240600"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "240613"
replace will_number_of_stages_3 = RA_numberofstages2 if well_serial_num== "240708"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "240708"
replace will_number_of_stages_2 = RA_numberofstages2 if well_serial_num== "240724"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "240844"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "240898"
replace RA_numberofstages2 =15 if well_serial_num== "240906"
replace will_number_of_stages_2 =15 if well_serial_num== "240906"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "240959"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "240962"
replace will_number_of_stages_2 = RA_numberofstages2 if well_serial_num== "240973"
replace will_number_of_stages_2 = RA_numberofstages2 if well_serial_num== "240989"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "241000"
replace will_number_of_stages_2 = RA_numberofstages2 if well_serial_num== "241046"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "241139"
replace RA_numberofstages3 = will_number_of_stages_3 if well_serial_num== "241139"
replace will_number_of_stages_2 = RA_numberofstages2 if well_serial_num== "241174"
replace will_number_of_stages_2 = RA_numberofstages2 if well_serial_num== "241180"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "241205"
replace RA_numberofstages3 = will_number_of_stages_3 if well_serial_num== "241205"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "241224"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "241285"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "241286"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "241288"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "241310"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "241318"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "241328"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "241351"
replace will_number_of_stages_2 = RA_numberofstages2 if well_serial_num== "241478"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "241494"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "241495"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "241496"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "241500"
replace will_number_of_stages_2 = RA_numberofstages2 if well_serial_num== "241505"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "241525"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "241600"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "241624"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "241649"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "241663"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "241669"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "241670"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "241671"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "241672"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "241673"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "241674"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "241686"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "241687"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "241688"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "241689"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "241690"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "241691"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "241692"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "241700"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "241737"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "241817"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "241818"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "241823"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "241831"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "241843"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "241852"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "241853"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "241854"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "241903"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "242006"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "242037"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "242052"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "242150"
replace will_number_of_stages_2 = RA_numberofstages2 if well_serial_num== "242157"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "242207"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "242213"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "242218"
replace will_number_of_stages_2 = RA_numberofstages2 if well_serial_num== "242291"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "242322"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "242350"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "242351"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "242390"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "242393"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "242395"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "242422"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "242423"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "242433"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "242443"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "242619"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "242670"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "242676"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "242690"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "242692"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "242767"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "242772"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "242773"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "242774"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "242797"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "242848"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "242849"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "242888"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "242895"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "242901"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "242937"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "242986"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "242987"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "242988"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "243092"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "243134"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "243197"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "243260"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "243392"
replace will_number_of_stages_2 = RA_numberofstages2 if well_serial_num== "243657"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "243722"
replace will_number_of_stages_2 = RA_numberofstages2 if well_serial_num== "243943"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "244276"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "244338"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "245688"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "245858"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "245867"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "245902"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "245927"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "245959"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "245960"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "247074"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "247605"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "247964"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "247965"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "248114"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "248115"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "248248"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "248249"
replace will_number_of_stages_2 = RA_numberofstages2 if well_serial_num== "248901"
replace RA_numberofstages2 = will_number_of_stages_2 if well_serial_num== "248921"

/*
gen flag_number_of_stages_3 = 0
replace flag_number_of_stages_3 = 1 if will_number_of_stages_3 !=RA_numberofstages3
drop if flag_number_of_stages_3 == 0
order well_serial_num will_number_of_stages_3 RA_numberofstages3 will_number_of_stages_4
*/

replace RA_numberofstages3 = will_number_of_stages_3 if well_serial_num== "235535"
replace will_number_of_stages_3 = RA_numberofstages3 if well_serial_num== "236902"
replace will_number_of_stages_4 = RA_numberofstages4 if well_serial_num== "236902"
replace will_number_of_stages_3 = RA_numberofstages3 if well_serial_num== "236989"
replace will_number_of_stages_3 = RA_numberofstages3 if well_serial_num== "237156"
replace will_number_of_stages_3 = RA_numberofstages3 if well_serial_num== "237258"
replace RA_numberofstages3 = will_number_of_stages_3 if well_serial_num== "237643"
replace RA_numberofstages3 = will_number_of_stages_3 if well_serial_num== "237669"
replace RA_numberofstages3 = will_number_of_stages_3 if well_serial_num== "238481"
replace RA_numberofstages3 = will_number_of_stages_3 if well_serial_num== "239642"
replace RA_numberofstages3 = will_number_of_stages_3 if well_serial_num== "239708"
replace RA_numberofstages3 = will_number_of_stages_3 if well_serial_num== "239770"
replace RA_numberofstages3 = will_number_of_stages_3 if well_serial_num== "239829"
replace RA_numberofstages3 = will_number_of_stages_3 if well_serial_num== "239879"
replace RA_numberofstages3 = will_number_of_stages_3 if well_serial_num== "239965"
replace RA_numberofstages3 = will_number_of_stages_3 if well_serial_num== "240247"
replace RA_numberofstages3 = will_number_of_stages_3 if well_serial_num== "240330"
replace RA_numberofstages3 = will_number_of_stages_3 if well_serial_num== "240440"
replace RA_numberofstages3 = will_number_of_stages_3 if well_serial_num== "240551"
replace RA_numberofstages3 = will_number_of_stages_3 if well_serial_num== "240552"
replace RA_numberofstages3 = will_number_of_stages_3 if well_serial_num== "240586"
replace RA_numberofstages3 = will_number_of_stages_3 if well_serial_num== "240600"
replace RA_numberofstages4 = will_number_of_stages_4 if well_serial_num== "240600"
replace RA_numberofstages3 = will_number_of_stages_3 if well_serial_num== "240613"
replace RA_numberofstages3 = will_number_of_stages_3 if well_serial_num== "240618"
replace RA_numberofstages3 = will_number_of_stages_3 if well_serial_num== "240708"
replace RA_numberofstages3 = will_number_of_stages_3 if well_serial_num== "240730"
replace RA_numberofstages3 = will_number_of_stages_3 if well_serial_num== "240844"
replace RA_numberofstages3 = will_number_of_stages_3 if well_serial_num== "240898"
replace RA_numberofstages3 = will_number_of_stages_3 if well_serial_num== "240962"
replace RA_numberofstages3 = will_number_of_stages_3 if well_serial_num== "241049"
replace RA_numberofstages3 = will_number_of_stages_3 if well_serial_num== "242157"
replace RA_numberofstages2 =0 if well_serial_num== "242157"
replace will_number_of_stages_2 =0 if well_serial_num== "242157"
replace RA_numberofstages3 = will_number_of_stages_3 if well_serial_num== "243401"
replace RA_numberofstages3 = will_number_of_stages_3 if well_serial_num== "243570"

/*
gen flag_number_of_stages_4 = 0
replace flag_number_of_stages_4 = 1 if will_number_of_stages_4 !=RA_numberofstages4
drop if flag_number_of_stages_4 == 0
order well_serial_num will_number_of_stages_4 RA_numberofstages4 will_number_of_stages_5
*/

replace RA_numberofstages4 = will_number_of_stages_4 if well_serial_num== "235535"
replace will_number_of_stages_4 = RA_numberofstages4 if well_serial_num== "236989"
replace RA_numberofstages4 = will_number_of_stages_4 if well_serial_num== "237643"
replace RA_numberofstages4 = will_number_of_stages_4 if well_serial_num== "239046"
replace RA_numberofstages4 = will_number_of_stages_4 if well_serial_num== "239642"
replace will_water_volume_3=. if well_serial_num== "239642"
replace RA_watervolumeingallons3=. if well_serial_num== "239642"
replace RA_numberofstages4 = will_number_of_stages_4 if well_serial_num== "239817"
replace RA_numberofstages4 = will_number_of_stages_4 if well_serial_num== "239966"
replace RA_numberofstages4 = will_number_of_stages_4 if well_serial_num== "240730"

/*
gen flag_number_of_stages_5 = 0
replace flag_number_of_stages_5 = 1 if will_number_of_stages_5 !=RA_numberofstages5
drop if flag_number_of_stages_5 == 0
order well_serial_num will_number_of_stages_5 RA_numberofstages5 will_number_of_stages_4
*/

replace RA_numberofstages5 = will_number_of_stages_5 if well_serial_num== "237643"

/*
gen flag_data_type_1 = 0
replace flag_data_type_1 = 1 if will_data_type_1 !=RA_datatype1
drop if flag_data_type_1 == 0
order well_serial_num will_data_type_1 RA_datatype1
*/

replace will_data_type_1 = RA_datatype1 if well_serial_num== "197702"
replace will_data_type_1 = RA_datatype1 if well_serial_num== "236831"
replace RA_datatype1 = will_data_type_1 if well_serial_num== "237669"
replace RA_datatype1 = will_data_type_1 if well_serial_num== "238107"
replace will_data_type_1 = RA_datatype1 if well_serial_num== "238131"
replace will_data_type_1 = RA_datatype1 if well_serial_num== "239459"
replace RA_datatype1 = will_data_type_1 if well_serial_num== "239461"
replace RA_datatype1 = will_data_type_1 if well_serial_num== "239477"
replace RA_datatype1 = will_data_type_1 if well_serial_num== "239496"
replace RA_datatype1 = will_data_type_1 if well_serial_num== "239589"
replace RA_datatype1 = will_data_type_1 if well_serial_num== "239598"
replace will_data_type_1 = RA_datatype1 if well_serial_num== "239656"
replace will_data_type_1 = RA_datatype1 if well_serial_num== "239679"
replace RA_datatype1 = will_data_type_1 if well_serial_num== "239747"
replace RA_datatype1 = will_data_type_1 if well_serial_num== "239804"
replace will_data_type_1 = RA_datatype1 if well_serial_num== "239818"
replace RA_datatype1 = will_data_type_1 if well_serial_num== "239879"
replace RA_datatype1 = will_data_type_1 if well_serial_num== "239966"
replace will_data_type_1 = RA_datatype1 if well_serial_num== "240214"
replace will_data_type_1 = RA_datatype1 if well_serial_num== "240233"
replace will_data_type_1 = RA_datatype1 if well_serial_num== "240282"
replace will_data_type_1 = RA_datatype1 if well_serial_num== "240293"
replace RA_datatype1 = will_data_type_1 if well_serial_num== "240301"
replace will_data_type_1 = RA_datatype1 if well_serial_num== "240342"
replace RA_datatype1 = will_data_type_1 if well_serial_num== "240347"
replace will_data_type_1 = RA_datatype1 if well_serial_num== "240367"
replace will_data_type_1 = RA_datatype1 if well_serial_num== "240388"
replace RA_datatype1 = will_data_type_1 if well_serial_num== "240486"
replace will_data_type_1 = RA_datatype1 if well_serial_num== "240546"
replace RA_datatype1 = will_data_type_1 if well_serial_num== "240989"
replace RA_datatype1 = will_data_type_1 if well_serial_num== "240996"
replace will_data_type_1 = RA_datatype1 if well_serial_num== "241543"
replace RA_datatype1 = will_data_type_1 if well_serial_num== "241934"
replace RA_datatype1 = will_data_type_1 if well_serial_num== "242003"
replace RA_datatype1 = will_data_type_1 if well_serial_num== "242961"
replace will_data_type_1 = RA_datatype1 if well_serial_num== "243255"
replace RA_datatype1 = will_data_type_1 if well_serial_num== "243497"
replace RA_datatype1 = will_data_type_1 if well_serial_num== "243543"
replace RA_datatype1 = will_data_type_1 if well_serial_num== "243544"
replace will_data_type_1 = RA_datatype1 if well_serial_num== "243657"
replace RA_datatype1 = will_data_type_1 if well_serial_num== "243878"
replace will_data_type_1 = RA_datatype1 if well_serial_num== "244230"
replace RA_datatype1 = will_data_type_1 if well_serial_num== "244901"
replace RA_datatype1 = will_data_type_1 if well_serial_num== "245927"
replace will_data_type_1 = RA_datatype1 if well_serial_num== "246105"
replace RA_datatype1 = will_data_type_1 if well_serial_num== "246868"
replace RA_datatype1 = will_data_type_1 if well_serial_num== "248248"
replace will_data_type_1 = RA_datatype1 if well_serial_num== "248466"

/*
gen flag_data_type_2 = 0
replace flag_data_type_2 = 1 if will_data_type_2 !=RA_datatype2
drop if flag_data_type_2 == 0
order well_serial_num will_data_type_2 RA_datatype2
*/

replace RA_datatype2 = will_data_type_2 if RA_datatype2 !=will_data_type_2 & RA_datatype2==.
replace will_data_type_2 = RA_datatype2 if well_serial_num== "237942"
replace will_data_type_2 = RA_datatype2 if well_serial_num== "238911"
replace will_data_type_2 = RA_datatype2 if well_serial_num== "239685"
replace will_data_type_2 = RA_datatype2 if well_serial_num== "240345"
replace will_data_type_2 = RA_datatype2 if well_serial_num== "237838"
replace RA_datatype2 = will_data_type_2 if well_serial_num== "239770"
replace RA_datatype2 = will_data_type_2 if well_serial_num== "239817"
replace RA_datatype2 = will_data_type_2 if well_serial_num== "239965"
replace RA_datatype2 = will_data_type_2 if well_serial_num== "240247"
replace RA_datatype2 = will_data_type_2 if well_serial_num== "240440"
replace RA_datatype2 = will_data_type_2 if well_serial_num== "240551"
replace RA_datatype2 = will_data_type_2 if well_serial_num== "240552"
replace RA_datatype2 = will_data_type_2 if well_serial_num== "240586"
replace RA_datatype2 = will_data_type_2 if well_serial_num== "240600"
replace RA_datatype2 = will_data_type_2 if well_serial_num== "240708"
replace RA_datatype2 = will_data_type_2 if well_serial_num== "240724"
replace RA_datatype2 = will_data_type_2 if well_serial_num== "240844"
replace RA_datatype2 = will_data_type_2 if well_serial_num== "240898"
replace will_data_type_2 = RA_datatype2 if well_serial_num== "240906"
replace RA_datatype2 = will_data_type_2 if well_serial_num== "240962"
replace will_data_type_2 = RA_datatype2 if well_serial_num== "240973"
replace will_data_type_2 = RA_datatype2 if well_serial_num== "240989"
replace will_data_type_2 = RA_datatype2 if well_serial_num== "241046"
replace RA_datatype2 = will_data_type_2 if well_serial_num== "241139"
replace will_data_type_2 = RA_datatype2 if well_serial_num== "241174"
replace RA_datatype2 = will_data_type_2 if well_serial_num== "241205"
replace will_data_type_2 = RA_datatype2 if well_serial_num== "241478"
replace will_data_type_2 = RA_datatype2 if well_serial_num== "241505"
replace RA_datatype2 = will_data_type_2 if well_serial_num== "242157"
replace RA_datatype2 = will_data_type_2 if well_serial_num== "242663"
replace will_data_type_2 = RA_datatype2 if well_serial_num== "242774"
replace will_data_type_2 = RA_datatype2 if well_serial_num== "243943"
replace will_data_type_2 = RA_datatype2 if well_serial_num== "248901"

/*
gen flag_data_type_3 = 0
replace flag_data_type_3 = 1 if will_data_type_3 !=RA_datatype3
drop if flag_data_type_3 == 0
order well_serial_num will_data_type_3 RA_datatype3 will_water_volume_3
*/

replace will_data_type_3 = RA_datatype3 if well_serial_num== "236902"
replace RA_datatype3 = will_data_type_3 if well_serial_num== "237643"
replace RA_datatype3 = will_data_type_3 if well_serial_num== "237774"
replace will_data_type_3 = RA_datatype3 if well_serial_num== "237838"
replace will_data_type_3 = RA_datatype3 if well_serial_num== "238018"
replace RA_datatype3 = will_data_type_3 if well_serial_num== "238481"
replace RA_datatype3 = will_data_type_3 if well_serial_num== "238481"
replace RA_datatype3 = will_data_type_3 if well_serial_num== "239642"
replace RA_datatype3 = will_data_type_3 if well_serial_num== "239708"
replace RA_datatype3 = will_data_type_3 if well_serial_num== "239770"
replace RA_datatype3 = will_data_type_3 if well_serial_num== "239817"
replace RA_datatype3 = will_data_type_3 if well_serial_num== "239829"
replace RA_datatype3 = will_data_type_3 if well_serial_num== "239879"
replace RA_datatype3 = will_data_type_3 if well_serial_num== "239965"
replace RA_datatype3 = will_data_type_3 if well_serial_num== "240247"
replace RA_datatype3 = will_data_type_3 if well_serial_num== "240330"
replace RA_datatype3 = will_data_type_3 if well_serial_num== "240369"
replace RA_datatype3 = will_data_type_3 if well_serial_num== "240440"
replace RA_datatype3 = will_data_type_3 if well_serial_num== "240551"
replace RA_datatype3 = will_data_type_3 if well_serial_num== "240552"
replace RA_datatype3 = will_data_type_3 if well_serial_num== "240586"
replace RA_datatype3 = will_data_type_3 if well_serial_num== "240600"
replace RA_datatype3 = will_data_type_3 if well_serial_num== "240613"
replace RA_datatype3 = will_data_type_3 if well_serial_num== "240618"
replace RA_datatype3 = will_data_type_3 if well_serial_num== "240708"
replace RA_datatype3 = will_data_type_3 if well_serial_num== "240730"
replace RA_datatype3 = will_data_type_3 if well_serial_num== "240844"
replace RA_datatype3 = will_data_type_3 if well_serial_num== "240898"
replace RA_datatype3 = will_data_type_3 if well_serial_num== "240962"
replace RA_datatype3 = will_data_type_3 if well_serial_num== "241049"
replace RA_datatype3 = will_data_type_3 if well_serial_num== "241139"
replace RA_datatype3 = will_data_type_3 if well_serial_num== "241205"
replace RA_datatype3 = will_data_type_3 if well_serial_num== "242157"
replace RA_datatype3 = will_data_type_3 if well_serial_num== "243401"

/*
gen flag_data_type_4 = 0
replace flag_data_type_4 = 1 if will_data_type_4 !=RA_datatype4
drop if flag_data_type_4 == 0
order well_serial_num will_data_type_4 RA_datatype4 will_water_volume_4
*/

replace will_data_type_4 = RA_datatype4 if well_serial_num== "236902"
replace will_data_type_4 = RA_datatype4 if well_serial_num== "236989"
replace RA_datatype4 = will_data_type_4 if well_serial_num== "237643"
replace RA_datatype4 = will_data_type_4 if well_serial_num== "239046"
replace will_data_type_4 = RA_datatype4 if well_serial_num== "239642"
replace RA_datatype4 = will_data_type_4 if well_serial_num== "239817"
replace RA_datatype4 = will_data_type_4 if well_serial_num== "240600"
replace RA_datatype4 = will_data_type_4 if well_serial_num== "240730"
replace RA_datatype4 = will_data_type_4 if well_serial_num== "235535"
replace RA_datatype4 = will_data_type_4 if well_serial_num== "239642"

/*
gen flag_data_type_5 = 0
replace flag_data_type_5 = 1 if will_data_type_5 !=RA_datatype5
drop if flag_data_type_5 == 0
order well_serial_num will_data_type_5 RA_datatype5 will_water_volume_5
*/

replace RA_datatype5 = will_data_type_5 if well_serial_num== "237643"

/*
gen flag_has_sand_info_1 = 0
replace flag_has_sand_info_1 = 1 if has_sand_info_1 !=RA_hassandinfo1
drop if flag_has_sand_info_1 == 0
order well_serial_num has_sand_info_1 RA_hassandinfo1
*/

replace has_sand_info_1 = RA_hassandinfo1 if well_serial_num== "225067"
replace RA_hassandinfo1 = has_sand_info_1 if well_serial_num== "235919"
replace has_sand_info_1 = RA_hassandinfo1 if well_serial_num== "236831"
replace has_sand_info_1 = RA_hassandinfo1 if well_serial_num== "237255"
replace has_sand_info_1 = RA_hassandinfo1 if well_serial_num== "239026"
replace has_sand_info_1 = RA_hassandinfo1 if well_serial_num== "239055"
replace RA_hassandinfo1 = has_sand_info_1 if well_serial_num== "239161"
replace RA_hassandinfo1 = has_sand_info_1 if well_serial_num== "239250"
replace has_sand_info_1 = RA_hassandinfo1 if well_serial_num== "239359"
replace RA_hassandinfo1 = has_sand_info_1 if well_serial_num== "239360"
replace RA_hassandinfo1 = has_sand_info_1 if well_serial_num== "239475"
replace RA_hassandinfo1 = has_sand_info_1 if well_serial_num== "239496"
replace RA_hassandinfo1 = has_sand_info_1 if well_serial_num== "239589"
replace RA_hassandinfo1 = has_sand_info_1 if well_serial_num== "239644"
replace has_sand_info_1 = RA_hassandinfo1 if well_serial_num== "239708"
replace RA_hassandinfo1 = has_sand_info_1 if well_serial_num== "239764"
replace RA_hassandinfo1 = has_sand_info_1 if well_serial_num== "239804"
replace has_sand_info_1 = RA_hassandinfo1 if well_serial_num== "239829"
replace RA_hassandinfo1 = has_sand_info_1 if well_serial_num== "239973"
replace has_sand_info_1 = RA_hassandinfo1 if well_serial_num== "240075"
replace RA_hassandinfo1 = has_sand_info_1 if well_serial_num== "240120"
replace has_sand_info_1 = RA_hassandinfo1 if well_serial_num== "240150"
replace RA_hassandinfo1 = has_sand_info_1 if well_serial_num== "240347"
replace RA_hassandinfo1 = has_sand_info_1 if well_serial_num== "240419"
replace has_sand_info_1 = RA_hassandinfo1 if well_serial_num== "240594"
replace has_sand_info_1 = RA_hassandinfo1 if well_serial_num== "240743"
replace RA_hassandinfo1 = has_sand_info_1 if well_serial_num== "240866"
replace has_sand_info_1 = RA_hassandinfo1 if well_serial_num== "240989"
replace RA_hassandinfo1 = has_sand_info_1 if well_serial_num== "241222"
replace has_sand_info_1 = RA_hassandinfo1 if well_serial_num== "241248"
replace has_sand_info_1 = RA_hassandinfo1 if well_serial_num== "241256"
replace has_sand_info_1 = RA_hassandinfo1 if well_serial_num== "241262"
replace has_sand_info_1 = RA_hassandinfo1 if well_serial_num== "241293"
replace has_sand_info_1 = RA_hassandinfo1 if well_serial_num== "241315"
replace has_sand_info_1 = RA_hassandinfo1 if well_serial_num== "241661"
replace RA_hassandinfo1 = has_sand_info_1 if well_serial_num== "241668"
replace has_sand_info_1 = RA_hassandinfo1 if well_serial_num== "241724"
replace has_sand_info_1 = RA_hassandinfo1 if well_serial_num== "241733"
replace has_sand_info_1 = RA_hassandinfo1 if well_serial_num== "241739"
replace RA_hassandinfo1 = has_sand_info_1 if well_serial_num== "241873"
replace has_sand_info_1 = RA_hassandinfo1 if well_serial_num== "241934"
replace has_sand_info_1 = RA_hassandinfo1 if well_serial_num== "242090"
replace RA_hassandinfo1 = has_sand_info_1 if well_serial_num== "242169"
replace RA_hassandinfo1 = has_sand_info_1 if well_serial_num== "242218"
replace has_sand_info_1 = RA_hassandinfo1 if well_serial_num== "242222"
replace has_sand_info_1 = RA_hassandinfo1 if well_serial_num== "242415"
replace has_sand_info_1 = RA_hassandinfo1 if well_serial_num== "242493"
replace has_sand_info_1 = RA_hassandinfo1 if well_serial_num== "242581"
replace has_sand_info_1 = RA_hassandinfo1 if well_serial_num== "242747"
replace has_sand_info_1 = RA_hassandinfo1 if well_serial_num== "242864"
replace RA_hassandinfo1 = has_sand_info_1 if well_serial_num== "243168"
replace RA_hassandinfo1 = has_sand_info_1 if well_serial_num== "243178"
replace has_sand_info_1 = RA_hassandinfo1 if well_serial_num== "243657"
replace has_sand_info_1 = RA_hassandinfo1 if well_serial_num== "247131"
replace has_sand_info_1 = RA_hassandinfo1 if well_serial_num== "248831"
replace has_sand_info_1 = RA_hassandinfo1 if well_serial_num== "249113"

/*
gen flag_has_sand_info_2 = 0
replace flag_has_sand_info_2 = 1 if has_sand_info_2 !=RA_hassandinfo2
drop if flag_has_sand_info_2 == 0
order well_serial_num has_sand_info_2 RA_hassandinfo2
*/

replace RA_hassandinfo2 = has_sand_info_2 if RA_hassandinfo2 !=has_sand_info_2 & RA_hassandinfo2==.
replace has_sand_info_2 = RA_hassandinfo2 if well_serial_num== "237838"
replace has_sand_info_3 = RA_hassandinfo3 if well_serial_num== "237838"
replace has_sand_info_2 = RA_hassandinfo2 if well_serial_num== "237942"
replace has_sand_info_2 = RA_hassandinfo2 if well_serial_num== "238911"
replace RA_hassandinfo2 = has_sand_info_2 if well_serial_num== "239011"
replace RA_hassandinfo2 = has_sand_info_2 if well_serial_num== "239046"
replace has_sand_info_2 = RA_hassandinfo2 if well_serial_num== "239605"
replace RA_hassandinfo2 = has_sand_info_2 if well_serial_num== "239770"
replace RA_hassandinfo2 = has_sand_info_2 if well_serial_num== "239965"
replace has_sand_info_2 = RA_hassandinfo2 if well_serial_num== "240345"
replace RA_hassandinfo2 = has_sand_info_2 if well_serial_num== "240613"
replace RA_hassandinfo2 = has_sand_info_2 if well_serial_num== "240708"
replace RA_hassandinfo3 = has_sand_info_3 if well_serial_num== "240708"
replace RA_hassandinfo2 = has_sand_info_2 if well_serial_num== "240724"
replace has_sand_info_2 = RA_hassandinfo2 if well_serial_num== "240913"
replace RA_hassandinfo2 = has_sand_info_2 if well_serial_num== "240962"
replace has_sand_info_2 = RA_hassandinfo2 if well_serial_num== "240989"
replace has_sand_info_2 = RA_hassandinfo2 if well_serial_num== "241046"
replace has_sand_info_2 = RA_hassandinfo2 if well_serial_num== "241174"
replace RA_hassandinfo2 = has_sand_info_2 if well_serial_num== "241328"
replace has_sand_info_2 = RA_hassandinfo2 if well_serial_num== "241478"
replace has_sand_info_2 = RA_hassandinfo2 if well_serial_num== "241505"
replace has_sand_info_2 = RA_hassandinfo2 if well_serial_num== "242774"
replace has_sand_info_2 = RA_hassandinfo2 if well_serial_num== "248901"

/*
gen flag_has_sand_info_3 = 0
replace flag_has_sand_info_3 = 1 if has_sand_info_3 !=RA_hassandinfo3
drop if flag_has_sand_info_3 == 0
order well_serial_num has_sand_info_3 RA_hassandinfo3
*/

replace RA_hassandinfo3 = has_sand_info_3 if RA_hassandinfo3 !=has_sand_info_3 & RA_hassandinfo3==.
replace RA_hassandinfo3 = has_sand_info_3 if well_serial_num== "236902"
replace RA_hassandinfo3 = has_sand_info_3 if well_serial_num== "239642"
replace RA_hassandinfo3 = has_sand_info_3 if well_serial_num== "239879"
replace RA_hassandinfo3 = has_sand_info_3 if well_serial_num== "240369"
replace RA_hassandinfo3 = has_sand_info_3 if well_serial_num== "240618"
replace RA_hassandinfo3 = has_sand_info_3 if well_serial_num== "240915"

/*
gen flag_has_sand_info_4 = 0
replace flag_has_sand_info_4 = 1 if has_sand_info_4 !=RA_hassandinfo4
drop if flag_has_sand_info_4 == 0
order well_serial_num has_sand_info_4 RA_hassandinfo4
*/

replace RA_hassandinfo4 = has_sand_info_4 if well_serial_num== "235535"
replace has_sand_info_4 = RA_hassandinfo4 if well_serial_num== "236902"
replace has_sand_info_4 = RA_hassandinfo4 if well_serial_num== "236989"
replace RA_hassandinfo4 = has_sand_info_4 if well_serial_num== "239046"
replace RA_hassandinfo4 = has_sand_info_4 if well_serial_num== "239642"
replace RA_hassandinfo4 = has_sand_info_4 if well_serial_num== "239817"
replace RA_hassandinfo4 = has_sand_info_4 if well_serial_num== "240600"
replace RA_hassandinfo4 = has_sand_info_4 if well_serial_num== "240730"

/*
gen flag_has_sand_info_5 = 0
replace flag_has_sand_info_5 = 1 if has_sand_info_5 !=RA_hassandinfo5
drop if flag_has_sand_info_5 == 0
order well_serial_num has_sand_info_5 RA_hassandinfo5
*/

replace RA_hassandinfo5 = has_sand_info_5 if well_serial_num== "237643"

/*
gen flag_completion_date_1 = 0
replace flag_completion_date_1 = 1 if patterson_completion_date_1 !=RA_comp_date1
drop if flag_completion_date_1 == 0
order well_serial_num patterson_completion_date_1 RA_comp_date1
*/

// reformating dates from SIF to HRF
format patterson_completion_date_1 %td
format patterson_completion_date_2 %td
format patterson_completion_date_3 %td
format patterson_completion_date_4 %td
format patterson_completion_date_5 %td

replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "235535"
replace RA_comp_date1 = date("16Aug2008","%td") if well_serial_num== "236831"
replace patterson_completion_date_1 =date("16Aug2008","%td") if well_serial_num== "236831"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "237687"
replace patterson_completion_date_1 = RA_comp_date1 if well_serial_num== "237717"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "237774"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "237838"
replace patterson_completion_date_1 = RA_comp_date1 if well_serial_num== "237949"
replace patterson_completion_date_1 = RA_comp_date1 if well_serial_num== "238533"
replace patterson_completion_date_1 = RA_comp_date1 if well_serial_num== "238770"
replace patterson_completion_date_1 = RA_comp_date1 if well_serial_num== "238852"
replace patterson_completion_date_1 = RA_comp_date1 if well_serial_num== "238986"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "239038"
replace patterson_completion_date_1 = RA_comp_date1 if well_serial_num== "239055"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "239433"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "239516"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "239521"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "239547"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "239589"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "239613"
replace RA_comp_date1 =date("18sep2009","%td") if well_serial_num== "239705"
replace patterson_completion_date_1 =date("18sep2009","%td") if well_serial_num== "239705"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "239798"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "239804"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "239925"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "239937"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "239997"
replace RA_comp_date1 =date("26mar2010","%td") if well_serial_num== "240059"
replace patterson_completion_date_1 =date("26mar2010","%td") if well_serial_num== "240059"
replace patterson_completion_date_1 = RA_comp_date1 if well_serial_num== "240092"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "240123"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "240129"
replace patterson_completion_date_1 = RA_comp_date1 if well_serial_num== "240157"
replace patterson_completion_date_1 = RA_comp_date1 if well_serial_num== "240173"
replace patterson_completion_date_1 = RA_comp_date1 if well_serial_num== "240284"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "240321"
replace patterson_completion_date_1 = RA_comp_date1 if well_serial_num== "240324"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "240347"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "240471"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "240485"
replace patterson_completion_date_1 = RA_comp_date1 if well_serial_num== "240551"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "240819"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "240893"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "240921"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "240971"
replace patterson_completion_date_1 = RA_comp_date1 if well_serial_num== "240989"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "241069"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "241075"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "241113"
replace RA_comp_date1 =date("15feb2011","%td") if well_serial_num== "241171"
replace patterson_completion_date_1 =date("15feb2011","%td") if well_serial_num== "241171"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "241271"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "241272"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "241273"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "241275"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "241324"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "241377"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "241398"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "241424"
replace patterson_completion_date_1 = RA_comp_date1 if well_serial_num== "241511"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "241632"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "241677"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "241934"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "242011"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "242025"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "242159"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "242179"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "242187"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "242238"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "242347"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "242486"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "242490"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "242572"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "242754"
replace patterson_completion_date_1 = RA_comp_date1 if well_serial_num== "242864"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "242879"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "242955"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "242958"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "242998"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "243062"
replace patterson_completion_date_1 = RA_comp_date1 if well_serial_num== "243169"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "243296"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "243499"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "243570"
replace patterson_completion_date_1 = RA_comp_date1 if well_serial_num== "243626"
replace patterson_completion_date_1 = RA_comp_date1 if well_serial_num== "243657"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "243677"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "243678"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "243944"
replace patterson_completion_date_1 = RA_comp_date1 if well_serial_num== "243966"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "244659"
replace patterson_completion_date_1 = RA_comp_date1 if well_serial_num== "244731"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "244902"
replace patterson_completion_date_1 = RA_comp_date1 if well_serial_num== "245493"
replace patterson_completion_date_1 = RA_comp_date1 if well_serial_num== "245494"
replace patterson_completion_date_1 = RA_comp_date1 if well_serial_num== "245927"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "246186"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "246189"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "246413"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "246414"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "246828"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "246829"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "246971"
replace patterson_completion_date_1 = RA_comp_date1 if well_serial_num== "247117"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "247423"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "247424"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "247493"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "247610"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "247611"
replace RA_comp_date1 = patterson_completion_date_1 if well_serial_num== "247612"
replace patterson_completion_date_1 = RA_comp_date1 if well_serial_num== "249113"
replace patterson_completion_date_1 = RA_comp_date1 if well_serial_num== "249145"
replace patterson_completion_date_1 = RA_comp_date1 if well_serial_num== "249357"

/*
gen flag_completion_date_2 = 0
replace flag_completion_date_2 = 1 if patterson_completion_date_2 !=RA_comp_date2
drop if flag_completion_date_2 == 0
order well_serial_num patterson_completion_date_2 RA_comp_date2
*/

replace RA_comp_date2 = patterson_completion_date_2 if RA_comp_date2 !=patterson_completion_date_2 & RA_comp_date2==.
replace patterson_completion_date_2 = RA_comp_date2 if well_serial_num== "225067"
replace patterson_completion_date_2 = RA_comp_date2 if well_serial_num== "231996"
replace RA_comp_date2 = patterson_completion_date_2 if well_serial_num== "235535"
replace patterson_completion_date_2 = RA_comp_date2 if well_serial_num== "236902"
replace RA_comp_date2 = patterson_completion_date_2 if well_serial_num== "236989"
replace patterson_completion_date_2 = RA_comp_date2 if well_serial_num== "237069"
replace patterson_completion_date_2 = RA_comp_date2 if well_serial_num== "237564"
replace patterson_completion_date_3 = patterson_completion_date_2 if well_serial_num== "237838"
replace patterson_completion_date_2 = RA_comp_date2 if well_serial_num== "237838"
replace patterson_completion_date_2 = RA_comp_date2 if well_serial_num== "237942"
replace patterson_completion_date_2 = RA_comp_date2 if well_serial_num== "237949"
replace patterson_completion_date_2 = RA_comp_date2 if well_serial_num== "238018"
replace RA_comp_date2 = patterson_completion_date_2 if well_serial_num== "238492"
replace patterson_completion_date_2 = RA_comp_date2 if well_serial_num== "238911"
replace patterson_completion_date_2 = RA_comp_date2 if well_serial_num== "239046"
replace patterson_completion_date_2 = RA_comp_date2 if well_serial_num== "239521"
replace patterson_completion_date_2 = RA_comp_date2 if well_serial_num== "239563"
replace RA_comp_date2 = patterson_completion_date_2 if well_serial_num== "239642"
replace patterson_completion_date_2 = RA_comp_date2 if well_serial_num== "239685"
replace RA_comp_date2 = patterson_completion_date_2 if well_serial_num== "239708"
replace RA_comp_date2 = patterson_completion_date_2 if well_serial_num== "239770"
replace RA_comp_date3 = patterson_completion_date_3 if well_serial_num== "239770"
replace RA_comp_date2 = patterson_completion_date_2 if well_serial_num== "239817"
replace RA_comp_date3 = patterson_completion_date_3 if well_serial_num== "239817"
replace patterson_completion_date_2 = RA_comp_date2 if well_serial_num== "239879"
replace RA_comp_date2 = patterson_completion_date_2 if well_serial_num== "239965"
replace RA_comp_date3 = patterson_completion_date_3 if well_serial_num== "239965"
replace patterson_completion_date_2 = RA_comp_date2 if well_serial_num== "240034"
replace RA_comp_date2 = patterson_completion_date_2 if well_serial_num== "240247"
replace RA_comp_date3 = patterson_completion_date_3 if well_serial_num== "240247"
replace patterson_completion_date_2 = RA_comp_date2 if well_serial_num== "240324"
replace patterson_completion_date_2 = RA_comp_date2 if well_serial_num== "240345"
replace patterson_completion_date_2 = RA_comp_date2 if well_serial_num== "240393"
replace patterson_completion_date_2 = RA_comp_date2 if well_serial_num== "240434"
replace RA_comp_date2 = patterson_completion_date_2 if well_serial_num== "240440"
replace RA_comp_date3 = patterson_completion_date_3 if well_serial_num== "240440"
replace RA_comp_date2 = patterson_completion_date_2 if well_serial_num== "240551"
replace RA_comp_date3 = patterson_completion_date_3 if well_serial_num== "240551"
replace RA_comp_date2 = patterson_completion_date_2 if well_serial_num== "240552"
replace RA_comp_date3 = patterson_completion_date_3 if well_serial_num== "240552"
replace patterson_completion_date_2 = RA_comp_date2 if well_serial_num== "240565"
replace RA_comp_date2 = patterson_completion_date_2 if well_serial_num== "240586"
replace RA_comp_date3 = patterson_completion_date_3 if well_serial_num== "240586"
replace RA_comp_date2 = patterson_completion_date_2 if well_serial_num== "240600"
replace RA_comp_date3 = patterson_completion_date_3 if well_serial_num== "240600"
replace RA_comp_date2 = patterson_completion_date_2 if well_serial_num== "240613"
replace RA_comp_date3 = patterson_completion_date_3 if well_serial_num== "240613"
replace RA_comp_date2 = patterson_completion_date_2 if well_serial_num== "240618"
replace patterson_completion_date_3 = RA_comp_date2 if well_serial_num== "240708"
replace RA_comp_date2 = patterson_completion_date_2 if well_serial_num== "240708"
replace patterson_completion_date_2 = RA_comp_date2 if well_serial_num== "240724"
replace RA_comp_date2 = patterson_completion_date_2 if well_serial_num== "240730"
replace patterson_completion_date_2 = RA_comp_date2 if well_serial_num== "240789"
replace RA_comp_date2 = patterson_completion_date_2 if well_serial_num== "240844"
replace RA_comp_date3 = patterson_completion_date_3 if well_serial_num== "240844"
replace RA_comp_date2 = patterson_completion_date_2 if well_serial_num== "240898"
replace RA_comp_date3 = patterson_completion_date_3 if well_serial_num== "240898"
replace RA_comp_date2 = patterson_completion_date_2 if well_serial_num== "240962"
replace RA_comp_date3 = patterson_completion_date_3 if well_serial_num== "240962"
replace patterson_completion_date_2 = RA_comp_date2 if well_serial_num== "240973"
replace patterson_completion_date_2 = RA_comp_date2 if well_serial_num== "240981"
replace patterson_completion_date_2 = RA_comp_date2 if well_serial_num== "240989"
replace patterson_completion_date_2 = RA_comp_date2 if well_serial_num== "241046"
replace patterson_completion_date_2 = RA_comp_date2 if well_serial_num== "241073"
replace patterson_completion_date_2 = RA_comp_date2 if well_serial_num== "241134"
replace RA_comp_date2 = patterson_completion_date_2 if well_serial_num== "241139"
replace RA_comp_date3 = patterson_completion_date_3 if well_serial_num== "241139"
replace patterson_completion_date_2 = RA_comp_date2 if well_serial_num== "241174"
replace RA_comp_date2 = patterson_completion_date_2 if well_serial_num== "241205"
replace RA_comp_date3 = patterson_completion_date_3 if well_serial_num== "241205"
replace patterson_completion_date_2 = RA_comp_date2 if well_serial_num== "241243"
replace patterson_completion_date_2 = RA_comp_date2 if well_serial_num== "241321"
replace patterson_completion_date_2 = RA_comp_date2 if well_serial_num== "241390"
replace patterson_completion_date_2 = RA_comp_date2 if well_serial_num== "241478"
replace patterson_completion_date_2 = RA_comp_date2 if well_serial_num== "241505"
replace patterson_completion_date_2 = RA_comp_date2 if well_serial_num== "241528"
replace patterson_completion_date_2 = RA_comp_date2 if well_serial_num== "241543"
replace RA_comp_date2 = patterson_completion_date_2 if well_serial_num== "241701"
replace patterson_completion_date_2 = RA_comp_date2 if well_serial_num== "241771"
replace RA_comp_date2 = patterson_completion_date_2 if well_serial_num== "242157"
replace RA_comp_date3 = patterson_completion_date_3 if well_serial_num== "242157"
replace patterson_completion_date_2 = RA_comp_date2 if well_serial_num== "242493"
replace RA_comp_date2 = patterson_completion_date_2 if well_serial_num== "242528"
replace RA_comp_date2 = patterson_completion_date_2 if well_serial_num== "242653"
replace RA_comp_date2 = patterson_completion_date_2 if well_serial_num== "242734"
replace patterson_completion_date_2 = RA_comp_date2 if well_serial_num== "242774"
replace RA_comp_date2 = patterson_completion_date_2 if well_serial_num== "243385"
replace patterson_completion_date_2 = RA_comp_date2 if well_serial_num== "243390"
replace RA_comp_date2 = patterson_completion_date_2 if well_serial_num== "243401"
replace RA_comp_date3 = patterson_completion_date_3 if well_serial_num== "243401"
replace patterson_completion_date_2 = RA_comp_date2 if well_serial_num== "243840"
replace RA_comp_date2 = patterson_completion_date_2 if well_serial_num== "246971"
replace patterson_completion_date_2 = RA_comp_date2 if well_serial_num== "248901"
replace patterson_completion_date_2 = RA_comp_date2 if well_serial_num== "248914"

/*
gen flag_completion_date_3 = 0
replace flag_completion_date_3 = 1 if patterson_completion_date_3 !=RA_comp_date3
drop if flag_completion_date_3 == 0
order well_serial_num patterson_completion_date_3 RA_comp_date3
*/

replace RA_comp_date3 = patterson_completion_date_3 if RA_comp_date3 !=patterson_completion_date_3 & RA_comp_date3==.
replace patterson_completion_date_3 = RA_comp_date3 if RA_comp_date3 !=patterson_completion_date_3 & patterson_completion_date_3==.
replace RA_comp_date3 = patterson_completion_date_3 if well_serial_num== "235535"
replace RA_comp_date4 = patterson_completion_date_4 if well_serial_num== "235535"
replace patterson_completion_date_3 = RA_comp_date3 if well_serial_num== "236902"
replace patterson_completion_date_4 = RA_comp_date4 if well_serial_num== "236902"
replace patterson_completion_date_3 = RA_comp_date3 if well_serial_num== "236989"
replace patterson_completion_date_4 = RA_comp_date4 if well_serial_num== "236989"
replace RA_comp_date3 = patterson_completion_date_3 if well_serial_num== "237643"
replace RA_comp_date3 = patterson_completion_date_3 if well_serial_num== "237774"
replace patterson_completion_date_3 = RA_comp_date3 if well_serial_num== "237949"
replace RA_comp_date3 = patterson_completion_date_3 if well_serial_num== "239046"
replace RA_comp_date4 = patterson_completion_date_4 if well_serial_num== "239046"
replace RA_comp_date3 = patterson_completion_date_3 if well_serial_num== "239297"
replace RA_comp_date3 = patterson_completion_date_3 if well_serial_num== "239753"
replace patterson_completion_date_3 = RA_comp_date3 if well_serial_num== "239992"
replace patterson_completion_date_3 = RA_comp_date3 if well_serial_num== "240354"
replace RA_comp_date3 = patterson_completion_date_3 if well_serial_num== "240730"
replace RA_comp_date4 = patterson_completion_date_4 if well_serial_num== "240730"
replace patterson_completion_date_3 = RA_comp_date3 if well_serial_num== "240815"
replace patterson_completion_date_3 = RA_comp_date3 if well_serial_num== "241097"
replace RA_comp_date3 = patterson_completion_date_3 if well_serial_num== "243570"
replace patterson_completion_date_3 = RA_comp_date3 if well_serial_num== "243840"

/*
gen flag_completion_date_4 = 0
replace flag_completion_date_4 = 1 if patterson_completion_date_4 !=RA_comp_date4
drop if flag_completion_date_4 == 0
order well_serial_num patterson_completion_date_4 RA_comp_date4
*/

replace patterson_completion_date_4 = RA_comp_date4 if well_serial_num== "237156"
replace RA_comp_date4 = patterson_completion_date_4 if well_serial_num== "237643"
replace patterson_completion_date_4 = RA_comp_date4 if well_serial_num== "239642"
replace will_data_type_4=. if well_serial_num== "239642"
replace RA_comp_date4 = patterson_completion_date_4 if well_serial_num== "239817"
replace RA_comp_date4 = patterson_completion_date_4 if well_serial_num== "239966"
replace RA_comp_date4 = patterson_completion_date_4 if well_serial_num== "240600"

/*
gen flag_completion_date_5 = 0
replace flag_completion_date_5 = 1 if patterson_completion_date_5 !=RA_comp_date5
drop if flag_completion_date_5 == 0
order well_serial_num patterson_completion_date_5 RA_comp_date5
*/

replace RA_comp_date5 = patterson_completion_date_5 if well_serial_num== "237643"

// renaming variables for master copy
rename will_water_volume_1 water_volume_1
rename will_water_volume_2 water_volume_2
rename will_water_volume_3 water_volume_3
rename will_water_volume_4 water_volume_4
rename will_water_volume_5 water_volume_5

rename will_number_of_stages_1 number_of_stages_1
rename will_number_of_stages_2 number_of_stages_2
rename will_number_of_stages_3 number_of_stages_3
rename will_number_of_stages_4 number_of_stages_4
rename will_number_of_stages_5 number_of_stages_5

rename will_data_type_1 data_type_1
rename will_data_type_2 data_type_2
rename will_data_type_3 data_type_3
rename will_data_type_4 data_type_4
rename will_data_type_5 data_type_5

rename patterson_completion_date_1 completion_date_1
rename patterson_completion_date_2 completion_date_2
rename patterson_completion_date_3 completion_date_3
rename patterson_completion_date_4 completion_date_4
rename patterson_completion_date_5 completion_date_5

// Dropping extra variables
drop from_RAFracInputs
drop RA_api_num
drop RA_township
drop RA_range
drop RA_section

drop RA_comp_date1
drop RA_comp_date2
drop RA_comp_date3
drop RA_comp_date4
drop RA_comp_date5

drop RA_flagged1
drop RA_flagged2
drop RA_flagged3
drop RA_flagged4
drop RA_flagged5

drop RA_watervolumeingallons1
drop RA_watervolumeingallons2
drop RA_watervolumeingallons3
drop RA_watervolumeingallons4
drop RA_watervolumeingallons5

drop RA_numberofstages1
drop RA_numberofstages2
drop RA_numberofstages3
drop RA_numberofstages4
drop RA_numberofstages5

drop RA_datatype1
drop RA_datatype2
drop RA_datatype3
drop RA_datatype4
drop RA_datatype5

drop RA_hassandinfo1
drop RA_hassandinfo2
drop RA_hassandinfo3
drop RA_hassandinfo4
drop RA_hassandinfo5

drop _merge

ren well_serial_num Well_Serial_Num
gen from_RAFracInputs = 1

save "$outdir/ra_frac_inputs_cleaned.dta", replace
