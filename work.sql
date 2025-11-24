CREATE TABLE oscars (
    Ceremony INT,
    Year VARCHAR(20),
    Class TEXT,
    CanonicalCategory TEXT,
    Category TEXT,
    NomId VARCHAR(20) PRIMARY KEY,
    Film VARCHAR(200),
    FilmId VARCHAR(20),
    Name TEXT,
    NomineeIds VARCHAR(150),
    Winner BOOLEAN
);

SELECT * FROM OSCARS;

CREATE TABLE IMDB (
    movie_id VARCHAR(20),
    movie_name VARCHAR(100),
    year INT,
    certificate VARCHAR(100),
    runtime VARCHAR(50),
    genre TEXT,
    rating DECIMAL(2, 1),
    director TEXT,
    director_id VARCHAR(70),
    star VARCHAR(400),
    star_id VARCHAR(1000),
    votes INT,
    gross_in_dollars BIGINT
);

SELECT * FROM IMDB;

CREATE TABLE Ceremonies (
    Ceremony INT,
    Year VARCHAR(20),
    Class TEXT
);

INSERT INTO ceremonies (Ceremony, Year, Class)
SELECT Ceremony, Year, Class
FROM oscars;

SELECT * FROM Ceremonies;

CREATE TABLE Films (
    FilmId VARCHAR(20),
    Film VARCHAR(200),
    Year VARCHAR(20)
);

INSERT INTO Films (FilmId, Film, Year)
SELECT FilmId, Film, Year
FROM oscars
WHERE FilmId IS NOT NULL;

SELECT * FROM Films;

CREATE TABLE Categories (
    Category_id SERIAL PRIMARY KEY,
    Category TEXT,
    CanonicalCategory TEXT
);

INSERT INTO Categories (Category, CanonicalCategory)
SELECT DISTINCT Category, CanonicalCategory
FROM oscars;

SELECT * FROM Categories;

CREATE TABLE Nominees (
    NomineeIds VARCHAR(150),
    Name TEXT,
    Nominee_type VARCHAR(20)
);

INSERT INTO Nominees (NomineeIds, Name, Nominee_type)
SELECT NomineeIds, Name, CASE WHEN Name = Film THEN 'FILM' ELSE 'PERSON' END AS Nominee_type
FROM oscars
WHERE NomineeIds IS NOT NULL;

SELECT * FROM Nominees;

CREATE TABLE Nominations (
    NomId VARCHAR(20) PRIMARY KEY,
    Ceremony INT,
    Category_id INT,
    NomineeIds VARCHAR(150),
    FilmId VARCHAR(20),
    Winner BOOLEAN,
    FOREIGN KEY (Category_id) REFERENCES categories(Category_id)
);

INSERT INTO Nominations (NomId, Ceremony, Category_id, NomineeIds, FilmId, Winner)
SELECT oscars.NomId, oscars.Ceremony, categories.Category_id, oscars.NomineeIds, oscars.FilmId, oscars.Winner
FROM oscars
JOIN categories ON oscars.Category = categories.Category
AND oscars.CanonicalCategory = categories.CanonicalCategory;

SELECT * FROM Nominations;

CREATE TABLE Directors (
    director_id VARCHAR(70) PRIMARY KEY,
    director TEXT
);

INSERT INTO Directors (director_id, director)
SELECT DISTINCT
    trim(director_id_split) AS director_id,
    trim(director_split) AS director
FROM (
    SELECT
        unnest(string_to_array(director, ','))      AS director_split,
        unnest(string_to_array(director_id, ','))   AS director_id_split
    FROM IMDB
) AS sub
WHERE trim(director_id_split) <> ''
  AND trim(director_split) <> ''
ON CONFLICT (director_id) DO NOTHING;

SELECT * FROM Directors;

CREATE TABLE Movie_directors (
    movie_id VARCHAR(20),
    director_id VARCHAR(70),
    PRIMARY KEY (movie_id, director_id)
);

INSERT INTO Movie_directors (movie_id, director_id)
SELECT DISTINCT
    movie_id,
    trim(director_id_split) AS director_id
FROM (
    SELECT
        movie_id,
        unnest(string_to_array(director_id, ',')) AS director_id_split
    FROM IMDB
) AS sub
WHERE trim(director_id_split) <> ''
ON CONFLICT (movie_id, director_id) DO NOTHING;

SELECT * FROM Movie_directors;

CREATE TABLE Stars (
    star_id VARCHAR(200) PRIMARY KEY,
    star TEXT
);

INSERT INTO Stars (star_id, star)
SELECT DISTINCT
    trim(star_id_split) AS star_id,
    trim(star_split) AS star
