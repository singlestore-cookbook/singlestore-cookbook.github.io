# Chapter 16: Running Sentiment Analysis inside the Database with WebAssembly

## Introduction

WebAssembly (Wasm) is a binary instruction format for a stack-based virtual machine. Wasm enables developers to use existing code from programming languages, such as C, C++ and Rust, as part of their application development process. However, Wasm is not just for the web and today is moving in exciting new directions. For example, one use-case would be to run Wasm code directly on data already stored in the database - an example of co-locating computation with data. Using Wasm to extend the capabilities of a database system opens up opportunities to develop many new applications. SingleStore supports Wasm through Code Engine[^1] and, in this chapter, we'll see how to build a Wasm UDF to perform sentiment analysis on data already stored in SingleStore.

We'll need to perform a few steps to prepare our development environment and the following sections will show how to do this. We'll also use Rust to create our Wasm UDF.

## Setup Local Wasm Development Environment

We can quickly create a local Wasm development environment using a few steps. Let's work through these steps, one-by-one.

### Install the Software

First, we'll download the wasi-sdk[^2]. We'll use `wasi-sdk-27.0...`, the latest version available when writing this book. Download the archive matching your platform from the wasi-sdk releases page.

Using an example, we'll unpack the file to the `/opt` directory, as follows:

```shell
sudo tar xzvf /path/to/wasi-sdk-27.0-<platform>.tar.gz -C /opt
```

We'll replace `/path/to/` with the actual path to which we downloaded and `<platform>` with the platform. We'll also need to ensure that we add the `bin` directory to our PATH variable, as follows:

```shell
export PATH=/opt/wasi-sdk-27.0-<platform>/bin:$PATH
```

Second, we'll download and install the Rust toolchain, as follows:

```shell
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

To configure the current shell, we'll need to run:

```shell
source "$HOME/.cargo/env"
```

Next, we'll install `wit-bindgen-cli`, as follows:

```shell
cargo install wit-bindgen-cli
```

Then, we'll add `wasm32-wasip1` to the Rust toolchain as it is not installed by default:

```shell
rustup target add wasm32-wasip1
```

To deploy our Wasm module to SingleStore, we'll use the `pushwasm` tool. First, we'll clone the GitHub repo to a convenient location:

```shell
git clone https://github.com/singlestore-labs/pushwasm
```

Next, we'll change to the `pushwasm` directory and build the code, as follows:

```shell
cd pushwasm
cargo build --release
```

A new file called `pushwasm` should be written to `target/release` and this directory should be added to our `PATH` variable:

```shell
export PATH=/path/to/pushwasm/target/release:$PATH
```

We’ll replace `/path/to/` with the actual path.

We may also need to run the following to ensure a successful pushwasm build:

```shell
sudo apt install libssl-dev
```

### Initialize the Source Tree

Next, let's create a new directory called `workdir` in our home folder:

```shell
cd
mkdir workdir
cd workdir
```

From the `workdir`, we'll now create a skeletal Rust source tree, as follows:

```shell
cargo init --vcs none --lib
```

### Create the wit File

In our `workdir`, we'll now create a file called `sentimentable.wit` that contains the interface definition. In this file, we'll add the following:

```text
record polarity-scores {
    compound: float64,
    positive: float64,
    negative: float64,
    neutral: float64,
}

sentimentable: func(input: string) -> list<polarity-scores>
```

We'll define a function `sentimentable` that will take a string, perform sentiment analysis on that string and return a list of polarity scores - numeric values indicating how positive, negative or neutral the text is.

### Implement and Compile

In our workdir, we'll replace the existing contents of `Cargo.toml` with the following code:

```text
[package]
name = "sentimentable"
version = "0.1.0"
edition = "2021"

# See more keys and their definitions at https://doc.rust-lang.org/cargo/reference/manifest.html

[dependencies]
wit-bindgen-rust = { git = "https://github.com/bytecodealliance/wit-bindgen.git", rev = "60e3c5b41e616fee239304d92128e117dd9be0a7" }

vader_sentiment = { git = "https://github.com/ckw017/vader-sentiment-rust" }
lazy_static = "1.4.0"

