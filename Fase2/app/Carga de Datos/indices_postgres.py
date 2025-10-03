import psycopg2
import time

DB_CONFIG = {
    "host": "db",
    "port": 5432,
    "user": "root",
    "password": "Bases2_G10",
    "database": "IMDb"
}

def crear_indices(cur):
    """Crear todos los índices de optimización"""
    
    indices = [
        # TÍTULOS
        ("idx_titles_type", "CREATE INDEX idx_titles_type ON titles(title_type);"),
        ("idx_titles_year", "CREATE INDEX idx_titles_year ON titles(start_year);"),
        ("idx_titles_type_year", "CREATE INDEX idx_titles_type_year ON titles(title_type, start_year);"),
        ("idx_titles_runtime", "CREATE INDEX idx_titles_runtime ON titles(runtime_minutes);"),
        ("idx_titles_name", "CREATE INDEX idx_titles_name ON titles(primary_title);"),
        ("idx_titles_name_trgm", "CREATE INDEX idx_titles_name_trgm ON titles USING gin(primary_title gin_trgm_ops);"),
        
        # RATINGS
        ("idx_ratings_votes", "CREATE INDEX idx_ratings_votes ON ratings(num_votes DESC);"),
        ("idx_ratings_rating", "CREATE INDEX idx_ratings_rating ON ratings(average_rating DESC);"),
        ("idx_ratings_rating_votes", "CREATE INDEX idx_ratings_rating_votes ON ratings(average_rating DESC, num_votes DESC);"),
        
        # PEOPLE
        ("idx_people_name", "CREATE INDEX idx_people_name ON people(primary_name);"),
        ("idx_people_name_trgm", "CREATE INDEX idx_people_name_trgm ON people USING gin(primary_name gin_trgm_ops);"),
        ("idx_people_birth", "CREATE INDEX idx_people_birth ON people(birth_year);"),
        ("idx_people_death", "CREATE INDEX idx_people_death ON people(death_year);"),
        
        # TITLE_PRINCIPALS
        ("idx_principals_tconst", "CREATE INDEX idx_principals_tconst ON title_principals(tconst);"),
        ("idx_principals_nconst", "CREATE INDEX idx_principals_nconst ON title_principals(nconst);"),
        ("idx_principals_category", "CREATE INDEX idx_principals_category ON title_principals(category_id);"),
        ("idx_principals_ordering", "CREATE INDEX idx_principals_ordering ON title_principals(ordering);"),
        
        # TITLE_CREW
        ("idx_crew_tconst", "CREATE INDEX idx_crew_tconst ON title_crew(tconst);"),
        ("idx_crew_nconst", "CREATE INDEX idx_crew_nconst ON title_crew(nconst);"),
        ("idx_crew_type", "CREATE INDEX idx_crew_type ON title_crew(crew_type);"),
        
        # TITLE_GENRES
        ("idx_genres_tconst", "CREATE INDEX idx_genres_tconst ON title_genres(tconst);"),
        ("idx_genres_genre", "CREATE INDEX idx_genres_genre ON title_genres(genre_id);"),
        
        # EPISODES
        ("idx_episodes_parent", "CREATE INDEX idx_episodes_parent ON episodes(parent_tconst);"),
        ("idx_episodes_season", "CREATE INDEX idx_episodes_season ON episodes(season_number);"),
        ("idx_episodes_parent_season", "CREATE INDEX idx_episodes_parent_season ON episodes(parent_tconst, season_number);"),
        
        # GENRES y CATEGORIES
        ("idx_genres_name", "CREATE INDEX idx_genres_name ON genres(genre_name);"),
        ("idx_categories_name", "CREATE INDEX idx_categories_name ON categories(category_name);"),
    ]
    
    return indices

def main():
    print("\n" + "=" * 60)
    print("CREACIÓN DE ÍNDICES - POSTGRESQL")
    print("=" * 60 + "\n")
    
    conn = psycopg2.connect(**DB_CONFIG)
    conn.autocommit = True
    cur = conn.cursor()
    
    try:
        # Habilitar extensión para búsquedas de texto
        print("Habilitando extensión pg_trgm para búsquedas...")
        cur.execute("CREATE EXTENSION IF NOT EXISTS pg_trgm;")
        print("✓ Extensión habilitada\n")
        
        indices = crear_indices(cur)
        exitosos = 0
        fallidos = 0
        
        print("Creando índices:")
        print("-" * 40)
        
        for nombre, sql in indices:
            try:
                inicio = time.time()
                cur.execute(sql)
                tiempo = time.time() - inicio
                print(f"  ✓ {nombre} ({tiempo:.2f}s)")
                exitosos += 1
            except psycopg2.errors.DuplicateTable:
                print(f"  ⚠ {nombre} ya existe")
                exitosos += 1
            except Exception as e:
                print(f"  ✗ {nombre}: {str(e)[:50]}")
                fallidos += 1
        
        # Actualizar estadísticas
        print("\nActualizando estadísticas...")
        cur.execute("ANALYZE;")
        print("✓ Estadísticas actualizadas")
        
        # Mostrar resumen
        print("\n" + "=" * 60)
        print("RESUMEN")
        print("=" * 60)
        print(f"✓ Índices exitosos: {exitosos}")
        print(f"✗ Índices fallidos: {fallidos}")
        
        # Mostrar tamaños
        cur.execute("""
            SELECT 
                schemaname,
                tablename,
                pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
            FROM pg_tables
            WHERE schemaname = 'public'
            AND tablename IN ('titles', 'people', 'ratings', 'episodes', 
                             'title_principals', 'title_crew', 'title_genres')
            ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
        """)
        
        print("\nTamaño de tablas (con índices):")
        print("-" * 40)
        for row in cur.fetchall():
            print(f"  {row[1]:20} : {row[2]:>10}")
        
        print("\n✓ PROCESO COMPLETADO")
        print("\nPara hacer backup ejecuta:")
        print("pg_dump -U postgres -d imdb_data -f backup_imdb.sql")
        
    except Exception as e:
        print(f"\n ERROR: {e}")
    finally:
        cur.close()
        conn.close()

if __name__ == "__main__":
    main()
