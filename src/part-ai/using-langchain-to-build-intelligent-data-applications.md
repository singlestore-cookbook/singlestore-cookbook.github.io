# Chapter 18: Using LangChain to Build Intelligent Data Applications

## Introduction

Modern applications increasingly require the ability to interact with data using natural language, maintain conversational context and retrieve relevant information intelligently. LangChain, a framework for developing applications powered by language models, provides the building blocks to create these capabilities. When combined with SingleStore's high-performance database, we can build production-ready applications that handle real-time data with sophisticated AI-powered features.

This chapter demonstrates how to use LangChain's integration with SingleStore to create a simple intelligent stock market analysis system. We'll explore five key patterns that form the foundation of most AI-powered data applications:

- **Natural Language Querying:** Transform conversational questions into SQL queries, allowing users to ask questions like "What is the average trading volume for \<stock symbol\>?" without writing a single line of SQL.

- **Retrieval-Augmented Generation (RAG):** Combine vector similarity search with language models to provide contextually relevant answers from a knowledge base about company information.

- **Conversational Memory:** Maintain conversation history across multiple interactions, enabling follow-up questions that reference previous context, like "Now compare \<stock symbol 1\> with \<stock symbol 2\> for the same period."

- **Multi-Tool Orchestration:** Intelligently route queries between structured data (SQL) and unstructured knowledge (vector search), automatically determining which data source best answers each question.

- **Semantic Caching:** Improve response times and reduce API costs by caching semantically similar queries, recognizing that "What factors influence \<company name\>'s stock price?" and "Why does \<company name\>'s stock move up or down?" are essentially the same question.

The stock ticker scenario provides an ideal demonstration environment as it combines trading data in a time-series table with background company information in a vector store, representing the data challenges often seen in production applications. By the end of this chapter, we'll see how to architect LangChain applications that seamlessly integrate with SingleStore.

## Stockticker Data

### Create the Database and Tick Table

In the SingleStore Portal, we'll use the **SQL Editor** to create a new database. Call this `stockticker_db`, as follows:

```sql
CREATE DATABASE IF NOT EXISTS stockticker_db;
```

We'll also create a table, as follows:

```sql
USE stockticker_db;

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

DROP TABLE IF EXISTS chat_history;
```

### Fill out the Notebook

Let's now create a new Python notebook. We'll call it **data_loader_for_stockticker**.

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

We are now ready to write the DataFrame to SingleStore. First, we'll create a connection:

```python
from sqlalchemy import *

db_connection = create_engine(connection_url)
```

Next, we'll ensure that all the table is empty:

```python
with db_connection.begin() as conn:
    conn.execute(text("TRUNCATE TABLE tick;"))
```

Finally, we'll write the DataFrame to SingleStore:

```python
tick_df.to_sql(
    "tick",
    con = db_connection,
    if_exists = "append",
    index = False,
    chunksize = 1000
)
```

This gives us a dataset that we can use with LangChain in the next section.

## LangChain

In this section. we'll use LangChain with SingleStore and test the key capabilities we discussed earlier.

### Fill out the Notebook

Let's now create a new Python notebook. We'll call it **langchain**.

First, we'll set our models and retrieve our OpenAI API Key from the secrets vault. We'll need the OpenAI API Key for generating vector embeddings. We'll access the OpenAI API Key using `get_secret`:

```python
LLM_MODEL = ...
EMBEDDING_MODEL = ...

os.environ["OPENAI_API_KEY"] = get_secret("OPENAI_API_KEY")
```

Next, we'll set our OpenAI model:

```python
llm = ChatOpenAI(
    model = LLM_MODEL,
    temperature = 0
)
```

#### Natural Language

Let's start with natural language. First, we'll connect to SingleStore:

```python
try:
    db = SQLDatabase.from_uri(
        connection_url,
        include_tables = ["tick"]
    )
except SQLAlchemyError as e:
    print(f"Error connecting to the database: {e}")
    exit()
```

Now, we'll create our SQL Agent using the previous information:

```python
sql_agent_executor = create_sql_agent(
    llm = llm,
    db = db,
    agent_type = "openai-tools",
    verbose = False
)
```

To query the database, we'll create a helper function and tool, as follows:

