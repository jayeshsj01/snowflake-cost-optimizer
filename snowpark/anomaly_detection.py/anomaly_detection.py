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