[lib]
crate-type = ["cdylib"]
```

Now we need to add the code for `sentimentable`, so we'll navigate to the `src` directory in our `workdir` and locate the `lib.rs` file. In the `lib.rs` file, we'll replace the existing contents with the following code:

```text
wit_bindgen_rust::export!("sentimentable.wit");
use crate::sentimentable::PolarityScores;
struct Sentimentable;
impl sentimentable::Sentimentable for Sentimentable {

    fn sentimentable(input: String) -> Vec<PolarityScores> {
        lazy_static::lazy_static! {
            static ref ANALYZER: vader_sentiment::SentimentIntensityAnalyzer<'static> =
                vader_sentiment::SentimentIntensityAnalyzer::new();
        }

let scores = ANALYZER.polarity_scores(input.as_str());
        vec![PolarityScores {
            compound: scores["compound"],
            positive: scores["pos"],
            negative: scores["neg"],
            neutral: scores["neu"],
        }]
    }
}
```

Our code uses VADER[^3] (Valence Aware Dictionary and sEntiment Reasoner). VADER is a lexicon and rule-based sentiment analysis tool that can interpret and classify emotions.

Next, we'll go back up one directory level:

```shell
cd ..
```

We'll now build the Wasm module:

```shell
cargo build --target wasm32-wasip1 --release
```

A new Wasm file should be written to `workdir/target/wasm32-wasip1/release/sentimentable.wasm`.

### Deploy

In SingleStore Cloud, we'll use the **SQL Editor** to create a new database called `sentiment_db`, as follows:

```sql
CREATE DATABASE IF NOT EXISTS sentiment_db;
```

Next, from the command line, we'll use the `pushwasm` tool to push our Wasm module into SingleStore, as follows:

```shell
pushwasm tvf --force --conn 'mysql://admin:<password>@<host>:3306/sentiment_db' --wit ./sentimentable.wit --wasm ./target/wasm32-wasip1/release/sentimentable.wasm --name sentimentable
```

We'll replace the `<password>` and `<host>` with the values from our SingleStore Cloud account.

After a short time, we should see the following message:

```text
Wasm function was created successfully.
```

From SingleStore Cloud, we can also check that the function was created, as follows:

```sql
USE sentiment_db;

SHOW FUNCTIONS;
```

Example output:

```text
+---------------------------+-----------------------+---------+-------------+--------------+------+---------+
| Functions_in_sentiment_db | Function Type         | Definer | Data Format | Runtime Type | Link | Options |
+---------------------------+-----------------------+---------+-------------+--------------+------+---------+
| sentimentable             | Table Valued Function | admin@% |             | Wasm         |      |         |
+---------------------------+-----------------------+---------+-------------+--------------+------+---------+
```

### Run in the Database

We can quickly test our function, as follows:

```sql
SELECT * FROM sentimentable('The movie was great');
```

Example output:

```text
+--------------------+--------------------+----------+--------------------+
| compound           | positive           | negative | neutral            |
+--------------------+--------------------+----------+--------------------+
| 0.6248933269389457 | 0.5774647887323944 |        0 | 0.4225352112676057 |
+--------------------+--------------------+----------+--------------------+
```

VADER can consider capitalization, so let's try:

```sql
SELECT * FROM sentimentable('The movie was GREAT!');
```

Example output:

```text
+--------------------+--------------------+----------+---------------------+
| compound           | positive           | negative | neutral             |
+--------------------+--------------------+----------+---------------------+
| 0.7290259049799065 | 0.6307692307692307 |        0 | 0.36923076923076925 |
+--------------------+--------------------+----------+---------------------+
```

We see that the values changed, showing a stronger positive sentiment expressed by capitalization.

## Create the Database Tables

In the SingleStore Portal, we'll use the **SQL Editor** to create several database tables, as follows:

```sql
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
```

We'll use synthetic data for the `tick` table.

We'll also load synthetic data into the `raw_fictitious_headlines` table and apply the Wasm function to the `headline` column and store the results in the `stock_sentiment` table.

The synthetic dataset was generated using a random-walk model to simulate daily stock prices for fictitious stock symbols with open, high, low, close and volume values sampled from realistic distributions, to model market volatility and liquidity. News headlines were programmatically constructed from templated phrases combined with company names and market events, such as earnings surprises, regulatory actions and CEO comments, to ensure linguistic diversity.

## Fill out the Notebook

Let's now create a new Python notebook. We'll call it **data_loader_for_sentiment**.

We'll create a new DataFrame for the tick data, as follows:

```python
tick_csv_url = ...

