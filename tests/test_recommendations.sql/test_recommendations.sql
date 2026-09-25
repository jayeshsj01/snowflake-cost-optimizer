-- ============================================================
-- TEST RECOMMENDATIONS
-- Snowflake Cost Optimization Engine
-- ============================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE FINOPS_WH;
USE DATABASE SNOWFLAKE_FINOPS;


-- ------------------------------------------------------------
-- 1. Recommendation IDs must be unique
-- ------------------------------------------------------------

SELECT
    'REC_001_UNIQUE_IDS' AS TEST_NAME,
    COUNT(*) AS TOTAL_ROWS,
    COUNT(DISTINCT RECOMMENDATION_ID) AS UNIQUE_IDS,
    CASE
        WHEN COUNT(*) = COUNT(DISTINCT RECOMMENDATION_ID)
        THEN 'PASS'
        ELSE 'FAIL'
    END AS RESULT
FROM SNOWFLAKE_FINOPS.RECOMMENDATIONS.RECOMMENDATION_FACT;


-- ------------------------------------------------------------
-- 2. Confidence score must be between 0 and 1
-- ------------------------------------------------------------

SELECT
    'REC_002_CONFIDENCE_RANGE' AS TEST_NAME,
    COUNT(*) AS CHECKED_ROWS,
    SUM(
        CASE
            WHEN CONFIDENCE_SCORE BETWEEN 0 AND 1
            THEN 1
            ELSE 0
        END
    ) AS PASSED_ROWS,
    CASE
        WHEN COUNT(*) = SUM(
            CASE
                WHEN CONFIDENCE_SCORE BETWEEN 0 AND 1
                THEN 1
                ELSE 0
            END
        )
        THEN 'PASS'
        ELSE 'FAIL'
    END AS RESULT
FROM SNOWFLAKE_FINOPS.RECOMMENDATIONS.RECOMMENDATION_FACT;


-- ------------------------------------------------------------
-- 3. Estimated savings must not be negative
-- ------------------------------------------------------------

SELECT
    'REC_003_NON_NEGATIVE_SAVINGS' AS TEST_NAME,
    COUNT(*) AS CHECKED_ROWS,
    SUM(
        CASE
            WHEN ESTIMATED_MONTHLY_CREDITS_SAVED >= 0
             AND ESTIMATED_MONTHLY_USD_SAVED >= 0
            THEN 1
            ELSE 0
        END
    ) AS PASSED_ROWS,
    CASE
        WHEN COUNT(*) = SUM(
            CASE
                WHEN ESTIMATED_MONTHLY_CREDITS_SAVED >= 0
                 AND ESTIMATED_MONTHLY_USD_SAVED >= 0
                THEN 1
                ELSE 0
            END
        )
        THEN 'PASS'
        ELSE 'FAIL'
    END AS RESULT
FROM SNOWFLAKE_FINOPS.RECOMMENDATIONS.RECOMMENDATION_FACT;


-- ------------------------------------------------------------
-- 4. Priority score must be between 0 and 100
-- ------------------------------------------------------------

SELECT
    'REC_004_PRIORITY_RANGE' AS TEST_NAME,
    COUNT(*) AS CHECKED_ROWS,
    SUM(
        CASE
            WHEN PRIORITY_SCORE BETWEEN 0 AND 100
            THEN 1
            ELSE 0
        END
    ) AS PASSED_ROWS,
    CASE
        WHEN COUNT(*) = SUM(
            CASE
                WHEN PRIORITY_SCORE BETWEEN 0 AND 100
                THEN 1
                ELSE 0
            END
        )
        THEN 'PASS'
        ELSE 'FAIL'
    END AS RESULT
FROM SNOWFLAKE_FINOPS.RECOMMENDATIONS.RECOMMENDATION_FACT;


-- ------------------------------------------------------------
-- 5. Recommendation status must be controlled
-- ------------------------------------------------------------

SELECT
    'REC_005_VALID_STATUS' AS TEST_NAME,
    COUNT(*) AS CHECKED_ROWS,
    SUM(
        CASE
            WHEN UPPER(STATUS) IN
                 ('OPEN', 'REVIEWED', 'APPROVED', 'IMPLEMENTED', 'VERIFIED')
            THEN 1
            ELSE 0
        END
    ) AS PASSED_ROWS,
    CASE
        WHEN COUNT(*) = SUM(
            CASE
                WHEN UPPER(STATUS) IN
                     ('OPEN', 'REVIEWED', 'APPROVED', 'IMPLEMENTED', 'VERIFIED')
                THEN 1
                ELSE 0
            END
        )
        THEN 'PASS'
        ELSE 'FAIL'
    END AS RESULT
FROM SNOWFLAKE_FINOPS.RECOMMENDATIONS.RECOMMENDATION_FACT;


-- ------------------------------------------------------------
-- 6. Recommendation evidence must exist
-- ------------------------------------------------------------

SELECT
    'REC_006_EVIDENCE_PRESENT' AS TEST_NAME,
    COUNT(*) AS CHECKED_ROWS,
    SUM(
        CASE
            WHEN EVIDENCE IS NOT NULL
             AND LENGTH(TRIM(EVIDENCE)) > 0
            THEN 1
            ELSE 0
        END
    ) AS PASSED_ROWS,
    CASE
        WHEN COUNT(*) = SUM(
            CASE
                WHEN EVIDENCE IS NOT NULL
                 AND LENGTH(TRIM(EVIDENCE)) > 0
                THEN 1
                ELSE 0
            END
        )
        THEN 'PASS'
        ELSE 'FAIL'
    END AS RESULT
FROM SNOWFLAKE_FINOPS.RECOMMENDATIONS.RECOMMENDATION_FACT;


-- ------------------------------------------------------------
-- 7. Recommendation engine summary
-- ------------------------------------------------------------

SELECT
    RECOMMENDATION_TYPE,
    COUNT(*) AS RECOMMENDATION_COUNT,
    ROUND(SUM(ESTIMATED_MONTHLY_CREDITS_SAVED), 4)
        AS ESTIMATED_MONTHLY_CREDITS_SAVED,
    ROUND(SUM(ESTIMATED_MONTHLY_USD_SAVED), 2)
        AS ESTIMATED_MONTHLY_USD_SAVED,
    ROUND(AVG(CONFIDENCE_SCORE) * 100, 2)
        AS AVG_CONFIDENCE_PERCENT,
    ROUND(AVG(PRIORITY_SCORE), 2)
        AS AVG_PRIORITY_SCORE
FROM SNOWFLAKE_FINOPS.RECOMMENDATIONS.RECOMMENDATION_FACT
GROUP BY RECOMMENDATION_TYPE
ORDER BY ESTIMATED_MONTHLY_USD_SAVED DESC;
