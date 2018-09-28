* Set working directory *
cd "C:\Users\11998604\Documents\STATA VARIABLES\Data sheets"
clear all

**CREATE ALTERNATIVE AVI MEASURE USING BEAVER (1968)**
use "C:\Users\11998604\Documents\STATA VARIABLES\Data sheets\13. ALL DATA - CLEANSED (3) TIME SERIES.dta"

* Create new variable to indicate month of the year*/
gen mofy=month(date), after(month)

* Calculate percentage of shares traded on each day for each firm*/
gen vol_nosh = vol/nosh
save "C:\Users\11998604\Documents\STATA VARIABLES\Data sheets\AVI\2. CREATE VOL_NOSH VARIABLE TIME SERIES.dta"

* Calculate monthly average of the daily percentage of shares traded*/
bysort newcode year month: egen monthlyvol = mean(vol_nosh)
sort newcode year month
duplicates report newcode year month
duplicates drop newcode year month, force
keep newcode dscode year month monthlyvol nosh
summarize monthlyvol, detail

**Set time series to monthly**
sort newcode month
xtset newcode month
rename monthlyvol vol_nosh
save "C:\Users\11998604\Documents\STATA VARIABLES\Data sheets\AVI\3. VOL_NOSH MONTHLY VOLUME.dta"
clear all

**Calculate percentage of shares traded on each day for the market*/
use "C:\Users\11998604\Documents\STATA VARIABLES\Data sheets\AVI\2. CREATE VOL_NOSH VARIABLE TIME SERIES.dta"
sort date newcode
bysort date: egen dailyvol_mkt = mean(vol_nosh)
duplicates report date
duplicates drop date, force
keep month date dailyvol_mkt nosh
summarize dailyvol_mkt, detail
save "C:\Users\11998604\Documents\STATA VARIABLES\Data sheets\AVI\4. VOL_NOSH DAILY MARKET VOLUME.dta"

**Calculate monthly avereage of the daily percentage of shares traded for the market*/
sort month date
bysort month: egen monthlyvol_mkt = mean(dailyvol_mkt)
duplicates report month
duplicates drop month, force
drop date nosh dailyvol_mkt
rename monthlyvol_mkt mktvol
sort month
tsset month
save "C:\Users\11998604\Documents\STATA VARIABLES\Data sheets\AVI\5. VOL_NOSH MONTHLY MARKET VOLUME.dta"

**Merge market volume & monthly volume**
use "C:\Users\11998604\Documents\STATA VARIABLES\Data sheets\AVI\3. VOL_NOSH MONTHLY VOLUME.dta"
sort month newcode
save "C:\Users\11998604\Documents\STATA VARIABLES\Data sheets\AVI\3. VOL_NOSH MONTHLY VOLUME.dta", replace

use "C:\Users\11998604\Documents\STATA VARIABLES\Data sheets\AVI\5. VOL_NOSH MONTHLY MARKET VOLUME.dta"
sort month
save "C:\Users\11998604\Documents\STATA VARIABLES\Data sheets\AVI\5. VOL_NOSH MONTHLY MARKET VOLUME.dta", replace
merge 1:m month using "C:\Users\11998604\Documents\STATA VARIABLES\Data sheets\AVI\3. VOL_NOSH MONTHLY VOLUME.dta"

**Tidy up**
drop dailyvol_mkt nosh _merge
order newcode dscode year month vol_nosh mktvol
sort newcode month
save "C:\Users\11998604\Documents\STATA VARIABLES\Data sheets\AVI\6. VOL_NOSH MERGE MARKET VOL AND MONTHLY VOL.dta"

**Calculate abnormal volume**
regress vol_nosh mktvol
predict p_vol_nosh
gen abn_vol = vol_nosh - p_vol_nosh
summarize abn_vol, detail
save "C:\Users\11998604\Documents\STATA VARIABLES\Data sheets\AVI\7. VOL_NOSH ABNORMAL VOLUME.dta"
