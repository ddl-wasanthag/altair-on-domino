/*==============================================================================
  Program   : 01_data_preparation.sas
  Study     : STUDY01 - Oncology Phase II POC
  Purpose   : Read synthetic oncology data from Domino dataset and prepare
              analysis-ready datasets. Demonstrates reading CSV data from the
              Domino dataset mount path.

  Domino Dataset Path: /domino/datasets/local/oncology_poc/
  Altair SLC / Domino POC - Data Preparation Step

  Inputs    : patients.csv, tumor_measurements.csv, adverse_events.csv
  Outputs   : WORK.DM (Demographics), WORK.TR (Tumor Response),
              WORK.AE (Adverse Events), WORK.ADSL (Subject-Level Analysis)
==============================================================================*/

options nodate nonumber ls=180 ps=65 mprint symbolgen;
title "STUDY01 - Oncology POC: Data Preparation";

/* -----------------------------------------------------------------------
   MACRO: Resolve Domino dataset path.
   Checks mount paths in priority order:
     1. /mnt/data/<dataset_name>/       <- Domino dataset (current environment)
     2. /domino/datasets/local/<name>/  <- Domino dataset (legacy mount path)
     3. <DOMINO_PROJECT_ROOT>/data/     <- files uploaded directly to project
     4. Local development fallback
   ----------------------------------------------------------------------- */
%macro set_data_path;
  %global DATA_PATH;
  %if %sysfunc(fileexist(/mnt/data/oncology_altair_poc/patients.csv)) %then %do;
    %let DATA_PATH = /mnt/data/oncology_altair_poc;
    %put NOTE: Running on Domino - using dataset mount path: &DATA_PATH.;
  %end;
  %else %if %sysfunc(fileexist(/domino/datasets/local/oncology_poc/patients.csv)) %then %do;
    %let DATA_PATH = /domino/datasets/local/oncology_poc;
    %put NOTE: Running on Domino (legacy path) - using: &DATA_PATH.;
  %end;
  %else %do;
    /* Fallback: data uploaded directly into the Domino project files */
    %let DATA_PATH = %sysget(DOMINO_PROJECT_ROOT)/data;
    %put NOTE: Dataset mount not found - falling back to project data folder: &DATA_PATH.;
  %end;
%mend set_data_path;

%set_data_path;

/* -----------------------------------------------------------------------
   Step 1: Read Patient Demographics
   ----------------------------------------------------------------------- */
proc import datafile="&DATA_PATH./patients.csv"
            out=WORK.DM_RAW
            dbms=csv
            replace;
  getnames=yes;
  guessingrows=max;
run;

data WORK.DM;
  set WORK.DM_RAW;

  /* Derive survival time in days from randomisation to death or last contact.
     PROC IMPORT reads date columns as character (ISO 8601 strings) from CSV.
     Convert each using input() with yymmdd10. informat. */
  RANDDATE_DT  = input(strip(RANDDATE), yymmdd10.);
  RFSTDTC_DT   = input(strip(RFSTDTC),  yymmdd10.);
  RFENDTC_DT   = input(strip(RFENDTC),  yymmdd10.);

  /* Overall survival (days) */
  OS_DAYS = RFENDTC_DT - RFSTDTC_DT;

  /* Event indicator: 1 = death, 0 = censored */
  if DTHFL = "Y" then OS_CNSR = 0; /* event */
  else                OS_CNSR = 1; /* censored */

  /* Age group */
  if AGE < 55         then AGEGR1 = "<55";
  else if 55 <= AGE < 65 then AGEGR1 = "55-64";
  else                     AGEGR1 = ">=65";

  label
    USUBJID  = "Unique Subject Identifier"
    AGE      = "Age at Randomisation (years)"
    SEX      = "Sex"
    RACE     = "Race"
    ECOG     = "ECOG Performance Status"
    TRTARM   = "Treatment Arm"
    OS_DAYS  = "Overall Survival Duration (days)"
    OS_CNSR  = "OS Censoring Flag (0=Event, 1=Censored)"
    AGEGR1   = "Age Group"
    DTHFL    = "Death Flag";

  format RANDDATE_DT RFSTDTC_DT RFENDTC_DT date9.;
  drop RANDDATE RFSTDTC RFENDTC DIAGDATE;
run;

proc print data=WORK.DM (obs=5) noobs;
  title2 "Demographics - First 5 Records";
  var USUBJID AGE SEX RACE ECOG TRTARM OS_DAYS OS_CNSR;
run;

/* -----------------------------------------------------------------------
   Step 2: Read Tumor Measurements
   ----------------------------------------------------------------------- */
proc import datafile="&DATA_PATH./tumor_measurements.csv"
            out=WORK.TR_RAW
            dbms=csv
            replace;
  getnames=yes;
  guessingrows=max;
run;

/* Identify baseline and derive percent change from baseline */
proc sort data=WORK.TR_RAW out=WORK.TR_SORT;
  by USUBJID VISITNUM;
run;

data WORK.TR_BL;
  set WORK.TR_SORT;
  where VISITNUM = 1; /* Baseline */
  BL_SUMDIAM = TRSTRESC;
  keep USUBJID BL_SUMDIAM;
run;

