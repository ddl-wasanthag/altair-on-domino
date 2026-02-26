/*==============================================================================
  Program     : proc_r_example.sas  [JupyterLab version]
  Purpose     : Demonstrate PROC R in the Altair SLC Jupyter kernel.

  Altair SLC notes:
    - DATA= option is not supported on PROC R — datasets cannot be passed
      directly. Use OS environment variables instead.
    - options set= sets a real OS env var that R reads with Sys.getenv().
    - R writes a result CSV; SAS reads it back with PROC IMPORT.
    - cat() / print() output is visible in the Log tab.
    - PROC PRINT output appears in the notebook cell output area.
==============================================================================*/

/* Load shared macros */
%let MACR_DIR = %sysget(DOMINO_PROJECT_ROOT)/sas/macros;
%if "&MACR_DIR." = "/sas/macros" %then
  %let MACR_DIR = /mnt/code/sas/macros;
%include "&MACR_DIR./tfl_macros.sas";

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

/* Set PYTHONHOME / PYTHONLIB / R_HOME for Altair SLC on Domino */
%set_language_paths;

/* -----------------------------------------------------------------------
   Pass paths to R via OS environment variables.
   Macro variables are resolved here (SAS level) before R runs.
   ----------------------------------------------------------------------- */
%let R_OUTPUT = /tmp/r_age_summary.csv;
options set=SAS_R_INPUT  "&DATA_PATH./patients.csv";
options set=SAS_R_OUTPUT "&R_OUTPUT.";

/* -----------------------------------------------------------------------
   Step 1: PROC R — read CSV, compute summary, write result CSV
   ----------------------------------------------------------------------- */
proc r;
submit;

# Read paths from OS environment variables set by SAS
input_path  <- Sys.getenv("SAS_R_INPUT")
output_path <- Sys.getenv("SAS_R_OUTPUT")

cat("Input  path:", input_path,  "\n")
cat("Output path:", output_path, "\n")

# Read directly from the CSV on the dataset mount
patients <- read.csv(input_path, stringsAsFactors = FALSE)

cat("\nRows read from CSV:", nrow(patients), "\n")
print(patients[, c("USUBJID", "AGE", "SEX", "TRTARM", "ECOG")])

# Compute age and ECOG summary by treatment arm
summary_df <- do.call(rbind, lapply(split(patients, patients$TRTARM), function(g) {
  data.frame(
    TRTARM   = g$TRTARM[1],
    N        = nrow(g),
    Age_Mean = round(mean(g$AGE, na.rm = TRUE), 1),
    Age_Min  = min(g$AGE,  na.rm = TRUE),
    Age_Max  = max(g$AGE,  na.rm = TRUE),
    ECOG0_N  = sum(g$ECOG == 0, na.rm = TRUE),
    ECOG1_N  = sum(g$ECOG == 1, na.rm = TRUE),
    ECOG2_N  = sum(g$ECOG == 2, na.rm = TRUE),
    stringsAsFactors = FALSE
  )
}))
rownames(summary_df) <- NULL

cat("\nSummary computed in R:\n")
print(summary_df)

# Write result CSV for SAS to read back
write.csv(summary_df, output_path, row.names = FALSE)
cat("\nResult written to:", output_path, "\n")

endsubmit;
run;

/* -----------------------------------------------------------------------
   Step 2: SAS reads the result CSV back
   ----------------------------------------------------------------------- */
proc import datafile="&R_OUTPUT."
            out=WORK.r_age_summary
            dbms=csv
            replace;
  getnames=yes;
run;

/* -----------------------------------------------------------------------
   Step 3: Print the result — appears in the notebook cell output area
   ----------------------------------------------------------------------- */
proc print data=WORK.r_age_summary noobs;
  title "Age and ECOG Summary by Treatment Arm (computed in R)";
run;
title;

%put NOTE: PROC R example complete.;
