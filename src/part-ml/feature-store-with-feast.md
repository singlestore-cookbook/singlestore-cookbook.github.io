# Chapter 17: Feature Store with Feast

## Introduction

In modern Machine Learning (ML) systems, one of the most critical yet challenging aspects is managing features - the input variables that models use to make predictions. As ML applications scale from experimental notebooks to production systems, organizations quickly encounter the "feature engineering problem", where features are computed inconsistently across training and serving environments, recalculated redundantly by different teams and difficult to share and reuse across projects.

A **feature store** solves these challenges by providing a centralized repository for storing, managing and serving ML features. It can be considered as a specialized database optimized for ML workflows, sitting between raw data sources and models.

Feature stores address several critical needs in production ML systems:

- **Consistency Between Training and Serving:** Model performance degradation in production can occur when there is training-serving skew. This is when features are calculated differently during model training versus real-time prediction. A feature store ensures that the same feature computation logic is used in both environments, eliminating this source of errors.

- **Low-Latency Feature Retrieval:** Production ML systems often need to make predictions in milliseconds. A feature store provides an optimized online store for fast feature lookups during inference, while also maintaining an offline store for batch processing during training.

- **Feature Reusability and Discovery:** Without a feature store, teams often rebuild the same features independently, wasting engineering effort. A centralized feature store creates a catalog of available features that can be discovered and reused across projects and teams.

- **Point-in-Time Correctness:** For training models on historical data, it's crucial that features reflect only the information that would have been available at that specific point in time. Feature stores provide point-in-time correct feature retrieval, preventing data leakage that would artificially inflate model performance.

- **Simplified Feature Pipeline Management:** Feature stores manage the complexity of materializing features from raw data sources, keeping features up-to-date and monitoring feature quality over time.

SingleStore is uniquely positioned to serve as a feature store backend due to its hybrid transactional and analytical processing capabilities. It can handle both the real-time, low-latency reads required for online serving and the analytical queries needed for batch feature computation. Its distributed architecture provides the scalability needed for large feature sets, while maintaining the fast response times critical for production ML systems.

In this chapter, we'll explore how to build a complete feature store using Feast, an open-source feature store framework, with SingleStore as the online store backend. We'll work through a practical e-commerce use case, demonstrating how to define features, materialize them for fast serving and use them for real-time predictions.

## Create the Database

In the SingleStore Portal, we'll use the **SQL Editor** to create a new database. Let's call this `feast_db`, as follows:

```sql
CREATE DATABASE IF NOT EXISTS feast_db;
```

## Fill out the Notebook

Let's now create a new Python notebook. We'll call it **feast**.

After ensuring that we are connected to a database, we'll extract the connection details, as follows:

```python
from sqlalchemy import *

db_connection = create_engine(connection_url)

url = db_connection.url
host = url.host
port = url.port
database = url.database
username = "admin"
password = get_secret("password")
```

Using this information, we'll create a `yaml` file with the feature definitions for an e-commerce store, as follows:

```python
os.makedirs("feature_repo/data", exist_ok = True)
os.makedirs("feature_repo/features", exist_ok = True)

feature_store_yaml = f"""
project: ecommerce_features
registry: feature_repo/registry.db
provider: local

online_store:
    type: singlestore
    host: {host}
    port: {port}
    database: {database}
    user: {username}
    password: "{password}"
"""

with open("feature_repo/feature_store.yaml", "w") as f:
    f.write(feature_store_yaml)

print("Feature store configuration created.")
```

Now, we'll describe the features and write them out to a Python file. Using Feast's declarative feature definitions, we'll specify how these features should be computed and stored. The feature view configuration defines the schema, time-to-live settings and data source, while the customer entity establishes the primary key for feature lookups. This declarative approach separates feature logic from infrastructure concerns, making features easier to maintain and version control.

