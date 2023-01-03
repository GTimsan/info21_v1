-- 1) Написать функцию, возвращающую таблицу TransferredPoints в более человекочитаемом виде

CREATE OR REPLACE FUNCTION get_transferred_points()
    RETURNS table(peer1 varchar, peer2 varchar, points_amount int)
    LANGUAGE plpgsql
AS $$ BEGIN
    RETURN QUERY
        WITH agg AS
                 (SELECT t1.id AS id1, t2.id AS id2, t1.checking_peer AS peer_1, t1.checked_peer AS peer_2,
                         t1.points_amount - coalesce(t2.points_amount, 0) AS points_amount_
                  FROM transferredpoints AS t1
                           LEFT JOIN transferredpoints AS t2
                                     ON t1.checking_peer = t2.checked_peer
                                         AND t1.checked_peer = t2.checking_peer)
        SELECT peer_1, peer_2, points_amount_ FROM agg WHERE id2 IS NULL
        UNION
        (SELECT a.peer_1, a.peer_2, agg.points_amount_
         FROM (SELECT id1 * id2 AS multi, max(peer_1) AS peer_1, min(peer_2) AS peer_2
               FROM agg WHERE id2 IS NOT NULL GROUP BY id1 * id2) AS a
                  JOIN agg ON a.peer_1 = agg.peer_1 AND a.peer_2 = agg.peer_2)
        ORDER BY peer_1, peer_2;
END; $$;

SELECT * FROM get_transferred_points();



-- 2) Написать функцию, которая возвращает таблицу вида: ник пользователя, название проверенного задания, кол-во полученного XP
-- В таблицу включать только задания, успешно прошедшие проверку (определять по таблице Checks).
-- Одна задача может быть успешно выполнена несколько раз. В таком случае в таблицу включать все успешные проверки.

CREATE OR REPLACE FUNCTION fnc_checks_xp()
    RETURNS TABLE(peer varchar, task varchar, xp integer) AS
$$
SELECT checks.peer, checks.task, xp.xp_amount AS xp
FROM checks
         JOIN p2p p on checks.id = p.check_id
         JOIN xp on checks.id = xp.check_id
WHERE p.state = 'success'
ORDER BY 1, 2, 3;
$$
    LANGUAGE sql;

SELECT * FROM fnc_checks_xp();



-- 3) Написать функцию, определяющую пиров, которые не выходили из кампуса в течение всего дня

CREATE OR REPLACE FUNCTION fnc_full_day_peers(date)
    RETURNS TABLE(peer varchar) AS
$$
WITH tmp AS
         (SELECT peer, date, COUNT(state) AS count
          FROM timetracking
          GROUP BY peer, date)

SELECT DISTINCT peer
FROM tmp
WHERE date = $1 AND count = 2;
$$
    LANGUAGE sql;

SELECT * FROM fnc_full_day_peers('2022-12-01');



-- 4) Найти процент успешных и неуспешных проверок за всё время

BEGIN;
CALL prc_success_failure_checks('ref');
FETCH ALL IN "ref";
COMMIT;


CREATE OR REPLACE PROCEDURE prc_success_failure_checks(ref REFCURSOR)
LANGUAGE plpgsql AS $$ BEGIN
    OPEN ref FOR
        WITH all_checks AS
                 (SELECT check_id, state
                  FROM p2p
                  WHERE state = 'success'
                     OR state = 'failure')

        SELECT
            ((SELECT count(state)
              FROM all_checks
              WHERE state = 'success') * 100 / (SELECT count(*) FROM all_checks)) AS SuccessfulChecks,
            ((SELECT count(state)
              FROM all_checks
              WHERE state = 'failure') * 100/ (SELECT count(*) FROM all_checks)) AS UnsuccessfulChecks;
END;$$;



-- 5) Посчитать изменение в количестве пир поинтов каждого пира по таблице TransferredPoints
-- Результат вывести отсортированным по изменению числа поинтов.
-- Формат вывода: ник пира, изменение в количество пир поинтов

BEGIN;
CALL prc_count_points('ref');
FETCH ALL IN "ref";
COMMIT;


CREATE OR REPLACE PROCEDURE prc_count_points(ref REFCURSOR)
    LANGUAGE plpgsql
    AS
