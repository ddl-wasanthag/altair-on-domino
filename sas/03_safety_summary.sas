/*==============================================================================
  Program   : 03_safety_summary.sas
  Study     : STUDY01 - Oncology Phase II POC
  Purpose   : Safety analysis including:
                - Adverse event incidence by treatment arm and body system
                - High-grade (Grade 3+) AE summary (CTCAE)
                - Serious AE summary
                - Most frequent AEs (any grade and Grade 3+)
                - Treatment-related AE summary

  Prerequisite: Run 01_data_preparation.sas first (WORK.ADSL, WORK.AE)
  Altair SLC / Domino POC - Safety Analysis Step
==============================================================================*/

options nodate nonumber ls=180 ps=65 mprint;
title "STUDY01 - Oncology POC: Safety Summary";

/* -----------------------------------------------------------------------
   Merge AE with ADSL to get treatment arm (safety population)
   ----------------------------------------------------------------------- */
proc sort data=WORK.AE   out=WORK.AE_S;   by USUBJID; run;
proc sort data=WORK.ADSL out=WORK.ADSL_S; by USUBJID; run;

data WORK.AE_MERGED;
  merge WORK.AE_S   (in=inAE)
        WORK.ADSL_S (in=inADSL keep=USUBJID TRTARM);
  by USUBJID;
  if inAE and inADSL;
run;

/* -----------------------------------------------------------------------
   Table 1: Overview of Adverse Events (Safety Summary)
   ----------------------------------------------------------------------- */
title2 "Table 1: Safety Overview - Patients with At Least One AE";

/* Count subjects with at least one AE */
proc sort data=WORK.AE_MERGED out=WORK.AE_SUBJ nodupkey;
  by USUBJID TRTARM;
run;

proc freq data=WORK.AE_SUBJ;
  tables TRTARM / nocum;
  title3 "Number of Subjects with At Least One AE by Treatment Arm";
run;

/* Count subjects with at least one Grade 3+ AE */
proc sort data=WORK.AE_MERGED(where=(AETOXGR_N >= 3))
          out=WORK.AE_HG_SUBJ nodupkey;
  by USUBJID TRTARM;
run;

proc freq data=WORK.AE_HG_SUBJ;
  tables TRTARM / nocum;
  title3 "Number of Subjects with At Least One Grade >=3 AE by Treatment Arm";
run;

/* Count subjects with at least one SAE */
proc sort data=WORK.AE_MERGED(where=(AESER = "Y"))
          out=WORK.SAE_SUBJ nodupkey;
  by USUBJID TRTARM;
run;

proc freq data=WORK.SAE_SUBJ;
  tables TRTARM / nocum;
  title3 "Number of Subjects with At Least One Serious AE (SAE) by Treatment Arm";
run;

/* -----------------------------------------------------------------------
   Table 2: AEs by Body System and Treatment Arm (Any Grade)
   ----------------------------------------------------------------------- */
title2 "Table 2: Adverse Events by Body System and Treatment Arm (Any Grade)";

/* Get distinct subject-AE body system combinations (incidence, not event count) */
proc sort data=WORK.AE_MERGED out=WORK.AE_BODYSYS nodupkey;
  by USUBJID TRTARM AEBODSYS;
run;

proc freq data=WORK.AE_BODYSYS order=freq;
  tables AEBODSYS * TRTARM / nocum nopercent norow;
  title3 "Incidence of AEs by Body System (unique subjects)";
run;

/* -----------------------------------------------------------------------
   Table 3: Most Frequent AEs (Any Grade) - Top 10
   ----------------------------------------------------------------------- */
title2 "Table 3: Most Frequent Adverse Events - Any Grade";

/* Subject-level incidence (count each AE term once per subject) */
proc sort data=WORK.AE_MERGED out=WORK.AE_TERM_SUBJ nodupkey;
  by USUBJID TRTARM AEDECOD;
run;

proc freq data=WORK.AE_TERM_SUBJ order=freq noprint;
  tables AEDECOD / out=WORK.AE_FREQ_ALL;
run;

proc sort data=WORK.AE_FREQ_ALL; by descending COUNT; run;

data WORK.AE_FREQ_TOP10;
  set WORK.AE_FREQ_ALL;
  if _N_ <= 10;
  label AEDECOD = "Adverse Event (Preferred Term)"
        COUNT   = "Number of Subjects"
        PERCENT = "% of All Subjects";
