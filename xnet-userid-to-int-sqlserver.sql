/* ===========================================================================
   A_USER.USERID / A_USERLOG.USERID : numeric|decimal -> int        SQL Server
   ---------------------------------------------------------------------------
   Also converts every column that FKs to them (FK endpoints must share a type).

   Plain columns are converted with ALTER COLUMN. A column that is IDENTITY
   cannot be retyped in place, so its whole table is rebuilt (CREATE new ->
   IDENTITY_INSERT copy -> DROP old -> sp_rename -> RESEED). A rebuild drops
   everything attached to that table, so for a rebuilt table this script
   captures and restores ALL of its indexes, CHECKs and FKs -- not only the
   ones touching USERID. DEFAULTs are carried inline into the new table.

   NOT carried across a rebuild: triggers, extended properties, table-level
   permissions. The script aborts if a table being rebuilt has triggers or
   computed columns rather than silently dropping them.

   Works on compatibility level 100+ (FOR XML PATH, not STRING_AGG).
   Single batch, single transaction.
   =========================================================================== */
SET QUOTED_IDENTIFIER ON;   /* XML methods need it; sqlcmd defaults it OFF */
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @colName sysname = N'USERID';          -- the column being converted
DECLARE @nl nchar(2) = CHAR(13) + CHAR(10);

DECLARE @parent TABLE (object_id int PRIMARY KEY);
INSERT @parent
SELECT object_id FROM sys.tables
WHERE SCHEMA_NAME(schema_id) = N'dbo' AND name IN (N'A_USER', N'A_USERLOG');

IF (SELECT COUNT(*) FROM @parent) < 2
    THROW 50001, N'dbo.A_USER and/or dbo.A_USERLOG not found.', 1;

/* --- what has to become int ---------------------------------------------- */
DECLARE @target TABLE (object_id int NOT NULL, col sysname NOT NULL, PRIMARY KEY (object_id, col));

INSERT @target (object_id, col)
SELECT c.object_id, c.name
FROM sys.columns c JOIN @parent p ON p.object_id = c.object_id
WHERE c.name = @colName AND TYPE_NAME(c.user_type_id) <> N'int';

INSERT @target (object_id, col)
SELECT DISTINCT fkc.parent_object_id, pc.name
FROM sys.foreign_key_columns fkc
JOIN @parent p      ON p.object_id  = fkc.referenced_object_id
JOIN sys.columns rc ON rc.object_id = fkc.referenced_object_id AND rc.column_id = fkc.referenced_column_id AND rc.name = @colName
JOIN sys.columns pc ON pc.object_id = fkc.parent_object_id     AND pc.column_id = fkc.parent_column_id
WHERE TYPE_NAME(pc.user_type_id) <> N'int'
  AND NOT EXISTS (SELECT 1 FROM @target t WHERE t.object_id = fkc.parent_object_id AND t.col = pc.name);

/* --- tables that must be rebuilt (IDENTITY cannot be retyped) ------------- */
DECLARE @rebuild TABLE (object_id int PRIMARY KEY);
INSERT @rebuild
SELECT DISTINCT t.object_id
FROM @target t JOIN sys.identity_columns ic ON ic.object_id = t.object_id AND ic.name = t.col;

SELECT QUOTENAME(OBJECT_SCHEMA_NAME(t.object_id)) + N'.' + QUOTENAME(OBJECT_NAME(t.object_id)) AS [table],
       t.col AS [column],
       TYPE_NAME(c.user_type_id) + N'(' + CAST(c.precision AS nvarchar(10)) + N',' + CAST(c.scale AS nvarchar(10)) + N') -> int' AS [change],
       CASE WHEN r.object_id IS NULL THEN N'ALTER COLUMN' ELSE N'TABLE REBUILD (identity)' END AS [method]
FROM @target t
JOIN sys.columns c ON c.object_id = t.object_id AND c.name = t.col
LEFT JOIN @rebuild r ON r.object_id = t.object_id;

IF NOT EXISTS (SELECT 1 FROM @target) BEGIN PRINT N'Nothing to do - already int.'; RETURN; END

