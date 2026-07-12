# Chapter 19: Using LlamaIndex Workflows

## Introduction

LlamaIndex is a data framework designed to connect large language models with external data sources, making it an ideal tool for building intelligent applications that combine the reasoning capabilities of LLMs with structured and unstructured data. When paired with SingleStore's high-performance database, LlamaIndex enables powerful patterns like natural language querying, retrieval-augmented generation and conversational interfaces with memory.

In this chapter, we'll explore three fundamental LlamaIndex patterns using stock market data:

- **Natural Language to SQL:** Convert conversational queries into SQL statements, allowing users to ask questions about stock prices in plain English without writing any SQL code.

- **Retrieval-Augmented Generation:** Combine vector embeddings stored in SingleStore with LLM reasoning to answer questions about company information that isn't in structured tables, demonstrating how to augment a database with semantic search capabilities.

- **Conversational Memory:** Build stateful chat interfaces that remember context across multiple interactions, enabling more natural multi-turn conversations about data.

Each pattern demonstrates how SingleStore's dual capabilities as both a high-performance SQL database and a vector store make it an excellent foundation for LLM-powered applications. The stock ticker dataset provides a realistic scenario where users need to query time-series data, understand company information and have natural conversations about market trends.

By the end of this chapter, we'll understand how to:

- Set up LlamaIndex with SingleStore for natural language database interactions.

- Implement vector search for semantic retrieval using company knowledge.

- Build conversational interfaces that maintain context across queries.

- Combine structured SQL data with unstructured knowledge bases.

## Stockticker Data

We'll use the same dataset that was previously generated in the chapter on LangChain. Using the same dataset will also provide us with the opportunity to compare LlamaIndex with LangChain.

## LlamaIndex

In this section. we'll use LlamaIndex with SingleStore and test the key capabilities we discussed earlier.

### Fill out the Notebook

Let's now create a new Python notebook. We'll call it **llamaindex**.

First, we’ll set our models and retrieve our OpenAI API Key from the secrets vault. We'll need the OpenAI API Key for generating vector embeddings. We'll access the OpenAI API Key using `get_secret`:

```python
LLM_MODEL = ...
EMBEDDING_MODEL = ...

os.environ["OPENAI_API_KEY"] = get_secret("OPENAI_API_KEY")
```

Next, we'll set our OpenAI model:

```python
llm = OpenAI(
    model = LLM_MODEL,
    temperature = 0
)
```

#### Natural Language

Let's start with natural language. First, we'll connect to SingleStore:

```python
from sqlalchemy import *

db_connection = create_engine(connection_url)
```

Next, we'll create a LlamaIndex wrapper around this connection:

```python
db = SQLDatabase(
    db_connection,
    include_tables = ["tick"]
)

sql_query_engine = NLSQLTableQueryEngine(
    sql_database = db,
    tables = ["tick"]
)
```

The `SQLDatabase` object wraps our database connection and restricts LlamaIndex to only see and query the `tick` table, even if other tables exist in the database. This improves security, performance and helps the LLM generate more accurate queries by limiting its scope.

Let's now test the natural language capability. The following code sends a natural language question to the query engine, which converts it into SQL, executes the query against the `tick` table and prints the result.

```python
print(sql_query_engine.query(
    "Using the 'tick' table, return the ticker symbol with the highest closing price and its close value."
    )
)
```

Example output:

```text
The ticker symbol with the highest closing price is WVVF-FX, with a closing price of 6301.59.
```

We can also directly pass SQL statements, as follows:

```python
print(sql_query_engine.query(
    """
    SELECT symbol, close
    FROM tick
    ORDER BY close DESC
    LIMIT 1;
    """
    )
)
```

Example output:

```text
The stock with the highest closing price is WVVF-FX, with a closing price of $6301.59.
```

There is also an important consideration with natural language to SQL - when there are ties in the data, different SQL formulations could return different, but equally valid, answers. The LLM doesn't know there's a tie unless we explicitly ask it to check or handle duplicates.

#### Retrieval Augmented Generation (RAG)

