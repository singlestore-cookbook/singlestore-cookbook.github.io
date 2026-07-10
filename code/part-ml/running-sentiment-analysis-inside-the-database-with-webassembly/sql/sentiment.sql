CREATE DATABASE IF NOT EXISTS sentiment_db;

USE sentiment_db;

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

DROP TABLE IF EXISTS stock_sentiment;
CREATE TABLE IF NOT EXISTS stock_sentiment (
    headline  VARCHAR(250),
    compound  FLOAT,
    positive  FLOAT,
    negative  FLOAT,
    neutral   FLOAT,
    url       TEXT,
    publisher VARCHAR(30),
    ts        DATETIME,
    symbol    VARCHAR(10)
);

DROP TABLE IF EXISTS raw_fictitious_headlines;
CREATE TABLE IF NOT EXISTS raw_fictitious_headlines (
        headline  TEXT,
        url       TEXT,
        publisher TEXT,
        ts        DATETIME,
        symbol    VARCHAR(10)
);

INSERT INTO stock_sentiment (headline, compound, positive, negative, neutral, url, publisher, ts, symbol)
SELECT 
    SUBSTRING(i.headline, 1, 250),
    s.compound,
    s.positive,
    s.negative,
    s.neutral,
    i.url,
    SUBSTRING(i.publisher, 1, 30),
    i.ts,
    i.symbol
FROM raw_fictitious_headlines i, sentimentable(i.headline) s;

CREATE INDEX idx_stock_sentiment_symbol_ts ON stock_sentiment(symbol, ts);

-- Quick test
SELECT *
FROM sentimentable('Stocks rally as earnings beat expectations') AS s;

-- Apply sentimentable to the stock_sentiment table
SELECT
    symbol,
    DATE(ts) AS ts,
    LEFT(headline, 30) AS headline,
    ROUND(positive, 3) AS positive,
    ROUND(negative, 3) AS negative,
    ROUND(neutral, 3) AS neutral
FROM stock_sentiment
LIMIT 10;

-- Aggregate sentiment by stock
SELECT
    symbol,
    DATE(ts) AS ts,
    ROUND(AVG(positive), 3) AS avg_positive,
    ROUND(AVG(negative), 3) AS avg_negative,
    ROUND(AVG(neutral), 3)  AS avg_neutral,
    COUNT(*) AS num_headlines
FROM stock_sentiment
GROUP BY symbol, DATE(ts)
ORDER BY symbol, ts
LIMIT 10;

-- Join with tick data
SELECT
    t.symbol,
    DATE(t.ts) AS ts,
    ROUND(t.close, 2) AS close,
    ROUND(ss.positive, 3) AS positive,
    ROUND(ss.negative, 3) AS negative,
    ROUND(ss.neutral, 3) AS neutral
FROM tick t
JOIN stock_sentiment ss
  ON t.symbol = ss.symbol
 AND DATE(t.ts) = DATE(ss.ts)
ORDER BY t.symbol, t.ts
LIMIT 10;

-- Most positive headlines
SELECT
    symbol,
    DATE(ts) AS ts,
    LEFT(headline, 30) AS headline,
    ROUND(positive, 3) AS positive
FROM stock_sentiment
ORDER BY positive DESC
LIMIT 10;

-- Most negative headlines
SELECT
    symbol,
    DATE(ts) AS ts,
    LEFT(headline, 30) AS headline,
    ROUND(negative, 3) AS negative
FROM stock_sentiment
ORDER BY negative DESC
LIMIT 10;

-- Average daily sentiment vs daily close price
WITH daily_sentiment AS (
    SELECT
        symbol,
        DATE(ts) AS ts,
        ROUND(AVG(positive), 3) AS avg_positive,
        ROUND(AVG(negative), 3) AS avg_negative,
        ROUND(AVG(neutral), 3) AS avg_neutral
    FROM stock_sentiment
    GROUP BY symbol, DATE(ts)
)
SELECT
    d.symbol,
    d.ts,
    ROUND(t.close, 2) AS daily_close,
    d.avg_positive,
    d.avg_negative,
    d.avg_neutral
FROM daily_sentiment d
JOIN tick t
  ON d.symbol = t.symbol
 AND DATE(t.ts) = d.ts
ORDER BY d.symbol, d.ts
LIMIT 10;

-- Compare stored sentiment vs Wasm function
SELECT
    ss.symbol,
    DATE(ss.ts) AS ts,
    LEFT(ss.headline, 30) AS headline,
    CASE
        WHEN ROUND(ss.positive, 3) = ROUND(s.positive, 3)
         AND ROUND(ss.negative, 3) = ROUND(s.negative, 3)
         AND ROUND(ss.neutral, 3) = ROUND(s.neutral, 3)
        THEN 'match'
        ELSE 'not match'
    END AS comparison
FROM stock_sentiment ss
JOIN LATERAL sentimentable(ss.headline) AS s
WHERE ss.symbol = 'BBRQ-FX'
LIMIT 10;

-- Spot-checking discrepancies
SELECT
    ss.symbol,
    DATE(ss.ts) AS ts,
    LEFT(ss.headline, 30) AS headline,
    ROUND(ss.positive, 3) AS stored_positive,
    ROUND(ss.negative, 3) AS stored_negative,
    ROUND(ss.neutral, 3) AS stored_neutral,
    ROUND(s.positive, 3) AS positive,
    ROUND(s.negative, 3) AS negative,
    ROUND(s.neutral, 3) AS neutral
FROM stock_sentiment ss
JOIN LATERAL sentimentable(ss.headline) AS s
WHERE ss.symbol = 'BBRQ-FX'
  AND ss.ts BETWEEN '2013-01-01' AND '2014-01-01'
LIMIT 10;
