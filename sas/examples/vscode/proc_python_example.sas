/*==============================================================================
  Program     : proc_python_example.sas  [VS Code version]
  Purpose     : Demonstrate PROC PYTHON with the VS Code SAS extension.

  Output in VS Code:
    - print()     -> Log panel  (View > SAS Log)
    - PROC PRINT  -> Results panel  (the HTML viewer tab)
    - SAS.sd2df() -> SAS dataset into a pandas DataFrame
    - SAS.df2sd() -> pandas DataFrame back to a SAS dataset

  Note: SAS.submitLST() is a Jupyter-only API — do not use it here.
  VS Code manages its own ODS HTML session; do not call ods _all_ close.
==============================================================================*/

/* Load shared macros (includes %set_language_paths) */
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
   Step 2: PROC PYTHON — read from SAS, compute summary, write back.
   print() output is visible in the VS Code Log panel.
   ----------------------------------------------------------------------- */
proc python;
submit;

import pandas as pd

df = SAS.sd2df("WORK.patients")

# These appear in the VS Code Log panel
print(f"\nRows received from SAS: {len(df)}")
print(df[["USUBJID", "AGE", "SEX", "TRTARM", "ECOG"]].to_string(index=False))

# Compute age and ECOG summary by treatment arm
summary = (
    df.groupby("TRTARM", as_index=False)
      .agg(
          N        = ("USUBJID", "count"),
          Age_Mean = ("AGE",     "mean"),
          Age_Min  = ("AGE",     "min"),
          Age_Max  = ("AGE",     "max"),
          ECOG0_N  = ("ECOG",    lambda x: (x == 0).sum()),
          ECOG1_N  = ("ECOG",    lambda x: (x == 1).sum()),
          ECOG2_N  = ("ECOG",    lambda x: (x == 2).sum()),
      )
)
summary["Age_Mean"] = summary["Age_Mean"].round(1)

print("\nSummary computed in Python:")
print(summary.to_string(index=False))

# Write the result back to SAS
SAS.df2sd(summary, "WORK.py_age_summary")
print("\nWORK.py_age_summary written successfully.")

endsubmit;
run;

/* -----------------------------------------------------------------------
   Step 3: Print the returned dataset — appears in the VS Code Results panel
   ----------------------------------------------------------------------- */
proc print data=WORK.py_age_summary noobs;
  title "Age and ECOG Summary by Treatment Arm (computed in Python)";
run;
title;

%put NOTE: PROC PYTHON example complete.;
