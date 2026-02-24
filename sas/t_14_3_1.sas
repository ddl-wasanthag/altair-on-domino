/*==============================================================================
  Output      : Table 14.3.1
  Title       : Summary of Adverse Events - Safety Overview
  Population  : Safety Population
  Program     : t_14_3_1.sas
  Prerequisite: 01_data_preparation.sas, tfl_macros.sas

  Description:
    The "safety box" — the first table in every oncology safety section.
    Shows counts and percentages of subjects with:
      - Any AE
      - Any treatment-related AE
      - Any Grade 3+ AE
      - Any Grade 3+ treatment-related AE
      - Any Serious AE (SAE)
      - Any AE leading to discontinuation (proxy: Grade 4/5)
    Each row: n (%) by arm and total.
    Built with PROC REPORT compute blocks for conditional bold formatting.
==============================================================================*/

%tfl_setup_metadata;

/* -----------------------------------------------------------------------
   Step 1: Derive subject-level AE flags
   ----------------------------------------------------------------------- */
proc sort data=WORK.AE out=WORK._ae_s;  by USUBJID; run;
proc sort data=WORK.ADSL out=WORK._adsl_s; by USUBJID; run;

data WORK._ae_full;
  merge WORK._ae_s   (in=inAE)
        WORK._adsl_s (in=inADSL keep=USUBJID TRTARM);
  by USUBJID;
  if inAE and inADSL;
  RELATED = (AEREL in ("RELATED","POSSIBLY RELATED"));
run;

/* One flag per subject per category */
proc sql noprint;
  create table WORK._ae_subj_flags as
  select
    a.USUBJID,
    a.TRTARM,
    max(1)                              as AE_ANY,
    max(RELATED)                        as AE_REL,
    max(AETOXGR_N >= 3)                 as AE_G3,
    max(RELATED and AETOXGR_N >= 3)     as AE_G3_REL,
    max(AESER = "Y")                    as AE_SAE,
    max(AETOXGR_N >= 4)                 as AE_G4   /* proxy for discontinuation */
  from WORK._ae_full a
  group by a.USUBJID, a.TRTARM;
quit;

/* Include subjects with no AEs (flags = 0) */
data WORK._safety_flags;
  merge WORK._adsl_s (keep=USUBJID TRTARM)
        WORK._ae_subj_flags;
  by USUBJID;
  array flags AE_ANY AE_REL AE_G3 AE_G3_REL AE_SAE AE_G4;
  do over flags; if missing(flags) then flags=0; end;
run;

/* -----------------------------------------------------------------------
   Step 2: Compute n (%) per row category and arm
   ----------------------------------------------------------------------- */
%macro safety_row(var=, label=, sortord=);
  proc sql noprint;
    select
      sum(case when TRTARM="TRTMT A" then &var. else 0 end),
      sum(case when TRTARM="TRTMT B" then &var. else 0 end),
      sum(&var.)
    into :_n_a_&var. trimmed,
         :_n_b_&var. trimmed,
         :_n_t_&var. trimmed
    from WORK._safety_flags;
  quit;

  data WORK._row_&var.;
    length ROW_LABEL $70 COL_A COL_B COL_TOT $25 SORTORD 8 HDRFL 3;
    SORTORD   = &sortord.;
    HDRFL     = 0;
    ROW_LABEL = "&label.";
    COL_A   = cats(put(&&_n_a_&var.,3.)," (",
                   put(&&_n_a_&var./&_N_A_SAF.*100, 5.1),")");
    COL_B   = cats(put(&&_n_b_&var.,3.)," (",
                   put(&&_n_b_&var./&_N_B_SAF.*100, 5.1),")");
    COL_TOT = cats(put(&&_n_t_&var.,3.)," (",
                   put(&&_n_t_&var./&_N_TOT_SAF.*100, 5.1),")");
  run;
%mend safety_row;

%safety_row(var=AE_ANY,   label=%str(Subjects with any AE),                              sortord=10);
%safety_row(var=AE_REL,   label=%str(  Treatment-related AE),                            sortord=20);
%safety_row(var=AE_G3,    label=%str(Subjects with any Grade >=3 AE),                    sortord=30);
%safety_row(var=AE_G3_REL,label=%str(  Treatment-related Grade >=3 AE),                  sortord=40);
%safety_row(var=AE_SAE,   label=%str(Subjects with any Serious AE (SAE)),                sortord=50);
%safety_row(var=AE_G4,    label=%str(Subjects with Grade 4 or 5 AE (potential d/c)),     sortord=60);

/* Stack all rows */
data WORK.T14_3_1_DATA;
  length ROW_LABEL $70 COL_A COL_B COL_TOT $25 SORTORD 8 HDRFL 3;
  set WORK._row_AE_ANY
      WORK._row_AE_REL
      WORK._row_AE_G3
      WORK._row_AE_G3_REL
      WORK._row_AE_SAE
      WORK._row_AE_G4;
run;

/* -----------------------------------------------------------------------
   PROC REPORT — Table 14.3.1
   ----------------------------------------------------------------------- */
%tfl_title(
  tblnum = Table 14.3.1,
  t1     = Summary of Adverse Events,
  t2     = Safety Overview,
  pop    = Safety Population (TRTMT A: N=&_N_A_SAF.  |  TRTMT B: N=&_N_B_SAF.  |  Total: N=&_N_TOT_SAF.)
);

%tfl_footnote(
  pgmname = t_14_3_1.sas,
  extra1  = %str(AE = Adverse Event; SAE = Serious Adverse Event; d/c = Discontinuation.),
  extra2  = %str(Treatment-related includes "Related" and "Possibly Related" per investigator assessment.
                         CTCAE v5.0 grading. Subjects counted once per category at the maximum grade.)
);

proc report data=WORK.T14_3_1_DATA
            nowd split="^"
            style(report)=[rules=groups frame=hsides cellpadding=4
                           fontfamily="Courier New" fontsize=9pt]
            style(header)=[background=cxE8E8E8 fontweight=bold just=center]
            style(column)=[just=left];

  column SORTORD ROW_LABEL COL_A COL_B COL_TOT;

  define SORTORD   / order noprint;

  define ROW_LABEL / display "Category"
                     style(column)=[cellwidth=3.8in just=left]
                     style(header)=[just=left];

  define COL_A     / display "TRTMT A^(N=&_N_A_SAF.)"
                     style(column)=[cellwidth=1.3in just=center]
                     style(header)=[just=center];

  define COL_B     / display "TRTMT B^(N=&_N_B_SAF.)"
                     style(column)=[cellwidth=1.3in just=center]
                     style(header)=[just=center];

  define COL_TOT   / display "Total^(N=&_N_TOT_SAF.)"
                     style(column)=[cellwidth=1.3in just=center]
                     style(header)=[just=center];

  /* Bold primary (non-indented) rows */
  compute ROW_LABEL;
    if substr(strip(ROW_LABEL),1,2) ne "  " then
      call define(_col_, "style/merge", "style=[fontweight=bold]");
  endcomp;

  /* Highlight rows where Grade 3+ */
  compute COL_A;
    if SORTORD in (30,40) then
      call define(_col_, "style/merge",
                  "style=[background=cxFFF3CD]"); /* light amber */
  endcomp;
  compute COL_B;
    if SORTORD in (30,40) then
      call define(_col_, "style/merge",
                  "style=[background=cxFFF3CD]");
  endcomp;
  compute COL_TOT;
    if SORTORD in (30,40) then
      call define(_col_, "style/merge",
                  "style=[background=cxFFF3CD]");
  endcomp;

run;

%tfl_clear;
