# Chapter 22: Using MCP for Real-Time Data Access

## Introduction

As AI agents become more capable and more deeply embedded in software systems, the need for a consistent and reliable way to connect those agents to real services has become increasingly important. Large language models can reason about data, generate SQL, transform documents and orchestrate workflows, but they cannot interact with actual systems unless developers expose those systems in a controlled and structured way. This is exactly the problem the Model Context Protocol (MCP) solves.

MCP provides a standardized, tool-centric interface that lets agents invoke well-defined operations, called tools, without needing to understand proprietary APIs, authentication schemes or service-specific response formats. Any system that implements MCP immediately becomes accessible to any MCP-compatible client, whether that client is a local script, a CLI or a multimodal LLM. The result is a predictable and secure integration layer between AI and software infrastructure.

In this chapter, we'll explore MCP from two complementary perspectives. First, we'll build a small custom MCP server to demonstrate how the protocol works at a fundamental level, covering initialization, tool registration, communication and basic tool execution. This example shows how easy it is to expose business logic or domain-specific functionality through MCP.

Second, we'll turn to a production-grade implementation: the SingleStore MCP server. Rather than writing boilerplate code, we can use an off-the-shelf MCP server that exposes database operations, such as listing workspaces, running SQL and inspecting schemas directly to our agent. To make this practical, we'll use a lightweight CLI client that communicates with the SingleStore MCP server and shows how an AI agent can use MCP to query and reason about real databases.

These two sections provide both a conceptual understanding and a practical foundation for using MCP in real-world applications.

## Building a Custom MCP Server

### Introduction

An MCP server can be viewed as a standardized bridge between AI agents and our services. Instead of an agent having to learn different APIs, authentication methods and response formats, it calls well-defined tools through the MCP protocol. This means a single MCP server can work with many external tools or any MCP-compatible host.

The SingleStore MCP server is powerful for accessing a database and we'll configure and run it in the next section in this chapter. But what if we need to expose custom business logic, connect to external APIs or create domain-specific tools that combine multiple data sources? That's where building a custom MCP server would be useful.

### Why Build a Custom MCP Server?

Custom MCP servers are useful when we need to:

- **Wrap business logic:** Expose internal functions as tools that AI agents can safely call.

- **Integrate multiple data sources:** Combine APIs, databases and files into unified tools.

- **Add security boundaries:** Control exactly what data and operations agents can access.

- **Standardize interfaces:** Give agents a consistent way to interact with diverse services.

- **Enable offline work:** Run everything locally without external API dependencies.

### Architecture Overview

An MCP server follows a simple client-server pattern. The MCP server is a lightweight process that listens for requests from an MCP host and works as follows:

- **MCP Host:** Starts an MCP server as a subprocess.

- **MCP Server:** Initializes and announces what tools it exposes via standard I/O.

- **MCP Host:** Displays available tools to the user/agent.

- **When needed:** MCP Host sends tool requests to the MCP Server.

- **MCP Server:** Executes the tool and returns results back to the host.

Communication happens over standard input/output (`stdio`), making it easy to run locally.

### Building a Simple MCP Server

We'll build a simple stock ticker data server. This has three practical tools that show different patterns:

- **get_stock_price:** Single parameter lookup.

- **get_stock_sentiment:** Data with analysis logic.

- **compare_stocks:** Multiple parameters, comparative analysis.

All are hardcoded so we can see the server works without any database setup.

### Set up the Environment

We'll use Python with the FastMCP SDK, which simplifies server creation significantly.

First, we'll create a virtual environment from the home directory:

```shell
python3 -m venv venv
source venv/bin/activate
```

Next, we'll create a project directory:

```shell
mkdir stock-analyzer-mcp
cd stock-analyzer-mcp
```

### Install the Required Software

We need to install the required Python packages before running the project. These are listed in the requirements.txt file included on GitHub. You can install them all at once with the following command:

```shell
pip install -r requirements.txt
```

### Create the MCP Server

We'll create a file called `server.py`, as follows:

