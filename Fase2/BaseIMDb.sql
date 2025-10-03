-- =====================================================================
-- 1. CONFIGURACIÓN Y PREPARACIÓN (Estilo PostgreSQL)
-- =====================================================================

-- En PostgreSQL, la configuración de rendimiento no se hace con `SET GLOBAL` en un script,
-- sino en el archivo de configuración `postgresql.conf` o con `ALTER SYSTEM`.
--
-- Equivalentes para tu configuración de MySQL:
--
-- local_infile=1;            -> Se reemplaza por el comando `\copy` en psql o `COPY FROM STDIN`. Es seguro por defecto.
-- innodb_buffer_pool_size     -> shared_buffers = 8GB
-- bulk_insert_buffer_size     -> maintenance_work_mem = 256MB (o más para cargas grandes)
-- sort_buffer_size            -> work_mem = 16MB
-- sql_mode = '';              -> PostgreSQL es más estricto con el estándar SQL por defecto, lo cual es bueno.
--
-- Para deshabilitar temporalmente las llaves foráneas en una carga masiva, la práctica común en PostgreSQL
-- es hacerlo dentro de una transacción o deshabilitar los triggers temporalmente:
-- SET session_replication_role = 'replica'; -- Deshabilita FKs y triggers
-- ... hacer la carga ...
-- SET session_replication_role = 'origin';  -- Los vuelve a habilitar

-- =====================================================================
-- 2. CREACIÓN DE LA BASE DE DATOS Y TIPOS PERSONALIZADOS
-- =====================================================================

-- Ejecutar en la terminal o un gestor de BBDD:
-- CREATE DATABASE "IMDb" ENCODING 'UTF8' LC_COLLATE='en_US.UTF-8' LC_CTYPE='en_US.UTF-8' TEMPLATE template0;

-- Conectarse a la base de datos antes de continuar: \c IMDb

-- En PostgreSQL, los ENUM se definen primero como tipos de datos
CREATE TYPE title_type_enum AS ENUM ('movie', 'short', 'tvseries', 'tvepisode', 'video', 'tvMovie', 'tvShort', 'tvMiniSeries', 'tvSpecial');
CREATE TYPE crew_type_enum AS ENUM ('director', 'writer');

-- Función para actualizar la columna `updated_at` automáticamente (equivalente a ON UPDATE CURRENT_TIMESTAMP)
CREATE OR REPLACE FUNCTION trigger_set_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- =====================================================================
-- 3. CREACIÓN DE TABLAS
-- =====================================================================

