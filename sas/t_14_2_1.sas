/*==============================================================================
  Output      : Table 14.2.1
  Title       : Best Overall Response and Objective Response Rate
  Population  : Full Analysis Set
  Program     : t_14_2_1.sas
  Prerequisite: 01_data_preparation.sas, tfl_macros.sas

  Description:
    Two-part efficacy table:
      Part A - Best Overall Response (BOR) frequency by treatment arm
      Part B - Objective Response Rate (ORR = CR + PR) with exact 95% CI
               (Clopper-Pearson method via PROC FREQ / EXACT statement)
==============================================================================*/

%tfl_setup_metadata;

/* -----------------------------------------------------------------------
   Part A: BOR frequency table
   ----------------------------------------------------------------------- */

/* Ensure BOR has all possible values (CR/PR/SD/PD) and is sorted */
proc format;
  value $BORFMT
    "CR" = "Complete Response (CR)"
    "PR" = "Partial Response (PR)"
    "SD" = "Stable Disease (SD)"
    "PD" = "Progressive Disease (PD)"
    "UNK"= "Unknown / Not Evaluable";
  value $BORSORT
    "CR"  = "1"
    "PR"  = "2"
    "SD"  = "3"
    "PD"  = "4"
    "UNK" = "5";
run;

/* Count BOR by arm */
proc sql noprint;
  create table WORK._bor_counts as
  select
    BOR,
    sum(case when TRTARM="TRTMT A" then 1 else 0 end) as N_A,
    sum(case when TRTARM="TRTMT B" then 1 else 0 end) as N_B,
    count(*) as N_TOT
  from WORK.ADSL
  where BOR ne ""
  group by BOR
  order by put(BOR,$BORSORT.);
quit;

/* Build display dataset for Part A */
data WORK._bor_display;
  length ROW_LABEL $50 COL_A COL_B COL_TOT $25 SECTION $1 SORTORD 8;
  set WORK._bor_counts;

  SECTION = "A";

  ROW_LABEL = put(BOR, $BORFMT.);
  COL_A   = ifc(N_A=0,   "0",
              cats(put(N_A,3.)," (",put(N_A/&_N_A.*100,5.1),")"));
  COL_B   = ifc(N_B=0,   "0",
              cats(put(N_B,3.)," (",put(N_B/&_N_B.*100,5.1),")"));
  COL_TOT = ifc(N_TOT=0, "0",
              cats(put(N_TOT,3.)," (",put(N_TOT/&_N_TOT.*100,5.1),")"));
  SORTORD = input(put(BOR,$BORSORT.),1.);
run;

/* Add "Responders (CR+PR)" summary row */
proc sql noprint;
  select
    sum(case when TRTARM="TRTMT A" and BOR in ("CR","PR") then 1 else 0 end),
    sum(case when TRTARM="TRTMT B" and BOR in ("CR","PR") then 1 else 0 end),
    sum(case when BOR in ("CR","PR") then 1 else 0 end)
  into :_resp_a trimmed, :_resp_b trimmed, :_resp_tot trimmed
  from WORK.ADSL;
quit;

data WORK._bor_resprow;
  length ROW_LABEL $50 COL_A COL_B COL_TOT $25 SECTION $1 SORTORD 8;
  SECTION   = "A";
  SORTORD   = 6;
  ROW_LABEL = "Responders (CR + PR)";
  COL_A   = cats(put(&_resp_a.,3.)," (",
                 put(&_resp_a./&_N_A.*100,5.1),")");
  COL_B   = cats(put(&_resp_b.,3.)," (",
                 put(&_resp_b./&_N_B.*100,5.1),")");
  COL_TOT = cats(put(&_resp_tot.,3.)," (",
                 put(&_resp_tot./&_N_TOT.*100,5.1),")");
run;

/* -----------------------------------------------------------------------
   Part B: ORR with exact 95% CI (Clopper-Pearson via PROC FREQ EXACT)
   ----------------------------------------------------------------------- */

data WORK._orr_input;
  set WORK.ADSL;
  where RESP_FL in ("Y","N");
  RESPONSE = (RESP_FL = "Y"); /* 1=responder */
run;

/* Get exact CI per arm */
ods output BinomialCLs=WORK._orr_ci;
proc freq data=WORK._orr_input;
  by TRTARM;
  tables RESPONSE / binomial(p=0.5 level="1") alpha=0.05;
  exact binomial;
run;
ods output close;

/* Reshape CI output */
proc sql noprint;
  select
    sum(case when TRTARM="TRTMT A" then Proportion else 0 end),
    sum(case when TRTARM="TRTMT A" then LowerCL    else 0 end),
    sum(case when TRTARM="TRTMT A" then UpperCL    else 0 end),
    sum(case when TRTARM="TRTMT B" then Proportion else 0 end),
    sum(case when TRTARM="TRTMT B" then LowerCL    else 0 end),
    sum(case when TRTARM="TRTMT B" then UpperCL    else 0 end)
  into :_orr_a_p trimmed, :_orr_a_l trimmed, :_orr_a_u trimmed,
       :_orr_b_p trimmed, :_orr_b_l trimmed, :_orr_b_u trimmed
  from WORK._orr_ci
  where Type = "Exact";
quit;