```python
from fastmcp import FastMCP

mcp = FastMCP("stock-analyzer")

STOCK_DATA = {
    "BBRQ-FX": {
        "price": 150.25,
        "high_52w": 199.62,
        "low_52w": 124.17,
        "volume": 52_300_000,
        "pe_ratio": 28.5
    },
    "BJBY-FX": {
        "price": 140.80,
        "high_52w": 191.75,
        "low_52w": 102.21,
        "volume": 28_900_000,
        "pe_ratio": 25.3
    },
    "YWMG-FX": {
        "price": 380.45,
        "high_52w": 416.68,
        "low_52w": 309.40,
        "volume": 18_500_000,
        "pe_ratio": 35.2
    }
}

SENTIMENT_DATA = {
    "BBRQ-FX": {
        "sentiment_score": 0.65,
        "recent_news": "BBRQ reports strong Q3 earnings",
        "positive_count": 12,
        "negative_count": 3
    },
    "BJBY-FX": {
        "sentiment_score": 0.45,
        "recent_news": "BJBY faces regulatory scrutiny",
        "positive_count": 8,
        "negative_count": 7
    },
    "YWMG-FX": {
        "sentiment_score": 0.72,
        "recent_news": "YWMG's AI initiatives show promise",
        "positive_count": 15,
        "negative_count": 2
    }
}

@mcp.tool()
def get_stock_price(symbol: str) -> str:
    """Get current stock price and 52-week range for a symbol."""
    symbol = symbol.upper().strip()
    
    if symbol not in STOCK_DATA:
        return f"Symbol {symbol} not found. Available: BBRQ-FX, BJBY-FX, YWMG-FX"

    data = STOCK_DATA[symbol]
    report = f"Stock Price Data for {symbol}\n"
    report += f"{'='*40}\n"
    report += f"Current Price: ${data['price']}\n"
    report += f"52-Week High: ${data['high_52w']}\n"
    report += f"52-Week Low: ${data['low_52w']}\n"
    report += f"Volume: {data['volume']:,}\n"
    report += f"P/E Ratio: {data['pe_ratio']}\n"

    return report

@mcp.tool()
def get_stock_sentiment(symbol: str) -> str:
    """Get sentiment analysis and recent news for a stock symbol."""
    symbol = symbol.upper().strip()
    
    if symbol not in SENTIMENT_DATA:
        return f"Sentiment data not available for {symbol}"

    data = SENTIMENT_DATA[symbol]
    report = f"Sentiment Analysis for {symbol}\n"
    report += f"{'='*40}\n"
    report += f"Sentiment Score: {data['sentiment_score']:.2f} (Range: 0 to 1)\n"
    report += f"Recent Headline: {data['recent_news']}\n"
    report += f"Positive Articles: {data['positive_count']}\n"
    report += f"Negative Articles: {data['negative_count']}\n"

    if data["sentiment_score"] > 0.6:
        report += "Overall Sentiment: [+] Positive\n"
    elif data["sentiment_score"] < 0.4:
        report += "Overall Sentiment: [-] Negative\n"
    else:
        report += "Overall Sentiment: [~] Neutral\n"

    return report

@mcp.tool()
def compare_stocks(symbol1: str, symbol2: str) -> str:
    """Compare two stocks by price performance and sentiment."""
    symbol1 = symbol1.upper().strip()
    symbol2 = symbol2.upper().strip()
    
    if symbol1 not in STOCK_DATA or symbol2 not in STOCK_DATA:
        return "One or both symbols not found. Available: BBRQ-FX, BJBY-FX, YWMG-FX"

    stock1 = STOCK_DATA[symbol1]
    stock2 = STOCK_DATA[symbol2]
    sentiment1 = SENTIMENT_DATA[symbol1]
    sentiment2 = SENTIMENT_DATA[symbol2]

    report = f"Stock Comparison: {symbol1} vs {symbol2}\n"
    report += f"{'='*40}\n"
    report += f"\nPrice Comparison:\n"
    report += f"  {symbol1}: ${stock1['price']} (P/E: {stock1['pe_ratio']})\n"
    report += f"  {symbol2}: ${stock2['price']} (P/E: {stock2['pe_ratio']})\n"

    higher_price = symbol1 if stock1["price"] > stock2["price"] else symbol2
    report += f"  -> {higher_price} is trading higher\n"

    report += f"\nSentiment Comparison:\n"
    report += f"  {symbol1}: {sentiment1['sentiment_score']:.2f}\n"
    report += f"  {symbol2}: {sentiment2['sentiment_score']:.2f}\n"

    better_sentiment = symbol1 if sentiment1["sentiment_score"] > sentiment2["sentiment_score"] else symbol2
    report += f"  -> {better_sentiment} has more positive sentiment\n"

    return report
```

