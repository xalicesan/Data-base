# -*- coding: utf-8 -*-
"""Генератор 02_data.sql для ИС спортивных организаций (вариант 4.10)."""
import re
from datetime import date, timedelta
from pathlib import Path

SRC = Path(r"D:\Временно")
OUT = Path(r"C:\Users\Xalic\Documents\sports_db\02_data.sql")

SPORTS = [
    (1, "BOX",  "Бокс"),
    (2, "JUDO", "Дзюдо"),
    (3, "WR",   "Борьба"),
    (4, "LA",   "Лёгкая атлетика"),
    (5, "BB",   "Баскетбол"),
    (6, "VB",   "Волейбол"),
    (7, "SW",   "Плавание"),
    (8, "DV",   "Прыжки с вышки"),
    (9, "WP",   "Водное поло"),
]
SPORT_BY_CODE = {c: i for i, c, _ in SPORTS}
SPORT_ID = {name: i for i, _, name in SPORTS}

RANKS = [(1, "3-й разряд", 1), (2, "2-й разряд", 2), (3, "1-й разряд", 3)]

TYPES = [(1, "BK", "Боксёрский клуб"), (2, "B", "Бассейн"), (3, "M", "Манеж")]

CLUBS = [
    (1,  "Сибирь",           "Бокс"),
    (2,  "Зевс",             "Бокс"),
    (3,  "Спарта",           "Бокс"),
    (4,  "Тигр",             "Дзюдо"),
    (5,  "Чемпион",          "Дзюдо"),
    (6,  "Воин",             "Дзюдо"),
    (7,  "Олимп",            "Борьба"),
    (8,  "Медведь",          "Борьба"),
    (9,  "Богатырь",         "Борьба"),
    (10, "Изумруд",          "Лёгкая атлетика"),
    (11, "Сапфир",           "Лёгкая атлетика"),
    (12, "Динамо",           "Баскетбол"),
    (13, "Шахтёр",           "Баскетбол"),
    (14, "Импульс",          "Баскетбол"),
    (15, "Трентино",         "Волейбол"),
    (16, "Зенит",            "Волейбол"),
    (17, "Модена",           "Волейбол"),
    (18, "Брызги скорости",  "Плавание"),
    (19, "Волна энергии",    "Плавание"),
    (20, "Вершина",          "Прыжки с вышки"),
    (21, "Высота",           "Прыжки с вышки"),
    (22, "Морские волки",    "Водное поло"),
    (23, "Водные стражи",    "Водное поло"),
]
CLUB_ID = {name: i for i, name, _ in CLUBS}

# Сокращения, которые встречаются в файле спортсменов
CLUB_ALIASES = {
    "Брызги скор.": "Брызги скорости",
    "Вод. Стражи": "Водные стражи",
    "Волна энерг.": "Волна энергии",
    "Мор. вол.": "Морские волки",
    "Шахтер": "Шахтёр",
}


def club_id(name: str) -> int:
    return CLUB_ID[CLUB_ALIASES.get(name, name)]

# name, type, attributes, allowed sports
FACILITIES = [
    ("БК 1", "BK", dict(coverage="мягкое", area_m2=150, ring_size=None,   bags=10),
     ["Борьба", "Дзюдо"]),
    ("БК 2", "BK", dict(coverage="твердое", area_m2=200, ring_size="4.5x4.5", bags=15),
     ["Бокс"]),
    ("БК 3", "BK", dict(coverage="мягкое", area_m2=300, ring_size="8x8",   bags=20),
     ["Бокс", "Дзюдо", "Борьба"]),
    ("Б 1", "B", dict(length_m=25, depth_m=3.1, lanes=6, tower_max_m=7.5),
     ["Плавание", "Прыжки с вышки", "Водное поло"]),
    ("Б 2", "B", dict(length_m=50, depth_m=4.0, lanes=8, tower_max_m=10.0),
     ["Плавание", "Прыжки с вышки", "Водное поло"]),
    ("Б 3", "B", dict(length_m=25, depth_m=3.1, lanes=8, tower_max_m=None),
     ["Плавание", "Водное поло"]),
    ("М 1", "M", dict(lanes=6, length_m=400, has_net=True, has_hoop=True),
     ["Лёгкая атлетика", "Баскетбол", "Волейбол"]),
    ("М 2", "M", dict(lanes=5, length_m=200, has_net=True, has_hoop=False),
     ["Волейбол", "Лёгкая атлетика"]),
    ("М 3", "M", dict(lanes=5, length_m=200, has_net=False, has_hoop=True),
     ["Баскетбол", "Лёгкая атлетика"]),
]
FACILITY_ID = {name: i + 1 for i, (name, *_rest) in enumerate(FACILITIES)}

