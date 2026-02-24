/*==============================================================================
  Program   : 02_efficacy_analysis.sas
  Study     : STUDY01 - Oncology Phase II POC
  Purpose   : Efficacy analysis including:
                - Objective Response Rate (ORR) by treatment arm
                - Best percent change waterfall plot
                - Summary of Overall Survival by treatment arm
                - Kaplan-Meier survival summary statistics

  Prerequisite: Run 01_data_preparation.sas first (WORK.ADSL, WORK.TR)
  Altair SLC / Domino POC - Efficacy Analysis Step
==============================================================================*/

options nodate nonumber ls=180 ps=65 mprint;
title "STUDY01 - Oncology POC: Efficacy Analysis";

/* -----------------------------------------------------------------------
   Table 1: Patient Disposition and Demographics by Treatment Arm
   ----------------------------------------------------------------------- */
title2 "Table 1: Demographic Summary by Treatment Arm";

proc tabulate data=WORK.ADSL format=8.1;
  class TRTARM SEX AGEGR1 RACE ECOG / preloadfmt;
  var AGE;
  table
    (SEX AGEGR1 ECOG),
    TRTARM * N
    /  box="Characteristic" rts=35;
  table
    AGE,
    TRTARM * (N MEAN STD MEDIAN MIN MAX)
    / box="Age (years)" rts=35;
  keylabel N    = "n"
           MEAN = "Mean"
           STD  = "SD"
           MEDIAN = "Median"
           MIN  = "Min"
           MAX  = "Max";
run;

/* -----------------------------------------------------------------------
   Table 2: Best Overall Response (RECIST 1.1) by Treatment Arm
   ----------------------------------------------------------------------- */
title2 "Table 2: Best Overall Response by Treatment Arm (RECIST 1.1)";

proc freq data=WORK.ADSL;
  tables TRTARM * BOR / nocum nopercent chisq;
  format BOR $10.;
run;

/* ORR = CR + PR */
data WORK.ORR_CALC;
  set WORK.ADSL;
  RESP_N = (RESP_FL = "Y"); /* 1 if responder */
run;

proc means data=WORK.ORR_CALC n sum mean lclm uclm maxdec=4;
  class TRTARM;
  var RESP_N;
  output out=WORK.ORR_STAT (drop=_TYPE_ _FREQ_)
         n=N sum=N_RESP mean=ORR lclm=ORR_LCL uclm=ORR_UCL;
  title3 "Objective Response Rate (ORR) with 95% Confidence Interval";
run;

data WORK.ORR_DISPLAY;
  set WORK.ORR_STAT;
  ORR_PCT    = round(ORR * 100, 0.1);
  ORR_LCL_PCT = round(ORR_LCL * 100, 0.1);
  ORR_UCL_PCT = round(ORR_UCL * 100, 0.1);
  label
    TRTARM    = "Treatment Arm"
    N         = "Evaluable Patients"
    N_RESP    = "Responders (CR+PR)"
    ORR_PCT   = "ORR (%)"
    ORR_LCL_PCT = "95% CI Lower (%)"
    ORR_UCL_PCT = "95% CI Upper (%)";
run;

proc print data=WORK.ORR_DISPLAY noobs label;
  title3 "Objective Response Rate Summary";
  var TRTARM N N_RESP ORR_PCT ORR_LCL_PCT ORR_UCL_PCT;
  format ORR_PCT ORR_LCL_PCT ORR_UCL_PCT 5.1;
run;

/* -----------------------------------------------------------------------
   Figure 1: Waterfall Plot of Best % Change from Baseline
   ----------------------------------------------------------------------- */
title2 "Figure 1: Best % Change from Baseline by Subject (Waterfall)";

/* Sort by treatment arm then by percent change (ascending) */
proc sort data=WORK.ADSL out=WORK.WATERFALL;
  by TRTARM BESTPCHG;
run;

/* Add a sequential subject rank within arm */
data WORK.WATERFALL;
  set WORK.WATERFALL;
  by TRTARM;
  if first.TRTARM then SUBJ_RANK = 0;
  SUBJ_RANK + 1;
run;