run;

proc print data=WORK.AE_FREQ_TOP10 noobs label;
  title3 "Top 10 Most Frequent AEs (Any Grade) - All Subjects";
  var AEDECOD COUNT PERCENT;
  format PERCENT 5.1;
run;

/* -----------------------------------------------------------------------
   Table 4: Grade 3+ AEs by Term and Treatment Arm
   ----------------------------------------------------------------------- */
title2 "Table 4: Grade 3+ Adverse Events by Preferred Term and Treatment Arm";

proc sort data=WORK.AE_MERGED(where=(AETOXGR_N >= 3))
          out=WORK.AE_HG_TERM nodupkey;
  by USUBJID TRTARM AEDECOD;
run;

proc freq data=WORK.AE_HG_TERM order=freq;
  tables AEDECOD * TRTARM / nocum nopercent norow;
  title3 "High-Grade (CTCAE Grade >=3) AEs by Preferred Term (unique subjects)";
run;

/* -----------------------------------------------------------------------
   Table 5: Treatment-Related AEs by Grade
   ----------------------------------------------------------------------- */
title2 "Table 5: Treatment-Related Adverse Events by CTCAE Grade";

data WORK.AE_RELATED;
  set WORK.AE_MERGED;
  where AEREL in ("RELATED", "POSSIBLY RELATED");
run;

proc freq data=WORK.AE_RELATED;
  tables TRTARM * AETOXGR / nocum nopercent;
  title3 "Treatment-Related AEs by Grade and Treatment Arm";
run;

/* -----------------------------------------------------------------------
   Figure 1: AE Grade Profile by Treatment Arm (Stacked Bar)
   ----------------------------------------------------------------------- */
title2 "Figure 1: CTCAE Grade Distribution of Treatment-Related AEs";

proc format;
  value $GRADEFMT
    "1" = "Grade 1 (Mild)"
    "2" = "Grade 2 (Moderate)"
    "3" = "Grade 3 (Severe)"
    "4" = "Grade 4 (Life-Threatening)"
    "5" = "Grade 5 (Fatal)";
run;

proc freq data=WORK.AE_RELATED noprint;
  tables TRTARM * AETOXGR / out=WORK.AE_GRADE_FREQ;
run;

ods graphics on / width=10in height=6in;

proc sgplot data=WORK.AE_GRADE_FREQ;
  vbar TRTARM / response=COUNT
                group=AETOXGR
                groupdisplay=stack
                datalabel
                seglabel;
  xaxis label="Treatment Arm";
  yaxis label="Number of AE Reports" grid;
  keylegend / title="CTCAE Grade";
  title3 "Treatment-Related Adverse Events by CTCAE Grade and Treatment Arm";
  footnote "Based on treatment-related and possibly related AEs only.";
run;

ods graphics off;

/* -----------------------------------------------------------------------
   Table 6: Serious Adverse Events (SAEs) Listing
   ----------------------------------------------------------------------- */
title2 "Table 6: Listing of All Serious Adverse Events (SAEs)";

proc print data=WORK.AE_MERGED(where=(AESER = "Y")) noobs label;
  var USUBJID TRTARM AEDECOD AEBODSYS AETOXGR AEREL AESTDTC AEENDTC AEOUT;
  label
    USUBJID   = "Subject ID"
    TRTARM    = "Treatment Arm"
    AEDECOD   = "AE Preferred Term"
    AEBODSYS  = "Body System"
    AETOXGR   = "Grade"
    AEREL     = "Relationship"
    AESTDTC   = "Start Date"
    AEENDTC   = "End Date"
    AEOUT     = "Outcome";
  title3 "SAE Listing - All Subjects";
run;

/* -----------------------------------------------------------------------
   Table 7: AEs Leading to Study Discontinuation
   (Grade 4 or 5 = potential discontinuation criteria)
   ----------------------------------------------------------------------- */
title2 "Table 7: High-Grade AEs (Grade 4-5) with Potential Impact on Treatment";

proc print data=WORK.AE_MERGED(where=(AETOXGR_N >= 4)) noobs label;
  var USUBJID TRTARM AEDECOD AEBODSYS AETOXGR AESER AEREL AEOUT;
  title3 "Subjects with Grade 4 or 5 AEs";
run;

title;
footnote;
%put NOTE: === Safety Summary Complete ===;
