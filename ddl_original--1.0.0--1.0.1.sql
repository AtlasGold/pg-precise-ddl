DO $$
BEGIN
    IF current_setting('server_version_num')::integer < 140000 THEN
        RAISE EXCEPTION 'ddl_original pg_catalog patch supports PostgreSQL 14 or newer; this server is %',
            current_setting('server_version');
    END IF;
END;
$$;

DO $$
BEGIN
    IF pg_catalog.to_regprocedure('pg_catalog.pg_get_functiondef_native(oid)') IS NULL THEN
        IF EXISTS (
            SELECT 1
            FROM pg_catalog.pg_proc AS p
            JOIN pg_catalog.pg_namespace AS n
              ON n.oid = p.pronamespace
            JOIN pg_catalog.pg_language AS l
              ON l.oid = p.prolang
            WHERE n.nspname = 'pg_catalog'
              AND p.proname = 'pg_get_functiondef'
              AND pg_catalog.pg_get_function_identity_arguments(p.oid) = 'oid'
              AND l.lanname = 'internal'
              AND p.prosrc = 'pg_get_functiondef'
        ) THEN
            ALTER FUNCTION pg_catalog.pg_get_functiondef(oid)
            RENAME TO pg_get_functiondef_native;
        ELSE
            RAISE EXCEPTION 'Cannot find the native pg_catalog.pg_get_functiondef(oid) to rename';
        END IF;
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION pg_catalog.pg_get_functiondef(oid)
RETURNS text
LANGUAGE sql
STABLE
STRICT
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
    SELECT COALESCE(
        ddl_original.get_functiondef($1),
        pg_catalog.pg_get_functiondef_native($1)
    );
$$;

REVOKE ALL ON FUNCTION pg_catalog.pg_get_functiondef(oid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION pg_catalog.pg_get_functiondef(oid) TO PUBLIC;

DO $$
BEGIN
    IF pg_catalog.to_regprocedure('pg_catalog.pg_get_function_arguments_native(oid)') IS NULL THEN
        IF EXISTS (
            SELECT 1
            FROM pg_catalog.pg_proc AS p
            JOIN pg_catalog.pg_namespace AS n
              ON n.oid = p.pronamespace
            JOIN pg_catalog.pg_language AS l
              ON l.oid = p.prolang
            WHERE n.nspname = 'pg_catalog'
              AND p.proname = 'pg_get_function_arguments'
              AND pg_catalog.pg_get_function_identity_arguments(p.oid) = 'oid'
              AND l.lanname = 'internal'
              AND p.prosrc = 'pg_get_function_arguments'
        ) THEN
            ALTER FUNCTION pg_catalog.pg_get_function_arguments(oid)
            RENAME TO pg_get_function_arguments_native;
        ELSE
            RAISE EXCEPTION 'Cannot find the native pg_catalog.pg_get_function_arguments(oid) to rename';
        END IF;
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION pg_catalog.pg_get_function_arguments(oid)
RETURNS text
LANGUAGE sql
STABLE
STRICT
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
    SELECT COALESCE(
        ddl_original.get_function_arguments($1),
        pg_catalog.pg_get_function_arguments_native($1)
    );
$$;

REVOKE ALL ON FUNCTION pg_catalog.pg_get_function_arguments(oid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION pg_catalog.pg_get_function_arguments(oid) TO PUBLIC;