tick_df = pd.read_csv(tick_csv_url)
```

This reads the CSV file and creates a DataFrame called `tick_df`.

In the next code cell, we'll remove incomplete rows:

```python
tick_df = tick_df.dropna()
```

and also remove one extreme outlier:

```python
tick_df = tick_df[tick_df["volume"] <= 2_147_483_647]
```

Next, let's get the number of rows:

```python
tick_df.count()
```

Executing this will return the value `379764`.

We'll rename some columns to match our table schema, as follows:

```python
tick_df = tick_df.rename(columns = {"date": "ts", "Name": "symbol"})
```

and sort the data:

```python
tick_df = tick_df.sort_values(by = ["ts", "symbol"])
```

In the next code cell, we'll take a look at the structure of the DataFrame:

```python
tick_df.head()
```

It should look like this:

```text
              ts    open    high     low   close    volume   symbol
0     2013-01-02  743.98  756.93  736.15  745.68   9142645  BBRQ-FX
755   2013-01-02  418.92  426.82  415.64  420.77   2281501  BBYX-FX
1510  2013-01-02  192.05  192.73  190.29  192.03    194074  BFDS-FX
2265  2013-01-02  108.47  109.55  107.06  108.30   6371511  BGRP-FX
3020  2013-01-02  188.60  191.23  187.27  187.60  12854613  BJBY-FX
```

Next, we'll load the synthetic raw fictitious headlines:

```python
raw_csv_url = ...

raw_df = pd.read_csv(raw_csv_url)
```

We are now ready to write the DataFrames to SingleStore. First, we'll create a connection:

```python
from sqlalchemy import *

db_connection = create_engine(connection_url)
```

Next, we'll ensure that all the tables are empty:

```python
tables = ["tick", "stock_sentiment", "raw_fictitious_headlines"]

with db_connection.begin() as conn:
    for table in tables:
        conn.execute(text(f"TRUNCATE TABLE {table};"))
```

Finally, we'll write the DataFrames to SingleStore. First the `tick` data:

```python
tick_df.to_sql(
    "tick",
    con = db_connection,
    if_exists = "append",
    index = False,
    chunksize = 1000
)
```

and then the `raw_fictitious_headlines` data:

```python
raw_df.to_sql(
    "raw_fictitious_headlines",
    con = db_connection,
    if_exists = "append",
    index = False,
    chunksize = 1000
)
```

Once the data are loaded, we'll use the **SQL Editor** to apply the Wasm function and store the data in the `stock_sentiment` table, as follows:

```sql
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
```

Once this is complete, we'll also add an index:

```sql
CREATE INDEX idx_stock_sentiment_symbol_ts ON stock_sentiment(symbol, ts);
```

Now we're ready to run some queries.

## Example Queries

First, a quick test:

```sql
SELECT *
FROM sentimentable('Stocks rally as earnings beat expectations') AS s;
```

Example output:

```text
+----------+----------+----------+---------+
| compound | positive | negative | neutral |
+----------+----------+----------+---------+
|        0 |        0 |        0 |       1 |
+----------+----------+----------+---------+
```

This sanity check applies the sentiment function directly to a sample string. The neutral result is expected, as VADER's lexicon is tuned primarily for social media and general language, so financial terms such as 'rally' and 'beat' are not scored as strongly positive by default. The result confirms the function is working correctly and serves as a useful reminder that VADER will classify many short, factual financial headlines as neutral.

Next, let's apply `sentimentable` to the `stock_sentiment` table:

```sql
SELECT
    symbol,
    DATE(ts) AS ts,
    LEFT(headline, 30) AS headline,
    ROUND(positive, 3) AS positive,
    ROUND(negative, 3) AS negative,
    ROUND(neutral, 3) AS neutral
