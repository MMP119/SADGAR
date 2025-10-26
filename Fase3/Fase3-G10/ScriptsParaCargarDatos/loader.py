import os
import pandas as pd
from pymongo import MongoClient, UpdateOne
from tqdm import tqdm
import math
from multiprocessing import Pool, cpu_count

# --- CONFIGURACIÓN ---
# Lee las variables de entorno definidas en docker-compose.yml
MONGO_HOST = os.getenv('MONGO_HOST', 'localhost')
MONGO_PORT = int(os.getenv('MONGO_PORT', 27017))
MONGO_DB = os.getenv('MONGO_DB', 'imdb_nosql')
MONGO_USER = os.getenv('MONGO_USER')
MONGO_PASSWORD = os.getenv('MONGO_PASSWORD')

# Rutas y tamaños de procesamiento
DATA_PATH = '/data/'
CHUNK_SIZE = 75000  # Filas a procesar por cada trozo de archivo
BULK_SIZE = 30000   

# Construir la URI de conexión para MongoDB
MONGO_URI = f"mongodb://{MONGO_USER}:{MONGO_PASSWORD}@{MONGO_HOST}:{MONGO_PORT}/"

# --- FUNCIONES DE PROCESAMIENTO ---

def process_chunk(df, collection_name, id_column):
    """Prepara y realiza una escritura masiva (bulk write) en MongoDB."""

    # Se crea una nueva conexión dentro de cada proceso para evitar conflictos con multiprocessing
    client = MongoClient(MONGO_URI)
    db = client[MONGO_DB]
    collection = db[collection_name]

    # Renombrar la columna de ID a _id 
    df = df.rename(columns={id_column: '_id'})

    # Limpiar datos: eliminar filas donde el ID es nulo para evitar errores de clave duplicada
    df.dropna(subset=['_id'], inplace=True)
    if df.empty:
        client.close()
        return

    # Convertir el DataFrame a una lista de diccionarios (mucho más rápido que iterar)
    docs = df.to_dict('records')
    operations = []
    for doc in docs:
        # Limpiar valores nulos que pandas pueda haber introducido
        doc_cleaned = {k: v for k, v in doc.items() if pd.notna(v)}
        operations.append(
            # upsert=True crea el documento si no existe, o lo actualiza si ya existe
            UpdateOne({'_id': doc_cleaned['_id']}, {'$set': doc_cleaned}, upsert=True)
        )
    
    if operations:
        # ordered=False permite a MongoDB procesar el lote en paralelo, acelerando la escritura
        collection.bulk_write(operations, ordered=False)
    
    client.close()

def worker_process_file(filename, collection_name, id_column):
    """Función que lee y procesa un archivo TSV. Será ejecutada por cada proceso del pool."""
    filepath = os.path.join(DATA_PATH, filename)
    print(f"Iniciando procesamiento para: {filename}")
    try:
        # Leer el archivo CSV en trozos (chunks) para no consumir toda la RAM
        reader = pd.read_csv(filepath, sep='\t', chunksize=CHUNK_SIZE, low_memory=False, na_values=['\\N'], quoting=3, encoding='latin-1')
        for chunk in reader:
            process_chunk(chunk, collection_name, id_column)
    except Exception as e:
        print(f"Error procesando el archivo {filename}: {e}")
    
    print(f"Finalizado procesamiento para: {filename}")
    return f"Completado: {filename}"

