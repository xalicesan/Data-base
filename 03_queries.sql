-- ============================================================
-- 03_queries.sql — 13 запросов по варианту 4.10
-- Параметры задаются в начале файла (psql-переменные).
-- Значение 0 / 'ANY' означает «не фильтровать».
-- ============================================================

\set ON_ERROR_STOP on

-- Параметры по умолчанию (комментарии отдельными строками: \set забирает весь остаток строки)
-- type_code: BK | B | M | ANY
\set type_code       'ANY'
-- min_value: площадь для БК, число дорожек для Б/М
\set min_value       0
\set sport_id        1
-- min_rank_level: 1 = 3-й разряд, 2 = 2-й, 3 = 1-й
\set min_rank_level  0
\set coach_id        1
\set athlete_id      1
\set organizer_id    0
\set facility_id     0
\set competition_id  7
\set date_from       '2025-01-01'
\set date_to         '2025-12-31'

\echo '=== Запрос 1. Сооружения указанного типа / с заданными характеристиками ==='
SELECT f.id,
       f.name,
       f.type_name,
       f.coverage,
       f.area_m2,
       f.ring_size,
       f.pool_length_m,
       f.pool_lanes,
       f.tower_max_m,
       f.manege_lanes,
       f.manege_length_m,
       f.has_net,
       f.has_hoop
  FROM v_facility f
 WHERE (:'type_code' = 'ANY' OR f.type_code = :'type_code')
   AND (:min_value = 0 OR (CASE f.type_code
                              WHEN 'BK' THEN f.area_m2
                              WHEN 'B'  THEN f.pool_lanes
                              WHEN 'M'  THEN f.manege_lanes
                          END) >= :min_value)
 ORDER BY f.type_code, f.name;

\echo '=== Запрос 2. Спортсмены указанного вида спорта / не ниже разряда ==='
SELECT a.id,
       a.last_name || ' ' || a.first_name ||
           coalesce(' ' || a.middle_name, '') AS fio,
       r.name AS rank_name,
       cl.name AS club
  FROM athlete a
  JOIN rank r ON r.id = a.rank_id
  JOIN club cl ON cl.id = a.club_id
 WHERE (:sport_id = 0 OR EXISTS (
           SELECT 1
             FROM athlete_coach ac
             JOIN coach c  ON c.id = ac.coach_id
             JOIN club  cc ON cc.id = c.club_id
            WHERE ac.athlete_id = a.id
              AND cc.sport_id = :sport_id))
   AND (:min_rank_level = 0 OR r.level >= :min_rank_level)
 ORDER BY r.level DESC, a.last_name;

\echo '=== Запрос 3. Спортсмены указанного тренера / не ниже разряда ==='
SELECT a.id,
       a.last_name || ' ' || a.first_name ||
           coalesce(' ' || a.middle_name, '') AS fio,
       r.name AS rank_name,
       cl.name AS club
  FROM athlete a
  JOIN rank r ON r.id = a.rank_id
  JOIN club cl ON cl.id = a.club_id
 WHERE (:coach_id = 0 OR EXISTS (
           SELECT 1 FROM athlete_coach ac
            WHERE ac.athlete_id = a.id AND ac.coach_id = :coach_id))
   AND (:min_rank_level = 0 OR r.level >= :min_rank_level)
 ORDER BY r.level DESC, a.last_name;

\echo '=== Запрос 4. Спортсмены, занимающиеся более чем одним видом спорта ==='
SELECT a.id,
       a.last_name || ' ' || a.first_name ||
           coalesce(' ' || a.middle_name, '') AS fio,
       count(DISTINCT s.id) AS sports_count,
       string_agg(DISTINCT s.name, ', ' ORDER BY s.name) AS sports
  FROM athlete a
  JOIN athlete_coach ac ON ac.athlete_id = a.id
  JOIN coach c ON c.id = ac.coach_id
  JOIN club cl ON cl.id = c.club_id
  JOIN sport s ON s.id = cl.sport_id
 GROUP BY a.id, a.last_name, a.first_name, a.middle_name
HAVING count(DISTINCT s.id) > 1
 ORDER BY a.id;

\echo '=== Запрос 5. Тренеры указанного спортсмена ==='
SELECT c.id,
       c.last_name || ' ' || c.first_name ||
           coalesce(' ' || c.middle_name, '') AS fio,
       cl.name AS club,
       s.name  AS sport
  FROM athlete_coach ac
  JOIN coach c  ON c.id = ac.coach_id
  JOIN club  cl ON cl.id = c.club_id
  JOIN sport s  ON s.id = cl.sport_id
 WHERE ac.athlete_id = :athlete_id
 ORDER BY s.name, c.last_name;

