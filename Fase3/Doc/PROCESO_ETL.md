# Proceso ETL: De 7 Archivos TSV a 3 Colecciones MongoDB

## Diagrama Visual del Flujo Completo

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         ARCHIVOS TSV DE ORIGEN                               │
│                           (138M registros)                                   │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
    ┌───────────────┬───────────────┬───────────────┬───────────────┐
    │ CARGA DIRECTA │ CARGA DIRECTA │ CARGA DIRECTA │CARGA TEMPORAL │
    ▼               ▼               ▼               ▼               
┌─────────┐   ┌─────────┐   ┌─────────┐   ┌──────────────────┐
│  name.  │   │ title.  │   │ title.  │   │  4 archivos →    │
│ basics  │   │ basics  │   │  akas   │   │  temp_*          │
│ 14.7M   │   │ 11.8M   │   │  40M    │   │  118M registros  │
└────┬────┘   └────┬────┘   └────┬────┘   └────────┬─────────┘
     │             │             │                  │
     ▼             ▼             ▼                  │
┌─────────┐   ┌─────────┐   ┌─────────┐            │
│ people  │   │ titles  │   │  akas   │            │
│ (FINAL) │   │ (BASE)  │   │ (FINAL) │            │
└─────────┘   └────┬────┘   └─────────┘            │
                   │                                │
                   │    ┌───────────────────────────┘
                   │    │  FASE DE MERGE
                   ▼    ▼  (Embebido de datos)
              ┌─────────────┐
              │   titles    │
              │  (COMPLETO) │
              │  • ratings  │
              │  • crew     │
              │  • principals│
              │  • episodes │
              └─────────────┘
                     │
                     ▼
            ┌────────────────┐
            │  INDEXACIÓN    │
            │  7 índices     │
            └────────────────┘
                     │
                     ▼
       ┌──────────────────────────┐
       │   3 COLECCIONES          │
       │   OPTIMIZADAS Y LISTAS   │
       └──────────────────────────┘
```

## Transformación Detallada por Archivo

### Archivo 1: name.basics.tsv
```
ENTRADA (TSV):
┌──────────┬─────────────┬───────────┬───────────┬──────────────────┐
│ nconst   │ primaryName │ birthYear │ deathYear │ primaryProfession│
├──────────┼─────────────┼───────────┼───────────┼──────────────────┤
│nm0000001 │Fred Astaire │ 1899      │ 1987      │actor,director    │
└──────────┴─────────────┴───────────┴───────────┴──────────────────┘

SALIDA (MongoDB - people):
{
  "_id": "nm0000001",
  "primaryName": "Fred Astaire",
  "birthYear": 1899,
  "deathYear": 1987,
  "primaryProfession": ["actor", "director"]
}

TRANSFORMACIONES:
- nconst → _id (clave primaria)
- String separado por comas → Array
- Valores "\N" → null
```

### Archivo 2: title.basics.tsv
```
ENTRADA (TSV):
┌───────────┬───────────┬──────────────────────┬──────┬────────┐
│ tconst    │ titleType │ primaryTitle         │ year │ genres │
├───────────┼───────────┼──────────────────────┼──────┼────────┤
│tt0111161  │movie      │Shawshank Redemption  │ 1994 │ Drama  │
└───────────┴───────────┴──────────────────────┴──────┴────────┘

SALIDA (MongoDB - titles BASE):
{
  "_id": "tt0111161",
  "titleType": "movie",
  "primaryTitle": "The Shawshank Redemption",
  "startYear": 1994,
  "genres": ["Drama"]
  // Nota: Aún faltan ratings, crew, principals
}

TRANSFORMACIONES:
- tconst → _id
- String de géneros → Array
- Año como número entero
```

### Archivo 3: title.akas.tsv
```
ENTRADA (TSV):
┌───────────┬──────────┬──────────────────┬────────┬──────────┐
│ titleId   │ ordering │ title            │ region │ language │
├───────────┼──────────┼──────────────────┼────────┼──────────┤
│tt0111161  │ 1        │ Cadena perpetua  │ ES     │ es       │
└───────────┴──────────┴──────────────────┴────────┴──────────┘

SALIDA (MongoDB - akas):
{
  "_id": "tt0111161",
  "ordering": 1,
  "title": "Cadena perpetua",
  "region": "ES",
  "language": "es"
}

TRANSFORMACIONES:
- titleId → _id
- Carga directa sin merge
```

### Archivo 4: title.ratings.tsv
```
ENTRADA (TSV):
┌───────────┬───────────────┬──────────┐
│ tconst    │ averageRating │ numVotes │
├───────────┼───────────────┼──────────┤
│tt0111161  │ 9.3           │ 2500000  │
└───────────┴───────────────┴──────────┘

PASO 1 - Carga temporal (temp_ratings):
{
  "_id": "tt0111161",
  "averageRating": 9.3,
  "numVotes": 2500000
}

