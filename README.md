# Altair SLC on Domino — Oncology SAS POC

## Overview

This POC demonstrates running SAS programs using **Altair SLC** as the compute environment
on **Domino Data Lab**. The scenario is a synthetic Phase II oncology clinical trial where
data scientists produce regulatory-quality TFLs (Tables, Figures, Listings) from CDISC-style
data — and call **Python** and **R** directly from within SAS using `PROC PYTHON` and `PROC R`.

---

## Repository Structure

```
altair/
├── sdtm/                              # CDISC SDTM-style input datasets (upload to Domino dataset)
│   ├── patients.csv                   # Patient demographics, treatment arm, survival
│   ├── tumor_measurements.csv         # RECIST target lesion sum-of-diameters over time
│   └── adverse_events.csv             # CTCAE adverse events with grade and relationship
│
├── sas/
│   ├── 00_run_all.sas                 # Master driver — runs all TFL programs in sequence
│   ├── 01_data_preparation.sas        # Reads CSVs, builds WORK.ADSL / WORK.TR / WORK.AE
│   │
│   ├── t_14_1_1.sas                   # Table  14.1.1 — Demographics and Baseline
│   ├── t_14_2_1.sas                   # Table  14.2.1 — Best Overall Response / ORR
│   ├── t_14_3_1.sas                   # Table  14.3.1 — Safety Overview
│   ├── t_14_3_2.sas                   # Table  14.3.2 — AEs by System Organ Class / PT
│   ├── f_14_2_1.sas                   # Figure 14.2.1 — Kaplan-Meier Overall Survival
│   ├── f_14_2_2.sas                   # Figure 14.2.2/3 — Waterfall and Spider Plots
│   ├── l_16_2_1.sas                   # Listing 16.2.1/2 — SAE Listing / Deaths Listing
│   │
│   ├── macros/
│   │   └── tfl_macros.sas             # Shared macros: %tfl_title, %tfl_footnote,
│   │                                  #   %tfl_setup_metadata, %set_language_paths
│   │
│   └── examples/
│       ├── jupyter/                   # Examples for the Altair SLC JupyterLab kernel
│       │   ├── proc_python_example.sas
│       │   └── proc_r_example.sas
│       └── vscode/                    # Examples for the VS Code SAS extension
│           ├── proc_python_example.sas
│           └── proc_r_example.sas
│
└── README.md
```

### Domino Dataset layout (`oncology_altair_poc`)

```
/mnt/data/oncology_altair_poc/
├── sdtm/                              # Input CSVs (upload from sdtm/ above)
│   ├── patients.csv
│   ├── tumor_measurements.csv
│   └── adverse_events.csv
├── tfl/                               # TFL outputs written at runtime
│   ├── oncology_poc_tfls_<timestamp>.html
│   └── oncology_poc_tfls_<timestamp>.pdf
└── logs/                              # SAS log and listing, one pair per run
    ├── run_<timestamp>.log
    └── run_<timestamp>.lst
```

---

## Running the TFLs on Domino

### 1. Set up the Dataset

1. In Domino, go to **Data → Datasets → Create Dataset**, name it `oncology_altair_poc`.
2. Create a `sdtm/` subfolder and upload the three CSV files from `sdtm/`.
3. Attach the dataset to your project with **read/write** access.

### 2. Sync the code

Sync this repository to the Domino project via Git, or upload the `sas/` folder manually.
All code will be available under `/mnt/code/`.

### 3. Run via Domino Job

Create a Job with:
- **Compute Environment**: Altair SLC
- **Command**: `sas /mnt/code/sas/00_run_all.sas`

### 4. Run interactively (JupyterLab or VS Code)

Open a workspace with the Altair SLC environment, open a terminal, and run:

```bash
sas /mnt/code/sas/00_run_all.sas
```

Or open `00_run_all.sas` in the Altair SLC notebook / VS Code SAS extension and run it directly.

### 5. View Outputs

Outputs are written to `/mnt/data/oncology_altair_poc/tfl/` with a timestamp:
- `oncology_poc_tfls_<timestamp>.html` — interactive HTML report
- `oncology_poc_tfls_<timestamp>.pdf` — print-ready PDF report

Logs are written to `/mnt/data/oncology_altair_poc/logs/`:
- `run_<timestamp>.log` — SAS log (NOTEs, WARNINGs, ERRORs, macro trace)
- `run_<timestamp>.lst` — SAS listing (raw procedure output)

---

## TFL Programs

All outputs follow **ICH E3** Clinical Study Report section numbering.

| Program | Output | Description |
|---|---|---|
| `t_14_1_1.sas` | Table 14.1.1 | Demographics and Baseline Characteristics |
| `t_14_2_1.sas` | Table 14.2.1 | Best Overall Response (RECIST 1.1) and ORR with Clopper-Pearson 95% CI |
| `t_14_3_1.sas` | Table 14.3.1 | Safety Overview (any AE, Grade ≥3, SAE, treatment-related) |
| `t_14_3_2.sas` | Table 14.3.2 | Adverse Events by System Organ Class and Preferred Term |
| `f_14_2_1.sas` | Figure 14.2.1 | Kaplan-Meier Overall Survival curves with at-risk table and log-rank p-value |
| `f_14_2_2.sas` | Figure 14.2.2/3 | Waterfall plot (best % change) and Spider plot (change over time) |
| `l_16_2_1.sas` | Listing 16.2.1/2 | SAE Listing and Deaths Listing |

