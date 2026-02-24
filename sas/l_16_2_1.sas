/*==============================================================================
  Output      : Listing 16.2.1 and Listing 16.2.2
  Title       : Listing of Serious Adverse Events / Listing of Deaths
  Population  : Safety Population
  Program     : l_16_2_1.sas
  Prerequisite: 01_data_preparation.sas, tfl_macros.sas

  Description:
    Listings are patient-level data presented row by row — every SAE and
    every death with full details. Regulators use these to trace individual
    patient narratives.

    Listing 16.2.1 — All Serious Adverse Events (SAEs)
      One row per SAE. Sorted by treatment arm, subject, AE start date.
      Columns: Subject, Arm, AE Term, Body System, Grade, Relationship,
               Serious, Start Date, End Date, Outcome.

    Listing 16.2.2 — Deaths
      One row per deceased subject. Columns: Subject, Arm, Age, ECOG,
      Death Date, OS (days), Primary cause (proxied from SAE data).
==============================================================================*/

%tfl_setup_metadata;

/* -----------------------------------------------------------------------
   Prepare SAE listing data
   ----------------------------------------------------------------------- */
proc sort data=WORK.AE out=WORK._ae_s; by USUBJID; run;
proc sort data=WORK.ADSL out=WORK._adsl_s; by USUBJID; run;

data WORK._ae_listing;
  merge WORK._ae_s   (in=inAE)
        WORK._adsl_s (in=inADSL keep=USUBJID TRTARM);
  by USUBJID;
  if inAE and inADSL and AESER = "Y";

  /* Format dates for display */
  /* AESTDTC/AEENDTC are numeric SAS dates — format to character for display */
  length AESTDTC_D AEENDTC_D $12;
  AESTDTC_D = ifc(AESTDTC ne ., put(AESTDTC, date9.), "Ongoing");
  AEENDTC_D = ifc(AEENDTC ne ., put(AEENDTC, date9.), "Ongoing");

  /* Shorten outcome for display */
  length AEOUT_S $30;
  select;
    when (AEOUT = "RECOVERED/RESOLVED")               AEOUT_S = "Resolved";
    when (AEOUT = "RECOVERED/RESOLVED WITH SEQUELAE") AEOUT_S = "Resolved w/ sequelae";
    when (AEOUT = "NOT RECOVERED/NOT RESOLVED")        AEOUT_S = "Not resolved";
    when (AEOUT = "FATAL")                             AEOUT_S = "Fatal";
    otherwise                                          AEOUT_S = strip(AEOUT);
  end;

  /* Grade description */
  length GRADE_DESC $25;
  /* AETOXGR_N is numeric — use numeric comparisons */
  select (AETOXGR_N);
    when (1) GRADE_DESC = "Grade 1 (Mild)";
    when (2) GRADE_DESC = "Grade 2 (Moderate)";
    when (3) GRADE_DESC = "Grade 3 (Severe)";
    when (4) GRADE_DESC = "Grade 4 (Life-Threatening)";
    when (5) GRADE_DESC = "Grade 5 (Fatal)";
    otherwise GRADE_DESC = "Unknown";
  end;

  label
    USUBJID    = "Subject ID"
    TRTARM     = "Treatment Arm"
    AEDECOD    = "Preferred Term"
    AEBODSYS   = "System Organ Class"
    GRADE_DESC = "CTCAE Grade"
    AEREL      = "Relationship to Treatment"
    AESTDTC_D  = "Start Date"
    AEENDTC_D  = "End Date"
    AEOUT_S    = "Outcome";
run;

proc sort data=WORK._ae_listing; by TRTARM USUBJID AESTDTC_D; run;

/* -----------------------------------------------------------------------
   Listing 16.2.1 — SAE Listing
   ----------------------------------------------------------------------- */
%tfl_title(
  tblnum = Listing 16.2.1,
  t1     = Listing of Serious Adverse Events (SAEs),
  pop    = Safety Population
);

%tfl_footnote(
  pgmname = l_16_2_1.sas,
  extra1  = %str(SAE = Serious Adverse Event. MedDRA v26.0 coding. CTCAE v5.0 grading.),
  extra2  = %str(Treatment-related includes "Related" and "Possibly Related" per investigator assessment.
                         Sorted by treatment arm, subject ID, and AE start date.)
);

