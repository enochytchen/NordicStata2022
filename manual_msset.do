// Date: 20221006
// Author: Enoch Chen
// Purpose: manual msset wide data into long data
// ssc install multistate

/*==================
===Illness-death====
====================*/
// Example data from Crowther2017 
use http://fmwww.bc.edu/repec/bocode/m/multistate_example, clear

// List one patient to see the variables 
list pid rf rfi os osi if pid == 1 | pid == 1371, sepby(pid) noobs

// Transition matrix for Illness-death model 
matrix tmat = (.,1,2\ .,.,3\.,.,.)
matrix colnames tmat = to:Health to:Relapse to:Death
matrix rownames tmat = from:Health from:Relapse from:Death
matrix list tmat

// msset the data
msset, id(pid) states(rfi osi) times(rf os) transm(tmat)

list pid rf rfi os osi _trans _start _stop if pid == 1 | pid ==1371, sepby(pid) noobs

/*===============
===Reversible====
=================*/
// Example data from Crowther2017 
use http://fmwww.bc.edu/repec/bocode/m/multistate_example, clear

// Assume recovery indicator and recovery time
set seed 12345
// Recovery indicator  
gen rei = cond(runiform() < 0.5, 0 , 1)  if rfi == 1 & rf!= os
// Recovery 
gen re  = runiform(rf, os)  if rei == 1

save multistate_example_temp.dta, replace

// List one patient to see the variables 
list pid rf rfi re rei os osi if pid == 2778 , sepby(pid) noobs

// Transition matrix for reversible illness-death model 
matrix rtmat = (.,1,2\ 3,.,4\.,.,.)
matrix colnames rtmat = to:Health to:Relapse to:Death
matrix rownames rtmat = from:Health from:Relapse from:Death
matrix list rtmat

/*======================================================================
// Example of wrongly msset
preserve
	// 1st example of wrong
	msset, id(pid) states(rfi osi rei) times(rf os re) transm(rtmat)
	list pid rf rfi re rei os osi _trans _start _stop _status if pid == 2778
restore

preserve	
	// 2nd example of wrong
	msset, id(pid) states(rfi osi rei) times(rf os re)
	list pid rf rfi re rei os osi _trans _start _stop _status if pid == 2778
restore*/
//======================================================================
/*msset created the following variables:
_from           float   %9.0g  Starting state
_to             float   %9.0g  Receiving state
_status         byte    %8.0g  Event (transition) indicator
_start          double  %10.0g Starting time for each transition
_stop           double  %10.0g Stopping time for each transition
_flag           byte    %8.0g  Data modified
_trans          float   %9.0g  Transition number
_trans1         byte    %8.0g  _trans== 1.0000
_trans2         byte    %8.0g  _trans== 2.0000
_trans3         byte    %8.0g  _trans== 3.0000
*/

// Generate other variables
gen _from = .
gen _to = .
gen _start = .
gen _stop = .
gen _status = .

// Call the rtmat
matrix list rtmat

// Make 4 duplicates for each patient to define transitions
expand 4

// Mannually make msset format
bysort pid: gen _trans = _n
// Generate _episode for potential recurrent events after recovery
gen _episode = 1
expand 2 if (_tran == 1 | _tran == 2) & rei == 1, gen(du)
replace _episode = 2 if du == 1
drop du
gen _tr_epi = ""
forvalues i = 1/4{
	forvalues j = 1/2{
		replace _tr_epi = "`i'_`j'" if _trans == `i' & _epi == `j'
	}
}
// Check the duplicates were done correctly
list pid rf rfi re rei os osi _trans _episode if pid == 2778 , sepby(pid) noobs

/*========================
===== Specify _from _to===
==========================*/
matrix list rtmat

replace _from = 1 if _trans == 1 | _trans == 2  
replace _from = 2 if _trans == 3 | _trans == 4  

replace _to = 1 if _trans == 3  
replace _to = 2 if _trans == 1  
replace _to = 3 if _trans == 2 | _trans == 4  

