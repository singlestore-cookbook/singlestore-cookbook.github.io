# Chapter 21: Running Local LLMs with Ollama

## Introduction

In previous chapters, we explored cloud-based language models and their integration with SingleStore. While these solutions offer powerful capabilities, they come with considerations around data privacy, network latency and ongoing costs. This chapter introduces an alternative approach: running large language models locally on our own hardware.

We'll work with Ollama[^1], an open-source platform that makes it straightforward to download, run and manage language models on a local machine. By combining Ollama with SingleStore, we can build a complete RAG system that operates entirely within our own infrastructure. This approach gives us full control over our data, eliminates dependencies on external API services and allows us to experiment without usage-based charges.

In this chapter, we'll learn how to set up Ollama in our local environment, configure it to work with embedding and language models and integrate it with a database for semantic search capabilities. We'll explore two implementation approaches: one using LangChain that abstracts away many details and another using direct API calls for finer control. By the end of this chapter, we'll understand the trade-offs of these two approaches as well as local versus cloud-based LLM deployment.

In the examples in this chapter, we'll use a local installation of Ollama but connect securely to a SingleStore instance in the cloud. SingleStore can also be installed locally but using it in the cloud provides a quick and easy way to test Ollama without requiring any further local software installations.

## Create the Database

In the SingleStore Portal, we'll use the **SQL Editor** to create a new database. Call this `ollama_db`, as follows:

```sql
CREATE DATABASE IF NOT EXISTS ollama_db;
```

## Create the Environment Variables

From our running SingleStore cloud instance, we'll note down the `host` and `password` from the connection string and create two environment variables on our local machine called `SINGLESTOREDB_HOST` and `SINGLESTOREDB_PASSWORD`. For example, on Linux, we would use the following, replacing `<host>` and `<password>`, respectively:

```shell
export SINGLESTOREDB_HOST='<host>'
export SINGLESTOREDB_PASSWORD='<password>'
```

## Install the Required Tools

We'll need several tools installed on our local machine:

- **Jupyter Notebook:** The classic Jupyter notebook[^2] will be sufficient.

- **Ollama:** This can be installed on Apple macOS, Linux and Microsoft Windows[^3]. Use the installer for your platform. After installation, the Ollama server should be running in the background.

## Using Ollama with LangChain

### Fill out the Notebook

Let's now create a new Python notebook. We'll call it **ollama_langchain**.

First, we'll define the models to use:

```python
EMBEDDING_MODEL = "all-minilm"
LLM_MODEL = "llama3"
```

Next, we'll download a model for vector embeddings:

```python
ollama.pull(EMBEDDING_MODEL)
```

Example output:

```text
ProgressResponse(status='success', completed=None, total=None, digest=None)
```

There are many good LLMs available, but `llama3` is very capable and Meta provides a generous license[^4].

```python
ollama.pull(LLM_MODEL)
```

Example output:

```text
ProgressResponse(status='success', completed=None, total=None, digest=None)
```

Next, we'll create a small company knowledgebase similar to previous chapters, but we'll use real companies as we want the LLM to give us more information, if possible: 

```python
company_info = {
    "AAPL": "Apple Inc. is a technology company known for the iPhone, iPad and Mac. It also offers services like iCloud and Apple Music.",
    "AMZN": "Amazon.com is an e-commerce giant with businesses in cloud computing (AWS), logistics and digital streaming.",
    "GOOG": "Google, a subsidiary of Alphabet Inc., is a technology company specializing in internet services, online advertising, search and AI.",
    "MSFT": "Microsoft develops software such as Windows and Office and is a leader in cloud computing with Azure."
}
```

We'll extract the information and store the stock symbol as metadata and the text as the page content:

```python
documents = [
    Document(page_content = text, metadata = {"symbol": sym})
    for sym, text in company_info.items()
]
```

We'll use the embedding model and determine the length of the vectors that it returns using a test string:

```python
embeddings = OllamaEmbeddings(
    model = EMBEDDING_MODEL,
)

dimensions = len(embeddings.embed_query("test"))
```

Next, we'll ensure we have all the connection details for the SingleStore instance:

```python
username = "admin"
password = os.environ.get("SINGLESTOREDB_PASSWORD")
host = os.environ.get("SINGLESTOREDB_HOST")
port = 3306
database = "ollama_db"

if not password:
    raise ValueError("Environment variable SINGLESTOREDB_PASSWORD is not set or is empty.")

if not host:
    raise ValueError("Environment variable SINGLESTOREDB_HOST is not set or is empty.")

problematic_chars = ["#", "@", "/", "?", "%"]
found = [c for c in problematic_chars if c in password]
if found:
    print(f"WARNING: Password contains character(s) {found} which may cause connection issues.")

my_connection_url = f"singlestoredb://{username}:{quote(password, safe = '')}@{host}:{port}/{database}"
```