We'll create a `main.py` entry point, as follows:

```python
from server import mcp

if __name__ == "__main__":
    mcp.run()
```

and a configuration file `server_config.json` in the `stock-analyzer-mcp` directory as follows:

```json
{
  "mcpServers": {
    "stock-analyzer": {
      "command": "python3",
      "args": ["/absolute/path/to/stock-analyzer-mcp/main.py"]
    }
  }
}
```

Replace `/absolute/path/to` with the full directory path in your environment.

### Example Queries

Let's test our tools. In the terminal window, we'll first use **interactive mode**:

```shell
mcp-cli interactive --server stock-analyzer
```

and then run:

```shell
/tools
```

Example output:

```text
3 Available Tools
┌────────────────┬─────────────────────┬────────────────────────────────────────────────────────────┐
│ Server         │ Tool                │ Description                                                │
├────────────────┼─────────────────────┼────────────────────────────────────────────────────────────┤
│ stock-analyzer │ get_stock_price     │ Get current stock price and 52-week range for a symbol.    │
│ stock-analyzer │ get_stock_sentiment │ Get sentiment analysis and recent news for a stock symbol. │
│ stock-analyzer │ compare_stocks      │ Compare two stocks by price performance and sentiment.     │
└────────────────┴─────────────────────┴────────────────────────────────────────────────────────────┘
```

Next, let's test `get_stock_price`: 

```text
execute get_stock_price '{"symbol": "BBRQ-FX"}'
```

Example output:

```json
{
  "success": true,
  "result": {
    "isError": false,
    "content": {
      "content": [
        {
          "type": "text",
          "text": "Stock Price Data for BBRQ-FX\n========================================\nCurrent Price: $150.25\n52-Week High: $199.62\n52-Week Low: $124.17\nVolume: 52,300,000\nP/E Ratio: 28.5\n"
        }
      ],
      "isError": false,
      "meta": {
        "fastmcp": {
          "wrap_result": true
        }
      },
      "structuredContent": {
        "result": "Stock Price Data for BBRQ-FX\n========================================\nCurrent Price: $150.25\n52-Week High: $199.62\n52-Week Low: $124.17\nVolume: 52,300,000\nP/E Ratio: 28.5\n"
      }
    }
  },
  "error": null,
  "tool_name": "get_stock_price",
  "duration_ms": 4.083,
  "attempts": 1,
  "from_cache": false
}
```

and now `get_stock_sentiment`:

```text
execute get_stock_sentiment '{"symbol": "BJBY-FX"}'
```

Example output:

```json
{
  "success": true,
  "result": {
    "isError": false,
    "content": {
      "content": [
        {
          "type": "text",
          "text": "Sentiment Analysis for BJBY-FX\n========================================\nSentiment Score: 0.45 (Range: 0 to 1)\nRecent Headline: BJBY faces regulatory scrutiny\nPositive Articles: 8\nNegative Articles: 7\nOverall Sentiment: [~] Neutral\n"
        }
      ],
      "isError": false,
      "meta": {
        "fastmcp": {
          "wrap_result": true
        }
      },
      "structuredContent": {
        "result": "Sentiment Analysis for BJBY-FX\n========================================\nSentiment Score: 0.45 (Range: 0 to 1)\nRecent Headline: BJBY faces regulatory scrutiny\nPositive Articles: 8\nNegative Articles: 7\nOverall Sentiment: [~] Neutral\n"
      }
    }
  },
  "error": null,
  "tool_name": "get_stock_sentiment",
  "duration_ms": 2.7,
  "attempts": 1,
  "from_cache": false
}
```

and finally `compare_stocks`:

```text
execute compare_stocks '{"symbol1": "BBRQ-FX", "symbol2": "YWMG-FX"}'
```

Example output:

```json
{
  "success": true,
  "result": {
    "isError": false,
    "content": {
      "content": [
        {
          "type": "text",
          "text": "Stock Comparison: BBRQ-FX vs YWMG-FX\n========================================\n\nPrice Comparison:\n  BBRQ-FX: $150.25 (P/E: 28.5)\n  YWMG-FX: $380.45 (P/E: 35.2)\n  -> YWMG-FX is trading higher\n\nSentiment Comparison:\n  BBRQ-FX: 0.65\n  YWMG-FX: 0.72\n  -> YWMG-FX has more positive sentiment\n"
        }
      ],
      "isError": false,
      "meta": {
        "fastmcp": {
          "wrap_result": true
        }
      },
      "structuredContent": {
        "result": "Stock Comparison: BBRQ-FX vs YWMG-FX\n========================================\n\nPrice Comparison:\n  BBRQ-FX: $150.25 (P/E: 28.5)\n  YWMG-FX: $380.45 (P/E: 35.2)\n  -> YWMG-FX is trading higher\n\nSentiment Comparison:\n  BBRQ-FX: 0.65\n  YWMG-FX: 0.72\n  -> YWMG-FX has more positive sentiment\n"
      }
    }
  },
  "error": null,
  "tool_name": "compare_stocks",
  "duration_ms": 5.516,
  "attempts": 1,
  "from_cache": false
}
```

We'll exit interactive mode. To use natural language, we'll first define an OpenAI API Key in the environment:

```shell
export OPENAI_API_KEY='<OpenAI API Key>'
```

Replace `<OpenAI API Key>` with your key.

Next, we'll use chat mode. For example:

```shell
mcp-cli --server stock-analyzer --provider openai --model gpt-4.1-mini
```

Now, we'll try some queries at the prompt.

```text
What is the current price of BBRQ-FX?
```

Example output:

```text
The current price of the stock BBRQ-FX is $150.25. If you need more information about this stock, feel free to ask!
```

Let's check sentiment:

```text
How is the sentiment for BJBY-FX?
```

Example output:

```text
The sentiment for the stock BJBY-FX is overall neutral with a sentiment score of 0.45 on a scale from 0 to 1. There are 8 positive articles and 7 negative articles recently. The latest headline mentions that BJBY faces regulatory scrutiny. If you want more details or a comparison with other stocks, let me know!
```

Finally, let's compare:

```text
Compare BBRQ-FX and YWMG-FX
```

Example output:

```text
Here's the comparison between BBRQ-FX and YWMG-FX:

Price Comparison:
- BBRQ-FX: $150.25 (P/E Ratio: 28.5)
- YWMG-FX: $380.45 (P/E Ratio: 35.2)
YWMG-FX is trading at a higher price.

Sentiment Comparison:
- BBRQ-FX sentiment score: 0.65
- YWMG-FX sentiment score: 0.72
YWMG-FX has a more positive sentiment overall.

If you need more detailed analysis or information on either stock, feel free to ask!
```

The results show that the simple MCP server is working well. Let's now see how to use SingleStore's MCP server with an actual database system.

## Using the SingleStore MCP Server

### Introduction

While a custom MCP server is useful for exposing domain-specific logic, most applications benefit from using existing, production-ready MCP servers where possible. The SingleStore MCP server is one such implementation: it exposes database operations, such as listing workspaces, running SQL queries and inspecting schemas directly through the MCP protocol. This allows AI agents and CLI tools to interact with SingleStore in a consistent and controlled manner, without requiring JDBC drivers, REST APIs or manual SQL handling.

In this section, we configure the SingleStore MCP server and connect to it using a simple MCP client. The goal is not to build new tools, but to demonstrate how an agent can use MCP to access a database with zero additional integration work. Once the environment is set up, the MCP server handles connection management, authentication and tool discovery automatically, giving us a clean and reliable interface for executing SQL and exploring database metadata.

### Set up the Environment

The SingleStore MCP server uses `uvx`, so we'll first ensure that `uv` is installed. The installation is global and not in a virtual (`venv`) environment.

