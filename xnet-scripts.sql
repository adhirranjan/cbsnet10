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


 