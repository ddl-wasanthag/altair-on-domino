/*==============================================================================
  Output      : Table 14.3.2
  Title       : Adverse Events by System Organ Class and Preferred Term
  Population  : Safety Population
  Program     : t_14_3_2.sas
  Prerequisite: 01_data_preparation.sas, tfl_macros.sas

  Description:
    The standard AE incidence table — the most common table in any oncology
    safety section. Shows subjects with each AE by:
      - System Organ Class (SOC) — bold header row
      - Preferred Term (PT) — detail rows, indented under SOC
    Presented in two panels: Any Grade and Grade 3+.
    Sorted by SOC total frequency (descending), then PT total frequency.
    Subjects counted once per PT at the maximum grade.
==============================================================================*/

%tfl_setup_metadata;

/* -----------------------------------------------------------------------
   Step 1: Subject-level incidence — max one count per subject per PT
   ----------------------------------------------------------------------- */
proc sort data=WORK.AE out=WORK._ae_s; by USUBJID; run;
proc sort data=WORK.ADSL out=WORK._adsl_s; by USUBJID; run;

data WORK._ae_full;
  merge WORK._ae_s   (in=inAE)
        WORK._adsl_s (in=inADSL keep=USUBJID TRTARM);
  by USUBJID;
  if inAE and inADSL;
run;

/* Keep worst-grade record per subject per SOC/PT */
proc sort data=WORK._ae_full;
  by USUBJID AEBODSYS AEDECOD descending AETOXGR_N;
run;

data WORK._ae_worst;
  set WORK._ae_full;
  by USUBJID AEBODSYS AEDECOD;
  if first.AEDECOD; /* one row per subject per PT, worst grade */
run;

/* -----------------------------------------------------------------------
   Step 2: Count incidence by SOC/PT/arm — any grade and grade 3+
   ----------------------------------------------------------------------- */
proc sql noprint;
  /* PT level */
  create table WORK._pt_counts as
  select
    AEBODSYS  label="System Organ Class",
    AEDECOD   label="Preferred Term",
    sum(case when TRTARM="TRTMT A" then 1 else 0 end)             as PT_A_ANY,
    sum(case when TRTARM="TRTMT B" then 1 else 0 end)             as PT_B_ANY,
    count(*)                                                        as PT_T_ANY,
    sum(case when TRTARM="TRTMT A" and AETOXGR_N>=3 then 1 else 0 end) as PT_A_G3,
    sum(case when TRTARM="TRTMT B" and AETOXGR_N>=3 then 1 else 0 end) as PT_B_G3,
    sum(AETOXGR_N>=3)                                              as PT_T_G3
  from WORK._ae_worst
  group by AEBODSYS, AEDECOD;

  /* SOC level (re-aggregate, one subject may appear in multiple PTs) */
  create table WORK._soc_counts as
  select
    AEBODSYS,
    sum(case when TRTARM="TRTMT A" then 1 else 0 end)             as SOC_A_ANY,
    sum(case when TRTARM="TRTMT B" then 1 else 0 end)             as SOC_B_ANY,
    count(*)                                                        as SOC_T_ANY,
    sum(case when TRTARM="TRTMT A" and AETOXGR_N>=3 then 1 else 0 end) as SOC_A_G3,
    sum(case when TRTARM="TRTMT B" and AETOXGR_N>=3 then 1 else 0 end) as SOC_B_G3,
    sum(AETOXGR_N>=3)                                              as SOC_T_G3
  from (
    /* Distinct subject per SOC */
    select distinct USUBJID, TRTARM, AEBODSYS,
           max(AETOXGR_N) as AETOXGR_N
    from WORK._ae_worst
    group by USUBJID, TRTARM, AEBODSYS
  )
  group by AEBODSYS;
quit;

/* -----------------------------------------------------------------------
   Step 3: Sort SOCs and PTs by descending total frequency
   ----------------------------------------------------------------------- */