```python
def query_tick(question: str) -> str:
    """
    Ask a natural language question to the SQL agent and return only the text output.
    """
    try:
        result = sql_agent_executor.invoke({"input": question})
        return result.get("output", "").strip()
    except Exception as e:
        return f"Tool Error: Could not execute SQL query: {e}"

tick_tool = Tool(
    name = "TickTable",
    func = query_tick,
    description = "Use this to query the tick table in natural language about stock prices, volumes and time."
)
```

Now, we'll can ask some questions. First, let's look for a specific stock symbol and ask for tabular output:

```python
print(query_tick(
    "Show me the last 5 ticks for BBRQ-FX. Present the result as a table."
    )
)
```

Example output:

```text
Here are the last 5 ticks for BBRQ-FX:

| ts                  | open    | high    | low     | close   | volume   |
|---------------------|---------|---------|---------|---------|----------|
| 2015-11-24 00:00:00 | 999.83  | 1017.41 | 985.60  | 1004.39 | 2066982  |
| 2015-11-23 00:00:00 | 1020.74 | 1039.59 | 1010.85 | 1019.04 | 2005610  |
| 2015-11-20 00:00:00 | 991.68  | 992.87  | 977.93  | 990.32  | 1995583  |
| 2015-11-19 00:00:00 | 1001.18 | 1008.44 | 992.92  | 1003.77 | 33279776 |
| 2015-11-18 00:00:00 | 1037.09 | 1052.68 | 1023.30 | 1042.63 | 5600879  |
```

Next, let's try a broader question:

```python
print(query_tick(
    "Which ticker had the highest close price?"
    )
)
```

Example output:

```text
The ticker with the highest close price is WVVF-FX with a close price of 6301.59.
```

Next, let's try something that requires some calculation:

```python
print(query_tick(
    "What is the average trading volume for BJBY-FX?"
    )
)
```

Example output:

```text
The average trading volume for BJBY-FX is approximately 6,702,839.
```

Finally, let's try something a little more complex:

```python
print(query_tick(
    "Using the latest timestamp in the tick table as the reference, "
    "return all tickers from the 10 seconds before that timestamp "
    "where the close price is above 500 and sort the results alphabetically by ticker."
    )
)
```

Example output:

```text
The tickers from the 10 seconds before the latest timestamp in the tick table where the close price is above 500, sorted alphabetically, are:

1. BBRQ-FX
2. BBYX-FX
3. BKCZ-FX
4. BMJH-FX
5. BPDZ-FX
6. BPKV-FX
7. BTSP-FX
8. CCMN-FX
9. CGHY-FX
10. CHWP-FX

All these ticks have the latest timestamp of 2015-11-24 00:00:00.
```

All the results appear plausible, but should be checked carefully. Switching verbose mode to `True` in the SQL Agent would show us more details about each query. For example, in the last query above, LangChain uses an equality operator (`=`) for comparison, but timestamps often include fractional seconds, so using a range (`>=` and `<=`) would be safer.

#### Retrieval Aaugmented Rgeneration (RAG)

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
    Document(page_content = text, metadata = {"symbol": sym})
    for sym, text in company_info.items()
]
```

We'll use an OpenAI embedding model and determine the length of the vectors that it returns using a test string:

```python
embeddings = OpenAIEmbeddings(
    model = EMBEDDING_MODEL
)

dimensions = len(embeddings.embed_query("test"))
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

Now we're ready to use the SingleStore LangChain integration to store the company data:

```python
vector_store = SingleStoreVectorStore(
    embeddings,
    table_name = "company_knowledge",
    distance_strategy = "DOT_PRODUCT",
    use_vector_index = True,
    vector_size = dimensions
)

vector_store.add_documents(documents);
```

We'll quickly check what was stored by retrieving the data from the database into a Pandas DataFrame:

```python
df = pd.read_sql(
    """
    SELECT LEFT(content, 30) AS content, LEFT(vector :> JSON, 30) AS vector, metadata::symbol AS metadata
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
0  HRPD Technologies is a semicon  [-0.010345459,-0.0561523438,0.  HRPD-FX
1  BJBY Dynamics is a consumer el  [0.0344238281,0.000962734222,0  BJBY-FX
2  BBRQ Corp is a global technolo  [0.0343017578,-0.0219573975,0.  BBRQ-FX
3  YWMG Group is an e-commerce an  [-0.00539016724,0.0135269165,0  YWMG-FX
```