FROM stock_sentiment
LIMIT 10;
```

Example output:

```text
+---------+------------+--------------------------------+----------+----------+---------+
| symbol  | ts         | headline                       | positive | negative | neutral |
+---------+------------+--------------------------------+----------+----------+---------+
| CBDR-FX | 2014-01-22 | CBDR-FX stock strong performan |    0.355 |    0.000 |   0.645 |
| CHWP-FX | 2015-04-01 | CHWP-FX stock minor declines a |    0.167 |    0.000 |   0.833 |
| HRDM-FX | 2014-01-30 | HRDM-FX stock exceeding analys |    0.249 |    0.000 |   0.751 |
| JKYV-FX | 2015-01-02 | JKYV-FX faces regulatory inves |    0.089 |    0.057 |   0.854 |
| LNZR-FX | 2014-10-30 | LNZR-FX announces Cultivate Vi |    0.405 |    0.000 |   0.595 |
| LQHS-FX | 2015-10-30 | LQHS-FX completes acquisition  |    0.000 |    0.000 |   1.000 |
| SHBY-FX | 2014-01-03 | SHBY-FX impacted by Market beg |    0.449 |    0.000 |   0.551 |
| SHRN-FX | 2014-10-23 | SHRN-FX reports Q4 earnings: r |    0.000 |    0.000 |   1.000 |
| SPRL-FX | 2014-10-01 | SPRL-FX rumored to merge with  |    0.000 |    0.000 |   1.000 |
| TGLK-FX | 2014-01-24 | TGLK-FX impacted by Market beg |    0.356 |    0.000 |   0.644 |
+---------+------------+--------------------------------+----------+----------+---------+
```

This query spot-checks the inserted headlines, showing symbols, dates, truncated headlines and their sentiment breakdown. The results demonstrate that the synthetic headlines were ingested correctly and that sentiment is being captured at the per-headline level.

Now, let's aggregate sentiment by stock.

```sql
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
```

Example output:

```text
+---------+------------+--------------+--------------+-------------+---------------+
| symbol  | ts         | avg_positive | avg_negative | avg_neutral | num_headlines |
+---------+------------+--------------+--------------+-------------+---------------+
| BBRQ-FX | 2013-01-04 |        0.124 |        0.257 |       0.619 |             1 |
| BBRQ-FX | 2013-01-10 |        0.000 |        0.091 |       0.909 |             1 |
| BBRQ-FX | 2013-01-17 |        0.140 |        0.000 |       0.860 |             1 |
| BBRQ-FX | 2013-01-31 |        0.000 |        0.000 |       1.000 |             1 |
| BBRQ-FX | 2013-04-17 |        0.157 |        0.000 |       0.843 |             1 |
| BBRQ-FX | 2013-05-08 |        0.000 |        0.000 |       1.000 |             1 |
| BBRQ-FX | 2013-05-29 |        0.189 |        0.062 |       0.749 |             1 |
| BBRQ-FX | 2013-07-01 |        0.000 |        0.000 |       1.000 |             1 |
| BBRQ-FX | 2013-07-02 |        0.000 |        0.000 |       1.000 |             1 |
| BBRQ-FX | 2013-07-11 |        0.000 |        0.000 |       1.000 |             1 |
+---------+------------+--------------+--------------+-------------+---------------+
```

By grouping on `symbol` and `DATE(ts)`, this query shows average sentiment scores and headline counts. The results confirm that daily aggregation is possible and highlights variation in sentiment across dates for the same stock.

Next, we'll join two tables.

```sql
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
```

Example output:

```text
+---------+------------+--------+----------+----------+---------+
| symbol  | ts         | close  | positive | negative | neutral |
+---------+------------+--------+----------+----------+---------+
| BBRQ-FX | 2013-01-04 | 772.95 |    0.124 |    0.257 |   0.619 |
| BBRQ-FX | 2013-01-10 | 752.72 |    0.000 |    0.091 |   0.909 |
| BBRQ-FX | 2013-01-17 | 788.43 |    0.140 |    0.000 |   0.860 |
| BBRQ-FX | 2013-01-31 | 689.56 |    0.000 |    0.000 |   1.000 |
| BBRQ-FX | 2013-04-17 | 890.02 |    0.157 |    0.000 |   0.843 |
| BBRQ-FX | 2013-05-08 | 842.17 |    0.000 |    0.000 |   1.000 |
| BBRQ-FX | 2013-05-29 | 932.86 |    0.189 |    0.062 |   0.749 |
| BBRQ-FX | 2013-07-01 | 883.61 |    0.000 |    0.000 |   1.000 |
| BBRQ-FX | 2013-07-02 | 872.43 |    0.000 |    0.000 |   1.000 |
| BBRQ-FX | 2013-07-11 | 921.76 |    0.000 |    0.000 |   1.000 |
+---------+------------+--------+----------+----------+---------+
```

The join aligned sentiment with daily closing prices, showing how sentiment scores can be compared directly with market performance. The output confirms that the temporal and symbol keys line up correctly, allowing correlation analysis between news and stock movement.

Now, let's find the most positive headlines.

```sql
SELECT
    symbol,
    DATE(ts) AS ts,
    LEFT(headline, 30) AS headline,
    ROUND(positive, 3) AS positive