\echo '=== Запрос 6. Соревнования за период / указанного организатора ==='
SELECT c.id,
       e.event_date,
       c.start_time,
       s.name AS sport,
       f.name AS facility,
       o.full_name AS organizer,
       e.title
  FROM competition c
  JOIN event e ON e.id = c.event_id
  JOIN sport s ON s.id = c.sport_id
  JOIN sport_facility f ON f.id = e.facility_id
  JOIN organizer o ON o.id = e.organizer_id
 WHERE e.event_date BETWEEN :'date_from' AND :'date_to'
   AND (:organizer_id = 0 OR e.organizer_id = :organizer_id)
 ORDER BY e.event_date, c.start_time;

\echo '=== Запрос 7. Призёры указанного соревнования ==='
SELECT p.place,
       a.id,
       a.last_name || ' ' || a.first_name ||
           coalesce(' ' || a.middle_name, '') AS fio,
       cl.name AS club,
       s.name  AS sport
  FROM participation p
  JOIN athlete a ON a.id = p.athlete_id
  JOIN club cl ON cl.id = a.club_id
  JOIN competition c ON c.id = p.competition_id
  JOIN sport s ON s.id = c.sport_id
 WHERE p.competition_id = :competition_id
   AND p.place IS NOT NULL
 ORDER BY p.place;

\echo '=== Запрос 8. Соревнования на указанном сооружении / по виду спорта ==='
SELECT c.id,
       e.event_date,
       c.start_time,
       s.name AS sport,
       f.name AS facility,
       count(p.athlete_id) AS participants
  FROM competition c
  JOIN event e ON e.id = c.event_id
  JOIN sport s ON s.id = c.sport_id
  JOIN sport_facility f ON f.id = e.facility_id
  LEFT JOIN participation p ON p.competition_id = c.id
 WHERE (:facility_id = 0 OR e.facility_id = :facility_id)
   AND (:sport_id = 0 OR c.sport_id = :sport_id)
 GROUP BY c.id, e.event_date, c.start_time, s.name, f.name
 ORDER BY e.event_date, c.start_time;

\echo '=== Запрос 9. Клубы и число их спортсменов, участвовавших в соревнованиях за период ==='
SELECT cl.id,
       cl.name AS club,
       s.name  AS sport,
       count(DISTINCT a.id) FILTER (WHERE e.id IS NOT NULL) AS athletes_in_period
  FROM club cl
  JOIN sport s ON s.id = cl.sport_id
  LEFT JOIN athlete a ON a.club_id = cl.id
  LEFT JOIN participation p ON p.athlete_id = a.id
  LEFT JOIN competition c ON c.id = p.competition_id
  LEFT JOIN event e ON e.id = c.event_id
                   AND e.event_date BETWEEN :'date_from' AND :'date_to'
 GROUP BY cl.id, cl.name, s.name
 ORDER BY athletes_in_period DESC, cl.name;

\echo '=== Запрос 10. Тренеры по указанному виду спорта ==='
SELECT c.id,
       c.last_name || ' ' || c.first_name ||
           coalesce(' ' || c.middle_name, '') AS fio,
       cl.name AS club
  FROM coach c
  JOIN club cl ON cl.id = c.club_id
  JOIN sport s ON s.id = cl.sport_id
 WHERE s.id = :sport_id
 ORDER BY cl.name, c.last_name;

\echo '=== Запрос 11. Спортсмены, не участвовавшие в соревнованиях за период ==='
SELECT a.id,
       a.last_name || ' ' || a.first_name ||
           coalesce(' ' || a.middle_name, '') AS fio,
       r.name  AS rank_name,
       cl.name AS club
  FROM athlete a
  JOIN rank r ON r.id = a.rank_id
  JOIN club cl ON cl.id = a.club_id
 WHERE NOT EXISTS (
       SELECT 1
         FROM participation p
         JOIN competition c ON c.id = p.competition_id
         JOIN event e ON e.id = c.event_id
        WHERE p.athlete_id = a.id
          AND e.event_date BETWEEN :'date_from' AND :'date_to')
 ORDER BY a.id;

\echo '=== Запрос 12. Организаторы и число проведённых соревнований за период ==='
SELECT o.id,
       o.full_name,
       count(c.id) AS competitions_count
  FROM organizer o
  LEFT JOIN event e ON e.organizer_id = o.id
                   AND e.event_date BETWEEN :'date_from' AND :'date_to'
  LEFT JOIN competition c ON c.event_id = e.id
 GROUP BY o.id, o.full_name
 ORDER BY competitions_count DESC, o.full_name;

\echo '=== Запрос 13. Сооружения и даты соревнований за период ==='
SELECT f.id,
       f.name AS facility,
       ft.name AS facility_type,
       e.event_date,
       c.start_time,
       s.name AS sport
  FROM event e
  JOIN sport_facility f ON f.id = e.facility_id
  JOIN facility_type ft ON ft.id = f.type_id
  JOIN competition c ON c.event_id = e.id
  JOIN sport s ON s.id = c.sport_id
 WHERE e.event_date BETWEEN :'date_from' AND :'date_to'
 ORDER BY f.name, e.event_date, c.start_time;
