CREATE EXTENSION ddl_original;

CREATE OR REPLACE FUNCTION public.ddl_original_regress_func(
    p_val numeric(10,2),
    p_txt varchar(12)
)
RETURNS text
LANGUAGE sql
AS $$
    SELECT p_txt || ':' || p_val::text
$$;

CREATE OR REPLACE PROCEDURE public.ddl_original_regress_proc(
    p_val numeric(10,2),
    p_txt varchar(12)
)
LANGUAGE plpgsql
AS $$
BEGIN
    NULL;
END;
$$;

SELECT btrim(regexp_replace(
    ddl_original.get_function_arguments(
        'public.ddl_original_regress_func(numeric, character varying)'::regprocedure
    ),
    '\s+',
    ' ',
    'g'
)) AS function_arguments;

SELECT ddl_original.get_functiondef(
    'public.ddl_original_regress_func(numeric, character varying)'::regprocedure
) LIKE '%numeric(10,2)%varchar(12)%' AS function_definition_has_typmods;

SELECT btrim(regexp_replace(
    ddl_original.get_function_arguments(
        'public.ddl_original_regress_proc(numeric, character varying)'::regprocedure
    ),
    '\s+',
    ' ',
    'g'
)) AS procedure_arguments;

SELECT ddl_original.get_functiondef(
    'public.ddl_original_regress_proc(numeric, character varying)'::regprocedure
) LIKE '%numeric(10,2)%varchar(12)%' AS procedure_definition_has_typmods;

DROP FUNCTION public.ddl_original_regress_func(numeric, character varying);
DROP PROCEDURE public.ddl_original_regress_proc(numeric, character varying);

SELECT count(*) AS remaining_captured_regress_routines
FROM ddl_original.routine_source
WHERE object_identity LIKE 'public.ddl_original_regress_%';

DROP EXTENSION ddl_original;
