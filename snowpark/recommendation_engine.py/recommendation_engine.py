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

