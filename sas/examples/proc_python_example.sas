/*==============================================================================
  Program     : proc_python_example.sas
  Purpose     : Demonstrate PROC PYTHON — calling Python from within SAS.

  Output notes:
    - Python print()   -> goes to the SAS LOG, not the results/output area
    - SAS.submitLST()  -> pushes text into the visible results/output area
    - SAS.submitLOG()  -> writes a message into the SAS log
    - SAS.df2sd()      -> writes a pandas DataFrame back to a SAS dataset

  If WORK.py_age_summary does not appear in the Work library after running,
  check the SAS log for Python errors — the PROC DATASETS step below will
  also list every dataset currently in WORK to confirm it was created.
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
%put NOTE: Reading CSV from: &DATA_PATH.;

/* -----------------------------------------------------------------------
   Step 1: SAS reads the CSV — standard PROC IMPORT
   ----------------------------------------------------------------------- */
proc import datafile="&DATA_PATH./patients.csv"
            out=WORK.patients
            dbms=csv
            replace;
  getnames=yes;
run;

/* Confirm the import worked before calling Python */
%put NOTE: WORK.patients has %sysfunc(attrn(%sysfunc(open(WORK.patients)),nobs)) rows.;

/* -----------------------------------------------------------------------
   Step 2: PROC PYTHON — process in pandas, write result back to SAS
   ----------------------------------------------------------------------- */
proc python;
submit;

import pandas as pd

# ---------------------------------------------------------------
# NOTE: print() goes to the SAS LOG, not the results window.
#       Use SAS.submitLST() to push text to the visible output.
# ---------------------------------------------------------------

# Read the SAS dataset that PROC IMPORT just created
df = SAS.sd2df("WORK.patients")

# Quick summary: count, mean age, ECOG breakdown by treatment arm
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

# --- Push a formatted text table to the VISIBLE output area ---
SAS.submitLST(
    "proc odstext; p 'Python output — Age and ECOG summary by Treatment Arm' "
    "/ style=[fontweight=bold fontsize=11pt]; run;"
)

# Build a simple text table and push it to the results area
lines = []
lines.append(f"{'Arm':<12} {'N':>4} {'Age Mean':>9} {'Age Min':>8} {'Age Max':>8} "
             f"{'ECOG 0':>7} {'ECOG 1':>7} {'ECOG 2':>7}")
lines.append("-" * 66)
for _, row in summary.iterrows():
    lines.append(
        f"{row['TRTARM']:<12} {int(row['N']):>4} {row['Age_Mean']:>9.1f} "
        f"{int(row['Age_Min']):>8} {int(row['Age_Max']):>8} "
        f"{int(row['ECOG0_N']):>7} {int(row['ECOG1_N']):>7} {int(row['ECOG2_N']):>7}"
    )

table_text = "\n".join(lines)

# submitLST() wraps the text in a PROC ODSTEXT call so it appears in results
SAS.submitLST(
    "proc odstext; p '" + table_text.replace("'", "''") + "' "
    "/ style=[fontfamily='Courier New' fontsize=9pt]; run;"
)

# Write the summary DataFrame back to a SAS dataset
SAS.df2sd(summary, "WORK.py_age_summary")

# Confirm in the log (print -> log only)
print("py_age_summary written to WORK. Rows:", len(summary))

# Also confirm visibly in results
SAS.submitLST(
    "proc odstext; p 'WORK.py_age_summary created — "
    + str(len(summary)) + " rows written back to SAS.' "
    "/ style=[color=green fontweight=bold]; run;"
)

endsubmit;
run;

/* -----------------------------------------------------------------------
   Step 3: Confirm WORK.py_age_summary exists and print it
   ----------------------------------------------------------------------- */
proc print data=WORK.py_age_summary noobs label;
  title "Age and ECOG Summary — computed in Python, returned to SAS";
run;
title;

/* -----------------------------------------------------------------------
   Step 4: List everything currently in WORK (diagnostic)
   Useful to confirm which datasets exist after the Python step.
   ----------------------------------------------------------------------- */
proc datasets lib=WORK nolist;
  contents _all_ nods;
run;
quit;

%put NOTE: PROC PYTHON example complete.;
