-- ============================================================
-- 01_schema.sql
-- ИС спортивных организаций города (вариант 4.10)
-- СУБД: PostgreSQL 17
-- ============================================================

BEGIN;

DROP VIEW  IF EXISTS v_facility CASCADE;
DROP TABLE IF EXISTS participation, competition, event, athlete_coach,
                     coach, athlete, facility_sport, manege, pool,
                     boxing_club, sport_facility, organizer, club,
                     facility_type, rank, sport CASCADE;

-- ---------- Справочники ----------

CREATE TABLE sport (
    id   smallint PRIMARY KEY,
    code text NOT NULL UNIQUE,
    name text NOT NULL UNIQUE
);

CREATE TABLE rank (
    id    smallint PRIMARY KEY,
    name  text     NOT NULL UNIQUE,
    level smallint NOT NULL UNIQUE CHECK (level > 0)
);
COMMENT ON COLUMN rank.level IS 'Числовой уровень: 3-й разряд = 1, 2-й = 2, 1-й = 3';

CREATE TABLE facility_type (
    id   smallint PRIMARY KEY,
    code text NOT NULL UNIQUE,
    name text NOT NULL
);

-- ---------- Клубы и организаторы ----------

CREATE TABLE club (
    id       smallint PRIMARY KEY,
    name     text     NOT NULL UNIQUE,
    sport_id smallint NOT NULL REFERENCES sport (id)
);

CREATE TABLE organizer (
    id        smallint PRIMARY KEY,
    full_name text NOT NULL
);

-- ---------- Спортивные сооружения (супертип + подтипы) ----------

CREATE TABLE sport_facility (
    id      smallint PRIMARY KEY,
    name    text     NOT NULL UNIQUE,
    type_id smallint NOT NULL REFERENCES facility_type (id)
);

CREATE TABLE boxing_club (
    facility_id smallint PRIMARY KEY
                REFERENCES sport_facility (id) ON DELETE CASCADE,
    coverage    text    NOT NULL CHECK (coverage IN ('мягкое', 'твердое')),
    area_m2     integer NOT NULL CHECK (area_m2 > 0),
    ring_size   text,
    bags        smallint NOT NULL CHECK (bags >= 0)
);

CREATE TABLE pool (
    facility_id smallint PRIMARY KEY
                REFERENCES sport_facility (id) ON DELETE CASCADE,
    length_m    smallint     NOT NULL CHECK (length_m IN (25, 50)),
    depth_m     numeric(3,1) NOT NULL CHECK (depth_m > 0),
    lanes       smallint     NOT NULL CHECK (lanes BETWEEN 1 AND 10),
    tower_max_m numeric(3,1) CHECK (tower_max_m > 0)
);
COMMENT ON COLUMN pool.tower_max_m IS 'Максимальная вышка, м; NULL — вышек нет (ПСВ проводить нельзя)';

CREATE TABLE manege (
    facility_id smallint PRIMARY KEY
                REFERENCES sport_facility (id) ON DELETE CASCADE,
    lanes     smallint NOT NULL CHECK (lanes > 0),
    length_m  smallint NOT NULL CHECK (length_m > 0),
    has_net   boolean  NOT NULL,
    has_hoop  boolean  NOT NULL
);

-- Допустимые виды спорта на сооружении
CREATE TABLE facility_sport (
    facility_id smallint NOT NULL REFERENCES sport_facility (id) ON DELETE CASCADE,
    sport_id    smallint NOT NULL REFERENCES sport (id),
    PRIMARY KEY (facility_id, sport_id)
);

-- ---------- Спортсмены и тренеры ----------

CREATE TABLE athlete (
    id          smallint PRIMARY KEY,
    last_name   text     NOT NULL,
    first_name  text     NOT NULL,
    middle_name text,
    birth_date  date     NOT NULL,
    rank_id     smallint NOT NULL REFERENCES rank (id),
    club_id     smallint NOT NULL REFERENCES club (id)
);

CREATE TABLE coach (
    id          smallint PRIMARY KEY,
    last_name   text     NOT NULL,
    first_name  text     NOT NULL,
    middle_name text,
    club_id     smallint NOT NULL REFERENCES club (id)
);

-- Тренировки: спортсмен <-> тренер (M:N). Вид спорта выводится из клуба тренера.
CREATE TABLE athlete_coach (
    athlete_id smallint NOT NULL REFERENCES athlete (id) ON DELETE CASCADE,
    coach_id   smallint NOT NULL REFERENCES coach (id) ON DELETE CASCADE,
    PRIMARY KEY (athlete_id, coach_id)
);

