/*==============================================================================
  Program     : proc_python_example.sas  [VS Code version]
  Purpose     : Demonstrate PROC PYTHON with the VS Code SAS extension.

  Data exchange:
    Python reads the CSV directly from the dataset mount,
    processes it, and writes a result CSV to /tmp.
    SAS reads the result back with PROC IMPORT.

  Output in VS Code:
    - print()    -> Log panel  (View > SAS Log)
    - PROC PRINT -> Results panel
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

/* Set PYTHONHOME / PYTHONLIB / R_HOME */
%set_language_paths;

/* -----------------------------------------------------------------------
   Pass paths to Python via OS environment variables.
   options set= sets a real OS env var that Python reads with os.environ.
   ----------------------------------------------------------------------- */
%let PY_OUTPUT = /tmp/py_age_summary.csv;
options set=SAS_PY_INPUT  "&DATA_PATH./patients.csv";
options set=SAS_PY_OUTPUT "&PY_OUTPUT.";

/* -----------------------------------------------------------------------
   Step 1: PROC PYTHON — read CSV, compute summary, write result CSV
   ----------------------------------------------------------------------- */
proc python;
submit;

import os
import pandas as pd

# Read paths from OS environment variables set by SAS above
input_path  = os.environ["SAS_PY_INPUT"]
output_path = os.environ["SAS_PY_OUTPUT"]

print(f"\nInput  path : {input_path}")
print(f"Output path : {output_path}")

df = pd.read_csv(input_path)

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

# Write result CSV for SAS to read back
summary.to_csv(output_path, index=False)
print(f"\nResult written to: {output_path}")

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
   Step 3: Print the result — appears in VS Code Results panel
   ----------------------------------------------------------------------- */
proc print data=WORK.py_age_summary noobs;
  title "Age and ECOG Summary by Treatment Arm (computed in Python)";
run;
title;

%put NOTE: PROC PYTHON example complete.;