/* ORR rows */
data WORK._orr_display;
  length ROW_LABEL $50 COL_A COL_B COL_TOT $25 SECTION $1 SORTORD 8;

  /* ORR % row */
  SECTION="B"; SORTORD=10;
  ROW_LABEL = "ORR, % (95% CI)";
  COL_A     = cats(put(&_orr_a_p.*100,5.1),
                   " (",put(&_orr_a_l.*100,5.1),", ",put(&_orr_a_u.*100,5.1),")");
  COL_B     = cats(put(&_orr_b_p.*100,5.1),
                   " (",put(&_orr_b_l.*100,5.1),", ",put(&_orr_b_u.*100,5.1),")");

  /* Total ORR (unstratified) */
  %let _orr_tot_p = %sysevalf(&_resp_tot. / &_N_TOT.);
  COL_TOT   = cats(put(&_orr_tot_p.*100,5.1));

  output;

  /* Responders n row */
  SECTION="B"; SORTORD=11;
  ROW_LABEL = "  Responders, n";
  COL_A     = "&_resp_a.";
  COL_B     = "&_resp_b.";
  COL_TOT   = "&_resp_tot.";
  output;

  /* Evaluable n row */
  SECTION="B"; SORTORD=12;
  ROW_LABEL = "  Evaluable patients, n";
  COL_A     = "&_N_A.";
  COL_B     = "&_N_B.";
  COL_TOT   = "&_N_TOT.";
  output;
run;

/* -----------------------------------------------------------------------
   Combine into one report dataset with section dividers
   ----------------------------------------------------------------------- */
data WORK.T14_2_1_DATA;
  length ROW_LABEL $50 COL_A COL_B COL_TOT $25 SECTION $1 SORTORD 8 HDRFL 3;

  /* Section A header */
  SECTION="A"; SORTORD=0; HDRFL=1;
  ROW_LABEL="Best Overall Response (RECIST 1.1), n (%)";
  COL_A=""; COL_B=""; COL_TOT="";
  output;

  set WORK._bor_display WORK._bor_resprow;
  HDRFL=0; output;
  return;

  /* Section B header */
  SECTION="B"; SORTORD=9; HDRFL=1;
  ROW_LABEL="Objective Response Rate (ORR)";
  COL_A=""; COL_B=""; COL_TOT="";
  output;

  set WORK._orr_display;
  HDRFL=0; output;
run;

/* Re-run with proper ordering */
data WORK.T14_2_1_DATA;
  set WORK._bor_display
      WORK._bor_resprow
      WORK._orr_display;
  /* Section A header row */
  if _N_ = 1 then do;
    call missing(ROW_LABEL, COL_A, COL_B, COL_TOT);
  end;
run;

/* Build final clean stack */
data WORK.T14_2_1_FINAL;
  length ROW_LABEL $60 COL_A COL_B COL_TOT $30 HDRFL 3 SORTORD 8;

  HDRFL=1; SORTORD=-1;
  ROW_LABEL="Best Overall Response (RECIST 1.1), n (%)";
  COL_A=""; COL_B=""; COL_TOT=""; output;

  do _i=1 to 5;
    set WORK._bor_display point=_i;
    HDRFL=0; output;
  end;

  HDRFL=0; SORTORD=5.5;
  ROW_LABEL=""; COL_A=""; COL_B=""; COL_TOT=""; output; /* spacer */

  set WORK._bor_resprow;
  HDRFL=1; output;

  HDRFL=1; SORTORD=8.5;
  ROW_LABEL="Objective Response Rate (ORR)";
  COL_A=""; COL_B=""; COL_TOT=""; output;

  do _i=1 to 3;
    set WORK._orr_display point=_i;
    HDRFL=0; output;
  end;

  stop;
  drop _i;
run;

/* -----------------------------------------------------------------------
   PROC REPORT — Table 14.2.1
   ----------------------------------------------------------------------- */
%tfl_title(
  tblnum = Table 14.2.1,
  t1     = Best Overall Response and Objective Response Rate,
  t2     = RECIST Version 1.1,
  pop    = Full Analysis Set (TRTMT A: N=&_N_A.  |  TRTMT B: N=&_N_B.  |  Total: N=&_N_TOT.)
);

%tfl_footnote(
  pgmname = t_14_2_1.sas,
  extra1  = %str(CR=Complete Response; PR=Partial Response; SD=Stable Disease; PD=Progressive Disease.),
  extra2  = %str(ORR 95% CI uses the Clopper-Pearson exact method. Total column ORR is descriptive only (unstratified).)
);

proc report data=WORK.T14_2_1_FINAL
            nowd split="^"
            style(report)=[rules=groups frame=hsides cellpadding=4
                           fontfamily="Courier New" fontsize=9pt]
            style(header)=[background=cxE8E8E8 fontweight=bold just=center]
            style(column)=[just=left];

  column SORTORD HDRFL ROW_LABEL COL_A COL_B COL_TOT;

  define SORTORD   / order noprint;
  define HDRFL     / noprint;

  define ROW_LABEL / display "Response Category"
                     style(column)=[cellwidth=3.4in just=left]
                     style(header)=[just=left];

  define COL_A     / display "TRTMT A^(N=&_N_A.)"
                     style(column)=[cellwidth=1.4in just=center]
                     style(header)=[just=center];

  define COL_B     / display "TRTMT B^(N=&_N_B.)"
                     style(column)=[cellwidth=1.4in just=center]
                     style(header)=[just=center];

  define COL_TOT   / display "Total^(N=&_N_TOT.)"
                     style(column)=[cellwidth=1.4in just=center]
                     style(header)=[just=center];

  compute ROW_LABEL;
    if HDRFL = 1 then
      call define(_col_, "style/merge", "style=[fontweight=bold]");
  endcomp;

run;

%tfl_clear;