Let's now create a small knowledge base that stores some information about the key demo tickers that we created earlier, as follows:

```python
company_info = {
    "BBRQ-FX": "BBRQ Corp is a global technology conglomerate known for its enterprise software platforms, cloud infrastructure services and a dominant position in business productivity tools.",
    "BJBY-FX": "BJBY Dynamics is a consumer electronics and devices company renowned for its flagship smartphone line, wearable technology and a fast-growing digital services ecosystem.",
    "YWMG-FX": "YWMG Group is an e-commerce and logistics powerhouse with expanding interests in cloud computing, digital advertising and subscription-based media streaming.",
    "HRPD-FX": "HRPD Technologies is a semiconductor and hardware manufacturer supplying chips and processing units to the automotive, aerospace and artificial intelligence industries."
}
```

We'll extract the information and store the stock symbol as metadata and the text as the page content:

```python
documents = [
    Document(text = text, metadata = {"symbol": symbol})
    for symbol, text in company_info.items()
]
```

We'll use an OpenAI embedding model:

```python
embed_model = OpenAIEmbedding(
    model = EMBEDDING_MODEL
)
```

Next, we'll ensure that we have a connection to SingleStore:

```python
from sqlalchemy import *

db_connection = create_engine(connection_url)
```

and then drop the company knowledge table if it already exists, so we start with a clean state:

```python
with db_connection.begin() as conn:
    conn.execute(text("DROP TABLE IF EXISTS company_knowledge;"))
```

Now we're ready to use the SingleStore LlamaIndex integration to store the company data:

```python
vector_store = SingleStoreVectorStore(
    table_name = "company_knowledge"
)

storage_context = StorageContext.from_defaults(vector_store = vector_store)

index = VectorStoreIndex.from_documents(
    documents,
    storage_context = storage_context,
    embed_model = embed_model,
    llm = llm
)

query_engine = index.as_query_engine()
```

We'll quickly check what was stored by retrieving the data from the database into a Pandas DataFrame:

```python
df = pd.read_sql(
    """
    SELECT
        LEFT(content, 30) AS content,
        LEFT(JSON_ARRAY_UNPACK(vector), 30) AS vector,
        metadata::symbol AS metadata
    FROM company_knowledge
    """,
    db_connection
)
```

and then check the DataFrame:

```python
df.head()
```

Example output:

```text
                         content                          vector metadata
0  YWMG Group is an e-commerce an  [-0.00719451904,0.0222320557,-  YWMG-FX
1  BBRQ Corp is a global technolo  [0.0135726929,-0.00692367554,0  BBRQ-FX
2  HRPD Technologies is a semicon  [-0.0163726807,-0.0491027832,0  HRPD-FX
3  BJBY Dynamics is a consumer el  [0.0202178955,-0.0174713135,-0  BJBY-FX
```

We'll also quickly check that the semantic search works for the four key demo stocks we stored. First, BBRQ.

```python
print(query_engine.query(
    "What are the most popular consumer devices and services that BBRQ sells?"
).response)
```

Example output:

```text
BBRQ Corp is known for its enterprise software platforms, cloud infrastructure services, and business productivity tools.
```

Next, BJBY.

```python
print(query_engine.query(
    "Describe BJBY's main contributions to both operating systems and cloud services."
).response)
```

Example output:

```text
BJBY's main contributions include innovations in operating systems that enhance user experience on its devices, as well as advancements in cloud services that support its digital ecosystem and services.
```

Next, YWMG.

```python
print(query_engine.query(
    "Can you detail the core technologies and services provided by YWMG?"
).response)
```

Example output:

```text
YWMG Group offers a range of core technologies and services including e-commerce solutions, logistics services, cloud computing services, digital advertising services, and subscription-based media streaming services.
```

Finally, HRPD.

```python
print(query_engine.query(
    "What are the primary sectors, including e-commerce and cloud, in which HRPD operates?"
).response)
```

Example output:

```text
HRPD operates primarily in the automotive, aerospace, and artificial intelligence industries.
```

All is working well with the semantic search. Next, we'll explore how to use LlamaIndex to store the full transcript of conversations.

