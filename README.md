# Altair SLC on Domino — Oncology SAS POC

## Overview

This POC demonstrates running existing SAS programs using **Altair SLC** as the compute
environment on **Domino Data Lab**. The scenario is a Phase II oncology clinical trial
where data scientists can read data from a Domino dataset and produce regulatory-quality
efficacy and safety outputs using standard SAS procedures.

---

## Repository Structure

```
altair/
├── data/                          # Synthetic oncology datasets (Domino Dataset source)
│   ├── patients.csv               # Patient demographics, treatment arm, survival
│   ├── tumor_measurements.csv     # RECIST target lesion sum-of-diameters over time
│   └── adverse_events.csv         # CTCAE adverse events with grade and relationship
│
├── sas/
│   ├── 00_run_all.sas             # Master driver — runs all programs in sequence
│   ├── 01_data_preparation.sas    # Reads Domino dataset CSVs, builds analysis datasets
│   ├── 02_efficacy_analysis.sas   # ORR, waterfall plot, Kaplan-Meier OS curves
│   └── 03_safety_summary.sas      # AE incidence, grade profile, SAE listing
│
├── output/                        # Generated reports (created at runtime)
│   ├── oncology_poc_report.html
│   └── oncology_poc_report.pdf
│
└── README.md
```

---

## Data Description

### `patients.csv`
20 synthetic subjects across two treatment arms (TRTMT A / TRTMT B).

| Field       | Description                                       |
|-------------|---------------------------------------------------|
| USUBJID     | Unique subject identifier                         |
| AGE / SEX / RACE | Demographics                                |
| ECOG        | ECOG Performance Status (0–2)                     |
| TRTARM      | Treatment arm (TRTMT A or TRTMT B)                |
| DTHFL       | Death flag (Y/N)                                  |
| RFSTDTC     | Start of treatment (ISO 8601)                     |
| RFENDTC     | End of treatment / last contact (ISO 8601)        |

### `tumor_measurements.csv`
RECIST target lesion sum-of-diameters (mm) at baseline and follow-up visits.

| Field       | Description                                       |
|-------------|---------------------------------------------------|
| USUBJID     | Subject identifier                                |
| VISITNUM    | Visit number (1=Baseline)                         |
| VISIT       | Visit label                                       |
| TRDTC       | Assessment date                                   |
| TRSTRESC    | Sum of target lesion diameters (mm)               |

### `adverse_events.csv`
Adverse events coded using MedDRA preferred terms with CTCAE grading.

| Field       | Description                                       |
|-------------|---------------------------------------------------|
| AETERM      | Verbatim AE term                                  |
| AEDECOD     | MedDRA preferred term                             |
| AEBODSYS    | Body system                                       |
| AETOXGR     | CTCAE toxicity grade (1–5)                        |
| AESER       | Serious AE flag (Y/N)                             |
| AEREL       | Relationship to treatment                         |
| AESTDTC     | AE start date                                     |
| AEENDTC     | AE end date                                       |
| AEOUT       | AE outcome                                        |

---

## Running on Domino

### 1. Upload the Dataset

1. In Domino, go to **Data** → **Datasets** → **Create Dataset**, name it `oncology_poc`.
2. Upload the three CSV files from `data/` into the dataset.
3. Attach the dataset to your project (read/write or read-only).

   The data will be mounted at:
   ```
   /domino/datasets/local/oncology_poc/
   ```

### 2. Upload SAS Programs

Upload the contents of `sas/` to your Domino project's file system (or sync via Git).

### 3. Run via Domino Job (Altair SLC)

Create a new **Job** in Domino with:

- **Compute Environment**: Altair SLC (the Docker image configured for your org)
- **Command**:
  ```
  sas /mnt/code/sas/00_run_all.sas
  ```
  *(Adjust the path to match where your code is mounted in the container)*

### 4. Run in a Workspace

Alternatively, open an **RStudio** or **JupyterLab** workspace with the Altair SLC
environment, open a terminal, and run:

```bash
sas /mnt/code/sas/00_run_all.sas
```

### 5. View Outputs

After the job completes, outputs are written to `output/`:
- `oncology_poc_report.html` — interactive HTML report with all tables and figures
- `oncology_poc_report.pdf` — printable PDF report

---

## What Each Program Produces

### `01_data_preparation.sas`
- Reads all three CSV files from the Domino dataset path
- Derives RECIST 1.1 response categories (CR/PR/SD/PD) per visit
- Computes overall survival duration and censoring
- Builds `WORK.ADSL` (subject-level) and `WORK.TR` (tumor) analysis datasets

### `02_efficacy_analysis.sas`
| Output | Description |
|--------|-------------|
| Table 1 | Demographic summary by treatment arm |
| Table 2 | Best Overall Response (RECIST 1.1) by arm |
| Table 3 | ORR with 95% confidence interval |
| Figure 1 | Waterfall plot — best % change from baseline |
| Figure 2 | Kaplan-Meier overall survival curves |
| Table 4 | Median OS by treatment arm |
| Table 5 | OS — responders vs non-responders |

### `03_safety_summary.sas`
| Output | Description |
|--------|-------------|
| Table 1 | Safety overview (subjects with ≥1 AE, SAE, Grade 3+) |
| Table 2 | AEs by body system and treatment arm |
| Table 3 | Top 10 most frequent AEs (any grade) |
| Table 4 | Grade 3+ AEs by term and arm |
| Table 5 | Treatment-related AEs by CTCAE grade |
| Figure 1 | Stacked bar: grade distribution of treatment-related AEs |
| Table 6 | SAE listing |
| Table 7 | Grade 4–5 AE listing |

---

## Key SAS Features Demonstrated

- `PROC IMPORT` — reading CSV files from the Domino dataset mount
- `PROC LIFETEST` — Kaplan-Meier survival curves with strata
- `PROC SGPANEL` / `PROC SGPLOT` — waterfall plots, stacked bar charts (ODS Graphics)
- `PROC TABULATE` / `PROC FREQ` / `PROC MEANS` — standard summary tables
- `%INCLUDE` — modular program execution from a master driver
- `%SYSGET(DOMINO_PROJECT_ROOT)` — environment variable to resolve paths on Domino
- ODS HTML + PDF — combined report output

---

## Notes

- All patient data is **entirely synthetic** and generated for demonstration purposes only.
- Variable naming follows **CDISC SDTM/ADaM conventions** where applicable (USUBJID,
  TRTARM, RFSTDTC, AETOXGR, etc.) to reflect real oncology study data structures.
- The path-resolution macro in `01_data_preparation.sas` automatically detects whether
  it is running on Domino or locally, requiring no manual path changes.
