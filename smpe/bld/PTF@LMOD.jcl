//*
//* PROC to stage file for SYSMOD creation, front-end for LMOD
//*
//*--------
//PTF@LMOD PROC HLQ=&HLQ,                 * work HLQ
//            REL=&REL,                   * hlq.F1, hlq.F2, ...
//            MBR=                        * member name Fx(<member>)
//*
//         SET $PDSE=&HLQ..$E.&MBR
//         SET $PDS=&HLQ..$P.&MBR
//*
//PTF@LMOD EXEC PROC=PTF@,
//*            DSP='CATLG',                * final DISP of temp files
//*            SIZE='TRK,(#trks)',        * temp file size
//* enable a step
//            UNLOAD=IKJEFT01,            * IEFBR14 (skip) or IKJEFT01
//            GIMDTS=GIMDTS               * IEFBR14 (skip) or GIMDTS
//* input
//UNLOAD.SYSUT1 DD DISP=SHR,DSN=&REL(&MBR)                 MBR optional
//*
//* allocate $PDSE work file
//MARKER.PDSE DD DISP=(NEW,CATLG),SPACE=(&SIZE,RLSE),UNIT=SYSALLDA,
#volser
//            LIKE=&REL,DSNTYPE=LIBRARY,LRECL=0,DSN=&$PDSE
//UNLOAD.PDSE DD DISP=OLD,DSN=&$PDSE
//*
//* allocate $PDS work file
//* Marist requires $PDS and $PDSE are allocated in different steps
//UNLOAD.PDS DD DISP=(NEW,CATLG),UNIT=SYSALLDA,LIKE=&$PDSE,DSN=&$PDS,
#volser
//            SPACE=(,(,,5)),DSNTYPE=PDS,LRECL=0   * LRECL=0 mandatory
//*
//* set final disposition
//DISP.PDSE DD DISP=(OLD,&DSP),DSN=&$PDSE
//DISP.PDS DD DISP=(OLD,&DSP),DSN=&$PDS
//*
//         PEND
//*--------
//*
