/*==============================================================================
  Program     : proc_python_example.sas  [JupyterLab version]
  Purpose     : Demonstrate PROC PYTHON in the Altair SLC Jupyter kernel.

  Data exchange approach (Altair SLC compatible):
    - SAS object (SAS.sd2df / SAS.df2sd) is NOT available in Altair SLC.
    - Instead: Python reads the CSV directly from the dataset mount,
      processes it, and writes a result CSV to /tmp.
      SAS then reads the result back with PROC IMPORT.

  Output in JupyterLab:
    - print()    -> Log tab
    - PROC PRINT -> cell output area
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

/* Set PYTHONHOME / PYTHONLIB for Altair SLC on Domino */
%set_language_paths;

/* Pass the CSV path into Python via a macro variable */
%let PY_INPUT  = &DATA_PATH./patients.csv;
%let PY_OUTPUT = /tmp/py_age_summary.csv;

/* -----------------------------------------------------------------------
   Step 1: PROC PYTHON — read CSV, compute summary, write result CSV
   ----------------------------------------------------------------------- */
proc python;
submit;

import pandas as pd

# &PY_INPUT. and &PY_OUTPUT. are resolved by the SAS macro processor
# before this code reaches Python — they arrive as plain strings.
df = pd.read_csv("&PY_INPUT.")

print(f"\nRows read from CSV: {len(df)}")
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

# Write result to a temp CSV for SAS to read back
summary.to_csv("&PY_OUTPUT.", index=False)
print(f"\nResult written to: &PY_OUTPUT.")

endsubmit;
run;

/* -----------------------------------------------------------------------
   Step 2: SAS reads the result CSV back
   ----------------------------------------------------------------------- */
proc import datafile="&PY_OUTPUT."
            out=WORK.py_age_summary
            dbms=csv
            replace;
  getnames=yes;
run;

/* -----------------------------------------------------------------------
   Step 3: Print the result — appears in notebook cell output area
   ----------------------------------------------------------------------- */
proc print data=WORK.py_age_summary noobs;
  title "Age and ECOG Summary by Treatment Arm (computed in Python)";
run;
title;

%put NOTE: PROC PYTHON example complete.;
