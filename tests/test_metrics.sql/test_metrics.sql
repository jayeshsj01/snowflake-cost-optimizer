-- ============================================================
-- TEST METRICS
-- Snowflake Cost Optimization Engine
-- ============================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE FINOPS_WH;
USE DATABASE SNOWFLAKE_FINOPS;

-- ------------------------------------------------------------
-- 1. Test idle percentage calculation
-- Expected:
-- IDLE_PERCENTAGE = IDLE_CREDITS / COMPUTE_CREDITS * 100
-- ------------------------------------------------------------

SELECT
    'METRIC_001_IDLE_PERCENTAGE' AS TEST_NAME,
    COUNT(*) AS CHECKED_ROWS,
    SUM(
        CASE
            WHEN COMPUTE_CREDITS = 0 AND IDLE_PERCENTAGE = 0 THEN 1
            WHEN COMPUTE_CREDITS > 0
                 AND ABS(
                     IDLE_PERCENTAGE
                     - (ESTIMATED_IDLE_CREDITS / COMPUTE_CREDITS * 100)
                 ) < 0.01
            THEN 1
            ELSE 0
        END
    ) AS PASSED_ROWS,
    CASE
        WHEN COUNT(*) = SUM(
            CASE
                WHEN COMPUTE_CREDITS = 0 AND IDLE_PERCENTAGE = 0 THEN 1
                WHEN COMPUTE_CREDITS > 0
                     AND ABS(
                         IDLE_PERCENTAGE
                         - (ESTIMATED_IDLE_CREDITS / COMPUTE_CREDITS * 100)
                     ) < 0.01
                THEN 1
                ELSE 0
            END
        )
        THEN 'PASS'
        ELSE 'FAIL'
    END AS RESULT
FROM SNOWFLAKE_FINOPS.ANALYTICS.DAILY_WAREHOUSE_COST;


-- ------------------------------------------------------------
-- 2. Test cost calculation
-- Total credits should equal compute + cloud services credits
-- ------------------------------------------------------------

SELECT
    'METRIC_002_TOTAL_CREDITS' AS TEST_NAME,
    COUNT(*) AS CHECKED_ROWS,
    SUM(
        CASE
            WHEN ABS(
                TOTAL_CREDITS
                - (COMPUTE_CREDITS + CLOUD_SERVICES_CREDITS)
            ) < 0.000001
            THEN 1
            ELSE 0
        END
    ) AS PASSED_ROWS,
    CASE
        WHEN COUNT(*) = SUM(
            CASE
                WHEN ABS(
                    TOTAL_CREDITS
                    - (COMPUTE_CREDITS + CLOUD_SERVICES_CREDITS)
                ) < 0.000001
                THEN 1
                ELSE 0
            END
        )
        THEN 'PASS'
        ELSE 'FAIL'
    END AS RESULT
FROM SNOWFLAKE_FINOPS.ANALYTICS.DAILY_WAREHOUSE_COST;


-- ------------------------------------------------------------
-- 3. Test idle credits cannot exceed compute credits
-- ------------------------------------------------------------

SELECT
    'METRIC_003_IDLE_CREDIT_BOUND' AS TEST_NAME,
    COUNT(*) AS CHECKED_ROWS,
    SUM(
        CASE
            WHEN ESTIMATED_IDLE_CREDITS >= 0
             AND ESTIMATED_IDLE_CREDITS <= COMPUTE_CREDITS
            THEN 1
            ELSE 0
        END
    ) AS PASSED_ROWS,
    CASE
        WHEN COUNT(*) = SUM(
            CASE
                WHEN ESTIMATED_IDLE_CREDITS >= 0
                 AND ESTIMATED_IDLE_CREDITS <= COMPUTE_CREDITS
                THEN 1
                ELSE 0
            END
        )
        THEN 'PASS'
        ELSE 'FAIL'
    END AS RESULT
FROM SNOWFLAKE_FINOPS.ANALYTICS.DAILY_WAREHOUSE_COST;


-- ------------------------------------------------------------
-- 4. Test partition scan percentage logic
-- ------------------------------------------------------------

WITH TEST_DATA AS (
    SELECT
        PARTITIONS_SCANNED,
        PARTITIONS_TOTAL,
        CASE
            WHEN PARTITIONS_TOTAL > 0
            THEN PARTITIONS_SCANNED * 100.0 / PARTITIONS_TOTAL
            ELSE 0
        END AS EXPECTED_SCAN_PERCENT
    FROM SNOWFLAKE_FINOPS.RAW.QUERY_HISTORY_RAW
    WHERE PARTITIONS_TOTAL IS NOT NULL
      AND PARTITIONS_SCANNED IS NOT NULL
)
SELECT
    'METRIC_004_PARTITION_SCAN_PERCENT' AS TEST_NAME,
    COUNT(*) AS CHECKED_ROWS,
    SUM(
        CASE
            WHEN EXPECTED_SCAN_PERCENT BETWEEN 0 AND 100
            THEN 1
            ELSE 0
        END
    ) AS PASSED_ROWS,
    CASE
        WHEN COUNT(*) = SUM(
            CASE
                WHEN EXPECTED_SCAN_PERCENT BETWEEN 0 AND 100
                THEN 1
                ELSE 0
            END
        )
        THEN 'PASS'
        ELSE 'FAIL'
    END AS RESULT
FROM TEST_DATA;


-- ------------------------------------------------------------
-- 5. Test anomaly score boundaries
-- ------------------------------------------------------------

SELECT
    'METRIC_005_ANOMALY_SCORE' AS TEST_NAME,
    COUNT(*) AS CHECKED_ROWS,
    SUM(
        CASE
            WHEN ANOMALY_FLAG = TRUE AND Z_SCORE >= 2 THEN 1
            WHEN ANOMALY_FLAG = FALSE THEN 1
            ELSE 0
        END
    ) AS PASSED_ROWS,
    CASE
        WHEN COUNT(*) = SUM(
            CASE
                WHEN ANOMALY_FLAG = TRUE AND Z_SCORE >= 2 THEN 1
                WHEN ANOMALY_FLAG = FALSE THEN 1
                ELSE 0
            END
        )
        THEN 'PASS'
        ELSE 'FAIL'
    END AS RESULT
FROM SNOWFLAKE_FINOPS.ANALYTICS.COST_ANOMALIES;


-- ------------------------------------------------------------
-- 6. Metrics sanity summary
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS DAILY_COST_ROWS,
    SUM(TOTAL_CREDITS) AS TOTAL_CREDITS,
    SUM(COMPUTE_CREDITS) AS TOTAL_COMPUTE_CREDITS,
    SUM(ESTIMATED_IDLE_CREDITS) AS TOTAL_ESTIMATED_IDLE_CREDITS
FROM SNOWFLAKE_FINOPS.ANALYTICS.DAILY_WAREHOUSE_COST;