-- ---------- Мероприятия и соревнования ----------

CREATE TABLE event (
    id           smallint PRIMARY KEY,
    organizer_id smallint NOT NULL REFERENCES organizer (id),
    facility_id  smallint NOT NULL REFERENCES sport_facility (id),
    event_date   date     NOT NULL,
    title        text     NOT NULL
);

CREATE TABLE competition (
    id         smallint PRIMARY KEY,
    event_id   smallint NOT NULL REFERENCES event (id) ON DELETE CASCADE,
    sport_id   smallint NOT NULL REFERENCES sport (id),
    start_time time     NOT NULL,
    UNIQUE (event_id, sport_id)
);

CREATE TABLE participation (
    competition_id smallint NOT NULL REFERENCES competition (id) ON DELETE CASCADE,
    athlete_id     smallint NOT NULL REFERENCES athlete (id) ON DELETE CASCADE,
    place          smallint CHECK (place BETWEEN 1 AND 3),
    PRIMARY KEY (competition_id, athlete_id)
);
-- В одном соревновании не может быть двух одинаковых призовых мест
CREATE UNIQUE INDEX ux_participation_place
    ON participation (competition_id, place)
    WHERE place IS NOT NULL;

-- ---------- Индексы ----------

CREATE INDEX ix_athlete_club      ON athlete (club_id);
CREATE INDEX ix_coach_club        ON coach (club_id);
CREATE INDEX ix_competition_sport ON competition (sport_id);
CREATE INDEX ix_event_date        ON event (event_date);
CREATE INDEX ix_event_facility    ON event (facility_id);
CREATE INDEX ix_participation_ath ON participation (athlete_id);

-- ============================================================
-- Триггеры целостности
-- ============================================================

-- 1. Подтип сооружения должен соответствовать типу
CREATE OR REPLACE FUNCTION fn_subtype_type() RETURNS trigger AS $$
DECLARE
    v_expected text;
    v_actual   text;
BEGIN
    v_expected := CASE TG_TABLE_NAME
                      WHEN 'boxing_club' THEN 'BK'
                      WHEN 'pool'        THEN 'B'
                      WHEN 'manege'      THEN 'M'
                  END;
    SELECT ft.code INTO v_actual
      FROM sport_facility f
      JOIN facility_type ft ON ft.id = f.type_id
     WHERE f.id = NEW.facility_id;

    IF v_actual IS DISTINCT FROM v_expected THEN
        RAISE EXCEPTION 'Сооружение % имеет тип %, а подтип ожидает %',
            NEW.facility_id, coalesce(v_actual, '?'), v_expected;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_boxing_club_type BEFORE INSERT OR UPDATE ON boxing_club
    FOR EACH ROW EXECUTE FUNCTION fn_subtype_type();
CREATE TRIGGER trg_pool_type BEFORE INSERT OR UPDATE ON pool
    FOR EACH ROW EXECUTE FUNCTION fn_subtype_type();
CREATE TRIGGER trg_manege_type BEFORE INSERT OR UPDATE ON manege
    FOR EACH ROW EXECUTE FUNCTION fn_subtype_type();

-- 2. Вид спорта в facility_sport должен соответствовать оборудованию
CREATE OR REPLACE FUNCTION fn_facility_sport_equipment() RETURNS trigger AS $$
DECLARE
    v_code text;
    v_ok   boolean := false;