FROM (
    SELECT
        movie_id,
        unnest(string_to_array(star, ','))      AS star_split,
        unnest(string_to_array(star_id, ','))   AS star_id_split
    FROM IMDB
) AS sub
WHERE trim(star_id_split) <> ''
  AND trim(star_split) <> ''
ON CONFLICT (star_id) DO NOTHING;

SELECT * FROM Stars;

CREATE TABLE Movie_stars (
    movie_id VARCHAR(20),
    star_id VARCHAR(200),
    PRIMARY KEY (movie_id, star_id)
);

INSERT INTO Movie_stars (movie_id, star_id)
SELECT DISTINCT
    movie_id,
    trim(star_id_split) AS star_id
FROM (
    SELECT
        movie_id,
        unnest(string_to_array(star_id, ',')) AS star_id_split
    FROM IMDB
) AS sub
WHERE trim(star_id_split) <> ''
ON CONFLICT (movie_id, star_id) DO NOTHING;

SELECT * FROM Movie_stars;

CREATE TABLE Genres (
    genre_id SERIAL PRIMARY KEY,
    genre TEXT UNIQUE
);

INSERT INTO Genres (genre)
SELECT DISTINCT trim(genre_split)
FROM (
    SELECT unnest(string_to_array(genre, ',')) AS genre_split
    FROM IMDB
) AS sub
WHERE trim(genre_split) <> ''
ON CONFLICT (genre) DO NOTHING;

SELECT * FROM Genres;

CREATE TABLE Movie_genres (
    movie_id VARCHAR(20),
    genre_id INT,
    PRIMARY KEY (movie_id, genre_id)
);

INSERT INTO Movie_genres (movie_id, genre_id)
SELECT DISTINCT IMDB.movie_id, genres.genre_id
FROM IMDB
CROSS JOIN LATERAL unnest(string_to_array(IMDB.genre, ',')) AS genre_split
JOIN genres 
ON trim(genre_split) = genres.genre
ON CONFLICT (movie_id, genre_id) DO NOTHING;

SELECT * FROM Movie_genres;

CREATE TABLE Imdb_movies (
    movie_id VARCHAR(20) PRIMARY KEY,
	movie_name VARCHAR(100),
    certificate VARCHAR(100),
    runtime VARCHAR(50),
    rating DECIMAL(2,1),
    votes INT,
    gross_in_dollars BIGINT
);

INSERT INTO imdb_movies (movie_id, movie_name, certificate, runtime, rating, votes, gross_in_dollars)
SELECT DISTINCT movie_id, movie_name, certificate, runtime, rating, votes, gross_in_dollars
FROM IMDB
ON CONFLICT (movie_id) DO NOTHING;

SELECT * FROM Imdb_movies;









--Joining Tables--
SELECT films.film, imdb_movies.rating
FROM films
LEFT JOIN imdb_movies ON films.filmid = imdb_movies.movie_id;

SELECT ceremonies.ceremony, ceremonies.year, ceremonies.class, nominations.nomid, nominations.winner
FROM ceremonies
LEFT JOIN nominations ON ceremonies.ceremony = nominations.ceremony
ORDER BY ceremonies.ceremony;

SELECT categories.category, categories.canonicalcategory, nominations.nomid, nominations.winner
FROM categories
LEFT JOIN nominations ON categories.category_id = nominations.category_id;

SELECT nominees.name, nominees.nominee_type, nominations.nomid, nominations.winner
FROM nominees
LEFT JOIN nominations ON nominees.nomineeids = nominations.nomineeids;

SELECT DISTINCT films.film, films.year, categories.category, nominations.nomid, nominations.winner
FROM films
LEFT JOIN nominations ON films.filmid = nominations.filmid
LEFT JOIN categories ON nominations.category_id = categories.category_id
ORDER BY films.film;

SELECT imdb_movies.movie_id, imdb_movies.movie_name, directors.director
FROM imdb_movies
JOIN movie_directors ON imdb_movies.movie_id = movie_directors.movie_id
JOIN directors ON movie_directors.director_id = directors.director_id
ORDER BY imdb_movies.movie_name;

SELECT directors.director_id, directors.director, imdb_movies.movie_name
FROM movie_directors
JOIN directors ON movie_directors.director_id = directors.director_id
JOIN imdb_movies ON movie_directors.movie_id = imdb_movies.movie_id
ORDER BY directors.director;