#### Conversational Memory (in-memory)

Let's now create a conversational interface that remembers previous questions and answers. When we ask a follow-up question, the chat engine understands and maintains context across the conversation, enabling natural multi-turn dialogues with our database.

```python
memory = ChatMemoryBuffer.from_defaults()

chat_engine = CondenseQuestionChatEngine.from_defaults(
    query_engine = sql_query_engine,
    memory = memory,
    llm = llm
)
```

We'll ask a few questions to fill the buffer. First, let's ask for the tick values for a particular stock symbol:

```python
print(chat_engine.chat(
    "Show me the last 5 ticks for BBRQ-FX. Present the result as a table."
    )
)
```

Example output:

```text
Here are the last 5 ticks for BBRQ-FX:

| Symbol  | Date                | Open   | High    | Low     | Close   | Volume  |
|---------|---------------------|--------|---------|---------|---------|---------|
| BBRQ-FX | 2015-11-24 00:00:00 | 999.83 | 1017.41 | 985.60  | 1004.39 | 2066982 |
| BBRQ-FX | 2015-11-23 00:00:00 | 1020.74| 1039.59 | 1010.85 | 1019.04 | 2005610 |
| BBRQ-FX | 2015-11-20 00:00:00 | 991.68 | 992.87  | 977.93  | 990.32  | 1995583 |
| BBRQ-FX | 2015-11-19 00:00:00 | 1001.18| 1008.44 | 992.92  | 1003.77 | 33279776|
| BBRQ-FX | 2015-11-18 00:00:00 | 1037.09| 1052.68 | 1023.30 | 1042.63 | 5600879 |
```

Next, let's compare tick values from two different stock symbols:

```python
print(chat_engine.chat(
    "Now compare BBRQ-FX with BJBY-FX for the same period."
    )
)
```

Example output:

```text
Here is a comparison of the last 5 ticks for BBRQ-FX and BJBY-FX for the same dates:

| Symbol   | Date                | Open   | High    | Low     | Close   | Volume   |
|----------|----------------------|--------|---------|---------|---------|----------|
| BBRQ-FX  | 2015-11-24 00:00:00  | 999.83 | 1017.41 | 985.60  | 1004.39 | 2066982  |
| BJBY-FX  | 2015-11-24 00:00:00  | 423.62 | 427.74  | 419.80  | 423.54  | 4809503  |
| BBRQ-FX  | 2015-11-23 00:00:00  | 1020.74| 1039.59 | 1010.85 | 1019.04 | 2005610  |
| BJBY-FX  | 2015-11-23 00:00:00  | 414.12 | 419.63  | 408.61  | 411.49  | 1094794  |
| BBRQ-FX  | 2015-11-20 00:00:00  | 991.68 | 992.87  | 977.93  | 990.32  | 1995583  |
| BJBY-FX  | 2015-11-20 00:00:00  | 414.89 | 421.62  | 414.55  | 417.29  | 1528386  |
| BBRQ-FX  | 2015-11-19 00:00:00  | 1001.18| 1008.44 | 992.92  | 1003.77 | 33279776 |
| BJBY-FX  | 2015-11-19 00:00:00  | 405.89 | 413.27  | 403.93  | 406.81  | 7714812  |
| BBRQ-FX  | 2015-11-18 00:00:00  | 1037.09| 1052.68 | 1023.30 | 1042.63 | 5600879  |
| BJBY-FX  | 2015-11-18 00:00:00  | 392.06 | 394.92  | 385.35  | 392.48  | 4152808  |
```

Finally, let's compare the last close price for two stock symbols:

```python
print(chat_engine.chat(
    "Which had the higher last close, BBRQ-FX or BJBY-FX?"
    )
)
```

Example output:

```text
On the last date in the provided data (2015-11-24), the symbol BBRQ-FX had a higher closing price of 1004.39 compared to BJBY-FX.
```

Let's now output the complete conversation history:

```python
print("\nConversation memory buffer (recent):")
for msg in memory.get_all():
    role = msg.role.value.capitalize()
    # Each message may have multiple blocks, we just join text ones
    text = " ".join(
        block.text for block in msg.blocks if hasattr(block, "text")
    )
    print(f"{role}: {text}\n")
```

