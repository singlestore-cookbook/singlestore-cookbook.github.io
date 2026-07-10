CREATE DATABASE IF NOT EXISTS agriculture_db;

USE agriculture_db;

-- Overall yearly trends: average rainfall, soil pH, yield and predicted yield
SELECT
    year,
    ROUND(AVG(rainfall), 2) AS avg_rainfall,
    ROUND(AVG(soil_ph), 2) AS avg_soil_ph,
    ROUND(AVG(yield), 2) AS avg_yield,
    ROUND(AVG(predicted_yield), 2) AS avg_predicted_yield
FROM agriculture
GROUP BY year
ORDER BY year;

-- Top crop per year (with actual vs predicted yield)
SELECT
    year,
    crop,
    ROUND(avg_yield, 2) AS avg_yield,
    ROUND(avg_predicted_yield, 2) AS avg_predicted_yield,
    ROUND(yield_diff, 2) AS yield_diff
FROM (
    SELECT
        year,
        crop,
        AVG(yield) AS avg_yield,
        AVG(predicted_yield) AS avg_predicted_yield,
        AVG(predicted_yield) - AVG(yield) AS yield_diff,
        ROW_NUMBER() OVER (PARTITION BY year ORDER BY AVG(yield) DESC) AS rn
    FROM agriculture
    GROUP BY year, crop
) ranked
WHERE rn = 1
ORDER BY year;

-- Top crop per province (average yield)
SELECT
    province,
    crop,
    ROUND(avg_yield, 2) AS avg_yield,
    ROUND(avg_predicted_yield, 2) AS avg_predicted_yield,
    ROUND(avg_rainfall, 2) AS avg_rainfall,
    ROUND(avg_soil_ph, 2) AS avg_soil_ph
FROM (
    SELECT
        province,
        crop,
        AVG(yield) AS avg_yield,
        AVG(predicted_yield) AS avg_predicted_yield,
        AVG(rainfall) AS avg_rainfall,
        AVG(soil_ph) AS avg_soil_ph,
        ROW_NUMBER() OVER (PARTITION BY province ORDER BY AVG(yield) DESC) AS rn
    FROM agriculture
    GROUP BY province, crop
) ranked
WHERE rn = 1
ORDER BY province;

-- Top 5 provinces by average yield
SELECT
    province,
    ROUND(AVG(yield), 2) AS avg_yield,
    ROUND(AVG(predicted_yield), 2) AS avg_predicted_yield
FROM agriculture
GROUP BY province
ORDER BY avg_yield DESC
LIMIT 5;

-- Bottom 5 provinces by average yield
SELECT
    province,
    ROUND(AVG(yield), 2) AS avg_yield,
    ROUND(AVG(predicted_yield), 2) AS avg_predicted_yield
FROM agriculture
GROUP BY province
ORDER BY avg_yield ASC
LIMIT 5;

-- Top crop per year among selected major crops (Rice, Corn, Coffee, Palm Oil, Rubber, Cocoa)
SELECT
    year,
    crop,
    ROUND(avg_yield, 2) AS avg_yield,
    ROUND(avg_predicted_yield, 2) AS avg_predicted_yield,
    ROUND(yield_diff, 2) AS yield_diff
FROM (
    SELECT
        year,
        crop,
        AVG(yield) AS avg_yield,
        AVG(predicted_yield) AS avg_predicted_yield,
        AVG(predicted_yield) - AVG(yield) AS yield_diff,
        ROW_NUMBER() OVER (PARTITION BY year ORDER BY AVG(yield) DESC) AS rn
    FROM agriculture
    WHERE crop IN ('Rice', 'Corn', 'Coffee', 'Palm Oil', 'Rubber', 'Cocoa')
    GROUP BY year, crop
) ranked
WHERE rn = 1
ORDER BY year;

-- Rank top 2 crops per year among selected major crops
WITH yearly_crop_stats AS (
    SELECT
        year,
        crop,
        ROUND(AVG(yield), 2) AS avg_yield,
        ROUND(AVG(predicted_yield), 2) AS avg_predicted_yield,
        ROUND(AVG(predicted_yield) - AVG(yield), 2) AS yield_diff
    FROM agriculture
    WHERE crop IN ('Rice', 'Corn', 'Coffee', 'Palm Oil', 'Rubber', 'Cocoa')
    GROUP BY year, crop
)
SELECT *
FROM (
    SELECT *,
            ROW_NUMBER() OVER (PARTITION BY year ORDER BY avg_yield DESC) AS rank_in_year
    FROM yearly_crop_stats
) ranked
WHERE rank_in_year <= 2
ORDER BY year ASC;
