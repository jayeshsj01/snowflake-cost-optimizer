# Snowflake Cost Optimization Engine

A Snowflake-based FinOps system for analyzing warehouse usage, query performance and compute costs, and identifying practical opportunities to reduce unnecessary consumption.

The project uses Snowflake usage telemetry, SQL analytics, configurable optimization rules, Snowpark Python and Streamlit in Snowflake to provide a single view of cost and workload behavior.

---

## Overview

Snowflake costs can increase because of:

- warehouses running while idle
- oversized warehouses
- inefficient queries
- repeated query execution
- poor partition pruning
- local or remote spilling
- low cache utilization
- failed queries
- unexpected changes in warehouse usage

This project collects and analyzes Snowflake telemetry to identify these patterns and generate recommendations with supporting evidence.

The main goal is not only to show where credits are being used, but also to explain why a potential optimization is being suggested and estimate the possible savings.

---

## What the Project Does

The system currently covers:

- Warehouse daily cost analysis
- Query execution analysis
- Query frequency analysis
- Idle compute detection
- Warehouse sizing analysis
- Query spill detection
- Partition pruning analysis
- Cache utilization analysis
- Failed query analysis
- Cost anomaly detection
- Configurable optimization rules
- Recommendation generation
- Estimated savings calculation
- Recommendation confidence scoring
- Recommendation priority scoring
- Before/after validation structure
- Snowpark-based processing
- Streamlit dashboard
- Role-based access control

The dashboard is designed around six main areas:

1. Overview
2. Warehouse Explorer
3. Query Analysis
4. Recommendations
5. Anomalies
6. Optimization Validation

---

## Architecture

```text
                         Snowflake Account
                                |
                                v
                  SNOWFLAKE.ACCOUNT_USAGE
                                |
                +---------------+---------------+
                |               |               |
                v               v               v
          QUERY_HISTORY   WAREHOUSE_METERING   LOAD_HISTORY
                |               |               |
                +---------------+---------------+
                                |
                                v
                           RAW Layer
                                |
                                v
                           CORE Layer
                                |
                                v
                        Analytics Layer
                                |
             +------------------+------------------+
             |                  |                  |
             v                  v                  v
        Cost Models       Query Analysis     Anomaly Detection
             |                  |                  |
             +------------------+------------------+
                                |
                                v
                       Optimization Rules
                                |
                                v
                     Recommendation Engine
                                |
                +---------------+---------------+
                |                               |
                v                               v
          Estimated Savings              Priority / Confidence
                |                               |
                +---------------+---------------+
                                |
                                v
                    Streamlit in Snowflake
                                |
                                v
                         FinOps Dashboard
