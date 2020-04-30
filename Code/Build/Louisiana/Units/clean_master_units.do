***************************************************************
* Perform a bit of cleaning on the master unit data
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

// Input and output directories
global outdir = "$dbdir/IntermediateData/Louisiana"
global codedir = "$hbpdir/Code/Build/Louisiana"
global logdir = "$codedir/Logfiles"

log using "$logdir/clean_master_units_log.txt", replace text

***************************************************************

use "${outdir}/DescriptiveUnits/master_units.dta", clear

drop ID

decode UNIT_NA, gen(unitName)
drop UNIT_NA

decode UNIT_OR, gen(unitOrder)
drop UNIT_OR

decode FIELD, gen(Field)
drop FIELD

ren UNIT_AC unitAcres

decode OPERATO, gen(unitOperator)
drop OPERATO

decode FIELD_A, gen(fieldAbbr)
drop FIELD_A

decode DISSOLV, gen(dissolved)
drop DISSOLV

decode TERMINA, gen(terminated)
drop TERMINA

decode REDEFIN, gen(redefined)
drop REDEFIN

decode UNIT_LA, gen(unitLabel)
drop UNIT_LA

decode LUW_COD, gen(luwCode)
drop LUW_COD

decode APPLICA, gen(applicant)
drop APPLICA

ren SHAPE_A shapeArea
ren SHAPE_L shapeLen

decode FORMATI, gen(formation)
drop FORMATI

decode FORM_AB, gen(formAbbr)
drop FORM_AB

save "${outdir}/DescriptiveUnits/cleaned_master_units.dta", replace

capture log close
exit
