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

/* STILL TO DO - Calculate PTS measures */
clear all
cd "\\utsfs5.adsroot.uts.edu.au\home14$\12219352\My Documents\stata\working\"
use "pri_15_6.dta", clear