proc sort data=WORK._soc_counts; by descending SOC_T_ANY AEBODSYS; run;

data WORK._soc_ranks;
  set WORK._soc_counts;
  SOC_RANK = _N_;
run;

proc sort data=WORK._pt_counts; by AEBODSYS descending PT_T_ANY AEDECOD; run;

data WORK._pt_ranks;
  set WORK._pt_counts;
  by AEBODSYS;
  retain PT_RANK;
  if first.AEBODSYS then PT_RANK = 0;
  PT_RANK + 1;
run;

/* -----------------------------------------------------------------------
   Step 4: Build vertical display dataset (SOC header + PT detail rows)
   ----------------------------------------------------------------------- */
data WORK.T14_3_2_DATA;
  length ROW_LABEL $80
         COL_A_ANY COL_B_ANY COL_T_ANY
         COL_A_G3  COL_B_G3  COL_T_G3  $20
         ROWTYPE $3  SOC_RANK PT_RANK 8;

  /* ---- SOC rows ---- */
  set WORK._soc_ranks (in=inSOC rename=(AEBODSYS=_SOC))
      WORK._pt_ranks  (in=inPT  rename=(AEBODSYS=_SOC));

  if inSOC then do;
    ROWTYPE   = "SOC";
    PT_RANK   = 0;
    ROW_LABEL = strip(_SOC);

    COL_A_ANY = cats(put(SOC_A_ANY,3.)," (",put(SOC_A_ANY/&_N_A_SAF.*100,5.1),")");
    COL_B_ANY = cats(put(SOC_B_ANY,3.)," (",put(SOC_B_ANY/&_N_B_SAF.*100,5.1),")");
    COL_T_ANY = cats(put(SOC_T_ANY,3.)," (",put(SOC_T_ANY/&_N_TOT_SAF.*100,5.1),")");

    COL_A_G3  = ifc(SOC_A_G3=0,"0",cats(put(SOC_A_G3,3.)," (",put(SOC_A_G3/&_N_A_SAF.*100,5.1),")"));
    COL_B_G3  = ifc(SOC_B_G3=0,"0",cats(put(SOC_B_G3,3.)," (",put(SOC_B_G3/&_N_B_SAF.*100,5.1),")"));
    COL_T_G3  = ifc(SOC_T_G3=0,"0",cats(put(SOC_T_G3,3.)," (",put(SOC_T_G3/&_N_TOT_SAF.*100,5.1),")"));

    /* Get SOC_RANK from merge */
    output;
  end;

  if inPT then do;
    ROWTYPE   = "PT";
    ROW_LABEL = "  " || strip(AEDECOD);

    /* Get SOC_RANK for this PT */
    if _N_ = . then SOC_RANK = 999; /* fallback */

    COL_A_ANY = cats(put(PT_A_ANY,3.)," (",put(PT_A_ANY/&_N_A_SAF.*100,5.1),")");
    COL_B_ANY = cats(put(PT_B_ANY,3.)," (",put(PT_B_ANY/&_N_B_SAF.*100,5.1),")");
    COL_T_ANY = cats(put(PT_T_ANY,3.)," (",put(PT_T_ANY/&_N_TOT_SAF.*100,5.1),")");

    COL_A_G3  = ifc(PT_A_G3=0,"0",cats(put(PT_A_G3,3.)," (",put(PT_A_G3/&_N_A_SAF.*100,5.1),")"));
    COL_B_G3  = ifc(PT_B_G3=0,"0",cats(put(PT_B_G3,3.)," (",put(PT_B_G3/&_N_B_SAF.*100,5.1),")"));
    COL_T_G3  = ifc(PT_T_G3=0,"0",cats(put(PT_T_G3,3.)," (",put(PT_T_G3/&_N_TOT_SAF.*100,5.1),")"));

    output;
  end;

  keep ROW_LABEL ROWTYPE SOC_RANK PT_RANK
       COL_A_ANY COL_B_ANY COL_T_ANY
       COL_A_G3  COL_B_G3  COL_T_G3;
