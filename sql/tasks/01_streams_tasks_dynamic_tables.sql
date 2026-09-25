-- ============================================================
-- PHASE 7
-- STREAMS + TASKS + DYNAMIC TABLES
-- ============================================================


-- ============================================================
-- 1. INCREMENTAL CORE TABLE
-- ============================================================

CREATE OR REPLACE TABLE
SNOWFLAKE_FINOPS.CORE.WAREHOUSE_METERING_INCREMENTAL
AS
SELECT
    START_TIME,
    END_TIME,
    WAREHOUSE_NAME,
    CREDITS_USED,
    CREDITS_USED_COMPUTE,
    CREDITS_USED_CLOUD_SERVICES,
    CREDITS_ATTRIBUTED_COMPUTE_QUERIES
FROM SNOWFLAKE_FINOPS.RAW.WAREHOUSE_METERING_RAW
WHERE 1 = 0;


-- ============================================================
-- 2. STREAM ON RAW WAREHOUSE METERING
-- ============================================================

CREATE OR REPLACE STREAM
SNOWFLAKE_FINOPS.CORE.WAREHOUSE_METERING_STREAM
ON TABLE SNOWFLAKE_FINOPS.RAW.WAREHOUSE_METERING_RAW;


-- ============================================================
-- 3. TASK TO PROCESS NEW RAW RECORDS
-- ============================================================

CREATE OR REPLACE TASK
SNOWFLAKE_FINOPS.CORE.PROCESS_WAREHOUSE_METERING_STREAM
WAREHOUSE = FINOPS_WH
SCHEDULE = '5 MINUTE'
WHEN SYSTEM$STREAM_HAS_DATA(
    'SNOWFLAKE_FINOPS.CORE.WAREHOUSE_METERING_STREAM'
)
AS
INSERT INTO
SNOWFLAKE_FINOPS.CORE.WAREHOUSE_METERING_INCREMENTAL
(
    START_TIME,
    END_TIME,
    WAREHOUSE_NAME,
    CREDITS_USED,
    CREDITS_USED_COMPUTE,
    CREDITS_USED_CLOUD_SERVICES,
    CREDITS_ATTRIBUTED_COMPUTE_QUERIES
)
SELECT
    START_TIME,
    END_TIME,
    WAREHOUSE_NAME,
    CREDITS_USED,
    CREDITS_USED_COMPUTE,
    CREDITS_USED_CLOUD_SERVICES,
    CREDITS_ATTRIBUTED_COMPUTE_QUERIES
FROM
SNOWFLAKE_FINOPS.CORE.WAREHOUSE_METERING_STREAM
WHERE METADATA$ACTION = 'INSERT';


-- ============================================================
-- 4. START THE TASK
-- ============================================================

ALTER TASK
SNOWFLAKE_FINOPS.CORE.PROCESS_WAREHOUSE_METERING_STREAM
RESUME;


-- ============================================================
-- 5. INITIAL LOAD
-- ============================================================

INSERT INTO
SNOWFLAKE_FINOPS.CORE.WAREHOUSE_METERING_INCREMENTAL
(
    START_TIME,
    END_TIME,
    WAREHOUSE_NAME,
    CREDITS_USED,
    CREDITS_USED_COMPUTE,
    CREDITS_USED_CLOUD_SERVICES,
    CREDITS_ATTRIBUTED_COMPUTE_QUERIES
)
SELECT
    START_TIME,
    END_TIME,
    WAREHOUSE_NAME,
    CREDITS_USED,
    CREDITS_USED_COMPUTE,
    CREDITS_USED_CLOUD_SERVICES,
    CREDITS_ATTRIBUTED_COMPUTE_QUERIES
FROM
SNOWFLAKE_FINOPS.RAW.WAREHOUSE_METERING_RAW;


-- ============================================================
-- 6. DYNAMIC TABLE
-- ============================================================

CREATE OR REPLACE DYNAMIC TABLE
SNOWFLAKE_FINOPS.ANALYTICS.DAILY_COST_DYNAMIC
TARGET_LAG = '5 MINUTE'
WAREHOUSE = FINOPS_WH
AS
SELECT
    WAREHOUSE_NAME,

    START_TIME::DATE AS USAGE_DATE,

    ROUND(
        SUM(COALESCE(CREDITS_USED, 0)),
        6
    ) AS TOTAL_CREDITS,

    ROUND(
        SUM(COALESCE(CREDITS_USED_COMPUTE, 0)),
        6
    ) AS COMPUTE_CREDITS,

    ROUND(
        SUM(COALESCE(CREDITS_USED_CLOUD_SERVICES, 0)),
        6
    ) AS CLOUD_SERVICES_CREDITS,

    ROUND(
        SUM(
            COALESCE(
                CREDITS_ATTRIBUTED_COMPUTE_QUERIES,
                0
            )
        ),
        6
    ) AS QUERY_ATTRIBUTED_COMPUTE_CREDITS,

    ROUND(
        GREATEST(
            SUM(
                COALESCE(
                    CREDITS_USED_COMPUTE,
                    0
                )
            )
            -
            SUM(
                COALESCE(
                    CREDITS_ATTRIBUTED_COMPUTE_QUERIES,
                    0
                )
            ),
            0
        ),
        6
    ) AS ESTIMATED_IDLE_CREDITS,

    ROUND(
        CASE
            WHEN SUM(
                COALESCE(
                    CREDITS_USED_COMPUTE,
                    0
                )
            ) > 0
            THEN
                (
                    GREATEST(
                        SUM(
                            COALESCE(
                                CREDITS_USED_COMPUTE,
                                0
                            )
                        )
                        -
                        SUM(
                            COALESCE(
                                CREDITS_ATTRIBUTED_COMPUTE_QUERIES,
                                0
                            )
                        ),
                        0
                    )
                    /
                    SUM(
                        COALESCE(
                            CREDITS_USED_COMPUTE,
                            0
                        )
                    )
                ) * 100
            ELSE 0
        END,
        2
    ) AS IDLE_PERCENTAGE

FROM
SNOWFLAKE_FINOPS.CORE.WAREHOUSE_METERING_INCREMENTAL

GROUP BY
    WAREHOUSE_NAME,
    START_TIME::DATE;


-- ============================================================
-- 7. VERIFY STREAM
-- ============================================================

SHOW STREAMS
IN SCHEMA SNOWFLAKE_FINOPS.CORE;


-- ============================================================
-- 8. VERIFY TASK
-- ============================================================

SHOW TASKS
IN SCHEMA SNOWFLAKE_FINOPS.CORE;


-- ============================================================
-- 9. VERIFY DYNAMIC TABLE
-- ============================================================

SHOW DYNAMIC TABLES
IN SCHEMA SNOWFLAKE_FINOPS.ANALYTICS;


-- ============================================================
-- 10. VERIFY DATA
-- ============================================================

SELECT *
FROM SNOWFLAKE_FINOPS.CORE.WAREHOUSE_METERING_INCREMENTAL
ORDER BY START_TIME DESC
LIMIT 20;


SELECT *
FROM SNOWFLAKE_FINOPS.ANALYTICS.DAILY_COST_DYNAMIC
ORDER BY USAGE_DATE DESC
LIMIT 20;