-- Tabla principal de títulos (películas, series, etc.)
CREATE TABLE titles (
    tconst VARCHAR(10) PRIMARY KEY,
    title_type title_type_enum NOT NULL,
    primary_title TEXT NOT NULL,
    original_title TEXT,
    is_adult BOOLEAN DEFAULT FALSE,
    start_year SMALLINT, -- PostgreSQL no tiene tipo YEAR
    end_year SMALLINT,
    runtime_minutes INTEGER, -- Se cambia SMALLINT UNSIGNED a INTEGER
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
-- Trigger para updated_at en la tabla titles
CREATE TRIGGER set_timestamp
BEFORE UPDATE ON titles
FOR EACH ROW
EXECUTE PROCEDURE trigger_set_timestamp();

-- Tabla de personas (actores, directores, escritores, etc.)
CREATE TABLE people (
    nconst VARCHAR(10) PRIMARY KEY,
    primary_name TEXT NOT NULL,
    birth_year SMALLINT,
    death_year SMALLINT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
-- Trigger para updated_at en la tabla people
CREATE TRIGGER set_timestamp
BEFORE UPDATE ON people
FOR EACH ROW
EXECUTE PROCEDURE trigger_set_timestamp();

-- Tabla de calificaciones/ratings
CREATE TABLE ratings (
    tconst VARCHAR(10) PRIMARY KEY,
    average_rating DECIMAL(3,1) NOT NULL,
    num_votes BIGINT NOT NULL, -- Se cambia INT UNSIGNED a BIGINT
    last_updated TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (tconst) REFERENCES titles(tconst) ON DELETE CASCADE
);
-- Trigger para last_updated en la tabla ratings
CREATE TRIGGER set_timestamp_ratings
BEFORE UPDATE ON ratings
FOR EACH ROW
EXECUTE PROCEDURE trigger_set_timestamp();


-- Tabla de episodios (para series de TV)
CREATE TABLE episodes (
    episode_tconst VARCHAR(10) PRIMARY KEY,
    parent_tconst VARCHAR(10) NOT NULL,
    season_number SMALLINT, -- Se cambia TINYINT UNSIGNED a SMALLINT
    episode_number INTEGER, -- Se cambia SMALLINT UNSIGNED a INTEGER
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (episode_tconst) REFERENCES titles(tconst) ON DELETE CASCADE,
    FOREIGN KEY (parent_tconst) REFERENCES titles(tconst) ON DELETE CASCADE
);

-- Catálogo de géneros
CREATE TABLE genres (
    genre_id SMALLSERIAL PRIMARY KEY, -- Se cambia TINYINT UNSIGNED AUTO_INCREMENT a SMALLSERIAL
    genre_name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Catálogo de categorías (actor, director, producer, etc.)
CREATE TABLE categories (
    category_id SMALLSERIAL PRIMARY KEY, -- Se cambia TINYINT UNSIGNED AUTO_INCREMENT a SMALLSERIAL
    category_name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Relación entre títulos y géneros
CREATE TABLE title_genres (
    id SERIAL PRIMARY KEY, -- Se cambia INT UNSIGNED AUTO_INCREMENT a SERIAL
    tconst VARCHAR(10) NOT NULL,
    genre_id SMALLINT NOT NULL,
    genre_order SMALLINT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (tconst) REFERENCES titles(tconst) ON DELETE CASCADE,
    FOREIGN KEY (genre_id) REFERENCES genres(genre_id) ON DELETE CASCADE
);

-- Actores principales y cast
CREATE TABLE title_principals (
    id SERIAL PRIMARY KEY,
    tconst VARCHAR(10) NOT NULL,
    ordering SMALLINT NOT NULL,
    nconst VARCHAR(10) NOT NULL,
    category_id SMALLINT NOT NULL,
    job TEXT,
    characters TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (tconst) REFERENCES titles(tconst) ON DELETE CASCADE,
    FOREIGN KEY (nconst) REFERENCES people(nconst) ON DELETE CASCADE,
    FOREIGN KEY (category_id) REFERENCES categories(category_id)
);

-- Crew (directores y escritores)
CREATE TABLE title_crew (
    id SERIAL PRIMARY KEY,
    tconst VARCHAR(10) NOT NULL,
    nconst VARCHAR(10) NOT NULL,
    crew_type crew_type_enum NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (tconst) REFERENCES titles(tconst) ON DELETE CASCADE,
    FOREIGN KEY (nconst) REFERENCES people(nconst) ON DELETE CASCADE
);

-- =====================================================
-- TABLAS TEMPORALES PARA CARGA INICIAL (UNLOGGED para mayor velocidad)
-- =====================================================
-- En PostgreSQL, para cargas masivas, se pueden crear tablas como UNLOGGED
-- para que no escriban en el WAL (Write-Ahead Log), lo que las hace mucho más rápidas.
-- Se convierten en tablas normales después de la carga.

CREATE UNLOGGED TABLE temp_title_basics (
    tconst VARCHAR(10), titleType VARCHAR(50), primaryTitle VARCHAR(500), originalTitle VARCHAR(500),
    isAdult VARCHAR(1), startYear VARCHAR(10), endYear VARCHAR(10), runtimeMinutes VARCHAR(10), genres TEXT
);
CREATE UNLOGGED TABLE temp_name_basics (
    nconst VARCHAR(10), primaryName VARCHAR(200), birthYear VARCHAR(10), deathYear VARCHAR(10),
    primaryProfession TEXT, knownForTitles TEXT
);
CREATE UNLOGGED TABLE temp_title_ratings ( tconst VARCHAR(10), averageRating VARCHAR(10), numVotes VARCHAR(20) );
CREATE UNLOGGED TABLE temp_title_crew ( tconst VARCHAR(10), directors TEXT, writers TEXT );
CREATE UNLOGGED TABLE temp_title_principals (
    tconst VARCHAR(10), ordering VARCHAR(10), nconst VARCHAR(10), category VARCHAR(100), job TEXT, characters TEXT
);
CREATE UNLOGGED TABLE temp_title_episode ( tconst VARCHAR(10), parentTconst VARCHAR(10), seasonNumber VARCHAR(10), episodeNumber VARCHAR(10) );
CREATE UNLOGGED TABLE temp_title_akas (
    titleId VARCHAR(10), ordering VARCHAR(10), title TEXT, region VARCHAR(10),
    language VARCHAR(10), types TEXT, attributes TEXT, isOriginalTitle VARCHAR(1)
);