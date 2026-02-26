/*==============================================================================
  Program     : proc_python_example.sas  [JupyterLab version]
  Purpose     : Demonstrate PROC PYTHON in the Altair SLC Jupyter kernel.

  Output in JupyterLab:
    - print()         -> SAS log (visible in the Log tab of the notebook)
    - SAS.submitLST() -> pushes a SAS statement whose output appears in the
                         notebook cell output area
    - PROC PRINT etc  -> appears in the notebook cell output area
    - SAS.sd2df()     -> SAS dataset into a pandas DataFrame
    - SAS.df2sd()     -> pandas DataFrame back to a SAS dataset
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
   Step 2: PROC PYTHON — read from SAS, compute summary, write back.
   SAS.submitLST() pushes output into the notebook cell output area.
   print() goes to the Log tab only.
   ----------------------------------------------------------------------- */
proc python;
submit;

import pandas as pd

df = SAS.sd2df("WORK.patients")

# print() -> Log tab
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

# Write result back to SAS
SAS.df2sd(summary, "WORK.py_age_summary")

# Confirm in notebook cell output area via submitLST
SAS.submitLST(
    "proc odstext; "
    "p 'WORK.py_age_summary written — " + str(len(summary)) + " rows' "
    "/ style=[color=green fontweight=bold]; run;"
)

endsubmit;
run;

/* -----------------------------------------------------------------------
   Step 3: Print the returned dataset — appears in cell output area
   ----------------------------------------------------------------------- */
proc print data=WORK.py_age_summary noobs;
  title "Age and ECOG Summary by Treatment Arm (computed in Python)";
run;
title;

%put NOTE: PROC PYTHON example complete.;
