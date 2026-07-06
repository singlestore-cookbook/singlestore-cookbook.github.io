CREATE DATABASE IF NOT EXISTS timeseries_db;

USE timeseries_db;

DROP TABLE IF EXISTS tick;
CREATE TABLE IF NOT EXISTS tick (
    ts     DATETIME SERIES TIMESTAMP,
    symbol VARCHAR(5),
    price  NUMERIC(18, 4),
    KEY(ts)
);

-- Average Aggregate
SELECT symbol, AVG(price)
FROM tick
GROUP BY symbol
ORDER BY symbol
LIMIT 10;

-- Time Bucketing
SELECT symbol, TIME_BUCKET("5d", ts), AVG(price)
FROM tick
WHERE symbol = "AAPL"
GROUP BY 1, 2
ORDER BY 1, 2
LIMIT 10;

-- Candlestick
SELECT TIME_BUCKET("5d") AS ts,
     symbol,
     MIN(price) AS low,
     MAX(price) AS high,
     FIRST(price) AS open,
     LAST(price) AS close
FROM tick
WHERE symbol = "AAPL"
GROUP BY 2, 1
ORDER BY 2, 1
LIMIT 10;

-- Smoothing
SELECT symbol, ts, price, AVG(price)
OVER (ORDER BY ts ROWS BETWEEN 3 PRECEDING AND CURRENT ROW) AS smoothed_price
FROM tick
WHERE symbol = "AAPL"
LIMIT 10;

-- AS OF
SELECT *
FROM tick
WHERE ts <= "2024-10-11 00:00:00"
AND symbol = "AAPL"
ORDER BY ts DESC
LIMIT 1;
