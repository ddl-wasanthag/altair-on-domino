/*==============================================================================
  Program     : proc_r_example.sas
  Purpose     : Demonstrate PROC R — calling R from within SAS.

  What this shows:
    1. SAS reads a CSV from the dataset mount into a SAS dataset
    2. R receives the SAS dataset as a data frame (via DATA= option)
    3. R does a quick summary and writes the result back to SAS (sas.put)
    4. SAS prints the returned summary table
==============================================================================*/

/* -----------------------------------------------------------------------
   Resolve dataset path (same logic as main programs)
   ----------------------------------------------------------------------- */
%macro set_data_path;
  %global DATA_PATH;
  %if %sysfunc(fileexist(/mnt/data/oncology_altair_poc/sdtm/patients.csv)) %then
    %let DATA_PATH = /mnt/data/oncology_altair_poc/sdtm;
  %else %if %sysfunc(fileexist(/mnt/data/oncology_altair_poc/patients.csv)) %then
    %let DATA_PATH = /mnt/data/oncology_altair_poc;
  %else
    %let DATA_PATH = %sysget(DOMINO_PROJECT_ROOT)/sdtm;
%mend set_data_path;
%set_data_path;
%put NOTE: Reading CSV from: &DATA_PATH.;

/* -----------------------------------------------------------------------
   Step 1: SAS reads the CSV into WORK
   ----------------------------------------------------------------------- */
proc import datafile="&DATA_PATH./patients.csv"
            out=WORK.patients
            dbms=csv
            replace;
  getnames=yes;
run;

/* -----------------------------------------------------------------------
   Step 2: Pass to R — compute a quick age summary by treatment arm.
   DATA= makes WORK.patients available inside R as a data frame
   named 'patients' (lowercase, no libname prefix).
   sas.put() writes an R data frame back to a SAS dataset.
   ----------------------------------------------------------------------- */
proc r data=WORK.patients;
submit;

cat("Rows received:", nrow(patients), "\n")
print(patients[, c("USUBJID", "AGE", "SEX", "TRTARM", "ECOG")])

# Quick summary: mean age, count, ECOG breakdown by treatment arm
summary_df <- do.call(rbind, lapply(split(patients, patients$TRTARM), function(grp) {
  data.frame(
    TRTARM   = grp$TRTARM[1],
    N        = nrow(grp),
    Age_Mean = round(mean(grp$AGE, na.rm = TRUE), 1),
    Age_Min  = min(grp$AGE,  na.rm = TRUE),
    Age_Max  = max(grp$AGE,  na.rm = TRUE),
    ECOG0_N  = sum(grp$ECOG == 0, na.rm = TRUE),
    ECOG1_N  = sum(grp$ECOG == 1, na.rm = TRUE),
    ECOG2_N  = sum(grp$ECOG == 2, na.rm = TRUE),
    stringsAsFactors = FALSE
  )
}))
rownames(summary_df) <- NULL

cat("\nSummary by Treatment Arm (computed in R):\n")
print(summary_df)

# Write back to SAS
sas.put(summary_df, "WORK.r_age_summary")
cat("\nResult written back to WORK.r_age_summary\n")

endsubmit;
run;

/* -----------------------------------------------------------------------
   Step 3: Print the summary that came back from R
   ----------------------------------------------------------------------- */
proc print data=WORK.r_age_summary noobs;
  title "Age and ECOG Summary by Arm — computed in R, returned to SAS";
run;
title;

%put NOTE: PROC R example complete.;