run;

/* Merge SOC_RANK onto PT rows */
proc sql;
  create table WORK.T14_3_2_FINAL as
  select
    coalesce(a.SOC_RANK, b.SOC_RANK) as SOC_RANK,
    a.PT_RANK,
    a.ROW_LABEL,
    a.ROWTYPE,
    a.COL_A_ANY, a.COL_B_ANY, a.COL_T_ANY,
    a.COL_A_G3,  a.COL_B_G3,  a.COL_T_G3
  from WORK.T14_3_2_DATA a
  left join WORK._soc_ranks b
    on strip(a.ROW_LABEL) = strip(b.AEBODSYS)
    and a.ROWTYPE = "SOC"
  order by coalesce(a.SOC_RANK,b.SOC_RANK), a.PT_RANK;
quit;

/* Fallback — simpler merge */
proc sort data=WORK._soc_ranks; by AEBODSYS; run;

data WORK._pt_with_socrank;
  merge WORK._pt_ranks    (in=inPT)
        WORK._soc_ranks   (in=inSOC keep=AEBODSYS SOC_RANK);
  by AEBODSYS;
  if inPT;
run;

data WORK.T14_3_2_CLEAN;
  length ROW_LABEL $80
         COL_A_ANY COL_B_ANY COL_T_ANY
         COL_A_G3  COL_B_G3  COL_T_G3  $20
         ROWTYPE $3;

  /* SOC rows */
  set WORK._soc_ranks (in=inSOC);
  ROWTYPE   = "SOC";
  PT_RANK   = 0;
  ROW_LABEL = strip(AEBODSYS);
  COL_A_ANY = cats(put(SOC_A_ANY,3.)," (",put(SOC_A_ANY/&_N_A_SAF.*100,5.1),")");
  COL_B_ANY = cats(put(SOC_B_ANY,3.)," (",put(SOC_B_ANY/&_N_B_SAF.*100,5.1),")");
  COL_T_ANY = cats(put(SOC_T_ANY,3.)," (",put(SOC_T_ANY/&_N_TOT_SAF.*100,5.1),")");
  COL_A_G3  = ifc(SOC_A_G3=0,"0",cats(put(SOC_A_G3,3.)," (",put(SOC_A_G3/&_N_A_SAF.*100,5.1),")"));
  COL_B_G3  = ifc(SOC_B_G3=0,"0",cats(put(SOC_B_G3,3.)," (",put(SOC_B_G3/&_N_B_SAF.*100,5.1),")"));
  COL_T_G3  = ifc(SOC_T_G3=0,"0",cats(put(SOC_T_G3,3.)," (",put(SOC_T_G3/&_N_TOT_SAF.*100,5.1),")"));
  output;
  keep SOC_RANK PT_RANK ROW_LABEL ROWTYPE
       COL_A_ANY COL_B_ANY COL_T_ANY COL_A_G3 COL_B_G3 COL_T_G3;
run;

data WORK._pt_rows;
  length ROW_LABEL $80
         COL_A_ANY COL_B_ANY COL_T_ANY
         COL_A_G3  COL_B_G3  COL_T_G3  $20
         ROWTYPE $3;
  set WORK._pt_with_socrank;
  ROWTYPE   = "PT";
  ROW_LABEL = "  " || strip(AEDECOD);
  COL_A_ANY = cats(put(PT_A_ANY,3.)," (",put(PT_A_ANY/&_N_A_SAF.*100,5.1),")");
  COL_B_ANY = cats(put(PT_B_ANY,3.)," (",put(PT_B_ANY/&_N_B_SAF.*100,5.1),")");
  COL_T_ANY = cats(put(PT_T_ANY,3.)," (",put(PT_T_ANY/&_N_TOT_SAF.*100,5.1),")");
  COL_A_G3  = ifc(PT_A_G3=0,"0",cats(put(PT_A_G3,3.)," (",put(PT_A_G3/&_N_A_SAF.*100,5.1),")"));
  COL_B_G3  = ifc(PT_B_G3=0,"0",cats(put(PT_B_G3,3.)," (",put(PT_B_G3/&_N_B_SAF.*100,5.1),")"));
  COL_T_G3  = ifc(PT_T_G3=0,"0",cats(put(PT_T_G3,3.)," (",put(PT_T_G3/&_N_TOT_SAF.*100,5.1),")"));
  keep SOC_RANK PT_RANK ROW_LABEL ROWTYPE
       COL_A_ANY COL_B_ANY COL_T_ANY COL_A_G3 COL_B_G3 COL_T_G3;
