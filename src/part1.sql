DROP DATABASE info21;

CREATE DATABASE info21;

-- DROP SCHEMA IF EXISTS public CASCADE;

CREATE SCHEMA IF NOT EXISTS public AUTHORIZATION public;

-- DROP TABLE IF EXISTS tasks, p2p, verter, checks, xp, peers,
--     transferredPoints, friends, recommendations, timeTracking CASCADE;



CREATE TABLE IF NOT EXISTS tasks
(
    title varchar NOT NULL PRIMARY KEY,
    parent_task varchar NULL REFERENCES tasks(title),
    max_XP bigint NOT NULL
);


INSERT INTO tasks VALUES ('CPP1_s21_matrix+', NULL, 300);
INSERT INTO tasks VALUES ('CPP2_s21_containers', 'CPP1_s21_matrix+', 350);
INSERT INTO tasks VALUES ('CPP3_SmartCalc_v2.0', 'CPP2_s21_containers', 600);
INSERT INTO tasks VALUES ('A1_Maze', 'CPP3_SmartCalc_v2.0', 300);
INSERT INTO tasks VALUES ('A2_SimpleNavigator_v1.0', 'A1_Maze', 400);
INSERT INTO tasks VALUES ('A3_Parallels', 'A2_SimpleNavigator_v1.0', 300);




CREATE TABLE IF NOT EXISTS peers
(
    nickname varchar PRIMARY KEY,
    birthday date NOT NULL
);

INSERT INTO peers VALUES ('mercury', '1985-01-12');
INSERT INTO peers VALUES ('venus', '1987-03-14');
INSERT INTO peers VALUES ('earth', '1989-05-16');
INSERT INTO peers VALUES ('saturn', '1991-07-18');
INSERT INTO peers VALUES ('jupiter', '1993-09-20');
INSERT INTO peers VALUES ('neptun', '1994-01-01');
INSERT INTO peers VALUES ('luna', '1998-12-10');
INSERT INTO peers VALUES ('mars', '2002-12-31');




CREATE TABLE IF NOT EXISTS checks
(
    id BIGSERIAL PRIMARY KEY,
    peer varchar NOT NULL REFERENCES peers(nickname),
    task varchar NOT NULL REFERENCES tasks(title),
    date date NOT NULL
);

INSERT INTO checks (peer, task, date) VALUES ('mercury', 'CPP1_s21_matrix+', '2022-12-16');
INSERT INTO checks (peer, task, date) VALUES ('venus', 'CPP2_s21_containers', '2022-12-16');
INSERT INTO checks (peer, task, date) VALUES ('earth', 'CPP2_s21_containers', '2022-12-16');
INSERT INTO checks (peer, task, date) VALUES ('earth', 'A1_Maze', '2022-12-17');
INSERT INTO checks (peer, task, date) VALUES ('saturn', 'CPP3_SmartCalc_v2.0', '2022-12-17');
INSERT INTO checks (peer, task, date) VALUES ('venus', 'CPP3_SmartCalc_v2.0', '2022-12-17');
INSERT INTO checks (peer, task, date) VALUES ('venus', 'CPP1_s21_matrix+', '2022-12-16');
INSERT INTO checks (peer, task, date) VALUES ('mercury', 'CPP2_s21_containers', '2022-12-24');
INSERT INTO checks (peer, task, date) VALUES ('mercury', 'A1_Maze', '2023-01-12');
INSERT INTO checks (peer, task, date) VALUES ('venus', 'A1_Maze', '2023-03-14');
INSERT INTO checks (peer, task, date) VALUES ('earth', 'A2_SimpleNavigator_v1.0', '2023-05-16');



CREATE TYPE CHECK_STATUS AS ENUM ('start', 'success', 'failure');

CREATE TABLE IF NOT EXISTS p2p
(
    id BIGSERIAL PRIMARY KEY,
    check_id bigint REFERENCES checks(id),
    checking_peer varchar NOT NULL REFERENCES peers(nickname),
    state CHECK_STATUS NOT NULL,
    time time NOT NULL,
    UNIQUE (check_id, checking_peer, state)
);

