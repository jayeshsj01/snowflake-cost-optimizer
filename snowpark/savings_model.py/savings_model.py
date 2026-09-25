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