/*===========================
===== Specify _start _stop===
=============================*/
local condition "(_trans == 1 | _trans == 2) & _episode == 1"
replace _start = 0 if `condition'               // T0 is 0
replace _stop = min(rf,os) if `condition'		// Replase, death/censoring, whichever happens first
replace _stop = 120 if _stop == . & `condition' // Censor everyone after 120 mos

local condition "(_trans == 3 | _trans == 4)"
replace _start = rf if `condition'				// T0 is time since relapse
replace _stop = min(re,os) if `condition'		// Recovery, death/censoring, whichever happens
replace _stop = 120 if _stop == . & `condition' // Censor everyone after 120 mos

local condition "(_trans == 1 | _trans == 2) & _episode == 2"
replace _start = re if `condition'			    // T0 is time since recovery
replace _stop = os if `condition'				// Death/censoring, whichever happens 
replace _stop = 120 if _stop == . & `condition' // Censor everyone after 120 mos

// Drop if any missing
// There shouldn't be any missing tho
// If there is, it means there's something wrong
list if _start == . | _stop == .

/*===========================
====== Specify _status=======
===========================*/
// _trans == 1 & _episode == 1
replace _status = 1 if _trans == 1 & _episode == 1 & /// 
					   rfi == 1 & min(rf,os) == rf   // Relapse as an event and happens first
replace _status = 0 if _trans == 1 & _episode == 1 & _status != 1 

// _trans == 2 & _episode == 1
replace _status = 1 if _trans == 2 & _episode == 1 & ///
					   osi == 1 & rfi == 0   // Death/censoring as an event and relapse never happens
replace _status = 0 if _trans == 2 & _episode == 1 & _status != 1 

// _trans == 3
replace _status = 1 if _trans == 3 & rfi == 1 & /// Relapse has happened
					   rei == 1 // Recovery as an event 
					   
replace _status = 0 if _trans == 3 & rfi == 1 & /// Relapse has happened 
					   _status != 1 

// _trans == 4
replace _status = 1 if _trans == 4 & rfi == 1 & /// Relapse has happened
					   osi == 1 & rei == 0 // Death/censoring as an event and happens first
					   
replace _status = 0 if _trans == 4 & rfi == 1 & /// Relapse has happened
					   _status != 1
					   

// _trans == 1 & _episode == 2
replace _status = 1 if _trans == 1 & _episode == 2 & ///
					   rfi == 1 & rei == 1 & /// Relapse and recovery have happened
					   min(rf,re) == re // Recovery as an event and happens first, which is impossible here.
replace _status = 0 if _trans == 1 & _episode == 2 & ///
					   rfi == 1 & rei == 1 & /// Relapse and recovery have happened
						_status != 1

// _trans == 2 & _episode == 2
replace _status = 1 if _trans == 2 & _episode == 2 & ///
					   rfi == 1 & rei == 1 & /// Relapse and recovery have happened
					   osi == 1 & min(re,os) == re // Death/censoring as an event and should have recovery as an event already 
replace _status = 0 if _trans == 2 & _episode == 2 & ///
					   rfi == 1 & rei == 1 & ///
					   _status != 1 

// Drop those who are not at risk in each transition
// There shouldn't be any missing tho
// If there is, it means there's something wrong
list pid if _status == . 

/*==================
====== Check =======
====================*/
// Double check
list pid _start _stop _from _to _status _trans if _start == . | _stop == . |  _status == . 

list pid rf rfi re rei os osi _trans _episode _start _stop _status if pid == 2778

list pid rf rfi re rei os osi _trans _epi _start _stop _status if pid == 2846

tab _tr_epi _status

// Compare with the original file
preserve
	use multistate_example_temp, clear
	tab rei
	tab rfi 
	tab osi
restore

stset _stop, enter(_start) failure(_status==1) scale(12)
bysort _trans _episode: su _t


