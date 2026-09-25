-- PHASE 5 - RECOMMENDATION ENGINE + SAVINGS MODEL
-- =========================================================

USE ROLE ACCOUNTADMIN;

USE WAREHOUSE FINOPS_WH;

USE DATABASE SNOWFLAKE_FINOPS;


-- =========================================================
-- 1. CREDIT PRICING CONFIGURATION
-- =========================================================

CREATE OR REPLACE TABLE
SNOWFLAKE_FINOPS.CONFIG.CREDIT_PRICING
(
    PRICING_ID VARCHAR,
    CREDIT_PRICE_USD FLOAT,
    EFFECTIVE_FROM DATE,
    EFFECTIVE_TO DATE,
    IS_ACTIVE BOOLEAN,
    DESCRIPTION VARCHAR
);

INSERT INTO
SNOWFLAKE_FINOPS.CONFIG.CREDIT_PRICING
VALUES
(
    'DEFAULT_ESTIMATE',
    3.00,
    CURRENT_DATE(),
    NULL,
    TRUE,
    'Configurable estimated credit price. Replace with organization-specific pricing.'
);


-- =========================================================
-- 2. SAVINGS ASSUMPTIONS
-- =========================================================

CREATE OR REPLACE TABLE
SNOWFLAKE_FINOPS.CONFIG.SAVINGS_ASSUMPTIONS
(
    RULE_ID VARCHAR,
    SAVINGS_RATE FLOAT,
    DESCRIPTION VARCHAR
);

INSERT INTO
SNOWFLAKE_FINOPS.CONFIG.SAVINGS_ASSUMPTIONS
VALUES
('R001', 0.25, 'Estimated 25% compute reduction after expensive query optimization.'),
('R002', 0.20, 'Estimated 20% compute reduction after partition pruning improvement.'),
('R003', 0.10, 'Estimated 10% compute reduction through improved cache effectiveness.'),
('R004', 0.20, 'Estimated 20% compute reduction after reducing query spill.'),
('R005', 0.50, 'Estimated 50% reduction in failed-query compute after fixing failures.'),
('R006', 0.15, 'Estimated 15% reduction from consolidating or caching repeated queries.'),
('R007', 1.00, 'Idle compute treated as potentially avoidable compute.'),
('R008', 0.25, 'Estimated 25% compute reduction after warehouse right-sizing.');


-- =========================================================
-- 3. RECOMMENDATION FACT TABLE
-- =========================================================

CREATE OR REPLACE TABLE
SNOWFLAKE_FINOPS.RECOMMENDATIONS.RECOMMENDATION_FACT
(
    RECOMMENDATION_ID VARCHAR,

    DETECTED_AT TIMESTAMP,

    ENTITY_TYPE VARCHAR,
    ENTITY_NAME VARCHAR,

    RECOMMENDATION_TYPE VARCHAR,
    SEVERITY VARCHAR,

    CONFIDENCE_SCORE FLOAT,

    CURRENT_STATE VARCHAR,
    RECOMMENDED_STATE VARCHAR,

    REASON VARCHAR,
    EVIDENCE VARCHAR,

    ESTIMATED_MONTHLY_CREDITS_SAVED FLOAT,
    ESTIMATED_MONTHLY_USD_SAVED FLOAT,

    IMPLEMENTATION_RISK VARCHAR,

    PRIORITY_SCORE FLOAT,

    STATUS VARCHAR,

    CREATED_BY VARCHAR,
    REVIEWED_BY VARCHAR,

    IMPLEMENTED_AT TIMESTAMP,

    VERIFIED_AT TIMESTAMP,

    VERIFICATION_STATUS VARCHAR
);


-- =========================================================
-- 4. LOAD PHASE 4 RECOMMENDATIONS
-- =========================================================

