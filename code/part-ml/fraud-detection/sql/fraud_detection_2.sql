CREATE DATABASE IF NOT EXISTS creditcard_db;

USE creditcard_db;

-- Find the average amount for fraudulent vs. genuine transactions for train_data table
SELECT
    CASE
        WHEN Class = 1 THEN 'Fraud'
        WHEN Class = 0 THEN 'Genuine'
        ELSE 'Unknown'
    END AS TransactionType,
    ROUND(AVG(Amount), 2) AS AverageAmount,
    COUNT(*) AS NumberOfTransactions
FROM train_data
GROUP BY TransactionType
ORDER BY TransactionType;

-- Find the average amount for fraudulent vs. genuine transactions for test_data table
SELECT
    CASE
        WHEN Class = 1 THEN 'Fraud'
        WHEN Class = 0 THEN 'Genuine'
        ELSE 'Unknown'
    END AS TransactionType,
    ROUND(AVG(Amount), 2) AS AverageAmount,
    COUNT(*) AS NumberOfTransactions
FROM test_data
GROUP BY TransactionType
ORDER BY TransactionType;

-- Fraud vs. genuine proportion in train_data
SELECT
    CASE WHEN Class = 1 THEN 'Fraud' ELSE 'Genuine' END AS TransactionType,
    COUNT(*) AS Count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS Percentage
FROM train_data
GROUP BY TransactionType;

-- Fraud vs. genuine proportion in test_data
SELECT
    CASE WHEN Class = 1 THEN 'Fraud' ELSE 'Genuine' END AS TransactionType,
    COUNT(*) AS Count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS Percentage
FROM test_data
GROUP BY TransactionType;

-- Find the maximum and minimum amounts for fraudulent transactions
SELECT
    MAX(Amount) AS MaxFraudAmount,
    MIN(Amount) AS MinFraudAmount
FROM train_data
WHERE Class = 1;

-- Quartiles for fraud vs. genuine transactions
SELECT
    CASE WHEN Class = 1 THEN 'Fraud' ELSE 'Genuine' END AS TransactionType,
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY Amount) AS Q1,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY Amount) AS Median,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY Amount) AS Q3
FROM train_data
GROUP BY TransactionType;

-- Count fraudulent transactions within specific amount ranges
SELECT
    CASE
        WHEN Amount < 50 THEN 'Low'
        WHEN Amount >= 50 AND Amount < 200 THEN 'Medium'
    ELSE 'High'
    END AS AmountRange,
    COUNT(*) AS FraudCount
FROM train_data
WHERE Class = 1
GROUP BY AmountRange
ORDER BY FraudCount DESC;

-- Top 10 highest fraud amounts
SELECT Amount
FROM train_data
WHERE Class = 1
ORDER BY Amount DESC
LIMIT 10;

-- Fraud ratio across amount ranges
SELECT
    CASE
        WHEN Amount < 50 THEN 'Low'
        WHEN Amount >= 50 AND Amount < 200 THEN 'Medium'
        ELSE 'High'
    END AS AmountRange,
    COUNT(*) AS TotalTransactions,
    SUM(CASE WHEN Class = 1 THEN 1 ELSE 0 END) AS FraudCount,
    ROUND(SUM(CASE WHEN Class = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS FraudPercentage
FROM train_data
GROUP BY AmountRange
ORDER BY FraudPercentage DESC;

-- Fraud likelihood by deciles of transaction amount
WITH deciles AS (
    SELECT
        Amount,
        Class,
        NTILE(10) OVER (ORDER BY Amount) AS Decile
    FROM train_data
)
SELECT
    Decile,
    COUNT(*) AS TotalTransactions,
    SUM(CASE WHEN Class = 1 THEN 1 ELSE 0 END) AS FraudCount,
    ROUND(SUM(CASE WHEN Class = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS FraudPercentage
FROM deciles
GROUP BY Decile
ORDER BY Decile;

-- Overall fraud prevalence
SELECT
    COUNT(*) AS TotalTransactions,
    SUM(CASE WHEN Class = 1 THEN 1 ELSE 0 END) AS FraudCount,
    ROUND(SUM(CASE WHEN Class = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 4) AS FraudPercentage
FROM creditcard;

-- Fraud vs. genuine by amount ranges
SELECT
    CASE
        WHEN Amount < 50 THEN 'Low'
        WHEN Amount >= 50 AND Amount < 200 THEN 'Medium'
        ELSE 'High'
    END AS AmountRange,
    COUNT(*) AS TotalTransactions,
    SUM(CASE WHEN Class = 1 THEN 1 ELSE 0 END) AS FraudCount,
    ROUND(SUM(CASE WHEN Class = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 4) AS FraudPercentage
FROM creditcard
GROUP BY AmountRange
ORDER BY FraudPercentage DESC;

-- Fraud by deciles of transaction amount
WITH deciles AS (
    SELECT
        Amount,
        Class,
        NTILE(10) OVER (ORDER BY Amount) AS Decile
    FROM creditcard
)
SELECT
    Decile,
    COUNT(*) AS TotalTransactions,
    SUM(CASE WHEN Class = 1 THEN 1 ELSE 0 END) AS FraudCount,
    ROUND(SUM(CASE WHEN Class = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 4) AS FraudPercentage
FROM deciles
GROUP BY Decile
ORDER BY Decile;

-- Extreme fraud amounts (90th, 95th, 99th percentiles)
SELECT
    PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY Amount) AS P90,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY Amount) AS P95,
    PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY Amount) AS P99
FROM creditcard
WHERE Class = 1;

-- Top 10 highest fraud amounts
SELECT Amount
FROM creditcard
WHERE Class = 1
ORDER BY Amount DESC
LIMIT 10;

-- Fraud vs. genuine counts by quarter of transaction amount
SELECT AmountQuartile, COUNT(*) AS TransactionCount
FROM (
    SELECT 
        CASE 
            WHEN Amount < 50 THEN 'Low'
            WHEN Amount BETWEEN 50 AND 200 THEN 'Medium'
            WHEN Amount BETWEEN 200 AND 500 THEN 'High'
            ELSE 'Very High'
        END AS AmountQuartile
    FROM creditcard
) t
GROUP BY AmountQuartile;

-- Daily fraud distribution
SELECT
    FLOOR(Time/86400) AS DayNumber,
    COUNT(*) AS TotalTransactions,
    SUM(CASE WHEN Class = 1 THEN 1 ELSE 0 END) AS FraudCount,
    ROUND(SUM(CASE WHEN Class = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 4) AS FraudPercentage
FROM creditcard
GROUP BY DayNumber
ORDER BY DayNumber;

-- Daily fraud distribution by amount range
SELECT
    FLOOR(Time/86400) AS DayNumber,
    CASE
        WHEN Amount < 50 THEN 'Low'
        WHEN Amount >= 50 AND Amount < 200 THEN 'Medium'
        ELSE 'High'
    END AS AmountRange,
    COUNT(*) AS TotalTransactions,
    SUM(CASE WHEN Class = 1 THEN 1 ELSE 0 END) AS FraudCount,
    ROUND(SUM(CASE WHEN Class = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 4) AS FraudPercentage
FROM creditcard
GROUP BY DayNumber, AmountRange
ORDER BY DayNumber, AmountRange;
