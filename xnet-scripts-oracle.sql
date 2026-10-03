/* =====================================================================
   xnet schema changes -- ORACLE SIDE.
   Target: Oracle 21c, schema XNETTN. Run as XNETTN, or qualify the names.

   Twin of docs/xnet-scripts-sqlserver.sql, which is the fuller record: most
   of what that file does (adding PASSWORDHASH, the mfa/otp tables, the new
   columns) was already present on Oracle, because this schema was migrated
   FROM SQL Server after those columns existed. What lands here is only the
   work that had no Oracle equivalent yet, plus an index of the changes that
   were applied through their own script files.

   Everything below has been RUN. The script files keep the guards, the
   pre-flight queries and the verification; this file is the ledger.
   ===================================================================== */

/* ---------------------------------------------------------------------
   CONVENTIONS -- both live in the SQL Server twin, both bind Oracle:

     flags  ->  NUMBER(10,0) holding 0/1   (INT on SQL Server / PostgreSQL)
     GUIDs  ->  CHAR(36 CHAR), UPPERCASE   (CHAR(36) on the other two)

   Oracle is the reason for both. Its managed provider cannot bind a CLR bool
   (ORA-00932) and cannot bind a CLR Guid (DbType.Guid -> ArgumentException),
   so those writes had never worked here -- while reads looked fine, because
   ColumnDescriptor.SetValue coerces with Convert.ChangeType / Guid.Parse.

   Oracle needed NO change for either: it already held all 83 flag columns as
   NUMBER(10,0) and all 40 GUID columns as CHAR(36 CHAR) uppercase. It was SQL
   Server that moved onto Oracle's shape. Rationale in full:
   docs/xnet-scripts-sqlserver.sql (the two CONVENTION blocks).
   --------------------------------------------------------------------- */

/* ---------------------------------------------------------------------
   APPLIED THROUGH SCRIPT FILES (Oracle side) -- all run, all idempotent:

     scripts/password-nullable.oracle.sql
         A_USER.PASSWORD / A_USERLOG.PASSWORD : NOT NULL -> NULL.
         ORA-01400 on every user create -- the port writes PASSWORDHASH +
         PASSWORDVERSION and never the legacy RAW(100) PASSWORD column.
         Superseded by the drop below; kept for the record.

     scripts/password-drop.oracle.sql
         DROP A_USER.PASSWORD and A_USERLOG.PASSWORD. Data copied first to
         A_USER_PASSWORDDROPBACKUP / A_USERLOG_PASSWORDDROPBACKUP -- drop
         those two tables yourself once you are satisfied.

     scripts/userlog-level-rename.oracle.sql
         A_USERLOG."LEVEL" -> A_USERLOG.LEVEL_. LEVEL is the hierarchical-query
         pseudo-column, so the DAL's unquoted identifier raised ORA-00904 on
         every mod-log write (i.e. user update and delete, never create).
         A_USER.LEVEL had already been renamed; A_USERLOG was missed.

     scripts/passwordchangelog-varchar.oracle.sql
         A_PASSWORDCHANGELOG.NEWPASSWORD / .OLDPASSWORD : RAW(200) ->
         VARCHAR2(200), matching A_USER.PASSWORDHASH. Oracle was not broken by
         RAW (it is variable length) -- SQL Server's fixed-width binary(100)
         was, silently: the last-N password-reuse check compared padded bytes
         and never matched. Both providers changed so one entity fits both.

     scripts/guid-to-char36.oracle-verify.sql
         VERIFY ONLY, changes nothing. Confirms all 40 GUID columns are
         CHAR(36 CHAR) and every stored value is 36 uppercase characters,
         before the SQL Server side converts onto that shape.

   There is no Oracle twin of scripts/bit-to-int.sqlserver.sql or
   scripts/guid-to-char36.sqlserver.sql: Oracle already holds both shapes.
   --------------------------------------------------------------------- */

/* ---------------------------------------------------------------------
   APPLIED INLINE (no script file of its own)
   --------------------------------------------------------------------- */

-- A_PASSWORDCHANGELOG.WORKINGDATE was VARCHAR2 on Oracle and DATETIME on SQL
-- Server, so the DateTime parameter the service binds landed on a string
-- column. One entity, two shapes -- Oracle moves to DATE.
ALTER TABLE A_PASSWORDCHANGELOG MODIFY (WORKINGDATE DATE);

/* ---------------------------------------------------------------------
   OPEN ON ORACLE

     * 697 foreign keys were dropped at migration and are NOT restored.
       Deferred by decision. One test names it:
       SignatureServiceTests.Save_UnknownTarget_RejectedByForeignKey skips
       Oracle, because only SQL Server's FK_b_Signature_b_Account refuses the
       orphan write -- the service does not guard the target itself, and
       neither does xnet legacy.

     * No CHECK (col IN (0,1)) on the NUMBER(10,0) flag columns. BIT enforced
       0/1 for free on SQL Server; nothing does now, on any provider.
       Additive, no code change -- worth adding.
   --------------------------------------------------------------------- */
