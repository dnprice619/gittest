* Getting started
capture log close
log using benin_ttests, text replace
set more off
clear
* cd "/Users/henrique/Desktop/Benin Project/Benin data"
use benin_data_modified

* The bulk of the work done by this program is coded in this first loop.
* There are four main objectives:
* (1). Go through all variables in the dataset and see whether they are numeric;
* (2). If they are numeric, execute a unequal variances t-test between control,
*      coded as zero in all treatment variables, and each kind of treatment;
* (3). Counts how many tests were made, using the global macro $j as a tracker;
* (4). Store the results of interest, identified in the global macro $vals, 
*      in local macros, identified by the name of the result and the number of
*      that specific test.

global vals N_1 N_2 p_l p_u p t mu_1 mu_2
global j = 0

foreach x of varlist _all {
	capture confirm numeric variable `x'                                 /*(1)*/
	if !_rc {
		foreach t in "B" "C" "D" {
			capture noisily ttest `x', by(treat`t') uneq                 /*(2)*/
			global j = $j+1                                              /*(3)*/
			local var$j: di "`x'"
			local treat$j: di "`t'"
			foreach r of global vals {
				local `r'$j: di "`r(`r')'"                               /*(4)*/
				}
			su `x'
			local sigma$j: di "`r(Var)'"
			}
		}
	}
	
save benin_data_modified.dta, replace
clear

* Now we proceed to creating a new dataset that will contain the results of the
* tests carried out above.
* The number of observations in this dataset is the number of tests done:
set obs $j

* We proceed thus to generate the variables that will contain those values
gen variable = ""
gen treat = ""
foreach r of global vals {
		gen `r' = ""
		}
gen variance = ""

save benin_ttests_dataset, replace
clear
use benin_data_modified

* This loop does the work of organizing the data produced by the first loop onto
* the framework laid out by the steps above. For every t-test carried out, this
* loop fetches the results, stored in macros and identified by test number, and
* relays them onto the adequate variables.

forval n = 1/$j {
	clear
	use benin_ttests_dataset
	replace variable = "`var`n''" if _n==`n'
	replace treat = "`treat`n''" if _n==`n'
	foreach r of global vals {
		replace `r' = "``r'`n''" if _n==`n'
		}
	replace variance = "`sigma`n''" if _n==`n'
	save benin_ttests_dataset, replace
	}
	
* Work is done. Now to a little bit of housekeeping.
	
drop if strpos(variable, "treat")>0
encode variable, gen(variable2)
encode treat, gen(treat2)
drop variable treat
rename variable2 variable
rename treat2 treat
order variable treat
gsort variable treat


foreach x of global vals {
	destring `x', force replace
	}
	
destring variance, force replace
	
gen diff = mu_1 - mu_2
order diff, after(treat)

label variable variance "Variance of the entire original variable"
label variable diff "Difference in means between control and treatment"
label variable N_1 "Sample size of control group"
label variable N_2 "Sample size of treatment group"
label variable p_l "lower one-sided p-value"
label variable p_u "upper one-sided p-value"
label variable p "two-sided p-value"
label variable t "t statistic"
label variable mu_1 "mean for control group"
label variable mu_2 "mean for treatment group"

save 2016_04_benin_ttests, replace

**************************************************************************************
* Now we move on to use the variance of the variables in the dataset and the         *
* shift in means calculated so far to calculate the maximum standard errors of       *
* the impact estimate and the minimum detectable effect for different sample sizes   *
**************************************************************************************

* This first loop has the objective of calculating the maximum standard errors of the
* impact estimators. Its fundamental assumption is that the difference in means observed
* is the "real" treatment effect, and we want to know what are the maximum standard errors
* that would enable us to detect this effect in different situations.
	
forval n=1/18 {
	clear
	import delim using stderrors
	local type`n'= v1[`n']                /* these three macros store the type of the*/
	local std`n' = v2[`n']                /* test (one-sided or two-sided, power level*/
	local varlab`n' = v3[`n']             /* significance level etc), the value of*/
	clear                                 /* t_{(1-\kappa)}+t_{\alpha} for each type of*/
	use 2016_04_benin_ttests              /* test, and a variable label for each of them*/
	*
	* The following line does the important work in this loop, it shows how the 
	* calculation was made for each standard error of impact estimator:
	gen `type`n'' = abs(diff)/`std`n''
	**********************************
	*
	label variable `type`n'' "`varlab`n''"
	#delimit ;
	notes `type`n'': "This variable brings the maximum standard error of the
	impact estimate in order to detect a shift in means with the value denoted
	in the variable "diff" for every specific variable and treatment if the test
	is `varlab`n''. Values of t_{(1-\kappa)} and t_{\alpha} were taken from 
	Howard S. Bloom (1995). 'Minimum Detectable Effects: A Simple Way to Report
	the Statistical Power of Experimental Designs'. Evaluation Review, Vol. 19
	No. 5";
	#delimit cr
	save 2016_04_benin_ttests, replace
	}
	
* This second loop has the objective of calculating the minimum detectable effect
* according to some different sample sizes, based on each variable's variance. 


forval n=1/18 {
* The following foreach specification determines how many and what are the sizes
* of the sample sizes that the MDE's will be calculated upon
	foreach m in 10 15 20 25 {
	*
	* The following line does the important work in this loop, it shows how the 
	* minimum detectable effect was calculated for every variable:
	gen MDE_`type`n''_ss`m' = `std`n''*2*sqrt(variance/`m')
	*******************************************************
	*
	label variable MDE_`type`n''_ss`m' "MDE for `varlab`n'', sample size `m'"
	#delimit;
	notes MDE_`type`n''_ss`m': "This variable brings the minimum detectable effect
	for each numeric variable in the Benin dataset with the following parameters:
	`varlab`n'' and sample size of`m'. The MDE was calculated according to the 
	expression laid out in Duflo, Glennerster and Kremer's 	"Toolkit", pg. 29, 
	expression (7). The toolkit is available at economics.mit.edu/files/806";
	#delimit cr
	}
}	
	
save 2016_04_benin_ttests_MDE, replace
	
log close