INSERT INTO
SNOWFLAKE_FINOPS.RECOMMENDATIONS.RECOMMENDATION_FACT
(
    RECOMMENDATION_ID,
    DETECTED_AT,
    ENTITY_TYPE,
    ENTITY_NAME,
    RECOMMENDATION_TYPE,
    SEVERITY,
    CONFIDENCE_SCORE,
    CURRENT_STATE,
    RECOMMENDED_STATE,
    REASON,
    EVIDENCE,
    ESTIMATED_MONTHLY_CREDITS_SAVED,
    ESTIMATED_MONTHLY_USD_SAVED,
    IMPLEMENTATION_RISK,
    PRIORITY_SCORE,
    STATUS,
    CREATED_BY,
    REVIEWED_BY,
    IMPLEMENTED_AT,
    VERIFIED_AT,
    VERIFICATION_STATUS
)

SELECT

    COALESCE(
        RECOMMENDATION_ID,
        'REC_' || UUID_STRING()
    ),

    CREATED_AT,

    OBJECT_TYPE,
    OBJECT_NAME,

    RULE_NAME,
    SEVERITY,

    CASE
        WHEN RULE_ID IN ('R004','R007')
            THEN 0.90

        WHEN RULE_ID IN ('R002','R005')
            THEN 0.85

        WHEN RULE_ID = 'R001'
            THEN 0.80

        WHEN RULE_ID IN ('R003','R006')
            THEN 0.75

        WHEN RULE_ID = 'R008'
            THEN 0.70

        ELSE 0.60
    END,

    CASE
        WHEN RULE_ID = 'R001'
            THEN 'High query execution time or data scanned'

        WHEN RULE_ID = 'R002'
            THEN 'High partition scan percentage'

        WHEN RULE_ID = 'R003'
            THEN 'Low cache utilization'

        WHEN RULE_ID = 'R004'
            THEN 'Query spilling detected'

        WHEN RULE_ID = 'R005'
            THEN 'Query execution failed'

        WHEN RULE_ID = 'R006'
            THEN 'Repeated query pattern'

        WHEN RULE_ID = 'R007'
            THEN 'Warehouse consumed credits without recorded query activity'

        WHEN RULE_ID = 'R008'
            THEN 'Warehouse is larger than XSMALL'

        ELSE
            'Optimization opportunity detected'
    END,

    CASE
        WHEN RULE_ID = 'R001'
            THEN 'Optimize query logic, filters, joins or data access'

        WHEN RULE_ID = 'R002'
            THEN 'Improve filters and partition pruning'

        WHEN RULE_ID = 'R003'
            THEN 'Improve repeated-query and cache usage'

        WHEN RULE_ID = 'R004'
            THEN 'Reduce memory pressure and query spill'

        WHEN RULE_ID = 'R005'
            THEN 'Fix failure cause and prevent repeated execution'

        WHEN RULE_ID = 'R006'
            THEN 'Consolidate, cache or schedule repeated workloads'

        WHEN RULE_ID = 'R007'
            THEN 'Reduce idle runtime using appropriate auto-suspend'

        WHEN RULE_ID = 'R008'
            THEN 'Evaluate smaller warehouse size'

        ELSE
            'Review optimization opportunity'
    END,

    RECOMMENDATION,

    EVIDENCE,

    0,
    0,

    CASE
        WHEN RULE_ID IN ('R003','R005','R006','R007')
            THEN 'LOW'

        WHEN RULE_ID IN ('R001','R002','R004','R008')
            THEN 'MEDIUM'

        ELSE
            'MEDIUM'
    END,

    0,

    'OPEN',

    CURRENT_USER(),

    NULL,
    NULL,
    NULL,

    'NOT_VERIFIED'

FROM
    SNOWFLAKE_FINOPS.RECOMMENDATIONS.OPTIMIZATION_RECOMMENDATIONS_CLEAN;


-- =========================================================
-- 6. QUERY-LEVEL SAVINGS
-- =========================================================

UPDATE
    SNOWFLAKE_FINOPS.RECOMMENDATIONS.RECOMMENDATION_FACT R

