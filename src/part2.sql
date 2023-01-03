-- 1) Написать процедуру добавления P2P проверки
-- Параметры: ник проверяемого, ник проверяющего, название задания, статус P2P проверки, время. 
-- Если задан статус "начало", добавить запись в таблицу Checks (в качестве даты использовать сегодняшнюю). 
-- Добавить запись в таблицу P2P. 
-- Если задан статус "начало", в качестве проверки указать только что добавленную запись, иначе указать проверку с незавершенным P2P этапом.

CREATE OR REPLACE PROCEDURE add_p2p_check(checked varchar, checking varchar,
                                    task_name varchar, state CHECK_STATUS, "time" time)
    LANGUAGE plpgsql
AS $$
DECLARE count_p2p_check INT;
BEGIN
    IF (checked <> checking AND is_available_task(checked, task_name)) THEN
        count_p2p_check := get_count_p2p(checked, checking, task_name);
        IF (state = 'start') THEN
            IF count_p2p_check % 2 = 0 THEN
                INSERT INTO checks(peer, task, date) VALUES (checked, task_name, now());
                INSERT INTO p2p(check_id, checking_peer, state, time)
                    VALUES ( get_check_id_start_for_checked_and_checking_and_task(checked, checking, task_name),
                             checking, state, "time");
            ELSE RAISE EXCEPTION 'ERROR: This task is already in the start status';
            END IF;

        ELSE
            IF count_p2p_check % 2 = 1 THEN
                INSERT INTO p2p(check_id, checking_peer, state, time)
                    VALUES ( get_check_id_start_for_checked_and_checking_and_task(checked, checking, task_name),
                        checking, state, "time");
            ELSE RAISE EXCEPTION 'ERROR: This task is not start status';
            END IF;
        END IF;
    ELSIF checked = checking THEN
        RAISE EXCEPTION 'ERROR: Checked peer and checking peer not should be same';
    ELSE RAISE EXCEPTION 'ERROR: This task is not available for check, because not complete parent task';
    END IF;
END; $$;



CREATE OR REPLACE FUNCTION is_available_task(checked varchar, task_name varchar)
    RETURNS BOOLEAN
    LANGUAGE plpgsql
AS $$
DECLARE id_for_check BIGINT;
BEGIN
    IF exist_parent_task(task_name) THEN
        id_for_check := get_max_check_id_from_checks_for_checked_and_task(checked, (SELECT parent_task FROM tasks WHERE title = task_name));
        IF (id_for_check = 0 AND is_success_verter_check_task(id_for_check) = FALSE) THEN
            RAISE EXCEPTION 'ERROR: This task is not available, because parent task was not completed or not success';
        END IF;
    END IF;
    RETURN TRUE;
END; $$;



CREATE OR REPLACE FUNCTION get_count_p2p(checked varchar, checking varchar, task_name varchar)
    RETURNS INT
    LANGUAGE plpgsql
AS $$ BEGIN
    RETURN (SELECT count(*) FROM (SELECT * FROM p2p WHERE checking_peer = checking) AS p
            JOIN checks c
            ON p.check_id = c.id
                AND c.peer = checked
                AND c.task = task_name);

END; $$;



CREATE OR REPLACE FUNCTION exist_parent_task(task_name varchar)
    RETURNS BOOLEAN
    LANGUAGE plpgsql
AS $$ BEGIN
    RETURN (SELECT parent_task FROM tasks WHERE title = task_name) IS NOT NULL;
END; $$;



CREATE OR REPLACE FUNCTION get_max_check_id_from_checks_for_checked_and_task(checked varchar, task_name varchar)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$ BEGIN
    RETURN coalesce(
        (SELECT max(id) FROM checks
        WHERE peer = checked
            AND task = task_name),
    0);
END; $$;



CREATE OR REPLACE FUNCTION get_check_id_start_for_checked_and_checking_and_task(checked varchar, checking varchar, task_name varchar)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$ BEGIN
    RETURN (SELECT c.id FROM (SELECT * FROM p2p
                                WHERE checking_peer = checking AND p2p.state = 'start') AS p
                JOIN checks c
                ON p.check_id = c.id
                    AND c.peer = checked AND c.task = task_name
                ORDER BY c.date DESC, p.time DESC LIMIT 1);
END; $$;



CREATE OR REPLACE FUNCTION is_success_verter_check_task(id_for_check BIGINT)
    RETURNS BOOLEAN
    LANGUAGE plpgsql
