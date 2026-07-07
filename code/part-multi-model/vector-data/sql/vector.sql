CREATE DATABASE IF NOT EXISTS vector_db;

USE vector_db;

DROP TABLE IF EXISTS train_data;
CREATE TABLE IF NOT EXISTS train_data (
    id INT PRIMARY KEY,
    vector VECTOR(784),
    label VARCHAR(20)
);

DROP TABLE IF EXISTS test_data;
CREATE TABLE IF NOT EXISTS test_data (
    id INT PRIMARY KEY,
    vector VECTOR(784),
    label VARCHAR(20)
);

ALTER TABLE train_data ADD VECTOR INDEX (vector)
    INDEX_OPTIONS '{
        "index_type": "HNSW_FLAT",
        "metric_type": "EUCLIDEAN_DISTANCE",
        "M": 16,
        "efConstruction": 200
    }';

ALTER TABLE test_data ADD VECTOR INDEX (vector)
    INDEX_OPTIONS '{
        "index_type": "HNSW_FLAT",
        "metric_type": "EUCLIDEAN_DISTANCE",
        "M": 16,
        "efConstruction": 200
    }';

SHOW INDEXES FROM train_data;

SHOW INDEXES FROM test_data;

-- dress
SELECT label
FROM train_data
WHERE id = 30000;

-- pullover
SELECT label
FROM test_data
WHERE id = 500;

-- Basic k-NN search with index using ORDER BY and LIMIT
SELECT label, vector <-> (
    SELECT vector FROM train_data WHERE id = 30000
) AS distance
FROM train_data
ORDER BY distance
LIMIT 5;

-- k-NN search in test_data with index
SELECT label, vector <-> (
    SELECT vector FROM test_data WHERE id = 500
) AS distance
FROM test_data
ORDER BY distance
LIMIT 5;

-- Cross-table similarity search
SELECT label, vector <-> (
    SELECT vector FROM train_data WHERE id = 30000
) AS distance
FROM test_data
ORDER BY distance
LIMIT 5;

-- Using EXPLAIN for query plan
EXPLAIN
SELECT label, vector <-> (
    SELECT vector FROM train_data WHERE id = 30000
) AS distance
FROM train_data
ORDER BY distance
LIMIT 5;