$$ BEGIN
    OPEN ref FOR
        WITH union_table AS
                 (SELECT checking_peer AS peer, points_amount
                  FROM transferredpoints
                  UNION ALL
                  SELECT checked_peer, points_amount * (-1)
                  FROM transferredpoints)

        SELECT peer, SUM(points_amount) AS points_change
        FROM union_table
        GROUP BY peer
        ORDER BY 2 DESC;
END;
$$;



-- 6) Посчитать изменение в количестве пир поинтов каждого пира по таблице,
-- возвращаемой первой функцией из Part 3

BEGIN;
CALL get_count_points('ref');
FETCH ALL IN "ref";
COMMIT;


CREATE OR REPLACE PROCEDURE get_count_points(ref REFCURSOR)
    LANGUAGE plpgsql
AS $$ BEGIN
    OPEN ref FOR
        SELECT agg.peer, sum(agg.points_change) AS points_change FROM
            (SELECT peer1 AS peer, points_amount AS points_change FROM get_transferred_points()
             UNION ALL
             SELECT peer2 AS peer, points_amount * -1 AS points_change FROM get_transferred_points()) AS agg
        GROUP BY agg.peer
        ORDER BY points_change DESC, agg.peer;
END;$$;



-- 7) Определить самое часто проверяемое задание за каждый день

BEGIN;
CALL prc_get_most_popular_task_of_day('ref');
FETCH ALL IN "ref";
COMMIT;


CREATE OR REPLACE FUNCTION get_max_count_checked_task_of_day(target_date date)
    RETURNS int
    LANGUAGE plpgsql
AS $$ BEGIN
    RETURN (SELECT count(*) AS count FROM checks
            GROUP BY date, task HAVING date = target_date
            ORDER BY count DESC LIMIT 1);
END; $$;

CREATE OR REPLACE PROCEDURE prc_get_most_popular_task_of_day(ref REFCURSOR)
    LANGUAGE plpgsql
AS $$ BEGIN
    OPEN ref FOR
        WITH agg AS (SELECT date, task, count(*) AS count FROM checks
                     GROUP BY date, task ORDER BY date DESC)
        SELECT to_char(date, 'DD.MM.YYYY') AS day, substring(task from '^(.+?)_') AS task FROM agg
        WHERE count = get_max_count_checked_task_of_day(agg.date);
END;
$$;



-- 8) Определить длительность последней P2P проверки
-- Под длительностью подразумевается разница
-- между временем, указанным в записи со статусом "начало",
-- и временем, указанным в записи со статусом "успех" или "неуспех".
-- Формат вывода: длительность проверки

BEGIN;
CALL prc_finished_time('ref');
FETCH ALL IN "ref";
COMMIT;

CREATE OR REPLACE PROCEDURE prc_finished_time(ref REFCURSOR)
LANGUAGE plpgsql AS $$ BEGIN
    OPEN ref FOR
        WITH cte_finished_time AS (SELECT id, check_id, time
                                   FROM p2p
                                   WHERE state = 'success'
                                      OR state = 'failure'
                                   ORDER BY 1 DESC LIMIT 1)
        SELECT to_char((cte_finished_time.time - (SELECT time FROM p2p
                                                  WHERE check_id = cte_finished_time.check_id
                                                    AND state = 'start')), 'HH24:MI:SS') as interval FROM cte_finished_time;
END;$$;



-- 9) Найти всех пиров, выполнивших весь заданный блок задач и дату завершения
-- последнего задания

BEGIN;
CALL get_peer_who_completed_all_tasks_from_block('ref', 'CPP');
FETCH ALL IN "ref";
COMMIT;


CREATE OR REPLACE PROCEDURE get_peer_who_completed_all_tasks_from_block(ref REFCURSOR, block_name VARCHAR)
    LANGUAGE plpgsql
AS $$ BEGIN
    OPEN ref FOR
        SELECT c.peer, to_char(max(c.date), 'DD.MM.YYYY') AS day FROM checks c
        JOIN p2p on c.id = p2p.check_id AND p2p.state = 'success'
                                        AND c.task IN (SELECT title FROM tasks
                                                        WHERE title SIMILAR TO format('%s[0-9]+_%%', block_name))
        LEFT JOIN verter v on c.id = v.check_id
        WHERE v.state = 'success' OR v.state IS NULL
        GROUP BY c.peer
        HAVING count(DISTINCT c.task) =
               (SELECT count(*) FROM tasks
                WHERE title SIMILAR TO format('%s[0-9]+_%%', block_name));
