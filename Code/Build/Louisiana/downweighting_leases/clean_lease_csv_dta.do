*****************************************************************************
*
* Cleans up csv lease data
*       -Limits it to Haynesville counties
*       -eliminates duplicates such that the variables:
*          grantor grantee insttype instdate termmo royalty recdate effdate area
*          bonus exprdate optext extbonus exttermmo blm state county recordno township range section
*       uniquely identify observations
*
*****************************************************************************
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
global codedir = "$hbpdir/code/build/Louisiana"
global logdir = "$codedir/Logfiles"

// Create a plain text log file to record output
// Log file has same name as do-file
log using "$logdir/clean_lease_csv_dta_log.txt", replace text


* Bring in leases:
use "${leasedir}/louisiana_leases_DI_csvs.dta", clear
keep if ~missing(township) & ~missing(range) & ~missing(section)
drop if ~inlist(county,"BIENVILLE", "BOSSIER", "CADDO", "DE SOTO", "NATCHITOCHES", ///
    "RED RIVER", "SABINE", "WEBSTER")
keep if inlist(insttype,"LEASE","MEMO OF LEASE","LEASE OPTION","LEASE EXTENSION","LEASE AMENDMENT")
drop if real(section)>36 & real(section)<.
tab county
compress township range section
replace grantor = upper(grantor)
replace grantee = upper(grantee)

* drops straight duplicates
duplicates report // a few duplicates
duplicates drop

gen cluster_exprdate = exprdate + (exttermmo/12) * 365.25 if exttermmo!=.
replace cluster_exprdate=exprdate if cluster_exprdate==.
format cluster_exprdate %td
ren exprdate original_exprdate