We'll also quickly check that the semantic search works for the four key demo stocks we stored. First, BBRQ.

```python
print(vector_store.similarity_search(
    "What are the most popular consumer devices and services that BBRQ sells?",
    k = 1
)[0].page_content)
```

Example output:

```text
BBRQ Corp is a global technology conglomerate known for its enterprise software platforms, cloud infrastructure services and a dominant position in business productivity tools.
```

Next, BJBY.

```python
print(vector_store.similarity_search(
    "Describe BJBY's main contributions to consumer electronics.",
    k = 1
)[0].page_content)
```

Example output:

```text
BJBY Dynamics is a consumer electronics and devices company renowned for its flagship smartphone line, wearable technology and a fast-growing digital services ecosystem.
```

Next, YWMG.

```python
print(vector_store.similarity_search(
    "Can you detail the core technologies and services provided by YWMG?",
    k = 1
)[0].page_content)
```

Example output:

```text
YWMG Group is an e-commerce and logistics powerhouse with expanding interests in cloud computing, digital advertising and subscription-based media streaming.
```

Finally, HRPD.

```python
print(vector_store.similarity_search(
    "What are the primary sectors in which HRPD operates?",
    k = 1
)[0].page_content)
```

Example output:

```text
HRPD Technologies is a semiconductor and hardware manufacturer supplying chips and processing units to the automotive, aerospace and artificial intelligence industries.
```

All is working well with the semantic search. Next, we'll explore how to use LangChain to store the full transcript of conversations.

#### Conversational Memory (in-memory)

Let's now create a temporary (non-persistent) conversational memory buffer and attach it to an agent so that the agent can recall earlier messages during a session. The memory lives only in RAM and disappears when the program ends.

```python
print("\n--- In-Memory Agent (No Persistence) ---")

in_memory = ConversationBufferMemory(
    memory_key = "chat_history",
    return_messages = False
)

agent_memory = initialize_agent(
    tools = [tick_tool],
    llm = llm,
    agent = "zero-shot-react-description",
    memory = in_memory,
    verbose = False,
    max_iterations = 6,
    handle_parsing_errors = True
)
```

We'll ask a few questions to fill the buffer. First, let's ask for the tick values for a particular stock symbol:

```python
print(agent_memory.invoke(
    "Show me the last 5 ticks for BBRQ-FX. Present the result as a table."
)["output"])
```

Example output:

```text
| Date       | Open    | High    | Low     | Close   | Volume     |
|------------|---------|---------|---------|---------|------------|
| 2015-11-24 | 999.83  | 1017.41 | 985.60  | 1004.39 | 2,066,982  |
| 2015-11-23 | 1020.74 | 1039.59 | 1010.85 | 1019.04 | 2,005,610  |
| 2015-11-20 | 991.68  | 992.87  | 977.93  | 990.32  | 1,995,583  |
| 2015-11-19 | 1001.18 | 1008.44 | 992.92  | 1003.77 | 33,279,776 |
| 2015-11-18 | 1037.09 | 1052.68 | 1023.30 | 1042.63 | 5,600,879  |
```

Next, let's compare tick values from two different stock symbols:

```python
print(agent_memory.invoke(
    "Now compare BBRQ-FX with BJBY-FX for the last 5 ticks."
)["output"])
```

Example output:

```text
BBRQ-FX consistently shows higher prices than BJBY-FX over the last 5 ticks. Volume for BBRQ-FX is generally higher except on 2015-11-24 when BJBY-FX had more than double the volume.
```

Finally, let's compare the last close price for two stock symbols:

```python
print(agent_memory.invoke(
    "Which had the higher last close, BBRQ-FX or BJBY-FX?"
)["output"])
```

Example output:

```text
BBRQ-FX had the higher last close price.
```

Let's now output the complete conversation history:

```python
print("\nCurrent conversation memory (in-memory buffer):\n")

for msg in in_memory.chat_memory.messages:
    role = msg.type.upper()
    print(f"{role}: {msg.content}")
```

