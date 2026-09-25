-- PHASE 6: SNOWPARK PYTHON
-- Register Snowpark Python procedures
-- ============================================================


-- ============================================================
-- 1. ANOMALY DETECTION
-- ============================================================

CREATE OR REPLACE PROCEDURE
SNOWFLAKE_FINOPS.ANALYTICS.RUN_COST_ANOMALY_DETECTION()
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'main'
AS
$$

from snowflake.snowpark import Session
from snowflake.snowpark.functions import (
    col,
    sum as sf_sum,
    avg,
    stddev,
    count,
    when,
    lit,
    current_timestamp,
    round as sf_round
)
from snowflake.snowpark.window import Window


def main(session: Session):

    source = session.table(
        "SNOWFLAKE_FINOPS.RAW.WAREHOUSE_METERING_RAW"
    )

    daily = (
        source
        .filter(
            col("WAREHOUSE_NAME").is_not_null()
            & col("CREDITS_USED").is_not_null()
        )
        .group_by(
            col("WAREHOUSE_NAME"),
            col("START_TIME").cast("DATE").alias("USAGE_DATE")
        )
        .agg(
            sf_round(
                sf_sum(col("CREDITS_USED")),
                6
            ).alias("DAILY_CREDITS")
        )
    )

    w = Window.partition_by(
        col("WAREHOUSE_NAME")
    )

    result = (
        daily
        .with_column(
            "AVG_DAILY_CREDITS",
            sf_round(
                avg(col("DAILY_CREDITS")).over(w),
                6
            )
        )
        .with_column(
            "STDDEV_DAILY_CREDITS",
            sf_round(
                stddev(col("DAILY_CREDITS")).over(w),
                6
            )
        )
        .with_column(
            "BASELINE_DAYS",
            count(col("USAGE_DATE")).over(w)
        )
        .with_column(
            "Z_SCORE",
            when(
                col("STDDEV_DAILY_CREDITS") > 0,
                (
                    col("DAILY_CREDITS")
                    - col("AVG_DAILY_CREDITS")
                )
                / col("STDDEV_DAILY_CREDITS")
            ).otherwise(lit(0))
        )
        .with_column(
            "ANOMALY_FLAG",
            when(
                (col("BASELINE_DAYS") >= 3)
                & (col("Z_SCORE") >= 2),
                lit(True)
            ).otherwise(lit(False))
        )
        .with_column(
            "ANOMALY_SEVERITY",
            when(
                col("Z_SCORE") >= 3,
                lit("HIGH")
            )
            .when(
                col("Z_SCORE") >= 2,
                lit("MEDIUM")
            )
            .otherwise(lit("NORMAL"))
        )
        .with_column(
            "BASELINE_STATUS",
            when(
                col("BASELINE_DAYS") >= 3,
                lit("SUFFICIENT")
            ).otherwise(lit("LIMITED_HISTORY"))
        )
        .with_column(
            "DETECTED_AT",
            current_timestamp()
        )
    )

    result.write.mode("overwrite").save_as_table(
        "SNOWFLAKE_FINOPS.ANALYTICS.COST_ANOMALIES"
    )

    anomaly_count = (
        result
        .filter(col("ANOMALY_FLAG") == True)
        .count()
    )

    total_rows = result.count()

    return (
        "Cost anomaly detection completed. "
        + str(total_rows)
        + " records analyzed. "
        + str(anomaly_count)
        + " anomalies detected."
    )

$$;


-- ============================================================
-- 2. SNOWPARK RECOMMENDATION ENGINE
-- ============================================================

CREATE OR REPLACE PROCEDURE SNOWFLAKE_FINOPS.RECOMMENDATIONS.RUN_SNOWPARK_RECOMMENDATION_ENGINE()
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'main'
AS
$$

from snowflake.snowpark import Session
from snowflake.snowpark.functions import (
    col,
    lit,
    when,
    upper,
    round as sf_round
)


DATABASE = "SNOWFLAKE_FINOPS"

SOURCE_TABLE = (
    f"{DATABASE}.RECOMMENDATIONS."
    f"OPTIMIZATION_RECOMMENDATIONS_CLEAN"
)

OUTPUT_TABLE = (
    f"{DATABASE}.RECOMMENDATIONS."
    f"SNOWPARK_RECOMMENDATIONS"
)


