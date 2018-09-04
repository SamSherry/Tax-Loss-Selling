/* Created: 15/8/2018
Last updated: 15/8/2018
Project: Tax-loss selling in Australia
For use with: ASX End of Day (EOD) database

Programming environment: STATA

Version: 14.1

Author: Sam Sherry

Objective: Import AEOD data into STATA, and calculate abnormal volume and PTS measures*/

/*Settings*/
pwd
cd "\\utsfs5.adsroot.uts.edu.au\home14$\12219352\My Documents\stata\working\"

/* Download AEOD data from SIRCA Databricks*/

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
keep aeodnum asxcode year month monthlyvol

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
sort month aeodnum
save monthlyvol, replace

/* Calculate market volume and market turnover for abnormal volume measures*/
/* Calculate daily market volume*/
clear all
cd "\\utsfs5.adsroot.uts.edu.au\home14$\12219352\My Documents\stata\working\"
use "pri_15_6.dta", clear
sort date aeodnum
bysort date: egen dailyvol_mkt = total(volume)
duplicates report date
duplicates drop date, force
keep month date dailyvol_mkt

/* Calculate monthly market volume*/
sort month date
bysort month: egen monthlyvol_mkt = total(dailyvol_mkt)
duplicates report month
duplicates drop month, force
drop date
rename monthlyvol_mkt mktvol
sort month 
tsset month
gen mktvol_ma = (L12.mktvol + L11.mktvol + L10.mktvol + L9.mktvol + L8.mktvol + L7.mktvol + L6.mktvol + L5.mktvol + L4.mktvol + L3.mktvol + L2.mktvol + L.mktvol)/12 
gen relvol_mkt = mktvol/mktvol_ma
sort month
save monthlyvol_mkt, replace

/* Merge market volume data with monthly volume data*/
use monthlyvol, clear
sort month aeodnum
save monthlyvol, replace

use monthlyvol_mkt, clear
sort month
save monthlyvol_mkt, replace
merge 1:m month using monthlyvol

/* Tidy up dataset and drop unnecessary variables*/
drop if _merge==1
drop dailyvol_mkt mktvol mktvol_ma vol vol_ma _merge
order aeodnum asxcode year month relvol relvol_mkt
sort aeodnum month

/* Calculate abnormal volume*/
regress relvol relvol_mkt
predict p_vol
gen abn_vol = relvol - p_vol
summarize abn_vol
save abnormal_volume, replace

/* TO DO - Calculate turnover measures*/

/* TO DO - Adjust prices for dilutions e.g. stock splits, capital adjustments*/

/* Calculate PTS measures*/
clear all
cd "\\utsfs5.adsroot.uts.edu.au\home14$\12219352\My Documents\stata\working\"
use "pri_15_6.dta", clear

/* Declare data to be panel, with panel variable aeodnum, daily time series;
Fill in gaps in the time series
(Note: tsfill will likely result in a large file, as there will be many
more observations. However, we aren't going to keep the output, as tsfill
is only used as an intermediate step in calculating the PTS measures - the
resulting dataset can be discarded after)*/
sort aeodnum date
xtset aeodnum date
tsfill

/* Replace missing values inserted by tsfill*/
foreach i of varlist aeodnum{
drop year month
gen year = year(date), after(date)
gen month = mofd(date), after(year)
format %tm month
drop taxyear
gen taxyear = year, after(year)
replace taxyear = year + 1 if month(date)>6
replace last = L.last if last == .
}

/* Create identifier variable to identify each firm-year*/
tostring aeodnum taxyear, generate(aeod_string taxyear_string)
generate id = aeod_string + "_" + taxyear_string, after(aeodnum)
sort id date
drop aeod_string taxyear_string

/* Generate observation number variables:
n1 = the observation number within each panel;
n2 = the total number of observations in the panel;
n3 = the observation number within each firm-year;
n4 = the total number of observations for that firm-year. 
(One panel = one company)*/
sort aeodnum date
by aeodnum: generate n1 = _n
by aeodnum: generate n2 = _N
order aeodnum asxcode n1 n2

sort id date
by id: generate n3 = _n
by id: generate n4 = _N

order aeodnum asxcode n1 n2 id n3 n4

/* Drop surplus variables and observations*/
drop asxcode volume value listedshares dilfactornodiv dilutionfactor dilutionfactorcode numberofdilution divdilutioncode divdilution coraxdilutioncode coraxdilution 

/* Save as temp dataset - can delete later*/
sort aeodnum taxyear
save prices_temp, replace

/* Calculate PTS measure*/
/* Extract beginning of period prices*/
foreach i of varlist aeodnum{
gen begprice1=last if month(date)==7 & day(date)==1 /* July 1 Price*/
gen begprice2=last if n3==1 /* Alternative specification of begprice - optional*/
}
keep aeodnum taxyear begprice1 begprice2
drop if begprice1==. & begprice2==.
sort aeodnum taxyear
save begprices, replace

drop begprice2
drop if begprice1==.
rename begprice1 begprice
sort aeodnum taxyear
save begprice1, replace

/* Extract maximum price for PTSMAX measure*/
clear all
use prices_temp
sort id date
by id: egen maxprice=max(last)
drop if maxprice==.
keep aeodnum taxyear maxprice
sort aeodnum taxyear
duplicates drop aeodnum taxyear, force
save maxprices, replace

/* Merge beginning of period prices with main dataset*/
clear all
use begprice1
merge 1:m aeodnum taxyear using prices_temp
keep if _merge==3 /*Keep matched observations*/
drop _merge

/* Calculate PTS = May 31 price divided by July 1 price*/
gen pts=last/begprice
keep if month(date)==5 & day(date)==31
keep aeodnum taxyear pts
drop if pts==.
save pts, replace

/* PTSMAX = May 31 price divided by highest close between July 1 and May 31*/
clear all
use maxprices
merge 1:m aeodnum taxyear using prices_temp
keep if _merge==3
drop _merge
gen ptsmax = last/maxprice
drop if ptsmax==.
summarize ptsmax
keep if month(date)==5 & day(date)==31
keep aeodnum taxyear ptsmax
save ptsmax, replace

/* Calculate turn of year returns*/
clear all
use prices_temp
sort aeodnum date
xtset aeodnum date
foreach i of varlist aeodnum{
gen prel = last/L.last
gen prel_5day = last/L5.last
}

/* Return for first five days in July*/
keep if month(date)==7 & day(date)==5
drop if prel_5day==.
keep aeodnum taxyear prel_5day
sort aeodnum taxyear
save July_5day, replace

/* Return for last five days in June*/
clear all
use prices_temp
sort aeodnum date
xtset aeodnum date
foreach i of varlist aeodnum{
gen prel = last/L.last
gen prel_5day = last/L5.last
}
keep if month(date)==6 & day(date)==30
drop if prel_5day==.
keep aeodnum taxyear prel_5day
sort aeodnum taxyear
save June_5day, replace