run;

data WORK.T14_3_2_REPORT;
  set WORK.T14_3_2_CLEAN WORK._pt_rows;
run;

proc sort data=WORK.T14_3_2_REPORT; by SOC_RANK ROWTYPE PT_RANK; run;

/* -----------------------------------------------------------------------
   PROC REPORT — Table 14.3.2
   ----------------------------------------------------------------------- */
%tfl_title(
  tblnum = Table 14.3.2,
  t1     = Adverse Events by System Organ Class and Preferred Term,
  t2     = Any Grade and Grade >=3,
  pop    = Safety Population (TRTMT A: N=&_N_A_SAF.  |  TRTMT B: N=&_N_B_SAF.  |  Total: N=&_N_TOT_SAF.)
);

%tfl_footnote(
  pgmname = t_14_3_2.sas,
  extra1  = %str(MedDRA v26.0. CTCAE v5.0 grading. Subjects counted once per preferred term at the maximum CTCAE grade.),
  extra2  = %str(SOCs and PTs sorted by descending total incidence. n (%) = number and percentage of subjects with event.)
);

proc report data=WORK.T14_3_2_REPORT
            nowd split="^"
            style(report)=[rules=groups frame=hsides cellpadding=3
                           fontfamily="Courier New" fontsize=8pt]
            style(header)=[background=cxE8E8E8 fontweight=bold just=center]
            style(column)=[just=left];

  column SOC_RANK PT_RANK ROWTYPE ROW_LABEL
         ("Any Grade"   COL_A_ANY COL_B_ANY COL_T_ANY)
         ("Grade >=3"   COL_A_G3  COL_B_G3  COL_T_G3);

  define SOC_RANK  / order noprint;
  define PT_RANK   / order noprint;
  define ROWTYPE   / noprint;

  define ROW_LABEL / display "System Organ Class / Preferred Term"
                     style(column)=[cellwidth=2.8in just=left]
                     style(header)=[just=left];

  define COL_A_ANY / display "TRTMT A^(N=&_N_A_SAF.)"
                     style(column)=[cellwidth=1.1in just=center]
                     style(header)=[just=center];
  define COL_B_ANY / display "TRTMT B^(N=&_N_B_SAF.)"
                     style(column)=[cellwidth=1.1in just=center]
                     style(header)=[just=center];
  define COL_T_ANY / display "Total^(N=&_N_TOT_SAF.)"
                     style(column)=[cellwidth=1.0in just=center]
                     style(header)=[just=center];

  define COL_A_G3  / display "TRTMT A^(N=&_N_A_SAF.)"
                     style(column)=[cellwidth=1.1in just=center]
                     style(header)=[just=center];
  define COL_B_G3  / display "TRTMT B^(N=&_N_B_SAF.)"
                     style(column)=[cellwidth=1.1in just=center]
                     style(header)=[just=center];
  define COL_T_G3  / display "Total^(N=&_N_TOT_SAF.)"
                     style(column)=[cellwidth=1.0in just=center]
                     style(header)=[just=center];

  /* Bold SOC rows */
  compute ROW_LABEL;
    if ROWTYPE = "SOC" then
      call define(_col_, "style/merge",
                  "style=[fontweight=bold background=cxF2F2F2]");
  endcomp;

run;

%tfl_clear;
