/* Created: 18/5/2018
Last updated: 15/8/2018
Used for: Tax-loss selling in Australia using ASX End of Day (EOD) database

STATA version: 14.1

Author: Sam Sherry

Objective: Import AEOD data into STATA, and calculate abnormal volume and PTS measures*/

/*Settings*/
pwd
cd "\\utsfs5.adsroot.uts.edu.au\home14$\12219352\My Documents\stata\working\"

/* Download AEOD data from SIRCA Databricks - refer to code on GitHub to do this*/

/* Import AEOD data into STATA once in the working directory*/
clear all
import delimited "pri_15_6.csv"

/*Generate date variable*/
gen datevar = date(date,"YMD"), after(date) 
format %td datevar

/* Generate year and month variables*/
gen year = year(datevar), after(datevar)
gen month = mofd(datevar), after(year)
drop date
rename datevar date
format %tm month

/* Generate tax year variable - only needed for non-December 31 year end*/
gen taxyear = year, after(year)
replace taxyear = year + 1 if month(date)>6

/* Drop NEW shares - these are often listed following an entitlement issue, e.g.
a renounceable issue, and usually become FPO shares after a certain date*/
drop if aeodnum > 1000000

/* Check for duplicate observations (i.e. with more than one observation for 
a given firm on the same trading day)*/
sort aeodnum date
duplicates report aeodnum date

/* Drop duplicates (if any)*/
duplicates drop aeodnum date, force

/* Drop observations where the dilution factor is negative,
as this value is used by SIRCA to indicate ex-price events where a 
dilution factor cannot be calculated as the stock did not trade
at all after the event*/
summarize dilutionfactor
drop if dilutionfactor < 0

/* Set time series*/
sort aeodnum date
xtset aeodnum date

/* Monthly volume*/
bysort aeodnum year month: egen monthlyvol = total(volume)
sort aeodnum year month
duplicates report aeodnum year month
duplicates drop aeodnum year month, force
keep aeodnum asxcode year month taxyear listedshares monthlyvol

/* Set time series to monthly*/
sort aeodnum month
xtset aeodnum month
rename monthlyvol vol

/* 12 month rolling average*/
foreach i of varlist aeodnum {
gen vol_ma = (L12.vol + L11.vol + L10.vol + L9.vol + L8.vol + L7.vol + L6.vol + L5.vol + L4.vol + L3.vol + L2.vol + L.vol)/12 
gen relvol = vol/vol_ma
drop if vol_ma == .
}

/* TO DO - Calculate market volume and market turnover for abnormal volume measures*/

/* TO DO - Market volume - refer to SQL code to extract data from AEOD database on 
SIRCA Databricks*/

/* TO DO - Market turnover*/

/* TO DO - Calculating adjusted prices and volumes using dilution factors supplied by SIRCA - INCOMPLETE
Tabulate dilution factor codes*/
tab numberofdilution dilutionfactorcode
tab numberofdilution divdilutioncode
tab numberofdilution coraxdilutioncode
tab dilutionfactorcode divdilutioncode
tab dilutionfactorcode coraxdilutioncode

/* Create dilution factor variable ignoring dividends, and check 
that it created the variable correctly*/

/* Step 1 - days with 1 dilution*/
sort aeodnum date
gen dilfactornodiv=dilutionfactor, before(dilutionfactor)
replace dilfactornodiv=1 if dilutionfactorcode=="D" | dilutionfactorcode=="U"
tab dilfactornodiv dilutionfactorcode if dilfactornodiv==1

/* Step 2 - days with more than 1 dilution*/
/* Part 2a - first dilution is a dividend, no second dilution*/
replace dilfactornodiv=1 if dilutionfactorcode=="Z" & divdilutioncode=="D" & coraxdilution==.
replace dilfactornodiv=1 if dilutionfactorcode=="Z" & divdilutioncode=="DU" & coraxdilution==.
replace dilfactornodiv=1 if dilutionfactorcode=="Z" & divdilutioncode=="U" & coraxdilution==.

/* Part 2b - first dilution is a dividend, second dilution is another corporate action*/
replace dilfactornodiv=coraxdilution if dilutionfactorcode=="Z" & divdilutioncode=="D" & coraxdilution!=. & coraxdilutioncode!="U"
replace dilfactornodiv=coraxdilution if dilutionfactorcode=="Z" & divdilutioncode=="DU" & coraxdilution!=. & coraxdilutioncode!="U"
replace dilfactornodiv=coraxdilution if dilutionfactorcode=="Z" & divdilutioncode=="U" & coraxdilution!=. & coraxdilutioncode!="U"