SELECT imdb_movies.movie_id, imdb_movies.movie_name, stars.star
FROM imdb_movies
JOIN movie_stars ON imdb_movies.movie_id = movie_stars.movie_id
JOIN stars ON movie_stars.star_id = stars.star_id
ORDER BY imdb_movies.movie_name;

SELECT stars.star_id, stars.star, imdb_movies.movie_name
FROM movie_stars
JOIN stars ON movie_stars.star_id = stars.star_id
JOIN imdb_movies ON movie_stars.movie_id = imdb_movies.movie_id
ORDER BY stars.star;

SELECT imdb_movies.movie_id, imdb_movies.movie_name, genres.genre
FROM imdb_movies
JOIN movie_genres ON imdb_movies.movie_id = movie_genres.movie_id
JOIN genres ON movie_genres.genre_id = genres.genre_id
ORDER BY imdb_movies.movie_name;

SELECT genres.genre_id, genres.genre, imdb_movies.movie_name
FROM movie_genres
JOIN genres ON movie_genres.genre_id = genres.genre_id
JOIN imdb_movies ON movie_genres.movie_id = imdb_movies.movie_id
ORDER BY genres.genre;









--Query 1--
INSERT INTO imdb_movies (movie_id, movie_name, certificate, runtime, rating, votes, gross_in_dollars)
VALUES ('tt9999999', 'Sample Test Movie', 'PG-13', '120 min', 8.5, 120000, 50000000);

--Query 2--
INSERT INTO directors (director_id, director)
VALUES ('nm9999999', 'Test Director');

INSERT INTO movie_directors (movie_id, director_id)
VALUES ('tt9999999', 'nm9999999');

--Query 3--
UPDATE imdb_movies
SET rating = 9.1
WHERE movie_id = 'tt9999999';

--Query 4--
UPDATE nominees
SET name = 'Updated Nominee Name'
WHERE nomineeids = 'nm0001932';

--Query 5--
DELETE FROM movie_stars
WHERE movie_id = 'tt9999999'AND star_id = 'nm0000000';

--Query 6--
DELETE FROM imdb_movies
WHERE movie_id = 'tt9999999';

--Query 7-- List Oscar nominations for each film
SELECT DISTINCT films.film, films.year, categories.category, nominations.winner
FROM films
JOIN nominations ON films.filmid = nominations.filmid
JOIN categories ON nominations.category_id = categories.category_id
ORDER BY films.film, categories.category;

--Query 8-- List IMDb movies with their directors
SELECT imdb_movies.movie_name, directors.director
FROM imdb_movies
JOIN movie_directors ON imdb_movies.movie_id = movie_directors.movie_id
JOIN directors ON movie_directors.director_id = directors.director_id
ORDER BY imdb_movies.movie_name;

--Query 9-- Count Oscar nominations per film
SELECT films.film, COUNT(nominations.nomid) AS total_nominations
FROM films
LEFT JOIN nominations ON films.filmid = nominations.filmid
GROUP BY films.film
ORDER BY total_nominations DESC;

--Query 10-- Count Oscar wins per year
SELECT ceremonies.year, COUNT(nominations.winner) AS wins
FROM ceremonies
JOIN nominations ON ceremonies.ceremony = nominations.ceremony
WHERE nominations.winner = TRUE
GROUP BY ceremonies.year
ORDER BY wins DESC;

--Query 11-- Top-rated IMDb movies that were Oscar nominated
SELECT DISTINCT imdb_movies.movie_name, imdb_movies.rating
FROM imdb_movies
JOIN films ON imdb_movies.movie_id = films.filmid
ORDER BY imdb_movies.rating DESC;

--Query 12-- Find movies with more than one director
SELECT DISTINCT imdb_movies.movie_name, COUNT(movie_directors.director_id) AS director_count
FROM imdb_movies
JOIN movie_directors ON imdb_movies.movie_id = movie_directors.movie_id
GROUP BY imdb_movies.movie_name
HAVING COUNT(movie_directors.director_id) > 1;

--Query 13-- Get all stars who acted in Oscar-winning films
SELECT DISTINCT stars.star
FROM stars
JOIN movie_stars ON stars.star_id = movie_stars.star_id
JOIN nominations ON movie_stars.movie_id = nominations.filmid
WHERE nominations.winner = TRUE;

--Query 14-- Subquery: Movies with rating above IMDb average
SELECT movie_name, rating
FROM imdb_movies
WHERE rating > (
    SELECT AVG(rating) FROM imdb_movies
)
ORDER BY rating DESC;

--Query 15-- Most common Oscar category
SELECT categories.category, COUNT(*) AS nomination_count
FROM nominations
JOIN categories ON nominations.category_id = categories.category_id
GROUP BY categories.category
ORDER BY nomination_count DESC;









