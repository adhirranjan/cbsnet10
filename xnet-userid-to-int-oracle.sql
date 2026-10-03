-- ===========================================================================
-- USERID : NUMBER -> NUMBER(10)   (tables listed in c_tabs)             Oracle
-- ---------------------------------------------------------------------------
-- Oracle has no "int": INT/INTEGER are synonyms for NUMBER(38,0), which still
-- maps to decimal in ODP.NET. NUMBER(10) is the type that round-trips as a
-- C# int, so that is the target here.
--
-- Also converts every column that FKs to them (an FK needs matching types).
-- Drops + recreates the PK / unique / indexes / FKs on those columns.
-- Re-runnable: columns already NUMBER(10) are skipped.
--
-- ALTER ... MODIFY is tried first; when Oracle refuses (ORA-01440: cannot
-- decrease precision/scale on a populated column) the column is rebuilt as
-- add -> copy -> drop -> rename. The rebuild moves the column to the end of
-- the table and drops its DEFAULT and COMMENT -- re-apply those if you use any.
-- A trigger naming the column goes INVALID across a rebuild; it is recompiled
-- at the end and its status reported.
-- Run in the schema that owns the tables.
-- ===========================================================================
SET SERVEROUTPUT ON SIZE UNLIMITED

DECLARE
    TYPE str_t IS TABLE OF VARCHAR2(4000) INDEX BY PLS_INTEGER;
    TYPE col_r IS RECORD (tab VARCHAR2(128), col VARCHAR2(128), nullable VARCHAR2(1));
    TYPE col_t IS TABLE OF col_r INDEX BY PLS_INTEGER;

    TYPE name_t IS TABLE OF VARCHAR2(128);

    c_col      CONSTANT VARCHAR2(128) := 'USERID';   -- the column being converted
    c_tabs     CONSTANT name_t := name_t('A_USER', 'A_USERLOG', 'A_USERRIGHTS');

    v_tgt      col_t;
    v_drop_fk  str_t;   v_add_fk  str_t;
    v_drop_con str_t;   v_add_con str_t;   -- PK / UNIQUE
    v_drop_ix  str_t;   v_add_ix  str_t;

    PROCEDURE ddl(p_sql IN VARCHAR2) IS
    BEGIN
        DBMS_OUTPUT.PUT_LINE(p_sql || ';');
        EXECUTE IMMEDIATE p_sql;
    END;

    PROCEDURE push(p_list IN OUT NOCOPY str_t, p_sql IN VARCHAR2) IS
    BEGIN
        p_list(p_list.COUNT + 1) := p_sql;
    END;

    PROCEDURE run_all(p_list IN str_t) IS
    BEGIN
        FOR i IN 1 .. p_list.COUNT LOOP ddl(p_list(i)); END LOOP;
    END;

    FUNCTION is_listed(p_tab VARCHAR2) RETURN BOOLEAN IS
    BEGIN
        FOR i IN 1 .. c_tabs.COUNT LOOP
            IF c_tabs(i) = p_tab THEN RETURN TRUE; END IF;
        END LOOP;
        RETURN FALSE;
    END;

    FUNCTION is_target(p_tab VARCHAR2, p_col VARCHAR2) RETURN BOOLEAN IS
    BEGIN
        FOR i IN 1 .. v_tgt.COUNT LOOP
            IF v_tgt(i).tab = p_tab AND v_tgt(i).col = p_col THEN RETURN TRUE; END IF;
        END LOOP;
        RETURN FALSE;
    END;

    -- registers (table, column) unless it is already NUMBER(10) or already listed
    PROCEDURE add_target(p_tab VARCHAR2, p_col VARCHAR2) IS
        r col_r;
    BEGIN
        IF is_target(p_tab, p_col) THEN RETURN; END IF;
        SELECT nullable INTO r.nullable
        FROM   user_tab_columns
        WHERE  table_name = p_tab AND column_name = p_col
          AND  NOT (data_type = 'NUMBER' AND data_precision = 10 AND NVL(data_scale, 0) = 0);
        r.tab := p_tab;
        r.col := p_col;
        v_tgt(v_tgt.COUNT + 1) := r;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN NULL;   -- missing, or already NUMBER(10)
    END;

    PROCEDURE check_fits(p_tab VARCHAR2, p_col VARCHAR2) IS
        v_bad PLS_INTEGER;
    BEGIN
        EXECUTE IMMEDIATE
            'SELECT COUNT(*) FROM "' || p_tab || '" WHERE "' || p_col || '" IS NOT NULL AND ("'
            || p_col || '" NOT BETWEEN -2147483648 AND 2147483647 OR "'
            || p_col || '" <> TRUNC("' || p_col || '"))'
            INTO v_bad;
        IF v_bad > 0 THEN
            RAISE_APPLICATION_ERROR(-20001, p_tab || '.' || p_col || ': ' || v_bad
                || ' value(s) out of int range or non-integral. Aborted.');
        END IF;
    END;

    PROCEDURE convert(p_tab VARCHAR2, p_col VARCHAR2, p_nullable VARCHAR2) IS
    BEGIN
        BEGIN
            ddl('ALTER TABLE "' || p_tab || '" MODIFY ("' || p_col || '" NUMBER(10))');
            RETURN;
        EXCEPTION
            WHEN OTHERS THEN
                IF SQLCODE <> -1440 THEN RAISE; END IF;   -- ORA-01440 only
                DBMS_OUTPUT.PUT_LINE('-- ORA-01440: rebuilding ' || p_tab || '.' || p_col);
        END;

        ddl('ALTER TABLE "' || p_tab || '" ADD ("' || p_col || '$INT" NUMBER(10))');
        ddl('UPDATE "' || p_tab || '" SET "' || p_col || '$INT" = "' || p_col || '"');
        ddl('ALTER TABLE "' || p_tab || '" DROP COLUMN "' || p_col || '"');
        ddl('ALTER TABLE "' || p_tab || '" RENAME COLUMN "' || p_col || '$INT" TO "' || p_col || '"');
        IF p_nullable = 'N' THEN
            ddl('ALTER TABLE "' || p_tab || '" MODIFY ("' || p_col || '" NOT NULL)');
        END IF;
    END;

