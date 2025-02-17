//GIMDTS   JOB #job1
//* This program and the accompanying materials are made available
//* under the terms of the Eclipse Public License v2.0 which
//* accompanies this distribution, and is available at
//* https://www.eclipse.org/legal/epl-v20.html
//*
//* SPDX-License-Identifier: EPL-2.0
//*
//* Copyright Contributors to the Zowe Project. 2019, 2019
//*********************************************************************
//* Job to create Zowe PTF/APAR/USERMOD parts in GIMDTS format
//* Assumes submitter cleaned &HLQ.** and only these data sets exist:
//* - #hlq
//* - #hlq.#mlq.*
//* - #sysprint
//*********************************************************************
//*
//*        ----+----1----+----2----+----3--
// SET HLQ=#hlq
// SET SYSOUT=#sysprint
// SET TOOL=&HLQ
// JCLLIB ORDER=&TOOL
//*
//* added by caller
//*        SET REL=#rel
//*#member EXEC PROC=PTF@LMOD,MBR=#member
//*#member EXEC PROC=PTF@FB80,MBR=#member
//*#member EXEC PROC=PTF@MVS,MBR=#member
//*