```python
driver_features_py = """
from feast import Entity, FeatureView, Field, FileSource
from feast.types import Float32, Int64, String, ValueType
from datetime import timedelta

customer = Entity(
    name = "customer_id",
    description = "Customer identifier",
    value_type = ValueType.STRING
)

customer_features = FeatureView(
    name = "customer_features",
    entities = [customer],
    ttl = timedelta(days = 90),
    schema = [
        Field(name = "total_orders", dtype = Int64),
        Field(name = "total_spent", dtype = Float32),
        Field(name = "avg_order_value", dtype = Float32),
        Field(name = "days_since_last_order", dtype = Int64),
        Field(name = "favorite_category", dtype = String),
    ],
    online = True,
    source = FileSource(
        path = "data/customer_features.parquet",
        timestamp_field = "event_timestamp"
    ),
)
"""

with open("feature_repo/features/driver_features.py", "w") as f:
    f.write(driver_features_py)

print("Feature definitions created.")
```

Next, we'll create the database schema and sample data. We'll create a realistic e-commerce dataset with 1,000 orders across 100 customers over a 90-day period.

```python
def setup_database():
    """Create tables and populate with sample e-commerce data."""

    with db_connection.connect() as conn:
        conn.execute(text("""
        CREATE TABLE IF NOT EXISTS customer_orders (
            customer_id VARCHAR(50),
            order_id VARCHAR(50),
            order_timestamp DATETIME,
            order_value DECIMAL(10, 2),
            product_category VARCHAR(50),
            quantity INT,
            PRIMARY KEY (order_id),
            KEY idx_customer_ts (customer_id, order_timestamp)
        )
        """))
        conn.execute(text("TRUNCATE TABLE customer_orders"))
        conn.commit()

    customers = [f"CUST_{i:04d}" for i in range(1, 101)]
    categories = ["Electronics", "Clothing", "Home", "Books", "Sports"]

    print("Generating sample orders...")

    orders_data = []
    for i in range(1000):
        customer_id = random.choice(customers)
        order_id = f"ORD_{i:06d}"
        days_ago = random.randint(0, 90)
        order_timestamp = datetime.now() - timedelta(days = days_ago, hours = random.randint(0, 23))
        order_value = round(random.uniform(10, 500), 2)
        product_category = random.choice(categories)
        quantity = random.randint(1, 5)

        orders_data.append({
            "customer_id": customer_id,
            "order_id": order_id,
            "order_timestamp": order_timestamp,
            "order_value": order_value,
            "product_category": product_category,
            "quantity": quantity
        })

    orders_df = pd.DataFrame(orders_data)
    orders_df.to_sql(
        "customer_orders",
        con = db_connection,
        if_exists = "append",
        index = False,
        chunksize = 1000
    )

    print("Database setup complete with 1000 sample orders.")

# Run setup
setup_database()
```

Now we'll compute features from the raw data:

```python
def compute_customer_features():
    """Compute customer features from orders table."""

    query = """
    WITH category_counts AS (
        SELECT
            customer_id,
            product_category,
            COUNT(*) as category_count,
            ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY COUNT(*) DESC) as rn
        FROM customer_orders
        GROUP BY customer_id, product_category
    )
    SELECT
        co.customer_id,
        COUNT(*) as total_orders,
        SUM(co.order_value) as total_spent,
        AVG(co.order_value) as avg_order_value,
        DATEDIFF(NOW(), MAX(co.order_timestamp)) as days_since_last_order,
        MAX(cc.product_category) as favorite_category,
        MAX(co.order_timestamp) as event_timestamp
    FROM customer_orders co
    LEFT JOIN category_counts cc ON co.customer_id = cc.customer_id AND cc.rn = 1
    GROUP BY co.customer_id
    """

    df = pd.read_sql(
        query,
        con = db_connection
    )

    df.to_parquet("feature_repo/data/customer_features.parquet")

    print(f"Computed features for {len(df)} customers.")
    print("\nSample features:")
    print(df.head(4).T)

    return df

features_df = compute_customer_features()
```

From the transactional data, we've engineered 5 customer-level features:

- Total order count

- Total amount spent

- Average order value

- Days since last order

- Favorite product category

These features capture both behavioral patterns and recency signals that are valuable for customer analytics and churn prediction. Example output:

```text
Computed features for 100 customers.

Sample features:
                                         0                    1                    2                    3
customer_id                      CUST_0027            CUST_0095            CUST_0075            CUST_0020
total_orders                             6                    6                   11                   16
total_spent                        1101.60              1156.01              2413.08              4695.57
avg_order_value                     183.60               192.67               219.37               293.47
days_since_last_order                    7                   11                    1                    6
favorite_category              Electronics          Electronics                Books             Clothing
event_timestamp        2025-10-18 22:41:56  2025-10-14 12:41:56  2025-10-24 13:41:56  2025-10-19 17:41:56
```

Next, we'll initialize Feast and apply the feature definitions:

```python
fs = FeatureStore(repo_path = "feature_repo")

print("Applying feature definitions...")

result = subprocess.run(
    ["feast", "-c", "feature_repo", "apply"],
    capture_output = True,
    text = True
)

print(result.stdout)
if result.returncode == 0:
    print("Features applied successfully.")
else:
    print("Error:", result.stderr)
```

Example output:

```text
INFO:feast.infra.registry.registry:Registry file not found. Creating new registry.
Applying feature definitions...
No project found in the repository. Using project name ecommerce_features defined in feature_store.yaml
Applying changes for project ecommerce_features
Deploying infrastructure for customer_features

Features applied successfully.
```

Now we'll materialize the features to the online store. The materialization process demonstrates how feature stores handle the dual-store architecture. We compute features from the source data and materialize them into SingleStore's online store, where they can be quickly retrieved.

```python
end_date = datetime.now()
start_date = end_date - timedelta(days = 90)

print(f"Materializing features from {start_date} to {end_date}...")

result = subprocess.run(
    [
        "feast", "-c", "feature_repo", "materialize",
        start_date.isoformat(),
        end_date.isoformat()
    ],
    capture_output = True,
    text = True
)

print(result.stdout)

if result.returncode == 0:
    print("Features materialized to online store.")
else:
    print("Error:", result.stderr)
```

Example output:

```text
Materializing features from 2025-07-27 14:42:01.208776 to 2025-10-25 14:42:01.208776...
Materializing 1 feature views from 2025-07-27 14:42:01+00:00 to 2025-10-25 14:42:01+00:00 into the singlestore online store.

customer_features:

Features materialized to online store.
```

Next, we'll reinitialize the feature store to get the applied features and select several test customers:

```python
fs = FeatureStore(repo_path = "feature_repo")

test_customers = ["CUST_0001", "CUST_0025", "CUST_0050"]
entity_rows = [{"customer_id": cid} for cid in test_customers]

feature_vector = fs.get_online_features(
    features = [
        "customer_features:total_orders",
        "customer_features:total_spent",
        "customer_features:avg_order_value",
        "customer_features:days_since_last_order",
        "customer_features:favorite_category",
    ],
    entity_rows = entity_rows
)

features_df = feature_vector.to_df()
print(features_df)
```

Example output:

```text
  customer_id  total_orders  days_since_last_order  total_spent  avg_order_value favorite_category
0   CUST_0001             9                      0      2364.08           262.68       Electronics
1   CUST_0025             5                     20      1455.68           291.14              Home
2   CUST_0050             9                      8      2750.71           305.63            Sports
```

For these customers, we'll use the features to make predictions for churn risk:

```python
def predict_customer_churn(customer_id):
    """Use features for real-time prediction."""

    features = fs.get_online_features(
        features = [
            "customer_features:total_orders",
            "customer_features:total_spent",
            "customer_features:days_since_last_order",
        ],
        entity_rows = [{"customer_id": customer_id}]
    ).to_df()

    days_since = features["days_since_last_order"].iloc[0]
    total_orders = features["total_orders"].iloc[0]

    if days_since > 60:
        return {"customer_id": customer_id, "churn_risk": "HIGH", "action": "Send 20% discount"}
    elif days_since > 30:
        return {"customer_id": customer_id, "churn_risk": "MEDIUM", "action": "Send personalized email"}
    else:
        return {"customer_id": customer_id, "churn_risk": "LOW", "action": "Continue engagement"}

for customer in ["CUST_0001", "CUST_0025", "CUST_0050"]:
    prediction = predict_customer_churn(customer)
    print(f"{prediction['customer_id']}: {prediction['churn_risk']} - {prediction['action']}")
```

