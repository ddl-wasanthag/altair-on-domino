/*==============================================================================
  Output      : Figure 14.2.1
  Title       : Kaplan-Meier Plot of Overall Survival by Treatment Arm
  Population  : Full Analysis Set
  Program     : f_14_2_1.sas
  Prerequisite: 01_data_preparation.sas, tfl_macros.sas

  Description:
    Kaplan-Meier overall survival curves by treatment arm using PROC LIFETEST.
    Includes:
      - Step-function survival curves with 95% Hall-Wellner confidence bands
      - At-risk table below the plot (standard in oncology publications)
      - Log-rank p-value
      - Median OS with 95% CI in the figure legend area
      - Censoring tick marks on the curves
==============================================================================*/

%tfl_setup_metadata;

/* -----------------------------------------------------------------------
   Derive OS in months (more readable on figures than days)
   ----------------------------------------------------------------------- */
data WORK._os_plot;
  set WORK.ADSL;
  OS_MONTHS = round(OS_DAYS / 30.4375, 0.1);
  label OS_MONTHS = "Overall Survival (months)";
run;

/* -----------------------------------------------------------------------
   Get median OS by arm for legend annotation — suppress from report output
   Use outsurv= to capture survival estimates, then derive median manually.
   ----------------------------------------------------------------------- */
ods exclude all;
proc lifetest data=WORK._os_plot method=km
              outsurv=WORK._km_surv_med;
  time OS_MONTHS * OS_CNSR(1);
  strata TRTARM;
run;
ods exclude none;

/* Derive median OS: last time point where Survival >= 0.5 per arm */
proc sql noprint;
  select put(max(OS_MONTHS), 5.1)
  into :_med_a trimmed
  from WORK._km_surv_med
  where TRTARM="TRTMT A" and SURVIVAL >= 0.5;

  select put(max(OS_MONTHS), 5.1)
  into :_med_b trimmed
  from WORK._km_surv_med
  where TRTARM="TRTMT B" and SURVIVAL >= 0.5;
quit;

%let _med_a = %sysfunc(coalescec(&_med_a., NR)); /* NR = Not Reached */
%let _med_b = %sysfunc(coalescec(&_med_b., NR));

/* -----------------------------------------------------------------------
   Figure 14.2.1 — KM Plot with at-risk table
   ----------------------------------------------------------------------- */
%tfl_title(
  tblnum = Figure 14.2.1,
  t1     = Kaplan-Meier Plot of Overall Survival by Treatment Arm,
  pop    = Full Analysis Set (TRTMT A: N=&_N_A.  |  TRTMT B: N=&_N_B.)
);

%tfl_footnote(
  pgmname = f_14_2_1.sas,
  extra1  = %str(OS = Overall Survival. Tick marks indicate censored observations.
                        Shaded band = 95% Hall-Wellner confidence band.),
  extra2  = %str(Median OS: TRTMT A = &_med_a. months; TRTMT B = &_med_b. months.
                        P-value from log-rank test (unstratified).)
);

ods graphics on / reset=all
                  width=9in
                  height=6in
                  imagename="f_14_2_1"
                  imagefmt=png;

proc lifetest data=WORK._os_plot
              method=km
              plots=survival(atrisk)
              outsurv=WORK._km_surv_out;
  time OS_MONTHS * OS_CNSR(1);
  strata TRTARM / test=logrank;
  label OS_MONTHS = "Overall Survival (months)"
        TRTARM    = "Treatment Arm";
run;

ods graphics off;
%tfl_clear;