data WORK.TR;
  merge WORK.TR_SORT (in=inTR)
        WORK.TR_BL   (in=inBL);
  by USUBJID;
  if inTR;

  /* Percent change from baseline */
  if BL_SUMDIAM > 0 then
    PCHG_BL = round(((TRSTRESC - BL_SUMDIAM) / BL_SUMDIAM) * 100, 0.1);

  /* RECIST 1.1 response per visit */
  if VISITNUM = 1 then RECIST_RESP = "BASELINE";
  else if TRSTRESC = 0               then RECIST_RESP = "CR";  /* Complete Response     */
  else if PCHG_BL <= -30            then RECIST_RESP = "PR";  /* Partial Response      */
  else if PCHG_BL >= 20             then RECIST_RESP = "PD";  /* Progressive Disease   */
  else                                    RECIST_RESP = "SD";  /* Stable Disease        */

  TRDTC_DT = input(TRDTC, yymmdd10.);

  label
    USUBJID    = "Unique Subject Identifier"
    VISIT      = "Visit Name"
    TRSTRESC   = "Sum of Target Lesion Diameters (mm)"
    BL_SUMDIAM = "Baseline Sum of Diameters (mm)"
    PCHG_BL    = "Percent Change from Baseline (%)"
    RECIST_RESP = "RECIST 1.1 Response"
    TRDTC_DT   = "Assessment Date";

  format TRDTC_DT date9.;
  drop TRDTC TRORRES TRSTRESU TRTESTCD;
run;

proc print data=WORK.TR (obs=10) noobs;
  title2 "Tumor Measurements - First 10 Records";
  var USUBJID VISIT TRSTRESC BL_SUMDIAM PCHG_BL RECIST_RESP;
run;

/* -----------------------------------------------------------------------
   Step 3: Read Adverse Events
   ----------------------------------------------------------------------- */
proc import datafile="&DATA_PATH./adverse_events.csv"
            out=WORK.AE_RAW
            dbms=csv
            replace;
  getnames=yes;
  guessingrows=max;
run;

data WORK.AE;
  set WORK.AE_RAW;

  /* Convert grade to numeric */
  AETOXGR_N = input(AETOXGR, best.);

  /* High-grade flag (Grade 3+) */
  if AETOXGR_N >= 3 then HGAE_FL = "Y";
  else                    HGAE_FL = "N";

  /* Serious AE flag */
  if AESER = "Y" then SAE_FL = 1;
  else                SAE_FL = 0;

  label
    USUBJID   = "Unique Subject Identifier"
    AETERM    = "Adverse Event Term (Verbatim)"
    AEDECOD   = "Adverse Event (Dictionary-Derived)"
    AEBODSYS  = "Body System"
    AETOXGR   = "CTCAE Toxicity Grade"
    AESER     = "Serious AE Flag"
    AEREL     = "Relationship to Treatment"
    HGAE_FL   = "High-Grade AE Flag (Grade >=3)"
    SAE_FL    = "Serious AE (1=Yes, 0=No)";
run;

proc print data=WORK.AE (obs=5) noobs;
  title2 "Adverse Events - First 5 Records";
  var USUBJID AETERM AETOXGR AESER AEREL HGAE_FL;
run;

/* -----------------------------------------------------------------------
   Step 4: Build Subject-Level Analysis Dataset (ADSL-like)
   ----------------------------------------------------------------------- */

/* Best Overall Response (BOR) per RECIST - worst (most favourable) non-baseline response */
proc sort data=WORK.TR out=WORK.TR_NONBL;
  by USUBJID VISITNUM;
  where VISITNUM > 1; /* exclude baseline */
run;

/* Assign RECIST numeric rank for BOR determination */
data WORK.TR_RANK;
  set WORK.TR_NONBL;
  select (RECIST_RESP);
    when ("CR") RESP_RANK = 1;
    when ("PR") RESP_RANK = 2;
    when ("SD") RESP_RANK = 3;
    when ("PD") RESP_RANK = 4;
    otherwise   RESP_RANK = 5;
  end;
run;

proc sort data=WORK.TR_RANK;
  by USUBJID RESP_RANK;
run;

/* Keep best (lowest rank = best response) */
data WORK.BOR;
  set WORK.TR_RANK;
  by USUBJID RESP_RANK;
  if first.USUBJID;
  BOR = RECIST_RESP;
  keep USUBJID BOR PCHG_BL;
  rename PCHG_BL = BOR_PCHG;
run;

/* Best percent change (minimum - most negative) */
proc means data=WORK.TR_NONBL noprint;
  by USUBJID;
  var PCHG_BL;
  output out=WORK.BESTPCHG (drop=_TYPE_ _FREQ_) min=BESTPCHG;
run;

/* Merge all into subject-level dataset */
data WORK.ADSL;
  merge WORK.DM      (in=inDM)
        WORK.BOR     (in=inBOR)
        WORK.BESTPCHG(in=inPCHG);
  by USUBJID;
  if inDM;

  /* Responder flag (CR or PR) */
  if BOR in ("CR","PR") then RESP_FL = "Y";
  else if BOR ne ""     then RESP_FL = "N";
  else                       RESP_FL = "UNK";

  label
    BOR      = "Best Overall Response (RECIST 1.1)"
    BOR_PCHG = "% Change from Baseline at BOR"
    BESTPCHG = "Best % Change from Baseline"
    RESP_FL  = "Responder Flag (CR/PR)";
run;

proc contents data=WORK.ADSL varnum;
  title2 "ADSL - Subject-Level Analysis Dataset Contents";
run;

proc print data=WORK.ADSL noobs;
  title2 "ADSL - All Subjects";
  var USUBJID TRTARM AGE AGEGR1 SEX ECOG BOR BESTPCHG RESP_FL OS_DAYS OS_CNSR;
run;

title;
%put NOTE: === Data Preparation Complete. WORK datasets ready for analysis. ===;