Example output:

```text
CUST_0001: LOW - Continue engagement
CUST_0025: LOW - Continue engagement
CUST_0050: LOW - Continue engagement
```

For the test customers, churn risk is currently low.

We'll query SingleStore to verify that the features were materialized:

```python
query = "SELECT feature_name, value, event_ts FROM ecommerce_features_customer_features LIMIT 5"

materialized_features = pd.read_sql(
    query,
    con = db_connection
)

print("Features in SingleStore online store:")
print(materialized_features)
```

Example output:

```text
Features in SingleStore online store:
        feature_name                   value            event_ts
0       total_orders                  b' \t' 2025-10-17 20:41:56
1  favorite_category         b'\x12\x04Home' 2025-10-15 17:41:56
2  favorite_category  b'\x12\x0bElectronics' 2025-10-17 21:41:56
3       total_orders                  b' \t' 2025-10-22 13:41:56
4  favorite_category     b'\x12\x08Clothing' 2025-10-20 21:41:56
```

We'll also query historical data directly from source data. Here's an example for one particular customer:

```python
def get_historical_features_from_orders(customer_id, as_of_date):
    """Get features as they existed at a specific date."""

    query = f"""
    SELECT
        customer_id,
        COUNT(*) as total_orders,
        SUM(order_value) as total_spent,
        AVG(order_value) as avg_order_value
    FROM customer_orders
    WHERE customer_id = '{customer_id}'
    AND order_timestamp <= '{as_of_date}'
    GROUP BY customer_id
    """
    result = pd.read_sql(query, db_connection)
    if result.empty:
        print(f"No historical data found for {customer_id} as of {as_of_date}")
    return result

past_date = (datetime.now() - timedelta(days = 30)).strftime("%Y-%m-%d")
hist_features = get_historical_features_from_orders("CUST_0001", past_date)
print(f"Features for CUST_0001 as of {past_date}:")
print(hist_features)
```

Example output:

```text
Features for CUST_0001 as of 2025-09-25:
  customer_id  total_orders  total_spent  avg_order_value
0   CUST_0001             6      1376.93           229.49
```

## Summary

In this chapter, we built a complete feature store solution using Feast and SingleStore, demonstrating the full lifecycle of feature management for an ML application. Using an e-commerce customer analytics scenario, we showed how feature stores bridge the gap between raw operational data and production ML systems.

We demonstrated online feature retrieval, fetching features for specific customers. This fast lookup capability makes feature stores viable for real-time prediction systems - applications that need to score customers, products or transactions as events occur.

The simple churn prediction example we implemented illustrates how feature stores enable operational ML. By accessing pre-computed, up-to-date features instantly, our prediction function could make real-time decisions about customer engagement strategies. In a production system, this same pattern scales to support use cases such as:

- Real-time fraud detection, accessing customer transaction patterns and risk scores.

- Personalized product recommendations, combining user preferences with real-time behavior.

- Dynamic pricing, using market features and customer propensity scores.

- Credit decisioning, pulling together features from multiple data sources.

The integration of Feast and SingleStore demonstrates several important principles:

- The separation of feature definition from storage allows teams to evolve their feature logic independently of infrastructure changes.

- The dual-store architecture with SingleStore handling online serving and parquet files providing offline training data shows how feature stores balance different performance requirements.

- The point-in-time feature retrieval capability we explored ensures that historical features remain consistent, preventing data leakage in model training.

Feature stores transform feature engineering from an ad-hoc, project-specific activity into a reusable, managed capability. Features become first-class assets that can be shared across teams, versioned alongside models and monitored for quality over time. The patterns demonstrated here - centralized feature definitions, materialized views for fast serving and consistent computation across environments - help avoid common pitfalls and accelerate the path to production ML systems.
