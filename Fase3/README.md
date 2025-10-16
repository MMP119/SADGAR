# Documentación del Proyecto: Carga y Optimización de IMDb en MongoDB

## 1. Resumen Ejecutivo

El objetivo de este proyecto fue migrar el masivo conjunto de datos de IMDb (compuesto por 7 archivos TSV con más de 138 millones de registros en total) a una base de datos NoSQL MongoDB. El diseño se centró en optimizar la estructura para un conjunto específico de consultas complejas, garantizando que cada una se ejecute en menos de 30 segundos.

---

## 2. Estrategia de Diseño: El Modelo Híbrido de 3 Colecciones

En lugar de crear una colección por cada archivo de origen (lo que replicaría un modelo relacional ineficiente), se optó por un **modelo de datos híbrido**. Este enfoque utiliza tanto el **embebido de documentos** para acelerar las lecturas como la **referenciación** para mantener la consistencia y evitar la duplicación masiva de datos.

### Colección `titles` (La Colección Principal)
-   **Propósito:** Es el corazón de la base de datos. Cada documento representa una obra única (película, serie, corto, etc.).
-   **Datos Base:** Se construye a partir de `title.basics.tsv`.
-   **Datos Embebidos:** Para maximizar la velocidad de lectura, se fusionan e incrustan los datos de otros archivos directamente en cada documento de `titles`:
    -   **Ratings (`rating`):** El promedio y número de votos se guarda como un sub-documento.
    -   **Crew (`crew`):** Los IDs de directores y escritores se guardan en un sub-documento.
    -   **Reparto (`principals`):** La información de los actores principales se guarda como un array de sub-documentos.
    -   **Episodios:** La información de temporada y número de episodio se añade directamente a los documentos que son de tipo `tvepisode`.

### Colección `people` (Fuente de Verdad para Personas)
-   **Propósito:** Almacena la información única de cada persona (actores, directores, etc.). Actúa como una fuente de verdad centralizada.
-   **Datos Base:** Se construye a partir de `name.basics.tsv`.
-   **Estrategia:** Se utiliza la **referenciación**. La colección `titles` solo guarda el ID (`nconst`) de las personas. Esto evita duplicar millones de veces el nombre y biografía de un actor, y facilita las actualizaciones.

### Colección `akas` (Colección Auxiliar)
-   **Propósito:** Almacena todos los títulos alternativos, localizados y de trabajo de las obras.
-   **Datos Base:** Se construye a partir de `title.akas.tsv`.
-   **Estrategia:** Se mantiene en una colección separada para no "engordar" innecesariamente los documentos de la colección `titles`. Un título popular puede tener docenas de AKAs, y cargarlos siempre ralentizaría las consultas más comunes.

---

## 3. Distribución de los 7 Archivos de Origen

La siguiente tabla resume cómo se distribuyó cada archivo TSV en nuestra estructura de 3 colecciones:

| Archivo de Origen (TSV)      | Colección de Destino Final | Estrategia de Carga                                                                                                  |
| ----------------------------- | -------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| `title.basics.tsv`            | `titles`                   | Carga directa. Cada fila se convierte en el documento base de esta colección.                                        |
| `name.basics.tsv`             | `people`                   | Carga directa. Cada fila se convierte en un documento en esta colección.                                             |
| `title.akas.tsv`              | `akas`                     | Carga directa. Cada fila se convierte en un documento en esta colección.                                             |
| `title.ratings.tsv`           | `titles`                   | Cargado a `temp_ratings` y luego **embebido** como el sub-documento `rating` en los documentos `titles` correspondientes. |
| `title.crew.tsv`              | `titles`                   | Cargado a `temp_crew` y luego **embebido** como el sub-documento `crew` en los documentos `titles` correspondientes.     |
| `title.principals.tsv`        | `titles`                   | Cargado a `temp_principals` y luego **embebido** como un array de sub-documentos `principals`.                         |
| `title.episode.tsv`           | `titles`                   | Cargado a `temp_episodes` y luego los campos relevantes fueron **añadidos** a los documentos `titles` de tipo episodio. |

---

## 4. Estrategia Final de Indexación para un Rendimiento Óptimo

Tras la carga de datos, el paso más crucial es la creación de índices. Un índice es una estructura de datos especial que permite a MongoDB encontrar documentos de forma extremadamente rápida sin tener que escanear toda la colección (evitando el temido `COLLSCAN`).

La siguiente es la lista definitiva de índices implementados para garantizar que todas las consultas se ejecuten en menos de 30 segundos.

### Índices en la Colección `titles`

1.  **Índice Compuesto para "Top 10 Ratings":**
    -   `{ "titleType": 1, "rating.average": -1, "rating.votes": -1 }`
    -   **Propósito:** Acelera la consulta del Top 10. La primera parte (`titleType`) filtra rápidamente solo las películas, y la segunda (`rating.average`) permite ordenarlas eficientemente usando el índice, resultando en una "Covered Query" casi instantánea.

2.  **Índice de Texto para Búsquedas por Nombre:**
    -   `{ "primaryTitle": "text" }`
    -   **Propósito:** Permite búsquedas de texto ultra-rápidas usando el operador `$text`. Es fundamental para la consulta de "Información de una película", convirtiendo una búsqueda de minutos en una de milisegundos.

3.  **Índice para Búsqueda de Actores/Actrices:**
    -   `{ "principals.category": 1 }`
    -   **Propósito:** Acelera la consulta "Top 10 Actores". Permite a MongoDB encontrar rápidamente todos los documentos que contienen actores o actrices antes de la costosa operación `$unwind`, reduciendo drásticamente el conjunto de datos a procesar.

4.  **Índices para Búsquedas de Crew y Reparto:**
    -   `{ "crew.directors": 1 }` y `{ "principals.nconst": 1 }`
    -   **Propósito:** Optimizan las uniones (`$lookup`) cuando se busca desde una persona hacia sus obras.

### Índices en `people` y `akas`

1.  **Índice en `people.primaryName`:**
    -   `{ "primaryName": 1 }`
    -   **Propósito:** Permite encontrar a una persona por su nombre de forma instantánea, paso necesario para la consulta "Películas de un Director".

2.  **Índice en `akas.title`:**
    -   `{ "title": 1 }`
    -   **Propósito:** Acelera la búsqueda de títulos alternativos.