---

## PROC PYTHON and PROC R Examples

The `sas/examples/` folder demonstrates calling Python and R directly from SAS using
`PROC PYTHON` and `PROC R`. Two versions are provided — one per IDE.

### Which file to use

| IDE | Folder |
|---|---|
| JupyterLab (Altair SLC kernel) | `sas/examples/jupyter/` |
| VS Code (SAS extension) | `sas/examples/vscode/` |

The dataset paths and logic are identical in both. Only the output handling differs
(Jupyter uses a notebook cell output area; VS Code uses the Results panel and Log panel).

### What the examples do

Each example follows the same three-step pattern:

```
patients.csv  ──►  PROC PYTHON / PROC R  ──►  age + ECOG summary by arm
     (read by language directly)               (written to /tmp/ as CSV)
                                                        │
                                               PROC IMPORT ──► WORK dataset
                                                        │
                                                   PROC PRINT
```

**Step 1 — SAS sets paths as OS environment variables:**
```sas
options set=SAS_PY_INPUT  "/mnt/data/oncology_altair_poc/sdtm/patients.csv";
options set=SAS_PY_OUTPUT "/tmp/py_age_summary.csv";
```

**Step 2 — Python reads the env vars and processes the data:**
```python
import os, pandas as pd
df = pd.read_csv(os.environ["SAS_PY_INPUT"])
# ... compute summary ...
summary.to_csv(os.environ["SAS_PY_OUTPUT"], index=False)
```

**Step 2 — R reads the env vars and processes the data:**
```r
input_path <- Sys.getenv("SAS_R_INPUT")
patients   <- read.csv(input_path)
# ... compute summary ...
write.csv(summary_df, Sys.getenv("SAS_R_OUTPUT"), row.names=FALSE)
```

**Step 3 — SAS reads the result back:**
```sas
proc import datafile="/tmp/py_age_summary.csv"
            out=WORK.py_age_summary dbms=csv replace;
  getnames=yes;
run;
```

### Altair SLC compatibility notes

These patterns differ from standard SAS 9.4 / Viya because Altair SLC has a
subset of their APIs:

| Feature | Standard SAS Viya | Altair SLC |
|---|---|---|
| `SAS.sd2df()` / `SAS.df2sd()` | ✅ Available | ❌ `SAS` object not defined |
| `SASMacroVar()` in Python | ✅ Available | ❌ Not defined |
| `DATA=` option on `PROC R` | ✅ Available | ❌ Option not recognised |
| `&macrovar.` inside `submit` block | ✅ Resolved | ❌ Passed as literal string |
| `options set=` + `os.environ` / `Sys.getenv` | ✅ | ✅ **Use this pattern** |

### Environment variables required

Set once in `tfl_macros.sas` via `%set_language_paths`:

```sas
options set=PYTHONHOME "/opt/conda";
options set=PYTHONLIB  "/opt/conda/lib/libpython3.10.so";
options set=R_HOME     "/usr/lib/R";
```

Confirmed paths for the Domino compute environment:
- Python 3.10.14 (conda-forge) at `/opt/conda/bin/python`
- R 4.4.1 at `/usr/bin/R`

---

## Key SAS Features Demonstrated

| Feature | Where used |
|---|---|
| `PROC IMPORT` | `01_data_preparation.sas` — reads SDTM CSVs |
| `PROC SQL` | Data prep and all TFL programs — counts, flags, pivots |
| `PROC MEANS` / `PROC FREQ` | `t_14_1_1.sas` — continuous and categorical summaries |
| `PROC REPORT` with COMPUTE blocks | All TFL tables — conditional formatting, bold headers |
| `PROC LIFETEST` | `f_14_2_1.sas` — Kaplan-Meier survival with at-risk table |
| `PROC SGPANEL` / `PROC SGPLOT` | `f_14_2_2.sas` — waterfall and spider plots |
| ODS HTML + PDF | `00_run_all.sas` — combined timestamped report output |
| `PROC PRINTTO` | `00_run_all.sas` — separates .log and .lst output per run |
| `PROC PYTHON` | `examples/` — Python pandas processing from SAS |
| `PROC R` | `examples/` — R data frame processing from SAS |
| `%SYSGET(DOMINO_PROJECT_ROOT)` | All programs — portable path resolution on Domino |

---

## Notes

- All patient data is **entirely synthetic**, generated for demonstration purposes only.
- Variable naming follows **CDISC SDTM/ADaM conventions** (USUBJID, TRTARM, RFSTDTC,
  AETOXGR, etc.) to reflect real oncology study data structures.
- The `%set_data_path` macro automatically detects the correct CSV location across
  different Domino dataset mount configurations — no manual path changes needed.
- The `%set_language_paths` macro sets the three OS environment variables needed by
  Altair SLC to locate the Python and R runtimes.
