-- a_Menus route cutover for xnet — point the migrated screens at their new MVC routes.
-- Same mechanism and rationale as DbMigrator 0004/0008 (read 0004's header): the database is the
-- route map, a_Menus.NavigateURL holds the new route and _NavigateURL_SQL keeps the pre-migration
-- legacy value. Verified before running: all 9 rows below had _NavigateURL_SQL populated and
-- byte-identical to NavigateURL.
--
-- Why not just run DbMigrator 0004 + 0008: their assertions are written for the India menu tree
-- (9 and 4 rows). xnet has no menu row at all for four of those screens, so both scripts would
-- RAISERROR. This is the xnet-shaped equivalent (backlog-xnet-variant 4.5).
--
-- NOT CUT OVER — no a_Menus row exists in xnet (confirmed by filename search, not just exact match):
--   /Hr/Taluka                          (~/ho/bank/g_Taluka.aspx)
--   /Lockers/LockerType                 (~/lockers/k_LockerType.aspx)
--   /Administration/SystemNotification  (~/config/b_MarqueeAlert.aspx)
--   /Administration/BlockedUsers        (~/config/updateBlockedUser.aspx)
-- NOT CUT OVER — no legacy counterpart, the screen is ours:
--   /Bank/ReferenceCache
--
-- ROLLBACK:
--   UPDATE dbo.a_Menus SET NavigateURL = _NavigateURL_SQL
--    WHERE MenuId IN (824, 825, 826, 843, 844, 857, 1000, 2784, 2785);
--
-- Re-runnable: after a successful run the legacy values no longer match, so a re-run updates 0 rows
-- and the assertion — which counts rows HOLDING the new route — still passes.

WITH cutover(LegacyUrl, NewRoute) AS (
    SELECT * FROM (VALUES
        ('/hr/h_discipactionhistory.aspx?',                          '/Hr/DiscipActionHistory'),
        ('/ho/admin/a_rolemaster.aspx?',                             '/Administration/Role'),
        ('/ho/admin/a_module.aspx?',                                 '/Administration/Module'),
        ('/ho/admin/a_menus.aspx?',                                  '/Administration/Menu'),
        ('/ho/bank/g_state.aspx?',                                   '/Hr/State'),
        ('/ho/bank/g_district.aspx?',                                '/Hr/District'),
        ('/config/connectedusers.aspx?',                             '/Administration/ConnectedUsers'),
        ('/retailbanking/b_accholdingamount.aspx?source=entry',      '/RetailBanking/AccHoldingAmount'),
        ('/retailbanking/b_accholdingamount.aspx?source=entrypass',  '/RetailBanking/AccHoldingAmount/Authorize')
    ) v(LegacyUrl, NewRoute)
)
UPDATE m
   SET m._NavigateURL_SQL = m.NavigateURL          -- defensive: keeps the rollback value truthful
  FROM dbo.a_Menus m
  JOIN cutover c ON LOWER(REPLACE(m.NavigateURL, '~', '')) = c.LegacyUrl
 WHERE m._NavigateURL_SQL IS NULL;
GO

WITH cutover(LegacyUrl, NewRoute) AS (
    SELECT * FROM (VALUES
        ('/hr/h_discipactionhistory.aspx?',                          '/Hr/DiscipActionHistory'),
        ('/ho/admin/a_rolemaster.aspx?',                             '/Administration/Role'),
        ('/ho/admin/a_module.aspx?',                                 '/Administration/Module'),
        ('/ho/admin/a_menus.aspx?',                                  '/Administration/Menu'),
        ('/ho/bank/g_state.aspx?',                                   '/Hr/State'),
        ('/ho/bank/g_district.aspx?',                                '/Hr/District'),
        ('/config/connectedusers.aspx?',                             '/Administration/ConnectedUsers'),
        ('/retailbanking/b_accholdingamount.aspx?source=entry',      '/RetailBanking/AccHoldingAmount'),
        ('/retailbanking/b_accholdingamount.aspx?source=entrypass',  '/RetailBanking/AccHoldingAmount/Authorize')
    ) v(LegacyUrl, NewRoute)
)
UPDATE m
   SET m.NavigateURL = c.NewRoute
  FROM dbo.a_Menus m
  JOIN cutover c ON LOWER(REPLACE(m.NavigateURL, '~', '')) = c.LegacyUrl;
GO

-- Assertion: exactly the 9 expected rows carry a new route. A silent zero-match would leave every
-- migrated screen unreachable from the menu and — since CbsAccessMiddleware derives AllowedUrls from
-- these URLs — 403 on direct navigation too.
DECLARE @moved int = (
    SELECT COUNT(*) FROM dbo.a_Menus
     WHERE NavigateURL IN ('/Hr/DiscipActionHistory', '/Administration/Role', '/Administration/Module',
                           '/Administration/Menu', '/Hr/State', '/Hr/District',
                           '/Administration/ConnectedUsers',
                           '/RetailBanking/AccHoldingAmount', '/RetailBanking/AccHoldingAmount/Authorize'));
IF @moved <> 9
    RAISERROR('menu_routes_cutover_xnet: expected 9 migrated menu rows, found %d.', 16, 1, @moved);
GO