PASO 2 - Merge en titles:
db.titles.updateOne(
  {"_id": "tt0111161"},
  {"$set": {
    "rating": {
      "average": 9.3,
      "votes": 2500000
    }
  }}
)

RESULTADO FINAL en titles:
{
  "_id": "tt0111161",
  "primaryTitle": "The Shawshank Redemption",
  "rating": {              // <- EMBEBIDO
    "average": 9.3,
    "votes": 2500000
  }
}

TRANSFORMACIONES:
- Carga temporal → Merge → Embedding
- Renombrar campos (averageRating → average)
- Crear sub-documento
```

### Archivo 5: title.crew.tsv
```
ENTRADA (TSV):
┌───────────┬──────────────────┬──────────────────┐
│ tconst    │ directors        │ writers          │
├───────────┼──────────────────┼──────────────────┤
│tt0111161  │nm0001104         │nm0001104,nm00456 │
└───────────┴──────────────────┴──────────────────┘

PASO 1 - Carga temporal (temp_crew):
{
  "_id": "tt0111161",
  "directors": "nm0001104",
  "writers": "nm0001104,nm0456158"
}

PASO 2 - Merge en titles:
db.titles.updateOne(
  {"_id": "tt0111161"},
  {"$set": {
    "crew": {
      "directors": ["nm0001104"],
      "writers": ["nm0001104", "nm0456158"]
    }
  }}
)

RESULTADO FINAL en titles:
{
  "_id": "tt0111161",
  "primaryTitle": "The Shawshank Redemption",
  "rating": { "average": 9.3, "votes": 2500000 },
  "crew": {                // <- EMBEBIDO
    "directors": ["nm0001104"],
    "writers": ["nm0001104", "nm0456158"]
  }
}

TRANSFORMACIONES:
- String CSV → Array de IDs
- Crear sub-documento 'crew'
- Mantener referencias (no nombres completos)
```

### Archivo 6: title.principals.tsv
```
ENTRADA (TSV):
┌───────────┬──────────┬──────────┬──────────────────────┐
│ tconst    │ nconst   │ category │ characters           │
├───────────┼──────────┼──────────┼──────────────────────┤
│tt0111161  │nm0000209 │ actor    │ ["Andy Dufresne"]    │
│tt0111161  │nm0000151 │ actor    │ ["Red"]              │
└───────────┴──────────┴──────────┴──────────────────────┘

PASO 1 - Carga temporal (temp_principals):
// Múltiples documentos por película
{
  "_id": "tt0111161",
  "nconst": "nm0000209",
  "category": "actor",
  "characters": "[\"Andy Dufresne\"]"
}

PASO 2 - Merge en titles (iterativo con $push):
// Se ejecuta por cada actor:
db.titles.updateOne(
  {"_id": "tt0111161"},
  {"$push": {
    "principals": {
      "nconst": "nm0000209",
      "category": "actor",
      "characters": ["Andy Dufresne"]
    }
  }}
)

RESULTADO FINAL en titles:
{
  "_id": "tt0111161",
  "primaryTitle": "The Shawshank Redemption",
  "rating": { ... },
  "crew": { ... },
  "principals": [          // <- ARRAY EMBEBIDO
    {
      "nconst": "nm0000209",
      "category": "actor",
      "characters": ["Andy Dufresne"]
    },
    {
      "nconst": "nm0000151",
      "category": "actor",
      "characters": ["Red"]
    }
  ]
}

TRANSFORMACIONES:
- Múltiples filas → Array en un documento
- String JSON → Array parseado
- Uso de $push para agregar al array
```

### Archivo 7: title.episode.tsv
```
ENTRADA (TSV):
┌───────────┬──────────────┬──────────────┬───────────────┐
│ tconst    │ parentTconst │ seasonNumber │ episodeNumber │
├───────────┼──────────────┼──────────────┼───────────────┤
│tt0103569  │tt0101175     │ 1            │ 1             │
└───────────┴──────────────┴──────────────┴───────────────┘

PASO 1 - Carga temporal (temp_episodes):
{
  "_id": "tt0103569",
  "parentTconst": "tt0101175",
  "seasonNumber": 1,
  "episodeNumber": 1
}

PASO 2 - Merge en titles:
db.titles.updateOne(
  {"_id": "tt0103569"},
  {"$set": {
    "parentTconst": "tt0101175",
    "seasonNumber": 1,
    "episodeNumber": 1
  }}
)

RESULTADO FINAL en titles:
{
  "_id": "tt0103569",
  "titleType": "tvEpisode",
  "primaryTitle": "Pilot",
  "parentTconst": "tt0101175",   // <- AGREGADO
  "seasonNumber": 1,              // <- AGREGADO
  "episodeNumber": 1              // <- AGREGADO
}

