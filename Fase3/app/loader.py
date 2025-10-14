"""
================================================================================
LOADER NORMALIZADO - Múltiples Colecciones Especializadas
================================================================================
"""

import csv
import logging
from pymongo import MongoClient, ASCENDING, DESCENDING, TEXT
from tqdm import tqdm
import time
from config import (
    MONGO_URI, 
    BATCH_SIZE, 
    TSV_FILES,
    TITLE_TYPES,
    PERSON_CATEGORIES
)

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class IMDbNormalizedLoader:
    """
    Loader que crea múltiples colecciones especializadas
    """
    
    def __init__(self):
        self.client = MongoClient(MONGO_URI, serverSelectionTimeoutMS=5000)
        self.db = self.client['IMDb_NoSQL']
        self.start_time = time.time()
    
    def read_tsv(self, filepath):
        """Leer archivo TSV"""
        logger.info(f"📖 Leyendo: {filepath}")
        with open(filepath, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f, delimiter='\t')
            for row in reader:
                # Convertir \N a None
                yield {k: (None if v == '\\N' else v) for k, v in row.items()}
    
    # ========================================================================
    # PASO 1: CARGAR PEOPLE
    # ========================================================================
    
    def load_people(self):
        """Cargar personas a la colección people"""
        logger.info("\n" + "="*80)
        logger.info("👥 PASO 1: Cargando PEOPLE")
        logger.info("="*80)
        
        self.db['people'].drop()
        
        batch = []
        count = 0
        
        for row in tqdm(self.read_tsv(TSV_FILES['people']), desc="People"):
            # Convertir profesiones
            professions = row.get('primaryProfession', '').split(',') if row.get('primaryProfession') else []
            
            doc = {
                '_id': row['nconst'],
                'nombre': row.get('primaryName'),
                'año_nacimiento': int(row['birthYear']) if row.get('birthYear') and row['birthYear'].isdigit() else None,
                'año_muerte': int(row['deathYear']) if row.get('deathYear') and row['deathYear'].isdigit() else None,
                'profesiones': professions,
            }
            
            batch.append(doc)
            count += 1
            
            if len(batch) >= BATCH_SIZE:
                self.db['people'].insert_many(batch, ordered=False)
                batch = []
        
        if batch:
            self.db['people'].insert_many(batch, ordered=False)
        
        logger.info(f"✅ {count:,} personas cargadas")
    
    # ========================================================================
    # PASO 2: CARGAR TITLES (separado por tipo)
    # ========================================================================
    
    def load_titles(self):
        """Cargar títulos separados por tipo (movies, series, etc.)"""
        logger.info("\n" + "="*80)
        logger.info("🎬 PASO 2: Cargando TÍTULOS (por tipo)")
        logger.info("="*80)
        
        # Drop collections
        self.db['movies'].drop()
        self.db['series'].drop()
        self.db['documentaries'].drop()
        self.db['shorts'].drop()
        self.db['episodes'].drop()
        self.db['others'].drop()
        
        batches = {
            'movies': [],
            'series': [],
            'documentaries': [],
            'shorts': [],
            'episodes': [],
            'others': []
        }
        
        counts = {k: 0 for k in batches.keys()}
        
        for row in tqdm(self.read_tsv(TSV_FILES['titles']), desc="Titles"):
            title_type = row.get('titleType')
            
            # Determinar colección destino
            collection = None
            for col_name, types in TITLE_TYPES.items():
                if title_type in types:
                    collection = col_name
                    break
            
            if not collection:
                collection = 'others'
            
            # Convertir géneros
            genres = row.get('genres', '').split(',') if row.get('genres') else []
            
            # Documento base
            doc = {
                '_id': row['tconst'],
                'titulo': row.get('primaryTitle'),
                'titulo_original': row.get('originalTitle'),
                'año': int(row['startYear']) if row.get('startYear') and row['startYear'].isdigit() else None,
                'generos': genres,
            }
            
            # Campos específicos por tipo
            if collection in ['movies', 'documentaries', 'shorts']:
                doc['duracion'] = int(row['runtimeMinutes']) if row.get('runtimeMinutes') and row['runtimeMinutes'].isdigit() else None
            
            if collection == 'series':
                doc['año_inicio'] = doc['año']
                doc['año_fin'] = int(row['endYear']) if row.get('endYear') and row['endYear'].isdigit() else None
                del doc['año']
            
            batches[collection].append(doc)
            counts[collection] += 1
            
            # Insert cuando el batch esté lleno
            if len(batches[collection]) >= BATCH_SIZE:
                self.db[collection].insert_many(batches[collection], ordered=False)
                batches[collection] = []
        
        # Insert batches restantes
        for collection, batch in batches.items():
            if batch:
                self.db[collection].insert_many(batch, ordered=False)
        
        logger.info(f"✅ Títulos cargados:")
        for col_name, count in counts.items():
            logger.info(f"   - {col_name}: {count:,}")
    
    # ========================================================================
    # PASO 3: AGREGAR RATINGS
    # ========================================================================
    
    def merge_ratings(self):
        """Agregar ratings a movies y series"""
        logger.info("\n" + "="*80)
        logger.info("⭐ PASO 3: Agregando RATINGS")
        logger.info("="*80)
        
        from pymongo import UpdateOne
        
        batch_movies = []
        batch_series = []
        
        for row in tqdm(self.read_tsv(TSV_FILES['ratings']), desc="Ratings"):
            tconst = row['tconst']
            rating = float(row['averageRating']) if row.get('averageRating') else None
            votos = int(row['numVotes']) if row.get('numVotes') else None
            
            update = UpdateOne(
                {'_id': tconst},
                {'$set': {'rating': rating, 'votos': votos}}
            )
            
            # Intentar actualizar en movies y series
            batch_movies.append(update)
            batch_series.append(update)
            
            if len(batch_movies) >= BATCH_SIZE:
                try:
                    self.db['movies'].bulk_write(batch_movies, ordered=False)
                except:
                    pass
                try:
                    self.db['series'].bulk_write(batch_series, ordered=False)
                except:
                    pass
                batch_movies = []
                batch_series = []
        
        # Restantes
        if batch_movies:
            try:
                self.db['movies'].bulk_write(batch_movies, ordered=False)
            except:
                pass
            try:
                self.db['series'].bulk_write(batch_series, ordered=False)
            except:
                pass
        
        logger.info("✅ Ratings agregados")
    
    # ========================================================================
    # PASO 4: AGREGAR CREW (directores/escritores)
    # ========================================================================
    
    def merge_crew(self):
        """Agregar director_ids y writer_ids a movies/series"""
        logger.info("\n" + "="*80)
        logger.info("🎥 PASO 4: Agregando CREW (directors/writers)")
        logger.info("="*80)
        
        from pymongo import UpdateOne
        
        batch_movies = []
        batch_series = []
        
        for row in tqdm(self.read_tsv(TSV_FILES['crew']), desc="Crew"):
            tconst = row['tconst']
            
            directors = row.get('directors', '').split(',') if row.get('directors') else []
            writers = row.get('writers', '').split(',') if row.get('writers') else []
            
            update = UpdateOne(
                {'_id': tconst},
                {'$set': {
                    'director_ids': directors,
                    'writer_ids': writers
                }}
            )
            
            batch_movies.append(update)
            batch_series.append(update)
            
            if len(batch_movies) >= BATCH_SIZE:
                try:
                    self.db['movies'].bulk_write(batch_movies, ordered=False)
                except:
                    pass
                try:
                    self.db['series'].bulk_write(batch_series, ordered=False)
                except:
                    pass
                batch_movies = []
                batch_series = []
        
        # Restantes
        if batch_movies:
            try:
                self.db['movies'].bulk_write(batch_movies, ordered=False)
            except:
                pass
            try:
                self.db['series'].bulk_write(batch_series, ordered=False)
            except:
                pass
        
        logger.info("✅ Crew agregado")
    
    # ========================================================================
    # PASO 5: CARGAR PRINCIPALS
    # ========================================================================
    
    def load_principals(self):
        """Cargar principals (roles en producciones)"""
        logger.info("\n" + "="*80)
        logger.info("🎭 PASO 5: Cargando PRINCIPALS")
        logger.info("="*80)
        
        self.db['principals'].drop()
        
        batch = []
        count = 0
        
        for row in tqdm(self.read_tsv(TSV_FILES['principals']), desc="Principals"):
            doc = {
                'titulo_id': row['tconst'],
                'persona_id': row['nconst'],
                'categoria': row.get('category'),
                'personaje': row.get('characters'),
                'orden': int(row['ordering']) if row.get('ordering') else None
            }
            
            batch.append(doc)
            count += 1
            
            if len(batch) >= BATCH_SIZE:
                self.db['principals'].insert_many(batch, ordered=False)
                batch = []
        
        if batch:
            self.db['principals'].insert_many(batch, ordered=False)
        
        logger.info(f"✅ {count:,} principals cargados")
    
    # ========================================================================
    # PASO 6: CREAR COLECCIONES ESPECIALIZADAS DE PERSONAS
    # ========================================================================
    
    def create_specialized_people(self):
        """Crear colecciones actors, directors, writers"""
        logger.info("\n" + "="*80)
        logger.info("👤 PASO 6: Creando colecciones especializadas de personas")
        logger.info("="*80)
        
        # Actores
        logger.info("  Creando colección: actors")
        self.db['actors'].drop()
        
        pipeline_actors = [
            {'$match': {'profesiones': {'$in': ['actor', 'actress']}}},
            {'$project': {
                '_id': 1,
                'nombre': 1,
                'año_nacimiento': 1
            }},
            {'$addFields': {'peliculas_count': 0}},
            {'$out': 'actors'}  # Escribe directo sin cargar en RAM
        ]
        
        self.db['people'].aggregate(pipeline_actors, allowDiskUse=True)
        count = self.db['actors'].count_documents({})
        logger.info(f"    ✅ {count:,} actores")
        
        # Directores
        logger.info("  Creando colección: directors")
        self.db['directors'].drop()
        
        pipeline_directors = [
            {'$match': {'profesiones': {'$in': ['director']}}},
            {'$project': {
                '_id': 1,
                'nombre': 1,
                'año_nacimiento': 1
            }},
            {'$addFields': {'peliculas_count': 0}},
            {'$out': 'directors'}  # Escribe directo sin cargar en RAM
        ]
        
        self.db['people'].aggregate(pipeline_directors, allowDiskUse=True)
        count = self.db['directors'].count_documents({})
        logger.info(f"    ✅ {count:,} directores")
        
        # Escritores
        logger.info("  Creando colección: writers")
        self.db['writers'].drop()
        
        pipeline_writers = [
            {'$match': {'profesiones': {'$in': ['writer']}}},
            {'$project': {
                '_id': 1,
                'nombre': 1,
                'año_nacimiento': 1
            }},
            {'$addFields': {'obras_count': 0}},
            {'$out': 'writers'}  # Escribe directo sin cargar en RAM
        ]
        
        self.db['people'].aggregate(pipeline_writers, allowDiskUse=True)
        count = self.db['writers'].count_documents({})
        logger.info(f"    ✅ {count:,} escritores")
    
    # ========================================================================
    # PASO 7: CALCULAR ESTADÍSTICAS
    # ========================================================================
    
    def calculate_statistics(self):
        """Calcular peliculas_count para actors y directors"""
        logger.info("\n" + "="*80)
        logger.info("📊 PASO 7: Calculando estadísticas")
        logger.info("="*80)
        
        from pymongo import UpdateOne
        
        # Contar películas por director
        logger.info("  Contando películas por director...")
        pipeline = [
            {'$match': {'director_ids': {'$exists': True, '$ne': []}}},
            {'$unwind': '$director_ids'},
            {'$group': {
                '_id': '$director_ids',
                'count': {'$sum': 1}
            }}
        ]
        
        director_counts = self.db['movies'].aggregate(pipeline, allowDiskUse=True)
        updates = []
        
        for doc in tqdm(director_counts, desc="Director counts"):
            updates.append(UpdateOne(
                {'_id': doc['_id']},
                {'$set': {'peliculas_count': doc['count']}}
            ))
            
            if len(updates) >= 1000:
                try:
                    self.db['directors'].bulk_write(updates, ordered=False)
                except:
                    pass
                updates = []
        
        if updates:
            try:
                self.db['directors'].bulk_write(updates, ordered=False)
            except:
                pass
        
        # Contar películas por actor (desde principals)
        logger.info("  Contando películas por actor...")
        pipeline = [
            {'$match': {'categoria': {'$in': ['actor', 'actress']}}},
            {'$group': {
                '_id': '$persona_id',
                'count': {'$sum': 1}
            }}
        ]
        
        actor_counts = self.db['principals'].aggregate(pipeline, allowDiskUse=True)
        updates = []
        
        for doc in tqdm(actor_counts, desc="Actor counts"):
            updates.append(UpdateOne(
                {'_id': doc['_id']},
                {'$set': {'peliculas_count': doc['count']}}
            ))
            
            if len(updates) >= 1000:
                try:
                    self.db['actors'].bulk_write(updates, ordered=False)
                except:
                    pass
                updates = []
        
        if updates:
            try:
                self.db['actors'].bulk_write(updates, ordered=False)
            except:
                pass
        
        logger.info("✅ Estadísticas calculadas")
    
    # ========================================================================
    # PASO 8: CREAR ÍNDICES
    # ========================================================================
    
    def create_indexes(self):
        """Crear índices optimizados"""
        logger.info("\n" + "="*80)
        logger.info("📇 PASO 8: Creando índices")
        logger.info("="*80)
        
        # People
        self.db['people'].create_index([('nombre', TEXT)])
        logger.info("  ✅ people: nombre (TEXT)")
        
        # Movies
        self.db['movies'].create_index([('titulo', TEXT), ('titulo_original', TEXT)])
        self.db['movies'].create_index([('rating', DESCENDING), ('votos', DESCENDING)])
        self.db['movies'].create_index([('director_ids', ASCENDING)])
        self.db['movies'].create_index([('generos', ASCENDING)])
        self.db['movies'].create_index([('año', DESCENDING)])
        logger.info("  ✅ movies: 5 índices")
        
        # Series
        self.db['series'].create_index([('titulo', TEXT)])
        self.db['series'].create_index([('rating', DESCENDING), ('votos', DESCENDING)])
        logger.info("  ✅ series: 2 índices")
        
        # Actors
        self.db['actors'].create_index([('nombre', TEXT)])
        self.db['actors'].create_index([('peliculas_count', DESCENDING)])
        logger.info("  ✅ actors: 2 índices")
        
        # Directors
        self.db['directors'].create_index([('nombre', TEXT)])
        self.db['directors'].create_index([('peliculas_count', DESCENDING)])
        logger.info("  ✅ directors: 2 índices")
        
        # Principals
        self.db['principals'].create_index([('titulo_id', ASCENDING)])
        self.db['principals'].create_index([('persona_id', ASCENDING)])
        self.db['principals'].create_index([('categoria', ASCENDING)])
        logger.info("  ✅ principals: 3 índices")
        
        logger.info("✅ Todos los índices creados")
    
    # ========================================================================
    # EJECUTAR TODO
    # ========================================================================
    
    def load_all(self):
        """Ejecutar carga completa"""
        try:
            self.load_people()
            self.load_titles()
            self.merge_ratings()
            self.merge_crew()
            self.load_principals()
            self.create_specialized_people()
            self.calculate_statistics()
            self.create_indexes()
            
            elapsed = (time.time() - self.start_time) / 60
            
            logger.info("\n" + "="*80)
            logger.info("✅ CARGA COMPLETADA")
            logger.info(f"   Tiempo total: {elapsed:.1f} minutos")
            logger.info("="*80)
            
            # Mostrar resumen
            logger.info("\n📊 RESUMEN:")
            collections = ['people', 'movies', 'series', 'documentaries', 'shorts', 
                          'actors', 'directors', 'writers', 'principals']
            for col in collections:
                count = self.db[col].count_documents({})
                logger.info(f"   {col}: {count:,}")
            
        except Exception as e:
            logger.error(f"\n❌ ERROR: {e}")
            raise
        finally:
            self.client.close()


if __name__ == '__main__':
    loader = IMDbNormalizedLoader()
    loader.load_all()