/* Part 2c - first and second dilutions are both dividends*/
replace dilfactornodiv=1 if dilutionfactorcode=="Z" & divdilutioncode=="D" & coraxdilutioncode=="U"
replace dilfactornodiv=1 if dilutionfactorcode=="Z" & divdilutioncode=="DU" & coraxdilutioncode=="U"
replace dilfactornodiv=1 if dilutionfactorcode=="Z" & divdilutioncode=="U" & coraxdilutioncode=="U"

/* Check that the code above dealt with all possible permutations*/
browse if dilutionfactorcode=="Z"

/* Save data set*/
cd "\\utsfs5.adsroot.uts.edu.au\home14$\12219352\My Documents\stata\working\"
save pri_15_6, replace

/* Declare dataset to be panel data with panel identifier aeodnum and ordered by date*/
sort aeodnum date
xtset aeodnum date

/* Calculate cumulative adjustment factors and adjust prices*/
gen cumdilfactor = dilfactornodiv, after(value)
replace cumdilfactor = dilfactornodiv*L.cumdilfactor

RETAIN CUMDILFACTOR;
	IF FIRST.GRPCODE = 1 AND NODILS = 0 THEN CUMDILFACTOR = 1;
		ELSE IF FIRST.GRPCODE = 1 AND DILCODE = 'D' THEN CUMDILFACTOR = 1;
		ELSE IF FIRST.GRPCODE = 1 AND NODILS > 0 AND DILCODE NE 'D' AND DILCODE NE 'Z' THEN
		CUMDILFACTOR = DILFACTOR;
		ELSE IF FIRST.GRPCODE = 1 AND DILCODE = 'Z' AND DILCODE1 = 'D' THEN
		CUMDILFACTOR = FACTOR2;
		ELSE IF FIRST.GRPCODE = 1 AND DILCODE = 'Z' AND DILCODE2 = 'D' THEN
		CUMDILFACTOR = FACTOR1;
		ELSE IF FIRST.GRPCODE = 1 AND DILCODE = 'Z' AND DILCODE1 NE 'D' AND DILCODE2 NE 'D' THEN
		CUMDILFACTOR = DILFACTOR;
		ELSE IF NODILS = 0 OR DILCODE = 'D' THEN CUMDILFACTOR = CUMDILFACTOR;
		ELSE IF NODILS > 0 AND DILCODE NE 'D' AND DILCODE NE 'Z' THEN 
		CUMDILFACTOR = CUMDILFACTOR * DILFACTOR;
		ELSE IF DILCODE = 'Z' AND DILCODE1 = 'D' THEN CUMDILFACTOR = CUMDILFACTOR * FACTOR2;
		ELSE IF DILCODE = 'Z' AND DILCODE2 = 'D' THEN CUMDILFACTOR = CUMDILFACTOR * FACTOR1;
		ELSE IF DILCODE = 'Z' AND DILCODE1 NE 'D' AND DILCODE2 NE 'D' THEN
		CUMDILFACTOR = CUMDILFACTOR * DILFACTOR;
	ADJPRICE = CLOSE / CUMDILFACTOR;

* Calculate cumulative adjustment factors and adjust prices and volumes for the purposes of 
* estimating beta, where dividends are taken into account;

DATA dilutions_beta_az;
SET nodup_az;
BY GRPCODE;
RETAIN CUMDILFACTOR;
	IF FIRST.GRPCODE = 1 AND NODILS = 0 THEN CUMDILFACTOR = 1;
		ELSE IF FIRST.GRPCODE = 1 AND NODILS > 0 THEN CUMDILFACTOR = DILFACTOR;
		ELSE IF FIRST.GRPCODE = 0 AND NODILS = 0 THEN CUMDILFACTOR = CUMDILFACTOR;
		ELSE IF FIRST.GRPCODE = 0 AND NODILS > 0 THEN CUMDILFACTOR = CUMDILFACTOR * DILFACTOR;
	ADJPRICE = CLOSE / CUMDILFACTOR;
RUN;

save pri_15_6, replace
