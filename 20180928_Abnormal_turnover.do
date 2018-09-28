/* Created: 28/09/2018
Last updated: 28/09/2018
Project: Tax-loss selling in Australia
For use with: ASX End of Day (EOD) database
Programming environment: STATA
Version: 15.1
Author: Sam Sherry
Objective: Calculate abnormal volume based on the daily percentage of shares traded*/

/* Load dataset*/
clear all
cd "\\utsfs5.adsroot.uts.edu.au\home14$\12219352\My Documents\stata\working\"
use "pri_15_6.dta", clear

/* Create new variable to indicate month of the year*/
gen mofy=month(date), after(month)

/* Calculate percentage of shares traded on each day for each firm*/
gen vol_nosh = volume/listedshares /* (nosh = number of shares outstanding) */

/* Calculate monthly average of the daily percentage of shares traded*/
bysort aeodnum year month: egen monthlyvol = mean(vol_nosh)
sort aeodnum year month
duplicates report aeodnum year month
duplicates drop aeodnum year month, force
keep aeodnum asxcode year month monthlyvol listedshares
summarize monthlyvol, detail

/* Set time series to monthly */
sort aeodnum month
xtset aeodnum month
rename monthlyvol vol_nosh
save monthly_turnover, replace

/* Calculate percentage of shares traded on each day for the market*/
use pri_15_6, clear
sort date aeodnum
gen vol_nosh = volume/listedshares
bysort date: egen dailyvol_mkt = mean(vol_nosh)
duplicates report date
duplicates drop date, force
keep month date dailyvol_mkt listedshares
summarize dailyvol_mkt, detail
save dailyvol_mkt, replace

/* Calculate monthly average of the daily percentage of shares traded for the market*/
sort month date
bysort month: egen monthlyvol_mkt = mean(dailyvol_mkt)
duplicates report month
duplicates drop month, force
drop date listedshares dailyvol_mkt
rename monthlyvol_mkt mktvol
sort month
tsset month
save monthlyvol_mkt, replace

/* Merge market volume & monthly volume */
use monthly_turnover, clear
sort month aeodnum
save monthly_turnover, replace

use monthlyvol_mkt, clear
sort month
save monthlyvol_mkt, replace
merge 1:m month using monthly_turnover

/* Tidy up */
drop listedshares _merge
order aeodnum asxcode year month vol_nosh mktvol
sort aeodnum month
save monthly_turnover, replace

/*Calculate abnormal volume*/
regress vol_nosh mktvol
predict p_vol_nosh
gen abn_vol = vol_nosh - p_vol_nosh
summarize abn_vol, detail
save abnormal_turnover, replace
