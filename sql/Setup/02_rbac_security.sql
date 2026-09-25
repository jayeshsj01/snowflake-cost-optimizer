USE ROLE ACCOUNTADMIN;

-- ============================================================
-- PHASE 8 — RBAC / SECURITY
-- ============================================================


-- ============================================================
-- 1. CREATE PROJECT ROLES
-- ============================================================

CREATE ROLE IF NOT EXISTS FINOPS_ADMIN;

CREATE ROLE IF NOT EXISTS FINOPS_ANALYST;

CREATE ROLE IF NOT EXISTS FINOPS_VIEWER;


-- ============================================================
-- 2. ROLE HIERARCHY
-- ============================================================

-- Viewer gets analyst permissions
GRANT ROLE FINOPS_VIEWER
TO ROLE FINOPS_ANALYST;

-- Analyst gets admin-level project permissions
GRANT ROLE FINOPS_ANALYST
TO ROLE FINOPS_ADMIN;


-- ============================================================
-- 3. DATABASE ACCESS
-- ============================================================

GRANT USAGE
ON DATABASE SNOWFLAKE_FINOPS
TO ROLE FINOPS_VIEWER;

GRANT USAGE
ON DATABASE SNOWFLAKE_FINOPS
TO ROLE FINOPS_ANALYST;

GRANT USAGE
ON DATABASE SNOWFLAKE_FINOPS
TO ROLE FINOPS_ADMIN;


-- ============================================================
-- 4. VIEWER ACCESS
-- ============================================================

GRANT USAGE
ON SCHEMA SNOWFLAKE_FINOPS.ANALYTICS
TO ROLE FINOPS_VIEWER;

GRANT USAGE
ON SCHEMA SNOWFLAKE_FINOPS.RECOMMENDATIONS
TO ROLE FINOPS_VIEWER;

GRANT USAGE
ON SCHEMA SNOWFLAKE_FINOPS.AUDIT
TO ROLE FINOPS_VIEWER;


GRANT SELECT
ON ALL VIEWS
IN SCHEMA SNOWFLAKE_FINOPS.ANALYTICS
TO ROLE FINOPS_VIEWER;

GRANT SELECT
ON ALL VIEWS
IN SCHEMA SNOWFLAKE_FINOPS.RECOMMENDATIONS
TO ROLE FINOPS_VIEWER;

GRANT SELECT
ON ALL VIEWS
IN SCHEMA SNOWFLAKE_FINOPS.AUDIT
TO ROLE FINOPS_VIEWER;


GRANT SELECT
ON ALL TABLES
IN SCHEMA SNOWFLAKE_FINOPS.ANALYTICS
TO ROLE FINOPS_VIEWER;

GRANT SELECT
ON ALL TABLES
IN SCHEMA SNOWFLAKE_FINOPS.RECOMMENDATIONS
TO ROLE FINOPS_VIEWER;

GRANT SELECT
ON ALL TABLES
IN SCHEMA SNOWFLAKE_FINOPS.AUDIT
TO ROLE FINOPS_VIEWER;


-- ============================================================
-- 5. ANALYST ACCESS
-- ============================================================

GRANT USAGE
ON ALL SCHEMAS
IN DATABASE SNOWFLAKE_FINOPS
TO ROLE FINOPS_ANALYST;

GRANT SELECT
ON ALL TABLES
IN DATABASE SNOWFLAKE_FINOPS
TO ROLE FINOPS_ANALYST;

GRANT SELECT
ON ALL VIEWS
IN DATABASE SNOWFLAKE_FINOPS
TO ROLE FINOPS_ANALYST;


-- ============================================================
-- 6. ADMIN PROJECT ACCESS
-- ============================================================

GRANT USAGE
ON ALL SCHEMAS
IN DATABASE SNOWFLAKE_FINOPS
TO ROLE FINOPS_ADMIN;

GRANT SELECT, INSERT, UPDATE, DELETE
ON ALL TABLES
IN DATABASE SNOWFLAKE_FINOPS
TO ROLE FINOPS_ADMIN;

