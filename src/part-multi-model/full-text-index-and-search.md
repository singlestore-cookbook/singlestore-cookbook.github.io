# Chapter 5: Full-Text Index and Search

## Introduction

In this chapter, we'll explore SingleStore's support for Full-Text Index and Search.

There is a wide range of use cases where we may want to perform keyword searches on text. Examples include newspaper articles, journal articles, restaurant reviews, lodging reviews, etc. The requirements for these use cases would consist of the ability to:

- Store and search a, potentially, large body of text.

- Return query results based upon relevancy.

SingleStore can support these requirements by:

- `CHAR`, `VARCHAR`, `TEXT` or `LONGTEXT` data types.

To keep our focus on the database features rather than on sourcing and cleaning real-world data, we'll work with a synthetically generated dataset that represents the structure of academic journal articles.

Each record in this dataset includes:

- A unique identifier for the article.

- A DOI (Digital Object Identifier).

- A title that resembles those found in peer-reviewed publications.

- A list of authors formatted in a conventional academic style.

- Institutional affiliations.

- The journal name.

- The publication date.

- An abstract summarizing the article in concise, academic-style language.

- A body containing several paragraphs of realistic, topic-consistent text.

- References.

The content is entirely artificial, created using text-generation techniques, yet follows the style and tone of actual research papers. This ensures we can demonstrate realistic search and indexing scenarios while avoiding copyright or licensing restrictions. We'll store these journal articles in SingleStore, create a `FULLTEXT` index and then perform some queries using the full-text capabilities of SingleStore.

## Create the Database and Table

In the SingleStore Portal, let's use the **SQL Editor** to create a new database. Call this `fulltext_db`, as follows:

```sql
CREATE DATABASE IF NOT EXISTS fulltext_db;
```

We'll also create the articles table, as follows:

```sql
USE fulltext_db;

DROP TABLE IF EXISTS articles;
CREATE TABLE IF NOT EXISTS articles (
    id           VARCHAR(50) NOT NULL PRIMARY KEY,
    doi          VARCHAR(100),
    title        VARCHAR(500),
    authors      TEXT,
    affiliations TEXT,
    journal      VARCHAR(255),
    pub_date     DATE,
    abstract     TEXT,
    body         LONGTEXT,
    refs         LONGTEXT,
    FULLTEXT USING VERSION 2(title, abstract, body)
);
```

The article contents are stored in the body column using `LONGTEXT`. We also create an index on the **title**, **abstract** and **body** columns using `FULLTEXT`. Stopwords are ignored as they occur very frequently. SingleStore's default list of stopwords is as follows:

```text
a, an, and, are, as, at, be, but, by, for, if, in, into, is, it, no, not, of, on, or, such, that, the, their, then, there, these, they, this, to, was, will, with
```

## Fill out the Notebook

Let's now create a new Python notebook. We'll call it **data_loader_for_fulltext**.

We'll create a new DataFrame, as follows:

```python
articles_csv_url = ...

articles_df = pd.read_csv(articles_csv_url)
```

This reads the CSV file and creates a DataFrame called `articles_df`. The CSV file contains 10,000 synthetically generated journal articles.

We are now ready to write the DataFrame to SingleStore. First, we'll create a connection:

```python
from sqlalchemy import *

db_connection = create_engine(connection_url)
```

Next, we'll ensure that the table is empty:

```python
with db_connection.begin() as conn:
    conn.execute(text("TRUNCATE TABLE articles;"))
```

Then we'll write the DataFrame to SingleStore:

```python
articles_df.to_sql(
    "articles",
    con = db_connection,
    if_exists = "append",
    index = False,
    chunksize = 1000
)
```

This will write the DataFrame to the `articles` table in the `fulltext_db` database.

Next, we'll run the following command from the **SQL Editor**:

```sql
OPTIMIZE TABLE articles FLUSH;
```

