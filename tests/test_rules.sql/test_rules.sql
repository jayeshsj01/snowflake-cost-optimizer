-- ============================================================
-- TEST RULES
-- Snowflake Cost Optimization Engine
-- ============================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE FINOPS_WH;
USE DATABASE SNOWFLAKE_FINOPS;


-- ------------------------------------------------------------
-- 1. Rule configuration must exist
-- ------------------------------------------------------------

SELECT
    'RULE_001_RULE_CONFIGURATION' AS TEST_NAME,
    COUNT(*) AS RULE_COUNT,
    CASE
        WHEN COUNT(*) >= 8 THEN 'PASS'
        ELSE 'FAIL'
    END AS RESULT
FROM SNOWFLAKE_FINOPS.CONFIG.OPTIMIZATION_RULES;


-- ------------------------------------------------------------
-- 2. Required rule IDs must exist
-- ------------------------------------------------------------

WITH REQUIRED_RULES AS (
    SELECT COLUMN1 AS RULE_ID
    FROM VALUES
        ('R001'),
        ('R002'),
        ('R003'),
        ('R004'),
        ('R005'),
        ('R006'),
        ('R007'),
        ('R008')
),
FOUND_RULES AS (
    SELECT RULE_ID
    FROM SNOWFLAKE_FINOPS.CONFIG.OPTIMIZATION_RULES
)
SELECT
    'RULE_002_REQUIRED_RULE_IDS' AS TEST_NAME,
    COUNT(*) AS REQUIRED_RULES,
    COUNT(F.RULE_ID) AS FOUND_RULES,
    CASE
        WHEN COUNT(*) = COUNT(F.RULE_ID)
        THEN 'PASS'
        ELSE 'FAIL'
    END AS RESULT
FROM REQUIRED_RULES R
LEFT JOIN FOUND_RULES F
    ON R.RULE_ID = F.RULE_ID;


-- ------------------------------------------------------------
-- 3. Enabled rules must have valid thresholds
-- ------------------------------------------------------------

SELECT
    'RULE_003_VALID_THRESHOLDS' AS TEST_NAME,
    COUNT(*) AS CHECKED_ROWS,
    SUM(
        CASE
            WHEN ENABLED = TRUE
             AND THRESHOLD IS NOT NULL
             AND OPERATOR IS NOT NULL
            THEN 1
            WHEN ENABLED = FALSE
            THEN 1
            ELSE 0
        END
    ) AS PASSED_ROWS,
    CASE
        WHEN COUNT(*) = SUM(
            CASE
                WHEN ENABLED = TRUE
                 AND THRESHOLD IS NOT NULL
                 AND OPERATOR IS NOT NULL
                THEN 1
                WHEN ENABLED = FALSE
                THEN 1
                ELSE 0
            END
        )
        THEN 'PASS'
        ELSE 'FAIL'
    END AS RESULT
FROM SNOWFLAKE_FINOPS.CONFIG.OPTIMIZATION_RULES;


-- ------------------------------------------------------------
-- 4. Recommendation rules must map to configured rules
-- ------------------------------------------------------------

SELECT
    'RULE_004_RECOMMENDATION_RULE_MAPPING' AS TEST_NAME,
    COUNT(*) AS CHECKED_ROWS,
    COUNT(R.RULE_ID) AS MATCHED_ROWS,
    CASE
        WHEN COUNT(*) = COUNT(R.RULE_ID)
        THEN 'PASS'
        ELSE 'FAIL'
    END AS RESULT
FROM SNOWFLAKE_FINOPS.RECOMMENDATIONS.OPTIMIZATION_RECOMMENDATIONS_CLEAN C
LEFT JOIN SNOWFLAKE_FINOPS.CONFIG.OPTIMIZATION_RULES R
    ON C.RULE_ID = R.RULE_ID;


-- ------------------------------------------------------------
-- 5. Severity values must be controlled
-- ------------------------------------------------------------

SELECT
    'RULE_005_VALID_SEVERITY' AS TEST_NAME,
    COUNT(*) AS CHECKED_ROWS,
    SUM(
        CASE
            WHEN UPPER(SEVERITY) IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')
            THEN 1
            ELSE 0
        END
    ) AS PASSED_ROWS,
    CASE
        WHEN COUNT(*) = SUM(
            CASE
                WHEN UPPER(SEVERITY) IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')
                THEN 1
                ELSE 0
            END
        )
        THEN 'PASS'
        ELSE 'FAIL'
    END AS RESULT
FROM SNOWFLAKE_FINOPS.RECOMMENDATIONS.OPTIMIZATION_RECOMMENDATIONS_CLEAN;


-- ------------------------------------------------------------
-- 6. Rule engine summary
-- ------------------------------------------------------------

SELECT
    RULE_ID,
    RULE_NAME,
    ENABLED,
    OPERATOR,
    THRESHOLD,
    SEVERITY
FROM SNOWFLAKE_FINOPS.CONFIG.OPTIMIZATION_RULES
ORDER BY RULE_ID;
