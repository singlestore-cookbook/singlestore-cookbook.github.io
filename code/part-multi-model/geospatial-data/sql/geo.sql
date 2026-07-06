CREATE DATABASE IF NOT EXISTS geo_db;

USE geo_db;

DROP TABLE IF EXISTS london_boroughs;
CREATE ROWSTORE TABLE IF NOT EXISTS london_boroughs (
    name     VARCHAR(32),
    hectares FLOAT,
    geometry GEOGRAPHY,
    centroid GEOGRAPHYPOINT,
    INDEX(geometry)
);

DROP TABLE IF EXISTS london_connections;
CREATE TABLE IF NOT EXISTS london_connections (
    tube_line    VARCHAR(100),
    from_station VARCHAR(200),
    to_station   VARCHAR(200),
    PRIMARY KEY (tube_line, from_station, to_station)
);

DROP TABLE IF EXISTS london_lines;
CREATE TABLE IF NOT EXISTS london_lines (
    tube_line VARCHAR(100) PRIMARY KEY,
    color     CHAR(7)
);

DROP TABLE IF EXISTS london_stations;
CREATE ROWSTORE TABLE IF NOT EXISTS london_stations (
    station   VARCHAR(200) PRIMARY KEY,
    latitude  DOUBLE,
    longitude DOUBLE,
    zone      VARCHAR(20),
    geometry AS GEOGRAPHY_POINT(longitude, latitude) PERSISTED GEOGRAPHYPOINT,
    INDEX(geometry)
);

DROP TABLE IF EXISTS london_tube_edges;
CREATE TABLE IF NOT EXISTS london_tube_edges (
    tube_line VARCHAR(50) NOT NULL,
    from_station VARCHAR(100) NOT NULL,
    to_station VARCHAR(100) NOT NULL,
    color VARCHAR(7) NOT NULL,
    from_latitude DOUBLE NOT NULL,
    from_longitude DOUBLE NOT NULL,
    from_zone VARCHAR(20),
    to_latitude DOUBLE NOT NULL,
    to_longitude DOUBLE NOT NULL,
    to_zone VARCHAR(20),
    distance DOUBLE NOT NULL,
    PRIMARY KEY (tube_line, from_station, to_station)
);

SELECT * FROM london_boroughs LIMIT 5;

SELECT * FROM london_connections LIMIT 5;

SELECT * FROM london_lines LIMIT 5;

SELECT * FROM london_stations LIMIT 5;

-- Area
SELECT ROUND(GEOGRAPHY_AREA(geometry), 0) AS sqm
FROM london_boroughs
WHERE name = "Merton";

-- Distance
SELECT b.name AS neighbor, ROUND(GEOGRAPHY_DISTANCE(a.geometry, b.geometry), 0) AS distance_from_border
FROM london_boroughs a, london_boroughs b
WHERE a.name = "Merton"
ORDER BY distance_from_border
LIMIT 10;

-- Length
SELECT name, ROUND(GEOGRAPHY_LENGTH(geometry), 0) AS perimeter
FROM london_boroughs
ORDER BY perimeter DESC
LIMIT 5;

-- Contains
SELECT b.station
FROM london_boroughs a, london_stations b
WHERE GEOGRAPHY_CONTAINS(a.geometry, b.geometry) AND a.name = "Merton"
ORDER BY station;

-- Intersects
SELECT a.name
FROM london_boroughs a, london_stations b
WHERE GEOGRAPHY_INTERSECTS(b.geometry, a.geometry) AND b.station = "Morden";

-- Approx Intersects
SELECT a.name
FROM london_boroughs a, london_stations b
WHERE APPROX_GEOGRAPHY_INTERSECTS(b.geometry, a.geometry) AND b.station = "Morden";

-- Within Distance
SELECT a.station
FROM london_stations a, london_boroughs b
WHERE GEOGRAPHY_WITHIN_DISTANCE(a.geometry, b.centroid, 150)
ORDER BY station;

-- Count of connections per line
SELECT tube_line, COUNT(*) AS connection_count
FROM london_tube_edges
GROUP BY tube_line
ORDER BY connection_count DESC;

-- Count of stations per line
SELECT
    tube_line,
    COUNT(DISTINCT from_station) + COUNT(DISTINCT to_station) AS total_stations
FROM london_tube_edges
GROUP BY tube_line
ORDER BY total_stations DESC;

-- Zone-wise station count
SELECT zone, COUNT(*) AS station_count
FROM (
    SELECT from_zone AS zone FROM london_tube_edges
    UNION ALL
    SELECT to_zone AS zone FROM london_tube_edges
) AS all_zones
GROUP BY zone
ORDER BY station_count DESC;

-- Total distance covered by each tube line
SELECT
    tube_line,
    ROUND(SUM(distance), 2) AS total_distance_km
FROM london_tube_edges
GROUP BY tube_line
ORDER BY total_distance_km DESC;

-- Average distance per connection on each line
SELECT
    tube_line,
    ROUND(AVG(distance), 2) AS avg_distance_km,
    COUNT(*) AS connections
FROM london_tube_edges
GROUP BY tube_line
ORDER BY avg_distance_km DESC;

-- All stations served by a specific line
SELECT DISTINCT from_station AS station
FROM london_tube_edges
WHERE tube_line = 'Northern'
UNION
SELECT DISTINCT to_station
FROM london_tube_edges
WHERE tube_line = 'Northern'
ORDER BY 1;

-- All direct connections from a selected station
SELECT
    from_station,
    to_station,
    tube_line,
    ROUND(distance, 2) AS distance_km
FROM london_tube_edges
WHERE from_station = 'Oxford Circus'
UNION
SELECT
    to_station AS from_station,
    from_station AS to_station,
    tube_line,
    ROUND(distance, 2) AS distance_km
FROM london_tube_edges
WHERE to_station = 'Oxford Circus';

-- List all stations served by multiple lines
SELECT station
FROM (
    SELECT from_station AS station, tube_line FROM london_tube_edges
    UNION ALL
    SELECT to_station AS station, tube_line FROM london_tube_edges
) AS all_data
GROUP BY station
HAVING COUNT(DISTINCT tube_line) > 1
ORDER BY COUNT(DISTINCT tube_line) DESC;

-- Find the station with the most line connections
SELECT station, COUNT(DISTINCT tube_line) AS line_count
FROM (
    SELECT from_station AS station, tube_line FROM london_tube_edges
    UNION ALL
    SELECT to_station AS station, tube_line FROM london_tube_edges
) AS all_stations
GROUP BY station
ORDER BY line_count DESC
LIMIT 10;

-- Top 10 longest connections (by distance)
SELECT
    from_station,
    to_station,
    tube_line,
    ROUND(distance, 2) AS distance_km
FROM london_tube_edges
ORDER BY distance DESC
LIMIT 10;

-- List of zone transitions (e.g., Zone 1 to Zone 2)
SELECT
    from_zone,
    to_zone,
    COUNT(*) AS num_connections
FROM london_tube_edges
GROUP BY from_zone, to_zone
ORDER BY num_connections DESC;

-- Check for duplicate entries (e.g., both A→B and B→A)
SELECT
    a.from_station,
    a.to_station,
    a.tube_line
FROM london_tube_edges a
JOIN london_tube_edges b
  ON a.from_station = b.to_station 
  AND a.to_station = b.from_station 
  AND a.tube_line = b.tube_line
WHERE a.from_station < a.to_station;
