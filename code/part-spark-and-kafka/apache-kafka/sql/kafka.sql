CREATE DATABASE IF NOT EXISTS sensor_readings_db;

USE sensor_readings_db;

DROP TABLE IF EXISTS sensors;
CREATE TABLE IF NOT EXISTS sensors (
    id INT PRIMARY KEY,
    name VARCHAR (50),
    latitude DOUBLE,
    longitude DOUBLE
);

DROP TABLE IF EXISTS temperatures;
CREATE TABLE IF NOT EXISTS temperatures (
    id INT,
    temperature DOUBLE,
    timestamp BIGINT,
    PRIMARY KEY(id, timestamp)
);

DROP PIPELINE IF EXISTS kafka_confluent_cloud;

CREATE PIPELINE kafka_confluent_cloud AS
LOAD DATA KAFKA '<bootstrap_server>/iot-temperatures'
CONFIG '{
    "security.protocol" : "SASL_SSL",
    "sasl.mechanism" : "PLAIN",
    "sasl.username" : "<api_key>"
}'
CREDENTIALS '{
    "sasl.password" : "<api_secret>"
}'
SKIP DUPLICATE KEY ERRORS
INTO TABLE temperatures
FORMAT JSON
( id <- id, temperature <- temperature, timestamp <- timestamp );

TEST PIPELINE kafka_confluent_cloud LIMIT 1;

START PIPELINE kafka_confluent_cloud;

SHOW PIPELINES;

SELECT COUNT(*) FROM sensors;
SELECT COUNT(*) FROM temperatures;

STOP PIPELINE kafka_confluent_cloud;

CREATE DATABASE IF NOT EXISTS timeseries_db;

USE timeseries_db;

DROP TABLE IF EXISTS tick;
CREATE TABLE IF NOT EXISTS tick (
    ts     DATETIME SERIES TIMESTAMP,
    symbol VARCHAR(10),
    price  NUMERIC(18, 4),
    KEY(ts)
);

INSERT INTO tick (ts, symbol, price) VALUES
('2025-08-10 09:15:32', 'TEST14-FX', 134.27),
('2025-08-10 10:45:19', 'TEST03-FX', 89.54),
('2025-08-11 11:03:47', 'TEST19-FX', 215.76),
('2025-08-12 14:22:08', 'TEST07-FX', 52.13),
('2025-08-12 15:41:56', 'TEST11-FX', 301.45),
('2025-08-13 09:05:11', 'TEST01-FX', 177.88),
('2025-08-13 13:27:33', 'TEST16-FX', 64.92),
('2025-08-14 16:12:49', 'TEST09-FX', 240.67),
('2025-08-14 10:34:25', 'TEST20-FX', 118.39),
('2025-08-15 09:48:59', 'TEST05-FX', 78.56),
('2025-08-15 11:26:41', 'TEST12-FX', 412.09),
('2025-08-16 14:55:20', 'TEST04-FX', 33.48),
('2025-08-16 15:43:12', 'TEST17-FX', 265.31),
('2025-08-17 10:07:03', 'TEST08-FX', 190.75),
('2025-08-17 13:59:44', 'TEST15-FX', 142.63),
('2025-08-18 09:14:18', 'TEST02-FX', 523.22),
('2025-08-18 11:36:02', 'TEST18-FX', 74.85),
('2025-08-19 15:11:27', 'TEST10-FX', 96.40),
('2025-08-19 16:22:38', 'TEST06-FX', 381.77),
('2025-08-20 09:49:55', 'TEST13-FX', 120.18);

SELECT TO_JSON(tick.*)
FROM tick
INTO KAFKA '<bootstrap_server>/tick-data'
CONFIG '{
    "security.protocol" : "SASL_SSL",
    "sasl.mechanism" : "PLAIN",
    "sasl.username" : "<api_key>",
    "ssl.ca.location" : "/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem"}'
CREDENTIALS '{
    "sasl.password" : "<api_secret>"}';
