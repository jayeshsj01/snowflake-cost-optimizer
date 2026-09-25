-- PHASE 4 - OPTIMIZATION RULES + RECOMMENDATIONS
-- =========================================================

USE ROLE ACCOUNTADMIN;

USE WAREHOUSE FINOPS_WH;

USE DATABASE SNOWFLAKE_FINOPS;


-- =========================================================
-- 1. CONFIGURABLE OPTIMIZATION RULES
-- =========================================================

USE SCHEMA CONFIG;

CREATE OR REPLACE TABLE SNOWFLAKE_FINOPS.CONFIG.OPTIMIZATION_RULES
(
    RULE_ID VARCHAR,
    RULE_NAME VARCHAR,
    DESCRIPTION VARCHAR,
    ENABLED BOOLEAN,
    SEVERITY VARCHAR,
    THRESHOLD_VALUE FLOAT,
    THRESHOLD_UNIT VARCHAR
);

INSERT INTO SNOWFLAKE_FINOPS.CONFIG.OPTIMIZATION_RULES
VALUES
(
    'R001',
    'EXPENSIVE_QUERY',
    'Detect queries with high execution time or large data scans',
    TRUE,
    'HIGH',
    10,
    'SECONDS'
),
(
    'R002',
    'POOR_PARTITION_PRUNING',
    'Detect queries scanning a large percentage of available partitions',
    TRUE,
    'MEDIUM',
    50,
    'PERCENT'
),
(
    'R003',
    'LOW_CACHE_USAGE',
    'Detect queries with low cache utilization',
    TRUE,
    'LOW',
    50,
    'PERCENT'
),
(
    'R004',
    'QUERY_SPILL',
    'Detect queries spilling data to local or remote storage',
    TRUE,
    'HIGH',
    0,
    'BYTES'
),
(
    'R005',
    'FAILED_QUERY',
    'Detect failed queries that may create unnecessary compute usage',
    TRUE,
    'MEDIUM',
    1,
    'COUNT'
),
(
    'R006',
    'HIGH_QUERY_FREQUENCY',
    'Detect repeatedly executed query patterns',
    TRUE,
    'MEDIUM',
    20,
    'EXECUTIONS'
),
(
    'R007',
    'IDLE_WAREHOUSE',
    'Detect warehouses with metering activity but no recorded query activity',
    TRUE,
    'HIGH',
    1,
    'QUERY_COUNT'
),
(
    'R008',
    'OVERSIZED_WAREHOUSE',
    'Detect larger warehouses with relatively low workload',
    TRUE,
    'HIGH',
    20,
    'QUERIES_PER_DAY'
);


-- =========================================================
-- 2. RECOMMENDATION TABLE
-- =========================================================

USE SCHEMA RECOMMENDATIONS;

CREATE OR REPLACE TABLE
SNOWFLAKE_FINOPS.RECOMMENDATIONS.OPTIMIZATION_RECOMMENDATIONS
(
    RECOMMENDATION_ID VARCHAR,
    RULE_ID VARCHAR,
    RULE_NAME VARCHAR,

    OBJECT_TYPE VARCHAR,
    OBJECT_NAME VARCHAR,

    RECOMMENDATION VARCHAR,
    EVIDENCE VARCHAR,

    ESTIMATED_SAVINGS_USD FLOAT,
    CONFIDENCE_SCORE FLOAT,
    PRIORITY_SCORE FLOAT,

    SEVERITY VARCHAR,
    RISK_LEVEL VARCHAR,

    CREATED_AT TIMESTAMP
);


-- =========================================================
-- 3. EXPENSIVE QUERY RECOMMENDATIONS
-- =========================================================

INSERT INTO
SNOWFLAKE_FINOPS.RECOMMENDATIONS.OPTIMIZATION_RECOMMENDATIONS