Example output:

```text
Current conversation memory (in-memory buffer):

HUMAN: Show me the last 5 ticks for BBRQ-FX. Present the result as a table.
AI: | Date       | Open    | High    | Low     | Close   | Volume     |
|------------|---------|---------|---------|---------|------------|
| 2015-11-24 | 999.83  | 1017.41 | 985.60  | 1004.39 | 2,066,982  |
| 2015-11-23 | 1020.74 | 1039.59 | 1010.85 | 1019.04 | 2,005,610  |
| 2015-11-20 | 991.68  | 992.87  | 977.93  | 990.32  | 1,995,583  |
| 2015-11-19 | 1001.18 | 1008.44 | 992.92  | 1003.77 | 33,279,776 |
| 2015-11-18 | 1037.09 | 1052.68 | 1023.30 | 1042.63 | 5,600,879  |
HUMAN: Now compare BBRQ-FX with BJBY-FX for the last 5 ticks.
AI: BBRQ-FX consistently shows higher prices than BJBY-FX over the last 5 ticks. Volume for BBRQ-FX is generally higher except on 2015-11-24 when BJBY-FX had more than double the volume.
HUMAN: Which had the higher last close, BBRQ-FX or BJBY-FX?
AI: BBRQ-FX had the higher last close price.
```

and we can clear this conversation history, as follows:

```python
in_memory.clear()
```

#### Conversational Memory (persistent)

Now, let's persist the conversation history in SingleStore. First, we'll connect to SingleStore:

```python
from sqlalchemy import *

db_connection = create_engine(connection_url)
```

Next, let's create a function that consolidates the creation of persistent memory:

```python
def create_singlestore_agent_memory(
    session_id: str,
    table_name: str = "chat_history",
    clear_history: bool = True
) -> ConversationBufferMemory:
    """
    Consolidates the creation of SingleStore-backed memory for a LangChain Agent.

    Args:
        session_id: The unique ID for the conversation thread.
        table_name: The name of the table in SingleStore.
        clear_history: If True, clears the session's history before returning.

    Returns:
        A ConversationBufferMemory object ready for use in initialize_agent.
    """
    chat_history = SingleStoreChatMessageHistory(
        session_id = session_id,
        table_name = table_name,
    )

    if clear_history:
        chat_history.clear()

    memory = ConversationBufferMemory(
        memory_key = "chat_history",
        chat_memory = chat_history,
        return_messages = True
    )

    return memory
```

Let's now create a persistent conversational memory buffer and attach it to an agent so that the agent can recall earlier messages during a session.

```python
print("\n--- Persistent Agent (SingleStore Only) ---")

session_id = "persistent"
persistent_memory = create_singlestore_agent_memory(
    session_id = session_id,
    table_name = "chat_history",
    clear_history = True
)

agent_persistent = initialize_agent(
    tools = [tick_tool],
    llm = llm,
    agent = "zero-shot-react-description",
    memory = persistent_memory,
    verbose = False,
    max_iterations = 6,
    handle_parsing_errors = True
)
```

We'll test this now with the same queries we used earlier. First, let's ask for the tick values for a particular stock symbol:

```python
print(agent_persistent.invoke(
    "Show me the last 5 ticks for BBRQ-FX. Present the result as a table."
)["output"])
```

Example output:

```text
| Date       | Open    | High    | Low     | Close   | Volume    |
|------------|---------|---------|---------|---------|-----------|
| 2015-11-24 | 999.83  | 1017.41 | 985.60  | 1004.39 | 2,066,982 |
| 2015-11-23 | 1020.74 | 1039.59 | 1010.85 | 1019.04 | 2,005,610 |
| 2015-11-20 | 991.68  | 992.87  | 977.93  | 990.32  | 1,995,583 |
| 2015-11-19 | 1001.18 | 1008.44 | 992.92  | 1003.77 | 33,279,776|
| 2015-11-18 | 1037.09 | 1052.68 | 1023.30 | 1042.63 | 5,600,879 |
```

Next, let's compare tick values from two different stock symbols:

```python
print(agent_persistent.invoke(
    "Now compare BBRQ-FX with BJBY-FX for the last 5 ticks."
)["output"])
```

Example output:

