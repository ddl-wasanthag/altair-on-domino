/*==============================================================================
  Program     : 00_run_all.sas
  Study       : STUDY01 - Oncology Phase II POC
  Purpose     : Master driver. Runs data preparation then all TFL programs
                in ICH E3 section order, producing a combined HTML + PDF report.

  Output structure follows ICH E3 guideline sections:
    Section 14.1 - Demographics and Baseline Characteristics
    Section 14.2 - Efficacy Tables and Figures
    Section 16.2 - Patient Data Listings

  Usage on Domino (Altair SLC compute environment):
    sas /mnt/code/sas/00_run_all.sas

  Altair SLC / Domino POC - Master Driver
==============================================================================*/

options nodate nonumber ls=180 ps=65 mprint symbolgen msglevel=i;

/* -----------------------------------------------------------------------
   Resolve project root (Domino sets DOMINO_PROJECT_ROOT automatically)
   ----------------------------------------------------------------------- */
%let PROJ_ROOT = %sysget(DOMINO_PROJECT_ROOT);
%if "&PROJ_ROOT." = "" %then
  %let PROJ_ROOT = /mnt/code;
%put NOTE: [00_run_all] Project root: &PROJ_ROOT.;

%let SAS_DIR  = &PROJ_ROOT./sas;
%let MACR_DIR = &PROJ_ROOT./sas/macros;

/* -----------------------------------------------------------------------
   Output directory: write TFLs to the dataset tfl/ folder so reports
   are persisted as dataset artifacts and visible outside the run.
   Falls back to /mnt/code/tfl/ if the dataset path is not writable.
   ----------------------------------------------------------------------- */
%let DATA_MOUNT = /mnt/data/oncology_altair_poc;
%let OUT_DIR    = &DATA_MOUNT./tfl;
%let LOG_DIR    = &DATA_MOUNT./logs;

options noxwait noxsync;
x "mkdir -p &OUT_DIR. &LOG_DIR.";

/* Verify tfl/ folder was created; warn if not */
%if %sysfunc(fileexist(&OUT_DIR.)) = 0 %then %do;
  %put WARNING: Could not create &OUT_DIR. - check dataset is mounted read-write.;
  %put WARNING: Falling back to &PROJ_ROOT./tfl and &PROJ_ROOT./logs;
  %let OUT_DIR = &PROJ_ROOT./tfl;
  %let LOG_DIR = &PROJ_ROOT./logs;
  x "mkdir -p &OUT_DIR. &LOG_DIR.";
%end;
%put NOTE: [00_run_all] TFL directory: &OUT_DIR.;
%put NOTE: [00_run_all] Log directory: &LOG_DIR.;

/* -----------------------------------------------------------------------
   Redirect SAS log and listing to logs/ with a timestamped filename.
   Each run produces its own pair of files — history is fully preserved.
     .log  -> stdout equivalent: NOTE / WARNING / ERROR / macro trace
     .lst  -> stderr equivalent: raw procedure listing not captured by ODS
   PROC PRINTTO is reset at the end of this program.
   ----------------------------------------------------------------------- */
%let _runds  = %sysfunc(today(), yymmddn8.);         /* e.g. 20260224          */
%let _runtm  = %sysfunc(time(),  tod8.);             /* e.g. 18:30:45          */
%let _runtm  = %sysfunc(translate(&_runtm., -, :));  /* e.g. 18-30-45          */
%let _logtag = &_runds._&_runtm.;                   /* e.g. 20260224_18-30-45 */

proc printto
  log  = "&LOG_DIR./run_&_logtag..log"
  print= "&LOG_DIR./run_&_logtag..lst"
  new;
run;

/* -----------------------------------------------------------------------
   Load macro library (must be available to all included programs)
   ----------------------------------------------------------------------- */
%include "&MACR_DIR./tfl_macros.sas";

/* -----------------------------------------------------------------------
   Step 0: Data Preparation (builds WORK.ADSL, WORK.TR, WORK.AE)
   ----------------------------------------------------------------------- */
%put NOTE: ======== STEP 0: Data Preparation ========;
%include "&SAS_DIR./01_data_preparation.sas";

/* -----------------------------------------------------------------------
   Open ODS destinations for combined TFL output
   ----------------------------------------------------------------------- */
ods _all_ close;

ods html   path="&OUT_DIR."
           file="oncology_poc_tfls_&_logtag..html"
           style=Default
           gpath="&OUT_DIR."
           (url=none)
           options(pagebreakhtml="yes");

ods pdf    file="&OUT_DIR./oncology_poc_tfls_&_logtag..pdf"
           style=Printer
           startpage=bygroup
           pdftoc=2
           uniform;

ods graphics on / reset=all imagefmt=png;

/* -----------------------------------------------------------------------
   Section 14.1 — Demographics and Baseline Characteristics
   ----------------------------------------------------------------------- */
%put NOTE: ======== TABLE 14.1.1: Demographics ========;
%include "&SAS_DIR./t_14_1_1.sas";

/* -----------------------------------------------------------------------
   Section 14.2 — Efficacy
   ----------------------------------------------------------------------- */
%put NOTE: ======== TABLE 14.2.1: Best Overall Response / ORR ========;
%include "&SAS_DIR./t_14_2_1.sas";

%put NOTE: ======== FIGURE 14.2.1: Kaplan-Meier OS ========;
%include "&SAS_DIR./f_14_2_1.sas";

%put NOTE: ======== FIGURE 14.2.2/3: Waterfall and Spider Plots ========;
%include "&SAS_DIR./f_14_2_2.sas";

/* -----------------------------------------------------------------------
   Section 14.3 — Safety
   ----------------------------------------------------------------------- */
%put NOTE: ======== TABLE 14.3.1: Safety Overview ========;
%include "&SAS_DIR./t_14_3_1.sas";

%put NOTE: ======== TABLE 14.3.2: AEs by SOC and PT ========;
%include "&SAS_DIR./t_14_3_2.sas";

/* -----------------------------------------------------------------------
   Section 16.2 — Patient Data Listings
   ----------------------------------------------------------------------- */
%put NOTE: ======== LISTING 16.2.1: SAE Listing ========;
%put NOTE: ======== LISTING 16.2.2: Deaths Listing ========;
%include "&SAS_DIR./l_16_2_1.sas";

/* -----------------------------------------------------------------------
   Close ODS destinations
   ----------------------------------------------------------------------- */
ods html   close;
ods pdf    close;
ods graphics off;
ods _all_ close;

%put NOTE: ============================================================;
%put NOTE: POC TFLs Complete.;
%put NOTE: HTML report : &OUT_DIR./oncology_poc_tfls_&_logtag..html;
%put NOTE: PDF  report : &OUT_DIR./oncology_poc_tfls_&_logtag..pdf;
%put NOTE: SAS log     : &LOG_DIR./run_&_logtag..log;
%put NOTE: SAS listing : &LOG_DIR./run_&_logtag..lst;
%put NOTE: ============================================================;

/* -----------------------------------------------------------------------
   Reset log back to default (Domino console) — must be last statement
   ----------------------------------------------------------------------- */
proc printto; run;
