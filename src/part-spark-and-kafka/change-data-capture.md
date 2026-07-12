# Chapter 9: Change Data Capture

## Introduction

Change Data Capture (CDC) is a way to keep track of changes that happen in a database or a system. SingleStore provides a CDC solution that can be used to stream data from a number of different sources into SingleStore. In this chapter, we'll stream data from MongoDB Atlas into SingleStore.

To demonstrate the CDC solution, we'll first use a Jupyter notebook to create some data to represent stages in a Customer Relationship Management (CRM) system. We'll then store the data in a MongoDB Atlas cluster. Finally, we'll use a CDC pipeline in SingleStore Cloud to propagate the data from MongoDB Atlas to a SingleStore database.

## MongoDB Atlas

We'll create a free MongoDB Atlas account and configure an **admin** user with **atlasAdmin** privileges under:

- **Security > Database & Network Access > Database Access > Database Users**

We'll temporarily allow access from anywhere (IP Address `0.0.0.0/0`) under:

- **Security > Database & Network Access > Network Access > IP Access List**

We'll also note down the **password** and **host** details.

## Create the Database

In the SingleStore Portal, we'll use the **SQL Editor** to create a new database. Let's call this `crm_db`, as follows:

``` sql
CREATE DATABASE IF NOT EXISTS crm_db;
```

## Fill out the Notebook

Let's now create a new Python notebook. We'll call it **cdc**.

First, we'll ensure that we can reproduce the results:

``` python
SEED = 42
REFERENCE_DATE = datetime(2024, 10, 1, 12, 0, 0)

fake = Faker()
Faker.seed(SEED)
random.seed(SEED)
```

We'll now define the CRM stages:

``` python
class CustomStageProvider(BaseProvider):
    STAGES = [
        "new lead",
        "contacted",
        "qualified",
        "proposal sent",
        "negotiation",
        "won",
        "lost"
    ]
    def stage(self):
        return self.random_element(self.STAGES)

fake.add_provider(CustomStageProvider)
```

Next, we'll connect to MongoDB Atlas:

``` python
try:
    client = MongoClient("mongodb+srv://admin:<password>@<host>/?appName=Cluster0")
    db = client["crm_db"]
    print("Connected to MongoDB successfully.")
except Exception as e:
    print(f"Could not connect: {e}")
    exit(1)

print("Cleaning existing data...")
for coll in ["customers", "orders", "products"]:
    count = db[coll].delete_many({}).deleted_count
    print(f"  Deleted {count} documents from {coll}")
```

We'll replace `<password>` and `<host>` with the values that we saved earlier from MongoDB Atlas. Any existing data will also be deleted so that we can start with a clean slate.

In our example CRM system, we'll simulate `Customers`, `Orders` and `Products`, as follows:

``` python
NUM_CUSTOMERS = 50
NUM_PRODUCTS = 20
NUM_ORDERS = 100
```

Now we are ready to generate our CRM data and store it MongoDB Atlas. This will be Phase 1, as follows:

``` python
print("Phase 1: Initial Data Load")

customers = []
for i in range(NUM_CUSTOMERS):
    customers.append({
        "customer_id": i,
        "first_name": fake.first_name(),
        "last_name": fake.last_name(),
        "email": fake.email(),
        "company": fake.company(),
        "stage": fake.stage(),
        "created_at": fake.date_time_this_year()
    })
db.customers.insert_many(customers)
print(f"Inserted {NUM_CUSTOMERS} customers")

products = []
for i in range(NUM_PRODUCTS):
    products.append({
        "product_id": i,
        "name": fake.bs().title(),
        "price": round(random.uniform(10.0, 1000.0), 2),
        "category": random.choice(["software", "hardware", "service"]),
        "created_at": fake.date_time_this_year()
    })
db.products.insert_many(products)
print(f"Inserted {NUM_PRODUCTS} products")

orders = []
for i in range(NUM_ORDERS):
    cust = customers[i % NUM_CUSTOMERS]
    prod = products[i % NUM_PRODUCTS]
    qty = random.randint(1, 10)
    orders.append({
        "order_id": i,
        "customer_email": cust["email"],
        "product_name": prod["name"],
        "quantity": qty,
        "total_price": round(prod["price"] * qty, 2),
        "order_date": fake.date_time_this_year()
    })
db.orders.insert_many(orders)
print(f"Inserted {NUM_ORDERS} orders")

print("Phase 1 Complete: Initial load finished")
print("\nPAUSE HERE: Set up SingleStore pipeline, then press Enter...")
input()

print("Waiting 10 seconds for SingleStore initial sync...")
time.sleep(10)
```

Example output:

``` text
Phase 1: Initial Data Load
Inserted 50 customers
Inserted 20 products
Inserted 100 orders
Phase 1 Complete: Initial load finished

PAUSE HERE: Set up SingleStore pipeline, then press Enter...
```

The `Customers` and `Products` are stored as lists to maintain order for reproducibility. Once `Customers`, `Products` and `Orders` are created, we'll pause code execution so that we can switch to the **SQL Editor** to create and start the pipeline.

