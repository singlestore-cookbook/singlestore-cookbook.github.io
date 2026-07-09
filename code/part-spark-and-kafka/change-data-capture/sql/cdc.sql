DROP DATABASE IF EXISTS crm_db;
CREATE DATABASE IF NOT EXISTS crm_db;

USE crm_db;

CREATE LINK crm_link AS MONGODB
CONFIG '{"mongodb.hosts": " <primary>:27017, <secondary>:27017, <secondary>:27017",
        "collection.include.list": "crm_db.*",
        "mongodb.ssl.enabled": "true",
        "mongodb.authsource": "admin",
        "mongodb.members.auto.discover": "false"}'
CREDENTIALS '{"mongodb.user": "admin",
            "mongodb.password": "<password>"}';

CREATE TABLES AS INFER PIPELINE AS LOAD DATA LINK crm_link '*' FORMAT AVRO;

SHOW TABLES;

SHOW PIPELINES;

SHOW PROCEDURES;

START ALL PIPELINES;

-- Phase 1 values
SELECT COUNT(*) FROM customers; -- 50
SELECT COUNT(*) FROM products;  -- 20
SELECT COUNT(*) FROM orders;    -- 100

-- Phase 2 values
SELECT COUNT(*) FROM customers; -- 55
SELECT COUNT(*) FROM products;  -- 18
SELECT COUNT(*) FROM orders;    -- 110

-- Check record counts
SELECT 'customers' AS table_name, COUNT(*) AS count FROM customers
UNION ALL
SELECT 'orders', COUNT(*) FROM orders
UNION ALL
SELECT 'products', COUNT(*) FROM products;

-- Check for recent updates (customers with updated_at field)
SELECT
    JSON_EXTRACT_STRING(_more, 'stage') AS stage,
    JSON_EXTRACT_STRING(_more, 'updated_at') AS updated_at
FROM customers 
WHERE JSON_EXTRACT_STRING(_more, 'updated_at') IS NOT NULL
LIMIT 10;

-- Check customer stage distribution
SELECT 
    JSON_EXTRACT_STRING(_more, 'stage') AS stage,
    COUNT(*) AS count
FROM customers
GROUP BY JSON_EXTRACT_STRING(_more, 'stage')
ORDER BY count DESC;

-- View recent orders (new orders with recent timestamps)
SELECT 
    JSON_EXTRACT_STRING(_more, 'customer_email') AS customer,
    LEFT(JSON_EXTRACT_STRING(_more, 'product_name'), 10) AS product,
    JSON_EXTRACT_STRING(_more, 'order_date') AS order_date
FROM orders
ORDER BY JSON_EXTRACT_STRING(_more, 'order_date') DESC
LIMIT 10;

STOP ALL PIPELINES;