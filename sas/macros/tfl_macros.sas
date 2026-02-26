/*==============================================================================
  Macro Library : tfl_macros.sas
  Study         : STUDY01 - Oncology Phase II POC
  Purpose       : Shared macro infrastructure for all TFL programs.
                  Provides standardised headers, footers, population counts,
                  and utility macros following ICH E3 / pharma conventions.

  Macros:
    %tfl_setup_metadata  - Initialise study-level global macro variables
    %tfl_title           - Set ODS-compliant title block (output number + titles)
    %tfl_footnote        - Set ODS-compliant footnote block (program + data cutoff)
    %tfl_get_n           - Derive arm-level N counts into macro variables
    %npct                - Format "n (%)" string
    %fmt_mean_sd         - Format "mean (SD)" string
    %fmt_med             - Format median (min, max) string
==============================================================================*/

/* -----------------------------------------------------------------------
   %set_language_paths
   Set environment variables required for PROC PYTHON and PROC R.
   Paths are resolved from the actual Domino compute environment:
     Python 3.10 (conda-forge) at /opt/conda
     R 4.4.1 at /usr/bin/R  (R_HOME = /usr/lib/R)
   Call this once before any PROC PYTHON or PROC R step.
   ----------------------------------------------------------------------- */
%macro set_language_paths;
  options set=PYTHONHOME "/opt/conda";
  options set=PYTHONLIB  "/opt/conda/lib/libpython3.10.so.1.0";
  options set=R_HOME     "/usr/lib/R";
  %put NOTE: [set_language_paths] PYTHONHOME = /opt/conda;
  %put NOTE: [set_language_paths] PYTHONLIB  = /opt/conda/lib/libpython3.10.so.1.0;
  %put NOTE: [set_language_paths] R_HOME     = /usr/lib/R;
%mend set_language_paths;


/* -----------------------------------------------------------------------
   %tfl_setup_metadata
   Call once per driver program to initialise global metadata variables.
   ----------------------------------------------------------------------- */
%macro tfl_setup_metadata;
  %global
    _STUDY        /* Study identifier                              */
    _PROTOCOL     /* Protocol number                              */
    _DATACUTDT    /* Data cut-off date (display string)           */
    _CONFID       /* Confidentiality statement                    */
    _PROJ_ROOT    /* Project root path                            */
    _N_A          /* N for Treatment Arm A                        */
    _N_B          /* N for Treatment Arm B                        */
    _N_TOT        /* N total                                      */
    _N_A_SAF      /* N safety population Arm A                    */
    _N_B_SAF      /* N safety population Arm B                    */
    _N_TOT_SAF    /* N safety population total                    */
  ;

  %let _STUDY     = STUDY01;
  %let _PROTOCOL  = STD01-001;
  %let _DATACUTDT = 01 Oct 2023;
  %let _CONFID    = CONFIDENTIAL - Synthetic data for demonstration purposes only;

  /* Resolve project root (Domino vs local) */
  %let _PROJ_ROOT = %sysget(DOMINO_PROJECT_ROOT);
  %if "&_PROJ_ROOT." = "" %then
    %let _PROJ_ROOT = /mnt/code;

  /* Derive population N counts from ADSL */
  %if %sysfunc(exist(WORK.ADSL)) %then %do;

    proc sql noprint;
      select count(*)           into :_N_TOT   trimmed from WORK.ADSL;
      select count(*)           into :_N_A     trimmed from WORK.ADSL where TRTARM="TRTMT A";
      select count(*)           into :_N_B     trimmed from WORK.ADSL where TRTARM="TRTMT B";
      /* Safety population = all subjects who received at least one dose
         For this POC all randomised subjects are treated, so SAF = FAS */
      select count(*)           into :_N_TOT_SAF trimmed from WORK.ADSL;
      select count(*)           into :_N_A_SAF   trimmed from WORK.ADSL where TRTARM="TRTMT A";
      select count(*)           into :_N_B_SAF   trimmed from WORK.ADSL where TRTARM="TRTMT B";
    quit;

    %put NOTE: [tfl_macros] Population N counts:;
    %put NOTE:   FAS  - TRTMT A: &_N_A.  TRTMT B: &_N_B.  Total: &_N_TOT.;
    %put NOTE:   SAF  - TRTMT A: &_N_A_SAF.  TRTMT B: &_N_B_SAF.  Total: &_N_TOT_SAF.;

  %end;
  %else %do;
    %put WARNING: [tfl_macros] WORK.ADSL not found - N counts not populated.;
    %let _N_A=.; %let _N_B=.; %let _N_TOT=.;
    %let _N_A_SAF=.; %let _N_B_SAF=.; %let _N_TOT_SAF=.;
  %end;