def main(session: Session):

    recommendations = (
        session.table(SOURCE_TABLE)
        .select(
            col("RECOMMENDATION_ID"),
            col("RULE_ID"),
            col("RULE_NAME"),
            col("OBJECT_TYPE"),
            col("OBJECT_NAME"),
            col("RECOMMENDATION"),
            col("EVIDENCE"),
            col("ESTIMATED_SAVINGS_USD"),
            col("CONFIDENCE_SCORE"),
            col("PRIORITY_SCORE"),
            col("SEVERITY"),
            col("RISK_LEVEL"),
            col("CREATED_AT")
        )
    )

    recommendations = (
        recommendations
        .with_column(
            "CONFIDENCE_NORMALIZED",
            when(
                col("CONFIDENCE_SCORE").is_null(),
                lit(0)
            )
            .otherwise(
                col("CONFIDENCE_SCORE")
            )
        )
        .with_column(
            "SEVERITY_FACTOR",
            when(
                upper(col("SEVERITY")) == "HIGH",
                lit(1.0)
            )
            .when(
                upper(col("SEVERITY")) == "MEDIUM",
                lit(0.8)
            )
            .when(
                upper(col("SEVERITY")) == "LOW",
                lit(0.6)
            )
            .otherwise(
                lit(0.7)
            )
        )
        .with_column(
            "RISK_FACTOR",
            when(
                upper(col("RISK_LEVEL")) == "LOW",
                lit(1.0)
            )
            .when(
                upper(col("RISK_LEVEL")) == "MEDIUM",
                lit(0.85)
            )
            .when(
                upper(col("RISK_LEVEL")) == "HIGH",
                lit(0.7)
            )
            .otherwise(
                lit(0.8)
            )
        )
    )

    result = recommendations.with_column(
        "SAVINGS_SCORE",
        when(
            col("ESTIMATED_SAVINGS_USD") >= 1000,
            lit(100)
        )
        .when(
            col("ESTIMATED_SAVINGS_USD") >= 500,
            lit(85)
        )
        .when(
            col("ESTIMATED_SAVINGS_USD") >= 100,
            lit(70)
        )
        .when(
            col("ESTIMATED_SAVINGS_USD") >= 25,
            lit(55)
        )
        .otherwise(
            lit(30)
        )
    )

    result = result.with_column(
        "SNOWPARK_PRIORITY_SCORE",
        sf_round(
            col("SAVINGS_SCORE")
            * col("CONFIDENCE_NORMALIZED")
            * col("SEVERITY_FACTOR")
            * col("RISK_FACTOR"),
            2
        )
    )

    result = result.with_column(
        "PRIORITY_BUCKET",
        when(
            col("SNOWPARK_PRIORITY_SCORE") >= 80,
            lit("CRITICAL")
        )
        .when(
            col("SNOWPARK_PRIORITY_SCORE") >= 60,
            lit("HIGH")
        )
        .when(
            col("SNOWPARK_PRIORITY_SCORE") >= 40,
            lit("MEDIUM")
        )
        .otherwise(
            lit("LOW")
        )
    )

    result = result.with_column(
        "ENGINE_TYPE",
        lit("SNOWPARK")
    )

    result.write.mode("overwrite").save_as_table(
        OUTPUT_TABLE
    )

    recommendation_count = result.count()

    return (
        "Snowpark recommendation engine completed. "
        + str(recommendation_count)
        + " recommendations processed."
    )

$$;


-- ============================================================
-- 3. SNOWPARK SAVINGS MODEL
-- ============================================================

CREATE OR REPLACE PROCEDURE SNOWFLAKE_FINOPS.ANALYTICS.RUN_SNOWPARK_SAVINGS_MODEL()
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'main'
AS
$$

from snowflake.snowpark import Session
from snowflake.snowpark.functions import (
    col,
    lit,
    sum as sf_sum,
    round as sf_round,
    current_timestamp
)


DATABASE = "SNOWFLAKE_FINOPS"

RECOMMENDATIONS_TABLE = (
    f"{DATABASE}.RECOMMENDATIONS."
    f"SNOWPARK_RECOMMENDATIONS"
)

PRICING_TABLE = (
    f"{DATABASE}.CONFIG.CREDIT_PRICING"
)

OUTPUT_TABLE = (
    f"{DATABASE}.ANALYTICS."
    f"SNOWPARK_SAVINGS_MODEL"
)