ORGANIZERS = [
    (1, "Харитонов Игорь Валентинович"),
    (2, "Мещерякова Ольга Петровна"),
    (3, "Трофимов Сергей Анатольевич"),
]

# 54 придуманных ФИО (в чат не выводятся)
NAMES = {
    1: ("Королёв", "Артём", "Сергеевич"),
    2: ("Гаврилов", "Никита", "Андреевич"),
    3: ("Мельников", "Илья", "Дмитриевич"),
    4: ("Тарасов", "Максим", "Алексеевич"),
    5: ("Беляев", "Роман", "Викторович"),
    6: ("Ковалёв", "Денис", "Олегович"),
    7: ("Фомин", "Егор", "Павлович"),
    8: ("Чернов", "Кирилл", "Игоревич"),
    9: ("Соколов", "Матвей", "Русланович"),
    10: ("Лебедев", "Александр", "Юрьевич"),
    11: ("Никитин", "Данила", "Михайлович"),
    12: ("Орлов", "Владислав", "Денисович"),
    13: ("Егоров", "Пётр", "Николаевич"),
    14: ("Алексеев", "Степан", "Валерьевич"),
    15: ("Богданов", "Григорий", "Тимурович"),
    16: ("Воробьёв", "Андрей", "Фёдорович"),
    17: ("Дмитриев", "Арсений", "Львович"),
    18: ("Крылов", "Виктор", "Семёнович"),
    19: ("Панов", "Олег", "Борисович"),
    20: ("Савельев", "Дмитрий", "Артурович"),
    21: ("Тихонов", "Иван", "Глебович"),
    22: ("Смирнова", "Анна", "Викторовна"),
    23: ("Ушаков", "Николай", "Петрович"),
    24: ("Яковлев", "Сергей", "Вячеславович"),
    25: ("Кузнецова", "Мария", "Сергеевна"),
    26: ("Антонов", "Михаил", "Эдуардович"),
    27: ("Гусев", "Артём", "Вадимович"),
    28: ("Дроздов", "Юрий", "Анатольевич"),
    29: ("Петрова", "Екатерина", "Андреевна"),
    30: ("Жуков", "Анатолий", "Степанович"),
    31: ("Романова", "Ольга", "Игоревна"),
    32: ("Васильева", "Дарья", "Алексеевна"),
    33: ("Зайцев", "Валерий", "Иванович"),
    34: ("Соловьёва", "Полина", "Максимовна"),
    35: ("Ильин", "Константин", "Маркович"),
    36: ("Фёдорова", "Елена", "Павловна"),
    37: ("Козлов", "Ростислав", "Ильич"),
    38: ("Михайлова", "Ксения", "Дмитриевна"),
    39: ("Кузьмин", "Борис", "Аркадьевич"),
    40: ("Николаева", "Виктория", "Олеговна"),
    41: ("Макаров", "Геннадий", "Филиппович"),
    42: ("Павлова", "Софья", "Артёмовна"),
    43: ("Морозов", "Станислав", "Юрьевич"),
    44: ("Сергеева", "Алина", "Романовна"),
    45: ("Новиков", "Валентин", "Романович"),
    46: ("Степанова", "Валерия", "Ильинична"),
    47: ("Покровский", "Лев", "Андреевич"),
    48: ("Титова", "Наталья", "Борисовна"),
    49: ("Рогов", "Вадим", "Александрович"),
    50: ("Устинова", "Ирина", "Валерьевна"),
    51: ("Симонов", "Аркадий", "Борисович"),
    52: ("Царёва", "Людмила", "Фёдоровна"),
    53: ("Хабаров", "Игнат", "Дмитриевич"),
    54: ("Шилова", "Татьяна", "Николаевна"),
}

# соревнование -> (мероприятие, вид спорта, время, участники, призёры по порядку)
COMPETITIONS = [
    (1, 1, "SW",   "10:00", [40, 42],                         [42]),
    (2, 1, "DV",   "12:00", [43, 45],                         [43]),
    (3, 1, "WP",   "14:00", [47, 48, 49, 50, 51, 52],         [47, 48, 49]),
    (4, 2, "LA",   "16:00", [21, 22, 23, 25],                 [21, 25]),
    (5, 2, "BB",   "12:00", list(range(26, 35)),              [26, 27, 28]),
    (6, 2, "VB",   "18:00", [35, 36, 37, 38, 53],             [53, 38]),
    (7, 3, "BOX",  "09:30", list(range(1, 8)),                [1, 3, 5]),
    (8, 3, "JUDO", "10:30", list(range(8, 15)),               [9, 12, 14]),
    (9, 3, "WR",   "11:30", list(range(15, 21)),              [15, 17, 20]),
]

