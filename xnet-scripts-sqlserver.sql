IF COL_LENGTH('dbo.a_User', 'PASSWORDHASH') IS NULL
    ALTER TABLE dbo.a_User ADD PASSWORDHASH VARCHAR(200) NULL;
GO

IF COL_LENGTH('dbo.a_User', 'PASSWORDVERSION') IS NULL
    ALTER TABLE dbo.a_User ADD PASSWORDVERSION INT NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID('dbo.G_STATE') AND name = 'VERSION')
BEGIN
    ALTER TABLE dbo.G_STATE
        ADD VERSION int NOT NULL CONSTRAINT DF_G_STATE_VERSION DEFAULT 0;
END;
GO
IF OBJECT_ID('mfa_otp') IS NULL
    CREATE TABLE mfa_otp
    (
        id               INT IDENTITY(1,1) PRIMARY KEY,
        [TimeStamp]      DATETIME DEFAULT GETDATE(),
        RefId            VARCHAR(100),
        OTPHash          VARBINARY(8000),
        OTPFor           VARCHAR(1000),
        ValidTo          DATETIME,
        Tag1             VARCHAR(1000),
        Attempt          INT DEFAULT 0,
        UsedAt           DATETIME NULL,
        Param1           VARCHAR(1000),
        CreatedBy        VARCHAR(1000),
        CreatedOn        DATETIME DEFAULT GETDATE(),
        LastModifiedBy   VARCHAR(1000) NULL,
        LastModifiedOn   DATETIME NULL
    );
GO

IF OBJECT_ID('mfa_otp') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.indexes
                   WHERE object_id = OBJECT_ID('dbo.mfa_otp') AND name = 'IX_mfa_otp_RefId')
    CREATE NONCLUSTERED INDEX IX_mfa_otp_RefId ON dbo.mfa_otp (RefId);
GO

-- =====================================================================
-- bit -> int
-- =====================================================================

-- ---------------------------------------------------------------------
-- CONVENTION: flag columns are INT (0/1) on all three providers -- never BIT,
-- NUMBER(1) or BOOLEAN. Entities carry them as int? / CoreDataType.Int32.
--
-- Why: Oracle's managed provider cannot bind a CLR bool (ORA-00932), so a bool
-- property forces the DAL to translate on the way in and out. Storing the flag
-- as INT removes the translation entirely -- what the code holds is what the
-- column holds, identically on SQL Server, Oracle (NUMBER(10,0)) and
-- PostgreSQL (INTEGER).
--
-- This applies to NEW tables too, not just conversions -- see CBS_OTP.ISUSED,
-- B_USERSWITCHLOGTIME.ISOFFLINE, A_BRLOGINACCESSTIME.ISACTIVE and
-- K_LOCKERRENTDISC.ISACTIVESCDISC further down this file.
--
-- Note: the TflOmniDb docs map BIT -> Boolean -> NUMBER(1,0) -> BOOLEAN. That is
-- the library default, NOT this project's convention. INT wins here.
--
-- OPEN: none of these INT flags carry CHECK (col IN (0,1)). BIT enforced 0/1 for
-- free; INT does not, on any provider. Worth adding -- additive, no code change.
--
-- STILL ON BIT: 83 flag columns across 27 tables the code uses today (and ~2700
-- more schema-wide). The 83 get the same bit -> INT treatment as the 9 below,
-- in a separate script -- NOT included here, run it on its own:
--
--     scripts/bit-to-int.sqlserver.sql
--
-- Same shape as this section: pre-flight blocker query, drop 1 index + 4 DEFAULT
-- constraints, 83 guarded ALTER COLUMN ... INT, recreate, verify. Idempotent.
-- SQL Server only -- Oracle already holds all 83 as NUMBER(10,0), which is what
-- CoreDataType.Int32 renders to, so there is no Oracle twin.
-- After running it: regenerate TflCbs.Entities for those 27 tables (bool? ->
-- int?) and fix the call sites (== true -> == 1), or the build breaks.
-- ---------------------------------------------------------------------


--index drop for bit-->int

