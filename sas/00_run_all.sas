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

%let OUT_DIR  = &PROJ_ROOT./output;
%let SAS_DIR  = &PROJ_ROOT./sas;
%let MACR_DIR = &PROJ_ROOT./sas/macros;

/* Create output directory */
options noxwait noxsync;
x "mkdir -p &OUT_DIR.";

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
           file="oncology_poc_tfls.html"
           style=Harvest
           gpath="&OUT_DIR."
           (url=none)
           options(pagebreakhtml="yes");

ods pdf    file="&OUT_DIR./oncology_poc_tfls.pdf"
           style=Journal
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
%put NOTE: HTML report: &OUT_DIR./oncology_poc_tfls.html;
%put NOTE: PDF  report: &OUT_DIR./oncology_poc_tfls.pdf;
%put NOTE: ============================================================;
