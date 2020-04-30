/*********************************************************
This file takes in both sets of hand-entered data, hand checks each
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
global rawdir = "$dbdir/RawData/orig/Louisiana/DNR/WellCosts"
global outdir = "$dbdir/RawData/data/Louisiana/DNR/WellCosts"
global codedir = "$hbpdir/code/build/Louisiana"
global logdir = "$codedir/Logfiles"

log using "$logdir/Haynesville_well_costs_merge_log.txt", replace text

/*********************************************************
IMPORT NADIA'S WELL COST DATA; MERGE WITH WELL SERIAL NUMBER LIST
AND CORRECT ANY DISCREPANCIES
*********************************************************/

import excel "$rawdir/lucas_wellcosts_data.xlsx", firstrow

// Drop empty columns
drop E
drop F
drop G
drop H

gen well_cost_lucas = real(well_cost)
drop well_cost
ren serial_num well_serial_num
ren prod_date prod_date_lucas
ren note note_lucas

tempfile temp_lucaswellcosts
save "`temp_lucaswellcosts'"

clear all

// Import and merge base list of well serial numbers for cost data
import delimited "$rawdir/welllist_for_cost_input.csv", varnames(1)
merge 1:1 well_serial_num using "`temp_lucaswellcosts'"

// Note and fix problematic serial numbers
gen flag_serial_num_problem = 0
replace flag_serial_num_problem = 1 if _merge!=3

replace prod_date_lucas = "14-Apr-10" if well_serial_num == 239590
replace well_cost_lucas = 8408671.12 if well_serial_num == 239590
replace note_lucas = "amendment" if well_serial_num == 239590
drop if well_serial_num == 239950

replace prod_date_lucas = "25-Oct-12" if well_serial_num == 244137
replace well_cost_lucas = 22104653 if well_serial_num == 244137
drop if well_serial_num == 244317

drop flag_serial_num_problem

// Serial number 245963 does not exist in welllist_for_cost_input.csv presumably because the notary hand wrote
// the wrong serial number on the file as 245693 (upon further inspection, it is actually 245963) so since it
// isn't in the csv, I'll go ahead and drop that data point

drop if well_serial_num==245963

drop _merge
drop most_recent_comp_approx

tempfile temp_lucaswellcosts2
save "`temp_lucaswellcosts2'"


/*********************************************************
IMPORT WILL'S WELL COST DATA; MERGE WITH NADIA'S DATA
FLAG AND CORRECT DATE DISCREPANCIES
*********************************************************/

clear all
import excel "$rawdir/patterson_wellcosts_data.xlsx", firstrow

gen well_cost_patterson = real(well_cost)
drop well_cost
ren prod_date prod_date_patterson
ren Note note_patterson

// Merge the two files on well serial number
merge 1:m well_serial_num using "`temp_lucaswellcosts2'"
drop _merge

// First we make sure all dates are in a consistent format by reformating the
// strings and creating date objects
gen string = subinstr(prod_date_patterson, "/","-",.)
gen date_patterson = date(subinstr(prod_date_patterson,"/","-",.), "MDY")
gen date_lucas = date(subinstr(prod_date_lucas, "-","",.), "DM20Y")
gen flag_prod_date_problem = 0

// Flag any discrepencies
replace flag_prod_date_problem = 1 if date_patterson != date_lucas
drop prod_date_patterson
drop prod_date_lucas

// Create the final date variable
gen date = date_lucas if flag_prod_date_problem==0

/*
Note: the flags are useful if when going through and handchecking we perform:

keep if flag_prod_date_problem==1

which will only keep the data entries with discrepancies between Will and Nadia's
files. Then, opening the data editor we can see all of these and easily go through
all the pdfs to hand check the discrpancies.
*/

// Now we hand check each flagged entry and write a replace command to resolve issues.
replace date = date_patterson if well_serial_num==237650
replace note_lucas = note_patterson if well_serial_num==237650
replace well_cost_lucas = well_cost_patterson if well_serial_num==237650

replace date = date_lucas if well_serial_num==238018

replace date = date_patterson if well_serial_num==239084
replace note_lucas = note_patterson if well_serial_num==239084
replace well_cost_lucas = well_cost_patterson if well_serial_num==239084

replace date = date_patterson if well_serial_num==239603
replace note_lucas = "" if well_serial_num==239603
replace well_cost_lucas = 9076521 if well_serial_num==239603
replace note_lucas = "amendment" if well_serial_num==239803
replace well_cost_lucas = 8931946.05 if well_serial_num==239803

replace date = date_patterson if well_serial_num==239609
replace note_lucas = note_patterson if well_serial_num==239609
replace well_cost_lucas = well_cost_patterson if well_serial_num==239609

