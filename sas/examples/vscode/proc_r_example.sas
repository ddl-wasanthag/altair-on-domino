/*==============================================================================
  Program     : proc_r_example.sas  [VS Code version]
  Purpose     : Demonstrate PROC R with the VS Code SAS extension.

  Output in VS Code:
    - R cat() / print() -> Log panel  (View > SAS Log)
    - PROC PRINT etc    -> Results panel  (the HTML viewer tab)
    - DATA= option      -> passes named SAS datasets to R as data frames
    - sas.put()         -> writes an R data frame back to a SAS dataset
==============================================================================*/

/* -----------------------------------------------------------------------
   Resolve dataset path
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

/* -----------------------------------------------------------------------
   Step 1: SAS reads the CSV
   ----------------------------------------------------------------------- */
proc import datafile="&DATA_PATH./patients.csv"
            out=WORK.patients
            dbms=csv
            replace;
  getnames=yes;
run;

%put NOTE: WORK.patients has
  %sysfunc(attrn(%sysfunc(open(WORK.patients)),nobs)) rows.;

/* -----------------------------------------------------------------------
   Step 2: PROC R — DATA= passes WORK.patients as the R data frame
   'patients'. sas.put() writes a result back to SAS.
   cat() / print() are visible in the VS Code Log panel.
   ----------------------------------------------------------------------- */
proc r data=WORK.patients;
submit;

# 'patients' data frame is automatically available via DATA=
cat("Rows received from SAS:", nrow(patients), "\n")
print(patients[, c("USUBJID", "AGE", "SEX", "TRTARM", "ECOG")])

# Compute age and ECOG summary by treatment arm
summary_df <- do.call(rbind, lapply(split(patients, patients$TRTARM), function(g) {
  data.frame(
    TRTARM   = g$TRTARM[1],
    N        = nrow(g),
    Age_Mean = round(mean(g$AGE, na.rm=TRUE), 1),
    Age_Min  = min(g$AGE,  na.rm=TRUE),
    Age_Max  = max(g$AGE,  na.rm=TRUE),
    ECOG0_N  = sum(g$ECOG == 0, na.rm=TRUE),
    ECOG1_N  = sum(g$ECOG == 1, na.rm=TRUE),
    ECOG2_N  = sum(g$ECOG == 2, na.rm=TRUE),
    stringsAsFactors = FALSE
  )
}))
rownames(summary_df) <- NULL

cat("\nSummary computed in R:\n")
print(summary_df)

# Write back to SAS
sas.put(summary_df, "WORK.r_age_summary")
cat("WORK.r_age_summary written.\n")

endsubmit;
run;

/* -----------------------------------------------------------------------
   Step 3: Print the returned dataset — appears in the VS Code Results panel
   ----------------------------------------------------------------------- */
proc print data=WORK.r_age_summary noobs;
  title "Age and ECOG Summary by Treatment Arm (computed in R)";
run;
title;

%put NOTE: PROC R example complete.;