TRANSFORMACIONES:
- Campos agregados directamente al documento
- Solo aplica a documentos de tipo 'tvEpisode'
```

## Comparación: Antes vs Después

### Diseño Relacional (Lo que NO hicimos)

```
7 COLECCIONES SEPARADAS:
========================
people              (14.7M docs)
titles              (11.8M docs)
akas                (40M docs)
ratings             (1.6M docs)
crew                (11.8M docs)
principals          (95M docs)
episodes            (9M docs)
------------------------
TOTAL: 184.8M documentos

CONSULTA "Película con ratings y directores":
1. Buscar en titles
2. Lookup en ratings    <- JOIN
3. Lookup en crew       <- JOIN
4. Lookup en principals <- JOIN
5. Lookup en people     <- JOIN
Tiempo: >2 minutos
```

### Diseño NoSQL Optimizado (Lo que hicimos)

```
3 COLECCIONES CONSOLIDADAS:
===========================
people              
titles              
  ├─ rating        (embebido)
  ├─ crew          (embebido)
  ├─ principals    (embebido)
  └─ episodes      (embebido)
akas               
------------------------


CONSULTA "Película con ratings y directores":
1. Buscar en titles
   → rating: YA ESTÁ EMBEBIDO
   → crew: YA ESTÁ EMBEBIDO
   → principals: YA ESTÁ EMBEBIDO
2. Lookup en people (solo si necesito nombres)
Tiempo: <2 segundos
```

## Decisiones de Diseño y Justificación

### ¿Por qué embeber ratings, crew y principals?

```
OPCIÓN A: Referencias (estilo relacional)
titles: { "_id": "tt0111161", "rating_id": "r123" }
ratings: { "_id": "r123", "average": 9.3 }

Ventaja:  Ninguna relevante
Desventaja: - Requiere JOIN
            - 2 consultas en lugar de 1
            - Más lento

OPCIÓN B: Embebido (estilo NoSQL) <- ELEGIDA
titles: {
  "_id": "tt0111161",
  "rating": { "average": 9.3 }  <- Directo
}

Ventaja:  - 1 sola consulta
          - Sin JOINs
          - 60x más rápido
Desventaja: Ninguna relevante
```

### ¿Por qué mantener people separado?

```
OPCIÓN A: Embeber nombres de personas en titles
titles: {
  "_id": "tt0111161",
  "crew": {
    "directors": ["Frank Darabont"]  <- Nombre completo
  }
}

Problema: 
- "Frank Darabont" se duplica en 150+ películas
- Si cambia su nombre, hay que actualizar 150+ docs
- Desperdicia 15 bytes × 150 = 2.25 KB por persona

OPCIÓN B: Referencias a people <- ELEGIDA
titles: {
  "_id": "tt0111161",
  "crew": {
    "directors": ["nm0001104"]  <- Solo ID (9 bytes)
  }
}

Ventaja:
- Un solo lugar para actualizar
- Ahorra espacio (9 bytes vs 15+ bytes)
- 14.7M nombres NO duplicados
- Lookup solo cuando se necesita el nombre
```

### ¿Por qué mantener akas separado?

```
OPCIÓN A: Embeber akas en titles
titles: {
  "_id": "tt0111161",
  "akas": [
    {"title": "Cadena perpetua", "region": "ES"},
    {"title": "Die Verurteilten", "region": "DE"},
    // ... 50+ traducciones
  ]
}

Problema:
- Títulos populares tienen 50+ traducciones
- La mayoría de consultas NO necesitan traducciones
- Inflar cada documento con datos raramente usados

OPCIÓN B: Colección separada <- ELEGIDA
titles: { "_id": "tt0111161", ... }  <- Ligero
akas: { "_id": "tt0111161", "title": "...", ... }

Ventaja:
- Documentos 'titles' más ligeros
- Consultas principales más rápidas
- Traducciones solo cuando se soliciten
- Separación de concerns
```

## Tecnologías y Optimizaciones

### Multiprocessing
```python
# Sin paralelización:
for archivo in archivos:
    cargar_archivo(archivo)  # Secuencial
# Tiempo: ~4 horas

# Con paralelización:
with Pool(cpu_count()) as pool:
    pool.starmap(cargar_archivo, archivos)
# Tiempo: ~1 hora
# Mejora: 4x más rápido
```

### Procesamiento por Chunks
```python
# Sin chunks:
df = pd.read_csv("principals.tsv")  # 95M filas
# RAM: 50+ GB

# Con chunks:
for chunk in pd.read_csv("principals.tsv", chunksize=75000):
    procesar(chunk)
# RAM: ~2 GB
# Mejora: Uso constante de memoria
```

### Bulk Operations
```python
# Sin bulk:
for doc in documents:
    collection.insert_one(doc)  # 1 operación por doc
# Tiempo: ~8 horas

# Con bulk:
operations = [UpdateOne(...) for doc in documents]
collection.bulk_write(operations, ordered=False)
# Tiempo: ~5 minutos
# Mejora: 96x más rápido
```

