# Chapter 24: Conclusions

When we started this book, we set out a simple premise: rather than stitching together multiple specialized systems to support a modern, data-intensive application, SingleStore could serve as the single, unified platform underneath it all. Over the preceding chapters, we put that premise to the test across time series, geospatial, JSON, full-text and vector data, streaming pipelines, machine learning workflows and, finally, AI and agentic systems. Looking back across all of it, the premise holds up well.

## What We Covered

**Part 1** grounded us in SingleStore's multi-model foundations. We worked with time series stock data, geospatial data for the London Underground, JSON-based library inventories, full-text search over synthetic journal articles and vector embeddings for Fashion-MNIST images. Each chapter made the same underlying point in a different way: SingleStore didn't need a separate specialized engine bolted on for each of these data types. The same distributed SQL engine handled all of them, with dedicated functions and indexes for each.

**Part 2** moved from storage to motion. We used SingleStore Pipelines with Apache Kafka to ingest streaming IoT sensor data and, in the same chapter, used SingleStore as a Kafka producer to push data back out. We connected Apache Spark to SingleStore, explored query pushdown and used GraphFrames for graph analytics. Finally, we used Change Data Capture to keep a SingleStore database continuously in sync with a MongoDB Atlas cluster. Across all three chapters, the theme was consistency: data flowing in from multiple sources and directions, landing in the same place, ready to query.

**Part 3** put that data to work. We built predictive models for loan approvals, credit card fraud detection, image classification, movie recommendations, crop yield prediction, crime hotspot analysis and in-database sentiment analysis using WebAssembly, and we built a feature store with Feast. Whatever the modeling technique, be it logistic regression, SHAP and LIME explanations, collaborative filtering, Keras and TensorFlow or scikit-learn, SingleStore consistently played the same two roles: a place to store and query the data driving the models, and a place to store and serve the results, embeddings and features those models produced.

**Part 4** brought everything together around large language models and AI agents. We used LangChain and LlamaIndex to build natural language interfaces over stock market data, explored multimodal RAG across PDFs, images and voice, ran fully local LLMs with Ollama, connected agents to real-time data through MCP and, in our final chapter, built a multi-agent trading system where SingleStore served simultaneously as feature store, memory layer, coordination mechanism and audit log for a Chain of Responsibility pipeline of cooperating agents.

## Recurring Themes

A few ideas surfaced again and again across this book, regardless of the specific technology in play:

- **Unification over fragmentation.** Whether the task involved SQL and JSON, SQL and vectors or SQL and geospatial functions, SingleStore consistently let us combine data models in a single query rather than joining across separate systems.

- **Synthetic and fictitious data, used deliberately.** Many of our datasets, from the `-FX` stock tickers to the synthetic loan, agriculture and movie recommendation data, were generated rather than scraped from real, licensed sources. This kept the book's examples reproducible, free of licensing complications and safe to run without touching sensitive or proprietary data, while still preserving the statistical texture of real-world data.

- **From data to decisions.** Book by book, we moved further up the stack: from storing data, to querying it, to modeling it, to having language models and agents reason over it directly. SingleStore's role stayed constant even as the applications on top of it became more sophisticated.

- **Real-time as the default, not the exception.** Pipelines, Change Data Capture, streaming sentiment scores and live agent decision logs all point to the same underlying capability: SingleStore is built to keep data current, not just to store it.

## Where to Go from Here

The code, notebooks and datasets for every chapter are available in the book's GitHub repo, [singlestore-cookbook.github.io](https://singlestore-cookbook.github.io). Each chapter's examples are generally self-contained. If a particular pattern in this book, be it vector search, agentic pipelines or feature stores, maps onto a problem in front of you, that's a good place to start experimenting further.

Data infrastructure will keep evolving and new specialized systems will keep appearing to solve narrow problems well. But the case we've made throughout this book is that many of these problems, perhaps more than we tend to assume, can be solved within a single, unified platform. We hope the examples in this book give you a solid, practical starting point for finding out where that's true for your own applications.
