-- =====================================================================
-- DATOS DE PRUEBA PARA SISTEMA DE BACKUPS
-- Plan: 6 días con inserts incrementales
-- =====================================================================

-- =====================================================================
-- DÍA 1: DATOS INICIALES (Géneros y Categorías)
-- =====================================================================

-- Géneros base
INSERT INTO genres (genre_name, description) VALUES
    ('Action', 'Películas de acción y aventura'),
    ('Drama', 'Películas dramáticas'),
    ('Comedy', 'Películas de comedia'),
    ('Thriller', 'Películas de suspenso'),
    ('Horror', 'Películas de terror'),
    ('Sci-Fi', 'Ciencia ficción'),
    ('Romance', 'Películas románticas'),
    ('Documentary', 'Documentales'),
    ('Animation', 'Películas animadas'),
    ('Crime', 'Películas de crimen')
ON CONFLICT (genre_name) DO NOTHING;

-- Categorías base
INSERT INTO categories (category_name, description) VALUES
    ('actor', 'Actor/Actriz principal'),
    ('actress', 'Actriz'),
    ('director', 'Director'),
    ('writer', 'Escritor/Guionista'),
    ('producer', 'Productor'),
    ('cinematographer', 'Director de fotografía'),
    ('composer', 'Compositor musical'),
    ('editor', 'Editor'),
    ('self', 'Aparece como él/ella mismo'),
    ('archive_footage', 'Imágenes de archivo')
ON CONFLICT (category_name) DO NOTHING;

-- Verificar: SELECT count(*) FROM genres; SELECT count(*) FROM categories;

-- =====================================================================
-- DÍA 2: PELÍCULAS INICIALES Y PERSONAS
-- =====================================================================

-- Personas (directores y actores famosos)
INSERT INTO people (nconst, primary_name, birth_year, death_year) VALUES
    ('nm0000001', 'Christopher Nolan', 1970, NULL),
    ('nm0000002', 'Leonardo DiCaprio', 1974, NULL),
    ('nm0000003', 'Tom Hardy', 1977, NULL),
    ('nm0000004', 'Quentin Tarantino', 1963, NULL),
    ('nm0000005', 'Samuel L. Jackson', 1948, NULL)
ON CONFLICT (nconst) DO NOTHING;

-- Películas famosas
INSERT INTO titles (tconst, title_type, primary_title, original_title, is_adult, start_year, runtime_minutes) VALUES
    ('tt0468569', 'movie', 'The Dark Knight', 'The Dark Knight', false, 2008, 152),
    ('tt1375666', 'movie', 'Inception', 'Inception', false, 2010, 148),
    ('tt0110912', 'movie', 'Pulp Fiction', 'Pulp Fiction', false, 1994, 154)
ON CONFLICT (tconst) DO NOTHING;

-- Ratings de las películas
INSERT INTO ratings (tconst, average_rating, num_votes) VALUES
    ('tt0468569', 9.0, 2500000),
    ('tt1375666', 8.8, 2300000),
    ('tt0110912', 8.9, 2000000)
ON CONFLICT (tconst) DO NOTHING;

-- Verificar: SELECT count(*) FROM people; SELECT count(*) FROM titles; SELECT count(*) FROM ratings;

-- =====================================================================
-- DÍA 3: MÁS PELÍCULAS Y RELACIONES TÍTULO-GÉNERO
-- =====================================================================

-- Más personas
INSERT INTO people (nconst, primary_name, birth_year, death_year) VALUES
    ('nm0000006', 'Martin Scorsese', 1942, NULL),
    ('nm0000007', 'Robert De Niro', 1943, NULL),
    ('nm0000008', 'Al Pacino', 1940, NULL),
    ('nm0000009', 'Meryl Streep', 1949, NULL),
    ('nm0000010', 'Tom Hanks', 1956, NULL)
ON CONFLICT (nconst) DO NOTHING;

-- Más películas clásicas
INSERT INTO titles (tconst, title_type, primary_title, original_title, is_adult, start_year, runtime_minutes) VALUES
    ('tt0111161', 'movie', 'The Shawshank Redemption', 'The Shawshank Redemption', false, 1994, 142),
    ('tt0068646', 'movie', 'The Godfather', 'The Godfather', false, 1972, 175),
    ('tt0071562', 'movie', 'The Godfather Part II', 'The Godfather Part II', false, 1974, 202)