replace date = date_patterson if well_serial_num==239611
replace note_lucas = note_patterson if well_serial_num==239611
replace well_cost_lucas = well_cost_patterson if well_serial_num==239611

replace date = date_lucas if well_serial_num==239791

replace date = date_lucas if well_serial_num==239792

replace date = date_patterson if well_serial_num==239798

replace date = date_patterson if well_serial_num==239918

replace date = date_lucas if well_serial_num==239920

replace date = date_patterson if well_serial_num==239925

replace date = date_patterson if well_serial_num==239945

replace date = date_lucas if well_serial_num==239973

replace date = date_patterson if well_serial_num==240254

replace date = date_lucas if well_serial_num==240301

replace date = date_patterson if well_serial_num==240637

replace date = date_patterson if well_serial_num==240706

replace date = date_lucas if well_serial_num==240724

replace date = date_patterson if well_serial_num==240743
replace note_lucas = note_patterson if well_serial_num==240743
replace well_cost_lucas = well_cost_patterson if well_serial_num==240743

replace date = date_lucas if well_serial_num==240881

replace date = date_lucas if well_serial_num==241025

replace date = date_patterson if well_serial_num==241071

replace date = date_patterson if well_serial_num==241080

replace date = date_lucas if well_serial_num==241180

replace date = date_patterson if well_serial_num==241205

replace date = date_patterson if well_serial_num==241222

replace date = date_patterson if well_serial_num==241348

replace date = date_patterson if well_serial_num==241397

replace date = date_lucas if well_serial_num==241460

replace date = date_lucas if well_serial_num==241632
replace well_cost_patterson = well_cost_lucas if well_serial_num==241632

replace date = date_lucas if well_serial_num==241657

replace date = date("2Mar11","DM20Y") if well_serial_num==241682
replace well_cost_patterson = 8719123.34 if well_serial_num==241682
replace well_cost_lucas = well_cost_patterson if well_serial_num==241682
replace note_patterson = "" if well_serial_num==241682

replace date = date_patterson if well_serial_num==241787

replace date = date_patterson if well_serial_num==242127

replace date = date_patterson if well_serial_num==242204

replace date = date_patterson if well_serial_num==242859
replace note_lucas = note_patterson if well_serial_num==242859
replace well_cost_lucas = well_cost_patterson if well_serial_num==242859

replace date = date_patterson if well_serial_num==242896

replace date = date_lucas if well_serial_num==243432

replace date = date_patterson if well_serial_num==243547
replace well_cost_lucas = well_cost_patterson if well_serial_num==243547
replace note_lucas = note_patterson if well_serial_num==243547

replace date = date_patterson if well_serial_num==243610

replace date = date_patterson if well_serial_num==244188

replace date = date_patterson if well_serial_num==244229

replace date = date_lucas if well_serial_num==244535

replace date = date_patterson if well_serial_num==244607

replace date = date_lucas if well_serial_num==244835
replace well_cost_patterson = well_cost_lucas if well_serial_num==244835

replace date = date_lucas if well_serial_num==245693

replace date = date_patterson if well_serial_num==247044

replace date = date_patterson if well_serial_num==247282

replace date = date_patterson if well_serial_num==247323

replace date = date_patterson if well_serial_num==247515

replace date = date_patterson if well_serial_num==248244

replace date = date_patterson if well_serial_num==248807

// Format the date to a more easily readable format
format date %tdnn/dd/CCYY

// The following block of code is a check to see if we indeed fixed all discrepancies
replace flag_prod_date_problem = 0
replace flag_prod_date_problem = 1 if date==. &(date_lucas!=.|date_patterson!=.)
// This should come out to 0
count if flag_prod_date_problem==1

ren date prod_date
drop date_patterson
drop date_lucas
drop flag_prod_date_problem


/*********************************************************
FLAG AND CORRECT COST  DISCREPANCIES
*********************************************************/
gen flag_costs_problem = 0
replace flag_costs_problem = 1 if well_cost_patterson!=well_cost_lucas

gen well_cost = well_cost_lucas if flag_costs_problem==0

// Replace commands after hand checking discrepancies
replace well_cost = well_cost_lucas if well_serial_num==237992

replace well_cost = well_cost_lucas if well_serial_num==238307

replace well_cost = well_cost_lucas if well_serial_num==238616

replace well_cost = well_cost_patterson if well_serial_num==238660

replace well_cost = well_cost_lucas if well_serial_num==238703

replace well_cost = well_cost_lucas if well_serial_num==238770

replace well_cost = well_cost_patterson if well_serial_num==239038

replace well_cost = well_cost_lucas if well_serial_num==239052

replace well_cost = 7736175.26 if well_serial_num==239233

replace well_cost = 12764732.23 if well_serial_num==239293

replace well_cost = well_cost_patterson if well_serial_num==239358

