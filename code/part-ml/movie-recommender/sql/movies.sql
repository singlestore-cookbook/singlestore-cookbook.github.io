CREATE DATABASE IF NOT EXISTS movies_db;

USE movies_db;

DROP TABLE IF EXISTS users;
CREATE TABLE users (
    id INT PRIMARY KEY,
    age INT,
    gender VARCHAR(5),
    occupation VARCHAR(255),
    zip_code VARCHAR(255),
    factors VECTOR(200)
);

DROP TABLE IF EXISTS movies;
CREATE TABLE movies (
    id INT PRIMARY KEY,
    title VARCHAR(255),
    genres VARCHAR(255),
    factors VECTOR(200)
);

DROP TABLE IF EXISTS ratings;
CREATE TABLE ratings (
    user_id INT,
    movie_id INT,
    rating FLOAT,
    timestamp INT
);

-- Compute similarity between a user and a movie
SELECT
    u.id AS user_id,
    m.title,
    (u.factors <*> m.factors) AS similarity_score
FROM users u, movies m
WHERE u.id = 1 AND m.id = 989;

-- Find top movies for a user based on similarity
SELECT
    m.title,
    m.genres,
    (u.factors <*> m.factors) AS similarity_score
FROM users u, movies m
WHERE u.id = 1
ORDER BY similarity_score DESC
LIMIT 10;

-- Calculate similarity matrix between users and movies
SELECT
    u.id AS user_id,
    m.title,
    (u.factors <*> m.factors) AS similarity_score
FROM users u, movies m
ORDER BY similarity_score DESC
LIMIT 10;

-- Recommend top movies for each user
SELECT
    u.id AS user_id,
    m.title,
    (u.factors <*> m.factors) AS similarity_score
FROM users u, movies m
ORDER BY u.id, similarity_score DESC
LIMIT 10;

-- Top-N movies for a given user, excluding already-rated movies
SELECT
    m.id,
    m.title,
    m.genres,
    (u.factors <*> m.factors) AS predicted_rating
FROM users u
JOIN movies m ON TRUE
WHERE u.id = 1
  AND m.id NOT IN (SELECT movie_id FROM ratings WHERE user_id = u.id)
ORDER BY predicted_rating DESC
LIMIT 10;

-- Top movies predicted ratings
SELECT
    m.title,
    m.genres,
    (m.factors <*> u.factors) AS predicted_rating
FROM movies m, users u
WHERE u.gender = 'F' AND u.age = 18
ORDER BY predicted_rating DESC
LIMIT 10;

-- Find Movies Similar to Computer Whisper
SELECT
    m.title,
    (m.factors <*> qv.factors) AS similarity_score
FROM movies m,
    (SELECT factors AS factors FROM movies WHERE id = 2) AS qv -- Computer Whisper
ORDER BY similarity_score DESC
LIMIT 10;

-- Find users similar to Computer Whisper
SELECT
    u.gender,
    u.age,
    u.occupation,
    u.zip_code,
    (m.factors <*> u.factors) AS similarity_score
FROM movies m, users u
WHERE m.id = 2 -- Computer Whisper
ORDER BY similarity_score DESC
LIMIT 10;

-- Find the most similar users to a given user
SELECT
    u2.id AS other_user_id,
    (u1.factors <*> u2.factors) AS similarity_score
FROM users u1
JOIN users u2 ON u1.id <> u2.id
WHERE u1.id = 1
ORDER BY similarity_score DESC
LIMIT 10;

-- User activity overview
SELECT
    u.gender,
    u.age,
    COUNT(r.rating) AS num_ratings,
    AVG(r.rating) AS avg_rating
FROM users u
LEFT JOIN ratings r ON u.id = r.user_id
GROUP BY u.gender, u.age
ORDER BY u.gender, u.age;

-- Most active users
SELECT
    u.id,
    u.gender,
    u.age,
    COUNT(r.rating) AS num_ratings
FROM users u
LEFT JOIN ratings r ON u.id = r.user_id
GROUP BY u.id, u.gender, u.age
ORDER BY num_ratings DESC
LIMIT 10;

-- Distribution of ratings
SELECT
    rating,
    COUNT(*) AS count
FROM ratings
GROUP BY rating
ORDER BY rating;

-- Average rating over time
SELECT
    YEAR(FROM_UNIXTIME(r.timestamp)) AS rating_year,
    AVG(r.rating) AS avg_rating
FROM ratings r
GROUP BY rating_year
ORDER BY rating_year;

-- Top average ratings by genre
SELECT
    genres,
    ROUND(AVG(rating), 2) AS avg_rating,
    COUNT(*) AS num_ratings
FROM movies m
JOIN ratings r ON m.id = r.movie_id
GROUP BY genres
ORDER BY avg_rating DESC
LIMIT 10;

-- Genre preferences by gender/age group
SELECT
    u.gender,
    u.age,
    m.genres,
    ROUND(AVG(r.rating),2) AS avg_rating,
    COUNT(*) AS num_ratings
FROM users u
JOIN ratings r ON u.id = r.user_id
JOIN movies m ON m.id = r.movie_id
GROUP BY u.gender, u.age, m.genres
ORDER BY avg_rating DESC
LIMIT 10;

-- Movies that are both highly rated and diverse (long-tail hits)
SELECT
    m.title,
    m.genres,
    COUNT(r.rating) AS num_ratings,
    AVG(r.rating) AS avg_rating
FROM movies m
JOIN ratings r ON m.id = r.movie_id
GROUP BY m.id, m.title, m.genres
HAVING COUNT(r.rating) BETWEEN 20 AND 100
ORDER BY avg_rating DESC
LIMIT 10;

-- Cold-start problem check (movies with few ratings)
SELECT
    m.title,
    COUNT(r.rating) AS num_ratings
FROM movies m
LEFT JOIN ratings r ON m.id = r.movie_id
GROUP BY m.id, m.title
HAVING COUNT(r.rating) < 5
ORDER BY num_ratings ASC
LIMIT 10;

-- Ratings density (how filled the user–movie matrix is)
SELECT
    COUNT(*) / (SELECT COUNT(*) FROM users) / (SELECT COUNT(*) FROM movies) AS density
FROM ratings;