EVENTS = [
    (1, 1, "Б 1",  date(2025, 1, 9),  "Мероприятие 1"),
    (2, 2, "М 1",  date(2025, 2, 20), "Мероприятие 2"),
    (3, 3, "БК 3", date(2025, 4, 7),  "Мероприятие 3"),
]


def q(s):
    return "'" + str(s).replace("'", "''") + "'"


def parse_coaches():
    rows = []
    for line in (SRC / "Тренера.txt").read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if " - " not in line or "(" not in line:
            continue
        parts = [p.strip() for p in line.split(" - ")]
        if len(parts) != 3:
            continue
        sport, club, rest = parts
        m = re.match(r"(.+?)\s*\((\d+)\)\s*$", rest)
        if not m:
            continue
        fio, cid = m.group(1).strip(), int(m.group(2))
        tokens = fio.split()
        last = tokens[0]
        letters = re.findall(r"[А-ЯЁA-Z]", "".join(tokens[1:]))
        first = letters[0] + "." if len(letters) >= 1 else ""
        middle = letters[1] + "." if len(letters) >= 2 else ""
        rows.append((cid, last, first, middle, club, sport))
    return sorted(rows)


def parse_athletes():
    rows = []
    text = (SRC / "Спортсмены.txt").read_text(encoding="utf-8")
    for line in text.splitlines():
        line = line.strip()
        m = re.match(r"Спортсмен (\d+) - (.+?) - (.+?) \| Тренеры?: ([\d,\s]+) \| Разряд: (\d+)$", line)
        if not m:
            continue
        aid = int(m.group(1))
        club = m.group(2).strip()
        coaches = [int(x) for x in re.findall(r"\d+", m.group(4))]
        rank = int(m.group(5))
        rows.append((aid, club, coaches, rank))
    return sorted(rows)