proc report data=WORK._ae_listing
            nowd split="^"
            style(report)=[rules=groups frame=hsides cellpadding=3
                           fontfamily="Courier New" fontsize=8pt]
            style(header)=[background=cxE8E8E8 fontweight=bold just=center]
            style(column)=[just=left];

  column TRTARM USUBJID AEDECOD AEBODSYS GRADE_DESC AEREL
         AESTDTC_D AEENDTC_D AEOUT_S;

  define TRTARM     / order "Treatment^Arm"
                      style(column)=[cellwidth=0.8in just=center]
                      style(header)=[just=center];

  define USUBJID    / order "Subject ID"
                      style(column)=[cellwidth=1.1in just=left];

  define AEDECOD    / display "Preferred Term"
                      style(column)=[cellwidth=1.6in just=left];

  define AEBODSYS   / display "System Organ^Class"
                      style(column)=[cellwidth=1.7in just=left];

  define GRADE_DESC / display "CTCAE Grade"
                      style(column)=[cellwidth=1.3in just=left];

  define AEREL      / display "Relationship"
                      style(column)=[cellwidth=1.1in just=left];

  define AESTDTC_D  / display "Start Date"
                      style(column)=[cellwidth=0.8in just=center]
                      style(header)=[just=center];

  define AEENDTC_D  / display "End Date"
                      style(column)=[cellwidth=0.8in just=center]
                      style(header)=[just=center];

  define AEOUT_S    / display "Outcome"
                      style(column)=[cellwidth=1.2in just=left];

  /* Alternating row shading by subject */
  compute TRTARM;
    if mod(_N_,2)=0 then
      call define(_row_, "style/merge",
                  "style=[background=cxF7F7F7]");
  endcomp;

  /* Highlight Grade 4+ in red */
  compute GRADE_DESC;
    if index(GRADE_DESC,"Grade 4") > 0 or
       index(GRADE_DESC,"Grade 5") > 0 then
      call define(_col_, "style/merge",
                  "style=[color=cxCC0000 fontweight=bold]");
  endcomp;

  break after TRTARM / skip;

run;

%tfl_clear;

/* -----------------------------------------------------------------------
   Prepare Deaths listing
   ----------------------------------------------------------------------- */
data WORK._deaths_listing;
  set WORK.ADSL;
  where DTHFL = "Y";

  /* Format death date */
  /* DTHDTC is a numeric SAS date — assign directly */
  if DTHDTC ne . then DTHDTC_D = DTHDTC;
  format DTHDTC_D date9.;

  label
    USUBJID   = "Subject ID"
    TRTARM    = "Treatment Arm"
    AGE       = "Age (years)"
    SEX       = "Sex"
    ECOG      = "ECOG PS"
    OS_DAYS   = "OS Duration^(days)"
    DTHDTC_D  = "Date of Death";

  keep USUBJID TRTARM AGE SEX ECOG RANDDATE_DT DTHDTC_D OS_DAYS;
run;

proc sort data=WORK._deaths_listing; by TRTARM USUBJID; run;

/* -----------------------------------------------------------------------
   Listing 16.2.2 — Deaths Listing
   ----------------------------------------------------------------------- */
%tfl_title(
  tblnum = Listing 16.2.2,
  t1     = Listing of Deaths,
  pop    = Safety Population
);

%tfl_footnote(
  pgmname = l_16_2_1.sas,
  extra1  = %str(OS = Overall Survival. Duration calculated from date of randomisation to date of death.),
  extra2  = %str(ECOG PS = Eastern Cooperative Oncology Group Performance Status at baseline.
                         Sorted by treatment arm and subject ID.)
);

proc report data=WORK._deaths_listing
            nowd split="^"
            style(report)=[rules=groups frame=hsides cellpadding=3
                           fontfamily="Courier New" fontsize=8pt]
            style(header)=[background=cxE8E8E8 fontweight=bold just=center]
            style(column)=[just=left];

  column TRTARM USUBJID AGE SEX ECOG RANDDATE_DT DTHDTC_D OS_DAYS;

  define TRTARM      / order "Treatment^Arm"
                       style(column)=[cellwidth=0.9in just=center]
                       style(header)=[just=center];

  define USUBJID     / display "Subject ID"
                       style(column)=[cellwidth=1.2in just=left];

  define AGE         / display "Age^(years)"
                       style(column)=[cellwidth=0.6in just=center]
                       style(header)=[just=center];

  define SEX         / display "Sex"
                       style(column)=[cellwidth=0.5in just=center]
                       style(header)=[just=center];

  define ECOG        / display "ECOG^PS"
                       style(column)=[cellwidth=0.6in just=center]
                       style(header)=[just=center];

  define RANDDATE_DT / display "Randomisation^Date"
                       format=date9.
                       style(column)=[cellwidth=1.0in just=center]
                       style(header)=[just=center];

  define DTHDTC_D    / display "Date of^Death"
                       format=date9.
                       style(column)=[cellwidth=1.0in just=center]
                       style(header)=[just=center];

  define OS_DAYS     / display "OS^(days)"
                       style(column)=[cellwidth=0.7in just=center]
                       style(header)=[just=center];

  break after TRTARM / skip;

run;

%tfl_clear;
