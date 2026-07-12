CREATE DATABASE IF NOT EXISTS ollama_db;

USE ollama_db;

DESCRIBE company_knowledge;

SELECT LEFT(content, 30) AS content, LEFT(vector :> JSON, 30) AS vector FROM company_knowledge;

SHOW INDEX FROM company_knowledge;