def build():
    out = []
    out.append("-- ============================================================")
    out.append("-- 02_data.sql — тестовые данные (вариант 4.10)")
    out.append("-- Сгенерировано tools/gen_data.py")
    out.append("-- ============================================================")
    out.append("BEGIN;")
    out.append("")

    out.append("-- Виды спорта")
    out.append("INSERT INTO sport (id, code, name) VALUES")
    out.append(",\n".join("  (%d, %s, %s)" % (i, q(c), q(n)) for i, c, n in SPORTS) + ";")
    out.append("")

    out.append("-- Разряды")
    out.append("INSERT INTO rank (id, name, level) VALUES")
    out.append(",\n".join("  (%d, %s, %d)" % (i, q(n), lvl) for i, n, lvl in RANKS) + ";")
    out.append("")

    out.append("-- Типы сооружений")
    out.append("INSERT INTO facility_type (id, code, name) VALUES")
    out.append(",\n".join("  (%d, %s, %s)" % (i, q(c), q(n)) for i, c, n in TYPES) + ";")
    out.append("")

    out.append("-- Клубы")
    out.append("INSERT INTO club (id, name, sport_id) VALUES")
    out.append(",\n".join("  (%d, %s, %d)" % (i, q(n), SPORT_ID[s]) for i, n, s in CLUBS) + ";")
    out.append("")

    out.append("-- Организаторы")
    out.append("INSERT INTO organizer (id, full_name) VALUES")
    out.append(",\n".join("  (%d, %s)" % (i, q(n)) for i, n in ORGANIZERS) + ";")
    out.append("")

    out.append("-- Сооружения (супертип)")
    out.append("INSERT INTO sport_facility (id, name, type_id) VALUES")
    out.append(",\n".join("  (%d, %s, %d)" % (i + 1, q(n), {c: t for t, c, _ in TYPES}[tp])
                          for i, (n, tp, _a, _s) in enumerate(FACILITIES)) + ";")
    out.append("")

    bk = [(i + 1, a) for i, (n, tp, a, _s) in enumerate(FACILITIES) if tp == "BK"]
    out.append("-- Боксёрские клубы")
    out.append("INSERT INTO boxing_club (facility_id, coverage, area_m2, ring_size, bags) VALUES")
    out.append(",\n".join("  (%d, %s, %d, %s, %d)" % (
        fid, q(a["coverage"]), a["area_m2"],
        q(a["ring_size"]) if a["ring_size"] else "NULL", a["bags"]) for fid, a in bk) + ";")
    out.append("")

    pools = [(i + 1, a) for i, (n, tp, a, _s) in enumerate(FACILITIES) if tp == "B"]
    out.append("-- Бассейны")
    out.append("INSERT INTO pool (facility_id, length_m, depth_m, lanes, tower_max_m) VALUES")
    out.append(",\n".join("  (%d, %d, %s, %d, %s)" % (
        fid, a["length_m"], a["depth_m"], a["lanes"],
        a["tower_max_m"] if a["tower_max_m"] is not None else "NULL") for fid, a in pools) + ";")
    out.append("")

    mans = [(i + 1, a) for i, (n, tp, a, _s) in enumerate(FACILITIES) if tp == "M"]
    out.append("-- Манежи")
    out.append("INSERT INTO manege (facility_id, lanes, length_m, has_net, has_hoop) VALUES")
    out.append(",\n".join("  (%d, %d, %d, %s, %s)" % (
        fid, a["lanes"], a["length_m"],
        "true" if a["has_net"] else "false",
        "true" if a["has_hoop"] else "false") for fid, a in mans) + ";")
    out.append("")

    out.append("-- Допустимые виды спорта на сооружениях")
    out.append("INSERT INTO facility_sport (facility_id, sport_id) VALUES")
    fs = []
    for i, (n, tp, _a, sports) in enumerate(FACILITIES):
        for s in sports:
            fs.append("  (%d, %d)" % (i + 1, SPORT_ID[s]))
    out.append(",\n".join(fs) + ";")
    out.append("")

    coaches = parse_coaches()
    missing = [(cid, club) for cid, _l, _f, _m, club, _s in coaches if club not in CLUB_ID]
    assert not missing, missing
    out.append("-- Тренеры")
    out.append("INSERT INTO coach (id, last_name, first_name, middle_name, club_id) VALUES")
    out.append(",\n".join("  (%d, %s, %s, %s, %d)" % (
        cid, q(last), q(first), q(middle), club_id(club))
        for cid, last, first, middle, club, _s in coaches) + ";")
    out.append("")

    athletes = parse_athletes()
    assert len(athletes) == 54, len(athletes)
    out.append("-- Спортсмены (ФИО придуманы для учебного задания)")
    out.append("INSERT INTO athlete (id, last_name, first_name, middle_name, birth_date, rank_id, club_id) VALUES")
    rows = []
    for aid, club, _coaches, rank in athletes:
        last, first, middle = NAMES[aid]
        bd = date(1996, 1, 1) + timedelta(days=(aid * 211) % 2900)
        rows.append("  (%d, %s, %s, %s, DATE %s, %d, %d)" % (
            aid, q(last), q(first), q(middle), q(bd.isoformat()), rank, club_id(club)))
    out.append(",\n".join(rows) + ";")
    out.append("")

    out.append("-- Кто у кого тренируется")
    out.append("INSERT INTO athlete_coach (athlete_id, coach_id) VALUES")
    ac = []
    for aid, _club, cs, _rank in athletes:
        for c in cs:
            ac.append("  (%d, %d)" % (aid, c))
    out.append(",\n".join(ac) + ";")
    out.append("")

    out.append("-- Мероприятия")
    out.append("INSERT INTO event (id, organizer_id, facility_id, event_date, title) VALUES")
    out.append(",\n".join("  (%d, %d, %d, DATE %s, %s)" % (
        eid, org, FACILITY_ID[fac], q(d.isoformat()), q(title))
        for eid, org, fac, d, title in EVENTS) + ";")
    out.append("")

    out.append("-- Соревнования")
    out.append("INSERT INTO competition (id, event_id, sport_id, start_time) VALUES")
    out.append(",\n".join("  (%d, %d, %d, TIME %s)" % (
        cid, ev, SPORT_BY_CODE[sc], q(t)) for cid, ev, sc, t, _p, _w in COMPETITIONS) + ";")
    out.append("")

    out.append("-- Участие и призовые места (места — по порядку перечисления)")
    parts = []
    for cid, _ev, _sc, _t, participants, winners in COMPETITIONS:
        place = {a: i + 1 for i, a in enumerate(winners)}
        for a in participants:
            parts.append("  (%d, %d, %s)" % (cid, a, place.get(a, "NULL")))
    out.append("INSERT INTO participation (competition_id, athlete_id, place) VALUES")
    out.append(",\n".join(parts) + ";")
    out.append("")

    out.append("COMMIT;")
    return "\n".join(out) + "\n"


if __name__ == "__main__":
    text = build()
    OUT.write_text(text, encoding="utf-8")
    print("written:", OUT, len(text), "chars")
