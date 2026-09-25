-- =========================================================
-- SNOWFLAKE COST OPTIMIZATION ENGINE
-- INITIAL PROJECT SETUP
-- =========================================================

USE ROLE ACCOUNTADMIN;

-- ---------------------------------------------------------
-- 1. PROJECT DATABASE
-- ---------------------------------------------------------

CREATE OR REPLACE DATABASE SNOWFLAKE_FINOPS;

-- ---------------------------------------------------------
-- 2. PROJECT SCHEMAS
-- ---------------------------------------------------------

CREATE OR REPLACE SCHEMA SNOWFLAKE_FINOPS.RAW;

CREATE OR REPLACE SCHEMA SNOWFLAKE_FINOPS.CORE;

CREATE OR REPLACE SCHEMA SNOWFLAKE_FINOPS.ANALYTICS;

CREATE OR REPLACE SCHEMA SNOWFLAKE_FINOPS.RECOMMENDATIONS;

CREATE OR REPLACE SCHEMA SNOWFLAKE_FINOPS.CONFIG;

CREATE OR REPLACE SCHEMA SNOWFLAKE_FINOPS.AUDIT;

-- ---------------------------------------------------------
-- 3. PROJECT WAREHOUSE
-- ---------------------------------------------------------

CREATE OR REPLACE WAREHOUSE FINOPS_WH
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Warehouse for Snowflake Cost Optimization Engine';

-- ---------------------------------------------------------
-- 4. USE PROJECT CONTEXT
-- ---------------------------------------------------------

USE WAREHOUSE FINOPS_WH;

USE DATABASE SNOWFLAKE_FINOPS;

USE SCHEMA RAW;

-- ---------------------------------------------------------
-- 5. VERIFY
-- ---------------------------------------------------------

SELECT CURRENT_ROLE() AS CURRENT_ROLE,
       CURRENT_WAREHOUSE() AS CURRENT_WAREHOUSE,
       CURRENT_DATABASE() AS CURRENT_DATABASE,
       CURRENT_SCHEMA() AS CURRENT_SCHEMA;

SHOW DATABASES LIKE 'SNOWFLAKE_FINOPS';

SHOW SCHEMAS IN DATABASE SNOWFLAKE_FINOPS;

SHOW WAREHOUSES LIKE 'FINOPS_WH';

