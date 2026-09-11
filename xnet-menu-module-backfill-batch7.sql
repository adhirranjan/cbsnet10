/* ============================================================================
   xnet — menu placement backfill for the batch-7 screens
   Target : Trustbank_XNETT_ORCL (SQL Server)
   Mirror : TflCbs.Tools.DbMigrator/Migrations/sqlserver/0011_menu_module_backfill_batch7.sql
            Same statements. This copy exists because the migrator has never run
            against xnet (no CbsSchemaVersions journal), so xnet SQL is applied by
            hand — the docs/xnet-scripts.sql convention. See BACKLOG-xnet-variant.md 4.8.

   WHAT IT FIXES
     MenuListService builds the menu tree from A_MENUS.ModuleId / A_MENUS.ParentMenuId,
     but xnet's newer menu rows leave both empty (0 / NULL) and keep module + parent in
     a_ModuleMenuMap. Such a row is filtered out of a module-scoped menu, and because
     CbsAccessMiddleware derives AllowedUrls from the same tree, the screen 403s even
     when its route is correct.

   SCOPE  9 rows — the batch-7 screens plus the two group nodes they hang off.
          231 other active menus have the same defect and are NOT touched here.

   SAFE TO RE-RUN. Values are read from a_ModuleMenuMap, so a second run writes the
   same values and the verification below still prints PASS.

   ROLLBACK (all 9 were 0 / NULL beforehand):
     UPDATE dbo.A_MENUS SET ModuleId = 0, ParentMenuId = NULL
      WHERE MenuId IN (2783,2784,2785,2786,2787,2788,3286,3287,3288);
   ============================================================================ */

SET NOCOUNT ON;
GO

/* -- 1. Precondition: this must be the xnet-shaped database.
      On any other, these MenuIds name different rows. ------------------------ */
IF NOT EXISTS (SELECT 1 FROM dbo.A_MENUS WHERE MenuId = 2784 AND MenuCaption = 'Holding Amount Entry')
   OR NOT EXISTS (SELECT 1 FROM dbo.A_MENUS WHERE MenuId = 3287 AND MenuCaption = 'Direct Credit Entry')
    RAISERROR('batch7 backfill: MenuId 2784/3287 are not the expected screens. Wrong database - nothing applied.', 16, 1);
GO

/* -- 2. Before ------------------------------------------------------------- */
SELECT 'BEFORE' AS phase, m.MenuId, m.MenuCaption, m.ModuleId, m.ParentMenuId,
       MapModuleId = x.ModuleId, MapParentId = x.ParentMenuId
  FROM dbo.A_MENUS m
  JOIN dbo.a_ModuleMenuMap x ON x.MenuId = m.MenuId
 WHERE m.MenuId IN (2783,2784,2785,2786,2787,2788,3286,3287,3288)
 ORDER BY m.MenuId;
GO

/* -- 3. The backfill ------------------------------------------------------- */
BEGIN TRAN;

UPDATE m
   SET m.ModuleId     = x.ModuleId,
       m.ParentMenuId = x.ParentMenuId
  FROM dbo.A_MENUS m
  JOIN dbo.a_ModuleMenuMap x
    ON x.MenuId = m.MenuId
 WHERE m.MenuId IN (2783,2784,2785,2786,2787,2788,3286,3287,3288);

DECLARE @fixed int = (
    SELECT COUNT(*)
      FROM dbo.A_MENUS m
      JOIN dbo.a_ModuleMenuMap x ON x.MenuId = m.MenuId
     WHERE m.MenuId IN (2783,2784,2785,2786,2787,2788,3286,3287,3288)
       AND m.ModuleId = x.ModuleId
       AND m.ParentMenuId = x.ParentMenuId);

IF @fixed <> 9
BEGIN
    ROLLBACK TRAN;
    RAISERROR('batch7 backfill: expected 9 placed menu rows, found %d. ROLLED BACK.', 16, 1, @fixed);
END
ELSE
BEGIN
    COMMIT TRAN;
    PRINT 'batch7 backfill: 9/9 rows placed. Committed.';
END
GO

/* -- 4. After -------------------------------------------------------------- */
SELECT 'AFTER' AS phase, m.MenuId, m.MenuCaption, m.ModuleId, m.ParentMenuId,
       Parent = p.MenuCaption
  FROM dbo.A_MENUS m
  LEFT JOIN dbo.A_MENUS p ON p.MenuId = m.ParentMenuId
 WHERE m.MenuId IN (2783,2784,2785,2786,2787,2788,3286,3287,3288)
 ORDER BY m.MenuId;

SELECT result = CASE WHEN COUNT(*) = 9 THEN 'PASS - all 9 rows match a_ModuleMenuMap'
                     ELSE 'FAIL - only ' + CAST(COUNT(*) AS varchar(4)) + ' of 9 match' END
  FROM dbo.A_MENUS m
  JOIN dbo.a_ModuleMenuMap x ON x.MenuId = m.MenuId
 WHERE m.MenuId IN (2783,2784,2785,2786,2787,2788,3286,3287,3288)
   AND m.ModuleId = x.ModuleId AND m.ParentMenuId = x.ParentMenuId;

/* Remaining database-wide defect, deliberately NOT fixed here (own backlog item). */
SELECT still_zero_module_active = (SELECT COUNT(*) FROM dbo.A_MENUS WHERE ISNULL(ModuleId,0) = 0 AND IsActive = 1),
       still_parent_disagreements = (SELECT COUNT(*) FROM dbo.A_MENUS m
                                       JOIN dbo.a_ModuleMenuMap x ON x.MenuId = m.MenuId
                                      WHERE ISNULL(m.ParentMenuId,-1) <> ISNULL(x.ParentMenuId,-1));
GO