INSERT INTO p2p (check_id, checking_peer, state, time) VALUES (1, 'venus', 'start', '20:30');
INSERT INTO p2p (check_id, checking_peer, state, time) VALUES (1, 'venus', 'success', '21:04');
INSERT INTO p2p (check_id, checking_peer, state, time) VALUES (2, 'earth', 'start', '13:03');
INSERT INTO p2p (check_id, checking_peer, state, time) VALUES (2, 'earth', 'success', '13:37');
INSERT INTO p2p (check_id, checking_peer, state, time) VALUES (3, 'saturn', 'start', '08:17');
INSERT INTO p2p (check_id, checking_peer, state, time) VALUES (3, 'saturn', 'success', '09:03');
INSERT INTO p2p (check_id, checking_peer, state, time) VALUES (4, 'venus', 'start', '00:00');
INSERT INTO p2p (check_id, checking_peer, state, time) VALUES (4, 'venus', 'success', '00:44');
INSERT INTO p2p (check_id, checking_peer, state, time) VALUES (5, 'jupiter', 'start', '17:01');
INSERT INTO p2p (check_id, checking_peer, state, time) VALUES (5, 'jupiter', 'success', '17:48');
INSERT INTO p2p (check_id, checking_peer, state, time) VALUES (6, 'jupiter', 'start', '11:32');
INSERT INTO p2p (check_id, checking_peer, state, time) VALUES (6, 'jupiter', 'success', '12:13');
insert into p2p (check_id, checking_peer, state, time) VALUES (7, 'mercury', 'start', '21:00:29');
insert into p2p (check_id, checking_peer, state, time) VALUES (7, 'mercury', 'success', '21:31:57');
INSERT INTO p2p (check_id, checking_peer, state, time) VALUES (9, 'venus', 'start', '08:30');
INSERT INTO p2p (check_id, checking_peer, state, time) VALUES (9, 'venus', 'success', '09:12');
INSERT INTO p2p (check_id, checking_peer, state, time) VALUES (10, 'jupiter', 'start', '18:30');
INSERT INTO p2p (check_id, checking_peer, state, time) VALUES (10, 'jupiter', 'failure', '19:12');
INSERT INTO p2p (check_id, checking_peer, state, time) VALUES (11, 'jupiter', 'start', '10:12');
INSERT INTO p2p (check_id, checking_peer, state, time) VALUES (11, 'jupiter', 'success', '11:02');




CREATE TABLE IF NOT EXISTS verter
(
    id BIGSERIAL PRIMARY KEY,
    check_id bigint REFERENCES checks(id),
    state CHECK_STATUS NOT NULL,
    time time NOT NULL,
    UNIQUE (check_id, state)
);

-- DROP TABLE verter;

INSERT INTO verter (check_id, state, time) VALUES (1, 'start', '21:05');
INSERT INTO verter (check_id, state, time) VALUES (1, 'success', '21:07');
INSERT INTO verter (check_id, state, time) VALUES (2, 'start', '13:37');
INSERT INTO verter (check_id, state, time) VALUES (2, 'success', '13:38');
INSERT INTO verter (check_id, state, time) VALUES (3, 'start', '09:03');
INSERT INTO verter (check_id, state, time) VALUES (3, 'success', '09:04');
INSERT INTO verter (check_id, state, time) VALUES (4, 'start', '00:44');
INSERT INTO verter (check_id, state, time) VALUES (4, 'success', '00:45');
INSERT INTO verter (check_id, state, time) VALUES (5, 'start', '17:48');
INSERT INTO verter (check_id, state, time) VALUES (5, 'success', '17:49');
INSERT INTO verter (check_id, state, time) VALUES (7, 'start', '06:57');
INSERT INTO verter (check_id, state, time) VALUES (7, 'success', '06:58');
INSERT INTO verter (check_id, state, time) VALUES (8, 'start', '07:47');
INSERT INTO verter (check_id, state, time) VALUES (8, 'success', '07:49');
INSERT INTO verter (check_id, state, time) VALUES (9, 'start', '17:48');
INSERT INTO verter (check_id, state, time) VALUES (9, 'failure', '17:49');
INSERT INTO verter (check_id, state, time) VALUES (11, 'start', '11:48');
INSERT INTO verter (check_id, state, time) VALUES (11, 'success', '12:09');


CREATE TABLE IF NOT EXISTS xp
(
    id BIGSERIAL PRIMARY KEY,
    check_id bigint REFERENCES checks(id) UNIQUE,
    xp_amount integer NOT NULL CHECK ( xp_amount > 0 )
);
-- Первое поле этой таблицы может ссылаться только на успешные проверки.