Example output:

```text
Conversation memory buffer (recent):
User: Show me the last 5 ticks for BBRQ-FX. Present the result as a table.

Assistant: Here are the last 5 ticks for BBRQ-FX:

| Symbol  | Date                | Open   | High    | Low     | Close   | Volume  |
|---------|---------------------|--------|---------|---------|---------|---------|
| BBRQ-FX | 2015-11-24 00:00:00 | 999.83 | 1017.41 | 985.60  | 1004.39 | 2066982 |
| BBRQ-FX | 2015-11-23 00:00:00 | 1020.74| 1039.59 | 1010.85 | 1019.04 | 2005610 |
| BBRQ-FX | 2015-11-20 00:00:00 | 991.68 | 992.87  | 977.93  | 990.32  | 1995583 |
| BBRQ-FX | 2015-11-19 00:00:00 | 1001.18| 1008.44 | 992.92  | 1003.77 | 33279776|
| BBRQ-FX | 2015-11-18 00:00:00 | 1037.09| 1052.68 | 1023.30 | 1042.63 | 5600879 |

User: Now compare BBRQ-FX with BJBY-FX for the same period.

Assistant: Here is a comparison of the last 5 ticks for BBRQ-FX and BJBY-FX for the same dates:

| Symbol   | Date                | Open   | High    | Low     | Close   | Volume   |
|----------|----------------------|--------|---------|---------|---------|----------|
| BBRQ-FX  | 2015-11-24 00:00:00  | 999.83 | 1017.41 | 985.60  | 1004.39 | 2066982  |
| BJBY-FX  | 2015-11-24 00:00:00  | 423.62 | 427.74  | 419.80  | 423.54  | 4809503  |
| BBRQ-FX  | 2015-11-23 00:00:00  | 1020.74| 1039.59 | 1010.85 | 1019.04 | 2005610  |
| BJBY-FX  | 2015-11-23 00:00:00  | 414.12 | 419.63  | 408.61  | 411.49  | 1094794  |
| BBRQ-FX  | 2015-11-20 00:00:00  | 991.68 | 992.87  | 977.93  | 990.32  | 1995583  |
| BJBY-FX  | 2015-11-20 00:00:00  | 414.89 | 421.62  | 414.55  | 417.29  | 1528386  |
| BBRQ-FX  | 2015-11-19 00:00:00  | 1001.18| 1008.44 | 992.92  | 1003.77 | 33279776 |
| BJBY-FX  | 2015-11-19 00:00:00  | 405.89 | 413.27  | 403.93  | 406.81  | 7714812  |
| BBRQ-FX  | 2015-11-18 00:00:00  | 1037.09| 1052.68 | 1023.30 | 1042.63 | 5600879  |
| BJBY-FX  | 2015-11-18 00:00:00  | 392.06 | 394.92  | 385.35  | 392.48  | 4152808  |

User: Which had the higher last close, BBRQ-FX or BJBY-FX?

Assistant: On the last date in the provided data (2015-11-24), the symbol BBRQ-FX had a higher closing price of 1004.39 compared to BJBY-FX.
```

Finally, let's query structured data as JSON documents. We'll retrieve the most recent stock prices from the database, convert each row into a JSON document and index with LlamaIndex. We'll then ask a natural language question and the LLM will filter and sort the JSON documents to return the answer ordered alphabetically.

```python
# Load sample tick data from SingleStore
df = pd.read_sql(
    """
    SELECT symbol
    FROM tick
    WHERE ts >= (SELECT MAX(ts) FROM tick) - INTERVAL 10 SECOND AND close > 500
    ORDER BY symbol ASC
    """,
    db_connection
)

# Convert each row into a Document
documents = [Document(text = row.to_json()) for _, row in df.iterrows()]

# Create a ListIndex over the JSON documents
json_index = ListIndex.from_documents(documents)

# Convert the DataFrame to a JSON list for deterministic querying
json_data = df.to_dict(orient = "records")

# Deterministic processing to extract tickers and sort alphabetically
tickers = sorted([row["symbol"] for row in json_data])

print("Tickers from last 10 seconds with close > 500:")
print(tickers)

# Query example
query = (
    "Using the latest timestamp in the tick table as the reference, "
    "return all tickers from the 10 seconds before that timestamp "
    "where the close price is above 500 and sort the results alphabetically by ticker."
)

response = json_index.as_query_engine().query(query)

print("\nLLM / Document Query Response (for reasoning / summary purposes):")
print(response.response)
```