FROM stock_sentiment
ORDER BY positive DESC
LIMIT 10;
```

Example output:

```text
+---------+------------+--------------------------------+----------+
| symbol  | ts         | headline                       | positive |
+---------+------------+--------------------------------+----------+
| GQVB-FX | 2014-06-12 | GQVB-FX announces Optimize Dyn |    0.592 |
| WZWQ-FX | 2013-10-15 | WZWQ-FX announces Innovate Dyn |    0.592 |
| SXJS-FX | 2014-06-19 | SXJS-FX announces Optimize Rob |    0.583 |
| FNDN-FX | 2014-01-15 | FNDN-FX announces Engage Dynam |    0.556 |
| YSXQ-FX | 2014-04-08 | YSXQ-FX announces Harness Proa |    0.529 |
| VRFZ-FX | 2013-10-22 | VRFZ-FX announces Deliver Dyna |    0.518 |
| MHNG-FX | 2014-07-07 | MHNG-FX announces Engage Rich  |    0.511 |
| BYPT-FX | 2013-07-04 | BYPT-FX announces Brand Robust |    0.506 |
| JRQF-FX | 2013-10-18 | JRQF-FX faces regulatory inves |    0.496 |
| FBPH-FX | 2013-12-11 | FBPH-FX faces regulatory inves |    0.496 |
+---------+------------+--------------------------------+----------+
```

Sorting by positive reveals the most upbeat headlines. The results are dominated by product launch announcements.

Next, let's do the opposite and find the most negative headlines.

```sql
SELECT
    symbol,
    DATE(ts) AS ts,
    LEFT(headline, 30) AS headline,
    ROUND(negative, 3) AS negative
