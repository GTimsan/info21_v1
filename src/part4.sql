-- 1) Создать хранимую процедуру, которая, не уничтожая базу данных,
-- уничтожает все те таблицы текущей базы данных, имена которых начинаются с фразы 'TableName'.


CREATE OR REPLACE PROCEDURE drop_tables(pattern varchar DEFAULT 'TableName')
LANGUAGE plpgsql
AS $$
DECLARE
    name text;
BEGIN
    FOR name IN SELECT table_name
                FROM information_schema.tables
                WHERE table_schema NOT IN ('information_schema', 'pg_catalog')
                    AND table_name LIKE pattern
    LOOP
        EXECUTE format('DROP table %I CASCADE', name);
    END LOOP;
END; $$;

CALL drop_tables('xp');

-- 2) Создать хранимую процедуру с выходным параметром,
--     которая выводит список имен и параметров
--     всех скалярных SQL функций пользователя в текущей базе данных.
--     Имена функций без параметров не выводить.
--     Имена и список параметров должны выводиться в одну строку.
--     Выходной параметр возвращает количество найденных функций.

CREATE OR REPLACE PROCEDURE prc_get_function(ref REFCURSOR, count INOUT int)
LANGUAGE plpgsql
AS $$ BEGIN
OPEN ref FOR 
    SELECT t2.routine_name, t1.arg
    FROM (SELECT p.specific_name, string_agg(CONCAT(p.parameter_name, '::', p.data_type), ', ') AS arg
                    FROM information_schema.parameters AS p
                    WHERE p.specific_schema NOT IN ('information_schema', 'pg_catalog') AND p.parameter_mode = 'IN'
                    GROUP BY p.specific_name) AS t1
    JOIN
        (SELECT *
        FROM information_schema.routines
        WHERE routine_schema NOT IN ('information_schema', 'pg_catalog') AND routine_type = 'FUNCTION') AS t2
        ON t1.specific_name = t2.specific_name;

MOVE FORWARD ALL FROM ref;  
GET DIAGNOSTICS count := ROW_COUNT;  
MOVE BACKWARD ALL FROM ref;  

END; $$;

BEGIN;
    CALL prc_get_function('data');
    FETCH ALL IN "data";
COMMIT;

DO $$
DECLARE
    count int;
BEGIN
    CALL prc_get_function('data', count);
    RAISE NOTICE 'count of functions = %', count;
END; $$;

DROP PROCEDURE prc_get_function;

-- 3) Создать хранимую процедуру с выходным параметром, которая уничтожает 
-- все SQL DML триггеры в текущей базе данных. Выходной параметр 
-- возвращает количество уничтоженных триггеров.

CREATE OR REPLACE PROCEDURE prc_delete_all_dml_triggers(INOUT count INTEGER DEFAULT 0)
LANGUAGE plpgsql AS $$
DECLARE
    trg_name text;
    table_name text;
BEGIN
    FOR trg_name, table_name IN SELECT trigger_name, event_object_table
                                  FROM information_schema.triggers
    LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS %I ON %I ', trg_name, table_name);
        count := count + 1;
    END LOOP;
END;$$;

CALL prc_delete_all_dml_triggers();

-- 4) Создать хранимую процедуру с входным параметром, которая выводит имена и описания типа 
-- объектов (только хранимых процедур и скалярных функций), в тексте которых на языке SQL 
-- встречается строка, задаваемая параметром процедуры.

CREATE OR REPLACE PROCEDURE prc_find_pcr_and_fnc_by_string_in_definition(ref REFCURSOR, str varchar)
LANGUAGE plpgsql
AS $$ BEGIN
    OPEN ref FOR
        SELECT routine_name, routine_type
        FROM information_schema.routines AS p
        WHERE p.specific_schema NOT IN ('information_schema', 'pg_catalog')
          AND p.routine_definition ILIKE '%' ||str||'%';

END; $$;

BEGIN;
CALL prc_find_pcr_and_fnc_by_string_in_definition('test', 'get');
FETCH ALL IN "test";
COMMIT;