ON CONFLICT (tconst) DO NOTHING;

-- Ratings adicionales
INSERT INTO ratings (tconst, average_rating, num_votes) VALUES
    ('tt0111161', 9.3, 2700000),
    ('tt0068646', 9.2, 1800000),
    ('tt0071562', 9.0, 1300000)
ON CONFLICT (tconst) DO NOTHING;

-- Relaciones título-género (asignar géneros a las películas)
INSERT INTO title_genres (tconst, genre_id, genre_order) VALUES
    -- The Dark Knight: Action, Thriller, Crime
    ('tt0468569', (SELECT genre_id FROM genres WHERE genre_name = 'Action'), 1),
    ('tt0468569', (SELECT genre_id FROM genres WHERE genre_name = 'Thriller'), 2),
    ('tt0468569', (SELECT genre_id FROM genres WHERE genre_name = 'Crime'), 3),
    -- Inception: Action, Sci-Fi, Thriller
    ('tt1375666', (SELECT genre_id FROM genres WHERE genre_name = 'Action'), 1),
    ('tt1375666', (SELECT genre_id FROM genres WHERE genre_name = 'Sci-Fi'), 2),
    ('tt1375666', (SELECT genre_id FROM genres WHERE genre_name = 'Thriller'), 3),
    -- Pulp Fiction: Crime, Drama
    ('tt0110912', (SELECT genre_id FROM genres WHERE genre_name = 'Crime'), 1),
    ('tt0110912', (SELECT genre_id FROM genres WHERE genre_name = 'Drama'), 2),
    -- The Shawshank Redemption: Drama
    ('tt0111161', (SELECT genre_id FROM genres WHERE genre_name = 'Drama'), 1),
    -- The Godfather: Crime, Drama
    ('tt0068646', (SELECT genre_id FROM genres WHERE genre_name = 'Crime'), 1),
    ('tt0068646', (SELECT genre_id FROM genres WHERE genre_name = 'Drama'), 2),
    -- The Godfather Part II: Crime, Drama
    ('tt0071562', (SELECT genre_id FROM genres WHERE genre_name = 'Crime'), 1),
    ('tt0071562', (SELECT genre_id FROM genres WHERE genre_name = 'Drama'), 2)
ON CONFLICT DO NOTHING;

-- Verificar: SELECT count(*) FROM title_genres;

-- =====================================================================
-- DÍA 4: CREW Y PRINCIPALS (Directores, Escritores, Cast)
-- =====================================================================

-- Directores y escritores
INSERT INTO title_crew (tconst, nconst, crew_type) VALUES
    ('tt0468569', 'nm0000001', 'director'),  -- Christopher Nolan dirigió The Dark Knight
    ('tt1375666', 'nm0000001', 'director'),  -- Christopher Nolan dirigió Inception
    ('tt1375666', 'nm0000001', 'writer'),    -- Christopher Nolan escribió Inception
    ('tt0110912', 'nm0000004', 'director'),  -- Tarantino dirigió Pulp Fiction
    ('tt0110912', 'nm0000004', 'writer'),    -- Tarantino escribió Pulp Fiction
    ('tt0068646', 'nm0000006', 'director'),  -- Scorsese dirigió The Godfather
    ('tt0071562', 'nm0000006', 'director')   -- Scorsese dirigió The Godfather Part II
ON CONFLICT DO NOTHING;

-- Cast principal (actores en las películas)
INSERT INTO title_principals (tconst, ordering, nconst, category_id, job, characters) VALUES
    -- Inception
    ('tt1375666', 1, 'nm0000002', (SELECT category_id FROM categories WHERE category_name = 'actor'), NULL, '["Dom Cobb"]'),
    ('tt1375666', 2, 'nm0000003', (SELECT category_id FROM categories WHERE category_name = 'actor'), NULL, '["Eames"]'),
    -- Pulp Fiction
    ('tt0110912', 1, 'nm0000005', (SELECT category_id FROM categories WHERE category_name = 'actor'), NULL, '["Jules Winnfield"]'),
    -- The Godfather
    ('tt0068646', 1, 'nm0000007', (SELECT category_id FROM categories WHERE category_name = 'actor'), NULL, '["Vito Corleone"]'),
    -- The Godfather Part II
    ('tt0071562', 1, 'nm0000008', (SELECT category_id FROM categories WHERE category_name = 'actor'), NULL, '["Michael Corleone"]'),
    ('tt0071562', 2, 'nm0000007', (SELECT category_id FROM categories WHERE category_name = 'actor'), NULL, '["Vito Corleone"]')