END;$$;



-- 10) Определить, к какому пиру стоит идти на проверку каждому обучающемуся
-- Определять нужно исходя из рекомендаций друзей пира, т.е. нужно найти пира,
-- проверяться у которого рекомендует наибольшее число друзей.
-- Формат вывода: ник пира, ник найденного проверяющего

BEGIN;
CALL get_recommended_from_friends('ref');
FETCH ALL IN "ref";
COMMIT;


CREATE OR REPLACE PROCEDURE get_recommended_from_friends(ref REFCURSOR)
    LANGUAGE plpgsql
AS $$ BEGIN
    OPEN ref FOR
        WITH agg AS (SELECT f.peer1, r.recommended_peer, count(*) AS count FROM friends f
                                                                                    JOIN recommendations r
                                                                                         ON f.peer2 = r.peer AND f.peer1 <> r.recommended_peer
                     GROUP BY f.peer1, r.recommended_peer)
        SELECT a1.peer1 AS peer, min(a1.recommended_peer) AS recommended_peer FROM agg AS a1
        WHERE a1.count = (SELECT max(a2.count) FROM agg AS a2 WHERE a1.peer1 = a2.peer1)
        GROUP BY a1.peer1
        ORDER BY a1.peer1;
        END;
$$;



-- 11) Определить процент пиров, которые:
-- Приступили к блоку 1
-- Приступили к блоку 2
-- Приступили к обоим
-- Не приступили ни к одному

BEGIN;
CALL get_percent_of_peers('ref', 'CPP', 'A');
FETCH ALL IN "ref";
COMMIT;


CREATE OR REPLACE PROCEDURE get_percent_of_peers(ref REFCURSOR, block1 varchar, block2 varchar)
    LANGUAGE plpgsql
AS $$ BEGIN
    OPEN ref FOR
        WITH count_of_peers AS (SELECT count(*) FROM peers),
             peers_stat AS
                 (SELECT nickname,
                         count(DISTINCT CASE WHEN task SIMILAR TO format('%s[0-9]+_%%', block1) THEN 1 END) AS b1,
                         count(DISTINCT CASE WHEN task SIMILAR TO format('%s[0-9]+_%%', block2) THEN 1 END) AS b2
                  FROM peers p
                           LEFT JOIN checks c on p.nickname = c.peer
                  GROUP BY nickname)
        SELECT round(count(CASE WHEN b1 = 1 AND b2 = 0 THEN 1 END)::numeric / (SELECT * FROM count_of_peers) * 100, 0)
                   AS started_block1,
               round(count(CASE WHEN b1 = 0 AND b2 = 1 THEN 1 END)::numeric / (SELECT * FROM count_of_peers) * 100, 0)
                   AS started_block2,
               round(count(CASE WHEN b1 = 1 AND b2 = 1 THEN 1 END)::numeric / (SELECT * FROM count_of_peers) * 100, 0)
                   AS started_both_blocks,
               round(count(CASE WHEN b1 = 0 AND b2 = 0 THEN 1 END)::numeric / (SELECT * FROM count_of_peers) * 100, 0)
                   AS didnt_start_any_block
        FROM peers_stat;
END; $$;



-- 12) Определить N пиров с наибольшим числом друзей
-- Параметры процедуры: количество пиров N.
-- Результат вывести отсортированным по кол-ву друзей.
-- Формат вывода: ник пира, количество друзей

BEGIN;
CALL max_friends('ref', 4);
FETCH ALL IN "ref";
COMMIT;


CREATE OR REPLACE PROCEDURE max_friends(ref REFCURSOR, N integer)
    LANGUAGE plpgsql
AS $$ BEGIN
    OPEN ref FOR
        WITH all_peers AS
                 (SELECT peer1 AS peer, count(peer2) AS friendsCount
                  FROM (SELECT peer1, peer2
                        FROM friends
                        UNION ALL
                        SELECT peer2, peer1
                        FROM friends) AS twice_friends
                  GROUP BY peer
                 )

        SELECT nickname AS peer, COALESCE(friendsCount, 0)
        FROM all_peers
                 RIGHT JOIN peers ON nickname = peer
        ORDER BY 2 DESC, 1
        LIMIT N;
