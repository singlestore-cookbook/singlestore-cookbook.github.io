CREATE DATABASE IF NOT EXISTS library_db;

USE library_db;

DROP TABLE IF EXISTS authors;
CREATE TABLE IF NOT EXISTS authors (
    id INT PRIMARY KEY NOT NULL,
    name VARCHAR(100) NOT NULL,
    nationality VARCHAR(50) NOT NULL
);

DROP TABLE IF EXISTS publishers;
CREATE TABLE IF NOT EXISTS publishers (
    id INT PRIMARY KEY NOT NULL,
    name VARCHAR(100) NOT NULL,
    location VARCHAR(100) NOT NULL
);

DROP TABLE IF EXISTS items;
CREATE TABLE IF NOT EXISTS items (
    id INT PRIMARY KEY NOT NULL,
    title VARCHAR(200) NOT NULL,
    item_type VARCHAR(50) NOT NULL,
    publisher_id INT NOT NULL,
    metadata JSON NOT NULL
);

INSERT INTO authors (id, name, nationality) VALUES
(1, 'Clara Penrose', 'British'),
(2, 'Dmitri Ivanov', 'Russian'),
(3, 'Mei-Ling Zhang', 'Chinese');

INSERT INTO publishers (id, name, location) VALUES
(1, 'Aurora Press', 'London, UK'),
(2, 'Maple Leaf Publishing', 'Toronto, Canada'),
(3, 'Lotus House', 'Beijing, China');

-- Books (flat JSON)
INSERT INTO items (id, title, item_type, publisher_id, metadata) VALUES
(1, 'The Quantum Garden', 'book', 1, '{"isbn": "978-0-123456-47-2", "pages": 320, "language": "English", "author_id": 1}'),
(2, 'Empire of Winds', 'book', 2, '{"isbn": "978-1-234567-89-3", "pages": 290, "language": "English", "author_id": 2}'),
(3, 'Pathways to Silk', 'book', 3, '{"isbn": "978-9-876543-21-0", "pages": 350, "language": "Chinese", "author_id": 3}'),
(4, 'Under Northern Lights', 'book', 1, '{"isbn": "978-0-111222-33-4", "pages": 400, "language": "English", "author_id": 1}'),
(5, 'Siberian Dreams', 'book', 2, '{"isbn": "978-8-765432-10-9", "pages": 275, "language": "Russian", "author_id": 2}');

-- Journals (JSON with array of article titles)
INSERT INTO items (id, title, item_type, publisher_id, metadata) VALUES
(6, 'Journal of Advanced Robotics - Vol 12', 'journal', 2,
 '{"volume": 12, "year": 2022, "editor": "Dr. Helen Moritz", "articles": [
     "Autonomous Drones in Urban Spaces",
     "Swarm Intelligence in Rescue Missions",
     "Adaptive Control in Humanoid Robots",
     "Robot Learning from Demonstration"
 ]}'),
(7, 'Neuroscience Frontier - Issue 8', 'journal', 1,
 '{"volume": 8, "year": 2023, "editor": "Prof. Alan Greene", "articles": [
     "Neural Plasticity in Adults"
 ]}'),
(8, 'Cultural History Review - Q3 Edition', 'journal', 3,
 '{"volume": 21, "year": 2023, "editor": "Dr. Olivia Chen", "articles": [
     "Myth & Memory in East Asia",
     "Oral Traditions and Digital Preservation",
     "Historical Narratives in Postcolonial Societies"
 ]}'),
(9, 'GreenTech Journal - April', 'journal', 2,
 '{"volume": 9, "year": 2022, "editor": "Samuel Takahashi", "articles": [
     "Vertical Farming Breakthroughs",
     "Sustainable Batteries for Grid Storage",
     "AI in Climate Modeling",
     "Smart Irrigation Systems",
     "Eco-Friendly Construction Materials"
 ]}'),
(10, 'Modern Linguistics Digest - Spring', 'journal', 1,
 '{"volume": 6, "year": 2023, "editor": "Dr. Sara König", "articles": [
     "Semantic Drift in Digital Age",
     "Code-Switching Patterns in Bilingual Youth"
 ]}');

-- Multimedia (JSON with nested contributor)
INSERT INTO items (id, title, item_type, publisher_id, metadata) VALUES
(11, 'Ocean Deep - A Documentary', 'multimedia', 3,
 '{"format": "DVD", "duration_min": 92, "language": "English", 
   "contributors": {
      "narrator": "David Stone",
      "director": "Lisa Wong",
      "editor": "James Patel"
   }
 }'),
(12, 'Symphony No. 9 Performance', 'multimedia', 1,
 '{"format": "Blu-Ray", "duration_min": 78, "language": "German", 
   "contributors": {
      "conductor": "Klaus Berger",
      "violinist": "Maria Rossi"
   }
 }'),
(13, 'Machine Learning Explained', 'multimedia', 2,
 '{"format": "MP4", "duration_min": 60, "language": "English", 
   "contributors": {
      "presenter": "Anna Dupont",
      "animator": "John Kim",
      "scriptwriter": "Elena Grant"
   }
 }'),
(14, 'The Story of Silk Road', 'multimedia', 3,
 '{"format": "DVD", "duration_min": 85, "language": "Mandarin", 
   "contributors": {
      "host": "Ming Zhao",
      "director": "Yuki Nakamura",
      "translator": "Akira Tanaka",
      "composer": "Minji Park"
   }
 }'),
(15, 'Astrophysics Today', 'multimedia', 2,
 '{"format": "Blu-Ray", "duration_min": 70, "language": "English", 
   "contributors": {
      "presenter": "Neil Quinn",
      "editor": "Farah Idris",
      "consultant": "Liam Becker"
   }
 }');

-- Show the type for metadata
SELECT JSON_GET_TYPE(metadata)
FROM items;

-- Select all books and extract ISBN and language from metadata
SELECT
    id,
    title,
    metadata::$isbn AS isbn,
    metadata::$language AS language
FROM items
WHERE item_type = 'book'
ORDER BY id;

-- Get all journals, showing editor and number of articles
SELECT
    id,
    title,
    metadata::$editor AS editor,
    JSON_LENGTH(metadata::$articles) AS article_count
FROM items
WHERE item_type = 'journal';

-- Query multimedia items and get contributors as JSON object
SELECT
    SUBSTRING(metadata::$contributors, 1, 60) AS contributors
FROM items
WHERE item_type = 'multimedia';

-- Join books with authors by author_id extracted from JSON metadata
SELECT
    b.id,
    b.title,
    a.name AS author_name,
    a.nationality
FROM items b
JOIN authors a ON a.id = CAST(b.metadata::$author_id AS SIGNED)
WHERE b.item_type = 'book';

-- Search journals where any article title contains 'AI'
SELECT
    i.id,
    i.title,
    i.metadata::$editor AS editor,
    a.table_col AS article
FROM items AS i
JOIN TABLE(JSON_TO_ARRAY(i.metadata::articles)) AS a
WHERE i.item_type = 'journal' AND a.table_col LIKE '%AI%';

-- Add a new JSON field 'edition' to a book's metadata
UPDATE items
SET metadata::$edition = 'Second'
WHERE id = 1 AND item_type = 'book';

SELECT metadata::edition
FROM items
WHERE id = 1 AND item_type = 'book';

-- Remove the 'language' field from a book's metadata
UPDATE items
SET metadata = JSON_DELETE_KEY(metadata, 'language')
WHERE id = 1 AND item_type = 'book';

SELECT metadata::language
FROM items
WHERE id = 1 AND item_type = 'book';
