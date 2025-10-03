import os
import sys
import psycopg2

# ====== CONFIGURA AQUÍ ======
DB_CONFIG = {
    "host": "db",
    "port": 5432,
    "user": "root",
    "password": "Bases2_G10",
    "dbname": "IMDb",
}

BATCH = 900_000   # Ajusta según la memoria y CPU de tu equipo
# ==================================

def connect():
    """Establece la conexión con PostgreSQL."""
    conn = psycopg2.connect(**DB_CONFIG)
    with conn.cursor() as cur:
        # En PostgreSQL, la configuración de memoria se hace por sesión o en postgresql.conf
        # 'work_mem' es crucial para ordenamientos y joins grandes.
        cur.execute("SET work_mem = '512MB';")
        cur.execute("SET maintenance_work_mem = '1GB';") # Útil para CREATE INDEX
    return conn

def safe_exec(cur, sql, params=None, label=""):
    """Ejecuta una consulta y muestra las filas afectadas."""
    cur.execute(sql, params or ())
    print(f"{label} -> OK, filas afectadas={cur.rowcount}")

def create_indexes(cur):
    """Crea índices en las tablas temporales para acelerar el ETL."""
    print("\n== Creando índices en tablas temporales (si no existen) ==")
    idx_cmds = [
        ("temp_title_basics",     "idx_tconst",   "CREATE INDEX IF NOT EXISTS idx_tconst ON temp_title_basics(tconst)"),
        ("temp_name_basics",      "idx_nconst",   "CREATE INDEX IF NOT EXISTS idx_nconst ON temp_name_basics(nconst)"),
        ("temp_title_ratings",    "idx_tconst",   "CREATE INDEX IF NOT EXISTS idx_tconst ON temp_title_ratings(tconst)"),
        ("temp_title_principals", "idx_tconst",   "CREATE INDEX IF NOT EXISTS idx_tconst ON temp_title_principals(tconst)"),
        ("temp_title_principals", "idx_nconst",   "CREATE INDEX IF NOT EXISTS idx_nconst ON temp_title_principals(nconst)"),
        ("temp_title_principals", "idx_category", "CREATE INDEX IF NOT EXISTS idx_category ON temp_title_principals(category)"),
        ("temp_title_episode",    "idx_tconst",   "CREATE INDEX IF NOT EXISTS idx_tconst ON temp_title_episode(tconst)"),
        ("temp_title_episode",    "idx_parent",   "CREATE INDEX IF NOT EXISTS idx_parent ON temp_title_episode(parentTconst)"),
        ("temp_title_crew",       "idx_tconst",   "CREATE INDEX IF NOT EXISTS idx_tconst ON temp_title_crew(tconst)"),
    ]
    for table, idx, cmd in idx_cmds:
        safe_exec(cur, cmd, label=f"INDEX {table}.{idx}")

def next_upper_key(cur, table, keycol, last_key, limit):
    """Obtiene el límite superior para el siguiente lote."""
    sql = f"SELECT {keycol} FROM {table} WHERE {keycol} > %s ORDER BY {keycol} LIMIT %s"
    cur.execute(sql, (last_key, limit))
    rows = cur.fetchall()
    if not rows:
        return None
    return rows[-1][0]

# ================== POBLACIÓN DE DATOS (VERSIÓN POSTGRESQL) ==================

def populate_titles(cur):
    print("\n>> TITLES (UPSERT)")
    last = ''
    while True:
        upper = next_upper_key(cur, "temp_title_basics", "tconst", last, BATCH)
        if not upper: break
        sql = """
INSERT INTO titles (tconst, title_type, primary_title, original_title, is_adult, start_year, end_year, runtime_minutes)
SELECT
    m.tconst, m.title_type::title_type_enum, m.primaryTitle, m.originalTitle, m.is_adult,
    CASE WHEN m.startYear ~ '^[0-9]{4}$' THEN m.startYear::SMALLINT ELSE NULL END,
    CASE WHEN m.endYear ~ '^[0-9]{4}$' THEN m.endYear::SMALLINT ELSE NULL END,
    CASE WHEN m.runtimeMinutes ~ '^[0-9]+$' THEN m.runtimeMinutes::INTEGER ELSE NULL END
FROM (
    SELECT
        tb.tconst,
        LOWER(tb.titleType) AS title_type,
        tb.primaryTitle, tb.originalTitle,
        (tb.isAdult = '1') AS is_adult,
        tb.startYear, tb.endYear, tb.runtimeMinutes
    FROM temp_title_basics tb
    WHERE tb.tconst > %s AND tb.tconst <= %s
) AS m
WHERE m.title_type IN ('movie', 'short', 'tvseries', 'tvepisode', 'video', 'tvMovie', 'tvShort', 'tvMiniSeries', 'tvSpecial')
ON CONFLICT (tconst) DO UPDATE SET
    title_type      = EXCLUDED.title_type,
    primary_title   = EXCLUDED.primary_title,
    original_title  = EXCLUDED.original_title,
    is_adult        = EXCLUDED.is_adult,
    start_year      = EXCLUDED.start_year,
    end_year        = EXCLUDED.end_year,
    runtime_minutes = EXCLUDED.runtime_minutes;
"""
        safe_exec(cur, sql, (last, upper), f"titles [{last}..{upper}]")
        last = upper

