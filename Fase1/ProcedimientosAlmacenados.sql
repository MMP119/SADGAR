-- =======================================================
-- FUNCIÓN 1: OBTENER LA INFORMACIÓN PRINCIPAL DE UN DIRECTOR
-- Devuelve una tabla con los datos biográficos y el total de películas.
-- =======================================================
CREATE OR REPLACE FUNCTION get_director_info(p_director_name VARCHAR(200))
RETURNS TABLE(
    nconst VARCHAR(10),
    primary_name TEXT,
    birth_year SMALLINT,
    death_year SMALLINT,
    total_movies BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        p.nconst,
        p.primary_name,
        p.birth_year,
        p.death_year,
        COUNT(DISTINCT t.tconst) AS total_movies
    FROM people p
    JOIN title_crew tc ON p.nconst = tc.nconst
    JOIN titles t ON tc.tconst = t.tconst
    WHERE p.primary_name = p_director_name
      AND tc.crew_type = 'director'
      AND t.title_type IN ('movie', 'tvMovie')
    GROUP BY p.nconst, p.primary_name, p.birth_year, p.death_year;
END;
$$ LANGUAGE plpgsql;

-- =======================================================
-- FUNCIÓN 2: OBTENER LAS PELÍCULAS DE UN DIRECTOR
-- Devuelve una tabla con la lista de películas, su rating y géneros.
-- =======================================================
CREATE OR REPLACE FUNCTION get_director_movies(p_director_name VARCHAR(200))
RETURNS TABLE(
    tconst VARCHAR(10),
    primary_title TEXT,
    start_year SMALLINT,
    runtime_minutes INTEGER,
    average_rating DECIMAL(3,1),
    num_votes BIGINT,
    genres TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        t.tconst,
        t.primary_title,
        t.start_year,
        t.runtime_minutes,
        r.average_rating,
        r.num_votes,
        -- CORRECCIÓN: Se ha eliminado DISTINCT para resolver el error de ordenamiento.
        STRING_AGG(g.genre_name, ', ' ORDER BY tg.genre_order) AS genres
    FROM people p
    JOIN title_crew tc ON p.nconst = tc.nconst
    JOIN titles t ON tc.tconst = t.tconst
    LEFT JOIN ratings r ON t.tconst = r.tconst
    LEFT JOIN title_genres tg ON t.tconst = tg.tconst
    LEFT JOIN genres g ON tg.genre_id = g.genre_id
    WHERE p.primary_name = p_director_name
      AND tc.crew_type = 'director'
      AND t.title_type IN ('movie', 'tvMovie')
    GROUP BY t.tconst, t.primary_title, t.start_year, t.runtime_minutes, r.average_rating, r.num_votes
    ORDER BY t.start_year DESC, r.average_rating DESC;
END;
$$ LANGUAGE plpgsql;



-- PRUEBAS 

-- Para obtener la información principal de Christopher Nolan
SELECT * FROM get_director_info('Christopher Nolan');

-- Para obtener la lista de sus películas
SELECT * FROM get_director_movies('Christopher Nolan');