;WITH target(tbl, col) AS (
    SELECT    *  FROM (VALUES
        ('dbo.b_WorkingDate',   'DAYENDFLAG'),
        ('dbo.b_UserLogTime',   'ISOFFLINE'),
        ('dbo.b_FinancialYear', 'YEARCOMPLETIONFLAG'),
        ('dbo.a_Menus',         'ISACTIVE'),
        ('dbo.a_Menus',         'ISREPORT'),
        ('dbo.a_Module',        'ISACTIVE'),
        ('dbo.g_Taluka',        'ISACTIVE'),
        ('dbo.g_AccountHead',   'ISACTIVE')
    ) v(tbl, col)
)
SELECT 'drop index '+t.tbl+'.'+blocker, t.tbl, t.col, b.blocker
FROM target t
CROSS APPLY (
    SELECT 'replicated article' AS blocker
      FROM sys.tables s
     WHERE s.object_id = OBJECT_ID(t.tbl)
       AND (s.is_published = 1 OR s.is_merge_published = 1)
    UNION ALL
    SELECT   i.name
      FROM sys.index_columns ic
      JOIN sys.indexes i ON i.object_id = ic.object_id AND i.index_id = ic.index_id
      JOIN sys.columns  c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
     WHERE ic.object_id = OBJECT_ID(t.tbl) AND c.name = t.col
    UNION ALL
    SELECT 'check constraint ' + cc.name
      FROM sys.check_constraints cc
      JOIN sys.columns c ON c.object_id = cc.parent_object_id
                        AND c.column_id = cc.parent_column_id
     WHERE cc.parent_object_id = OBJECT_ID(t.tbl) AND c.name = t.col
    UNION ALL
    SELECT 'computed column'
      FROM sys.columns c
     WHERE c.object_id = OBJECT_ID(t.tbl) AND c.name = t.col AND c.is_computed = 1
   
) b;
GO

-- Drop the DEFAULT constraints for bit-->int

IF OBJECT_ID('tempdb..#bitdefaults') IS NOT NULL DROP TABLE #bitdefaults;

CREATE TABLE #bitdefaults
(
    tbl        SYSNAME,
    col        SYSNAME,
    dc_name    SYSNAME,
    definition NVARCHAR(4000)
);

INSERT INTO #bitdefaults (tbl, col, dc_name, definition)
SELECT t.tbl, t.col, dc.name, dc.definition
FROM (VALUES
    ('dbo.b_WorkingDate',   'DAYENDFLAG'),
    ('dbo.b_UserLogTime',   'ISOFFLINE'),
    ('dbo.b_FinancialYear', 'YEARCOMPLETIONFLAG'),
    ('dbo.a_Menus',         'ISACTIVE'),
    ('dbo.a_Menus',         'ISREPORT'),
    ('dbo.a_Module',        'ISACTIVE'),
    ('dbo.g_Taluka',        'ISACTIVE'),
    ('dbo.g_AccountHead',   'ISACTIVE')
) t(tbl, col)
JOIN sys.columns c              ON c.object_id = OBJECT_ID(t.tbl) AND c.name = t.col
JOIN sys.default_constraints dc ON dc.parent_object_id = c.object_id
                               AND dc.parent_column_id = c.column_id;

 
SELECT tbl, col, dc_name, definition FROM #bitdefaults;

DECLARE @drop NVARCHAR(MAX) = N'';
SELECT @drop = @drop + N'ALTER TABLE ' + tbl
                     + N' DROP CONSTRAINT ' + QUOTENAME(dc_name) + N';' + CHAR(10)
FROM #bitdefaults;
PRINT @drop;
EXEC sys.sp_executesql @drop;
GO

 

IF EXISTS (SELECT 1 FROM sys.columns
           WHERE object_id = OBJECT_ID('dbo.b_WorkingDate')
             AND name = 'DAYENDFLAG' AND system_type_id = TYPE_ID('bit'))
    ALTER TABLE dbo.b_WorkingDate ALTER COLUMN DAYENDFLAG INT NOT NULL;
GO