SET

    ESTIMATED_MONTHLY_CREDITS_SAVED =
        X.MONTHLY_CREDITS,

    ESTIMATED_MONTHLY_USD_SAVED =
        X.MONTHLY_USD

FROM
(
    SELECT

        R.RECOMMENDATION_ID,

        COALESCE(
            Q.ATTRIBUTED_CREDITS,
            0
        )

        *

        30

        *

        COALESCE(
            S.SAVINGS_RATE,
            0
        )

        AS MONTHLY_CREDITS,

        COALESCE(
            Q.ATTRIBUTED_CREDITS,
            0
        )

        *

        30

        *

        COALESCE(
            S.SAVINGS_RATE,
            0
        )

        *

        P.CREDIT_PRICE_USD

        AS MONTHLY_USD

    FROM
        SNOWFLAKE_FINOPS.RECOMMENDATIONS.RECOMMENDATION_FACT R

    LEFT JOIN
        SNOWFLAKE_FINOPS.ANALYTICS.QUERY_COMPUTE_ATTRIBUTION Q

    ON
        R.ENTITY_NAME = Q.QUERY_ID

    LEFT JOIN
        SNOWFLAKE_FINOPS.CONFIG.SAVINGS_ASSUMPTIONS S

    ON
        S.RULE_ID =

        CASE R.RECOMMENDATION_TYPE

            WHEN 'EXPENSIVE_QUERY'
                THEN 'R001'

            WHEN 'POOR_PARTITION_PRUNING'
                THEN 'R002'

            WHEN 'LOW_CACHE_USAGE'
                THEN 'R003'

            WHEN 'QUERY_SPILL'
                THEN 'R004'

            WHEN 'FAILED_QUERY'
                THEN 'R005'

            ELSE NULL

        END

    CROSS JOIN
    (
        SELECT

            CREDIT_PRICE_USD

        FROM
            SNOWFLAKE_FINOPS.CONFIG.CREDIT_PRICING

        WHERE
            IS_ACTIVE = TRUE

        QUALIFY
            ROW_NUMBER()
            OVER
            (
                ORDER BY EFFECTIVE_FROM DESC
            ) = 1

    ) P

    WHERE
        R.ENTITY_TYPE = 'QUERY'

) X

WHERE
    R.RECOMMENDATION_ID =
    X.RECOMMENDATION_ID;


-- =========================================================
-- 7. WAREHOUSE-LEVEL SAVINGS
-- =========================================================
-- Uses RAW WAREHOUSE_METERING_RAW.
-- CREDITS_USED is the actual Snowflake metering column.


UPDATE
    SNOWFLAKE_FINOPS.RECOMMENDATIONS.RECOMMENDATION_FACT R

SET

    ESTIMATED_MONTHLY_CREDITS_SAVED =
        X.MONTHLY_CREDITS,

    ESTIMATED_MONTHLY_USD_SAVED =
        X.MONTHLY_USD