local leasekeep = "grantor grantee insttype instdate termmo royalty recdate effdate area bonus original_exprdate cluster_exprdate optext extbonus exttermmo blm state county recordno township range section calls volpage"
egen Group = group(`leasekeep'), missing

* lat/lon puts one obs in Mississippi - drop it
drop if round(longitude*10000)==-910082 // observation that would be in Mississippi

* drop observations that are missing lat and lon but otherwise match some other observation
egen has_latlon = max(~missing(latitude) & ~missing(longitude)), by(Group)
drop if missing(latitude) & missing(longitude) & has_latlon 
drop has_latlon

local calls calls 
local leasekeep_minus_calls : list leasekeep - calls
duplicates tag `leasekeep_minus_calls', gen(duptag)
    egen group_dups = group(`leasekeep_minus_calls'), missing
    egen tag_dups = tag(`leasekeep_minus_calls'), missing
    egen count_dups = total(1), by(`leasekeep_minus_calls') missing
	tab count_dups if tag_dups
	egen has_nonmiss_calls = total(~missing(calls)), by(`leasekeep_minus_calls') missing
        replace has_nonmiss_calls = has_nonmiss_calls>0 if has_nonmiss_calls<.
    egen has_miss_calls    = total( missing(calls)), by(`leasekeep_minus_calls') missing
        replace has_miss_calls = has_miss_calls>0 if has_miss_calls<.
    drop if missing(call) & duptag & has_nonmiss_calls
    drop count_dups tag_dups duptag group_dups

duplicates tag `leasekeep_minus_calls', gen(duptag)
    egen group_dups = group(`leasekeep_minus_calls'), missing
    egen tag_dups = tag(`leasekeep_minus_calls'), missing
    egen count_dups = total(1), by(`leasekeep_minus_calls') missing
    sort group_dups calls
    sum count_dups
	local max_minus_1 = r(max)-1
    by group_dups: gen n_temp = _n
    gen new_calls = call
    replace new_calls = "+"+new_calls if n_temp>1 & n_temp<.
    forvalues n=`max_minus_1'(-1)1 {
        replace new_calls = new_calls+new_calls[_n+1] if n_temp==`n' & group_dups==group_dups[_n+1]
    }

    replace calls = new_calls
    drop new_calls
    drop if n_temp>1 & n_temp<.
    drop has_nonmiss_calls-n_temp

drop Group 


* Nadia finds that these locations are strictly mapped to one particular county
* (doesn't straddle the border) -- so drops the ones that are wrong
drop if township=="17N" & range=="14W" & section=="34" & county=="BOSSIER" // is Caddo
drop if township=="17N" & range=="14W" & section=="27" & county=="BOSSIER" // is Caddo
drop if township=="17N" & range=="14W" & section=="26" & county=="BOSSIER" // is Caddo
drop if township=="18N" & range=="16W" & section=="13" & county=="CADDO" // is Bossier
drop if township=="9N" & range=="13W" & section=="17" & county=="NATCHITOCHES" // is Sabine
drop if township=="7N" & range=="11W" & section=="25" & county=="NATCHITOCHES" // is Sabine

keep grantor-cluster_exprdate

* recdate:
qui ds recdate, not
local allbut `r(varlist)'
egen group = group(`allbut'), missing
egen firstrecdate = min(recdate), by(group)
keep if recdate==firstrecdate
drop firstrecdate
drop group

* recordno
qui ds recordno, not
local allbut `r(varlist)'
egen group = group(`allbut'), missing
sort group recordno
by group : gen n_temp = _n
drop if n_temp>1


* Final determination of leaseGroup:
keep grantor-cluster_exprdate // keeps only the original variables
qui ds township range section latitude longitude calls, not
local notTRS `r(varlist)'
egen leaseGroup = group(`notTRS'), missing
order leaseGroup, before(grantor)

* clean vol/page by splitting the two and destring-ing
split volpage, p("/")

replace volpage1 = subinstr(volpage1," ","",.)
replace volpage2 = subinstr(volpage2," ","",.)

replace volpage1 = "" if volpage1 == "NA"
replace volpage2 = "" if volpage2 == "NA"

destring volpage1, replace force
destring volpage2, replace force

ren volpage1 vol
ren volpage2 page

* clean recordno so we can do some analysis on differences here
replace recordno = subinstr(recordno, "/" " ", "",.)
destring recordno, replace force
* we need to do some downweighting
* code to identify grantors that are oil and gas firms
gen grantor_OGco = 0
foreach string in ENERGY OIL GAS PETROLEUM DRILL RESOURCE RESOURCES LAND LEASING ROYALTY MINERAL MINERALS EXPLORATION {
replace grantor_OGco = 1 if strpos(" "+grantor+" "," `string' ")
}
* a few other cases:
replace grantor_OGco = 1 if strpos(grantor,"PETRO-HUNT")
replace grantor_OGco = 1 if strpos(grantor,"PETROHAWK")
replace grantor_OGco = 1 if strpos(grantor,"CHESAPEAKE")
replace grantor_OGco = 1 if strpos(grantor,"ARKOMA")
replace grantor_OGco = 1 if strpos(grantor,"BRAMMER")
replace grantor_OGco = 1 if strpos(grantor,"DSK")
replace grantor_OGco = 1 if strpos(grantor,"BOKEY")
replace grantor_OGco = 1 if strpos(grantor,"KINSEY")
replace grantor_OGco = 1 if strpos(grantor,"GHK")
replace grantor_OGco = 1 if strpos(grantor,"EL PASO")
replace grantor_OGco = 1 if strpos(grantor,"BLACK STONE")
replace grantor_OGco = 1 if strpos(grantor,"GRAY INVESTMENTS")
replace grantor_OGco = 1 if strpos(grantor,"IVORY WORKING")
replace grantor_OGco = 1 if strpos(grantor,"HUNT PETOLEUM CORP")

replace grantor_OGco = 0 if blm | state // don't categorize Louisiana state mineral ownership as a O&G firm
egen totgra_area = total(area), by(grantor)
egen totgra_obs  = total(1), by(grantor)
gen gra_areaperobs = totgra_area / totgra_obs
egen tag_grantor = tag(grantor)
gsort -totgra_area // sorts the observations by descending area

* replace some alsgrantee names to make consistent
* Nadia hand checked all pairs of alsgrantee strings with fuzzywuzzy score > 75 and made the following cleaning corrections
replace alsgrantee = "FRANKS EXPL" if alsgrantee == "FRANK EXPLORATION" | alsgrantee == "FRANKS EXPLORATION LLC." | alsgrantee == "FRANK EXPL" | alsgrantee == "FRANKS EXPLO" | alsgrantee == "FRANKS PETROLEUM" | alsgrantee == "FRANK EXPLORATION CO LLC." | alsgrantee == "FRANKS EXPLORATION CO LLC."
replace alsgrantee = "TWIN CITIES DEVELOPMENT" if alsgrantee == "TWIN CITIES DEVELOPMENT LP." | alsgrantee == "TWIN CITIES DEVELOPEMENT LP." | alsgrantee == "TWIN CITES DEVELOPMENT LP." | alsgrantee == "TWIN CITIES DEVLEOPMENT LP." | alsgrantee == "TWIN CITIIES DEVELOPMENT LP."
replace alsgrantee = "FOREST OIL" if alsgrantee == "FORREST OIL CORP." | alsgrantee == "FOREST OIL C"
replace alsgrantee = "WELSH OIL CO." if alsgrantee == "WELSH OIL CO INC."
replace alsgrantee = "MANA ACQUISITIONS" if alsgrantee == "MANNA ACQUISITIONS" | alsgrantee == "MANNA ACQUISITIONS LLC." | alsgrantee == "MANNA ACQUISITONS LLC."
replace alsgrantee = "GULFSTREAM O&G" if alsgrantee == "GULFSTREAM OIL AND GAS CO."
replace alsgrantee = "SYLVIA RESOURCES" if alsgrantee == "SLYVIA RESOURCES"
replace alsgrantee = "RIVERSTONE ENERGY" if alsgrantee == "RIVER STONE ENERGY"
replace alsgrantee = "BIG PINE PETROLEUM" if alsgrantee == "BING PINE PETROLEUM"
replace alsgrantee = "DEDA HOLDINGS LLC." if alsgrantee == "DEDA HOLDINGA LLC."
replace alsgrantee = "ARK-LA-TEX ENERGY" if alsgrantee == "ARKLATEX ENERGY"
replace alsgrantee = "ANADARKO" if alsgrantee == "ANADARKO E&P" | alsgrantee == "ANADARKO E&P CO. LP." | alsgrantee == "ANADARKO E&P ONSHORE LLC." | alsgrantee == "ANADARKO E&P ONSHORELLC."
replace alsgrantee = "PINNACLE" if alsgrantee == "PINNACLE OPE"
replace alsgrantee = "TRINITY" if alsgrantee == "TRINITY RESOURCES"
replace alsgrantee = "PETROHAWK" if alsgrantee == "PETROHAWK PROPETIES LP. ET AL" | alsgrantee == "PETROHAWK PROPERTIES LLC." | strpos(" "+alsgrantee+" ","PETROWHAWK") | alsgrantee == "PETROHAK PROPERTIES"
replace alsgrantee = "STROUD" if alsgrantee == "STROUD EXPLO"
replace alsgrantee = "FLEET O&G" if alsgrantee == "J FLEET O&G"
replace alsgrantee = "CHIPPEWA INVESTMENTS LLC." if alsgrantee == "CHIPPEWA INVESTMEN"
replace alsgrantee = "PXP" if alsgrantee == "PXP LOUISIANA LLC. ET AL" | alsgrantee == "PXP LOUISIAN" | alsgrantee == "PXP LOUISIANA LLC."
replace alsgrantee = "COMSTOCK" if alsgrantee == "COMSTOCK OIL AND GAS LA INC." | alsgrantee == "COMSTOCK OIL AND GAS LOUISIANA LLC." | alsgrantee == "COMSTSOCK OIL & GAS-LA LLC." | strpos(" "+alsgrantee+" ", "COMSTOCK")
replace alsgrantee = "EXCO OPERATING" if alsgrantee == "EXCO OPERATI" | alsgrantee == "EXCO OPERATING CO. LP." | alsgrantee == "EXCO OPERATING CO LP." | alsgrantee == "EXCO PRODUCTION" | strpos(" "+alsgrantee+" ","EXCO")
replace alsgrantee = "TENSAS DELTA EXPL" if alsgrantee == "TENSAS DELTA EXPLORATION CO. LLC."
replace alsgrantee = "EL PASO" if alsgrantee == "EL PASO ENERGY E&P LLC." | alsgrantee == "EL PASO E&P CO LP."
replace alsgrantee = "CHESAPEAKE" if alsgrantee == "CHESAPEAKE O" | alsgrantee == "CHESAPEAKE LOUISINA LP." | alsgrantee == "CHESAPEAKE L" | strpos(" "+alsgrantee+" ", "CHESAPEAKE") | alsgrantee == "CHESPAEAKE LOUISIANA LP." | alsgrantee == "CHESAEPAKE LOUISIANA LP."
replace alsgrantee = "PETRO SHORE" if alsgrantee == "PETRO SHORE LLC."
replace alsgrantee = "ATLANTA EXPLORATION" if alsgrantee == "ATLATA EXPL"
replace alsgrantee = "SM ENERGY CORP." if alsgrantee == "SM ENERGY CO"
replace alsgrantee = "ENDEAVOR" if alsgrantee == "ENDEAVOUR OPERATING CORP. ET AL" | strpos(" "+alsgrantee+" ", "ENDEAVOR")
replace alsgrantee = "DB INTERESTS" if alsgrantee == "D B INTERESTS"
replace alsgrantee = "BHP BILLITON PETROLEUM" if alsgrantee == "BHP BILLITON PROPERTIES LP."
replace alsgrantee = "LAZARUS TRADING CO LLC." if alsgrantee == "LAZARUS TRADING CO. LLC."
replace alsgrantee = "KCS RESOURCES" if alsgrantee == "KCS RESOURCE"
replace alsgrantee = "HEP ENERGY INC." if alsgrantee == "HEP ENERGY INC."
replace alsgrantee = "BEUSA ENERGY" if alsgrantee == "BEUSA ENERGY LLC." | alsgrantee == "BEUSA ENERGY INC"
replace alsgrantee = "BHP BILLITON" if strpos(" "+alsgrantee+" ","BHP BILLITON") | alsgrantee == "BHP BILLTON" | alsgrantee == "BHP PETROLEU" | alsgrantee == "BH PETROLEUM"
replace alsgrantee = "CAMTERRA RESOURCES" if strpos(" "+alsgrantee+" ","CAMTERRA")
replace alsgrantee = "CYPRESS" if alsgrantee == "CPRESS OPERATING" | strpos(" "+alsgrantee+" ", "CYPRESS")
replace alsgrantee = "ENCANA" if alsgrantee == "ENCANA OIL &" | alsgrantee == "ENCANA OIL & GAS (USA) INC." | alsgrantee == "ENCANA OIL AND GAS (USA) INC." | strpos(" "+alsgrantee+" ", "ENCANA")
replace alsgrantee = "HEP ENERGY INC." if alsgrantee == "HEP ENERGY I"
replace alsgrantee = "INDIGO MINERALS" if strpos(" "+alsgrantee+" ", "INDIGO")
replace alsgrantee = "PRIDE O&G" if alsgrantee == "PRIDE OIL &"
replace alsgrantee = "QEP ENERGY" if alsgrantee == "QEP ENERGY CO" | alsgrantee == "QEP ENERGY CO." | strpos(" "+alsgrantee+" ","QEP")
replace alsgrantee = "TACOMA ENERGY CORP." if alsgrantee == "TACOMA ENERG" | alsgrantee == "TACOMA ENERGY"
replace alsgrantee = "VALOR PETROL" if alsgrantee == "VALOR PETROLEUM LLC."
replace alsgrantee = "XTO ENERGY" if alsgrantee == "XTO ENERGY I"
replace alsgrantee = "3G OIL & GAS LLC." if alsgrantee == "3 G OIL AND GAS LLC" | alsgrantee == "3G OIL AND G"
replace alsgrantee = "ADA CARBON SOLUTIONS LLC." if alsgrantee == "ADA CARBON SOLUTIONS LLC. ET AL"
replace alsgrantee = "AEEC II" if alsgrantee == "AEEC II LLC."
replace alsgrantee = "ALTERNATE FUEL" if alsgrantee == "ALTERNATE FU"
replace alsgrantee = "ARKOMA LOUISIANA LLC." if alsgrantee == "ARKOMA-LA LLC."
replace alsgrantee = "ASHLEY ANN ENERGY" if alsgrantee == "ASHLEY ANN ENERGY LLC."
replace alsgrantee = "ASHLOR" if alsgrantee == "ASHLOR LLC."
replace alsgrantee = "AUDUBON EXPLORATION" if alsgrantee == "AUDUBON EXPL" | alsgrantee == "AUDUBON O&G"
replace alsgrantee = "BERGFELD LAND & MINERALS GROUP LLC." if alsgrantee == "BERGFIELD LAND & MINERALS GROUP LLC."
replace alsgrantee = "BERKSHIRE INTERESTS" if alsgrantee == "BERKSHIRE INTERESTS INC."
replace alsgrantee = "BMW ENDEAVORS" if alsgrantee == "BMW ENDEAVORS LLC."
replace alsgrantee = "C6 OPERATING INC." if alsgrantee == "C6 OPERATING LLC."
replace alsgrantee = "CHEROKEE HORN ENERGY" if alsgrantee == "CHEROKEE HORN LOUISIANA"
replace alsgrantee = "CINDER PRODUCTION" if strpos(" "+alsgrantee+" ", "CINDER")
replace alsgrantee = "CLARK ENERGY" if strpos(" "+alsgrantee+ " ", "CLARK ENERGY")
replace alsgrantee = "CLASSIC PRODUCTION SERVICES" if alsgrantee == "CLASSIC PROD SERVICES"
replace alsgrantee = "COASTAL LAND" if alsgrantee == "COASTAL" | alsgrantee == "COASTAL LAND SERVICES INC."
replace alsgrantee = "COHORT ENERGY" if alsgrantee == "COHORT ENERGY CO."
replace alsgrantee = "COY W HALE" if alsgrantee == "COY W. HALE"
replace alsgrantee = "CRABAPPLE PROPERTIES" if alsgrantee == "CRABAPPLE PROPERTIES LTD."
replace alsgrantee = "CROSS PETROL" if alsgrantee == "CROSS PETROLEUM LLC."
replace alsgrantee = "CROSSKEYS ENERGY LLC." if alsgrantee == "CROSSKEYS EN"
replace alsgrantee = "CROWNPOINTE ACQUISITIONS" if alsgrantee == "CROWNEPOINTE ACQUISITIONS"
replace alsgrantee = "CSC ENERGY" if alsgrantee == "CSC ENERGY C" | alsgrantee == "CSC ENERGY CORP." | alsgrantee == "CSC INTERESTS"
replace alsgrantee = "CURTIS F ADAMS" if alsgrantee == "CURTIS F. ADAMS ET UX"
replace alsgrantee = "DAVID D. KIRBY" if alsgrantee == "DAVID D. KIR"
replace alsgrantee = "DELTA LAND" if alsgrantee == "DELTA"
replace alsgrantee = "DUCHARME VOZELLA INVESTMENTS LLC." if alsgrantee == "DUCHARME VOZZELLA INVESTMENTS LLC."
replace alsgrantee = "EASON PETROLEUM" if strpos(" "+alsgrantee+" ", "EASON")
replace alsgrantee = "EDDY ENTERPRISE" if alsgrantee == "EDDY ENTERPR"
replace alsgrantee = "EMPRESA" if alsgrantee == "EMPRESA ENER"
replace alsgrantee = "EMPRESS" if alsgrantee == "EMPRESS LLC ET AL"
replace alsgrantee = "ENERGEN" if alsgrantee == "ENEREN RESOURCES" | strpos(" "+alsgrantee+" ", "ENERGEN")
replace alsgrantee = "ENERQUEST" if strpos(" "+alsgrantee+" ", "ENERQUEST")
replace alsgrantee = "EOG" if alsgrantee == "EOG RESOURCES INC."
replace alsgrantee = "EQUITY OIL" if alsgrantee == "EQUITY OIL CO. ET AL"
replace alsgrantee = "FAMILY TREE" if alsgrantee == "FAMILY TREE CORP."
replace alsgrantee = "FARNLEY O&G" if strpos(" "+alsgrantee+" ", "FARNLEY") | alsgrantee == "FAMLEY O&G"
replace alsgrantee = "FITE O&G" if strpos(" "+alsgrantee+" ","FITE")
replace alsgrantee = "FIVE FORKS MINING" if alsgrantee == "FIVE FORKS MINING LLC."
replace alsgrantee = "FOUR STAR" if strpos(" "+alsgrantee+" ", "FOUR STAR")
replace alsgrantee = "FREDCO" if strpos(" "+alsgrantee+" ", "FREDCO")
replace alsgrantee = "FURIE O&G" if strpos(" "+alsgrantee+" ", "FURIE")
replace alsgrantee = "GEM EXPL" if alsgrantee == "GEM PRODUCTION"
replace alsgrantee = "GOLDCO OPERATING" if alsgrantee == "GOLDCO OPERA"
replace alsgrantee = "GOODRICH" if strpos(" "+alsgrantee+" ", "GOODRICH")
replace alsgrantee = "HALE OIL" if alsgrantee == "HALE OIL CO" | alsgrantee == "HALE OIL COM"
replace alsgrantee = "HERITAGE ENERGY" if alsgrantee == "HERITAGE ENE"
replace alsgrantee = "HIGH HOPE O&G" if alsgrantee == "HIGH HOPE OIL & GAS INC."
replace alsgrantee = "HOBBS PRODUCTION LLC."  if alsgrantee == "HOBBS PRODUC"
replace alsgrantee = "HODGES ENERGY" if alsgrantee == "HODGES ENERGY LLC."
replace alsgrantee = "HUNTER" if alsgrantee == "HUNTER ENERG"
replace alsgrantee = "ILIOS EXPL" if alsgrantee == "ILIOS RESOURCES"
replace alsgrantee = "INDIAN WELLS" if alsgrantee == "INDIAN WELLS INVESTMENTS LLC."
replace alsgrantee = "IVORY ACQUISITIONS" if strpos(" "+alsgrantee+" ", "IVORY")
replace alsgrantee = "J-W OPERATING CO" if alsgrantee == "J-W OPERATIN"
replace alsgrantee = "JABEZ L&M" if strpos(" "+alsgrantee+" ","JABEZ")
replace alsgrantee = "JB LAND SERVICES LLC." if alsgrantee == "JB LAND SERV"
replace alsgrantee = "JM EXPLORATI" if alsgrantee == "JM EXPL"
replace alsgrantee = "JOHN H FETZER" if alsgrantee == "JOHN H. FETZER JR."
replace alsgrantee = "JPD ENERGY" if alsgrantee  == "JPD ENERGY INC."
replace alsgrantee = "JUSTISS OIL" if strpos(" "+alsgrantee+" ","JUSTISS")
replace alsgrantee = "JW ENERGY" if alsgrantee == "JW OPERATING CO."
replace alsgrantee = "LANZA LAND LLC." if alsgrantee == "LANZA LAND MGMT"
replace alsgrantee = "LODWICK MINERALS" if strpos(" "+alsgrantee+" ", "LODWICK")
replace alsgrantee = "LONG PETROLEUM" if alsgrantee == "LONG PETROLE"| alsgrantee == "LONG OPERATING" | alsgrantee == "LONG PETROLEUM LLC." | alsgrantee == "LONG PETROLEUM LLC. ET AL"
replace alsgrantee = "LOUISIANA ENERGY" if alsgrantee == "LOUISIANA EN"
replace alsgrantee = "M&M ENERGY" if strpos(" "+alsgrantee+" ","M&M")
replace alsgrantee = "MARK A O'NEAL" if alsgrantee == "MARK A O NEA" | alsgrantee == "MARK A. O NE" | alsgrantee == "MARK O'NEAL"
replace alsgrantee = "MARTIN PRODUCING" if alsgrantee == "MARTIN PRODU" | alsgrantee == "MARTIN PRODUCING LLC."
replace alsgrantee = "MATADOR" if alsgrantee == "MATADOR RESOURCES CO." | alsgrantee == "MATARDO RESOURCES"
replace alsgrantee = "MEMCO E&P" if alsgrantee == "MEMCOEXPLOR"
replace alsgrantee = "MERIT ENERGY" if alsgrantee == "MERIT ENERGY SERVICES LLC."
replace alsgrantee = "MID SOUTH TRADING" if alsgrantee == "MID SOUTH TR" | alsgrantee == "MID SOUTH TRADING INC."
replace alsgrantee = "MIDLAND WORKOVER" if alsgrantee == "MIDLAND WORKOVER INC ET AL"
replace alsgrantee = "MIKE SPEEGLE" if alsgrantee == "MIKE R. SPEEGLE"
replace alsgrantee = "MILLER LAND PROFESSIONALS LLC." if alsgrantee == "MILLER LAND"
replace alsgrantee = "MINERAL VENTURES" if alsgrantee == "MINERAL VENT"
replace alsgrantee = "MONETA" if alsgrantee == "MONETA MANAGEMENT LLC."
replace alsgrantee = "MURPHY LAND & EXPLORATION LLC." if alsgrantee == "MURPHY E&P" | alsgrantee == "MURPHY L&E" | alsgrantee == "MURPHY LAND"
replace alsgrantee = "NADEL & GUSSMAN" if strpos(" "+alsgrantee+" ","NADEL & GUSSMAN") | strpos(" "+alsgrantee+" ","NADEL AND GUSSMAN")
replace alsgrantee = "NATHAN HALE OIL CO." if alsgrantee == "NATHAN HALE OIL"
replace alsgrantee = "PARAMOUNT ENERGY" if alsgrantee == "PARAMOUNT ENERGY INC."
replace alsgrantee = "PERKINS OIL" if alsgrantee == "PERKINS OIL PROPERTIES"
replace alsgrantee = "PETRO-CHEM OPERATING" if strpos(" "+alsgrantee+" ","PETRO-CHEM")
replace alsgrantee = "PLANTATION OPERATING" if alsgrantee == "PLANTATION OPERATING LLC."
replace alsgrantee = "PRESTIGE EXPL" if alsgrantee == "PRESTIGE EXP"
replace alsgrantee = "QUEST ENERGIES" if alsgrantee == "QUEST ENERGIES LLC."
replace alsgrantee = "RIC BAJON &" if alsgrantee == "RIC BAJON & ASSOCIATES LLC."
replace alsgrantee = "SAMMY D THRASH" if alsgrantee == "SAMMY D. THRASH"
replace alsgrantee = "SGS NATURAL GAS" if alsgrantee == "SGS NATURAL"
replace alsgrantee = "SHELBY ENERGY HOLDING LLC ET AL" if alsgrantee == "SHELBY ENERGY HOLDINGS LLC." | alsgrantee == "SHELBY O&G"
replace alsgrantee = "SKLARCO" if alsgrantee == "SKLARCO LLC."
replace alsgrantee = "SM ENERGY CORP." if alsgrantee == "SM ENERGY CORP."
replace alsgrantee = "SONAT EXPL" if alsgrantee == "SONAT MINERALS LEASING"
replace alsgrantee = "SOURCE OIL LLC." if alsgrantee == "SOURCE OI L"
replace alsgrantee = "SOUTHERN ENE" if alsgrantee == "SOUTHE5N ENE" | alsgrantee == "SOUTHERN ENERGY LLC."
replace alsgrantee = "SOUTHERN LAND" if alsgrantee == "SOUTHERN LAND & EXPLORATION"
replace alsgrantee = "STELLIOS EXPLORATION" if alsgrantee == "STELLIOS EXPLORATION CO."
replace alsgrantee = "STRATA ACQUISITIONS LLC." if strpos(" "+alsgrantee+" ","STRATA")
replace alsgrantee = "SUNCOAST" if alsgrantee == "SUN COAST TECHNICAL" | alsgrantee == "SUNCOAST LAND SERVICES INC."
replace alsgrantee = "SUNLAND PRODUCTION" if strpos(" "+alsgrantee+" ","SUNLAND PRODUCTION")
replace alsgrantee = "SWEPI LP." if strpos(" "+alsgrantee+" ","SWEPI")
replace alsgrantee = "TAYCO ENERGY" if alsgrantee == "TAYCO ENERGY INC."
replace alsgrantee = "TDX ENERGY LLC." if alsgrantee == "TDX ENERGY L"
replace alsgrantee = "TEDAN" if alsgrantee == "TEDAN EXPLORATION CO."
replace alsgrantee = "TEXEX PETROL" if alsgrantee == "TEXEX PETROLEUM CORP."
replace alsgrantee = "THEOPHILEUS O&G" if alsgrantee == "THEOHILUS O&G LAND SERVICES" | strpos(" "+alsgrantee+" ","THEOPHILUS")
replace alsgrantee = "TITAN LAND AND MINERALS LLC." if alsgrantee == "TITAN LAND A"
replace alsgrantee = "TONY CLEMONS" if alsgrantee == "TONY W. CLEMONS"
replace alsgrantee = "TOUCHSTONE O&G" if strpos(" "+alsgrantee+" ","TOUCHSTONE")
replace alsgrantee = "TRINITY O&G EXPL" if strpos(" "+alsgrantee+" ","TRINITY")
replace alsgrantee = "TXX ENERGY CORP." if alsgrantee == "TXX OPERATING LLC."
replace alsgrantee = "WAGNER OIL" if alsgrantee == "WAGNER OIL CO."
replace alsgrantee = "WELSH OIL" if alsgrantee == "WELSH OIL CO."
replace alsgrantee = "WESTGROVE ENERGY HOLDINGS" if alsgrantee == "WESTGROVE ENERGY HOLDINGS LLC."
replace alsgrantee = "WHITING OIL AND GAS CORP." if alsgrantee == "WHITING OIL"
replace alsgrantee = "WILCOX OPERATING" if alsgrantee == "WILCOX OPERA"
replace alsgrantee = "WILL-DRILL RESOURCES" if alsgrantee == "WILL-DRILL RESOURCES INC."
replace alsgrantee = "WOODLAND PETROLEUM" if alsgrantee == "WOODLAND PET"
replace alsgrantee = "XH LLC" if alsgrantee == "XH LLC."

*let's first do some general cleaning on grantor name
gen grantor_orig = grantor
gen grantor_clean = grantor
replace grantor_clean = regexr(grantor_clean, "\.+", "")
replace grantor_clean = regexr(grantor_clean, "\.+", "")
replace grantor_clean = regexr(grantor_clean, "\.+", "")
replace grantor_clean = regexr(grantor_clean, ",+", "")
replace grantor_clean = regexr(grantor_clean, ",+", "")
replace grantor_clean = regexr(grantor_clean, " ,+", "")
replace grantor_clean = regexr(grantor_clean, " \.+", "")
replace grantor_clean = regexr(grantor_clean, " ,+", "")
replace grantor_clean = regexr(grantor_clean, " \.+", "")
replace grantor_clean = subinstr(grantor_clean, "ET AL", "",.)
replace grantor_clean = subinstr(grantor_clean, "ETAL", "",.)
replace grantor_clean = subinstr(grantor_clean, "ET UX","",.)
replace grantor_clean = subinstr(grantor_clean, "ETUX", "",.)
replace grantor_clean = subinstr(grantor_clean, "LLC","",.)
replace grantor_clean = subinstr(grantor_clean, "LP","",.)
replace grantor_clean = subinstr(grantor_clean, "JR", "",.)
replace grantor_clean = subinstr(grantor_clean, "SR","",.)
replace grantor_clean = subinstr(grantor_clean, "III","",.)
replace grantor_clean = subinstr(grantor_clean, "FAMILY","",.)
replace grantor_clean = subinstr(grantor_clean, "TRUSTEE","",.)
replace grantor_clean = subinstr(grantor_clean, "TRUST","",.)
replace grantor_clean = trim(grantor_clean)
replace grantor = grantor_clean
drop grantor_clean

* now let's clean grantor names
replace grantor = "BEN JOHNSON" if grantor=="BEN JOHNSON   OF THE NABORS"
replace grantor = "BROWN MCCULLOUGH" if grantor == "BROWN MCCULLOUGH HUMPHREY"
replace grantor = "COAL ROYALTY CO" if grantor=="N/A COAL ROYALTY COMPANY" | grantor=="NORTH AMERICAN COAL ROYALTY CO"
replace grantor = "FRANK PALMS BOOK" if grantor == "FRANK PALLMS BOOK"
replace grantor = "ELLEN VELVIN BURTON" if grantor == "ELLEN BURTON"
replace grantor = "UNITED STATES DEPT OF THE INTERIOR" if grantor == "UNITED STATES DEPARTMENT OF THE INTERIOR"
replace grantor = "JAY STERLING CLEMENTS" if grantor == "JAY S CLEMENTS"
replace grantor = "ANNIE LAURIE LANIER SAMUELS" if grantor == "ANNIE LAURIE LANNIER SAMUELS"
replace grantor = "MARY D BRADWAY" if grantor == "MARY D BROADWAY"
replace grantor = "NANCY LUCILLE HUDSON KETNER" if grantor == "NANCY LUCILL HUDSON KETNER ET UX"
replace grantor = "GIDDENS LAND CO" if grantor == "GIDDENS LAND COMPANY"
replace grantor = "HOLLIS RAY WALLER" if grantor == "WALLER"
replace grantor = "FLOYD E VALENTINE & SON INC" if grantor == "FLOYD E VOLENTINE & SON INC"
replace grantor = "HELEN E BAXLEY" if grantor == "HELEN E BAXTLEY"
replace grantor = "JOSEPHINE CHAMBERS HELLEYER" if grantor == "JOSEPHINE CHAMBERS HELLYER"
replace grantor = "BANGO  LIMITED PARTNERSHIP OF HOT SPRINGS" if grantor == "BANGO"
replace grantor = "KIELL R WAERSTAD" if grantor == "KJELL R WAERSTAD"
replace grantor = "LENNIS SMITH ELSTON" if grantor == "LENNIS SMITH ELSTON DA RICHLEN LAND COMPANY INC,"
replace grantor = "RED OAK TIMBER CO" if grantor == "RED OAK TIMBER COMPANY"
replace grantor = "WILLIAM F FORD TESTAMENTARY" if grantor == "WILLIAM F FORD TERTAMENTARY"
replace grantor = "CYNTHIA FRY PEIRONNET" if grantor == "CYNTHIA FRYE PEIRONET"
replace grantor = "G&J MICOTTO PROPETIES" if grantor == "GRECCO MICOTTO PROPERTIES"
replace grantor = "HERBERT P BENTON" if grantor == "HERBERTP BENTON"
replace grantor = "SUCCESSION OF KATHLYN RIDENOUR WALLACE" if grantor == "SUCCESSION OF ROSE KATHLYN RIDENOUR WALLACE"
replace grantor = "DOCHEAT ADVENTURES" if grantor == "DORCHEAT ADVENTURES"
replace grantor = "JOHN ALLEN CAMPBELL" if grantor == "JOHN CAMPBELL"
replace grantor = "HEROLD" if grantor == "HEROLD-WINKS-VALLHONRAT"
replace grantor = "CH COLVIN GROUP" if grantor == "COLVIN RESOURCE HOLDING"
replace grantor = "JILL ANN RUSH KOLODEZY" if grantor == "JILL ANN RUSH KOLODZEY"
replace grantor = "MOLLY ANNE DUGGAN CARROLL" if grantor == "MOLLY JONES DUGGAN"
replace grantor = "AT&N MARTINEZ LAND CO" if grantor == "AT&N MARTINEZ LAND COMPANY"
replace grantor = "KATHRYN JAMES BAKER" if grantor == "KATHRYN JAMES BUKER"
replace grantor = "LUTHER W MORE" if grantor == "LUTHER W MORE  INDEPENDENT EXECUTOR"
replace grantor = "CATHERINE POOLE ANTROBUS" if grantor == "KATHERINE POOLE ANTROBUS"
replace grantor = "HEZZIE L STEVENSON" if grantor == "HEZZIE L STVENSON"
replace grantor = "DAVID L CHILES" if grantor == "DAVID MARK CHILES"
replace grantor = "FHF" if grantor == "FHF L.L.C."
replace grantor = "JUDITH ANN MAYER KINSEY" if grantor == "JUDITH P MAYER"
replace grantor = "JEMMA MARIE G SLOAN" if grantor == "JEMMA MARY SLOAN"
replace grantor = "DAVID MADELL BEAIRD" if grantor == "DAVID MANDELL BEAIRD"
replace grantor = "ANGELA D CHISHIMBA" if grantor == "ANGELA D CHISIMBA"
replace grantor = "MAGDALENA HERSHEY" if grantor == "MAGDALENE HERSHEY"
replace grantor = "ELIZABETH GUICE BEAVERS" if grantor == "ELIZABETH GUICE WEAVER"
replace grantor = "LAURA GUICE" if grantor == "LAURA GUICE HARROFF"
replace grantor = "JAMES M ARGO TESTAMENTARY" if grantor == "JAMES MERCER ARGO TESTAMENTARY"
replace grantor = "SIMSHALE" if grantor == "SINSHALE"
replace grantor = "JOSEPH L ROGERS" if grantor == "JOSEPJ L ROGERS"
replace grantor = "DEBORAH J SILVERBERG" if grantor == "DEBORAH SILVERBERG"
replace grantor = "SIDNEY H GUINN" if grantor == "SIDNEY KATE GUINN"
replace grantor = "CBA INVESMTMENTS" if grantor == "CBA INVESTMENTS"
replace grantor = "DARRYL H LEVY" if grantor == "DARRYL HERBERT LEVY"
replace grantor = "GINA SHERYL ARNOLD CONNELL" if grantor == "GINA SHERYLL ARNOLD"
replace grantor = "JON TODD ARNOLD" if grantor == "JOHN T ARNOLD"
replace grantor = "MAX W HART" if grantor == "THE ESTATE OF MAXINE HART PREWITT INTERDICT"
replace grantor = "CHRISTOPHER HAYNE O SHEE" if grantor == "CHRISTOPHER L HAYNE"
replace grantor = "JIMMY D MORGAN" if grantor == "JIMMY MORGAN AND LINDA MORGAN REVOCABLE LIVING"
replace grantor = "BETTY JACKS HERVEY" if grantor == "BETTY JACKS HERVEY REVOCABLE LIVING"
replace grantor = "DEC LAND CO" if grantor == "DEC LAND COMPANY"
replace grantor = "BOB C JOLLY" if grantor == "BOB CONWAY JOLLY"
replace grantor = "EUGENIA CONWAY GOFF" if grantor == "EUGENIA CONWAY SAURAGE GOFF"
replace grantor = "DIXIE HAITI" if grantor == "DIXIE HAYTI"
replace grantor = "AMANDA PERITT CLINGAN" if grantor == "AMANDA PERRITT CLINGAN"
replace grantor = "LOTT CO" if grantor == "LOTT COMPANY"
replace grantor = "DOROTHY WAFER THOMA" if grantor == "DOROTHY W THOMA"
replace grantor = "ELIZABETH WHEELES ELGIN" if grantor == "ELIZABETH W EGLIN"
replace grantor = "EDWARD HENRY GANZ" if grantor == "GANZ"
replace grantor = "RUTH ANN BUTLER KIDD" if grantor == "RUTH A KIDO"
replace grantor = "WILLIAM THOMAS JOHNSTON" if grantor == "WILLIAM T JOHNSTON" | grantor == "WILLIAMS THOMAS JOHNSTON"
replace grantor = "MOHINDER PAUL AHLUWALIA" if grantor == "MOHINDER PAUL AHUWALIA"
replace grantor = "ALAN GLEN NICKERSON" if grantor == "ALAN G NICKERSON"
replace grantor = "ELIZABETH BRADFORD VAUGHAN" if grantor == "ELIZABETH B VAUGHAN"
replace grantor = "EMMA H HUGHES" if grantor == "EMMA H HUGHENS"
replace grantor = "ESTHER IRIS MILHOUS" if grantor == "ESTER IRIS MILHOUS"
replace grantor = "FRANK B TREAT & SONS INC" if grantor == "FRANK B TREAT & SON INC"
replace grantor = "GEORGE HAROLD ALEXANDER" if grantor == "GEORGE H ALEXANDER"
replace grantor = "MARY E EDENS" if grantor == "MARY ELIZABETH EDENS"
replace grantor = "MILDRED NAN HOOD LYNCH" if grantor == "MIDLRED NAN HOOD LYNCH"
replace grantor = "WILLIAM C HOOD" if grantor == "WILLIAMS CHARLES HOOD"
replace grantor = "DONOVAN L MCCANCE" if grantor == "MCCANCE"
replace grantor = "RUSSELL D YOUNGMAN" if grantor == "RUSSELL L YOUNGMAN"
replace grantor = "MARIUS T MCFARLAND" if grantor == "MAIRUS T MCFARLAND"
replace grantor = "RIVER POINT RACING" if grantor == "RIVER POINT RACING AND EQUESTRIAN CENTER INC"
replace grantor = "JUDY G BRITT" if grantor == "JUDY GAIL BRITT"
replace grantor = "LOY B MOORE" if grantor == "LOY BEENE MOORE"
replace grantor = "GLENN & JANIE HILL LIVING" if grantor == "GLENN AND JANIE HILL LIVING"
replace grantor = "ARTHUR ROY PAGE" if grantor == "A R PAGE"
replace grantor = "DEER CREEK MOBILE ESTATES INC" if grantor == "DEER CREEK MOBILE HOME ESTATE INC"
replace grantor = "ERNEST E WILKERSON" if grantor == "ERNEST EUGENE WILKERSON"
replace grantor = "FRANK MATTHEWS" if grantor == "FRANK WAYNE MATTHEWS QUALIFIED"
replace grantor = "DENNIS J MORRIS" if grantor == "DENNIS JON MORRIS"
replace grantor = "LISA MATTHEWS" if grantor == "LISA MATHEWS"
replace grantor = "LAMBERT PROPERTIES" if grantor == "LAMBERT DEVELOPING COMPANY"
replace grantor = "MARY R GALLASPY" if grantor == "MARY R GALLASPY DBA ROCKING G FARMS"
replace grantor = "MICHAEL COPELAND" if grantor == "MICHAEL WAYNE COPELAND"
replace grantor = "WILLIE COPELAND" if grantor == "WILLIE MAE COPELAND MOORE"
replace grantor = "JAMES T CRUMP" if grantor == "JAMES THOMAS CRUMP"
replace grantor = "LAVERNE BROWN BELL" if grantor == "LAVERNE BROWN BELL INDIV & EXECUTRIX"
replace grantor = "HOWARD FERGUSON" if grantor == "HOWARD N FERGUSON"
replace grantor = "JAMES E MARTIN" if grantor == "JAMES EMARTIN"
replace grantor = "SANDRA FRANKLIN" if grantor == "SANDRA FARNKLIN"
replace grantor = "STATE MINERAL BOARD OF LOUISIANA" if grantor == "STATE MINERAL BOARD"
replace grantor = "WEYERHAUSER CO" if grantor == "WEYERHAUSER NR CO"
replace grantor = "LEONARD JOHNSON" if grantor == "LEON JOHNSON"
replace grantor = "VIRGINIA RILEY HOUSTON" if grantor == "VIRGINIA REILY HOUSTON"
replace grantor = "ILIOS EXPLORATION" if grantor == "ILLIOS EXPLORATION"
replace grantor = "TERESA SHELTON BAYS" if grantor == "THERESA SHELTON BAYS"
replace grantor = "DIANNA BAKER DAVIS GUEVARA" if grantor == "DIANNA BAKER GUEVARA"
replace grantor = "JOHN W WALKER" if grantor == "JOHN WALKER"
replace grantor = "PAMELA JETER COMEGYS" if grantor == "PAMELA JETER COMYGES"
replace grantor = "JAMES L LOE" if grantor == "JAMES LEIGHTON LOE"
replace grantor = "BARRY J DEBROECK" if grantor == "BARRY J DEBROEK" | grantor == "BARRY JOSEPH DEBROECK"
replace grantor = "WILLIAM J DUNN" if grantor == "WILLIAM JOESPH DUNN"
replace grantor = "NEIL LEE NEW" if grantor == "NELL LEE NEW"
replace grantor = "ANDREA COLEMAN" if grantor == "ANDRIA COLEMAN"
replace grantor = "G RANDY ALEWYNE" if grantor == "GEORGE RANDY ALEWYNE  ET  UX"
replace grantor = "UNION PACIFIC RAILROAD CO" if grantor == "UNION PAC RAILROAD CO"
replace grantor = "YK LANDVEST 2 INC" if grantor == "YK LANDWEST 2 INC"
replace grantor = "WENDALL COKER" if grantor == "WENDELL COKER"
replace grantor = "LILLIAN DORLENE WARREN JONES" if grantor == "LILLIAN W JONES"
replace grantor = "CLECO POWELL" if grantor == "CLECO POWER"
replace grantor = "THOMAS O LEE" if grantor == "THOMAS OSCAR LEE"
replace grantor = "MARTHA MAGGIE TRIMBLE" if grantor == "MARTHA MAGEE TRIMBLE"
replace grantor = "JOHN FREEMAN" if grantor == "JOHN M FREEMAN"
replace grantor = "LOUISIANA DEPT OF TRANSPORTATION AND DEV" if grantor == "LOUISIANA DEPARMENT OF TRANSPORTATION AND DEVELOPMENT"
replace grantor = "FREDDIE TERRELL" if grantor == "FREDDIE B TERRELL"
replace grantor = "CARROLL G HARDY" if grantor == "CAROLL GAY HARDY"
replace grantor = "RAMSON EDGAR CASON" if grantor == "RAMSON EDGAR CASON INDIV & AGENT"
replace grantor = "FOSTER S SENTELL" if grantor == "FOSTER SCOTT SENTELL"
replace grantor = "JAMES B WHISTLER" if grantor == "JAMES BURCH WHISTLER"
replace grantor = "JOHN G SENTELL" if grantor == "JOHN GREGORY SENTELL"
replace grantor = "JOHNETTE S NORRIS" if grantor == "JOHNETTE SENTELL NORRIS"
replace grantor = "JOHNNIE S MARSHALL" if grantor == "JOHNNIE SANDIFER MARSHALL"
replace grantor = "MARGARET JOHNSON WARTON" if grantor == "MARGARET DEMARET JOHNSON WHARTON" | grantor == "MARGARET M JOHN"
replace grantor = "MAYBETH S PARKER" if grantor == "MAYBETH SENTELL PARKER"
replace grantor = "RICHARD C JOHNSON" if grantor == "RICHARD CLYDE JOHNSON"
replace grantor = "SARAH A WHISTLER" if grantor == "SARAH ALEXANDER WHISTLER"
replace grantor = "SUSAN K WHISTLER" if grantor == "SUSAN KATHERINE WHISTLER"
replace grantor = "WILLIAM B SENTELL" if grantor == "WILLIAM BRET SENTELL"
replace grantor = "SARAH ELIZABETH COPE JARVIS BROWN" if grantor == "SARAH ELIZABETH COP JARVIS BYRD BROWN"
replace grantor = "SARAH ELIZABETH COP JARVIS BYRD BROWN" if grantor == "CAROLYN SANDERS PEARSON ERVIN"
replace grantor = "OG PIPKIN" if grantor == "ORLANDO G PIPKIN"
replace grantor = "DEBORAH G GRIFFITH" if grantor == "DEBORAH GLYN GRIFFITH"
replace grantor = "DOROTHY NORMAN" if grantor == "DORETHA NORMAN"
replace grantor = "MARY MARGARET DALRYMPLE BRADWAY ETVIR" if grantor == "MARY MARGARET DALRYMPLE BRADWAY"
replace grantor = "LESTER SIMMONS" if grantor == "LESTER GERALD SIMMONS"
replace grantor = "WILBURN A CRNKOVIC" if grantor == "WILBURN ALVIN CRNKOVIC"
replace grantor = "RANDALL G MIDDLETON" if grantor == "RANDAL G MIDDLETON"
replace grantor = "WILLIAM J GOFF" if grantor == "WILLIAMS J GOFF"
replace grantor = "MARIUS T MCFARLAND" if grantor == "MAIRUS T MCFARLAND"
replace grantor = "THERESA BERNICE MATHEWS ETVIR" if grantor == "THERESA BERNICE CARTER MATHEWS"
replace grantor = "JE NAPIER" if grantor == "JAMES E NAPIER"
replace grantor = "THE ALVIN HOLLOWAY SINCLAIR" if grantor == "THE ALVIN HOLLOWAY SINCLAIR  TESTAMENTARY"
replace grantor = "THE BENNIE CLANTON SINCLAIR" if grantor == "THE BENNIE CLANTON SINCLAIRTESTAMENTARY"
replace grantor = "STEVEN L HARDEE" if grantor == "STEVEN LLOYD HARDEE"
replace grantor = "CECIL ARAN GAMBLE" if grantor == "CECIL ARLAN GAMBLE"
replace grantor = "THE BERT KOUNS" if grantor == "7540 BERT KOUNS"
replace grantor = "BERNICE LEWIS COLLINS" if grantor == "BENNIE LEWIS COLLINS"
replace grantor = "SHIRLEY TYLER" if grantor == "SHIRLEY R TYLER"
replace grantor = "MARTHA A GRIGG HANKINS" if grantor == "MARTHA ANN QUARLES GRIGG HANKINS"
replace grantor = "DONNIE WAYNE ARNOLD" if grantor == "DONNIE WAYNE ARNOLD TESTAMENTARY"
replace grantor = "EMILANE JOYNER WATSON" if grantor == "EMILANE J WATSON"
replace grantor = "GINELLEN JOYNER HUNTER" if grantor == "GINELLEN J HUNTER"
replace grantor = "RICHARD K PITMAN" if grantor == "RICHARD KEITH PITMAN"
replace grantor = "MATTIE BRADFORD GOSS" if grantor == "MATTIE A BRADFORD"
replace grantor = "WEYERHAUSER CO" if grantor == "WEYERHAEUSER CO" | grantor == "WEYERHAUSER NR COMPANY" | grantor == "WEYERHAUSER NR CO"
replace grantor = "FREDA KEEN THORNTON" if grantor == "FREDA KEEN"
replace grantor = "BARRIE E HAYNE" if grantor == "BARRIE E HAYNIE"
replace grantor = "SCOTT E TAYLOR" if grantor == "SCOTT ELBERT TAYLOR"
replace grantor = "HARVEY CLAUDE ALLUMS" if grantor == "HARVEY CALUDE ALLUMS"
replace grantor = "JOSEPHINE PATRICIA BURKHALTER PENDLETON" if grantor == "JOSEPHINE PATRICIA BURKHALTER PENDELTON"
replace grantor = "MARTHA ANN GOFF GREEN" if grantor == "MARTHA ANN GREEN"
replace grantor = "RUTH LANE POLLOCK DUPRE" if grantor == "RUTH LANE DUPRE"


drop if grantor_OGco==1
drop grantor_OGco
drop if cluster_exprdate-instdate<10


* Saves file
save "${leasedir}/louisiana_leases_DI_csvs_cleaned.dta", replace
capture log close
clear all