When inserting new rows, SingleStore may delay updating the full-text index until later, so running `OPTIMIZE TABLE <table_name> FLUSH` makes the new data searchable immediately.

## Example Queries

Now that we have built our system, we can run some queries. SingleStore supports two main functions for use with full-text:

- `MATCH`: Returns a relevance score based on the BM25 algorithm. The score is always greater than or equal to 0 and higher scores indicate a better match.

- `BM25`: Calculates a BM25 relevance score for the specified search terms. Unlike `MATCH`, which works at the segment level, BM25 produces more consistent scoring at the partition level.

Let's see some examples of these functions.

First, let's find all journal articles where the body contains the word **machine**.

```sql
SELECT title
FROM articles
WHERE MATCH(TABLE articles) AGAINST ('body:machine')
LIMIT 5;
```

Example output:

```text
+--------------------------------------------------------------------------------------+
| title                                                                                |
+--------------------------------------------------------------------------------------+
| A comparative analysis of random forests and classical methods for materials science |
| Scalable approaches to epidemiology using a Bayesian approach                        |
| Scalable approaches to machine learning using unsupervised pretraining               |
| Scalable approaches to bioinformatics using unsupervised pretraining                 |
| Assessing the impact of a novel regularization scheme on natural language processing |
+--------------------------------------------------------------------------------------+
```

Next, let's find articles that contain the exact phrase **neural network** anywhere in the title, as follows:

```sql
SELECT title
FROM articles
WHERE MATCH(TABLE articles) AGAINST ('title:"neural networks"')
LIMIT 5;
```

Example output:

```text
+---------------------------------------------------------------------------------------------+
| title                                                                                       |
+---------------------------------------------------------------------------------------------+
| A comparative analysis of graph neural networks and classical methods for genomics          |
| Scalable approaches to robotics using graph neural networks                                 |
| Towards better materials science: a graph neural networks for materials science             |
| A comparative analysis of graph neural networks and classical methods for synthetic biology |
| A comparative analysis of graph neural networks and classical methods for epidemiology      |
+---------------------------------------------------------------------------------------------+
```

Next, let's try a wildcard search in the article title. The `*` is the wildcard and will match anything that starts with **immun**, such as **immune**, **immunology** and **immunization**:

```sql
SELECT title
FROM articles
WHERE MATCH(TABLE articles) AGAINST ('title:immun*')
LIMIT 5;
```

Example output:

```text
+---------------------------------------------------------------------------------------+
| title                                                                                 |
+---------------------------------------------------------------------------------------+
| A comparative analysis of reinforcement learning and classical methods for immunology |
| Towards better immunology: a a multi-modal encoder for immunology                     |
| Understanding immunology through reinforcement learning                               |
| Assessing the impact of reinforcement learning on immunology                          |
| Improving immunology: methods and applications                                        |
+---------------------------------------------------------------------------------------+
```

In the following query, we'll use a Boolean `AND` along with a wildcard to look for any articles that have the word **machine** and anything that starts with **learn** in the abstract, as follows:

```sql
SELECT SUBSTRING(title, 1, 60) AS title
FROM articles
WHERE MATCH(TABLE articles) AGAINST ('abstract:machine AND abstract:learn*')
LIMIT 5;
```

Example output:

```text
+--------------------------------------------------------------+
| title                                                        |
+--------------------------------------------------------------+
| A comparative analysis of finite element analysis and classi |
| Assessing the impact of reinforcement learning on climate mo |
| A comparative analysis of Monte Carlo simulation and classic |
| A comparative analysis of finite element analysis and classi |
| A comparative analysis of CRISPR-Cas9 editing and classical  |
+--------------------------------------------------------------+
```

Next, something a little more complex. We'll search for articles where the body contains a word starting with **data**, but doesn't contain any word starting with **sens**:

```sql
SELECT SUBSTRING(title, 1, 60) AS title
FROM articles
WHERE MATCH (TABLE articles) AGAINST ('body:(+data*) AND NOT body:sens*')
LIMIT 5;
```