def populate_people(cur):
    print("\n>> PEOPLE (UPSERT)")
    last = ''
    while True:
        upper = next_upper_key(cur, "temp_name_basics", "nconst", last, BATCH)
        if not upper: break
        sql = """
INSERT INTO people (nconst, primary_name, birth_year, death_year)
SELECT
    m.nconst, m.primary_name, m.birth_year, m.death_year
FROM (
    SELECT
        nb.nconst,
        NULLIF(TRIM(nb.primaryName), '') AS primary_name,
        CASE WHEN nb.birthYear ~ '^[0-9]{4}$' THEN nb.birthYear::SMALLINT ELSE NULL END AS birth_year,
        CASE WHEN nb.deathYear ~ '^[0-9]{4}$' THEN nb.deathYear::SMALLINT ELSE NULL END AS death_year
    FROM temp_name_basics nb
    WHERE nb.nconst > %s AND nb.nconst <= %s
) AS m
WHERE m.primary_name IS NOT NULL
ON CONFLICT (nconst) DO UPDATE SET
    primary_name = EXCLUDED.primary_name,
    birth_year   = EXCLUDED.birth_year,
    death_year   = EXCLUDED.death_year;
"""
        safe_exec(cur, sql, (last, upper), f"people [{last}..{upper}]")
        last = upper

def populate_ratings(cur):
    print("\n>> RATINGS (UPSERT)")
    last = ''
    while True:
        upper = next_upper_key(cur, "temp_title_ratings", "tconst", last, BATCH)
        if not upper: break
        sql = """
INSERT INTO ratings (tconst, average_rating, num_votes)
SELECT r.tconst, r.averageRating::DECIMAL(3,1), r.numVotes::BIGINT
FROM temp_title_ratings r
JOIN titles t ON t.tconst = r.tconst
WHERE r.tconst > %s AND r.tconst <= %s
ON CONFLICT (tconst) DO UPDATE SET
    average_rating = EXCLUDED.average_rating,
    num_votes      = EXCLUDED.num_votes;
"""
        safe_exec(cur, sql, (last, upper), f"ratings [{last}..{upper}]")
        last = upper

def populate_genres(cur):
    print("\n>> GENRES (dim)")
    sql_dim = """
INSERT INTO genres (genre_name)
SELECT DISTINCT jt.genre
FROM temp_title_basics tb,
     unnest(string_to_array(tb.genres, ',')) AS jt(genre)
WHERE tb.genres IS NOT NULL AND tb.genres <> '\\N'
ON CONFLICT (genre_name) DO NOTHING;
"""
    safe_exec(cur, sql_dim, label="genres dim")

def populate_title_genres(cur):
    print("\n>> TITLE_GENRES (bridge)")
    last = ''
    while True:
        upper = next_upper_key(cur, "temp_title_basics", "tconst", last, BATCH)
        if not upper: break
        sql = """
INSERT INTO title_genres (tconst, genre_id, genre_order)
SELECT
    tb.tconst, g.genre_id, jt.ord
FROM (
    SELECT tconst, genres FROM temp_title_basics WHERE tconst > %s AND tconst <= %s
) tb
CROSS JOIN unnest(string_to_array(tb.genres, ',')) WITH ORDINALITY AS jt(genre, ord)
JOIN genres g ON g.genre_name = jt.genre
JOIN titles t ON t.tconst = tb.tconst
ON CONFLICT DO NOTHING; -- Manera simple de evitar duplicados
"""
        safe_exec(cur, sql, (last, upper), f"title_genres [{last}..{upper}]")
        last = upper