BEGIN
    SELECT code INTO v_code FROM sport WHERE id = NEW.sport_id;

    IF v_code = 'BOX' THEN
        SELECT EXISTS (SELECT 1 FROM boxing_club b
                        WHERE b.facility_id = NEW.facility_id
                          AND b.ring_size IS NOT NULL) INTO v_ok;
    ELSIF v_code IN ('JUDO', 'WR') THEN
        SELECT EXISTS (SELECT 1 FROM boxing_club b
                        WHERE b.facility_id = NEW.facility_id
                          AND b.coverage = 'мягкое') INTO v_ok;
    ELSIF v_code = 'DV' THEN
        SELECT EXISTS (SELECT 1 FROM pool p
                        WHERE p.facility_id = NEW.facility_id
                          AND p.tower_max_m >= 3) INTO v_ok;
    ELSIF v_code IN ('SW', 'WP') THEN
        SELECT EXISTS (SELECT 1 FROM pool p
                        WHERE p.facility_id = NEW.facility_id) INTO v_ok;
    ELSIF v_code = 'BB' THEN
        SELECT EXISTS (SELECT 1 FROM manege m
                        WHERE m.facility_id = NEW.facility_id
                          AND m.has_hoop) INTO v_ok;
    ELSIF v_code = 'VB' THEN
        SELECT EXISTS (SELECT 1 FROM manege m
                        WHERE m.facility_id = NEW.facility_id
                          AND m.has_net) INTO v_ok;
    ELSIF v_code = 'LA' THEN
        SELECT EXISTS (SELECT 1 FROM manege m
                        WHERE m.facility_id = NEW.facility_id) INTO v_ok;
    END IF;

    IF NOT v_ok THEN
        RAISE EXCEPTION 'Вид спорта % нельзя проводить на сооружении %: не хватает оборудования',
            v_code, NEW.facility_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_facility_sport_equipment
    BEFORE INSERT OR UPDATE ON facility_sport
    FOR EACH ROW EXECUTE FUNCTION fn_facility_sport_equipment();

-- 3. Нельзя убрать вид спорта с сооружения, если там уже есть соревнования
CREATE OR REPLACE FUNCTION fn_facility_sport_protect() RETURNS trigger AS $$
BEGIN
    IF EXISTS (
        SELECT 1
          FROM competition c
          JOIN event e ON e.id = c.event_id
         WHERE e.facility_id = OLD.facility_id
           AND c.sport_id    = OLD.sport_id
    ) THEN
        RAISE EXCEPTION 'Нельзя убрать вид спорта %: на сооружении % уже есть соревнования',
            OLD.sport_id, OLD.facility_id;
    END IF;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_facility_sport_protect
    BEFORE DELETE OR UPDATE ON facility_sport
    FOR EACH ROW EXECUTE FUNCTION fn_facility_sport_protect();

-- 4. Соревнование можно проводить только на сооружении, где этот вид разрешён
CREATE OR REPLACE FUNCTION fn_competition_venue() RETURNS trigger AS $$
DECLARE
    v_facility smallint;
BEGIN
    SELECT facility_id INTO v_facility FROM event WHERE id = NEW.event_id;

    IF NOT EXISTS (SELECT 1 FROM facility_sport fs
                    WHERE fs.facility_id = v_facility
                      AND fs.sport_id    = NEW.sport_id) THEN
        RAISE EXCEPTION 'Сооружение % не предназначено для вида спорта %',
            v_facility, NEW.sport_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_competition_venue
    BEFORE INSERT OR UPDATE ON competition
    FOR EACH ROW EXECUTE FUNCTION fn_competition_venue();

-- 5. Спортсмен может выступать только по виду спорта, который тренирует
CREATE OR REPLACE FUNCTION fn_participation_sport() RETURNS trigger AS $$
DECLARE
    v_sport smallint;
BEGIN
    SELECT sport_id INTO v_sport FROM competition WHERE id = NEW.competition_id;

    IF NOT EXISTS (
        SELECT 1
          FROM athlete_coach ac
          JOIN coach ch ON ch.id = ac.coach_id
          JOIN club  cl ON cl.id = ch.club_id
         WHERE ac.athlete_id = NEW.athlete_id
           AND cl.sport_id   = v_sport
    ) THEN
        RAISE EXCEPTION 'Спортсмен % не тренируется по виду спорта %',
            NEW.athlete_id, v_sport;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_participation_sport
    BEFORE INSERT OR UPDATE ON participation
    FOR EACH ROW EXECUTE FUNCTION fn_participation_sport();

-- ---------- Представление «сооружение + атрибуты» ----------

CREATE VIEW v_facility AS
SELECT f.id,
       f.name,
       ft.code AS type_code,
       ft.name AS type_name,
       b.coverage,
       b.area_m2,
       b.ring_size,
       b.bags,
       p.length_m AS pool_length_m,
       p.depth_m,
       p.lanes    AS pool_lanes,
       p.tower_max_m,
       m.lanes    AS manege_lanes,
       m.length_m AS manege_length_m,
       m.has_net,
       m.has_hoop
  FROM sport_facility f
  JOIN facility_type ft ON ft.id = f.type_id
  LEFT JOIN boxing_club b ON b.facility_id = f.id
  LEFT JOIN pool        p ON p.facility_id = f.id
  LEFT JOIN manege      m ON m.facility_id = f.id;

COMMIT;