Now, we'll connect to SingleStore:

```python
from sqlalchemy import *

db_connection = create_engine(my_connection_url)
```

and then drop the company knowledge table if it already exists, so we start with a clean state:

```python
try:
    with db_connection.begin() as conn:
        conn.execute(text("DROP TABLE IF EXISTS company_knowledge;"))
except Exception as e:
    print(f"Error dropping table: {e}")
    raise
```

Now we're ready to use the SingleStore LangChain integration to store the company data:

```python
vector_store = SingleStoreVectorStore(
    embeddings,
    user = username,
    password = password,
    host = host,
    port = port,
    database = database,
    table_name = "company_knowledge",
    distance_strategy = "DOT_PRODUCT",
    use_vector_index = True,
    vector_size = dimensions
)

vector_store.add_documents(documents);
```

Let's run a semantic search:

```python
prompt = "What are the most popular consumer devices and services that Apple Inc. sells?"
documents = vector_store.similarity_search(prompt, k = 1)
data = documents[0].page_content
print(data)
```

Example output:

```text
Apple Inc. is a technology company known for the iPhone, iPad and Mac. It also offers services like iCloud and Apple Music.
```

and we'll use this as input to the LLM:

```python
output = ollama.generate(
    model = LLM_MODEL,
    prompt = f"Using this data: {data}. Respond to this prompt: {prompt}",
    options = {
        "temperature": 0
    }
)

print(output["response"])
```

Example output:

```text
Based on the provided data, the most popular consumer devices sold by Apple Inc. are:

1. iPhone
2. iPad
3. Mac (computers)

As for services, Apple Inc. offers:

1. iCloud (cloud storage and backup)
2. Apple Music (music streaming)

These products and services are some of the most well-known and widely used among consumers, making them the most popular offerings from Apple Inc.
```

Let's now use the same example but without LangChain.

## Using Ollama with Direct API Calls

### Fill out the Notebook

Let's now create a new Python notebook. We'll call it **ollama_direct_api**.

Many of the initial steps will be the same as the LangChain example.

First, we'll define the models to use:

```python
EMBEDDING_MODEL = "all-minilm"
LLM_MODEL = "llama3"
```

Next, we'll download a model for vector embeddings:

```python
ollama.pull(EMBEDDING_MODEL)
```

Example output:

```text
ProgressResponse(status='success', completed=None, total=None, digest=None)
```

We'll use `llama3` again.

```python
ollama.pull(LLM_MODEL)
```

Example output:

```text
ProgressResponse(status='success', completed=None, total=None, digest=None)
```

Next, we'll create a small company knowledgebase similar to previous chapters, but we'll use real companies as we want the LLM to give us more information, if possible:

```python
company_info = {
    "AAPL": "Apple Inc. is a technology company known for the iPhone, iPad and Mac. It also offers services like iCloud and Apple Music.",
    "AMZN": "Amazon.com is an e-commerce giant with businesses in cloud computing (AWS), logistics and digital streaming.",
    "GOOG": "Google, a subsidiary of Alphabet Inc., is a technology company specializing in internet services, online advertising, search and AI.",
    "MSFT": "Microsoft develops software such as Windows and Office and is a leader in cloud computing with Azure."
}
```

Now, we'll loop through each company's text description, generate an embedding for it using the embedding model, convert that embedding into a NumPy float32 array and store the text, vector and metadata (the stock symbol) as rows in a Pandas DataFrame. Once all embeddings are processed, we'll determine the length of the vectors using a test string.

```python
df_data = []

for sym, text in company_info.items():
    response = ollama.embeddings(
        model = EMBEDDING_MODEL,
        prompt = text
    )
    embedding_array = np.array(response["embedding"], dtype = np.float32)
    df_data.append({"content": text, "vector": embedding_array, "metadata": json.dumps({"symbol": sym})})

df = pd.DataFrame(df_data)

response = ollama.embeddings(
    model = EMBEDDING_MODEL,
    prompt = "test"
)

dimensions = len(response["embedding"])
```

Next, we'll ensure we have all the connection details for the SingleStore instance:

