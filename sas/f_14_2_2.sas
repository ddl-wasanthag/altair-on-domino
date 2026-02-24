/*==============================================================================
  Output      : Figure 14.2.2 (Waterfall) and Figure 14.2.3 (Spider)
  Title       : Best Percent Change from Baseline / Change Over Time
  Population  : Full Analysis Set (evaluable subjects)
  Program     : f_14_2_2.sas
  Prerequisite: 01_data_preparation.sas, tfl_macros.sas

  Description:
    Figure 14.2.2 — Waterfall Plot
      Classic oncology bar chart: one bar per subject sorted by best %
      change from baseline. Bars below zero = tumour shrinkage.
      RECIST threshold lines at -30% (PR) and +20% (PD).
      Bars colour-coded by Best Overall Response (BOR).

    Figure 14.2.3 — Spider Plot (Tumour Change Over Time)
      Each line = one patient's % change from baseline over time.
      Useful for showing trajectory — how quickly tumours responded or
      progressed. Lines colour-coded by treatment arm.
==============================================================================*/

%tfl_setup_metadata;

/* -----------------------------------------------------------------------
   Prepare data: exclude baseline row, require at least one post-BL value
   ----------------------------------------------------------------------- */

/* Waterfall: best pct change per subject */
data WORK._wf_data;
  merge WORK.ADSL (in=inADSL keep=USUBJID TRTARM BOR BESTPCHG)
        WORK.ADSL (in=inADSL);
  by USUBJID;
  if inADSL and BESTPCHG ne .;
run;

proc sort data=WORK._wf_data; by TRTARM BESTPCHG; run;

data WORK._wf_plot;
  set WORK._wf_data;
  by TRTARM;
  retain RANK_A 0 RANK_B 0;
  if TRTARM = "TRTMT A" then do; RANK_A+1; SUBJ_RANK=RANK_A; end;
  else                        do; RANK_B+1; SUBJ_RANK=RANK_B; end;

  /* Colour group based on BOR */
  length BOR_COLOR $20;
  select (BOR);
    when ("CR") BOR_COLOR = "Complete Response";
    when ("PR") BOR_COLOR = "Partial Response";
    when ("SD") BOR_COLOR = "Stable Disease";
    when ("PD") BOR_COLOR = "Progressive Disease";
    otherwise   BOR_COLOR = "Unknown";
  end;
run;

/* Spider: % change at each visit (post-baseline only) */
data WORK._spider_data;
  merge WORK.TR    (in=inTR  where=(VISITNUM > 1))
        WORK.ADSL  (in=inADSL keep=USUBJID TRTARM);
  by USUBJID;
  if inTR and inADSL and PCHG_BL ne .;
run;

/* -----------------------------------------------------------------------
   Figure 14.2.2 — Waterfall Plot
   ----------------------------------------------------------------------- */
%tfl_title(
  tblnum = Figure 14.2.2,
  t1     = Waterfall Plot: Best Percent Change from Baseline in,
  t2     = Sum of Target Lesion Diameters by Treatment Arm,
  pop    = Full Analysis Set — Evaluable Subjects with Post-Baseline Assessment
);

%tfl_footnote(
  pgmname = f_14_2_2.sas,
  extra1  = %str(Each bar represents one subject. Subjects are ranked by best percent change within each arm.),
  extra2  = %str(Dashed lines denote RECIST 1.1 thresholds: -30% (Partial Response), +20% (Progressive Disease).)
);

ods graphics on / reset=all width=11in height=5.5in
                  imagename="f_14_2_2" imagefmt=png;

proc sgpanel data=WORK._wf_plot;
  panelby TRTARM / layout=rowlattice novarname
                   headerattrs=(size=10pt weight=bold);

  vbar SUBJ_RANK / response=BESTPCHG
                   group=BOR_COLOR
                   groupdisplay=cluster
                   fillattrs=(transparency=0.1)
                   nooutline;

  refline -30 / axis=y
                lineattrs=(color=cx2CA02C pattern=dash thickness=1.5px)
                label="PR threshold (-30%)"
                labelloc=outside;

  refline  20 / axis=y
                lineattrs=(color=cxD62728 pattern=dash thickness=1.5px)
                label="PD threshold (+20%)"
                labelloc=outside;

  refline   0 / axis=y
                lineattrs=(color=black pattern=solid thickness=0.5px);

  rowaxis label="Best % Change from Baseline"
          values=(-100 to 60 by 20)
          grid gridattrs=(pattern=dot color=cxCCCCCC);

  colaxis label="Subject (ranked by % change)" display=(novalues noticks nolabel);

  keylegend / title="Best Overall Response (RECIST 1.1)"
              position=bottomleft;
run;

ods graphics off;
%tfl_clear;

/* -----------------------------------------------------------------------
   Figure 14.2.3 — Spider Plot
   ----------------------------------------------------------------------- */
%tfl_title(
  tblnum = Figure 14.2.3,
  t1     = Spider Plot: Percent Change from Baseline over Time,
  t2     = Sum of Target Lesion Diameters by Treatment Arm,
  pop    = Full Analysis Set — Evaluable Subjects with Post-Baseline Assessment
);

%tfl_footnote(
  pgmname = f_14_2_2.sas,
  extra1  = %str(Each line represents one subject. Visit nominal week on the x-axis.),
  extra2  = %str(Dashed lines denote RECIST 1.1 thresholds: -30% (Partial Response), +20% (Progressive Disease).)
);

ods graphics on / reset=all width=11in height=5.5in
                  imagename="f_14_2_3" imagefmt=png;

proc sgpanel data=WORK._spider_data;
  panelby TRTARM / layout=rowlattice novarname
                   headerattrs=(size=10pt weight=bold);

  series x=TRNOMINAL y=PCHG_BL / group=USUBJID
                                  lineattrs=(thickness=1.5px)
                                  markers
                                  markerattrs=(symbol=circlefilled size=5px);

  refline -30 / axis=y
                lineattrs=(color=cx2CA02C pattern=dash thickness=1.5px)
                label="PR (-30%)" labelloc=outside;

  refline  20 / axis=y
                lineattrs=(color=cxD62728 pattern=dash thickness=1.5px)
                label="PD (+20%)" labelloc=outside;

  refline   0 / axis=y
                lineattrs=(color=black pattern=solid thickness=0.5px);

  rowaxis label="% Change from Baseline"
          values=(-80 to 80 by 20)
          grid gridattrs=(pattern=dot color=cxCCCCCC);

  colaxis label="Time from Randomisation (weeks)"
          values=(0 to 240 by 56)
          valuesdisplay=("0" "8" "16" "24" "32" "40");

  keylegend / exclude=(""); /* individual subject lines — suppress legend */
run;

ods graphics off;
%tfl_clear;