END;
$$;



-- 13) Определить процент пиров, которые когда-либо успешно проходили проверку в свой день рождения
-- Также определите процент пиров, которые хоть раз проваливали проверку в свой день рождения.
-- Формат вывода: процент успехов в день рождения, процент неуспехов в день рождения

BEGIN;
CALL prc_find_peer_percent('ref');
FETCH ALL IN "ref";
COMMIT;


CREATE OR REPLACE PROCEDURE prc_find_peer_percent(ref REFCURSOR)
    LANGUAGE plpgsql AS $$ BEGIN
    OPEN ref FOR
        WITH checks_on_birthday AS (
            SELECT nickname, date, p2p.state AS p_state, verter.state AS v_state
            FROM peers
                     JOIN checks ON peers.nickname = checks.peer
                     JOIN p2p ON checks.id = p2p.check_id
                     LEFT JOIN verter ON checks.id = verter.check_id AND (verter.state = 'success' OR verter.state = 'failure')
            WHERE date_part('day', checks.date) = date_part('day', peers.birthday)
              AND date_part('month', checks.date) = date_part('month', peers.birthday)
              AND (p2p.state = 'success' OR p2p.state = 'failure')
        ), agg_table AS (
            SELECT nickname, date, (
                CASE WHEN p_state = 'success' AND v_state <> 'failure'
                         THEN 1
                     ELSE 0
                    END
                ) AS final_state
            FROM checks_on_birthday)

        SELECT
            ((SELECT sum(final_state)
              FROM agg_table) * 100 / (SELECT count(*) FROM agg_table)) AS SuccessfulChecks,
            (100 - (SELECT sum(final_state)
                    FROM agg_table) * 100 / (SELECT count(*) FROM agg_table)) AS UnsuccessfulChecks;
END;$$;



-- 14) Определить кол-во XP, полученное в сумме каждым пиром
-- Если одна задача выполнена несколько раз, полученное за нее кол-во XP равно максимальному за эту задачу.
-- Результат вывести отсортированным по кол-ву XP.
-- Формат вывода: ник пира, количество XP

BEGIN;
CALL prc_find_sum_xp('ref');
FETCH ALL IN "ref";
COMMIT;


CREATE OR REPLACE PROCEDURE prc_find_sum_xp(ref REFCURSOR)
LANGUAGE plpgsql AS $$ BEGIN
    OPEN ref FOR
        WITH cte_tmp_table AS (SELECT c.peer, c.task,
                                      CASE WHEN count(c.task) > 1 THEN (
                                          SELECT max_xp FROM tasks WHERE title = c.task)
                                           ELSE sum(xp.xp_amount)
                                          END
                               FROM xp
                                        JOIN checks c ON (xp.check_id = c.id)
                               GROUP BY c.peer, c.task)

        SELECT peer AS Peer, sum(sum) AS XP FROM cte_tmp_table
        GROUP BY peer
        ORDER BY XP DESC;
END;$$;



-- 15) Определить всех пиров, которые сдали заданные задания 1 и 2, но не сдали задание 3
-- Параметры процедуры: названия заданий 1, 2 и 3.
-- Формат вывода: список пиров

BEGIN;
CALL peer_checker('ref', 'CPP3_SmartCalc_v2.0', 'CPP2_s21_containers', 'A1_Maze');
FETCH ALL IN "ref";
COMMIT;


CREATE OR REPLACE PROCEDURE peer_checker
    (ref REFCURSOR, task1 VARCHAR, task2 VARCHAR, task3 VARCHAR)
    LANGUAGE plpgsql
AS $$ BEGIN
    OPEN ref FOR
    WITH agg AS (
        SELECT c.id, c.peer AS checked, p.checking_peer AS checking, c.task,
                p.state AS p_state, v.state AS v_state
        FROM checks c
        JOIN p2p p ON c.id = p.check_id AND c.task IN (task1, task2, task3) AND p.state = 'success'
        LEFT JOIN verter v on c.id = v.check_id
        WHERE v.state = 'success' OR v.state IS NULL
                )
    SELECT a1.checked AS peer FROM agg AS a1
    WHERE a1.task = task1
    INTERSECT
    SELECT a2.checked AS peer FROM agg AS a2
    WHERE a2.task = task2
    EXCEPT
    SELECT a3.checked AS peer FROM agg AS a3
    WHERE a3.task = task3;