Example output:

```text
Tickers from last 10 seconds with close > 500:
['BBRQ-FX', 'BBYX-FX', 'BKCZ-FX', 'BMJH-FX', 'BPDZ-FX', 'BPKV-FX', 'BTSP-FX', 'CCMN-FX', 'CGHY-FX', 'CHWP-FX', 'CMJH-FX', 'CPNQ-FX', 'CQNW-FX', 'CRGY-FX', 'CRKV-FX', 'CRYZ-FX', 'CZWQ-FX', 'DBQS-FX', 'DGJR-FX', 'DJMM-FX', 'DJWS-FX', 'DPCV-FX', 'DPHQ-FX', 'DSPZ-FX', 'DWWH-FX', 'DYJN-FX', 'FDPZ-FX', 'FJND-FX', 'FMLH-FX', 'FNDN-FX', 'FPPC-FX', 'FPPT-FX', 'FRGJ-FX', 'FSLV-FX', 'FSQG-FX', 'FTFK-FX', 'FTVP-FX', 'FVMS-FX', 'GDYP-FX', 'GQJT-FX', 'GQVB-FX', 'GTHL-FX', 'GVKX-FX', 'GZKB-FX', 'HBVK-FX', 'HDGG-FX', 'HDTN-FX', 'HHBV-FX', 'HKHY-FX', 'HMWC-FX', 'HWMV-FX', 'HZPN-FX', 'JBPW-FX', 'JJSK-FX', 'JSZL-FX', 'JZPM-FX', 'KBKT-FX', 'KDZD-FX', 'KKVT-FX', 'KLPQ-FX', 'KMYW-FX', 'KQVR-FX', 'KZHV-FX', 'LBCX-FX', 'LCLR-FX', 'LFMD-FX', 'LJDL-FX', 'LKNK-FX', 'LMRZ-FX', 'LQNY-FX', 'MGMX-FX', 'MHHR-FX', 'MHSN-FX', 'MHTD-FX', 'MJBG-FX', 'MJJZ-FX', 'MLSG-FX', 'MNDG-FX', 'MPHX-FX', 'MQRM-FX', 'MSCP-FX', 'MYCD-FX', 'NFYX-FX', 'NMZC-FX', 'NRJZ-FX', 'NVHZ-FX', 'PCZW-FX', 'PHQX-FX', 'PHTG-FX', 'PMTL-FX', 'PPMJ-FX', 'PQCJ-FX', 'PQGG-FX', 'PTFJ-FX', 'PXWS-FX', 'PYLY-FX', 'PYSD-FX', 'QNJQ-FX', 'QPLR-FX', 'QSGD-FX', 'QWPW-FX', 'QXXM-FX', 'RBHG-FX', 'RBLP-FX', 'RBWJ-FX', 'RFFC-FX', 'RFMZ-FX', 'RJMQ-FX', 'RKKG-FX', 'RTYG-FX', 'RVLR-FX', 'RWCV-FX', 'RWRX-FX', 'RWSM-FX', 'RXRF-FX', 'RYWC-FX', 'SBGJ-FX', 'SHBY-FX', 'SHRN-FX', 'SPPW-FX', 'SQWY-FX', 'SXJS-FX', 'TCJT-FX', 'TCSR-FX', 'TFLD-FX', 'TJJL-FX', 'TSKC-FX', 'TTXB-FX', 'TVDL-FX', 'TVKL-FX', 'VBTS-FX', 'VFCN-FX', 'VGBG-FX', 'VMNM-FX', 'VNDN-FX', 'VNNN-FX', 'VNTT-FX', 'VRFZ-FX', 'VSKF-FX', 'VVQT-FX', 'VXBG-FX', 'VXWH-FX', 'WFSB-FX', 'WJKC-FX', 'WKYZ-FX', 'WLRW-FX', 'WNCS-FX', 'WQNM-FX', 'WQVT-FX', 'WQXQ-FX', 'WSQZ-FX', 'WVVF-FX', 'WXBK-FX', 'XLZN-FX', 'XMCS-FX', 'XMSX-FX', 'XNGZ-FX', 'XNXQ-FX', 'XXHV-FX', 'XXKF-FX', 'XYKS-FX', 'XZWX-FX', 'YCCQ-FX', 'YSXQ-FX', 'YWMG-FX', 'YWRV-FX', 'YXTC-FX', 'YZSH-FX', 'ZGKC-FX', 'ZHZY-FX', 'ZJZR-FX', 'ZKCD-FX', 'ZPZX-FX', 'ZQPT-FX', 'ZYMD-FX', 'ZYWF-FX']

LLM / Document Query Response (for reasoning / summary purposes):
VBTS-FX, VFCN-FX, VGBG-FX, VMNM-FX, VNDN-FX, VNNN-FX, VNTT-FX, VRFZ-FX, VSKF-FX, VVQT-FX
```

