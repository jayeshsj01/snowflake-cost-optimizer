-- ============================================================
-- TEST REGRESSION
-- Snowflake Cost Optimization Engine
-- ============================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE FINOPS_WH;
USE DATABASE SNOWFLAKE_FINOPS;


-- ------------------------------------------------------------
-- 1. Core objects exist
-- ------------------------------------------------------------

SELECT
    'REG_001_CORE_OBJECTS' AS TEST_NAME,
    COUNT(*) AS FOUND_OBJECTS,
    CASE
        WHEN COUNT(*) = 3 THEN 'PASS'
        ELSE 'FAIL'
    END AS RESULT
FROM SNOWFLAKE.INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'CORE'
  AND TABLE_NAME IN (
      'WAREHOUSE_METERING_INCREMENTAL',
      'QUERY_HISTORY',
      'WAREHOUSE_METERING'
  );


-- ------------------------------------------------------------
-- 2. Analytics objects exist
-- ------------------------------------------------------------

SELECT
    'REG_002_ANALYTICS_OBJECTS' AS TEST_NAME,
    COUNT(*) AS FOUND_OBJECTS,
    CASE
        WHEN COUNT(*) >= 3 THEN 'PASS'
        ELSE 'FAIL'
    END AS RESULT
FROM SNOWFLAKE.INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'ANALYTICS'
  AND TABLE_NAME IN (
      'DAILY_WAREHOUSE_COST',
      'QUERY_COMPUTE_ATTRIBUTION',
      'COST_ANOMALIES',
      'SNOWPARK_SAVINGS_MODEL'
  );


-- ------------------------------------------------------------
-- 3. Recommendation objects exist
-- ------------------------------------------------------------

SELECT
    'REG_003_RECOMMENDATION_OBJECTS' AS TEST_NAME,
    COUNT(*) AS FOUND_OBJECTS,
    CASE
        WHEN COUNT(*) >= 3 THEN 'PASS'
        ELSE 'FAIL'
    END AS RESULT
FROM SNOWFLAKE.INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'RECOMMENDATIONS'
  AND TABLE_NAME IN (
      'OPTIMIZATION_RECOMMENDATIONS_CLEAN',
      'RECOMMENDATION_FACT',
      'SNOWPARK_RECOMMENDATIONS'
  );


-- ------------------------------------------------------------
-- 4. Stream exists
-- ------------------------------------------------------------

SHOW STREAMS IN SCHEMA SNOWFLAKE_FINOPS.CORE;


-- ------------------------------------------------------------
-- 5. Task exists
-- ------------------------------------------------------------

SHOW TASKS IN SCHEMA SNOWFLAKE_FINOPS.CORE;


-- ------------------------------------------------------------
-- 6. Dynamic Table exists
-- ------------------------------------------------------------

SHOW DYNAMIC TABLES IN SCHEMA SNOWFLAKE_FINOPS.ANALYTICS;


-- ------------------------------------------------------------
-- 7. Snowpark output tables contain data
-- ------------------------------------------------------------

SELECT
    'REG_004_SNOWPARK_OUTPUTS' AS TEST_NAME,
    (SELECT COUNT(*)
     FROM SNOWFLAKE_FINOPS.ANALYTICS.COST_ANOMALIES)
    AS ANOMALY_ROWS,
    (SELECT COUNT(*)
     FROM SNOWFLAKE_FINOPS.RECOMMENDATIONS.SNOWPARK_RECOMMENDATIONS)
    AS SNOWPARK_RECOMMENDATION_ROWS,
    (SELECT COUNT(*)
     FROM SNOWFLAKE_FINOPS.ANALYTICS.SNOWPARK_SAVINGS_MODEL)
    AS SAVINGS_MODEL_ROWS,
    CASE
        WHEN
            (SELECT COUNT(*)
             FROM SNOWFLAKE_FINOPS.ANALYTICS.COST_ANOMALIES) >= 0
        AND
            (SELECT COUNT(*)
             FROM SNOWFLAKE_FINOPS.RECOMMENDATIONS.SNOWPARK_RECOMMENDATIONS) > 0
        AND
            (SELECT COUNT(*)
             FROM SNOWFLAKE_FINOPS.ANALYTICS.SNOWPARK_SAVINGS_MODEL) > 0
        THEN 'PASS'
        ELSE 'FAIL'
    END AS RESULT;


-- ------------------------------------------------------------
-- 8. RBAC roles exist
-- ------------------------------------------------------------

SHOW ROLES;


-- ------------------------------------------------------------
-- 9. Secure recommendation view exists
-- ------------------------------------------------------------

SELECT
    'REG_005_SECURE_RECOMMENDATIONS' AS TEST_NAME,
    COUNT(*) AS ROW_COUNT,
    'PASS' AS RESULT
FROM SNOWFLAKE_FINOPS.RECOMMENDATIONS.SECURE_RECOMMENDATIONS
LIMIT 1;


-- ------------------------------------------------------------
-- 10. Final project health snapshot
-- ------------------------------------------------------------

SELECT
    (SELECT COUNT(*)
     FROM SNOWFLAKE_FINOPS.RAW.QUERY_HISTORY_RAW)
        AS QUERY_TELEMETRY_ROWS,

    (SELECT COUNT(*)
     FROM SNOWFLAKE_FINOPS.RAW.WAREHOUSE_METERING_RAW)
        AS WAREHOUSE_METERING_ROWS,

    (SELECT COUNT(*)
     FROM SNOWFLAKE_FINOPS.RECOMMENDATIONS.RECOMMENDATION_FACT)
        AS RECOMMENDATION_ROWS,

    (SELECT COUNT(*)
     FROM SNOWFLAKE_FINOPS.ANALYTICS.COST_ANOMALIES)
        AS ANOMALY_ROWS,

    (SELECT COUNT(*)
     FROM SNOWFLAKE_FINOPS.ANALYTICS.SNOWPARK_SAVINGS_MODEL)
        AS SAVINGS_MODEL_ROWS;