END;$$;



-- 16) Используя рекурсивное обобщенное табличное выражение, для каждой задачи вывести кол-во предшествующих ей задач
-- То есть сколько задач нужно выполнить, исходя из условий входа, чтобы получить доступ к текущей.
-- Формат вывода: название задачи, количество предшествующих

BEGIN;
CALL prc_count_previous_task('ref');
FETCH ALL IN "ref";
COMMIT;


CREATE OR REPLACE PROCEDURE prc_count_previous_task(ref REFCURSOR)
LANGUAGE plpgsql AS $$BEGIN
    OPEN ref FOR
        WITH RECURSIVE count_previous_task AS (
            SELECT title AS task,
                   1 AS prevCount
            FROM tasks
            WHERE title = 'CPP1_s21_matrix+'
            UNION
            SELECT tasks.title,
                   count_previous_task.prevCount + 1 AS prevCount
            FROM tasks
                     JOIN count_previous_task ON tasks.parent_task = count_previous_task.task
        )
        SELECT *
        FROM count_previous_task;
END;$$;



-- 17) Найти "удачные" для проверок дни. День считается "удачным", если в нем есть хотя бы N идущих подряд успешных проверки
-- Параметры процедуры: количество идущих подряд успешных проверок N.
-- Временем проверки считать время начала P2P этапа.
-- Под идущими подряд успешными проверками подразумеваются успешные проверки, между которыми нет неуспешных.
-- При этом кол-во опыта за каждую из этих проверок должно быть не меньше 80% от максимального.
-- Формат вывода: список дней

BEGIN;
    CALL get_success_days('ref', 4);
    FETCH ALL IN "ref";
COMMIT;


CREATE OR REPLACE PROCEDURE get_success_days(ref refcursor, n int)
LANGUAGE plpgsql
AS $$ BEGIN
    OPEN ref FOR
        SELECT * FROM fnc_get_success_days(n);
END; $$;


CREATE OR REPLACE FUNCTION fnc_get_success_days(n int)
RETURNS SETOF date
    LANGUAGE plpgsql
AS $$
DECLARE
    row record;
    row2 record;
    i int := 0;
BEGIN
    FOR row IN
        SELECT c.date FROM checks AS c GROUP BY c.date ORDER BY c.date
    LOOP
        FOR row2 IN
            SELECT *
            FROM
                (
                SELECT c.id AS id, c.date, p2.time AS time,
                    (CASE WHEN v.state = 'success' AND x.xp_amount * 100 / t.max_xp >= 80 THEN 1 ELSE 0 END) AS state
                FROM checks c
                JOIN p2p p on c.id = p.check_id AND p.state <> 'start'
                LEFT JOIN verter v on c.id = v.check_id AND v.state <> 'start'
                LEFT JOIN xp x on c.id = x.check_id
                JOIN tasks t on c.task = t.title
                JOIN p2p p2 on c.id = p2.check_id AND p2.state = 'start'
                ) AS agg
            WHERE row.date = agg.date
            ORDER BY agg.time

            LOOP
                IF row2.state = 1 THEN
                    i := i + 1;
                    IF i = n THEN
                        RETURN NEXT row2.date;
                        EXIT;
                    END IF;
                ELSE
                    i := 0;
                END IF;
            END LOOP;
        i := 0;
    END LOOP;
    RETURN;
END; $$;



-- 18) Определить пира с наибольшим числом выполненных заданий
-- Формат вывода: ник пира, число выполненных заданий

BEGIN;
CALL prc_find_peer_max_success('ref');
FETCH ALL IN "ref";
COMMIT;


CREATE OR REPLACE PROCEDURE prc_find_peer_max_success(ref REFCURSOR)
LANGUAGE plpgsql AS $$BEGIN
    OPEN ref FOR
        SELECT checks.peer AS Peer, count(*) AS XP FROM xp
                    JOIN checks ON (xp.check_id = checks.id)
        GROUP BY checks.peer
        ORDER BY 2 DESC
        LIMIT 1
        ;
END;$$;



-- 19) Определить пира с наибольшим количеством XP

BEGIN;
CALL prc_find_peer_max_xp('ref');
FETCH ALL IN "ref";
COMMIT;