IF EXISTS (SELECT 1 FROM sys.columns
           WHERE object_id = OBJECT_ID('dbo.b_UserLogTime')
             AND name = 'ISOFFLINE' AND system_type_id = TYPE_ID('bit'))
    ALTER TABLE dbo.b_UserLogTime ALTER COLUMN ISOFFLINE INT NOT NULL;
GO

IF EXISTS (SELECT 1 FROM sys.columns
           WHERE object_id = OBJECT_ID('dbo.b_FinancialYear')
             AND name = 'YEARCOMPLETIONFLAG' AND system_type_id = TYPE_ID('bit'))
    ALTER TABLE dbo.b_FinancialYear ALTER COLUMN YEARCOMPLETIONFLAG INT NOT NULL;
GO

IF EXISTS (SELECT 1 FROM sys.columns
           WHERE object_id = OBJECT_ID('dbo.a_Menus')
             AND name = 'ISACTIVE' AND system_type_id = TYPE_ID('bit'))
    ALTER TABLE dbo.a_Menus ALTER COLUMN ISACTIVE INT NOT NULL;
GO

IF EXISTS (SELECT 1 FROM sys.columns
           WHERE object_id = OBJECT_ID('dbo.a_Menus')
             AND name = 'ISREPORT' AND system_type_id = TYPE_ID('bit'))
    ALTER TABLE dbo.a_Menus ALTER COLUMN ISREPORT INT NULL;
GO

IF EXISTS (SELECT 1 FROM sys.columns
           WHERE object_id = OBJECT_ID('dbo.a_Module')
             AND name = 'ISACTIVE' AND system_type_id = TYPE_ID('bit'))
    ALTER TABLE dbo.a_Module ALTER COLUMN ISACTIVE INT NOT NULL;
GO

IF EXISTS (SELECT 1 FROM sys.columns
           WHERE object_id = OBJECT_ID('dbo.g_Taluka')
             AND name = 'ISACTIVE' AND system_type_id = TYPE_ID('bit'))
    ALTER TABLE dbo.g_Taluka ALTER COLUMN ISACTIVE INT NOT NULL;
GO

IF EXISTS (SELECT 1 FROM sys.columns
           WHERE object_id = OBJECT_ID('dbo.g_AccountHead')
             AND name = 'ISACTIVE' AND system_type_id = TYPE_ID('bit'))
    ALTER TABLE dbo.g_AccountHead ALTER COLUMN ISACTIVE INT NULL;
GO
  

 


 


-- =====================================================================
-- uniqueidentifier -> char(36)
-- =====================================================================