```python
username = "admin"
password = os.environ.get("SINGLESTOREDB_PASSWORD")
host = os.environ.get("SINGLESTOREDB_HOST")
port = 3306
database = "ollama_db"

if not password:
    raise ValueError("Environment variable SINGLESTOREDB_PASSWORD is not set or is empty.")

if not host:
    raise ValueError("Environment variable SINGLESTOREDB_HOST is not set or is empty.")

problematic_chars = ["#", "@", "/", "?", "%"]
found = [c for c in problematic_chars if c in password]
if found:
    print(f"WARNING: Password contains character(s) {found} which may cause connection issues.")

my_connection_url = f"singlestoredb://{username}:{quote(password, safe = '')}@{host}:{port}/{database}"
```

Now, we'll connect to SingleStore:

```python
from sqlalchemy import *

db_connection = create_engine(my_connection_url)
```

and then drop the company knowledge table if it already exists, so we start with a clean state:

```python
try:
    with db_connection.begin() as conn:
        conn.execute(text("DROP TABLE IF EXISTS company_knowledge;"))
except Exception as e:
    print(f"Error dropping table: {e}")
    raise
```

We'll need to create the `company_knowledge` table:

```python
query = text("""
CREATE TABLE IF NOT EXISTS company_knowledge (
    id BIGINT AUTO_INCREMENT NOT NULL PRIMARY KEY,
    content LONGTEXT,
    vector VECTOR(:dimensions) NOT NULL,
    metadata JSON,
    VECTOR INDEX (vector) INDEX_OPTIONS '{"metric_type": "DOT_PRODUCT"}'
);
""")

with db_connection.begin() as conn:
    conn.execute(query, {"dimensions": dimensions})
```

Now we'll store the data from the Pandas DataFrame into the database:

```python
df.to_sql(
    "company_knowledge",
    con = db_connection,
    if_exists = "append",
    index = False,
    chunksize = 1000
)
```

Let's run a semantic search:

```python
prompt = "What are the most popular consumer devices and services that Apple Inc. sells?"

response = ollama.embeddings(
    model = EMBEDDING_MODEL,
    prompt = prompt
)
embedding_array = np.array(response["embedding"], dtype = np.float32)

query = text("""
SELECT content
FROM company_knowledge
ORDER BY vector <*> :embedding_array DESC
LIMIT 1;
""")

with db_connection.connect() as conn:
    row = conn.execute(query, {"embedding_array": embedding_array}).fetchone()

data = row[0]
print(data)
```

Example output:

```text
Apple Inc. is a technology company known for the iPhone, iPad and Mac. It also offers services like iCloud and Apple Music.
```

and we'll use this as input to the LLM:

```python
output = ollama.generate(
    model = LLM_MODEL,
    prompt = f"Using this data: {data}. Respond to this prompt: {prompt}",
    options = {
        "temperature": 0
    }
)

print(output["response"])
```

Example output:

```text
Based on the provided data, the most popular consumer devices sold by Apple Inc. are:

1. iPhone
2. iPad
3. Mac (computers)

As for services, Apple Inc. offers:

1. iCloud (cloud storage and backup)
2. Apple Music (music streaming)

These products and services are some of the most well-known and widely used among consumers, making them the most popular offerings from Apple Inc.
```

## Summary

In this chapter, we explored how to build a simple RAG system using locally-hosted language models. We began by installing and configuring Ollama, setting up the necessary environment variables to run models without requiring root privileges or cloud services.

We worked with two different models: an embedding model for converting text into vector representations and a language model for generating natural language responses. Using a collection of company descriptions as our knowledge base, we showed how to create embeddings and store them in a vector database alongside the original text content.

The chapter presented two implementation patterns. The first approach used an abstraction framework (LangChain) that simplified the integration between the embedding model, vector store and language model. This method provided a clean, high-level interface for building RAG applications with minimal boilerplate code. The second approach used direct API calls and database queries, offering more transparency into the underlying mechanics and greater control over each step of the process.

Both implementations followed the same fundamental pattern: convert a user query into an embedding, perform a similarity search to find the most relevant content from the knowledge base and use that content as context for the language model to generate an informed response. We used dot product as our similarity metric and configured the models with specific parameters to ensure consistent, deterministic outputs.

The key advantage of this local approach is high data control and independence from external language model services. All processing happens on our own hardware, making it suitable for sensitive data, offline environments or situations where API costs would be prohibitive. The trade-off is the need for sufficient local computational resources and the responsibility of managing the models ourselves.

By working through both high-level and low-level implementations, we gained insight into how RAG systems function under the hood, regardless of whether we choose convenience or control in our production applications. This foundation prepares us to make informed decisions about deployment strategies and to troubleshoot issues when they arise in more complex scenarios.

[^1]:  https://ollama.com

[^2]:  https://docs.jupyter.org/en/latest/install/notebook-classic.html

[^3]:  https://ollama.com/download

[^4]:  https://www.llama.com/llama3/license/
