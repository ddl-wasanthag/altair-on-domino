/*==============================================================================
  Program     : proc_python_example.sas
  Purpose     : Demonstrate PROC PYTHON — calling Python from within SAS.

  What this shows:
    1. SAS reads a CSV from the dataset mount into a SAS dataset
    2. Python receives the SAS dataset as a pandas DataFrame (SAS.sd2df)
    3. Python does a quick summary and writes the result back to SAS (SAS.df2sd)
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
   Step 2: Pass to Python — compute a quick age summary by treatment arm
   SAS.sd2df()  : SAS dataset  -> pandas DataFrame
   SAS.df2sd()  : pandas DataFrame -> SAS dataset
   ----------------------------------------------------------------------- */
proc python;
submit;

import pandas as pd

# Read the SAS dataset that was just imported from CSV
df = SAS.sd2df("WORK.patients")

print(f"Rows received: {len(df)}")
print(df[["USUBJID", "AGE", "SEX", "TRTARM", "ECOG"]].to_string(index=False))

# Quick summary: mean age, patient count, and ECOG breakdown by treatment arm
summary = (
    df.groupby("TRTARM")
      .agg(
          N=("USUBJID",  "count"),
          Age_Mean=("AGE", "mean"),
          Age_Min=("AGE",  "min"),
          Age_Max=("AGE",  "max"),
          ECOG0_N=("ECOG", lambda x: (x == 0).sum()),
          ECOG1_N=("ECOG", lambda x: (x == 1).sum()),
          ECOG2_N=("ECOG", lambda x: (x == 2).sum()),
      )
      .reset_index()
)
summary["Age_Mean"] = summary["Age_Mean"].round(1)

print("\nSummary by Treatment Arm (computed in Python):")
print(summary.to_string(index=False))

# Write back to SAS
SAS.df2sd(summary, "WORK.py_age_summary")
print("\nResult written back to WORK.py_age_summary")

endsubmit;
run;

/* -----------------------------------------------------------------------
   Step 3: Print the summary that came back from Python
   ----------------------------------------------------------------------- */
proc print data=WORK.py_age_summary noobs;
  title "Age and ECOG Summary by Arm — computed in Python, returned to SAS";
run;
title;

%put NOTE: PROC PYTHON example complete.;