```text
Over the last 5 ticks, BBRQ-FX has consistently higher prices (more than double) compared to BJBY-FX. Volume for BBRQ-FX is generally higher, notably on 2015-11-19 where it is significantly larger. BJBY-FX has lower prices and somewhat lower or comparable volumes on other days.
```

Finally, let's compare the last close price for two stock symbols:

```python
print(agent_persistent.invoke(
    "Which had the higher last close, BBRQ-FX or BJBY-FX?"
)["output"])
```

Example output:

```text
BBRQ-FX had the higher last close price.
```

Let's now output the complete persistent history:

```python
with db_connection.connect() as conn:
    rows = conn.execute(
        text("SELECT id, session_id, message FROM chat_history WHERE session_id = :sid ORDER BY id"),
        {"sid": session_id}
    ).fetchall()

print(f"Current conversation memory (persistent-memory buffer) for session: '{session_id}':\n")
for r in rows:
    msg = r.message
    role = msg.get("type", "unknown").upper()
    content = msg.get("data", {}).get("content", "")
    print(f"{role}: {content}")
```

Example output:

```text
Current conversation memory (persistent-memory buffer) for session: 'persistent':

HUMAN: Show me the last 5 ticks for BBRQ-FX. Present the result as a table.
AI: | Date       | Open    | High    | Low     | Close   | Volume    |
|------------|---------|---------|---------|---------|-----------|
| 2015-11-24 | 999.83  | 1017.41 | 985.60  | 1004.39 | 2,066,982 |
| 2015-11-23 | 1020.74 | 1039.59 | 1010.85 | 1019.04 | 2,005,610 |
| 2015-11-20 | 991.68  | 992.87  | 977.93  | 990.32  | 1,995,583 |
| 2015-11-19 | 1001.18 | 1008.44 | 992.92  | 1003.77 | 33,279,776|
| 2015-11-18 | 1037.09 | 1052.68 | 1023.30 | 1042.63 | 5,600,879 |
HUMAN: Now compare BBRQ-FX with BJBY-FX for the last 5 ticks.
AI: Over the last 5 ticks, BBRQ-FX has consistently higher prices (more than double) compared to BJBY-FX. Volume for BBRQ-FX is generally higher, notably on 2015-11-19 where it is significantly larger. BJBY-FX has lower prices and somewhat lower or comparable volumes on other days.
HUMAN: Which had the higher last close, BBRQ-FX or BJBY-FX?
AI: BBRQ-FX had the higher last close price.
```

#### Natural Language and RAG

We'll combine natural language and RAG. First, let's create a vector store retriever, define the RAG prompt and create the document and RAG chains, as follows:

```python
company_retriever = vector_store.as_retriever(search_kwargs = {"k": 1})

rag_prompt = ChatPromptTemplate.from_template(
    """
    You are a helpful assistant. Use the following context to answer the user's question.
    If the context does not contain the answer, politely state that the information is not in your knowledge base.

    Context: {context}

    Question: {input}
    """
)

document_chain = create_stuff_documents_chain(llm, rag_prompt)

rag_chain = create_retrieval_chain(company_retriever, document_chain)
```

We'll define a function that queries a RAG chain for company background information and returns the answer, then wraps that function into a LangChain Tool so agents can call it to look up company info.

```python
def query_company_info_lcel(question: str) -> str:
    """Use this to get background info about a company."""
    result = rag_chain.invoke({"input": question})
    return result["answer"]

company_tool = Tool(
    name = "CompanyKnowledge",
    func = query_company_info_lcel,
    description = "Use this to get background info about a company using its stock symbol or company name."
)
```

Next, let's create a new session with persistent SingleStore-backed conversational memory and build an agent that can use both tools (tick data and company info) while retaining conversation history across runs.

```python
print("\n--- Natural Language and RAG Agent (Combined) ---")

session_id = "combined"
combined_memory = create_singlestore_agent_memory(
    session_id = session_id,
    table_name = "chat_history",
    clear_history = True
)

agent_combined = initialize_agent(
    tools = [tick_tool, company_tool],
    llm = llm,
    agent = "zero-shot-react-description",
    memory = combined_memory,
    verbose = False,
    max_iterations = 6,
    handle_parsing_errors = True
)
```