def populate_categories_and_principals(cur):
    print("\n>> CATEGORIES (dim)")
    sql_dim = """
INSERT INTO categories (category_name)
SELECT DISTINCT category FROM temp_title_principals
WHERE category IS NOT NULL AND category <> '\\N'
ON CONFLICT (category_name) DO NOTHING;
"""
    safe_exec(cur, sql_dim, label="categories dim")
    
    print("\n>> TITLE_PRINCIPALS (bridge)")
    last = ''
    while True:
        upper = next_upper_key(cur, "temp_title_principals", "tconst", last, BATCH)
        if not upper: break
        sql = """
INSERT INTO title_principals (tconst, ordering, nconst, category_id, job, characters)
SELECT
    p.tconst, p.ordering::SMALLINT, p.nconst, c.category_id,
    NULLIF(p.job, '\\N'), NULLIF(p.characters, '\\N')
FROM temp_title_principals p
JOIN categories c ON c.category_name = p.category
JOIN titles t     ON t.tconst = p.tconst
JOIN people pe    ON pe.nconst = p.nconst
WHERE p.tconst > %s AND p.tconst <= %s
ON CONFLICT DO NOTHING;
"""
        safe_exec(cur, sql, (last, upper), f"title_principals [{last}..{upper}]")
        last = upper

def populate_title_crew(cur):
    print("\n>> TITLE_CREW (directors)")
    last = ''
    while True:
        upper = next_upper_key(cur, "temp_title_crew", "tconst", last, BATCH)
        if not upper: break
        sql = """
INSERT INTO title_crew (tconst, nconst, crew_type)
SELECT
    tc.tconst, jt.nconst, 'director'::crew_type_enum
FROM (
    SELECT tconst, directors FROM temp_title_crew WHERE tconst > %s AND tconst <= %s
) tc
CROSS JOIN unnest(string_to_array(tc.directors, ',')) AS jt(nconst)
JOIN titles t ON t.tconst = tc.tconst
JOIN people p ON p.nconst = jt.nconst
WHERE tc.directors IS NOT NULL AND tc.directors <> '\\N'
ON CONFLICT DO NOTHING;
"""
        safe_exec(cur, sql, (last, upper), f"title_crew directors [{last}..{upper}]")
        last = upper
    
    print("\n>> TITLE_CREW (writers)")
    last = ''
    while True:
        upper = next_upper_key(cur, "temp_title_crew", "tconst", last, BATCH)
        if not upper: break
        sql = """
INSERT INTO title_crew (tconst, nconst, crew_type)
SELECT
    tc.tconst, jt.nconst, 'writer'::crew_type_enum
FROM (
    SELECT tconst, writers FROM temp_title_crew WHERE tconst > %s AND tconst <= %s
) tc
CROSS JOIN unnest(string_to_array(tc.writers, ',')) AS jt(nconst)
JOIN titles t ON t.tconst = tc.tconst
JOIN people p ON p.nconst = jt.nconst
WHERE tc.writers IS NOT NULL AND tc.writers <> '\\N'
ON CONFLICT DO NOTHING;
"""
        safe_exec(cur, sql, (last, upper), f"title_crew writers [{last}..{upper}]")
        last = upper

def populate_episodes(cur):
    print("\n>> EPISODES")
    last = ''
    while True:
        upper = next_upper_key(cur, "temp_title_episode", "tconst", last, BATCH)
        if not upper: break
        sql = """
INSERT INTO episodes (episode_tconst, parent_tconst, season_number, episode_number)
SELECT
    e.tconst, e.parentTconst,
    CASE WHEN e.seasonNumber ~ '^[0-9]+$' THEN e.seasonNumber::SMALLINT ELSE NULL END,
    CASE WHEN e.episodeNumber ~ '^[0-9]+$' THEN e.episodeNumber::INTEGER ELSE NULL END
FROM temp_title_episode e
JOIN titles c ON c.tconst = e.tconst
JOIN titles p ON p.tconst = e.parentTconst
WHERE e.tconst > %s AND e.tconst <= %s
ON CONFLICT (episode_tconst) DO NOTHING;
"""
        safe_exec(cur, sql, (last, upper), f"episodes [{last}..{upper}]")
        last = upper

# ================== MAIN ==================
def main():
    conn = connect()
    try:
        with conn.cursor() as cur:
            print("\n>> Deshabilitando temporalmente llaves foráneas y triggers para acelerar... ")
            cur.execute("SET session_replication_role = 'replica';")

            create_indexes(cur)

            # Ejecutar ETL por tabla
            populate_titles(cur)
            populate_people(cur)
            populate_ratings(cur)
            populate_genres(cur)
            populate_title_genres(cur)
            populate_categories_and_principals(cur)
            populate_title_crew(cur)
            populate_episodes(cur)

            print("\n>> Reactivando llaves foráneas y triggers...")
            cur.execute("SET session_replication_role = 'origin';")


            print("\n✔ Población terminada. Confirmando cambios (commit)...")
            conn.commit()
            print("Cambios confirmados.")
 
    except Exception as e:
        print(f"\nERROR: Ocurrió un problema. Deshaciendo cambios (rollback)...")
        print(f"Detalle del error: {e}")
        conn.rollback()
    finally:
        conn.close()

if __name__ == "__main__":
    main()