INSERT INTO xp (check_id, xp_amount) VALUES (1, 280);
INSERT INTO xp (check_id, xp_amount) VALUES (2, 350);
INSERT INTO xp (check_id, xp_amount) VALUES (3, 350);
INSERT INTO xp (check_id, xp_amount) VALUES (4, 300);
INSERT INTO xp (check_id, xp_amount) VALUES (5, 550);
INSERT INTO xp (check_id, xp_amount) VALUES (6, 600);
INSERT INTO xp (check_id, xp_amount) VALUES (7, 300);
INSERT INTO xp (check_id, xp_amount) VALUES (11, 400);





CREATE TABLE IF NOT EXISTS transferredPoints
(
    id BIGSERIAL PRIMARY KEY,
    checking_peer varchar NOT NULL REFERENCES peers(nickname),
    checked_peer varchar NOT NULL REFERENCES peers(nickname),
    points_amount integer NOT NULL CHECK ( points_amount > 0 ),
    UNIQUE (checking_peer, checked_peer)
);

INSERT INTO transferredPoints (checking_peer, checked_peer, points_amount) VALUES ('mercury', 'venus', 1);
insert into transferredpoints (checking_peer, checked_peer, points_amount) values ('venus', 'mercury', 5);
INSERT INTO transferredPoints (checking_peer, checked_peer, points_amount) VALUES ('earth', 'mercury', 3);
insert into transferredpoints (checking_peer, checked_peer, points_amount) values ('mercury', 'earth', 7);
INSERT INTO transferredPoints (checking_peer, checked_peer, points_amount) VALUES ('saturn', 'jupiter', 2);
insert into transferredpoints (checking_peer, checked_peer, points_amount) values ('jupiter', 'saturn', 4);
INSERT INTO transferredPoints (checking_peer, checked_peer, points_amount) VALUES ('earth', 'jupiter', 3);
INSERT INTO transferredPoints (checking_peer, checked_peer, points_amount) VALUES ('venus', 'saturn', 1);



CREATE TABLE IF NOT EXISTS friends
(
    id BIGSERIAL PRIMARY KEY,
    peer1 varchar NOT NULL REFERENCES peers(nickname),
    peer2 varchar NOT NULL REFERENCES peers(nickname) CHECK ( peer2 <> peer1 ),
    UNIQUE (peer1, peer2)
);

INSERT INTO friends (peer1, peer2) VALUES ('mercury', 'venus');
INSERT INTO friends (peer1, peer2) VALUES ('mercury', 'earth');
INSERT INTO friends (peer1, peer2) VALUES ('saturn', 'earth');
INSERT INTO friends (peer1, peer2) VALUES ('jupiter', 'earth');
INSERT INTO friends (peer1, peer2) VALUES ('saturn', 'jupiter');
INSERT INTO friends (peer1, peer2) VALUES ('mercury', 'saturn');
INSERT INTO friends (peer1, peer2) VALUES ('saturn', 'venus');
INSERT INTO friends (peer1, peer2) VALUES ('mercury', 'jupiter');


CREATE TABLE IF NOT EXISTS recommendations
(
    id BIGSERIAL PRIMARY KEY,
    peer varchar NOT NULL REFERENCES peers(nickname),
    recommended_peer varchar NOT NULL REFERENCES peers(nickname) CHECK ( recommended_peer <> peer ),
    UNIQUE (peer, recommended_peer)
);

INSERT INTO recommendations (peer, recommended_peer) VALUES ('saturn', 'mercury');
INSERT INTO recommendations (peer, recommended_peer) VALUES ('saturn', 'venus');
INSERT INTO recommendations (peer, recommended_peer) VALUES ('jupiter', 'venus');
INSERT INTO recommendations (peer, recommended_peer) VALUES ('venus', 'earth');
INSERT INTO recommendations (peer, recommended_peer) VALUES ('earth', 'mercury');
INSERT INTO recommendations (peer, recommended_peer) VALUES ('earth', 'venus');


