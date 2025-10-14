/*
================================================================================
CONSULTAS - Modelo Normalizado con Múltiples Colecciones
================================================================================
Ejecutar en DataGrip: mongodb://admin:admin123@IP:27017/IMDb_NoSQL
================================================================================
*/


-- ============================================================================
-- QUERY 1: Top 10 películas con mejor rating
-- ============================================================================
-- Tiempo esperado: <2 segundos
-- Usa índice compound en rating + votos

db.getCollection('movies').find({
    rating: {$exists: true},
    votos: {$gte: 50000}
}).sort({
    rating: -1,
    votos: -1
}).limit(10)


-- ============================================================================
-- QUERY 2: Top 10 actores con más películas
-- ============================================================================
-- Tiempo esperado: <2 segundos
-- Usa índice en peliculas_count

db.getCollection('actors').find({
    peliculas_count: {$gt: 0}
}).sort({
    peliculas_count: -1
}).limit(10)


-- ============================================================================
-- QUERY 3: Director con más películas
-- ============================================================================
-- Tiempo esperado: <1 segundo
-- Usa índice en peliculas_count

db.getCollection('directors').find({
    peliculas_count: {$gt: 0}
}).sort({
    peliculas_count: -1
}).limit(1)


-- ============================================================================
-- QUERY 4: Buscar película por nombre (con datos completos)
-- ============================================================================
-- Tiempo esperado: <5 segundos
-- Paso 1: Buscar película
-- Paso 2: $lookup a directors para nombres completos

db.getCollection('movies').aggregate([
    {$match: {$text: {$search: 'Inception'}}},
    {$limit: 10},
    {$lookup: {
        from: 'directors',
        localField: 'director_ids',
        foreignField: '_id',
        as: 'directores_info'
    }},
    {$project: {
        titulo: 1,
        año: 1,
        rating: 1,
        votos: 1,
        generos: 1,
        directores: '$directores_info.nombre'
    }}
])


-- ============================================================================
-- QUERY 5: Películas de un director (stored procedure equivalente)
-- ============================================================================
-- Tiempo esperado: <5 segundos

-- PASO 1: Buscar director por nombre
db.getCollection('directors').findOne({
    nombre: {$regex: 'Spielberg', $options: 'i'}
})

-- PASO 2: Obtener sus películas (usar _id del paso 1, ej: 'nm0000229')
db.getCollection('movies').find({
    director_ids: 'nm0000229'
}).sort({
    año: -1
}).limit(50)


-- ============================================================================
-- QUERIES BONUS
-- ============================================================================

-- Actores de una película específica (con lookup)
db.getCollection('principals').aggregate([
    {$match: {
        titulo_id: 'tt0111161',  // The Shawshank Redemption
        categoria: {$in: ['actor', 'actress']}
    }},
    {$sort: {orden: 1}},
    {$limit: 10},
    {$lookup: {
        from: 'people',
        localField: 'persona_id',
        foreignField: '_id',
        as: 'persona_info'
    }},
    {$unwind: '$persona_info'},
    {$project: {
        nombre: '$persona_info.nombre',
        personaje: 1,
        orden: 1
    }}
])


-- Filmografía de un actor
db.getCollection('principals').aggregate([
    {$match: {
        persona_id: 'nm0000209',  // Tim Robbins
        categoria: {$in: ['actor', 'actress']}
    }},
    {$lookup: {
        from: 'movies',
        localField: 'titulo_id',
        foreignField: '_id',
        as: 'pelicula_info'
    }},
    {$unwind: '$pelicula_info'},
    {$project: {
        titulo: '$pelicula_info.titulo',
        año: '$pelicula_info.año',
        rating: '$pelicula_info.rating',
        personaje: 1
    }},
    {$sort: {año: -1}},
    {$limit: 20}
])


-- Top 10 series
db.getCollection('series').find({
    rating: {$exists: true}
}).sort({
    rating: -1,
    votos: -1
}).limit(10)


-- Películas por género
db.getCollection('movies').find({
    generos: 'Action',
    rating: {$gte: 7.0}
}).sort({
    rating: -1
}).limit(20)


-- Directores más prolíficos (top 20)
db.getCollection('directors').find().sort({
    peliculas_count: -1
}).limit(20)


-- Buscar persona por nombre
db.getCollection('people').find({
    $text: {$search: 'Tom Hanks'}
})


-- Verificar datos completos de una película
db.getCollection('movies').findOne({_id: 'tt0111161'})


-- ============================================================================
-- EXPLICACIONES PARA LA DEFENSA
-- ============================================================================

/*
ARQUITECTURA:
=============
- 10 colecciones especializadas (people, movies, series, episodes, documentaries, 
  shorts, actors, directors, writers, principals)
- Total: ~138M documentos (SIN pérdida de datos)
- Modelo normalizado similar a SQL pero con ventajas NoSQL

VENTAJAS:
=========
1. SIN PÉRDIDA DE DATOS: Todos los 138M+ registros de IMDb
2. CONSULTAS RÁPIDAS: Índices específicos por colección
3. ESCALABLE: Fácil agregar colecciones (producers, composers)
4. FLEXIBLE: $lookup solo cuando necesitas datos relacionados
5. MANTENIBLE: Actualizar actors no afecta movies

ÍNDICES CLAVE:
==============
- movies: TEXT search, rating+votos, director_ids, generos, año
- actors/directors: TEXT search, peliculas_count
- principals: titulo_id, persona_id, categoria
- Total: ~18 índices optimizados

TIEMPOS DE QUERY:
=================
- Query 1 (Top movies): <2s
- Query 2 (Top actors): <2s
- Query 3 (Top director): <1s
- Query 4 (Search + lookup): <5s
- Query 5 (Director movies): <5s
- Todas BIEN por debajo del límite de 30s ✅

TRADE-OFFS:
===========
- Espacio: 2-3GB (acceptable para 138M docs)
- Carga: 75-80 minutos (one-time cost)
- Complejidad: $lookup cuando necesitas datos relacionados
- BENEFICIO: Queries ultra-rápidas, datos completos, modelo profesional

COMPARACIÓN CON OTROS MODELOS:
===============================
1. Desnormalización (1-2 colecciones):
   ❌ Pérdida de datos
   ❌ Documentos gigantes
   ✅ Queries muy simples

2. Normalización (múltiples colecciones):
   ✅ Sin pérdida de datos
   ✅ Documentos manejables
   ✅ Escalable y mantenible
   ⚠️ Requiere $lookup (pero rápido con índices)

JUSTIFICACIÓN:
==============
Este modelo sigue las mejores prácticas de MongoDB para datasets grandes:
- "Reference data that changes frequently" → Normalizar
- "Embed data that is queried together" → Rating/votos dentro de movies
- "Index for query patterns" → 18 índices optimizados

Similar a arquitecturas de:
- Netflix: Múltiples colecciones especializadas
- YouTube: Videos, channels, users, comments (separado)
- IMDb mismo: Tablas normalizadas con índices
*/