GRANT SELECT
ON ALL VIEWS
IN DATABASE SNOWFLAKE_FINOPS
TO ROLE FINOPS_ADMIN;


-- ============================================================
-- 7. FUTURE OBJECT GRANTS
-- ============================================================

GRANT SELECT
ON FUTURE TABLES
IN DATABASE SNOWFLAKE_FINOPS
TO ROLE FINOPS_ANALYST;

GRANT SELECT
ON FUTURE VIEWS
IN DATABASE SNOWFLAKE_FINOPS
TO ROLE FINOPS_ANALYST;


GRANT SELECT
ON FUTURE TABLES
IN DATABASE SNOWFLAKE_FINOPS
TO ROLE FINOPS_VIEWER;

GRANT SELECT
ON FUTURE VIEWS
IN DATABASE SNOWFLAKE_FINOPS
TO ROLE FINOPS_VIEWER;


-- ============================================================
-- 8. SECURE VIEW FOR DASHBOARD USERS
-- ============================================================

CREATE OR REPLACE SECURE VIEW
SNOWFLAKE_FINOPS.RECOMMENDATIONS.SECURE_RECOMMENDATIONS
AS
SELECT
    RECOMMENDATION_ID,
    RULE_ID,
    RULE_NAME,
    OBJECT_TYPE,
    OBJECT_NAME,
    RECOMMENDATION,
    EVIDENCE,
    ESTIMATED_SAVINGS_USD,
    CONFIDENCE_SCORE,
    PRIORITY_SCORE,
    SEVERITY,
    RISK_LEVEL,
    CREATED_AT
FROM
SNOWFLAKE_FINOPS.RECOMMENDATIONS.OPTIMIZATION_RECOMMENDATIONS_CLEAN;


GRANT SELECT
ON VIEW
SNOWFLAKE_FINOPS.RECOMMENDATIONS.SECURE_RECOMMENDATIONS
TO ROLE FINOPS_VIEWER;


-- ============================================================
-- 9. CREATE SECURITY DOCUMENTATION TABLE
-- ============================================================

CREATE OR REPLACE TABLE
SNOWFLAKE_FINOPS.AUDIT.RBAC_ROLE_DOCUMENTATION
(
    ROLE_NAME VARCHAR,
    ROLE_PURPOSE VARCHAR,
    ACCESS_LEVEL VARCHAR,
    ALLOWED_OBJECTS VARCHAR,
    NOTES VARCHAR
);


INSERT INTO
SNOWFLAKE_FINOPS.AUDIT.RBAC_ROLE_DOCUMENTATION
VALUES
(
    'FINOPS_ADMIN',
    'Project administration and configuration',
    'HIGH',
    'All SNOWFLAKE_FINOPS project objects',
    'Used for project administration, not normal dashboard access'
),
(
    'FINOPS_ANALYST',
    'FinOps analysis and investigation',
    'MEDIUM',
    'Project tables and views',
    'Used for analytics and recommendation investigation'
),
(
    'FINOPS_VIEWER',
    'Dashboard and read-only consumption',
    'LOW',
    'Analytics, recommendations and audit outputs',
    'Read-only role for dashboard users'
);


-- ============================================================
-- 10. VERIFY ROLES
-- ============================================================

SHOW ROLES;


-- ============================================================
-- 11. VERIFY ROLE HIERARCHY
-- ============================================================

SHOW GRANTS
TO ROLE FINOPS_ADMIN;

SHOW GRANTS
TO ROLE FINOPS_ANALYST;

SHOW GRANTS
TO ROLE FINOPS_VIEWER;


-- ============================================================
-- 12. VERIFY SECURE VIEW
-- ============================================================

SELECT *
FROM SNOWFLAKE_FINOPS.RECOMMENDATIONS.SECURE_RECOMMENDATIONS
LIMIT 10;


-- ============================================================
-- 13. VERIFY RBAC DOCUMENTATION
-- ============================================================

SELECT *
FROM SNOWFLAKE_FINOPS.AUDIT.RBAC_ROLE_DOCUMENTATION;


USE DATABASE SNOWFLAKE_FINOPS;

DESC TABLE ANALYTICS.DAILY_WAREHOUSE_COST;