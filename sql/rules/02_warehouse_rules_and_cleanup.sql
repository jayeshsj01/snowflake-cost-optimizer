-- 10. WAREHOUSE WORKLOAD ANALYSIS
-- =========================================================

USE SCHEMA ANALYTICS;

CREATE OR REPLACE TABLE
SNOWFLAKE_FINOPS.ANALYTICS.WAREHOUSE_WORKLOAD
AS

SELECT
    WAREHOUSE_NAME,

    COUNT(*) AS QUERY_COUNT,

    COUNT(
        DISTINCT CAST(START_TIME AS DATE)
    ) AS ACTIVE_DAYS,

    ROUND(
        COUNT(*) /
        NULLIF(
            COUNT(DISTINCT CAST(START_TIME AS DATE)),
            0
        ),
        2
    ) AS AVG_QUERIES_PER_DAY,

    ROUND(
        AVG(TOTAL_ELAPSED_TIME) / 1000,
        2
    ) AS AVG_QUERY_SECONDS,

    ROUND(
        SUM(BYTES_SCANNED) / POWER(1024,3),
        2
    ) AS TOTAL_GB_SCANNED

FROM SNOWFLAKE_FINOPS.CORE.QUERY_HISTORY

WHERE
    WAREHOUSE_NAME IS NOT NULL

GROUP BY
    WAREHOUSE_NAME;


-- =========================================================
-- 11. WAREHOUSE CONFIGURATION
-- FIXED VERSION
-- Uses SHOW WAREHOUSES instead of nonexistent
-- ACCOUNT_USAGE.WAREHOUSES
-- =========================================================

SHOW WAREHOUSES;


CREATE OR REPLACE TABLE
SNOWFLAKE_FINOPS.ANALYTICS.WAREHOUSE_SIZE_INFO
AS

SELECT
    "name" AS WAREHOUSE_NAME,
    "size" AS WAREHOUSE_SIZE,
    "auto_suspend" AS AUTO_SUSPEND,
    "auto_resume" AS AUTO_RESUME

FROM TABLE(
    RESULT_SCAN(LAST_QUERY_ID())
);


-- =========================================================
-- 12. OVERSIZED WAREHOUSE RECOMMENDATIONS
-- =========================================================

INSERT INTO
SNOWFLAKE_FINOPS.RECOMMENDATIONS.OPTIMIZATION_RECOMMENDATIONS

SELECT
    'REC_SIZE_' || W.WAREHOUSE_NAME,

    'R008',
    'OVERSIZED_WAREHOUSE',

    'WAREHOUSE',

    W.WAREHOUSE_NAME,

    'Review warehouse sizing and consider a smaller warehouse if performance requirements allow.',

    'Warehouse size: '
        || W.WAREHOUSE_SIZE
        || '; Average queries/day: '
        || COALESCE(
            TO_VARCHAR(L.AVG_QUERIES_PER_DAY),
            '0'
        )
        || '; Average query time: '
        || COALESCE(
            TO_VARCHAR(L.AVG_QUERY_SECONDS),
            '0'
        )
        || ' seconds',

    0,

    0.70,

    70,

    'HIGH',
    'MEDIUM',

    CURRENT_TIMESTAMP()

FROM
    SNOWFLAKE_FINOPS.ANALYTICS.WAREHOUSE_SIZE_INFO W

LEFT JOIN
    SNOWFLAKE_FINOPS.ANALYTICS.WAREHOUSE_WORKLOAD L

ON
    W.WAREHOUSE_NAME = L.WAREHOUSE_NAME

WHERE
    W.WAREHOUSE_SIZE IN
    (
        'SMALL',
        'MEDIUM',
        'LARGE',
        'X-LARGE',
        '2X-LARGE',
        '3X-LARGE',
        '4X-LARGE',
        '5X-LARGE',
        '6X-LARGE'
    )

    AND COALESCE(
        L.AVG_QUERIES_PER_DAY,
        0
    ) < 20;


-- =========================================================
-- 13. REMOVE DUPLICATE RECOMMENDATIONS
-- =========================================================

CREATE OR REPLACE TABLE
SNOWFLAKE_FINOPS.RECOMMENDATIONS.OPTIMIZATION_RECOMMENDATIONS_CLEAN
AS

SELECT
    RECOMMENDATION_ID,
    RULE_ID,
    RULE_NAME,

    OBJECT_TYPE,
    OBJECT_NAME,

    RECOMMENDATION,
    EVIDENCE,

    ESTIMATED_SAVINGS_USD,
    CONFIDENCE_SCORE,
    PRIORITY_SCORE,

    SEVERITY,
    RISK_LEVEL,

    CREATED_AT

FROM
(
    SELECT
        R.*,

        ROW_NUMBER() OVER
        (
            PARTITION BY
                RULE_ID,
                OBJECT_TYPE,
                OBJECT_NAME

            ORDER BY
                CREATED_AT DESC
        ) AS RN

    FROM
        SNOWFLAKE_FINOPS.RECOMMENDATIONS.OPTIMIZATION_RECOMMENDATIONS R
)

WHERE
    RN = 1;


-- =========================================================
-- 14. FINAL RECOMMENDATION VIEW
-- =========================================================

CREATE OR REPLACE VIEW
SNOWFLAKE_FINOPS.RECOMMENDATIONS.RECOMMENDATION_SUMMARY
AS

SELECT
    RECOMMENDATION_ID,
    RULE_ID,
    RULE_NAME,

    OBJECT_TYPE,
    OBJECT_NAME,

    RECOMMENDATION,
    EVIDENCE,

    ESTIMATED_SAVINGS_USD,
    CONFIDENCE_SCORE,
    PRIORITY_SCORE,

    SEVERITY,
    RISK_LEVEL,

    CREATED_AT

FROM
    SNOWFLAKE_FINOPS.RECOMMENDATIONS.OPTIMIZATION_RECOMMENDATIONS_CLEAN;


-- =========================================================
-- 15. FINAL VALIDATION - RULE COUNTS
-- =========================================================

SELECT
    RULE_ID,
    RULE_NAME,
    COUNT(*) AS RECOMMENDATION_COUNT

FROM
    SNOWFLAKE_FINOPS.RECOMMENDATIONS.OPTIMIZATION_RECOMMENDATIONS_CLEAN

GROUP BY
    RULE_ID,
    RULE_NAME

ORDER BY
    RECOMMENDATION_COUNT DESC;


-- =========================================================
-- 16. FINAL VALIDATION - RECOMMENDATIONS
-- =========================================================

SELECT
    RECOMMENDATION_ID,
    RULE_ID,
    RULE_NAME,
    OBJECT_TYPE,
    OBJECT_NAME,
    RECOMMENDATION,
    EVIDENCE,
    ESTIMATED_SAVINGS_USD,
    CONFIDENCE_SCORE,
    PRIORITY_SCORE,
    SEVERITY,
    RISK_LEVEL,
    CREATED_AT

FROM
    SNOWFLAKE_FINOPS.RECOMMENDATIONS.RECOMMENDATION_SUMMARY

ORDER BY
    PRIORITY_SCORE DESC,
    CONFIDENCE_SCORE DESC;