```shell
curl -LsSf https://astral.sh/uv/install.sh | sh
```

To use natural language, we’ll first define an OpenAI API Key in the environment:

```shell
export OPENAI_API_KEY='<OpenAI API Key>'
```

Replace `<OpenAI API Key>` with your key.

The `server_config.json` file also needs to be updated:

```json
{
  "mcpServers": {
    "stock-analyzer": {
      "command": "python3",
      "args": ["/absolute/path/to/stock-analyzer-mcp/main.py"]
    },
    "singlestore-mcp-server": {
      "command": "/absolute/path/to/.local/bin/uvx",
      "args": ["singlestore-mcp-server", "start"]
    }
  }
}
```

Replace `/absolute/path/to` with the full directory path in your environment.

### Test the MCP Server

Let's now test the server:

```shell
mcp-cli --server singlestore-mcp-server --provider openai --model gpt-4.1-mini
```

When run, it will first attempt to authenticate with the SingleStore Cloud using OAuth. A browser will launch requiring the SingleStore Cloud **username** and **password**.

> **Note:** If you run into a stale or malformed authentication error with the SingleStore MCP server, delete the cached credentials file (`~/.singlestore/credentials.json`) and restart the server to trigger a fresh OAuth login.

### Example Queries

Once authenticated, we'll run various commands using the supported tools. Let's test a few commands:

```text
Show me my workspaces
```

Example output:

```text
You have one starter workspace:

- Name: workspace-144b0505
- Database Name: db_mr_blobby
- Endpoint: svc-3482219c-a389-4079-b18b-d50662524e8a-shared-dml.aws-virginia-6.svc.singlestore.com:3333
- Virtual Workspace ID: aeadfa2e-4126-48bb-b3f2-7dcd305dd893
- MySQL DML Port: 3333
- WebSocket Port: 443

There are no other workspace groups in your organization. Let me know if you want to do anything else with this workspace or others.
```

Let's see if there are any tables:

```text
What tables do I have?
```

Example output:

```text
In your workspace "workspace-144b0505" and database "db_mr_blobby," you have the following tables:

1. agent_decisions
2. portfolio
3. stock_sentiment
4. tick

If you want, I can provide more details or query data from any of these tables.
```

Let's create a new table:

```text
Create a table called users with id INT and name VARCHAR(100)
```

Example output:

```text
The table "users" with columns "id" (INT) and "name" (VARCHAR(100)) has been successfully created in your database "db_mr_blobby." If you need anything else like inserting data or querying this new table, just let me know.
```

Let's create some data in the new table:

```test
Fill the users table with 10 rows of sample data
```

Example output:

```text
I have inserted 10 rows of sample data into the users table. The table now contains users with the following names: Alice, Bob, Charlie, Diana, Ethan, Fiona, George, Hannah, Ian, and Jane. If you want to see the data or perform any other operations, please let me know.
```

Let's try a query:

```text
Query: SELECT * FROM users LIMIT 5
```

Example output:

```text
Here are the first 5 rows from the users table:

1. id: 4, name: Diana
2. id: 6, name: Fiona
3. id: 10, name: Jane
4. id: 9, name: Ian
5. id: 2, name: Bob

If you want to see more rows or need further assistance, please let me know.
```

## Summary

In this chapter, we examined the Model Context Protocol (MCP) from both a foundational and a practical perspective. We began by building a custom MCP server to illustrate how AI agents can interact with external systems through standardized tools. This example demonstrated server initialization, tool registration, communication and how to expose domain-specific logic in a controlled and consistent way. Even a simple implementation shows how MCP can unify access to business functions, APIs and analytical workflows without requiring agents to learn proprietary interfaces.

We then transitioned to a production scenario using the SingleStore MCP server. Instead of writing our own tooling, we used a fully supported MCP implementation that exposes database capabilities such as workspace discovery, SQL execution and schema exploration directly through the protocol. By connecting to this server with a lightweight CLI client, we saw how an agent can work with a database using the same standardized tool pattern used in the custom example. This reinforces one of MCP's core strengths: once a system implements the protocol, any compatible client or agent can interact with it immediately.