ON CONFLICT DO NOTHING;

-- Verificar: SELECT count(*) FROM title_crew; SELECT count(*) FROM title_principals;

-- =====================================================================
-- DÍA 5: SERIES DE TV Y EPISODIOS
-- =====================================================================

-- Series de TV
INSERT INTO titles (tconst, title_type, primary_title, original_title, is_adult, start_year, end_year, runtime_minutes) VALUES
    ('tt0944947', 'tvseries', 'Game of Thrones', 'Game of Thrones', false, 2011, 2019, 57),
    ('tt0903747', 'tvseries', 'Breaking Bad', 'Breaking Bad', false, 2008, 2013, 49),
    ('tt0108778', 'tvseries', 'Friends', 'Friends', false, 1994, 2004, 22)
ON CONFLICT (tconst) DO NOTHING;

-- Ratings de las series
INSERT INTO ratings (tconst, average_rating, num_votes) VALUES
    ('tt0944947', 9.2, 2000000),
    ('tt0903747', 9.5, 1900000),
    ('tt0108778', 8.9, 1000000)
ON CONFLICT (tconst) DO NOTHING;

-- Títulos de episodios (deben insertarse primero en titles)
INSERT INTO titles (tconst, title_type, primary_title, original_title, is_adult, start_year, runtime_minutes) VALUES
    ('tt1480055', 'tvepisode', 'Winter Is Coming', 'Winter Is Coming', false, 2011, 62),
    ('tt3866862', 'tvepisode', 'The Long Night', 'The Long Night', false, 2019, 82),
    ('tt0959621', 'tvepisode', 'Pilot', 'Pilot', false, 2008, 58)
ON CONFLICT (tconst) DO NOTHING;

-- Episodios (relación con series padres)
INSERT INTO episodes (episode_tconst, parent_tconst, season_number, episode_number) VALUES
    ('tt1480055', 'tt0944947', 1, 1),  -- GoT S01E01
    ('tt3866862', 'tt0944947', 8, 3),  -- GoT S08E03
    ('tt0959621', 'tt0903747', 1, 1)   -- Breaking Bad S01E01
ON CONFLICT (episode_tconst) DO NOTHING;

-- Géneros para las series
INSERT INTO title_genres (tconst, genre_id, genre_order) VALUES
    ('tt0944947', (SELECT genre_id FROM genres WHERE genre_name = 'Action'), 1),
    ('tt0944947', (SELECT genre_id FROM genres WHERE genre_name = 'Drama'), 2),
    ('tt0903747', (SELECT genre_id FROM genres WHERE genre_name = 'Crime'), 1),
    ('tt0903747', (SELECT genre_id FROM genres WHERE genre_name = 'Drama'), 2),
    ('tt0903747', (SELECT genre_id FROM genres WHERE genre_name = 'Thriller'), 3),
    ('tt0108778', (SELECT genre_id FROM genres WHERE genre_name = 'Comedy'), 1),
    ('tt0108778', (SELECT genre_id FROM genres WHERE genre_name = 'Romance'), 2)
ON CONFLICT DO NOTHING;

-- Verificar: SELECT count(*) FROM episodes;

-- =====================================================================
-- DÍA 6: DATOS FINALES Y ACTUALIZACIONES
-- =====================================================================