CREATE TABLE IF NOT EXISTS timeTracking
(
    id BIGSERIAL PRIMARY KEY,
    peer varchar NOT NULL REFERENCES peers(nickname),
    date date NOT NULL,
    time time NOT NULL,
    state integer NOT NULL CHECK ( state IN (1, 2) ),
    UNIQUE (peer, date, time)
);

INSERT INTO timeTracking (peer, date, time, state) VALUES ('saturn', '2022-12-01', '15:00', 1);
INSERT INTO timeTracking (peer, date, time, state) VALUES ('saturn', '2022-12-01', '18:43', 2);
INSERT INTO timeTracking (peer, date, time, state) VALUES ('saturn', '2022-12-01', '19:50', 1);
INSERT INTO timeTracking (peer, date, time, state) VALUES ('saturn', '2022-12-01', '23:23', 2);
INSERT INTO timeTracking (peer, date, time, state) VALUES ('earth', '2022-12-01', '07:00', 1);
INSERT INTO timeTracking (peer, date, time, state) VALUES ('earth', '2022-12-01', '14:00', 2);
INSERT INTO timeTracking(peer, date, time, state) VALUES ('mercury', '2022-12-28', '11:59', 1);
INSERT INTO timeTracking(peer, date, time, state) VALUES ('earth', now()::date, '10:00', 1);
INSERT INTO timeTracking(peer, date, time, state) VALUES ('earth', now()::date, '16:00', 2);
INSERT INTO timetracking(peer, date, time, state) VALUES
    ('mercury', now()::date - 1, '07:58', 1),
    ('mercury', now()::date - 2, '00:00', 1),
    ('mercury', now()::date - 3, '02:14', 1),
    ('saturn', now()::date - 1, '07:58', 1),
    ('saturn', now()::date - 1, '07:54', 1),
    ('saturn', now()::date - 1, '07:50', 1),
    ('saturn', now()::date - 2, '02:50', 1),
    ('saturn', now()::date - 3, '05:50', 1),
    ('saturn', now()::date - 4, '08:50', 1);
INSERT INTO timetracking(peer, date, time, state) VALUES
    ('mercury', now()::date - 1, '08:58', 2),
    ('mercury', now()::date - 2, '01:00', 2),
    ('mercury', now()::date - 3, '03:14', 2),
    ('saturn', now()::date - 1, '08:58', 2),
    ('saturn', now()::date - 1, '08:54', 2),
    ('saturn', now()::date - 1, '08:50', 2),
    ('saturn', now()::date - 2, '03:50', 2),
    ('saturn', now()::date - 3, '06:50', 2),
    ('saturn', now()::date - 4, '09:50', 2);
INSERT INTO timetracking (peer, date, time, state) VALUES
    ('venus', now()::date - 1, '07:00', 1), ('venus', now()::date - 1, '09:00', 2),
    ('venus', now()::date - 1, '11:00', 1), ('venus', now()::date - 1, '11:30', 2),
    ('venus', now()::date - 1, '12:00', 1), ('venus', now()::date - 1, '13:45', 2),
    ('jupiter', now()::date - 1, '00:00', 1), ('jupiter', now()::date - 1, '03:58', 2),
    ('jupiter', now()::date - 1, '04:48', 1), ('jupiter', now()::date - 1, '05:00', 2),
    ('jupiter', now()::date - 1, '06:12', 1), ('jupiter', now()::date - 1, '06:19', 2),
    ('jupiter', now()::date - 1, '06:30', 1), ('jupiter', now()::date - 1, '06:39', 2);



CREATE OR REPLACE PROCEDURE export(
    table_name VARCHAR(50),
    source VARCHAR(100),
    delimiter VARCHAR(5) DEFAULT ',')
    LANGUAGE plpgsql
AS $$
BEGIN
    EXECUTE format('COPY %I TO %L WITH DELIMITER %L CSV HEADER', table_name, source, delimiter);
END;
$$;

-- CALL export('tasks', '/home/student/for_sql/tasks.csv');


CREATE OR REPLACE PROCEDURE import(
    table_name VARCHAR(50),
    source VARCHAR(100),
    delimiter VARCHAR(5) DEFAULT ',')
    LANGUAGE plpgsql
AS $$
BEGIN
    EXECUTE format('COPY %I FROM %L WITH DELIMITER %L CSV HEADER', table_name, source, delimiter);
END;
$$;

-- CALL import('tasks', '/home/student/for_sql/tasks.csv');