First, we'll create the pipeline, as follows:

``` sql
USE crm_db;

CREATE LINK crm_link AS MONGODB
CONFIG '{"mongodb.hosts": " <primary>:27017, <secondary>:27017, <secondary>:27017",
        "collection.include.list": "crm_db.*",
        "mongodb.ssl.enabled": "true",
        "mongodb.authsource": "admin",
        "mongodb.members.auto.discover": "false"}'
CREDENTIALS '{"mongodb.user": "admin",
            "mongodb.password": "<password>"}';
```

We'll replace `<password>` with the value that we saved earlier from MongoDB Atlas. We'll also replace the values for `<primary>`, `<secondary>` and `<secondary>` with the full host address for each from MongoDB Atlas. From the database, we'll include all three collections that we created.

Next, we'll create the tables in SingleStore that map to the collections in MongoDB Atlas, as follows:

``` sql
CREATE TABLES AS INFER PIPELINE AS LOAD DATA LINK crm_link '*' FORMAT AVRO;
```

Now we'll check what's been created using the following commands:

``` sql
SHOW TABLES;

SHOW PIPELINES;

SHOW PROCEDURES;
```

The pipelines are ready, but not running, so we'll start them as follows:

``` sql
START ALL PIPELINES;
```

The pipelines will start and, after a short time, the data will be streamed from MongoDB Atlas into SingleStore. We can check this, as follows:

``` sql
SELECT COUNT(*) FROM customers;
SELECT COUNT(*) FROM products;
SELECT COUNT(*) FROM orders;
```

The values should be 50, 20 and 100, respectively. These match the values from MongoDB Atlas, reported earlier.

Having taken an initial snapshot and replicated all the data across, let's now test if additions, updates and deletions to the collections on MongoDB Atlas are correctly propagated to SingleStore. This will be Phase 2, as follows:

``` python
print("Phase 2: Simulating CDC Changes")

Faker.seed(SEED + 1)
random.seed(SEED + 1)

CDC_TIMESTAMP = REFERENCE_DATE + timedelta(days = 100)

new_customers = []
for i in range(5):
    new_customers.append({
        "customer_id": NUM_CUSTOMERS + i,
        "first_name": fake.first_name(),
        "last_name": fake.last_name(),
        "email": fake.email(),
        "company": fake.company(),
        "stage": "new lead",
        "created_at": CDC_TIMESTAMP + timedelta(minutes = i)
    })
result = db.customers.insert_many(new_customers)
print(f"Inserted {len(result.inserted_ids)} new customers")

customers_to_update = list(db.customers.find(
    {"stage": {"$ne": "won"}}
).sort("customer_id", 1).limit(3))

updated_count = 0
for cust in customers_to_update:
    db.customers.update_one(
        {"_id": cust["_id"]},
        {"$set": {
            "stage": "won",
            "updated_at": CDC_TIMESTAMP + timedelta(minutes = 10 + updated_count)
        }}
    )
    updated_count += 1
print(f"Updated {updated_count} customers")

all_customers = list(db.customers.find().sort("customer_id", 1))
all_products = list(db.products.find().sort("product_id", 1))

new_orders = []
for i in range(10):
    # Use modulo for deterministic cycling through lists
    cust = all_customers[i % len(all_customers)]
    prod = all_products[i % len(all_products)]
    qty = random.randint(1, 5)
    new_orders.append({
        "order_id": NUM_ORDERS + i,
        "customer_email": cust["email"],
        "product_name": prod["name"],
        "quantity": qty,
        "total_price": round(prod["price"] * qty, 2),
        "order_date": CDC_TIMESTAMP + timedelta(minutes = 20 + i)
    })
result = db.orders.insert_many(new_orders)
print(f"Inserted {len(result.inserted_ids)} new orders")

products_to_update = list(db.products.find().sort("product_id", 1).limit(3))

price_update_count = 0
for prod in products_to_update:
    new_price = round(prod["price"] * random.uniform(0.95, 1.05), 2)
    db.products.update_one(
        {"_id": prod["_id"]},
        {"$set": {
            "price": new_price,
            "updated_at": CDC_TIMESTAMP + timedelta(minutes = 30 + price_update_count)
        }}
    )
    price_update_count += 1
print(f"Updated {price_update_count} product prices")

products_to_delete = list(db.products.find().sort("product_id", 1).limit(2))

deleted_count = 0
for prod in products_to_delete:
    db.products.delete_one({"_id": prod["_id"]})
    deleted_count += 1
print(f"Deleted {deleted_count} products")

print("Phase 2 Complete: CDC changes applied")
```

Our code is deterministic for reproducibility. Example output:

``` text
Phase 2: Simulating CDC Changes
Inserted 5 new customers
Updated 3 customers
Inserted 10 new orders
Updated 3 product prices
Deleted 2 products
Phase 2 Complete: CDC changes applied
```

Now we'll verify from MongoDB Atlas and SQL queries that we'll use with SingleStore:

``` python
print("Expected Results:")
print(f"  Customers: 50 -> {db.customers.count_documents({})} (should be 55)")
print(f"  Products:  20 -> {db.products.count_documents({})} (should be 18)")
print(f"  Orders:    100 -> {db.orders.count_documents({})} (should be 110)")

print("Waiting 15 seconds for CDC propagation...")
time.sleep(15)
```

Example output:

``` text
Expected Results:
  Customers: 50 -> 55 (should be 55)
  Products:  20 -> 18 (should be 18)
  Orders:    100 -> 110 (should be 110)
Waiting 15 seconds for CDC propagation...
```

After waiting a short time for CDC propagation, we'll run the following SQL statements in SingleStore:

``` sql
SELECT COUNT(*) FROM customers;
SELECT COUNT(*) FROM products;
SELECT COUNT(*) FROM orders;
```

The values should be 55, 18 and 110, respectively. These match the values from MongoDB Atlas, reported earlier.

## Example Queries

We'll run several queries on the data in SingleStore.

First, we can double-check the values that we now have in the three tables, as follows:

``` sql
SELECT 'customers' AS table_name, COUNT(*) AS count FROM customers
UNION ALL
SELECT 'orders', COUNT(*) FROM orders
UNION ALL
SELECT 'products', COUNT(*) FROM products;
```

Example output:

``` text
+------------+-------+
| table_name | count |
+------------+-------+
| customers  |    55 |
| orders     |   110 |
| products   |    18 |
+------------+-------+
```

Next, let's check for recent updates (customers with `updated_at` field):

``` sql
SELECT
    JSON_EXTRACT_STRING(_more, 'stage') AS stage,
    JSON_EXTRACT_STRING(_more, 'updated_at') AS updated_at
FROM customers 
WHERE JSON_EXTRACT_STRING(_more, 'updated_at') IS NOT NULL
LIMIT 10;
```

Example output:

``` text
+-------+--------------------------------------+
| stage | updated_at                           |
+-------+--------------------------------------+
| won   | {"$date":"2025-01-09T12:12:00.000Z"} |
| won   | {"$date":"2025-01-09T12:10:00.000Z"} |
| won   | {"$date":"2025-01-09T12:11:00.000Z"} |
+-------+--------------------------------------+
```

Next, let's look at the `Customer` stage distribution:

``` sql
SELECT 
    JSON_EXTRACT_STRING(_more, 'stage') AS stage,
    COUNT(*) AS count
FROM customers
GROUP BY JSON_EXTRACT_STRING(_more, 'stage')
ORDER BY count DESC;
```

Example output:

``` text
+---------------+-------+
| stage         | count |
+---------------+-------+
| won           |    12 |
| new lead      |    12 |
| contacted     |     8 |
| proposal sent |     7 |
| negotiation   |     7 |
| lost          |     5 |
| qualified     |     4 |
+---------------+-------+
```

Finally, let's view recent `Orders` (new orders with recent timestamps):

``` sql
SELECT 
    JSON_EXTRACT_STRING(_more, 'customer_email') AS customer,
    LEFT(JSON_EXTRACT_STRING(_more, 'product_name'), 10) AS product,
    JSON_EXTRACT_STRING(_more, 'order_date') AS order_date
FROM orders
ORDER BY JSON_EXTRACT_STRING(_more, 'order_date') DESC
LIMIT 10;
```

Example output:

``` text
+---------------------------+------------+--------------------------------------+
| customer                  | product    | order_date                           |
+---------------------------+------------+--------------------------------------+
| rachel05@example.org      | Empower Ne | {"$date":"2025-11-16T21:26:02.843Z"} |
| emilywalker@example.org   | Aggregate  | {"$date":"2025-11-15T15:24:37.417Z"} |
| dramsey@example.org       | Transform  | {"$date":"2025-11-11T07:42:57.735Z"} |
| icox@example.net          | Incubate C | {"$date":"2025-11-10T13:51:23.348Z"} |
| glee@example.net          | Drive Real | {"$date":"2025-11-02T03:13:37.031Z"} |
| taylorjesse@example.net   | Transition | {"$date":"2025-11-01T23:34:41.212Z"} |
| gabrieltucker@example.org | Aggregate  | {"$date":"2025-10-30T21:09:50.158Z"} |
| jpeterson@example.org     | Seize Magn | {"$date":"2025-10-11T18:05:00.340Z"} |
| millertodd@example.org    | Seize Cutt | {"$date":"2025-10-11T07:57:18.520Z"} |
| sarahcampos@example.net   | Aggregate  | {"$date":"2025-10-08T21:14:51.773Z"} |
+---------------------------+------------+--------------------------------------+
```

## Summary

In this chapter, we demonstrated how CDC enabled synchronization between an operational MongoDB Atlas system and SingleStore. We showed how CDC streamed insert, update and delete events into the database, preserving records, including nested or BSON-style fields, in their original structure for downstream processing. We also examined before-and-after states, verified that CDC ingestion was working correctly and ran several example queries to extract meaningful information from the captured payloads.
