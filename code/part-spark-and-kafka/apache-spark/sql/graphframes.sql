CREATE DATABASE IF NOT EXISTS spark_demo_db;

USE spark_demo_db;

DROP TABLE IF EXISTS london_connections;
CREATE TABLE IF NOT EXISTS london_connections (
    tube_line VARCHAR(100),
    src       VARCHAR(200),
    dst       VARCHAR(200),
    PRIMARY KEY (tube_line, src, dst)
);

DROP TABLE IF EXISTS london_stations;
CREATE TABLE IF NOT EXISTS london_stations (
    id        VARCHAR(200) PRIMARY KEY,
    latitude  DOUBLE,
    longitude DOUBLE,
    zone      VARCHAR(20)
);