-- ---------------------------------------------------------------------
-- CONVENTION: GUID-valued columns are CHAR(36) holding the 36-character
-- UPPERCASE hyphenated form on all three providers -- never UNIQUEIDENTIFIER,
-- RAW(16) or UUID. Entities carry them as string? / CoreDataType.
-- AnsiStringFixed(36).
--
-- Why: Oracle's managed provider cannot bind a CLR Guid -- the DbType.Guid that
-- ADO.NET infers from a Guid value raises ArgumentException ("Value does not
-- fall within the expected range"), so every INSERT writing a Guid failed on
-- Oracle. Reads never showed it: ColumnDescriptor.SetValue already does
-- Guid.Parse(value.ToString()) precisely because Oracle stores these as
-- CHAR(36). Exactly the bool / ORA-00932 asymmetry again -- the read side
-- coerced and hid a write side that had never worked.
--
-- Same reasoning as bit -> INT above: normalise in the schema so what the code
-- holds is what the column holds, rather than asking the DAL to translate.
--
-- CASE matters. SQL Server's implicit uniqueidentifier -> char conversion and
-- CONVERT(char(36), newid()) both emit UPPERCASE, which is what the migrated
-- Oracle rows already hold. .NET's Guid.ToString() is lowercase, so every call
-- site writes Guid.NewGuid().ToString().ToUpperInvariant() -- a lowercase value
-- would silently never match on a CHAR comparison.
--
-- This applies to NEW tables too: G_ORGELEMENTIPMAP.ID further up this file was
-- created as UNIQUEIDENTIFIER DEFAULT NEWID() and is converted by the script
-- below. A new table should declare CHAR(36) with
-- DEFAULT (CONVERT(char(36), newid())) from the start.
--
-- CONVERTED: 40 GUID columns across the 40 tables the code uses today -- NOT
-- included here, run it on its own:
--
--     scripts/guid-to-char36.sqlserver.sql
--
-- Same shape as the bit -> INT section: pre-flight blocker query, drop 5 DEFAULT
-- constraints + PK_sms_buffer, 40 guarded ALTER COLUMN ... char(36), recreate,
-- verify. Idempotent. SQL Server only -- Oracle already holds all 40 as
-- CHAR(36 CHAR), so its twin is verify-only:
--
--     scripts/guid-to-char36.oracle-verify.sql
--
-- After running it: regenerate TflCbs.Entities for those 40 tables (Guid? ->
-- string?) and fix the three call sites that write a Guid to a column
-- (DirectCreditService.GUID, DormantReactivationService.GUID,
-- ForgotPasswordService.BUFFERID), or the build breaks.
--
-- STILL UNIQUEIDENTIFIER: 1262 columns schema-wide, on tables the code does not
-- reference. 34 of the 40 converted were msrepl_tran_version -- dead SQL Server
-- replication metadata (this database publishes nothing) that sits on nearly
-- every entity and would otherwise keep re-introducing Guid properties on each
-- regeneration.
--
-- OPEN: the 711 msrepl_tran_version columns are never read or written by this
-- codebase and could be dropped outright rather than converted. Deliberately
-- not done -- a separate, larger change.
-- ---------------------------------------------------------------------


-- a_userLoginType
IF OBJECT_ID('dbo.A_USERLOGINTYPE') IS NULL
CREATE TABLE dbo.A_USERLOGINTYPE
(
    [USERLOGINTYPEID]              INT IDENTITY(1,1) NOT NULL,
    [LOGINTYPE]                    INT NOT NULL,
    [USERID]                       INT NOT NULL,
    [ENTEREDBY]                    INT NULL,
    [ENTEREDON]                    DATETIME NULL,
    [PASSEDBY]                     INT NULL,
    [PASSEDON]                     DATETIME NULL,
    [CREATEDBY]                    INT NULL,
    [CREATEDON]                    DATETIME NULL,
    [LASTMODIFIEDBY]               INT NULL,
    [LASTMODIFIEDON]               DATETIME NULL,
    [REMARKS]                      VARCHAR(400) NULL,
    [REFNUMBER]                    VARCHAR(200) NULL,
    CONSTRAINT PK_A_USERLOGINTYPE PRIMARY KEY ([USERLOGINTYPEID])
);
GO

-- CBS_OTP
IF OBJECT_ID('dbo.CBS_OTP') IS NULL
CREATE TABLE dbo.CBS_OTP
(
    [CBSOTPID]                     INT IDENTITY(1,1) NOT NULL,
    [TYPE]                         INT NOT NULL,
    [USERID]                       DECIMAL(18, 0) NOT NULL,
    [OTP]                          INT NULL,
    [OTPGENERATEDON]               DATETIME NULL,
    [MOBILENUMBER]                 VARCHAR(30) NULL,
    [VALIDTO]                      DATETIME NULL,
    [ISUSED]                       INT NULL,
    [CREATEDBY]                    INT NOT NULL,
    [CREATEDON]                    DATETIME NOT NULL,
    [LASTMODIFIEDBY]               INT NULL,
    [LASTMODIFIEDON]               DATETIME NULL,
    CONSTRAINT PK_CBS_OTP PRIMARY KEY ([CBSOTPID])
);
GO

-- a_RemoteHostAttempt
IF OBJECT_ID('dbo.A_REMOTEHOSTATTEMPT') IS NULL
CREATE TABLE dbo.A_REMOTEHOSTATTEMPT
(
    [REMOTEHOSTATTEMPTID]          INT IDENTITY(1,1) NOT NULL,
    [REMOTEHOST]                   VARCHAR(20) NULL,
    [LOGINATTEMPT]                 INT NULL,
    [CREATEDBY]                    INT NULL,
    [CREATEDON]                    DATETIME NULL,
    [LASTMODIFIEDBY]               INT NULL,
    [LASTMODIFIEDON]               DATETIME NULL,
    [RELEASEDBY]                   INT NULL,
    [RELEASEDON]                   DATETIME NULL,
    CONSTRAINT PK_A_REMOTEHOSTATTEMPT PRIMARY KEY ([REMOTEHOSTATTEMPTID])
);
GO

-- a_PasswordChangeLog
IF OBJECT_ID('dbo.A_PASSWORDCHANGELOG') IS NULL
CREATE TABLE dbo.A_PASSWORDCHANGELOG
(
    [PASSWORDCHANGELOGID]          INT IDENTITY(1,1) NOT NULL,
    [USERID]                       DECIMAL(18, 0) NOT NULL,
    [NEWPASSWORD]                  BINARY(100) NOT NULL,
    [OTP]                          VARCHAR(20) NULL,
    [WORKINGDATE]                  DATE NOT NULL,
    [CREATEDBY]                    INT NOT NULL,
    [CREATEDON]                    DATETIME NOT NULL,
    [LASTMODIFIEDBY]               INT NULL,
    [LASTMODIFIEDON]               DATETIME NULL,
    [OLDPASSWORD]                  BINARY(100) NULL,
    CONSTRAINT PK_A_PASSWORDCHANGELOG PRIMARY KEY ([PASSWORDCHANGELOGID])
);
GO

-- h_EmpDeputation
IF OBJECT_ID('dbo.H_EMPDEPUTATION') IS NULL
CREATE TABLE dbo.H_EMPDEPUTATION
(
    [EMPDEPUTATIONID]              INT IDENTITY(1,1) NOT NULL,
    [EMPLOYEEID]                   INT NOT NULL,
    [FROMDATE]                     DATETIME NOT NULL,
    [TODATE]                       DATETIME NOT NULL,
    [ORGELEMENTID]                 INT NOT NULL,
    [ORGELEMENTIDDEP]              INT NOT NULL,
    [REMARKSDEP]                   VARCHAR(150) NULL,
    [ENTEREDBY]                    INT NOT NULL,
    [PASSEDBY]                     INT NULL,
    [RELEASEDBY]                   INT NULL,
    [RELEASEDON]                   DATETIME NULL,
    [RELEASEDPASSEDBY]             INT NULL,
    [REMARKSRELEASE]               VARCHAR(150) NULL,
    [CREATEDBY]                    INT NULL,
    [CREATEDON]                    DATETIME NULL,
    [LASTMODIFIEDBY]               INT NULL,
    [LASTMODIFIEDON]               DATETIME NULL,
    CONSTRAINT PK_H_EMPDEPUTATION PRIMARY KEY ([EMPDEPUTATIONID])
);
GO

-- h_EmpDeputationExt
IF OBJECT_ID('dbo.H_EMPDEPUTATIONEXT') IS NULL
CREATE TABLE dbo.H_EMPDEPUTATIONEXT
(
    [EMPDEPUTATIONEXTID]           INT IDENTITY(1,1) NOT NULL,
    [EMPDEPUTATIONID]              INT NOT NULL,
    [TODATE]                       DATETIME NOT NULL,
    [ENTEREDBY]                    INT NOT NULL,
    [PASSEDBY]                     INT NULL,
    [CREATEDBY]                    INT NULL,
    [CREATEDON]                    DATETIME NULL,
    [LASTMODIFIEDBY]               INT NULL,
    [LASTMODIFIEDON]               DATETIME NULL,
    [EXTENSIONREMARKS]             VARCHAR(200) NULL,
    CONSTRAINT PK_H_EMPDEPUTATIONEXT PRIMARY KEY ([EMPDEPUTATIONEXTID])
);
GO

-- g_OrgElementIPMap
IF OBJECT_ID('dbo.G_ORGELEMENTIPMAP') IS NULL
CREATE TABLE dbo.G_ORGELEMENTIPMAP
(
    [ID]                           UNIQUEIDENTIFIER NULL DEFAULT NEWID(),
    [ORGELEMENTID]                 INT NULL,
    [IPPATTERN]                    NVARCHAR(128) NOT NULL,
    [CREATEDBY]                    INT NULL,
    [CREATEDON]                    DATETIME NULL DEFAULT GETDATE(),
    [LASTMODIFIEDBY]               INT NULL,
    [LASTMODIFIEDON]               DATETIME NULL,
    CONSTRAINT UQ_G_ORGELEMENTIPMAP UNIQUE ([ORGELEMENTID], [IPPATTERN])
);
GO

-- b_UserSwitchLogTime
IF OBJECT_ID('dbo.B_USERSWITCHLOGTIME') IS NULL
CREATE TABLE dbo.B_USERSWITCHLOGTIME
(
    [USERSWITCHLOGTIMEID]          INT IDENTITY(1,1) NOT NULL,
    [USERID]                       DECIMAL(18, 0) NOT NULL,
    [SESSIONID]                    VARCHAR(50) NOT NULL,
    [LOGINTIME]                    DATETIME NOT NULL,
    [LOGOUTTIME]                   DATETIME NULL,
    [ISOFFLINE]                    INT NOT NULL,
    [ORGELEMENTID]                 INT NULL,
    [MODULEID]                     INT NULL,
    [CREATEDBY]                    INT NULL,
    [CREATEDON]                    DATETIME NULL,
    [LASTMODIFYBY]                 INT NULL,
    [LASTMODIFIEDON]               DATETIME NULL,
    [LOGININFO]                    VARCHAR(4000) NULL,
    CONSTRAINT PK_B_USERSWITCHLOGTIME PRIMARY KEY ([USERSWITCHLOGTIMEID])
);
GO

-- b_BusinessAssessmentDetails
IF OBJECT_ID('dbo.B_BUSINESSASSESSMENTDETAILS') IS NULL
CREATE TABLE dbo.B_BUSINESSASSESSMENTDETAILS
(
    [BUSINESSASSESSMENTDETAILSID]  INT IDENTITY(1,1) NOT NULL,
    [BUSINESSASSESSMENTID]         INT NOT NULL,
    [YEAR]                         VARCHAR(50) NULL,
    [INCOME]                       MONEY NULL,
    [EXPENCE]                      MONEY NULL,
    [PBDT]                         MONEY NULL,
    [PAT]                          MONEY NULL,
    [STATUS]                       VARCHAR(5) NULL,
    [CREATEDBY]                    INT NULL,
    [CREATEDON]                    DATETIME NULL,
    [LASTMODIFIEDBY]               INT NULL,
    [LASTMODIFIEDON]               DATETIME NULL,
    [TURNOVER]                     MONEY NULL,
    CONSTRAINT PK_B_BUSINESSASSESSMENTDETAILS PRIMARY KEY ([BUSINESSASSESSMENTDETAILSID])
);
GO

-- a_BrLoginAccessTime
IF OBJECT_ID('dbo.A_BRLOGINACCESSTIME') IS NULL
CREATE TABLE dbo.A_BRLOGINACCESSTIME
(
    [BRLOGINACCESSTIMEID]          INT IDENTITY(1,1) NOT NULL,
    [ORGELEMENTID]                 INT NOT NULL,
    [ISACTIVE]                     INT NULL,
    [LOGINTIME]                    BINARY(500) NOT NULL,
    [OUTTIME]                      BINARY(500) NOT NULL,
    [CREATEDBY]                    INT NULL,
    [CREATEDON]                    DATETIME NULL,
    [LASTMODIFIEDBY]               INT NULL,
    [LASTMODIFIEDON]               DATETIME NULL,
    CONSTRAINT PK_A_BRLOGINACCESSTIME PRIMARY KEY ([BRLOGINACCESSTIMEID])
);
GO

-- b_MarqueeAlert
IF OBJECT_ID('dbo.B_MARQUEEALERT') IS NULL
CREATE TABLE dbo.B_MARQUEEALERT
(
    [MARQUEEALERTID]               INT IDENTITY(1,1) NOT NULL,
    [FROMDATE]                     DATETIME NULL,
    [TODATE]                       DATETIME NULL,
    [ALERTTEXT]                    VARCHAR(200) NULL,
    [CREATEDBY]                    INT NULL,
    [CREATEDON]                    DATETIME NULL,
    [LASTMODIFIEDBY]               INT NULL,
    [LASTMODIFIEDON]               DATETIME NULL,
    CONSTRAINT PK_B_MARQUEEALERT PRIMARY KEY ([MARQUEEALERTID])
);
GO

-- k_LockerRentDisc
IF OBJECT_ID('dbo.K_LOCKERRENTDISC') IS NULL
CREATE TABLE dbo.K_LOCKERRENTDISC
(
    [LOCKERRENTDISCID]             INT IDENTITY(1,1) NOT NULL,
    [PERIODOVER]                   INT NULL,
    [DISCOUNT]                     DECIMAL(10, 2) NULL,
    [CREATEDBY]                    INT NULL,
    [CREATEDON]                    DATETIME NULL,
    [LASTMODIFIEDBY]               INT NULL,
    [LASTMODIFIEDON]               DATETIME NULL,
    [LOCKERTYPEID]                 INT NULL,
    [SPECIALCATEGORYID]            INT NULL,
    [ISACTIVESCDISC]               INT NULL,
    CONSTRAINT PK_K_LOCKERRENTDISC PRIMARY KEY ([LOCKERRENTDISCID])
);
GO

 
-- k_LockerMake
IF OBJECT_ID('dbo.K_LOCKERMAKE') IS NULL
CREATE TABLE dbo.K_LOCKERMAKE
(
    [LOCKERMAKEID]                 INT IDENTITY(1,1) NOT NULL,
    [LOCKERMAKER]                  VARCHAR(100) NOT NULL,
    [CREATEDBY]                    INT NOT NULL,
    [CREATEDON]                    DATETIME NOT NULL,
    [LASTMODIFIEDBY]               INT NULL,
    [LASTMODIFIEDON]               DATETIME NULL,
    CONSTRAINT PK_K_LOCKERMAKE PRIMARY KEY ([LOCKERMAKEID]),
    CONSTRAINT UQ_K_LOCKERMAKE UNIQUE ([LOCKERMAKER])
);
GO

-- k_LockerTypeLog
IF OBJECT_ID('dbo.K_LOCKERTYPELOG') IS NULL
CREATE TABLE dbo.K_LOCKERTYPELOG
(
    [LOCKERTYPELOGID]              INT IDENTITY(1,1) NOT NULL,
    [LOCKERTYPENAME]               CHAR(100) NULL,
    [CREATEDBY]                    INT NULL,
    [CREATEDON]                    DATETIME NULL,
    [LASTMODIFYBY]                 INT NULL,
    [LASTMODIFIEDON]               DATETIME NULL,
    [FROMDATE]                     DATETIME NULL,
    [TODATE]                       DATETIME NULL,
    [LOCKERRENT]                   MONEY NULL,
    [ORGELEMENTID]                 INT NULL
);
GO

-- a_UserMenu
IF OBJECT_ID('dbo.A_USERMENU') IS NULL
CREATE TABLE dbo.A_USERMENU
(
    [USERMENUID]                   INT IDENTITY(1,1) NOT NULL,
    [USERID]                       DECIMAL(18, 0) NULL,
    [MODULEID]                     INT NULL,
    [I]                            INT NULL,
    [C]                            VARCHAR(300) NULL,
    [L]                            INT NULL,
    [F]                            INT NULL,
    [U]                            VARCHAR(300) NULL,
    [O]                            VARCHAR(30) NULL,
    [USERRIGHTSCONSID]             INT NULL,
    CONSTRAINT PK_A_USERMENU PRIMARY KEY ([USERMENUID])
);
GO

  

IF COL_LENGTH('dbo.g_State', 'CERSAICODE') IS NULL
    ALTER TABLE dbo.g_State ADD CERSAICODE INT NULL;
GO

 
IF COL_LENGTH('dbo.g_Taluka', 'DISTRICTID') IS NULL
    ALTER TABLE dbo.g_Taluka ADD DISTRICTID INT NULL;
GO

IF COL_LENGTH('dbo.b_LoginPolicy', 'DEACTIVATEDAYS') IS NULL
    ALTER TABLE dbo.b_LoginPolicy ADD DEACTIVATEDAYS INT NULL;
GO

IF COL_LENGTH('dbo.b_LoginPolicy', 'REMOTEHOSTLOGINATTEMPT') IS NULL
    ALTER TABLE dbo.b_LoginPolicy ADD REMOTEHOSTLOGINATTEMPT INT NULL;
GO

IF COL_LENGTH('dbo.b_LoginPolicy', 'RESTRICTLASTPASSWORD') IS NULL
    ALTER TABLE dbo.b_LoginPolicy ADD RESTRICTLASTPASSWORD INT NULL;
GO

IF COL_LENGTH('dbo.a_User', 'PASSEDBY') IS NULL
    ALTER TABLE dbo.a_User ADD PASSEDBY INT NULL;
GO

UPDATE dbo.a_User SET PASSEDBY = COALESCE(CreatedBy, 1) WHERE PASSEDBY IS NULL;
GO

IF COL_LENGTH('dbo.a_User', 'USERLEVEL') IS NULL
    ALTER TABLE dbo.a_User ADD USERLEVEL INT NULL;
GO
 
UPDATE dbo.a_User SET USERLEVEL = [LEVEL] WHERE USERLEVEL IS NULL;
GO

-- =====================================================================
-- a_User.Password / a_UserLog.Password : drop column
-- =====================================================================
ALTER TABLE dbo.a_User DROP COLUMN [Password];
ALTER TABLE dbo.a_UserLog DROP COLUMN [Password];

-- =====================================================================
IF COL_LENGTH('dbo.b_AccHoldingAmount', 'HOLDTYPE') IS NULL
    ALTER TABLE dbo.b_AccHoldingAmount ADD HOLDTYPE INT NULL;
GO

IF COL_LENGTH('dbo.b_AccHoldingAmount', 'AVAILABLEBALANCE') IS NULL
    ALTER TABLE dbo.b_AccHoldingAmount ADD AVAILABLEBALANCE MONEY NULL;
GO

 
IF COL_LENGTH('dbo.h_Employee', 'PASSEDBY') IS NULL
    ALTER TABLE dbo.h_Employee ADD PASSEDBY INT NULL;
GO

UPDATE dbo.h_Employee SET PASSEDBY = COALESCE(CreatedBy, 1) WHERE PASSEDBY IS NULL;
GO

 
IF COL_LENGTH('dbo.k_LockerType', 'PENALRATEPERDAY') IS NULL
    ALTER TABLE dbo.k_LockerType ADD PENALRATEPERDAY MONEY NULL;
GO

IF COL_LENGTH('dbo.k_LockerType', 'LOCKERMAKEID') IS NULL
    ALTER TABLE dbo.k_LockerType ADD LOCKERMAKEID INT NULL;
GO
 
IF EXISTS (SELECT 1 FROM sys.columns
           WHERE object_id = OBJECT_ID('dbo.b_DayEndParamLog')
             AND name = 'ISEXECUTED' AND system_type_id = TYPE_ID('bit'))
    ALTER TABLE dbo.b_DayEndParamLog ALTER COLUMN ISEXECUTED INT NULL;
GO


 

EXEC sp_rename 'dbo.G_CURRENCY.Decimal', 'DECIMAL_', 'COLUMN';
EXEC sp_rename 'dbo.A_USER.Level',       'LEVEL_',   'COLUMN';
EXEC sp_rename 'dbo.a_UserLog.Level', 'LEVEL_', 'COLUMN';
GO
ALTER TABLE dbo.a_PasswordChangeLog ALTER COLUMN [NewPassword] varchar(200) NOT NULL;

ALTER TABLE dbo.a_PasswordChangeLog ALTER COLUMN [OldPassword] varchar(200) NULL;
GO