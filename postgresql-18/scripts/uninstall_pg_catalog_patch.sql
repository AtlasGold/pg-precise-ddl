\set ON_ERROR_STOP on

DO $$
DECLARE
    wrapper_oid oid;
BEGIN
    SELECT p.oid
    INTO wrapper_oid
    FROM pg_catalog.pg_proc AS p
    JOIN pg_catalog.pg_namespace AS n
      ON n.oid = p.pronamespace
    JOIN pg_catalog.pg_language AS l
      ON l.oid = p.prolang
    WHERE n.nspname = 'pg_catalog'
      AND p.proname = 'pg_get_functiondef'
      AND pg_catalog.pg_get_function_identity_arguments(p.oid) = 'oid'
      AND l.lanname = 'sql'
      AND p.prosrc LIKE '%ddl_original.get_functiondef%';

    IF wrapper_oid IS NOT NULL
       AND EXISTS (
        SELECT 1
        FROM pg_catalog.pg_depend AS d
        JOIN pg_catalog.pg_extension AS e
          ON e.oid = d.refobjid
        WHERE d.classid = 'pg_catalog.pg_proc'::pg_catalog.regclass
          AND d.objid = wrapper_oid
          AND d.deptype = 'e'
          AND e.extname = 'ddl_original'
    ) THEN
        ALTER EXTENSION ddl_original DROP FUNCTION pg_catalog.pg_get_functiondef(oid);
    END IF;

    IF wrapper_oid IS NOT NULL THEN
        DROP FUNCTION pg_catalog.pg_get_functiondef(oid);
    END IF;

    IF pg_catalog.to_regprocedure('pg_catalog.pg_get_functiondef_native(oid)') IS NOT NULL
       AND pg_catalog.to_regprocedure('pg_catalog.pg_get_functiondef(oid)') IS NULL THEN
        ALTER FUNCTION pg_catalog.pg_get_functiondef_native(oid)
        RENAME TO pg_get_functiondef;
    END IF;
END;
$$;

DO $$
DECLARE
    wrapper_oid oid;
BEGIN
    SELECT p.oid
    INTO wrapper_oid
    FROM pg_catalog.pg_proc AS p
        JOIN pg_catalog.pg_namespace AS n
          ON n.oid = p.pronamespace
        JOIN pg_catalog.pg_language AS l
          ON l.oid = p.prolang
    WHERE n.nspname = 'pg_catalog'
      AND p.proname = 'pg_get_function_arguments'
      AND pg_catalog.pg_get_function_identity_arguments(p.oid) = 'oid'
      AND l.lanname = 'sql'
      AND p.prosrc LIKE '%ddl_original.get_function_arguments%';

    IF wrapper_oid IS NOT NULL
       AND EXISTS (
        SELECT 1
        FROM pg_catalog.pg_depend AS d
        JOIN pg_catalog.pg_extension AS e
          ON e.oid = d.refobjid
        WHERE d.classid = 'pg_catalog.pg_proc'::pg_catalog.regclass
          AND d.objid = wrapper_oid
          AND d.deptype = 'e'
          AND e.extname = 'ddl_original'
    ) THEN
        ALTER EXTENSION ddl_original DROP FUNCTION pg_catalog.pg_get_function_arguments(oid);
    END IF;

    IF wrapper_oid IS NOT NULL THEN
        DROP FUNCTION pg_catalog.pg_get_function_arguments(oid);
    END IF;

    IF pg_catalog.to_regprocedure('pg_catalog.pg_get_function_arguments_native(oid)') IS NOT NULL
       AND pg_catalog.to_regprocedure('pg_catalog.pg_get_function_arguments(oid)') IS NULL THEN
        ALTER FUNCTION pg_catalog.pg_get_function_arguments_native(oid)
        RENAME TO pg_get_function_arguments;
    END IF;
END;
$$;