replace well_cost = well_cost_lucas if well_serial_num==239504

replace well_cost = well_cost_lucas if well_serial_num==239513

replace well_cost = well_cost_lucas if well_serial_num==239603

replace well_cost = well_cost_lucas if well_serial_num==239606

replace well_cost = well_cost_lucas if well_serial_num==239646

replace well_cost = well_cost_lucas if well_serial_num==239686

replace well_cost = well_cost_lucas if well_serial_num==239692

replace well_cost = well_cost_lucas if well_serial_num==239703

replace well_cost = well_cost_lucas if well_serial_num==239719

replace well_cost = well_cost_patterson if well_serial_num==239745

replace well_cost = well_cost_lucas if well_serial_num==239761

replace well_cost = well_cost_lucas if well_serial_num==239793

replace well_cost = well_cost_lucas if well_serial_num==239803

replace well_cost = well_cost_lucas if well_serial_num==239922

replace well_cost = well_cost_patterson if well_serial_num==239948

replace well_cost = well_cost_lucas if well_serial_num==239973

replace well_cost = well_cost_patterson if well_serial_num==240011

replace well_cost = well_cost_patterson if well_serial_num==240148

replace well_cost = well_cost_lucas if well_serial_num==240246

replace well_cost = well_cost_lucas if well_serial_num==240349

replace well_cost = well_cost_lucas if well_serial_num==240385

replace well_cost = well_cost_lucas if well_serial_num==240442

replace well_cost = well_cost_lucas if well_serial_num==240463

replace well_cost = well_cost_patterson if well_serial_num==240487

replace well_cost = well_cost_lucas if well_serial_num==240543

replace well_cost = well_cost_lucas if well_serial_num==240600

replace well_cost = well_cost_patterson if well_serial_num==240681

replace well_cost = well_cost_patterson if well_serial_num==240722

replace well_cost = well_cost_lucas if well_serial_num==240741

replace well_cost = well_cost_patterson if well_serial_num==240778

replace well_cost = well_cost_lucas if well_serial_num==240846

replace well_cost = well_cost_patterson if well_serial_num==240883

replace well_cost = well_cost_patterson if well_serial_num==240927

replace well_cost = well_cost_patterson if well_serial_num==240929

replace well_cost = well_cost_lucas if well_serial_num==240948

replace well_cost = well_cost_patterson if well_serial_num==240953

replace well_cost = well_cost_patterson if well_serial_num==240981

replace well_cost = well_cost_patterson if well_serial_num==240982

replace well_cost = well_cost_patterson if well_serial_num==241014

replace well_cost = well_cost_lucas if well_serial_num==241025

replace well_cost = well_cost_patterson if well_serial_num==241125

replace well_cost = well_cost_patterson if well_serial_num==241134

replace well_cost = well_cost_lucas if well_serial_num==241175

replace well_cost = well_cost_lucas if well_serial_num==241198

replace well_cost = well_cost_lucas if well_serial_num==241269

replace well_cost = well_cost_lucas if well_serial_num==241327

replace well_cost = well_cost_lucas if well_serial_num==241364

replace well_cost = well_cost_patterson if well_serial_num==241365

replace well_cost = well_cost_patterson if well_serial_num==241395

replace well_cost = well_cost_patterson if well_serial_num==241407

replace well_cost = well_cost_lucas if well_serial_num==241440

replace well_cost = well_cost_patterson if well_serial_num==241465

replace well_cost = well_cost_lucas if well_serial_num==241541

replace well_cost = well_cost_lucas if well_serial_num==241543

replace well_cost = well_cost_patterson if well_serial_num==241600

replace well_cost = well_cost_lucas if well_serial_num==241657

replace well_cost = well_cost_lucas if well_serial_num==241674

replace well_cost = well_cost_lucas if well_serial_num==241678

replace well_cost = well_cost_lucas if well_serial_num==241914

replace well_cost = well_cost_lucas if well_serial_num==242011

replace well_cost = well_cost_lucas if well_serial_num==242079

replace well_cost = well_cost_lucas if well_serial_num==242109

replace well_cost = well_cost_lucas if well_serial_num==242150

replace well_cost = well_cost_patterson if well_serial_num==242403

replace well_cost = well_cost_lucas if well_serial_num==242598

replace well_cost = well_cost_patterson if well_serial_num==242657

replace well_cost = well_cost_lucas if well_serial_num==242729

replace well_cost = well_cost_patterson if well_serial_num==242792

replace well_cost = well_cost_lucas if well_serial_num==242813

replace well_cost = well_cost_lucas if well_serial_num==242862

replace well_cost = well_cost_patterson if well_serial_num==242908

replace well_cost = well_cost_lucas if well_serial_num==242971