def merge_data(db):
    """Combina datos de las colecciones temporales en la colección principal 'titles'."""
    print("\nCombinando datos en la colección 'titles'...")
    titles_collection = db['titles']
    
    merges = [
        ('temp_ratings', 'Ratings', lambda doc: {'rating': {'average': float(doc['averageRating']) if 'averageRating' in doc else None, 'votes': int(doc['numVotes']) if 'numVotes' in doc else None}}),
        ('temp_crew', 'Crew', lambda doc: {'crew': {'directors': doc.get('directors', '').split(',') if doc.get('directors') else [], 'writers': doc.get('writers', '').split(',') if doc.get('writers') else []}}),
        ('temp_episodes', 'Episodios', lambda doc: {'parent_tconst': doc['parentTconst'], 'season_number': doc.get('seasonNumber'), 'episode_number': doc.get('episodeNumber')})
    ]

    for temp_name, desc, transform in merges:
        temp_collection = db[temp_name]
        cursor = temp_collection.find({}, no_cursor_timeout=True)
        operations = []
        for doc in tqdm(cursor, total=temp_collection.count_documents({}), desc=f"Fusionando {desc}"):
            update_data = transform(doc)
            operations.append(UpdateOne({'_id': doc['_id']}, {'$set': update_data}))
            if len(operations) >= BULK_SIZE:
                titles_collection.bulk_write(operations, ordered=False)
                operations = []
        if operations:
            titles_collection.bulk_write(operations, ordered=False)
        cursor.close()

    print("\nFusionando datos de Principals (esto puede tardar)...")
    principals_collection = db['temp_principals']
    cursor = principals_collection.find({}, no_cursor_timeout=True)
    operations = []
    for doc in tqdm(cursor, total=principals_collection.count_documents({}), desc="Fusionando Principals"):
        principal_obj = {
            'nconst': doc['nconst'], 'category': doc.get('category'), 'job': doc.get('job'),
            'characters': doc.get('characters', '').strip('[]').replace('"', '').split(',') if doc.get('characters') else []
        }
        operations.append(UpdateOne({'_id': doc['_id']}, {'$push': {'principals': principal_obj}}))
        if len(operations) >= BULK_SIZE:
            titles_collection.bulk_write(operations, ordered=False)
            operations = []
    if operations:
        titles_collection.bulk_write(operations, ordered=False)
    cursor.close()
    print("\n¡Combinación de datos completada!")

def main():
    """Función principal que orquesta todo el proceso ETL."""
    client = MongoClient(MONGO_URI)
    db = client[MONGO_DB]
    
    temp_collections = {"temp_ratings": "tconst", "temp_crew": "tconst", "temp_principals": "tconst", "temp_episodes": "tconst"}
    
    print("Limpiando colecciones existentes para un inicio limpio...")
    for col in list(temp_collections.keys()) + ['titles', 'people', 'akas']:
        db[col].drop()

    # Definir las 7 tareas de carga de archivos
    tasks = [
        ('name.basics.tsv', 'people', 'nconst'), ('title.akas.tsv', 'akas', 'titleId'),
        ('title.basics.tsv', 'titles', 'tconst'), ('title.ratings.tsv', 'temp_ratings', 'tconst'),
        ('title.crew.tsv', 'temp_crew', 'tconst'), ('title.principals.tsv', 'temp_principals', 'tconst'),
        ('title.episode.tsv', 'temp_episodes', 'tconst')
    ]
    
    # Ejecutar la carga de archivos en paralelo usando todos los núcleos de CPU disponibles
    num_processes = cpu_count()
    print(f"\nIniciando carga de datos en paralelo con {num_processes} procesos...")
    with Pool(processes=num_processes) as pool:
        results = list(tqdm(pool.starmap(worker_process_file, tasks), total=len(tasks)))
    
    for r in results: print(r)
    print("\n--- Carga inicial de archivos completada ---")

    # Ejecutar la fusión de datos de forma secuencial
    merge_data(db)

    print("\nLimpiando colecciones temporales...")
    for col_name in temp_collections.keys():
        db.drop_collection(col_name)

    # --- SECCIÓN FINAL DE CREACIÓN DE ÍNDICES ---
    print("\n--- Creando Índices Finales y Optimizados ---")
    
    print("Borrando índices antiguos para asegurar un estado limpio...")
    db.titles.drop_indexes()
    db.people.drop_indexes()
    db.akas.drop_indexes()

    print("Creando índice compuesto para Top 10 Ratings en 'titles'...")
    db.titles.create_index({ "titleType": 1, "rating.average": -1, "rating.votes": -1 })
    
    print("Creando índice de TEXTO para búsquedas por nombre en 'titles'...")
    db.titles.create_index({ "primaryTitle": "text" })

    print("Creando índice para la categoría de 'principals' en 'titles'...")
    db.titles.create_index({ "principals.category": 1 })

    print("Creando índices para Crew y Principals en 'titles'...")
    db.titles.create_index({ "crew.directors": 1 })
    db.titles.create_index({ "principals.nconst": 1 })

    print("Creando índice para búsquedas de personas por nombre en 'people'...")
    db.people.create_index({ "primaryName": 1 })

    print("Creando índice para búsquedas de títulos alternativos en 'akas'...")
    db.akas.create_index({ "title": 1 })

    print("\n--- Proceso ETL finalizado con éxito ---")
    client.close()

if __name__ == "__main__":
    main()