/* --- things a rebuild would silently destroy ------------------------------ */
IF EXISTS (SELECT 1 FROM sys.triggers tr JOIN @rebuild r ON r.object_id = tr.parent_id)
    THROW 50004, N'A table to be rebuilt has triggers. Script them out first, then re-run.', 1;

IF EXISTS (SELECT 1 FROM sys.columns c JOIN @rebuild r ON r.object_id = c.object_id WHERE c.is_computed = 1)
    THROW 50005, N'A table to be rebuilt has computed columns. Not supported - script it by hand.', 1;

/* --- values must actually fit an int ------------------------------------- */
DECLARE @chk nvarchar(max) = N'';
SELECT @chk = @chk + CASE WHEN @chk = N'' THEN N'' ELSE N' UNION ALL ' END
     + N'SELECT ''' + OBJECT_NAME(t.object_id) + N'.' + t.col + N''' AS bad_column, COUNT(*) AS bad_rows FROM '
     + QUOTENAME(OBJECT_SCHEMA_NAME(t.object_id)) + N'.' + QUOTENAME(OBJECT_NAME(t.object_id))
     + N' WHERE ' + QUOTENAME(t.col) + N' IS NOT NULL AND (' + QUOTENAME(t.col) + N' NOT BETWEEN -2147483648 AND 2147483647 OR '
     + QUOTENAME(t.col) + N' <> ROUND(' + QUOTENAME(t.col) + N', 0)) HAVING COUNT(*) > 0'
FROM @target t;

DROP TABLE IF EXISTS #bad;
CREATE TABLE #bad (bad_column nvarchar(300), bad_rows int);
INSERT #bad EXEC sp_executesql @chk;
IF EXISTS (SELECT 1 FROM #bad)
BEGIN
    SELECT * FROM #bad;
    THROW 50003, N'Values out of int range (or non-integral). Aborted.', 1;
END

/* ===========================================================================
   Capture the DDL to put back.
   Scope: anything touching a target column, PLUS everything on a rebuilt table.
   =========================================================================== */
DECLARE @fkDrop nvarchar(max) = N'', @fkAdd nvarchar(max) = N'';

;WITH fks AS (
    SELECT fk.object_id, fk.name, fk.is_not_trusted,
           QUOTENAME(OBJECT_SCHEMA_NAME(fk.parent_object_id))     + N'.' + QUOTENAME(OBJECT_NAME(fk.parent_object_id))     AS ptab,
           QUOTENAME(OBJECT_SCHEMA_NAME(fk.referenced_object_id)) + N'.' + QUOTENAME(OBJECT_NAME(fk.referenced_object_id)) AS rtab,
           REPLACE(fk.delete_referential_action_desc, N'_', N' ') AS del,
           REPLACE(fk.update_referential_action_desc, N'_', N' ') AS upd
    FROM sys.foreign_keys fk
    WHERE EXISTS (SELECT 1 FROM @rebuild r WHERE r.object_id IN (fk.parent_object_id, fk.referenced_object_id))
       OR EXISTS (SELECT 1 FROM sys.foreign_key_columns k
                  JOIN sys.columns c ON c.object_id = k.parent_object_id AND c.column_id = k.parent_column_id
                  JOIN @target t ON t.object_id = k.parent_object_id AND t.col = c.name
                  WHERE k.constraint_object_id = fk.object_id)
       OR EXISTS (SELECT 1 FROM sys.foreign_key_columns k
                  JOIN sys.columns c ON c.object_id = k.referenced_object_id AND c.column_id = k.referenced_column_id
                  JOIN @target t ON t.object_id = k.referenced_object_id AND t.col = c.name
                  WHERE k.constraint_object_id = fk.object_id)
)
SELECT @fkDrop = @fkDrop + N'ALTER TABLE ' + ptab + N' DROP CONSTRAINT ' + QUOTENAME(name) + N';' + @nl,
       @fkAdd  = @fkAdd  + N'ALTER TABLE ' + ptab
               + N' WITH ' + CASE WHEN is_not_trusted = 1 THEN N'NOCHECK' ELSE N'CHECK' END
               + N' ADD CONSTRAINT ' + QUOTENAME(name) + N' FOREIGN KEY ('
               + STUFF((SELECT N',' + QUOTENAME(c.name)
                        FROM sys.foreign_key_columns k JOIN sys.columns c ON c.object_id = k.parent_object_id AND c.column_id = k.parent_column_id
                        WHERE k.constraint_object_id = fks.object_id
                        ORDER BY k.constraint_column_id
                        FOR XML PATH(N''), TYPE).value(N'.', N'nvarchar(max)'), 1, 1, N'')
               + N') REFERENCES ' + rtab + N' ('
               + STUFF((SELECT N',' + QUOTENAME(c.name)
                        FROM sys.foreign_key_columns k JOIN sys.columns c ON c.object_id = k.referenced_object_id AND c.column_id = k.referenced_column_id
                        WHERE k.constraint_object_id = fks.object_id
                        ORDER BY k.constraint_column_id
                        FOR XML PATH(N''), TYPE).value(N'.', N'nvarchar(max)'), 1, 1, N'')
               + N') ON DELETE ' + del + N' ON UPDATE ' + upd + N';' + @nl
FROM fks;

/* --- CHECK constraints ---------------------------------------------------- */
DECLARE @ckDrop nvarchar(max) = N'', @ckAdd nvarchar(max) = N'';

SELECT @ckDrop = @ckDrop + CASE WHEN is_rebuilt = 1 THEN N'' ELSE N'ALTER TABLE ' + tab + N' DROP CONSTRAINT ' + QUOTENAME(name) + N';' + @nl END,
       @ckAdd  = @ckAdd  + N'ALTER TABLE ' + tab + N' WITH ' + CASE WHEN is_not_trusted = 1 THEN N'NOCHECK' ELSE N'CHECK' END
               + N' ADD CONSTRAINT ' + QUOTENAME(name) + N' CHECK ' + definition + N';' + @nl
FROM (
    SELECT DISTINCT cc.name, cc.definition, cc.is_not_trusted,
           QUOTENAME(OBJECT_SCHEMA_NAME(cc.parent_object_id)) + N'.' + QUOTENAME(OBJECT_NAME(cc.parent_object_id)) AS tab,
           CASE WHEN EXISTS (SELECT 1 FROM @rebuild r WHERE r.object_id = cc.parent_object_id) THEN 1 ELSE 0 END AS is_rebuilt
    FROM sys.check_constraints cc
    WHERE EXISTS (SELECT 1 FROM @rebuild r WHERE r.object_id = cc.parent_object_id)
       OR EXISTS (SELECT 1 FROM sys.sql_expression_dependencies d
                  JOIN sys.columns c ON c.object_id = d.referenced_id AND c.column_id = d.referenced_minor_id
                  JOIN @target t ON t.object_id = c.object_id AND t.col = c.name
                  WHERE d.referencing_id = cc.object_id)
) x;

/* --- indexes / PK / UNIQUE ------------------------------------------------ */
DECLARE @ixDrop nvarchar(max) = N'', @ixAdd nvarchar(max) = N'';

;WITH ixs AS (
    SELECT i.name, i.type_desc, i.is_unique, i.is_primary_key, i.is_unique_constraint, i.filter_definition,
           QUOTENAME(OBJECT_SCHEMA_NAME(i.object_id)) + N'.' + QUOTENAME(OBJECT_NAME(i.object_id)) AS tab,
           CASE WHEN EXISTS (SELECT 1 FROM @rebuild r WHERE r.object_id = i.object_id) THEN 1 ELSE 0 END AS is_rebuilt,
           STUFF((SELECT N',' + QUOTENAME(c.name) + CASE WHEN ic.is_descending_key = 1 THEN N' DESC' ELSE N'' END
                  FROM sys.index_columns ic JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
                  WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id AND ic.is_included_column = 0
                  ORDER BY ic.key_ordinal
                  FOR XML PATH(N''), TYPE).value(N'.', N'nvarchar(max)'), 1, 1, N'') AS keycols,
           STUFF((SELECT N',' + QUOTENAME(c.name)
                  FROM sys.index_columns ic JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
                  WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id AND ic.is_included_column = 1
                  ORDER BY ic.index_column_id
                  FOR XML PATH(N''), TYPE).value(N'.', N'nvarchar(max)'), 1, 1, N'') AS inccols
    FROM sys.indexes i
    WHERE i.type IN (1, 2)
      AND (EXISTS (SELECT 1 FROM @rebuild r WHERE r.object_id = i.object_id)
           OR EXISTS (SELECT 1 FROM sys.index_columns ic
                      JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
                      JOIN @target t ON t.object_id = ic.object_id AND t.col = c.name
                      WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id))
)
SELECT @ixDrop = @ixDrop + CASE WHEN is_rebuilt = 1 THEN N''      /* dies with the old table */
                                WHEN is_primary_key = 1 OR is_unique_constraint = 1
                                     THEN N'ALTER TABLE ' + tab + N' DROP CONSTRAINT ' + QUOTENAME(name) + N';' + @nl
                                ELSE N'DROP INDEX ' + QUOTENAME(name) + N' ON ' + tab + N';' + @nl END,
       @ixAdd  = @ixAdd  + CASE WHEN is_primary_key = 1 OR is_unique_constraint = 1
                                THEN N'ALTER TABLE ' + tab + N' ADD CONSTRAINT ' + QUOTENAME(name) + N' '
                                     + CASE WHEN is_primary_key = 1 THEN N'PRIMARY KEY ' ELSE N'UNIQUE ' END
                                     + type_desc + N' (' + keycols + N')'
                                ELSE N'CREATE ' + CASE WHEN is_unique = 1 THEN N'UNIQUE ' ELSE N'' END
                                     + type_desc + N' INDEX ' + QUOTENAME(name) + N' ON ' + tab + N' (' + keycols + N')'
                                     + ISNULL(N' INCLUDE (' + inccols + N')', N'')
                                     + ISNULL(N' WHERE ' + filter_definition, N'') END + N';' + @nl
FROM ixs;

/* ===========================================================================
   Build the rebuild script for each IDENTITY table.
   =========================================================================== */
DECLARE @rebuildSql nvarchar(max) = N'';

SELECT @rebuildSql = @rebuildSql
     + N'CREATE TABLE ' + newtab + N' (' + @nl + cols + @nl + N');' + @nl
     + N'SET IDENTITY_INSERT ' + newtab + N' ON;' + @nl
     + N'INSERT INTO ' + newtab + N' (' + collist + N') SELECT ' + collist + N' FROM ' + tab + N';' + @nl
     + N'SET IDENTITY_INSERT ' + newtab + N' OFF;' + @nl
     + N'DROP TABLE ' + tab + N';' + @nl
     + N'EXEC sp_rename N''' + newtab + N''', N''' + rawname + N''';' + @nl
     + N'DBCC CHECKIDENT(''' + tab + N''', RESEED, ' + CAST(lastval AS nvarchar(20)) + N');' + @nl
FROM (
    SELECT QUOTENAME(OBJECT_SCHEMA_NAME(r.object_id)) + N'.' + QUOTENAME(OBJECT_NAME(r.object_id)) AS tab,
           QUOTENAME(OBJECT_SCHEMA_NAME(r.object_id)) + N'.' + QUOTENAME(OBJECT_NAME(r.object_id) + N'__int_new') AS newtab,
           OBJECT_NAME(r.object_id) AS rawname,
           CONVERT(bigint, ISNULL((SELECT last_value FROM sys.identity_columns ic WHERE ic.object_id = r.object_id), 0)) AS lastval,
           STUFF((SELECT N',' + @nl + N'    ' + QUOTENAME(c.name) + N' '
                       + CASE WHEN EXISTS (SELECT 1 FROM @target t WHERE t.object_id = c.object_id AND t.col = c.name)
                              THEN N'int'
                              ELSE TYPE_NAME(c.user_type_id)
                                 + CASE
                                     WHEN TYPE_NAME(c.user_type_id) IN (N'char', N'varchar', N'binary', N'varbinary')
                                       THEN N'(' + CASE WHEN c.max_length = -1 THEN N'max' ELSE CAST(c.max_length AS nvarchar(10)) END + N')'
                                     WHEN TYPE_NAME(c.user_type_id) IN (N'nchar', N'nvarchar')
                                       THEN N'(' + CASE WHEN c.max_length = -1 THEN N'max' ELSE CAST(c.max_length / 2 AS nvarchar(10)) END + N')'
                                     WHEN TYPE_NAME(c.user_type_id) IN (N'decimal', N'numeric')
                                       THEN N'(' + CAST(c.precision AS nvarchar(10)) + N',' + CAST(c.scale AS nvarchar(10)) + N')'
                                     WHEN TYPE_NAME(c.user_type_id) IN (N'datetime2', N'time', N'datetimeoffset')
                                       THEN N'(' + CAST(c.scale AS nvarchar(10)) + N')'
                                     ELSE N'' END
                         END
                       + CASE WHEN c.is_identity = 1
                              THEN N' IDENTITY(' + CAST(CONVERT(bigint, ic.seed_value) AS nvarchar(20)) + N','
                                                 + CAST(CONVERT(bigint, ic.increment_value) AS nvarchar(20)) + N')'
                              ELSE N'' END
                       + ISNULL(N' COLLATE ' + c.collation_name, N'')
                       + CASE WHEN c.is_nullable = 1 THEN N' NULL' ELSE N' NOT NULL' END
                       + ISNULL(N' CONSTRAINT ' + QUOTENAME(dc.name) + N' DEFAULT ' + dc.definition, N'')
                  FROM sys.columns c
                  LEFT JOIN sys.identity_columns ic ON ic.object_id = c.object_id AND ic.column_id = c.column_id
                  LEFT JOIN sys.default_constraints dc ON dc.parent_object_id = c.object_id AND dc.parent_column_id = c.column_id
                  WHERE c.object_id = r.object_id
                  ORDER BY c.column_id
                  FOR XML PATH(N''), TYPE).value(N'.', N'nvarchar(max)'), 1, 1, N'') AS cols,
           STUFF((SELECT N',' + QUOTENAME(c.name) FROM sys.columns c
                  WHERE c.object_id = r.object_id ORDER BY c.column_id
                  FOR XML PATH(N''), TYPE).value(N'.', N'nvarchar(max)'), 1, 1, N'') AS collist
    FROM @rebuild r
) y;

/* --- plain ALTER COLUMN for everything not being rebuilt ------------------ */
DECLARE @alter nvarchar(max) = N'';
SELECT @alter = @alter + N'ALTER TABLE ' + QUOTENAME(OBJECT_SCHEMA_NAME(t.object_id)) + N'.' + QUOTENAME(OBJECT_NAME(t.object_id))
              + N' ALTER COLUMN ' + QUOTENAME(t.col) + N' int '
              + CASE WHEN c.is_nullable = 1 THEN N'NULL' ELSE N'NOT NULL' END + N';' + @nl
FROM @target t
JOIN sys.columns c ON c.object_id = t.object_id AND c.name = t.col
WHERE NOT EXISTS (SELECT 1 FROM @rebuild r WHERE r.object_id = t.object_id);

PRINT @fkDrop; PRINT @ckDrop; PRINT @ixDrop; PRINT @rebuildSql; PRINT @alter; PRINT @ixAdd; PRINT @ckAdd; PRINT @fkAdd;

BEGIN TRAN;
    EXEC sp_executesql @fkDrop;
    EXEC sp_executesql @ckDrop;
    EXEC sp_executesql @ixDrop;
    EXEC sp_executesql @rebuildSql;
    EXEC sp_executesql @alter;
    EXEC sp_executesql @ixAdd;
    EXEC sp_executesql @ckAdd;
    EXEC sp_executesql @fkAdd;
COMMIT;

PRINT N'Done.';