In the SQL code, we're using the greater-than-or-equal operator (`>=`), rather than the equality operator (`=`) that LangChain generated for the same query, as we discussed in the previous chapter. In the LlamaIndex example, we obtain a deterministic list of tickers using SQL. However, for the natural language query, we obtain a smaller non-deterministic result.

Deterministic results come directly from SQL or DataFrame queries, always returning the exact same rows because the logic is precise and explicit. Non-deterministic results occur when using an LLM over JSON or documents, where the model interprets and summarizes the data, which can omit, reorder or hallucinate entries. Deterministic queries are best when exact numbers or lists are needed, while non-deterministic queries are useful for summaries, explanations or reasoning over the data.

## Summary

This chapter demonstrated three powerful patterns for integrating LlamaIndex with SingleStore, each addressing different aspects of building intelligent data applications.

The first section showed how LlamaIndex can translate natural language questions into SQL queries. This capability eliminates the barrier between non-technical users and database insights, making data accessible through conversational interfaces. The example also demonstrated that we can pass raw SQL queries directly to the engine, providing flexibility to either let the LLM generate queries or provide our own when precision is required.

The RAG implementation showcased how to enhance LLMs with external knowledge stored as vector embeddings in SingleStore. By creating a `company_knowledge` table with text embeddings, we enabled semantic search over company descriptions. The `company_knowledge` table stored both the text content and its vector representation, along with metadata linking each entry to its stock symbol. This structure enables efficient semantic retrieval while maintaining connections to structured data in the `tick` table.

The final section demonstrated building stateful chat interfaces. This pattern showed how to maintain context across multiple related queries. The memory buffer retained the full conversation history, enabling the system to resolve pronouns, understand temporal references and provide contextually appropriate responses without requiring users to repeat information.

The chapter concluded with an advanced example showing how to query JSON documents. By converting SQL query results into JSON documents and indexing them with LlamaIndex, we enabled complex filtering and sorting operations expressed in natural language.

To summarize the benefits:

- **Unified Data Platform:** SingleStore serves as both a high-performance SQL database and a vector store, eliminating the need for separate systems and simplifying our architecture.

- **Progressive Enhancement:** We can start with simple natural language queries and progressively add vector search, conversational memory and document retrieval as our application needs grow.

- **Production-Ready Patterns:** All three patterns – natural language to SQL, RAG and conversational memory - are approaches used in production AI applications across industries.

- **Developer Productivity:** LlamaIndex abstracts the complexity of prompt engineering, embedding management and context handling, allowing developers to focus on application logic rather than LLM infrastructure.

LlamaIndex's abstraction layer provides a powerful foundation for building the next generation of data-driven AI applications, from customer support chatbots to financial analysis tools to enterprise search systems.
