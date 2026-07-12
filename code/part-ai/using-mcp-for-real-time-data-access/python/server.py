"""
Stock Analyzer MCP Server
A simple MCP server demonstrating tool creation with hardcoded stock data.
In production, this would connect to real data sources or APIs.
"""

from fastmcp import FastMCP

# Initialize the MCP server
mcp = FastMCP("stock-analyzer")

# Hardcoded sample data for demonstration
# In production, this would connect to a real data source or API
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
    symbol = symbol.upper().strip()  # Normalize input
    
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
    symbol = symbol.upper().strip()  # Normalize input
    
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
    symbol1 = symbol1.upper().strip()  # Normalize input
    symbol2 = symbol2.upper().strip()  # Normalize input
    
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