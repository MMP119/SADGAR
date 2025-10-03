import os
import psycopg2

# ====== CONFIGURA AQUÍ ======
DB_CONFIG = {
    "host": "db",
    "port": 5432,
    "user": "root",
    "password": "Bases2_G10",
    "dbname": "IMDb",
}

# ▼▼▼ RUTAS CORREGIDAS PARA EL CONTENEDOR ▼▼▼
FILES = {
    "/data/title.basics.tsv":     ("temp_title_basics",     "\t"),
    "/data/name.basics.tsv":      ("temp_name_basics",      "\t"),
    "/data/title.ratings.tsv":    ("temp_title_ratings",    "\t"),
    "/data/title.crew.tsv":       ("temp_title_crew",       "\t"),
    "/data/title.principals.tsv": ("temp_title_principals", "\t"),
    "/data/title.episode.tsv":    ("temp_title_episode",    "\t"),
    "/data/title.akas.tsv":       ("temp_title_akas",       "\t"),
}


# Reemplaza el diccionario COLUMNS con este
COLUMNS = {
    "temp_title_basics":     ["tconst","titletype","primarytitle","originaltitle","isadult","startyear","endyear","runtimeminutes","genres"],
    "temp_name_basics":      ["nconst","primaryname","birthyear","deathyear","primaryprofession","knownfortitles"],
    "temp_title_ratings":    ["tconst","averagerating","numvotes"],
    "temp_title_crew":       ["tconst","directors","writers"],
    "temp_title_principals": ["tconst","ordering","nconst","category","job","characters"],
    "temp_title_episode":    ["tconst","parenttconst","seasonnumber","episodenumber"],
    "temp_title_akas":       ["titleid","ordering","title","region","language","types","attributes","isoriginaltitle"],
}

# ============================

def main():
    # Conectarse a PostgreSQL usando psycopg2
    conn = psycopg2.connect(**DB_CONFIG)
    try:
        # Por defecto, psycopg2 abre una transacción. Hacemos commit al final.
        with conn.cursor() as cur:
            for path, (table, sep) in FILES.items():
                if not os.path.exists(path):
                    print(f"[OMITIDO] No existe: {path}")
                    continue

                cols = COLUMNS[table]

                print(f"\n=== Cargando {os.path.basename(path)} -> {table} ===")
                print("Ejecutando COPY FROM STDIN ...")

                # Abrimos el archivo para leerlo en modo texto
                with open(path, 'r', encoding='utf-8') as f:
                    # Leemos y descartamos la primera línea (la cabecera)
                    next(f)

                    # Usamos el método copy_from, la forma más rápida de cargar datos en psycopg2
                    # Le pasamos el objeto del archivo, la tabla, las columnas y el separador.
                    # Es crucial indicarle que los valores nulos en el archivo son '\\N'.
                    cur.copy_from(
                        file=f,
                        table=table,
                        sep=sep,
                        null='\\N',  # IMDB usa '\N' para representar NULL
                        columns=cols
                    )

                # copy_from no devuelve el número de filas, pero si no hay error, funcionó.
                print("OK.")

        # Hacemos commit de todas las operaciones de carga
        print("\nConfirmando todos los cambios (commit)...")
        conn.commit()
        print("Carga masiva completada.")

    except Exception as e:
        # Si algo falla, hacemos rollback para deshacer los cambios
        print(f"\nERROR: Ocurrió un problema. Deshaciendo cambios (rollback)...")
        print(f"Detalle del error: {e}")
        conn.rollback()
    finally:
        # Cerramos la conexión
        conn.close()

if __name__ == "__main__":
    main()