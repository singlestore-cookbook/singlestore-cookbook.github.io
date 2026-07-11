CREATE DATABASE IF NOT EXISTS multimodal_db;

USE multimodal_db;

DROP TABLE IF EXISTS pdf_docs;

DROP TABLE IF EXISTS clip_images;
CREATE TABLE IF NOT EXISTS clip_images (
    id INT AUTO_INCREMENT PRIMARY KEY,
    category VARCHAR(50),
    image_path VARCHAR(255),
    embedding VECTOR(512)
);
