"""
================================================================================
DISEÑO DE COLECCIONES - Modelo Normalizado MongoDB
================================================================================

ESTRATEGIA: Múltiples colecciones especializadas (como tablas en SQL)
VENTAJA: Sin pérdida de datos, consultas rápidas con índices apropiados
================================================================================

COLECCIONES:
============

1. people (~14.7M documentos)
   {
     _id: "nm0000001",
     nombre: "Fred Astaire",
     año_nacimiento: 1899,
     año_muerte: 1987,
     profesiones: ["actor", "producer", "soundtrack"]
   }

2. movies (~600k documentos - solo películas)
   {
     _id: "tt0111161",
     titulo: "The Shawshank Redemption",
     titulo_original: "The Shawshank Redemption",
     año: 1994,
     duracion: 142,
     generos: ["Drama"],
     rating: 9.3,
     votos: 2500000,
     director_ids: ["nm0001104"],
     writer_ids: ["nm0001104", "nm0000175"]
   }

3. series (~200k documentos - solo series/tvSeries)
   {
     _id: "tt0903747",
     titulo: "Breaking Bad",
     titulo_original: "Breaking Bad",
     año_inicio: 2008,
     año_fin: 2013,
     generos: ["Crime", "Drama", "Thriller"],
     rating: 9.5,
     votos: 1800000
   }

4. episodes (~7M documentos - episodios de series)
   {
     _id: "tt0959621",
     titulo: "Pilot",
     serie_id: "tt0903747",
     temporada: 1,
     episodio: 1,
     año: 2008
   }

5. documentaries (~150k documentos)
   {
     _id: "tt1504320",
     titulo: "The King of Kong",
     titulo_original: "The King of Kong: A Fistful of Quarters",
     año: 2007,
     duracion: 79,
     generos: ["Documentary"],
     rating: 8.1,
     votos: 45000
   }

6. shorts (~3M documentos - cortometrajes)
   {
     _id: "tt0000001",
     titulo: "Carmencita",
     año: 1894,
     duracion: 1,
     generos: ["Short", "Documentary"]
   }

7. actors (~8M documentos - solo actores)
   {
     _id: "nm0000209",
     nombre: "Tim Robbins",
     año_nacimiento: 1958,
     peliculas_count: 0,  // Se calculará
     series_count: 0
   }

8. directors (~500k documentos - solo directores)
   {
     _id: "nm0001104",
     nombre: "Frank Darabont",
     año_nacimiento: 1959,
     peliculas_count: 0,  // Se calculará
     obras_ids: []  // Se llenará
   }

9. writers (~400k documentos - solo escritores)
   {
     _id: "nm0000175",
     nombre: "Stephen King",
     año_nacimiento: 1947,
     obras_count: 0
   }

10. principals (~95M documentos - roles en producciones)
    {
      _id: ObjectId(),
      titulo_id: "tt0111161",
      persona_id: "nm0000209",
      categoria: "actor",
      personaje: "Andy Dufresne",
      orden: 1
    }

================================================================================
ÍNDICES CLAVE:
================================================================================

people:
  - _id (automático)
  - nombre (TEXT)
  - profesiones

movies:
  - _id (automático)
  - titulo (TEXT)
  - rating + votos (compound)
  - director_ids
  - generos
  - año

series:
  - titulo (TEXT)
  - rating + votos
  - año_inicio

episodes:
  - serie_id
  - temporada + episodio

directors:
  - nombre (TEXT)
  - peliculas_count

actors:
  - nombre (TEXT)
  - peliculas_count

principals:
  - titulo_id
  - persona_id
  - categoria

================================================================================
CONSULTAS OPTIMIZADAS:
================================================================================

Query 1: Top 10 películas
  → db.movies.find().sort({rating: -1, votos: -1}).limit(10)
  → Tiempo: <2s

Query 2: Top 10 actores
  → db.actors.find().sort({peliculas_count: -1}).limit(10)
  → Tiempo: <2s

Query 3: Director con más películas
  → db.directors.find().sort({peliculas_count: -1}).limit(1)
  → Tiempo: <1s

Query 4: Buscar película por nombre
  → db.movies.find({$text: {$search: 'Inception'}})
  → Luego lookup a directors si necesitas nombres
  → Tiempo: <5s

Query 5: Películas de un director
  → Paso 1: db.directors.findOne({nombre: /Spielberg/i})
  → Paso 2: db.movies.find({director_ids: 'nm0000229'})
  → Tiempo: <5s

Query BONUS: Actores de una película
  → db.principals.find({titulo_id: 'tt0111161', categoria: 'actor'})
  → Lookup a people para nombres
  → Tiempo: <3s

Query BONUS: Filmografía de un actor
  → db.principals.find({persona_id: 'nm0000209', categoria: 'actor'})
  → Lookup a movies/series para títulos
  → Tiempo: <5s

"""