CREATE OR REPLACE PROCEDURE prc_find_peer_max_xp(ref REFCURSOR)
LANGUAGE plpgsql AS $$BEGIN
    OPEN ref FOR
        SELECT checks.peer AS Peer, SUM(xp.xp_amount) AS XP FROM xp
                    JOIN checks ON (xp.check_id = checks.id)
        GROUP BY checks.peer
        ORDER BY 2 DESC
        LIMIT 1
    ;END;$$;



-- 20) Определить пира, который провел сегодня в кампусе больше всего времени
-- Формат вывода: ник пира

BEGIN;
    CALL get_peer_most_time_today('ref');
    FETCH ALL IN "ref";
COMMIT;


CREATE OR REPLACE PROCEDURE get_peer_most_time_today(ref REFCURSOR)
LANGUAGE plpgsql
AS $$ BEGIN
    OPEN ref FOR
        SELECT * FROM fnc_get_peer_most_time_today();
END; $$;


CREATE OR REPLACE FUNCTION fnc_get_peer_most_time_today()
RETURNS varchar
LANGUAGE plpgsql
AS $$
DECLARE
    peer_name varchar;
    row record;
    is_first boolean := true;
    time_in time;
    time_out time;
    is_out boolean := true;
    max interval := '00:00';
    max_peer_name varchar;
    cur_interval interval := '00:00';
BEGIN
    FOR peer_name IN SELECT nickname FROM peers
    LOOP

        FOR row IN SELECT * FROM timetracking WHERE date = now()::date AND peer = peer_name
        LOOP

            IF row.state = 1 THEN
                time_in = row.time;  -- проверить, если это время последнее
                is_out := false;
            ELSE
                IF is_first THEN
                    time_in = '00:00';
                END IF;
                time_out = row.time;
                is_out = true;
                cur_interval := cur_interval + (time_out - time_in);
            END IF;
            is_first := false;

        END LOOP;

    IF is_out = false THEN
        cur_interval := cur_interval + ('24:00' - time_in);
    END IF;

    IF cur_interval > max THEN
        max := cur_interval;
        max_peer_name = peer_name;
    END IF;

    cur_interval := '00:00';
    is_first := true;
    is_out = true;

    END LOOP;

    RETURN max_peer_name;
END; $$;



-- 21) Определить пиров, приходивших раньше заданного времени не менее N раз за всё время
-- Параметры процедуры: время, количество раз N.
-- Формат вывода: список пиров

BEGIN;
CALL prc_get_peers_who_came_early('ref','16:00', 3);
FETCH ALL IN "ref";
COMMIT;


CREATE OR REPLACE PROCEDURE prc_get_peers_who_came_early(ref REFCURSOR, target_time time, N int)
    LANGUAGE plpgsql
AS $$ BEGIN
    OPEN ref FOR
        SELECT t.peer FROM peers p
                               JOIN timetracking t on p.nickname = t.peer AND t.state = 1 AND t.time < target_time
        GROUP BY t.peer
        HAVING count(DISTINCT t.date) >= N;
END; $$;



-- 22) Определить пиров, выходивших за последние N дней из кампуса больше M раз
-- Параметры процедуры: количество дней N, количество раз M.
-- Формат вывода: список пиров

BEGIN;
CALL prc_get_peers_who_out_of_campus_more_then_M('ref', 2, 2);
FETCH ALL IN "ref";
COMMIT;


CREATE OR REPLACE PROCEDURE prc_get_peers_who_out_of_campus_more_then_M(ref REFCURSOR, N int, M int)
    LANGUAGE plpgsql
AS $$ BEGIN
    OPEN ref FOR
        SELECT t.peer FROM peers p
                               JOIN timetracking t ON p.nickname = t.peer AND t.state = 2 AND t.date > now()::date - N
        GROUP BY t.peer
        HAVING count(t.time) - count(DISTINCT t.date) > M;
END; $$;



-- 23) Определить пира, который пришел сегодня последним
-- Формат вывода: ник пира

BEGIN;
    CALL get_peer_who_came_today_last('ref');
    FETCH ALL IN "ref";
COMMIT;


CREATE OR REPLACE PROCEDURE get_peer_who_came_today_last(ref REFCURSOR)
LANGUAGE plpgsql
AS $$ BEGIN
    OPEN ref FOR
        SELECT peer AS time FROM timetracking
        WHERE date = now()::date AND state = 1
        GROUP BY peer
        ORDER BY min(time) DESC
        LIMIT 1;