FROM
(
    SELECT

        R.RECOMMENDATION_ID,

        CASE

            WHEN R.RECOMMENDATION_TYPE =
                 'IDLE_WAREHOUSE'

            THEN

                COALESCE(
                    C.TOTAL_CREDITS,
                    0
                )

                *

                (
                    30.0 /
                    NULLIF(
                        C.ACTIVE_DAYS,
                        0
                    )
                )

                *

                1.00


            WHEN R.RECOMMENDATION_TYPE =
                 'OVERSIZED_WAREHOUSE'

            THEN

                COALESCE(
                    C.TOTAL_CREDITS,
                    0
                )

                *

                (
                    30.0 /
                    NULLIF(
                        C.ACTIVE_DAYS,
                        0
                    )
                )

                *

                0.25


            WHEN R.RECOMMENDATION_TYPE =
                 'HIGH_QUERY_FREQUENCY'

            THEN

                COALESCE(
                    C.TOTAL_CREDITS,
                    0
                )

                *

                (
                    30.0 /
                    NULLIF(
                        C.ACTIVE_DAYS,
                        0
                    )
                )

                *

                0.15

            ELSE
                0

        END AS MONTHLY_CREDITS,


        CASE

            WHEN R.RECOMMENDATION_TYPE =
                 'IDLE_WAREHOUSE'

            THEN

                COALESCE(
                    C.TOTAL_CREDITS,
                    0
                )

                *

                (
                    30.0 /
                    NULLIF(
                        C.ACTIVE_DAYS,
                        0
                    )
                )

                *

                1.00

                *

                P.CREDIT_PRICE_USD


            WHEN R.RECOMMENDATION_TYPE =
                 'OVERSIZED_WAREHOUSE'

            THEN

                COALESCE(
                    C.TOTAL_CREDITS,
                    0
                )

                *

                (
                    30.0 /
                    NULLIF(
                        C.ACTIVE_DAYS,
                        0
                    )
                )

                *

                0.25

                *

                P.CREDIT_PRICE_USD


            WHEN R.RECOMMENDATION_TYPE =
                 'HIGH_QUERY_FREQUENCY'

            THEN

                COALESCE(
                    C.TOTAL_CREDITS,
                    0
                )

                *

                (
                    30.0 /
                    NULLIF(
                        C.ACTIVE_DAYS,
                        0
                    )
                )

                *

                0.15

                *

                P.CREDIT_PRICE_USD

            ELSE
                0

        END AS MONTHLY_USD

    FROM
        SNOWFLAKE_FINOPS.RECOMMENDATIONS.RECOMMENDATION_FACT R

    LEFT JOIN
    (
        SELECT

            WAREHOUSE_NAME,

            SUM(CREDITS_USED)
                AS TOTAL_CREDITS,

            COUNT(
                DISTINCT CAST(START_TIME AS DATE)
            )
                AS ACTIVE_DAYS

        FROM
            SNOWFLAKE_FINOPS.RAW.WAREHOUSE_METERING_RAW

        GROUP BY
            WAREHOUSE_NAME

    ) C

    ON
        R.ENTITY_NAME =
        C.WAREHOUSE_NAME

    CROSS JOIN
    (
        SELECT

            CREDIT_PRICE_USD

        FROM
            SNOWFLAKE_FINOPS.CONFIG.CREDIT_PRICING

        WHERE
            IS_ACTIVE = TRUE

        QUALIFY
            ROW_NUMBER()
            OVER
            (
                ORDER BY EFFECTIVE_FROM DESC
            ) = 1

    ) P

    WHERE

        R.ENTITY_TYPE IN
        (
            'WAREHOUSE',
            'QUERY_PATTERN'
        )

) X

WHERE

    R.RECOMMENDATION_ID =
    X.RECOMMENDATION_ID;


-- =========================================================
-- 8. PRIORITY SCORE
-- =========================================================

UPDATE
    SNOWFLAKE_FINOPS.RECOMMENDATIONS.RECOMMENDATION_FACT

SET

    PRIORITY_SCORE =

    ROUND
    (
        LEAST
        (
            100,

            (

                CASE

                    WHEN ESTIMATED_MONTHLY_USD_SAVED >= 100
                        THEN 100

                    WHEN ESTIMATED_MONTHLY_USD_SAVED >= 50
                        THEN 85

                    WHEN ESTIMATED_MONTHLY_USD_SAVED >= 20
                        THEN 70

                    WHEN ESTIMATED_MONTHLY_USD_SAVED >= 5
                        THEN 55

                    ELSE
                        30

                END

                *

                CONFIDENCE_SCORE

                *

                CASE

                    WHEN IMPLEMENTATION_RISK = 'LOW'
                        THEN 1.00

                    WHEN IMPLEMENTATION_RISK = 'MEDIUM'
                        THEN 0.80

                    ELSE
                        0.60

                END

                *

                CASE

                    WHEN SEVERITY = 'HIGH'
                        THEN 1.00

                    WHEN SEVERITY = 'MEDIUM'
                        THEN 0.85

                    ELSE
                        0.70

                END

            )

        ),

        2
    );


-- =========================================================