def main(session: Session):

    recommendations = (
        session.table(RECOMMENDATIONS_TABLE)
        .select(
            col("RECOMMENDATION_ID"),
            col("RULE_ID"),
            col("RULE_NAME"),
            col("OBJECT_TYPE"),
            col("OBJECT_NAME"),
            col("ESTIMATED_SAVINGS_USD"),
            col("SNOWPARK_PRIORITY_SCORE"),
            col("PRIORITY_BUCKET")
        )
    )

    pricing = (
        session.table(PRICING_TABLE)
        .filter(
            col("IS_ACTIVE") == lit(True)
        )
        .select(
            col("CREDIT_PRICE_USD")
        )
        .limit(1)
    )

    result = (
        recommendations
        .cross_join(pricing)
        .with_column(
            "ESTIMATED_MONTHLY_CREDITS_SAVED",
            sf_round(
                col("ESTIMATED_SAVINGS_USD")
                / col("CREDIT_PRICE_USD"),
                6
            )
        )
        .with_column(
            "CALCULATED_MONTHLY_USD_SAVED",
            sf_round(
                col("ESTIMATED_MONTHLY_CREDITS_SAVED")
                * col("CREDIT_PRICE_USD"),
                2
            )
        )
        .with_column(
            "SAVINGS_MODEL_STATUS",
            lit("MODEL_ESTIMATE")
        )
        .with_column(
            "CALCULATED_AT",
            current_timestamp()
        )
    )

    result.write.mode("overwrite").save_as_table(
        OUTPUT_TABLE
    )

    total_usd = (
        result
        .agg(
            sf_round(
                sf_sum(
                    col(
                        "CALCULATED_MONTHLY_USD_SAVED"
                    )
                ),
                2
            ).alias("TOTAL_USD")
        )
        .collect()[0]["TOTAL_USD"]
    )

    return (
        "Snowpark savings model completed. "
        "Estimated monthly savings: $"
        + str(total_usd)
    )

$$;


-- ============================================================
-- 4. EXECUTE ALL THREE SNOWPARK PROCEDURES
-- ============================================================

CALL SNOWFLAKE_FINOPS.ANALYTICS.RUN_COST_ANOMALY_DETECTION();

CALL SNOWFLAKE_FINOPS.RECOMMENDATIONS.RUN_SNOWPARK_RECOMMENDATION_ENGINE();

CALL SNOWFLAKE_FINOPS.ANALYTICS.RUN_SNOWPARK_SAVINGS_MODEL();


-- ============================================================
-- 5. VERIFY OUTPUTS
-- ============================================================

SELECT
    'COST_ANOMALIES' AS OUTPUT_OBJECT,
    COUNT(*) AS ROW_COUNT
FROM SNOWFLAKE_FINOPS.ANALYTICS.COST_ANOMALIES

UNION ALL

SELECT
    'SNOWPARK_RECOMMENDATIONS',
    COUNT(*)
FROM SNOWFLAKE_FINOPS.RECOMMENDATIONS.SNOWPARK_RECOMMENDATIONS

UNION ALL

SELECT
    'SNOWPARK_SAVINGS_MODEL',
    COUNT(*)
FROM SNOWFLAKE_FINOPS.ANALYTICS.SNOWPARK_SAVINGS_MODEL;


-- ============================================================
-- 6. SHOW ANOMALIES
-- ============================================================

SELECT
    WAREHOUSE_NAME,
    USAGE_DATE,
    DAILY_CREDITS,
    AVG_DAILY_CREDITS,
    Z_SCORE,
    ANOMALY_FLAG,
    ANOMALY_SEVERITY,
    BASELINE_STATUS
FROM SNOWFLAKE_FINOPS.ANALYTICS.COST_ANOMALIES
ORDER BY
    ANOMALY_FLAG DESC,
    Z_SCORE DESC
LIMIT 25;


-- ============================================================
-- 7. SHOW TOP SNOWPARK RECOMMENDATIONS
-- ============================================================

SELECT
    RECOMMENDATION_ID,
    RULE_NAME,
    OBJECT_TYPE,
    OBJECT_NAME,
    ESTIMATED_SAVINGS_USD,
    CONFIDENCE_SCORE,
    SNOWPARK_PRIORITY_SCORE,
    PRIORITY_BUCKET
FROM SNOWFLAKE_FINOPS.RECOMMENDATIONS.SNOWPARK_RECOMMENDATIONS
ORDER BY SNOWPARK_PRIORITY_SCORE DESC
LIMIT 25;


-- ============================================================
-- 8. SAVINGS SUMMARY
-- ============================================================

SELECT
    COUNT(*) AS RECOMMENDATION_COUNT,
    ROUND(
        SUM(ESTIMATED_MONTHLY_CREDITS_SAVED),
        4
    ) AS TOTAL_MONTHLY_CREDITS_SAVED,
    ROUND(
        SUM(CALCULATED_MONTHLY_USD_SAVED),
        2
    ) AS TOTAL_MONTHLY_USD_SAVED
FROM SNOWFLAKE_FINOPS.ANALYTICS.SNOWPARK_SAVINGS_MODEL;



USE ROLE ACCOUNTADMIN;

CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_FINOPS.STREAMLIT;

GRANT USAGE ON DATABASE SNOWFLAKE_FINOPS TO ROLE FINOPS_VIEWER;
GRANT USAGE ON SCHEMA SNOWFLAKE_FINOPS.STREAMLIT TO ROLE FINOPS_VIEWER;