AS $$ BEGIN
    RETURN (SELECT id FROM verter
            WHERE check_id = id_for_check
                AND state = 'success'
            ) IS NOT NULL;
END; $$;

-- 2) Написать процедуру добавления проверки Verter'ом
-- Параметры: ник проверяемого, название задания, статус проверки Verter'ом, время. 
-- Добавить запись в таблицу Verter (в качестве проверки указать проверку соответствующего задания с самым поздним (по времени) успешным P2P этапом)

CREATE OR REPLACE PROCEDURE add_verter_check(checked varchar, task_name varchar, state CHECK_STATUS, "time" time)
LANGUAGE plpgsql
AS $$ BEGIN
    IF is_success_last_p2p_check_task(checked, task_name) THEN
        INSERT INTO verter (check_id, state, time)
            VALUES (get_check_id_last_success_p2p_check(checked, task_name), state, time);
    ELSE RAISE EXCEPTION 'ERROR: This task is not success in last p2p check';
    END IF;
END; $$;



CREATE OR REPLACE FUNCTION is_success_last_p2p_check_task(checked varchar, task_name varchar)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$ BEGIN
    RETURN (SELECT c.id FROM (SELECT id FROM checks WHERE peer = checked AND task = task_name
                                                    ORDER BY id DESC LIMIT 1) AS c
                    JOIN p2p AS p
                    ON c.id = p.check_id AND p.state = 'success') IS NOT NULL;
END; $$;



CREATE OR REPLACE FUNCTION get_check_id_last_success_p2p_check(checked varchar, task_name varchar)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$ BEGIN
    RETURN (SELECT c.id FROM (SELECT * FROM checks WHERE peer = checked AND task = task_name
                                                    ORDER BY id DESC LIMIT 1) AS c
                JOIN p2p AS p
                ON c.id = p.check_id AND state = 'success'
            ORDER BY date DESC, time DESC LIMIT 1);
END; $$;

-- 3) Написать триггер: после добавления записи со статутом "начало" в таблицу P2P, изменить соответствующую запись в таблице TransferredPoints

CREATE OR REPLACE FUNCTION fnc_true_or_false(
    check_id BIGINT,
    fnc_checking_peer VARCHAR(30))
    RETURNS bool
    LANGUAGE plpgsql AS
$$BEGIN
    RETURN (SELECT count(*) <> 0 FROM transferredPoints
            WHERE checked_peer = (SELECT peer FROM checks
                                 WHERE id = check_id)
              AND checking_peer = fnc_checking_peer);
END;$$;

CREATE OR REPLACE FUNCTION fnc_check_transferred_points() RETURNS trigger
    LANGUAGE plpgsql AS
$$BEGIN
    IF (SELECT fnc_true_or_false(NEW.check_id, NEW.checking_peer)) THEN
        UPDATE transferredPoints SET points_amount = points_amount + 1
        WHERE checking_peer = NEW.checking_peer
          AND checked_peer = (SELECT peer FROM checks
                             WHERE id = NEW.check_id);
    ELSE
        INSERT INTO transferredPoints (checking_peer, checked_peer, points_amount)
        VALUES (NEW.checking_peer,
                (SELECT peer FROM checks
                 WHERE id = NEW.check_id),
                1);
    END IF;
    RETURN null;
END;$$;

CREATE TRIGGER trg_after_insert_p2p_success
    AFTER INSERT ON p2p FOR EACH ROW
    WHEN (NEW.state = 'start')
EXECUTE PROCEDURE fnc_check_transferred_points();

-- 4) Написать триггер: перед добавлением записи в таблицу XP, проверить корректность добавляемой записи

CREATE OR REPLACE FUNCTION fnc_check_max_xp() RETURNS trigger
    LANGUAGE plpgsql AS
$$BEGIN
    IF NEW.xp_amount >
       (SELECT t.max_xp FROM checks
                                JOIN tasks t on checks.task = t.title
        WHERE checks.id = NEW.check_id)
    THEN
        RAISE EXCEPTION 'Bad argument xpAmount: % > max xp', NEW.xp_amount;
    END IF;
    RETURN NEW;
END;$$;

CREATE TRIGGER trg_before_insert_xp
    BEFORE INSERT ON xp FOR EACH ROW
EXECUTE PROCEDURE fnc_check_max_xp();