Example output:

```text
+--------------------------------------------------------------+
| title                                                        |
+--------------------------------------------------------------+
| Assessing the impact of a novel regularization scheme on qua |
| Scalable approaches to synthetic biology using unsupervised  |
| Towards better materials science: a graph neural networks fo |
| Improving deep learning: methods and applications            |
| Improving machine learning: methods and applications         |
+--------------------------------------------------------------+
```

The `~` character can also be used for fuzzy searches. Here is an example where we use the British English spelling for **modelling** and look for any matches where there is a 1-character change, addition or deletion. This is useful for catching typos, alternate spellings or small differences in wording:

```sql
SELECT SUBSTRING(title, 1, 60) AS title
FROM articles
WHERE MATCH (TABLE articles) AGAINST ('title:modelling~1')
LIMIT 5;
```

Example output:

```text
+--------------------------------------------------------------+
| title                                                        |
+--------------------------------------------------------------+
| Understanding climate modeling through a multi-modal encoder |
| A comparative analysis of a multi-modal encoder and classica |
| Improving climate modeling: methods and applications         |
| A comparative analysis of CRISPR-Cas9 editing and classical  |
| A comparative analysis of a convolutional neural network and |
+--------------------------------------------------------------+
```

Let's now look at some examples of BM25. First, a query to find articles whose body text is most relevant to the word **science** and show their relevance scores:

```sql
SELECT SUBSTRING(title, 1, 60) AS title, ROUND(BM25(articles,'body:science'), 4) AS score
FROM articles
WHERE BM25(articles,'body:science')
ORDER BY score DESC
LIMIT 5;
```

Example output:

```text
+--------------------------------------------------------------+--------+
| title                                                        | score  |
+--------------------------------------------------------------+--------+
| Understanding computer vision through CRISPR-Cas9 editing    | 1.1970 |
| Understanding cancer biology through a Bayesian approach     | 1.1613 |
| Towards better immunology: a unsupervised pretraining for im | 1.1591 |
| Scalable approaches to deep learning using unsupervised pret | 1.1468 |
| Assessing the impact of CRISPR-Cas9 editing on synthetic bio | 1.1434 |
+--------------------------------------------------------------+--------+
```

We can also use Boolean operators with BM25. Here we are searching for articles where the word **machine** appears in either the title or the body, ranked by relevance:

```sql
SELECT SUBSTRING(title, 1, 60) AS title, ROUND(BM25(articles,'title:machine OR body:machine'), 4) AS score
FROM articles
WHERE BM25(articles,'title:machine OR body:machine')
ORDER BY score DESC
LIMIT 5;
```

Example output:

```text
+--------------------------------------------------------------+--------+
| title                                                        | score  |
+--------------------------------------------------------------+--------+
| Towards better machine learning: a unsupervised pretraining  | 2.6486 |
| Towards better machine learning: a random forests for machin | 2.6309 |
| Towards better machine learning: a reinforcement learning fo | 2.5842 |
| Towards better machine learning: a unsupervised pretraining  | 2.5698 |
| Towards better machine learning: a Monte Carlo simulation fo | 2.5352 |
+--------------------------------------------------------------+--------+
```

## Summary

In this chapter, we explored the powerful full-text search capabilities built into SingleStore, enabling efficient and flexible text-based queries. We focused on two primary functions: `MATCH` and `BM25`.

`MATCH` allows us to perform natural language searches and phrase matching with support for logical operators like `AND`, `OR`, `NOT` and proximity searches. It also supports both single-character (`?`) and multi-character (`*`) wildcard searches, making it easy to find partial matches or variations of search terms within specific columns.

`BM25`, on the other hand, provides a robust ranking algorithm that scores the relevance of each record based on how well the text matches the search terms, allowing us to sort results by their importance or relevance to the query.

We also covered how to target specific fields within our data for more precise searching and how to combine multiple fields in queries.