replace well_cost = well_cost_patterson if well_serial_num==243076

replace well_cost = well_cost_patterson if well_serial_num==243102

replace well_cost = well_cost_lucas if well_serial_num==243296

replace well_cost = well_cost_lucas if well_serial_num==243302

replace well_cost = well_cost_lucas if well_serial_num==243432

replace well_cost = well_cost_lucas if well_serial_num==243549

replace well_cost = well_cost_lucas if well_serial_num==243773

replace well_cost = well_cost_patterson if well_serial_num==243822

replace well_cost = well_cost_lucas if well_serial_num==243880

replace well_cost = well_cost_lucas if well_serial_num==243924

replace well_cost = well_cost_lucas if well_serial_num==243969

replace well_cost = well_cost_lucas if well_serial_num==244028

replace well_cost = well_cost_patterson if well_serial_num==244232

replace well_cost = well_cost_lucas if well_serial_num==244343

replace well_cost = well_cost_lucas if well_serial_num==244356

replace well_cost = well_cost_lucas if well_serial_num==244535

replace well_cost = well_cost_lucas if well_serial_num==245693

replace well_cost = well_cost_lucas if well_serial_num==245917

replace well_cost = well_cost_patterson if well_serial_num==246119

replace well_cost = well_cost_lucas if well_serial_num==246186

replace well_cost = well_cost_patterson if well_serial_num==247127

replace well_cost = well_cost_patterson if well_serial_num==247138

replace well_cost = well_cost_lucas if well_serial_num==247181

replace well_cost = well_cost_patterson if well_serial_num==247188

replace well_cost = well_cost_patterson if well_serial_num==247323

replace well_cost = well_cost_lucas if well_serial_num==247423

replace well_cost = well_cost_lucas if well_serial_num==247901

replace well_cost = well_cost_patterson if well_serial_num==248069

replace well_cost = well_cost_patterson if well_serial_num==248114

// Check to make sure we fixed everything (should be 0)
count if well_cost==. & (well_cost_patterson!=. | well_cost_lucas!=.)

drop well_cost_patterson
drop well_cost_lucas
drop flag_costs_problem

/*********************************************************
FLAG AND CORRECT NOTE DISCREPANCIES
*********************************************************/
// Fix string mismatch
replace note_patterson = "Amendment" if note_patterson == "Ammendment"
replace note_lucas = "Amendment" if note_lucas == "amendment"

// Now we check for note discrepancies
gen flag_note_problem = 0
replace flag_note_problem = 1 if note_patterson!=note_lucas

gen note = note_lucas if flag_note_problem==0

// After hand checking, we issue replace commands to fix everything
replace note = note_patterson if well_serial_num==238018

replace note = note_patterson if well_serial_num==239182

replace note = note_patterson if well_serial_num==239521

replace note = note_patterson if well_serial_num==239576

replace note = note_lucas if well_serial_num==239603

replace note = note_lucas if well_serial_num==239803

replace note = note_patterson if well_serial_num==240050

replace note = note_lucas if well_serial_num==240266

replace note = note_lucas if well_serial_num==240363

replace note = note_patterson if well_serial_num==240457

replace note = note_patterson if well_serial_num==240463

replace note = note_patterson if well_serial_num==240486

replace note = note_patterson if well_serial_num==240524

replace note = note_patterson if well_serial_num==240595

replace note = note_patterson if well_serial_num==240615

replace note = note_patterson if well_serial_num==240639

replace note = note_patterson if well_serial_num==240723

replace note = note_patterson if well_serial_num==240789

replace note = note_lucas if well_serial_num==240963

replace note = note_patterson if well_serial_num==240967

replace note = note_patterson if well_serial_num==241174

replace note = note_patterson if well_serial_num==241210

replace note = note_patterson if well_serial_num==241621

replace note = note_patterson if well_serial_num==241698

replace note = note_patterson if well_serial_num==241757

replace note = note_lucas if well_serial_num==241903

replace note = note_patterson if well_serial_num==242279

replace note = note_lucas if well_serial_num==243966

replace note = note_lucas if well_serial_num==244356

replace note = note_lucas if well_serial_num==244535

replace note = note_lucas if well_serial_num==245693

replace note = note_lucas if well_serial_num==246493

replace note = note_lucas if well_serial_num==247507

drop note_patterson
drop note_lucas
drop flag_note_problem

// modify well serial number for merging when creating master_wells.dta
rename well_serial_num Well_Serial_Num
tostring(Well_Serial_Num),replace

// Remove all wells with no data associated with them
drop if well_cost == .
gen from_RAFracCosts = 1
ren most_recent_comp_approx most_recent_comp_approx_costs

// Save the cleaned dataset
save "$outdir/wellcosts_data.dta", replace

// Close out the log file
capture log close
