CREATE DATABASE IF NOT EXISTS stockticker_db;

USE stockticker_db;

DROP TABLE IF EXISTS tick;
CREATE TABLE IF NOT EXISTS tick (
    symbol VARCHAR(10),
    ts     DATETIME SERIES TIMESTAMP,
    open   NUMERIC(18, 2),
    high   NUMERIC(18, 2),
    low    NUMERIC(18, 2),
    close  NUMERIC(18, 2),
    volume INT,
    PRIMARY KEY (symbol, ts)
);

DROP TABLE IF EXISTS chat_history;

-- Show me the last 5 ticks for BBRQ-FX. Present the result as a table.
SELECT ts, open, high, low, close, volume
FROM tick
WHERE symbol = 'BBRQ-FX'
ORDER BY ts DESC
LIMIT 5;

-- Which ticker had the highest close price?
SELECT symbol, close
FROM tick
ORDER BY close DESC
LIMIT 1;

-- What is the average trading volume for BJBY-FX?
SELECT AVG(volume) AS average_volume
FROM tick
WHERE symbol = 'BJBY-FX';

-- Using the latest timestamp in the tick table as the reference,
-- return all tickers from the 10 seconds before that timestamp
-- where the close price is above 500 and sort the results alphabetically by ticker.
SELECT symbol
FROM tick
WHERE ts >= (SELECT MAX(ts) FROM tick) - INTERVAL 10 SECOND AND close > 500
ORDER BY symbol ASC;