Let's test the combined agent. First, let's get tick data for a stock symbol:

```python
print(agent_combined.invoke(
    "Show me the last 5 ticks for BBRQ-FX. Present the result as a table."
)["output"])
```

Example output:

```text
| Date       | Open    | High    | Low     | Close   | Volume     |
|------------|---------|---------|---------|---------|------------|
| 2015-11-24 | 999.83  | 1017.41 | 985.60  | 1004.39 | 2,066,982  |
| 2015-11-23 | 1020.74 | 1039.59 | 1010.85 | 1019.04 | 2,005,610  |
| 2015-11-20 | 991.68  | 992.87  | 977.93  | 990.32  | 1,995,583  |
| 2015-11-19 | 1001.18 | 1008.44 | 992.92  | 1003.77 | 33,279,776 |
| 2015-11-18 | 1037.09 | 1052.68 | 1023.30 | 1042.63 | 5,600,879  |
```

Now, we'll try a RAG query:

```python
print(agent_combined.invoke(
    "What products does BJBY make?"
)["output"])
```

Example output:

```text
BJBY makes consumer electronics and devices, including a flagship smartphone line, wearable technology, and provides a fast-growing digital services ecosystem.
```

and a follow-on query:

```python
print(agent_combined.invoke(
    "Now do the same for HRPD."
)["output"])
```

Example output:

```text
HRPD Technologies is a semiconductor and hardware manufacturer supplying chips and processing units to the automotive, aerospace, and artificial intelligence industries. However, there is no recent stock price, volume, or time data available for HRPD in the tick table. If you need information on another company or symbol, please let me know.
```

#### Semantic Caching

Finally, let's see how we could benefit from semantic caching. We'll create a SingleStore-backed semantic cache that stores and retrieves LLM responses using embeddings and then sets it as the global cache so repeated or similar queries can run without re-calling the model.

```python
semantic_cache = SingleStoreSemanticCache(
    embedding = embeddings,
    search_threshold = 0.75,
    distance_strategy = DistanceStrategy.DOT_PRODUCT
)

set_llm_cache(semantic_cache)
print("SingleStore Semantic Cache initialized and set globally.")
```

We'll use a patch that replaces the cache's lookup method so it first tries semantic vector search to find a similar past prompt and if that fails or scores too low, it falls back to exact string matching. This ensures more reliable cache hits by combining embedding-based retrieval with strict equality as a backup.

```python
def semantic_lookup(self, prompt: str, llm_string: str):
    """
    Lookup using embeddings similarity with exact-match fallback.
    Vector search is attempted first, then exact-match if needed.
    """
    llm_cache = self._get_llm_cache(llm_string)

    try:
        vector = self.embedding.embed_query(prompt)
        results = llm_cache.similarity_search_by_vector(
            vector = vector,
            k = 1,
            embedding = self.embedding
        )
        if results:
            doc, score = results[0]
            if ((llm_cache.distance_strategy == DistanceStrategy.DOT_PRODUCT and score >= self.search_threshold) or
                (llm_cache.distance_strategy == DistanceStrategy.EUCLIDEAN_DISTANCE and score <= self.search_threshold)):
                return loads(doc.metadata["return_val"])
    except Exception as e:
        pass

    for doc in getattr(llm_cache, "docs", []):
        if doc.page_content == prompt:
            return loads(doc.metadata["return_val"])

    return None

SingleStoreSemanticCache.lookup = semantic_lookup
```

Now, we'll write a function that checks the semantic cache for a matching response and returns it instantly if found. Otherwise, it times a real LLM call, stores the new result in the cache and returns both the output and how long the uncached call took.

```python
def timed_llm_call(llm, prompt, semantic_cache):
    llm_string = llm._get_llm_string()

    cached_result = semantic_cache.lookup(prompt, llm_string)
    if cached_result:
        return cached_result[0].text, 0.0

    start_time = time.time()
    result = llm.invoke(prompt)
    elapsed = time.time() - start_time

    semantic_cache.update(
        prompt = prompt,
        llm_string = llm_string,
        return_val = [Generation(text = result.content)]
    )
    return result.content, elapsed
```

Before we run any queries, we'll clear the cache:

```python
semantic_cache.clear(llm_string = llm._get_llm_string())
print("Cache cleared for a fresh run.")
```

First, let's start with a cache miss:

```python
print("\n--- First Call (Cache Miss) ---")
prompt1 = "Explain the key factors influencing BBRQ’s stock price."
result1, time1 = timed_llm_call(llm, prompt1, semantic_cache)
print(f"Prompt: {prompt1}\nTime: {time1:.2f}s\nResult: {result1[:80]}...")
```

Example output:

```text
--- First Call (Cache Miss) ---
Prompt: Explain the key factors influencing BBRQ’s stock price.
Time: 7.11s
Result: To explain the key factors influencing BBRQ’s stock price, it’s important to con...
```

Now, let's try a query similar to the previous query which should use the cached result:

```python
print("\n--- Second Call (Semantic Hit - Expect faster response) ---")
prompt2 = "What are the main reasons for BBRQ’s stock price moving up or down?"
result2, time2 = timed_llm_call(llm, prompt2, semantic_cache)
print(f"Prompt: {prompt2}\nTime: {time2:.2f}s\nResult: {result2[:80]}...")
```

Example output:

```text
--- Second Call (Semantic Hit - Expect faster response) ---
Prompt: What are the main reasons for BBRQ’s stock price moving up or down?
Time: 3.66s
Result: To provide an accurate answer about the main reasons for BBRQ’s stock price move...
```

We see that the cached result is faster.

Finally, let's try an unrelated query, which would be another cache miss:

```python
print("\n--- Third Call (Cache Miss - Expect slow response) ---")
prompt3 = "What is the process of nuclear fusion?"
result3, time3 = timed_llm_call(llm, prompt3, semantic_cache)
print(f"Prompt: {prompt3}\nTime: {time3:.2f}s\nResult: {result3[:80]}...")
```

Example output:

```text
--- Third Call (Cache Miss - Expect slow response) ---
Prompt: What is the process of nuclear fusion?
Time: 6.19s
Result: Nuclear fusion is the process by which two light atomic nuclei combine to form a...
```

We see that the result is slightly slower than the previous query.

## Summary

This chapter demonstrated the power of combining LangChain with SingleStore to build AI-powered data applications. Through a stock market analysis use case, we explored five distinct patterns that solve common challenges in modern application development.

The chapter illustrated several architectural patterns worth noting:

- **Separation of Concerns:** The `tick` table handled high-frequency time-series data while the vector store managed semi-static knowledge, demonstrating SingleStore's versatility in handling different data modalities within a single database.

- **Session Management:** The `SingleStoreChatMessageHistory` implementation showed how to structure conversational sessions using unique session IDs, allowing concurrent users and conversation isolation.

- **Tool Abstraction:** By wrapping database operations in LangChain Tools, we created reusable components that can be composed into more complex agents as our application grows.

- **Caching Strategy:** The semantic cache implementation demonstrated the trade-off between search threshold and cache hit rate, a critical tuning parameter for production deployments.

While the examples focused on core functionality, several considerations emerge for production deployments:

- **Error Handling:** The code includes try-catch blocks around LLM calls and database operations, but production systems should implement comprehensive retry logic and fallback strategies.

- **Rate Limiting:** The semantic cache helps reduce LLM API calls, but we should also implement request throttling to manage costs and prevent abuse.

- **Security:** The SQL agent was restricted to read-only operations and specific tables. Production systems require additional safeguards including query validation, result filtering and user authorization.

- **Monitoring:** Instrumenting cache hit rates, query latencies and LLM token usage provides visibility into system performance and cost optimization opportunities.

The patterns demonstrated in this chapter can form the foundation for more advanced applications. For example, we could extend this implementation to include:

- Real-time alerting when specific stock conditions are met.

- Multi-step reasoning chains that combine technical analysis with fundamental data.

- Custom tool development for specialized financial calculations.

- Integration with external data sources through LangChain's extensive connector ecosystem.

By mastering these core patterns -- natural language querying, vector-based retrieval, conversational memory, multi-tool orchestration and semantic caching -- we've acquired the essential building blocks for creating intelligent, data-driven applications that feel natural to users while using the full power of distributed SQL and vector capabilities.
