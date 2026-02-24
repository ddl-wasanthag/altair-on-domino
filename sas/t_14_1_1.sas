/*==============================================================================
  Output      : Table 14.1.1
  Title       : Demographic and Baseline Characteristics
  Population  : Full Analysis Set
  Program     : t_14_1_1.sas
  Prerequisite: 01_data_preparation.sas, tfl_macros.sas

  Description:
    Produces a standard demographics and baseline characteristics table with
    columns for each treatment arm and total. Rows cover continuous variables
    (Age) summarised with n/mean/SD/median/min-max, and categorical variables
    (Age Group, Sex, Race, ECOG) summarised with n (%).
    Built entirely with PROC REPORT using COMPUTE blocks for n(%) formatting.
==============================================================================*/

%tfl_setup_metadata;

/* -----------------------------------------------------------------------
   Step 1: Build a report-ready "shell" dataset
   Approach: pre-compute all statistics, then stack into a
   vertical display dataset (one row per display line).
   Columns: ROW_LABEL, COL_A, COL_B, COL_TOT, SORTORD, INDENT
   ----------------------------------------------------------------------- */

/* --- Continuous: Age --- */
proc means data=WORK.ADSL noprint;
  class TRTARM;
  var AGE;
  output out=WORK._age_stats (drop=_TYPE_)
         n=AGE_N mean=AGE_MEAN std=AGE_STD
         median=AGE_MED min=AGE_MIN max=AGE_MAX;
run;

/* Pivot to columns */
proc transpose data=WORK._age_stats(where=(TRTARM ne ""))
               out=WORK._age_A (drop=_NAME_ _LABEL_)
               prefix=A_;
  id TRTARM;
  var AGE_N AGE_MEAN AGE_STD AGE_MED AGE_MIN AGE_MAX;
run;

proc means data=WORK.ADSL noprint;
  var AGE;
  output out=WORK._age_tot (drop=_TYPE_ _FREQ_)
         n=AGE_N mean=AGE_MEAN std=AGE_STD
         median=AGE_MED min=AGE_MIN max=AGE_MAX;
run;

/* Build age block rows */
data WORK._age_rows;
  length ROW_LABEL $60 COL_A COL_B COL_TOT $30;

  /* Pre-read arm stats */
  set WORK._age_stats end=eof;
  by _FREQ_ notsorted;

  /* Arrays for arm stats */
  array _n    {2}  _temporary_;
  array _mean {2}  _temporary_;
  array _std  {2}  _temporary_;
  array _med  {2}  _temporary_;
  array _min  {2}  _temporary_;
  array _max  {2}  _temporary_;

  retain _idx 0;

  if TRTARM ne "" then do;
    _idx + 1;
    if TRTARM = "TRTMT A" then do;
      _n[1]=AGE_N; _mean[1]=AGE_MEAN; _std[1]=AGE_STD;
      _med[1]=AGE_MED; _min[1]=AGE_MIN; _max[1]=AGE_MAX;
    end;
    else do;
      _n[2]=AGE_N; _mean[2]=AGE_MEAN; _std[2]=AGE_STD;
      _med[2]=AGE_MED; _min[2]=AGE_MIN; _max[2]=AGE_MAX;
    end;
  end;

  if eof then do;
    /* Get total stats */
    set WORK._age_tot;

    SORTORD=10; INDENT=0;
    ROW_LABEL="Age (years)"; COL_A=""; COL_B=""; COL_TOT=""; output;

    SORTORD=11; INDENT=1;
    ROW_LABEL="  n";
    COL_A   = strip(put(_n[1],3.));
    COL_B   = strip(put(_n[2],3.));
    COL_TOT = strip(put(AGE_N,3.));
    output;

    SORTORD=12; INDENT=1;
    ROW_LABEL="  Mean (SD)";
    COL_A   = cats(put(_mean[1],5.1)," (",put(_std[1],4.1),")");
    COL_B   = cats(put(_mean[2],5.1)," (",put(_std[2],4.1),")");
    COL_TOT = cats(put(AGE_MEAN,5.1)," (",put(AGE_STD,4.1),")");
    output;

    SORTORD=13; INDENT=1;
    ROW_LABEL="  Median";
    COL_A   = put(_med[1],5.1);
    COL_B   = put(_med[2],5.1);
    COL_TOT = put(AGE_MED,5.1);
    output;

    SORTORD=14; INDENT=1;
    ROW_LABEL="  Min, Max";
    COL_A   = cats(put(_min[1],3.)," , ",put(_max[1],3.));
    COL_B   = cats(put(_min[2],3.)," , ",put(_max[2],3.));
    COL_TOT = cats(put(AGE_MIN,3.)," , ",put(AGE_MAX,3.));
    output;
  end;
  keep ROW_LABEL COL_A COL_B COL_TOT SORTORD INDENT;
run;