--Procedure: Add a new IMDb movie--
CREATE OR REPLACE PROCEDURE add_imdb_movie(
    p_movie_id VARCHAR,
    p_movie_name VARCHAR,
    p_certificate VARCHAR,
    p_runtime VARCHAR,
    p_rating DECIMAL,
    p_votes INT,
    p_gross BIGINT
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO imdb_movies(movie_id, movie_name, certificate, runtime, rating, votes, gross_in_dollars)
    VALUES (p_movie_id, p_movie_name, p_certificate, p_runtime, p_rating, p_votes, p_gross);
END;
$$;

CALL add_imdb_movie('tt9900000', 'Inserting a Movie', 'PG', '100 min', 7.8, 40000, 12000000);

SELECT * FROM imdb_movies WHERE movie_id = 'tt9900000';


--Procedure: Update movie rating (IMDb)--
CREATE OR REPLACE PROCEDURE update_movie_rating(
    p_movie_id VARCHAR,
    p_new_rating DECIMAL
)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE imdb_movies
    SET rating = p_new_rating
    WHERE movie_id = p_movie_id;
END;
$$;

CALL update_movie_rating('tt9900000', 9.2);

SELECT movie_id, movie_name, rating 
FROM imdb_movies 
WHERE movie_id = 'tt9900000';


--Procedure: Delete a star from a movie--
CREATE OR REPLACE PROCEDURE remove_star_from_movie(
    p_movie_id VARCHAR,
    p_star_id VARCHAR
)
LANGUAGE plpgsql
AS $$
BEGIN
    DELETE FROM movie_stars
    WHERE movie_id = p_movie_id
      AND star_id = p_star_id;
END;
$$;

CALL remove_star_from_movie('tt0468569', 'nm0000288');

SELECT * FROM movie_stars 
WHERE movie_id = 'tt0468569' AND star_id = 'nm0000288';


--Procedure: Add a nominee (Oscar person/film)--
CREATE OR REPLACE PROCEDURE add_nominee(
    p_nominee_id VARCHAR,
    p_name TEXT,
    p_type VARCHAR
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO nominees(nomineeids, name, nominee_type)
    VALUES(p_nominee_id, p_name, p_type);
END;
$$;

CALL add_nominee('nm9900000', 'New Nominee', 'PERSON');

SELECT * FROM nominees WHERE nomineeids = 'nm9900000';









--Function: Count nominations for a film--
CREATE OR REPLACE FUNCTION get_nomination_count(p_film_id VARCHAR)
RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
    total INT;
BEGIN
    SELECT COUNT(*) INTO total
    FROM nominations
    WHERE filmid = p_film_id;

    RETURN total;
END;
$$;

SELECT get_nomination_count('tt0034583');


--Function: Get all films directed by a director--
CREATE OR REPLACE FUNCTION get_movies_by_director(p_director_id VARCHAR)
RETURNS TABLE(movie_id VARCHAR, movie_name VARCHAR)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT imdb_movies.movie_id, imdb_movies.movie_name
    FROM movie_directors
    JOIN imdb_movies ON movie_directors.movie_id = imdb_movies.movie_id
    WHERE movie_directors.director_id = p_director_id;
END;
$$;

SELECT * 
FROM get_movies_by_director((SELECT director_id FROM movie_directors LIMIT 1));


--Function: Get all stars in an IMDb movie--
CREATE OR REPLACE FUNCTION get_movie_stars(p_movie_id VARCHAR)
RETURNS TABLE(star_id VARCHAR, star_name TEXT)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT stars.star_id, stars.star
    FROM movie_stars
    JOIN stars ON movie_stars.star_id = stars.star_id
    WHERE movie_stars.movie_id = p_movie_id;
END;
$$;

SELECT * FROM get_movie_stars('tt0468569');


--Function: List Oscar-winning films (Film + Category)--
CREATE OR REPLACE FUNCTION get_oscar_winners()
RETURNS TABLE(film VARCHAR(200), category TEXT)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT films.film, categories.category
    FROM nominations
    JOIN films ON nominations.filmid = films.filmid
    JOIN categories ON nominations.category_id = categories.category_id
    WHERE nominations.winner = TRUE;
END;
$$;

SELECT DISTINCT * FROM get_oscar_winners();









--Transaction Log--
CREATE TABLE transaction_log (
    log_id SERIAL PRIMARY KEY,
    action TEXT,
    status TEXT,
    error_message TEXT,
    log_time TIMESTAMP DEFAULT NOW()
);

--Creating a function for failure--
CREATE OR REPLACE FUNCTION prevent_movie_deletion()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM nominations WHERE filmid = OLD.filmid) THEN
        INSERT INTO transaction_log(action, status, error_message)
        VALUES ('DELETE MOVIE', 'FAILED', 'Movie has oscar nominations — deletion cannot be performed');
        RETURN NULL;
    END IF;
    RETURN OLD;
END;
$$;

--Failure Trigger--
CREATE TRIGGER trigger_prevent_delete
BEFORE DELETE ON films
FOR EACH ROW
EXECUTE FUNCTION prevent_movie_deletion();

--Demo--
BEGIN;
DELETE FROM films
WHERE filmid = 'tt0034583';

SELECT DISTINCT * FROM transaction_log ORDER BY log_id DESC;









--Creating a function for success--
CREATE OR REPLACE FUNCTION allow_movie_insertion()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO transaction_log(action, status, error_message)
    VALUES ('INSERT MOVIE', 'SUCCESS', NULL);

    RETURN NEW;
END;
$$;


--Success Trigger--
CREATE TRIGGER trigger_allow_insert
AFTER INSERT ON imdb_movies
FOR EACH ROW
EXECUTE FUNCTION allow_movie_insertion();

--Demo--
BEGIN;
INSERT INTO imdb_movies(movie_id, movie_name, certificate, runtime, rating, votes, gross_in_dollars)
VALUES ('tt9870000', 'Trigger Test Movie', 'PG', '110 min', 8.1, 90000, 35000000);

SELECT * FROM transaction_log ORDER BY log_id DESC;









--Indexing and query execution--

--Query 1 - Count Oscar Nominations per Film--
EXPLAIN ANALYZE
SELECT films.film, COUNT(nominations.nomid) AS total_nominations
FROM films
LEFT JOIN nominations ON films.filmid = nominations.filmid
GROUP BY films.film
ORDER BY total_nominations DESC;

CREATE INDEX idx_films_filmid ON films(filmid);
CREATE INDEX idx_nominations_filmid ON nominations(filmid);

EXPLAIN ANALYZE
SELECT films.film, COUNT(nominations.nomid) AS total_nominations
FROM films
LEFT JOIN nominations ON films.filmid = nominations.filmid
GROUP BY films.film
ORDER BY total_nominations DESC;

DROP INDEX idx_films_filmid;
DROP INDEX idx_nominations_filmid;



--Query 2 - IMDb Movies + Directors--
EXPLAIN ANALYZE
SELECT imdb_movies.movie_name, directors.director
FROM imdb_movies
JOIN movie_directors ON imdb_movies.movie_id = movie_directors.movie_id
JOIN directors ON movie_directors.director_id = directors.director_id;

CREATE INDEX idx_imdb_movies_movieid ON imdb_movies(movie_id);
CREATE INDEX idx_movie_directors_movieid ON movie_directors(movie_id);
CREATE INDEX idx_movie_directors_directorid ON movie_directors(director_id);
CREATE INDEX idx_directors_directorid ON directors(director_id);

EXPLAIN ANALYZE
SELECT imdb_movies.movie_name, directors.director
FROM imdb_movies
JOIN movie_directors ON imdb_movies.movie_id = movie_directors.movie_id
JOIN directors ON movie_directors.director_id = directors.director_id;

DROP INDEX idx_imdb_movies_movieid;
DROP INDEX idx_movie_directors_movieid;
DROP INDEX idx_movie_directors_directorid;
DROP INDEX idx_directors_directorid;



--Query 3 - Getting stars acting in oscar winning films--
EXPLAIN ANALYZE
SELECT DISTINCT stars.star
FROM stars
JOIN movie_stars ON stars.star_id = movie_stars.star_id
JOIN nominations ON movie_stars.movie_id = nominations.filmid
WHERE nominations.winner = TRUE;

CREATE INDEX idx_stars_starid ON stars(star_id);
CREATE INDEX idx_movie_stars_movieid ON movie_stars(movie_id);
CREATE INDEX idx_movie_stars_starid ON movie_stars(star_id);
CREATE INDEX idx_nominations_winner ON nominations(winner);

EXPLAIN ANALYZE
SELECT DISTINCT stars.star
FROM stars
JOIN movie_stars ON stars.star_id = movie_stars.star_id
JOIN nominations ON movie_stars.movie_id = nominations.filmid
WHERE nominations.winner = TRUE;

DROP INDEX idx_stars_starid;
DROP INDEX idx_movie_stars_movieid;
DROP INDEX idx_movie_stars_starid;
DROP INDEX idx_nominations_winner;
