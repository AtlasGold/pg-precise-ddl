CREATE SCHEMA ddl_original;

REVOKE ALL ON SCHEMA ddl_original FROM PUBLIC;

CREATE TABLE ddl_original.routine_source (
    routine_oid oid PRIMARY KEY,
    object_identity text NOT NULL,
    schema_name name,
    command_tag text NOT NULL,
    source_sql text NOT NULL,
    source_hash text NOT NULL,
    server_version_num integer NOT NULL DEFAULT current_setting('server_version_num')::integer,
    captured_at timestamp with time zone NOT NULL DEFAULT clock_timestamp(),
    captured_by name NOT NULL DEFAULT session_user
);

REVOKE ALL ON ddl_original.routine_source FROM PUBLIC;

CREATE OR REPLACE FUNCTION ddl_original.capture_routine_source()
RETURNS event_trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
    cmd record;
    source_text text;
BEGIN
    source_text := current_query();

    FOR cmd IN
        SELECT *
        FROM pg_catalog.pg_event_trigger_ddl_commands()
        WHERE classid = 'pg_catalog.pg_proc'::pg_catalog.regclass
          AND command_tag IN ('CREATE FUNCTION', 'CREATE PROCEDURE')
          AND schema_name IS DISTINCT FROM 'pg_catalog'
          AND schema_name IS DISTINCT FROM 'ddl_original'
    LOOP
        INSERT INTO ddl_original.routine_source (
            routine_oid,
            object_identity,
            schema_name,
            command_tag,
            source_sql,
            source_hash,
            server_version_num,
            captured_at,
            captured_by
        )
        VALUES (
            cmd.objid,
            cmd.object_identity,
            cmd.schema_name,
            cmd.command_tag,
            source_text,
            pg_catalog.md5(source_text),
            current_setting('server_version_num')::integer,
            clock_timestamp(),
            session_user
        )
        ON CONFLICT (routine_oid)
        DO UPDATE SET
            object_identity = EXCLUDED.object_identity,
            schema_name = EXCLUDED.schema_name,
            command_tag = EXCLUDED.command_tag,
            source_sql = EXCLUDED.source_sql,
            source_hash = EXCLUDED.source_hash,
            server_version_num = EXCLUDED.server_version_num,
            captured_at = EXCLUDED.captured_at,
            captured_by = EXCLUDED.captured_by;
    END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION ddl_original.invalidate_altered_routine()
RETURNS event_trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
    cmd record;
BEGIN
    FOR cmd IN
        SELECT *
        FROM pg_catalog.pg_event_trigger_ddl_commands()
        WHERE classid = 'pg_catalog.pg_proc'::pg_catalog.regclass
          AND command_tag IN ('ALTER FUNCTION', 'ALTER PROCEDURE')
          AND schema_name IS DISTINCT FROM 'pg_catalog'
          AND schema_name IS DISTINCT FROM 'ddl_original'
    LOOP
        DELETE
        FROM ddl_original.routine_source
        WHERE routine_oid = cmd.objid;
    END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION ddl_original.remove_dropped_routine()
RETURNS event_trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
    obj record;
BEGIN
    FOR obj IN
        SELECT *
        FROM pg_catalog.pg_event_trigger_dropped_objects()
        WHERE classid = 'pg_catalog.pg_proc'::pg_catalog.regclass
    LOOP
        DELETE
        FROM ddl_original.routine_source
        WHERE routine_oid = obj.objid;
    END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION ddl_original.get_functiondef(p_routine_oid oid)
RETURNS text
LANGUAGE sql
STABLE
STRICT
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
    SELECT s.source_sql
    FROM ddl_original.routine_source AS s
    WHERE s.routine_oid = p_routine_oid;
$$;

CREATE OR REPLACE FUNCTION ddl_original.get_function_arguments(p_routine_oid oid)
RETURNS text
LANGUAGE sql
STABLE
STRICT
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
    SELECT btrim(
        (
            regexp_match(
                s.source_sql,
                '^[[:space:]]*CREATE[[:space:]]+' ||
                '(OR[[:space:]]+REPLACE[[:space:]]+)?' ||
                '(FUNCTION|PROCEDURE)[[:space:]]+' ||
                '.*?\((.*)\)[[:space:]]+' ||
                '(RETURNS|LANGUAGE)[[:space:]]',
                'is'
            )
        )[3]
    )
    FROM ddl_original.routine_source AS s
    WHERE s.routine_oid = p_routine_oid;
$$;

CREATE OR REPLACE VIEW ddl_original.captured_routines AS
SELECT
    s.routine_oid,
    s.routine_oid::pg_catalog.regprocedure AS routine,
    p.prokind,
    s.object_identity,
    s.schema_name,
    s.command_tag,
    s.server_version_num,
    s.source_hash,
    s.captured_at,
    s.captured_by
FROM ddl_original.routine_source AS s
JOIN pg_catalog.pg_proc AS p
  ON p.oid = s.routine_oid;

CREATE EVENT TRIGGER ddl_original_capture_create
    ON ddl_command_end
    WHEN TAG IN ('CREATE FUNCTION', 'CREATE PROCEDURE')
    EXECUTE FUNCTION ddl_original.capture_routine_source();

CREATE EVENT TRIGGER ddl_original_capture_alter
    ON ddl_command_end
    WHEN TAG IN ('ALTER FUNCTION', 'ALTER PROCEDURE')
    EXECUTE FUNCTION ddl_original.invalidate_altered_routine();

CREATE EVENT TRIGGER ddl_original_capture_drop
    ON sql_drop
    EXECUTE FUNCTION ddl_original.remove_dropped_routine();

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