END; $$;



-- 24) Определить пиров, которые выходили вчера из кампуса больше чем на N минут
-- Параметры процедуры: количество минут N.
-- Формат вывода: список пиров

BEGIN;
    CALL get_peers_who_came_out_yesterday_more_then_N_minutes('ref', '00:20');
    FETCH ALL IN "ref";
COMMIT;


CREATE OR REPLACE PROCEDURE get_peers_who_came_out_yesterday_more_then_N_minutes(ref REFCURSOR, N interval minute)
LANGUAGE plpgsql
AS $$ BEGIN
    OPEN ref FOR
        SELECT * FROM fnc_get_peers_who_came_out_yesterday_more_then_N_minutes(N);
END; $$;


CREATE OR REPLACE FUNCTION fnc_get_peers_who_came_out_yesterday_more_then_N_minutes(N interval minute)
RETURNS SETOF varchar
LANGUAGE plpgsql
AS $$
DECLARE
    peer_name varchar;
    row record;
    time_out time;
    is_first_step bool := TRUE;

BEGIN
    FOR peer_name IN
        SELECT peer FROM timetracking
        WHERE date = now()::date - 1
        GROUP BY peer
        HAVING count(*) >= 4
    LOOP

        FOR row IN
            SELECT * FROM timetracking
            WHERE date = now()::date - 1 AND peer = peer_name
        LOOP

            IF row.state = 2 THEN
                time_out := row.time;
            ELSE
                IF is_first_step = FALSE THEN
                    IF row.time - time_out > N THEN
                        RETURN NEXT peer_name;
                        EXIT;
                    END IF;
                END IF;
            END IF;
            is_first_step := FALSE;

        END LOOP;

        is_first_step := TRUE;
    END LOOP;
    RETURN;
END; $$;



-- 25) Определить для каждого месяца процент ранних входов
-- Для каждого месяца посчитать, сколько раз люди, родившиеся в этот месяц,
--      приходили в кампус за всё время (будем называть это общим числом входов).
-- Для каждого месяца посчитать, сколько раз люди, родившиеся в этот месяц,
--      приходили в кампус раньше 12:00 за всё время (будем называть это числом ранних входов).
-- Для каждого месяца посчитать процент ранних входов в кампус относительно общего числа входов.
-- Формат вывода: месяц, процент ранних входов

BEGIN;
    CALL get_percent_early_entries_for_each_months('ref');
    FETCH ALL IN "ref";
COMMIT;


CREATE OR REPLACE PROCEDURE get_percent_early_entries_for_each_months(ref REFCURSOR)
LANGUAGE plpgsql
AS $$
BEGIN
    OPEN ref FOR
        SELECT * FROM fnc_get_percent_early_entries_for_each_months();
END; $$;


CREATE OR REPLACE FUNCTION fnc_get_percent_early_entries_for_each_months()
RETURNS table(month varchar, early_entries numeric)
LANGUAGE plpgsql
AS $$ BEGIN
    FOR curr_month IN 1..12 LOOP
        RETURN QUERY
        WITH agg AS (SELECT peer, date, MIN(time) AS time_min, CASE WHEN MIN(time) < '12:00' THEN 1 ELSE 0 END AS early
                     FROM timetracking
                      WHERE peer IN (SELECT nickname FROM peers WHERE DATE_PART('month', birthday) = curr_month)
                        AND state = 1
                      GROUP BY peer, date)
        SELECT get_month_varchar(curr_month) AS month,
                (SELECT coalesce(round((CASE WHEN sum(early) = 0 THEN 1 ELSE sum(early) END)::numeric /
                              (CASE WHEN count(*) = 0 THEN 1 ELSE count(*) END) * 100), 0)
                FROM agg) AS early_entries;

        curr_month := curr_month + 1;
    END LOOP;
END; $$;


CREATE OR REPLACE FUNCTION get_month_varchar(n int)
RETURNS varchar
LANGUAGE plpgsql
AS $$
DECLARE
    month varchar[] := '{"January", "February", "March", "April", "May",' ||
                    '"June", "July", "August", "September", "October", "November", "December"}';
BEGIN
    RETURN month[n];
END; $$;