%mend tfl_setup_metadata;


/* -----------------------------------------------------------------------
   %tfl_title(tblnum=, pop=, t1=, t2=, t3=)
   Sets up to 5 title lines in the standard pharma format:
     Line 1: Study / Protocol / Table Number (left-right aligned)
     Line 2: Primary title (t1)
     Line 3: Secondary title (t2, optional)
     Line 4: Population statement (pop)
   ----------------------------------------------------------------------- */
%macro tfl_title(tblnum=, pop=, t1=, t2=, t3=);

  %local _pop_str;
  %let _pop_str = &pop.;

  title1  j=left  "Study: &_STUDY."
          j=right "Protocol: &_PROTOCOL.";
  title2  j=left  "&tblnum.";
  title3  "&t1.";
  %if %length(&t2.) > 0 %then %do;
    title4  "&t2.";
    %if %length(&t3.) > 0 %then %do;
      title5  "&t3.";
      title6  "&_pop_str.";
    %end;
    %else %do;
      title5  "&_pop_str.";
    %end;
  %end;
  %else %do;
    title4  "&_pop_str.";
  %end;

%mend tfl_title;


/* -----------------------------------------------------------------------
   %tfl_footnote(pgmname=, extra1=, extra2=)
   Sets standard footer lines:
     Line 1: extra1 (optional - e.g. abbreviation key)
     Line 2: extra2 (optional)
     Line 3: Data cut-off and program path
     Line 4: Confidentiality statement + page
   ----------------------------------------------------------------------- */
%macro tfl_footnote(pgmname=, extra1=, extra2=);

  %local _pgmpath _runtime;
  %let _pgmpath = &_PROJ_ROOT./sas/&pgmname.;
  %let _runtime = %sysfunc(datetime(), datetime20.);

  footnote1 " "; /* blank separator */
  %if %length(&extra1.) > 0 %then %do;
    footnote2 j=left "&extra1.";
    %if %length(&extra2.) > 0 %then %do;
      footnote3 j=left "&extra2.";
      footnote4 j=left "Data cut-off: &_DATACUTDT.   Program: &_pgmpath.   Run: &_runtime.";
      footnote5 j=left "&_CONFID.";
    %end;
    %else %do;
      footnote3 j=left "Data cut-off: &_DATACUTDT.   Program: &_pgmpath.   Run: &_runtime.";
      footnote4 j=left "&_CONFID.";
    %end;
  %end;
  %else %do;
    footnote2 j=left "Data cut-off: &_DATACUTDT.   Program: &_pgmpath.   Run: &_runtime.";
    footnote3 j=left "&_CONFID.";
  %end;

%mend tfl_footnote;


/* -----------------------------------------------------------------------
   %npct(n, denom)
   Returns a formatted "n (%)" string, e.g. "7 (70.0)".
   Returns "0" if n=0.
   ----------------------------------------------------------------------- */
%macro npct(n, denom);
  %local _pct;
  %if &denom. > 0 %then
    %let _pct = %sysfunc(putn(%sysevalf((&n. / &denom.) * 100), 5.1));
  %else
    %let _pct = 0.0;
  %if &n. = 0 %then 0
  %else &n. (&_pct.)
%mend npct;


/* -----------------------------------------------------------------------
   %fmt_mean_sd(mean, sd)
   Returns a formatted "mean (SD)" string.
   ----------------------------------------------------------------------- */
%macro fmt_mean_sd(mean, sd);
  %sysfunc(putn(&mean., 5.1)) (%sysfunc(putn(&sd., 4.1)))
%mend fmt_mean_sd;


/* -----------------------------------------------------------------------
   %tfl_clear
   Clears all title and footnote lines (call between TFLs).
   ----------------------------------------------------------------------- */
%macro tfl_clear;
  title;
  footnote;
%mend tfl_clear;
