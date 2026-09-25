-- PHASE 3 - ANALYTICS + COST MODEL
-- =========================================================

USE ROLE ACCOUNTADMIN;

USE WAREHOUSE FINOPS_WH;

USE DATABASE SNOWFLAKE_FINOPS;


-- =========================================================
-- 1. CONFIGURATION
-- =========================================================

USE SCHEMA CONFIG;

CREATE OR REPLACE TABLE SNOWFLAKE_FINOPS.CONFIG.COST_PARAMETERS (
    PARAMETER_NAME VARCHAR,
    PARAMETER_VALUE FLOAT,
    DESCRIPTION VARCHAR
);

INSERT INTO SNOWFLAKE_FINOPS.CONFIG.COST_PARAMETERS
    (PARAMETER_NAME, PARAMETER_VALUE, DESCRIPTION)
VALUES
    (
        'CREDIT_PRICE_USD',
        3.00,
        'Configurable estimated USD price per Snowflake credit'
    ),
    (
        'IDLE_THRESHOLD_MINUTES',
        10,
        'Minutes used later for idle compute detection'
    ),
    (
        'CACHE_EFFICIENCY_THRESHOLD',
        50,
        'Percentage below which cache efficiency may need review'
    ),
    (
        'PARTITION_PRUNING_THRESHOLD',
        50,
        'Percentage of partitions scanned above which pruning may need review'
    );


-- =========================================================
-- 2. DAILY WAREHOUSE COST
-- =========================================================

USE SCHEMA ANALYTICS;

CREATE OR REPLACE TABLE SNOWFLAKE_FINOPS.ANALYTICS.DAILY_WAREHOUSE_COST AS

SELECT
    CAST(START_TIME AS DATE) AS USAGE_DATE,

    WAREHOUSE_NAME,

    ROUND(SUM(CREDITS_USED), 6) AS TOTAL_CREDITS,

    ROUND(SUM(CREDITS_USED_COMPUTE), 6)
        AS COMPUTE_CREDITS,

    ROUND(SUM(CREDITS_USED_CLOUD_SERVICES), 6)
        AS CLOUD_SERVICES_CREDITS,

    ROUND(
        SUM(CREDITS_USED)
        *
        (
            SELECT PARAMETER_VALUE
            FROM SNOWFLAKE_FINOPS.CONFIG.COST_PARAMETERS
            WHERE PARAMETER_NAME = 'CREDIT_PRICE_USD'
        ),
        2
    ) AS ESTIMATED_COST_USD

FROM SNOWFLAKE_FINOPS.CORE.WAREHOUSE_METERING

GROUP BY
    CAST(START_TIME AS DATE),
    WAREHOUSE_NAME;


-- =========================================================
-- 3. QUERY COST / RESOURCE ANALYSIS
-- =========================================================

CREATE OR REPLACE TABLE SNOWFLAKE_FINOPS.ANALYTICS.QUERY_COST_ANALYSIS AS

SELECT
    QUERY_ID,
    QUERY_TEXT,

    DATABASE_NAME,
    SCHEMA_NAME,
    WAREHOUSE_NAME,
    USER_NAME,

    START_TIME,
    END_TIME,

    TOTAL_ELAPSED_TIME,
    EXECUTION_TIME,

    BYTES_SCANNED,
    ROWS_PRODUCED,

    PARTITIONS_SCANNED,
    PARTITIONS_TOTAL,

    CASE
        WHEN PARTITIONS_TOTAL > 0
        THEN ROUND(
            (PARTITIONS_SCANNED / PARTITIONS_TOTAL) * 100,
            2
        )
        ELSE NULL
    END AS PARTITION_SCAN_PERCENT,

    PERCENTAGE_SCANNED_FROM_CACHE
        AS CACHE_PERCENT,

    BYTES_SPILLED_TO_LOCAL_STORAGE,
    BYTES_SPILLED_TO_REMOTE_STORAGE,

    QUEUED_PROVISIONING_TIME,
    QUEUED_REPAIR_TIME,
    QUEUED_OVERLOAD_TIME,

    EXECUTION_STATUS,
    ERROR_CODE,
    ERROR_MESSAGE

FROM SNOWFLAKE_FINOPS.CORE.QUERY_HISTORY;


-- =========================================================