SELECT
    'REC_' || QUERY_ID,
    'R001',
    'EXPENSIVE_QUERY',

    'QUERY',
    QUERY_ID,

    'Review and optimize this expensive query.',

    'Elapsed time: '
        || ROUND(TOTAL_ELAPSED_TIME / 1000, 2)
        || ' seconds; Bytes scanned: '
        || ROUND(BYTES_SCANNED / POWER(1024,3), 2)
        || ' GB',

    0,

    CASE
        WHEN TOTAL_ELAPSED_TIME >= 60000 THEN 0.95
        WHEN TOTAL_ELAPSED_TIME >= 30000 THEN 0.85
        ELSE 0.70
    END,

    CASE
        WHEN TOTAL_ELAPSED_TIME >= 60000 THEN 90
        WHEN TOTAL_ELAPSED_TIME >= 30000 THEN 75
        ELSE 60
    END,

    'HIGH',
    'MEDIUM',

    CURRENT_TIMESTAMP()

FROM SNOWFLAKE_FINOPS.CORE.QUERY_HISTORY

WHERE
    TOTAL_ELAPSED_TIME >= 10000
    OR BYTES_SCANNED >= POWER(1024,3);


-- =========================================================
-- 4. POOR PARTITION PRUNING
-- =========================================================

INSERT INTO
SNOWFLAKE_FINOPS.RECOMMENDATIONS.OPTIMIZATION_RECOMMENDATIONS

SELECT
    'REC_PRUNE_' || QUERY_ID,
    'R002',
    'POOR_PARTITION_PRUNING',

    'QUERY',
    QUERY_ID,

    'Improve filtering and partition pruning for this query.',

    'Partitions scanned: '
        || PARTITIONS_SCANNED
        || ' of '
        || PARTITIONS_TOTAL
        || ' ('
        || ROUND(
            (PARTITIONS_SCANNED / NULLIF(PARTITIONS_TOTAL,0)) * 100,
            2
        )
        || '%)',

    0,

    0.85,

    70,

    'MEDIUM',
    'LOW',

    CURRENT_TIMESTAMP()

FROM SNOWFLAKE_FINOPS.CORE.QUERY_HISTORY

WHERE
    PARTITIONS_TOTAL > 0
    AND
    (PARTITIONS_SCANNED / NULLIF(PARTITIONS_TOTAL,0)) * 100 >= 50;


-- =========================================================
-- 5. LOW CACHE USAGE
-- =========================================================

INSERT INTO
SNOWFLAKE_FINOPS.RECOMMENDATIONS.OPTIMIZATION_RECOMMENDATIONS

SELECT
    'REC_CACHE_' || QUERY_ID,
    'R003',
    'LOW_CACHE_USAGE',

    'QUERY',
    QUERY_ID,

    'Review repeated query patterns and cache effectiveness.',

    'Cache usage: '
        || ROUND(
            PERCENTAGE_SCANNED_FROM_CACHE,
            2
        )
        || '%',

    0,

    0.70,

    50,

    'LOW',
    'LOW',

    CURRENT_TIMESTAMP()

FROM SNOWFLAKE_FINOPS.CORE.QUERY_HISTORY

WHERE
    PERCENTAGE_SCANNED_FROM_CACHE IS NOT NULL
    AND PERCENTAGE_SCANNED_FROM_CACHE < 50;


-- =========================================================
-- 6. QUERY SPILL
-- =========================================================

INSERT INTO
SNOWFLAKE_FINOPS.RECOMMENDATIONS.OPTIMIZATION_RECOMMENDATIONS

SELECT
    'REC_SPILL_' || QUERY_ID,
    'R004',
    'QUERY_SPILL',

    'QUERY',
    QUERY_ID,

    'Review query memory usage and consider query optimization or warehouse sizing.',

    'Local spill: '
        || ROUND(
            BYTES_SPILLED_TO_LOCAL_STORAGE / POWER(1024,3),
            2
        )
        || ' GB; Remote spill: '
        || ROUND(
            BYTES_SPILLED_TO_REMOTE_STORAGE / POWER(1024,3),
            2
        )
        || ' GB',

    0,

    0.90,

    85,

    'HIGH',
    'MEDIUM',

    CURRENT_TIMESTAMP()

