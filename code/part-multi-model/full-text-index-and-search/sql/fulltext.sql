CREATE DATABASE IF NOT EXISTS fulltext_db;

USE fulltext_db;

DROP TABLE IF EXISTS articles;
CREATE TABLE IF NOT EXISTS articles (
    id           VARCHAR(50) NOT NULL PRIMARY KEY,
    doi          VARCHAR(100),
    title        VARCHAR(500),
    authors      TEXT,
    affiliations TEXT,
    journal      VARCHAR(255),
    pub_date     DATE,
    abstract     TEXT,
    body         LONGTEXT,
    refs         LONGTEXT,
    FULLTEXT USING VERSION 2(title, abstract, body)
);

-- Run this command after loading the data from the CSV file
OPTIMIZE TABLE articles FLUSH;

-- Simple keyword search in one field
SELECT title
FROM articles
WHERE MATCH(TABLE articles) AGAINST ('body:machine')
LIMIT 5;

-- Exact phrase search in one field
SELECT title
FROM articles
WHERE MATCH(TABLE articles) AGAINST ('title:"neural networks"')
LIMIT 5;

-- Wildcard search in one field
SELECT title
FROM articles
WHERE MATCH(TABLE articles) AGAINST ('title:immun*')
LIMIT 5;

-- Boolean AND search across a single field
SELECT SUBSTRING(title, 1, 60) AS title
FROM articles
WHERE MATCH(TABLE articles) AGAINST ('abstract:machine AND abstract:learn*')
LIMIT 5;

-- Boolean search with AND and NOT
SELECT SUBSTRING(title, 1, 60) AS title
FROM articles
WHERE MATCH (TABLE articles) AGAINST ('body:(+data*) AND NOT body:sens*')
LIMIT 5;

-- Fuzzy search
SELECT SUBSTRING(title, 1, 60) AS title
FROM articles
WHERE MATCH (TABLE articles) AGAINST ('title:modelling~1')
LIMIT 5;

-- Ranking results by BM25 score across a single field
SELECT SUBSTRING(title, 1, 60) AS title, ROUND(BM25(articles,'body:science'), 4) AS score
FROM articles
WHERE BM25(articles,'body:science')
ORDER BY score DESC
LIMIT 5;

-- Ranking with BM25 across multiple fields
SELECT SUBSTRING(title, 1, 60) AS title, ROUND(BM25(articles,'title:machine OR body:machine'), 4) AS score
FROM articles
WHERE BM25(articles,'title:machine OR body:machine')
ORDER BY score DESC
LIMIT 5;