BEGIN
    ------------------------------------------------------------------ targets
    FOR i IN 1 .. c_tabs.COUNT LOOP
        add_target(c_tabs(i), c_col);
    END LOOP;

    FOR c IN (SELECT cc.table_name tab, cc.column_name col, pk.table_name r_tab
              FROM   user_constraints  fk
              JOIN   user_cons_columns cc  ON cc.owner = fk.owner  AND cc.constraint_name  = fk.constraint_name
              JOIN   user_constraints  pk  ON pk.owner = fk.r_owner AND pk.constraint_name = fk.r_constraint_name
              JOIN   user_cons_columns pkc ON pkc.owner = pk.owner AND pkc.constraint_name = pk.constraint_name
                                          AND pkc.position = cc.position
              WHERE  fk.constraint_type = 'R'
                AND  pkc.column_name = c_col) LOOP
        IF is_listed(c.r_tab) THEN add_target(c.tab, c.col); END IF;
    END LOOP;

    IF v_tgt.COUNT = 0 THEN
        DBMS_OUTPUT.PUT_LINE('-- Nothing to do - already NUMBER(10).');
        RETURN;
    END IF;

    FOR i IN 1 .. v_tgt.COUNT LOOP
        DBMS_OUTPUT.PUT_LINE('-- convert ' || v_tgt(i).tab || '.' || v_tgt(i).col);
        check_fits(v_tgt(i).tab, v_tgt(i).col);
    END LOOP;

    ------------------------------------------------------- capture FK/PK/UK DDL
    FOR c IN (SELECT fk.constraint_name, fk.table_name, fk.delete_rule,
                     pk.table_name r_table,
                     (SELECT LISTAGG('"' || column_name || '"', ',') WITHIN GROUP (ORDER BY position)
                      FROM user_cons_columns WHERE owner = fk.owner AND constraint_name = fk.constraint_name) cols,
                     (SELECT LISTAGG('"' || column_name || '"', ',') WITHIN GROUP (ORDER BY position)
                      FROM user_cons_columns WHERE owner = pk.owner AND constraint_name = pk.constraint_name) r_cols
              FROM   user_constraints fk
              JOIN   user_constraints pk ON pk.owner = fk.r_owner AND pk.constraint_name = fk.r_constraint_name
              WHERE  fk.constraint_type = 'R') LOOP
        -- keep only FKs whose own side or whose parent side touches a target column
        DECLARE
            v_hit BOOLEAN := FALSE;
        BEGIN
            FOR k IN (SELECT column_name FROM user_cons_columns WHERE constraint_name = c.constraint_name) LOOP
                IF is_target(c.table_name, k.column_name) THEN v_hit := TRUE; END IF;
            END LOOP;
            IF is_target(c.r_table, c_col) THEN v_hit := TRUE; END IF;
            IF v_hit THEN
                push(v_drop_fk, 'ALTER TABLE "' || c.table_name || '" DROP CONSTRAINT "' || c.constraint_name || '"');
                push(v_add_fk,  'ALTER TABLE "' || c.table_name || '" ADD CONSTRAINT "' || c.constraint_name
                                || '" FOREIGN KEY (' || c.cols || ') REFERENCES "' || c.r_table || '" (' || c.r_cols || ')'
                                || CASE c.delete_rule WHEN 'CASCADE'  THEN ' ON DELETE CASCADE'
                                                      WHEN 'SET NULL' THEN ' ON DELETE SET NULL'
                                                      ELSE '' END);
            END IF;
        END;
    END LOOP;

    FOR c IN (SELECT con.constraint_name, con.table_name, con.constraint_type, con.index_name,
                     (SELECT LISTAGG('"' || column_name || '"', ',') WITHIN GROUP (ORDER BY position)
                      FROM user_cons_columns WHERE owner = con.owner AND constraint_name = con.constraint_name) cols
              FROM   user_constraints con
              WHERE  con.constraint_type IN ('P', 'U')) LOOP
        DECLARE
            v_hit BOOLEAN := FALSE;
        BEGIN
            FOR k IN (SELECT column_name FROM user_cons_columns WHERE constraint_name = c.constraint_name) LOOP
                IF is_target(c.table_name, k.column_name) THEN v_hit := TRUE; END IF;
            END LOOP;
            IF v_hit THEN
                push(v_drop_con, 'ALTER TABLE "' || c.table_name || '" DROP CONSTRAINT "' || c.constraint_name || '"');
                push(v_add_con,  'ALTER TABLE "' || c.table_name || '" ADD CONSTRAINT "' || c.constraint_name || '" '
                                || CASE c.constraint_type WHEN 'P' THEN 'PRIMARY KEY' ELSE 'UNIQUE' END
                                || ' (' || c.cols || ')');
            END IF;
        END;
    END LOOP;

    -- plain indexes (constraint-backed ones come back with the constraint above)
    FOR i IN (SELECT ix.index_name, ix.table_name, ix.uniqueness,
                     (SELECT LISTAGG('"' || column_name || '" ' || descend, ',') WITHIN GROUP (ORDER BY column_position)
                      FROM user_ind_columns WHERE index_name = ix.index_name) cols
              FROM   user_indexes ix
              WHERE  ix.index_type = 'NORMAL'
                AND  NOT EXISTS (SELECT 1 FROM user_constraints con
                                 WHERE con.index_name = ix.index_name AND con.constraint_type IN ('P', 'U'))) LOOP
        DECLARE
            v_hit BOOLEAN := FALSE;
        BEGIN
            FOR k IN (SELECT column_name FROM user_ind_columns WHERE index_name = i.index_name) LOOP
                IF is_target(i.table_name, k.column_name) THEN v_hit := TRUE; END IF;
            END LOOP;
            IF v_hit THEN
                push(v_drop_ix, 'DROP INDEX "' || i.index_name || '"');
                push(v_add_ix,  'CREATE ' || CASE i.uniqueness WHEN 'UNIQUE' THEN 'UNIQUE ' ELSE '' END
                                || 'INDEX "' || i.index_name || '" ON "' || i.table_name || '" (' || i.cols || ')');
            END IF;
        END;
    END LOOP;

    ----------------------------------------------------------------- do it
    run_all(v_drop_fk);
    run_all(v_drop_con);
    run_all(v_drop_ix);

    FOR i IN 1 .. v_tgt.COUNT LOOP
        convert(v_tgt(i).tab, v_tgt(i).col, v_tgt(i).nullable);
    END LOOP;

    run_all(v_add_ix);
    run_all(v_add_con);
    run_all(v_add_fk);

    -- triggers that name the column go INVALID across a rebuild
    FOR t IN (SELECT trigger_name, table_name FROM user_triggers) LOOP
        IF is_listed(t.table_name) THEN
            ddl('ALTER TRIGGER "' || t.trigger_name || '" COMPILE');
        END IF;
    END LOOP;

    FOR o IN (SELECT object_name, status FROM user_objects
              WHERE object_type = 'TRIGGER' AND status <> 'VALID') LOOP
        DBMS_OUTPUT.PUT_LINE('-- WARNING invalid trigger: ' || o.object_name);
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('-- Done.');
END;
/