/* --- Categorical helper macro: one block per variable --- */
%macro cat_block(var=, label=, fmt=, sortstart=);

  /* Count per arm */
  proc freq data=WORK.ADSL noprint;
    tables TRTARM * &var. / out=WORK._freq_arm (drop=PERCENT) sparse;
  run;

  /* Count per arm total N */
  proc sql noprint;
    create table WORK._cat_rows_&var. as
    select
      b.&var. as CAT_VAL length=50,
      "&label."              as VAR_LABEL length=60,
      coalesce(a_cnt, 0)     as N_A,
      coalesce(b_cnt, 0)     as N_B,
      coalesce(a_cnt,0) + coalesce(b_cnt,0) as N_TOT,
      &sortstart. + monotonic() as SORTORD
    from
      (select distinct &var. from WORK.ADSL) b
    left join
      (select &var., count as a_cnt from WORK._freq_arm
       where TRTARM="TRTMT A") a on a.&var. = b.&var.
    left join
      (select &var., count as b_cnt from WORK._freq_arm
       where TRTARM="TRTMT B") c on c.&var. = b.&var.
    order by b.&var.;
  quit;

  data WORK._cat_display_&var.;
    length ROW_LABEL $60 COL_A COL_B COL_TOT $30;
    set WORK._cat_rows_&var.;

    /* Header row */
    if _N_ = 1 then do;
      ROW_LABEL = VAR_LABEL || ", n (%)";
      COL_A=""; COL_B=""; COL_TOT="";
      SORTORD = &sortstart.;
      INDENT = 0;
      output;
    end;

    /* Detail row */
    ROW_LABEL = "  " || strip(CAT_VAL);
    COL_A   = ifc(N_A=0,   "0",
                cats(put(N_A,3.)," (",put(N_A/&_N_A.*100,5.1),")"));
    COL_B   = ifc(N_B=0,   "0",
                cats(put(N_B,3.)," (",put(N_B/&_N_B.*100,5.1),")"));
    COL_TOT = ifc(N_TOT=0, "0",
                cats(put(N_TOT,3.)," (",put(N_TOT/&_N_TOT.*100,5.1),")"));
    INDENT  = 1;
    output;
    keep ROW_LABEL COL_A COL_B COL_TOT SORTORD INDENT;
  run;

%mend cat_block;

%cat_block(var=AGEGR1, label=Age Group,              sortstart=20);
%cat_block(var=SEX,    label=Sex,                    sortstart=30);
%cat_block(var=RACE,   label=Race,                   sortstart=40);
%cat_block(var=ECOG_C, label=ECOG Performance Status,sortstart=50);

/* Stack all blocks */
data WORK.T14_1_1_DATA;
  set WORK._age_rows
      WORK._cat_display_AGEGR1
      WORK._cat_display_SEX
      WORK._cat_display_RACE
      WORK._cat_display_ECOG_C;
run;

proc sort data=WORK.T14_1_1_DATA; by SORTORD; run;

/* -----------------------------------------------------------------------
   Step 2: PROC REPORT — Table 14.1.1
   ----------------------------------------------------------------------- */
%tfl_title(
  tblnum = Table 14.1.1,
  t1     = Demographic and Baseline Characteristics,
  pop    = Full Analysis Set (TRTMT A: N=&_N_A.  |  TRTMT B: N=&_N_B.  |  Total: N=&_N_TOT.)
);

%tfl_footnote(
  pgmname = t_14_1_1.sas,
  extra1  = %str(ECOG = Eastern Cooperative Oncology Group Performance Status.
                        SD = Standard Deviation.),
  extra2  = %str(Percentages are based on the number of subjects in each treatment arm.)
);

proc report data=WORK.T14_1_1_DATA
            nowd
            split="^"
            style(report)=[rules=groups frame=hsides cellpadding=4
                           fontfamily="Courier New" fontsize=9pt]
            style(header)=[background=cxE8E8E8 fontweight=bold just=center]
            style(column)=[just=left];

  column SORTORD INDENT ROW_LABEL COL_A COL_B COL_TOT;

  define SORTORD   / order noprint;
  define INDENT    / noprint;

  define ROW_LABEL / display
                     "Characteristic"
                     style(column)=[cellwidth=3.2in just=left]
                     style(header)=[just=left];

  define COL_A     / display
                     "TRTMT A^(N=&_N_A.)"
                     style(column)=[cellwidth=1.5in just=center]
                     style(header)=[just=center];

  define COL_B     / display
                     "TRTMT B^(N=&_N_B.)"
                     style(column)=[cellwidth=1.5in just=center]
                     style(header)=[just=center];

  define COL_TOT   / display
                     "Total^(N=&_N_TOT.)"
                     style(column)=[cellwidth=1.5in just=center]
                     style(header)=[just=center];

  /* Bold the header (non-indented) rows */
  compute ROW_LABEL;
    if INDENT = 0 and strip(COL_A) = "" then
      call define(_col_, "style/merge",
                  "style=[fontweight=bold]");
  endcomp;

run;

%tfl_clear;