-- Más personas (actores de las series)
INSERT INTO people (nconst, primary_name, birth_year, death_year) VALUES
    ('nm0000011', 'Bryan Cranston', 1956, NULL),
    ('nm0000012', 'Aaron Paul', 1979, NULL),
    ('nm0000013', 'Peter Dinklage', 1969, NULL),
    ('nm0000014', 'Emilia Clarke', 1986, NULL),
    ('nm0000015', 'Jennifer Aniston', 1969, NULL),
    ('nm0000016', 'Courteney Cox', 1964, NULL),
    ('nm0000017', 'Kit Harington', 1986, NULL),
    ('nm0000018', 'Matthew Perry', 1969, 2023)
ON CONFLICT (nconst) DO NOTHING;

-- Cast de las series
INSERT INTO title_principals (tconst, ordering, nconst, category_id, job, characters) VALUES
    -- Breaking Bad
    ('tt0903747', 1, 'nm0000011', (SELECT category_id FROM categories WHERE category_name = 'actor'), NULL, '["Walter White"]'),
    ('tt0903747', 2, 'nm0000012', (SELECT category_id FROM categories WHERE category_name = 'actor'), NULL, '["Jesse Pinkman"]'),
    -- Game of Thrones
    ('tt0944947', 1, 'nm0000013', (SELECT category_id FROM categories WHERE category_name = 'actor'), NULL, '["Tyrion Lannister"]'),
    ('tt0944947', 2, 'nm0000014', (SELECT category_id FROM categories WHERE category_name = 'actress'), NULL, '["Daenerys Targaryen"]'),
    ('tt0944947', 3, 'nm0000017', (SELECT category_id FROM categories WHERE category_name = 'actor'), NULL, '["Jon Snow"]'),
    -- Friends
    ('tt0108778', 1, 'nm0000015', (SELECT category_id FROM categories WHERE category_name = 'actress'), NULL, '["Rachel Green"]'),
    ('tt0108778', 2, 'nm0000016', (SELECT category_id FROM categories WHERE category_name = 'actress'), NULL, '["Monica Geller"]'),
    ('tt0108778', 3, 'nm0000018', (SELECT category_id FROM categories WHERE category_name = 'actor'), NULL, '["Chandler Bing"]')
ON CONFLICT DO NOTHING;

-- Actualizar algunos ratings para simular cambios con el tiempo
UPDATE ratings SET average_rating = 9.1, num_votes = 2550000 WHERE tconst = 'tt0468569';
UPDATE ratings SET average_rating = 9.6, num_votes = 1950000 WHERE tconst = 'tt0903747';
UPDATE ratings SET num_votes = 2750000 WHERE tconst = 'tt0111161';
UPDATE ratings SET average_rating = 9.0, num_votes = 1050000 WHERE tconst = 'tt0108778';

-- Insertar más géneros para películas que faltaban
INSERT INTO title_genres (tconst, genre_id, genre_order) VALUES
    ('tt0468569', (SELECT genre_id FROM genres WHERE genre_name = 'Drama'), 4)
ON CONFLICT DO NOTHING;

-- Verificar totales finales
-- SELECT 'titles' as tabla, count(*) as total FROM titles
-- UNION ALL SELECT 'people', count(*) FROM people
-- UNION ALL SELECT 'ratings', count(*) FROM ratings
-- UNION ALL SELECT 'genres', count(*) FROM genres
-- UNION ALL SELECT 'categories', count(*) FROM categories
-- UNION ALL SELECT 'title_genres', count(*) FROM title_genres
-- UNION ALL SELECT 'title_principals', count(*) FROM title_principals
-- UNION ALL SELECT 'title_crew', count(*) FROM title_crew
-- UNION ALL SELECT 'episodes', count(*) FROM episodes;

-- =====================================================================
-- RESUMEN DE DATOS INSERTADOS
-- =====================================================================
-- Día 1: 10 géneros + 10 categorías = 20 registros
-- Día 2: 5 personas + 3 películas + 3 ratings = 11 registros
-- Día 3: 5 personas + 3 películas + 3 ratings + 13 title_genres = 24 registros
-- Día 4: 7 title_crew + 6 title_principals = 13 registros
-- Día 5: 3 series + 3 episodios + 3 ratings + 3 títulos episodios + 7 title_genres = 19 registros
-- Día 6: 8 personas + 8 principals + 4 updates + 1 title_genre = 21 registros
-- TOTAL: ~108 registros distribuidos en 6 días
-- =====================================================================
