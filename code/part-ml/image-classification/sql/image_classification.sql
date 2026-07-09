CREATE DATABASE IF NOT EXISTS image_db;

USE image_db;

DROP TABLE IF EXISTS predictions;
CREATE TABLE IF NOT EXISTS predictions (
    id INT PRIMARY KEY,
    label VARCHAR(20),
    t_shirt_top FLOAT,
    trouser FLOAT,
    pullover FLOAT,
    dress FLOAT,
    coat FLOAT,
    sandal FLOAT,
    shirt FLOAT,
    sneaker FLOAT,
    bag FLOAT,
    ankle_boot FLOAT
);

-- Create a view
CREATE VIEW predictions_with_max AS
SELECT
    *,
    GREATEST(
        t_shirt_top, trouser, pullover, dress, coat,
        sandal, shirt, sneaker, bag, ankle_boot
    ) AS max_prob,
    CASE GREATEST(
        t_shirt_top, trouser, pullover, dress, coat,
        sandal, shirt, sneaker, bag, ankle_boot
    )
        WHEN t_shirt_top THEN 't_shirt_top'
        WHEN trouser THEN 'trouser'
        WHEN pullover THEN 'pullover'
        WHEN dress THEN 'dress'
        WHEN coat THEN 'coat'
        WHEN sandal THEN 'sandal'
        WHEN shirt THEN 'shirt'
        WHEN sneaker THEN 'sneaker'
        WHEN bag THEN 'bag'
        ELSE 'ankle_boot'
    END AS predicted_class
FROM predictions;

-- Show a few predictions with the top-scoring class
SELECT id, label, max_prob, predicted_class
FROM predictions_with_max
LIMIT 5;

-- Count how many predictions were very confident (> 0.9)
SELECT COUNT(*) AS very_confident
FROM predictions_with_max
WHERE max_prob > 0.9;

-- Most common predicted class
SELECT predicted_class, COUNT(*) AS count
FROM predictions_with_max
GROUP BY predicted_class
ORDER BY count DESC;

-- Top N most confident predictions per class
SELECT id, label, max_prob
FROM predictions_with_max
WHERE predicted_class = 'sneaker'
ORDER BY max_prob DESC
LIMIT 5;

-- Predictions with low confidence (< 0.5)
SELECT id, label, max_prob, predicted_class
FROM predictions_with_max
WHERE max_prob < 0.5
ORDER BY max_prob ASC
LIMIT 10;

-- Distribution of max probabilities
SELECT
    CASE
        WHEN max_prob < 0.2 THEN '0-0.2'
        WHEN max_prob < 0.4 THEN '0.2-0.4'
        WHEN max_prob < 0.6 THEN '0.4-0.6'
        WHEN max_prob < 0.8 THEN '0.6-0.8'
        WHEN max_prob < 0.9 THEN '0.8-0.9'
        ELSE '0.9-1.0'
    END AS prob_bin,
    COUNT(*) AS count
FROM predictions_with_max
GROUP BY prob_bin
ORDER BY prob_bin;

-- Most frequently misclassified true class
SELECT label AS true_class, predicted_class, COUNT(*) AS count
FROM predictions_with_max
WHERE label <> predicted_class
GROUP BY label, predicted_class
ORDER BY count DESC
LIMIT 10;

-- Overall accuracy
SELECT ROUND(SUM(CASE WHEN label = predicted_class THEN 1 ELSE 0 END) / COUNT(*), 4) AS accuracy
FROM predictions_with_max;

-- Top predicted class per true class
SELECT true_class, predicted_class, count
FROM (
    SELECT 
        label AS true_class,
        predicted_class,
        COUNT(*) AS count,
        ROW_NUMBER() OVER (PARTITION BY label ORDER BY COUNT(*) DESC) AS rn
    FROM predictions_with_max
    GROUP BY label, predicted_class
) t
WHERE rn = 1;

-- Average confidence per predicted class
SELECT predicted_class, ROUND(AVG(max_prob), 3) AS avg_confidence
FROM predictions_with_max
GROUP BY predicted_class
ORDER BY avg_confidence DESC;

-- Confusion matrix (true vs. predicted counts)
WITH label_order AS (
    SELECT 't_shirt_top' AS label, 1 AS sort_order UNION ALL
    SELECT 'trouser', 2 UNION ALL
    SELECT 'pullover', 3 UNION ALL
    SELECT 'dress', 4 UNION ALL
    SELECT 'coat', 5 UNION ALL
    SELECT 'sandal', 6 UNION ALL
    SELECT 'shirt', 7 UNION ALL
    SELECT 'sneaker', 8 UNION ALL
    SELECT 'bag', 9 UNION ALL
    SELECT 'ankle_boot', 10
)
SELECT p.label AS true_class,
    SUM(CASE WHEN predicted_class='t_shirt_top' THEN 1 ELSE 0 END) AS t_shirt_top,
    SUM(CASE WHEN predicted_class='trouser' THEN 1 ELSE 0 END) AS trouser,
    SUM(CASE WHEN predicted_class='pullover' THEN 1 ELSE 0 END) AS pullover,
    SUM(CASE WHEN predicted_class='dress' THEN 1 ELSE 0 END) AS dress,
    SUM(CASE WHEN predicted_class='coat' THEN 1 ELSE 0 END) AS coat,
    SUM(CASE WHEN predicted_class='sandal' THEN 1 ELSE 0 END) AS sandal,
    SUM(CASE WHEN predicted_class='shirt' THEN 1 ELSE 0 END) AS shirt,
    SUM(CASE WHEN predicted_class='sneaker' THEN 1 ELSE 0 END) AS sneaker,
    SUM(CASE WHEN predicted_class='bag' THEN 1 ELSE 0 END) AS bag,
    SUM(CASE WHEN predicted_class='ankle_boot' THEN 1 ELSE 0 END) AS ankle_boot
FROM predictions_with_max p
JOIN label_order l ON p.label = l.label
GROUP BY p.label, l.sort_order
ORDER BY l.sort_order;