FROM stock_sentiment
ORDER BY negative DESC
LIMIT 10;
```

Example output:

```text
+---------+------------+--------------------------------+----------+
| symbol  | ts         | headline                       | negative |
+---------+------------+--------------------------------+----------+
| FSLV-FX | 2015-07-30 | FSLV-FX suffers CEO scandal sp |    0.680 |
| RFMZ-FX | 2014-04-09 | RFMZ-FX suffers CEO scandal sp |    0.680 |
| FPPT-FX | 2013-07-18 | FPPT-FX suffers CEO scandal sp |    0.680 |
| DJMM-FX | 2015-07-15 | DJMM-FX suffers CEO scandal sp |    0.680 |
| CMJH-FX | 2014-07-29 | CMJH-FX suffers CEO scandal sp |    0.680 |
| SZDQ-FX | 2013-01-25 | SZDQ-FX suffers CEO scandal sp |    0.680 |
| GDYP-FX | 2014-04-17 | GDYP-FX suffers CEO scandal sp |    0.680 |
| YBVX-FX | 2013-07-15 | YBVX-FX suffers CEO scandal sp |    0.680 |
| HRDM-FX | 2013-10-25 | HRDM-FX suffers CEO scandal sp |    0.680 |
| QKQG-FX | 2015-10-19 | QKQG-FX suffers CEO scandal sp |    0.680 |
+---------+------------+--------------------------------+----------+
```

Sorting by negative highlights the most downbeat headlines, dominated by CEO scandal headlines. This shows that the sentiment engine clearly distinguishes severe negative events, assigning strong negative scores consistently across companies.

Next, let's compare the average daily sentiment against the daily close price.

```sql
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
```

Example output:

```text
+---------+------------+-------------+--------------+--------------+-------------+
| symbol  | ts         | daily_close | avg_positive | avg_negative | avg_neutral |
+---------+------------+-------------+--------------+--------------+-------------+
| BBRQ-FX | 2013-01-04 |      772.95 |        0.124 |        0.257 |       0.619 |
| BBRQ-FX | 2013-01-10 |      752.72 |        0.000 |        0.091 |       0.909 |
| BBRQ-FX | 2013-01-17 |      788.43 |        0.140 |        0.000 |       0.860 |
| BBRQ-FX | 2013-01-31 |      689.56 |        0.000 |        0.000 |       1.000 |
| BBRQ-FX | 2013-04-17 |      890.02 |        0.157 |        0.000 |       0.843 |
| BBRQ-FX | 2013-05-08 |      842.17 |        0.000 |        0.000 |       1.000 |
| BBRQ-FX | 2013-05-29 |      932.86 |        0.189 |        0.062 |       0.749 |
| BBRQ-FX | 2013-07-01 |      883.61 |        0.000 |        0.000 |       1.000 |
| BBRQ-FX | 2013-07-02 |      872.43 |        0.000 |        0.000 |       1.000 |
| BBRQ-FX | 2013-07-11 |      921.76 |        0.000 |        0.000 |       1.000 |
+---------+------------+-------------+--------------+--------------+-------------+
```

This query aggregates average daily sentiment and joins it to closing prices. The results enable exploratory analysis of whether sentiment leads or lags price moves.

Now, let's compare stored sentiment against using the Wasm function dynamically.

```sql
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
```

Example output:

```text
+---------+------------+--------------------------------+------------+
| symbol  | ts         | headline                       | comparison |
+---------+------------+--------------------------------+------------+
| BBRQ-FX | 2013-05-29 | BBRQ-FX announces Streamline W | match      |
| BBRQ-FX | 2013-10-29 | BBRQ-FX stock steady growth af | match      |
| BBRQ-FX | 2014-10-14 | BBRQ-FX delays Transform E-Bus | match      |
| BBRQ-FX | 2015-10-01 | BBRQ-FX impacted by Q3 earning | match      |
| BBRQ-FX | 2015-10-09 | BBRQ-FX faces regulatory inves | match      |
| BBRQ-FX | 2013-10-07 | BBRQ-FX announces Extend Leadi | match      |
| BBRQ-FX | 2014-10-22 | BBRQ-FX stock record revenues  | match      |
| BBRQ-FX | 2014-10-21 | BBRQ-FX receives analyst upgra | match      |
| BBRQ-FX | 2013-01-04 | BBRQ-FX suffers sudden geopoli | match      |
| BBRQ-FX | 2013-01-10 | BBRQ-FX faces regulatory inves | match      |
+---------+------------+--------------------------------+------------+
```

Here we validated whether stored values in `stock_sentiment` match fresh calls to the `sentimentable` function. The results for `BBRQ-FX` headlines all showed "match," confirming that the ingestion pipeline is consistent and reproducible.

Finally, let's perform a spot-check for discrepancies across a date range.

```sql
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
```

Example output:

```text
+---------+------------+--------------------------------+-----------------+-----------------+----------------+----------+----------+---------+
| BBRQ-FX | 2013-07-02 | BBRQ-FX rumored to merge with  |           0.000 |           0.000 |          1.000 |    0.000 |    0.000 |   1.000 |
| BBRQ-FX | 2013-07-01 | BBRQ-FX CEO Sherri Baker comme |           0.000 |           0.000 |          1.000 |    0.000 |    0.000 |   1.000 |
| BBRQ-FX | 2013-01-17 | BBRQ-FX reports Q2 earnings: i |           0.140 |           0.000 |          0.860 |    0.140 |    0.000 |   0.860 |
| BBRQ-FX | 2013-05-08 | BBRQ-FX rumored to merge with  |           0.000 |           0.000 |          1.000 |    0.000 |    0.000 |   1.000 |
| BBRQ-FX | 2013-07-11 | BBRQ-FX completes acquisition  |           0.000 |           0.000 |          1.000 |    0.000 |    0.000 |   1.000 |
| BBRQ-FX | 2013-07-29 | BBRQ-FX reports Q2 earnings: s |           0.191 |           0.000 |          0.809 |    0.191 |    0.000 |   0.809 |
| BBRQ-FX | 2013-05-29 | BBRQ-FX announces Streamline W |           0.189 |           0.062 |          0.749 |    0.189 |    0.062 |   0.749 |
| BBRQ-FX | 2013-10-29 | BBRQ-FX stock steady growth af |           0.302 |           0.000 |          0.698 |    0.302 |    0.000 |   0.698 |
| BBRQ-FX | 2013-10-07 | BBRQ-FX announces Extend Leadi |           0.254 |           0.000 |          0.746 |    0.254 |    0.000 |   0.746 |
| BBRQ-FX | 2013-01-04 | BBRQ-FX suffers sudden geopoli |           0.124 |           0.257 |          0.619 |    0.124 |    0.257 |   0.619 |
+---------+------------+--------------------------------+-----------------+-----------------+----------------+----------+----------+---------+
```

Note that `BETWEEN '2013-01-01' AND '2014-01-01'` is inclusive of the full year 2013, so rows from any date in that range may appear in the output, not just January. The side-by-side numbers match, confirming there's no drift between stored values and live scoring and that our backfill worked as intended.

## Summary

In this chapter, we saw how to build a complete sentiment-enriched market data pipeline using SingleStore and WebAssembly. We began by setting up the development environment, including installing the WASI SDK, configuring the Rust toolchain and compiling our custom sentiment analysis function into WebAssembly. Using `pushwasm`, we deployed this function directly into SingleStore, enabling in-database sentiment scoring via the `sentimentable` function.

Next, we used a synthetic dataset designed to mimic realistic S&P 500 market activity. Stock price data were produced using a random-walk model with daily OHLCV values, while news headlines were programmatically created from templates incorporating company tickers and financial events. Headlines were timestamped alongside price data to support time-aligned analysis. Dates in headlines were randomly distributed across calendar days, while tick data covers trading days only. As a result, headlines falling on weekends will have no matching price row, which is why the join in the queries only returns a subset of dates. Once loaded into SingleStore, sentiment scores were automatically computed and stored in a dedicated `stock_sentiment` table, while raw fictitious headlines were preserved for auditability.

With the data in place, we executed a series of analytical queries. These included headline-level sentiment extraction, symbol-level aggregation and temporal comparisons between daily sentiment and closing prices. We also joined sentiment with tick data to examine relationships between news flow and market movements, ranked the most positive and negative headlines and validated consistency between stored sentiment scores and real-time evaluations from the WebAssembly function.

Through this workflow, we showed how SingleStore can unify structured time-series market data with unstructured text sentiment, all processed in-database with high performance. The chapter highlights the practicality of using user-defined WebAssembly functions for advanced analytics, the value of synthetic data generation for experimentation and the insights that emerge when market prices and sentiment are analyzed together.

## Acknowledgements

I thank Peter Vetere[^4] for his assistance and patience during the development of the original code example used in this chapter.

[^1]:  https://docs.singlestore.com/cloud/reference/code-engine-powered-by-wasm/

[^2]:  https://github.com/WebAssembly/wasi-sdk/releases

[^3]:  https://github.com/cjhutto/vaderSentiment

[^4]:  https://www.linkedin.com/in/pvetere/