/* Bar chart using SGPANEL */
ods graphics on / width=12in height=6in;

proc sgpanel data=WORK.WATERFALL;
  panelby TRTARM / layout=rowlattice novarname;
  vbar SUBJ_RANK / response=BESTPCHG
                   fill
                   fillattrs=(transparency=0.2)
                   colorresponse=BESTPCHG
                   colorstat=mean
                   tip=(USUBJID BESTPCHG BOR);
  refline -30 / axis=y lineattrs=(color=green pattern=dash) label="-30% (PR)";
  refline  20 / axis=y lineattrs=(color=red   pattern=dash) label="+20% (PD)";
  rowaxis label="Best % Change from Baseline" values=(-100 to 50 by 25);
  colaxis label="Subject (ranked within arm)" display=(nolabel novalues noticks);
  title2 "Waterfall Plot: Best % Change from Baseline by Treatment Arm";
  footnote "Dashed lines denote RECIST 1.1 thresholds: -30% (Partial Response), +20% (Progressive Disease)";
run;

ods graphics off;

/* -----------------------------------------------------------------------
   Table 3: Overall Survival Summary by Treatment Arm
   ----------------------------------------------------------------------- */
title2 "Table 3: Overall Survival Summary by Treatment Arm";

proc means data=WORK.ADSL n nmiss mean std median min max maxdec=1;
  class TRTARM;
  var OS_DAYS;
  label OS_DAYS = "Overall Survival (days)";
  title3 "Descriptive Summary of Overall Survival Duration";
run;

/* Count events and censored by arm */
proc freq data=WORK.ADSL;
  tables TRTARM * OS_CNSR / nocum nopercent;
  format OS_CNSR CNSRFMT.;
  title3 "Overall Survival Events vs Censored by Treatment Arm";
run;

/* Format for censoring */
proc format;
  value CNSRFMT
    0 = "Event (Death)"
    1 = "Censored";
run;

proc freq data=WORK.ADSL;
  tables TRTARM * OS_CNSR / nocum nopercent;
  format OS_CNSR CNSRFMT.;
  title3 "Overall Survival Events vs Censored by Treatment Arm";
run;

/* -----------------------------------------------------------------------
   Kaplan-Meier Survival Estimate (Overall Survival)
   ----------------------------------------------------------------------- */
title2 "Figure 2: Kaplan-Meier Overall Survival Curves by Treatment Arm";

ods graphics on / width=10in height=6in;

proc lifetest data=WORK.ADSL
              method=km
              plots=survival(atrisk nocensor cl)
              outsurv=WORK.KM_SURV;
  time OS_DAYS * OS_CNSR(1); /* 1 = censored */
  strata TRTARM;
  title3 "Kaplan-Meier Overall Survival by Treatment Arm";
  footnote "OS_CNSR: 0=Death (event), 1=Censored. Data are synthetic for demonstration.";
run;

ods graphics off;

/* Median OS from KM output */
proc means data=WORK.KM_SURV noprint;
  where SURVIVAL >= 0.5;
  class TRTARM;
  var OS_DAYS;
  output out=WORK.MEDIAN_OS (drop=_TYPE_ _FREQ_) max=APPROX_MEDIAN_OS;
run;

proc print data=WORK.MEDIAN_OS noobs label;
  title2 "Table 4: Approximate Median Overall Survival by Treatment Arm";
  var TRTARM APPROX_MEDIAN_OS;
  label APPROX_MEDIAN_OS = "Approx. Median OS (days)";
  format APPROX_MEDIAN_OS 6.1;
run;

/* -----------------------------------------------------------------------
   Table 5: Responders vs Non-Responders - OS Comparison
   ----------------------------------------------------------------------- */
title2 "Table 5: OS Duration - Responders vs Non-Responders";

proc means data=WORK.ADSL n mean std median min max maxdec=1;
  where RESP_FL in ("Y","N");
  class RESP_FL;
  var OS_DAYS;
  label RESP_FL  = "Responder (CR/PR)"
        OS_DAYS  = "OS Duration (days)";
run;

title;
footnote;
%put NOTE: === Efficacy Analysis Complete ===;