FROM SNOWFLAKE_FINOPS.CORE.QUERY_HISTORY

WHERE
    BYTES_SPILLED_TO_LOCAL_STORAGE > 0
    OR BYTES_SPILLED_TO_REMOTE_STORAGE > 0;


-- =========================================================
-- 7. FAILED QUERY
-- =========================================================

INSERT INTO
SNOWFLAKE_FINOPS.RECOMMENDATIONS.OPTIMIZATION_RECOMMENDATIONS

SELECT
    'REC_FAIL_' || QUERY_ID,
    'R005',
    'FAILED_QUERY',

    'QUERY',
    QUERY_ID,

    'Investigate failed queries to avoid repeated compute consumption.',

    'Error code: '
        || COALESCE(ERROR_CODE, 'UNKNOWN')
        || '; Error: '
        || COALESCE(ERROR_MESSAGE, 'Unknown error'),

    0,

    0.90,

    65,

    'MEDIUM',
    'LOW',

    CURRENT_TIMESTAMP()

FROM SNOWFLAKE_FINOPS.CORE.QUERY_HISTORY

WHERE
    EXECUTION_STATUS <> 'SUCCESS';


-- =========================================================
-- 8. HIGH QUERY FREQUENCY
-- =========================================================

INSERT INTO
SNOWFLAKE_FINOPS.RECOMMENDATIONS.OPTIMIZATION_RECOMMENDATIONS

SELECT
    'REC_FREQ_' ||
    MD5(
        COALESCE(WAREHOUSE_NAME,'')
        || COALESCE(DATABASE_NAME,'')
        || COALESCE(SCHEMA_NAME,'')
        || COALESCE(USER_NAME,'')
        || COALESCE(QUERY_TYPE,'')
    ),

    'R006',
    'HIGH_QUERY_FREQUENCY',

    'QUERY_PATTERN',

    COALESCE(WAREHOUSE_NAME,'UNKNOWN'),

    'Review frequently executed query patterns for caching, scheduling, or consolidation opportunities.',

    'Execution count: '
        || EXECUTION_COUNT
        || '; Average execution time: '
        || AVG_EXECUTION_SECONDS
        || ' seconds; Total scanned: '
        || TOTAL_GB_SCANNED
        || ' GB',

    0,

    0.75,

    60,

    'MEDIUM',
    'LOW',

    CURRENT_TIMESTAMP()

FROM SNOWFLAKE_FINOPS.ANALYTICS.QUERY_FREQUENCY

WHERE
    EXECUTION_COUNT >= 20;


-- =========================================================
-- 9. IDLE WAREHOUSE
-- =========================================================

INSERT INTO
SNOWFLAKE_FINOPS.RECOMMENDATIONS.OPTIMIZATION_RECOMMENDATIONS

SELECT
    'REC_IDLE_' ||
    TO_VARCHAR(MIN(USAGE_DATE)) ||
    '_' ||
    WAREHOUSE_NAME,

    'R007',
    'IDLE_WAREHOUSE',

    'WAREHOUSE',

    WAREHOUSE_NAME,

    'Review warehouse auto-suspend settings or suspend the warehouse when not required.',

    'Warehouse consumed '
        || ROUND(SUM(TOTAL_CREDITS), 4)
        || ' credits but had no recorded query activity during the usage period.',

    ROUND(SUM(ESTIMATED_COST_USD), 2),

    0.90,

    90,

    'HIGH',
    'LOW',

    CURRENT_TIMESTAMP()

FROM SNOWFLAKE_FINOPS.ANALYTICS.DAILY_WAREHOUSE_COST C

WHERE NOT EXISTS
(
    SELECT 1

    FROM SNOWFLAKE_FINOPS.CORE.QUERY_HISTORY Q

    WHERE
        Q.WAREHOUSE_NAME = C.WAREHOUSE_NAME
        AND CAST(Q.START_TIME AS DATE) = C.USAGE_DATE
)

GROUP BY
    WAREHOUSE_NAME;


-- =========================================================
