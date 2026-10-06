-- ============================================================
-- PHASE 4: COHORT RETENTION ANALYSIS
-- ============================================================

-- ------------------------------------------------------------
-- 1. Basic validation checks
-- ------------------------------------------------------------

-- Check the number of customers in the RFM segmentation table
SELECT COUNT(*) AS customers
FROM customer_segments;

-- Preview customer segmentation results
SELECT *
FROM customer_segments
LIMIT 5;

-- Check the total number of cleaned transaction rows
SELECT COUNT(*) AS Rowsintable
FROM retail_clean;


-- ------------------------------------------------------------
-- 2. Identify each customer's acquisition/cohort month
-- ------------------------------------------------------------
-- cohort_month = the month of the customer's first-ever purchase
-- This month remains fixed for each customer.

WITH customer_first_purchase AS (
    SELECT
        CustomerID,
        DATE_FORMAT(
            MIN(InvoiceDate),
            '%Y-%m-01'
        ) AS cohort_month
    FROM retail_clean
    GROUP BY CustomerID
)

SELECT *
FROM customer_first_purchase
ORDER BY cohort_month
LIMIT 20;


-- ------------------------------------------------------------
-- 3. Create customer purchase activity
-- ------------------------------------------------------------
-- cohort_month  = customer's first purchase month
-- purchase_month = month in which the customer made a purchase
-- A customer can have multiple purchase_month values.

WITH customer_first_purchase AS (
    SELECT
        CustomerID,
        DATE_FORMAT(
            MIN(InvoiceDate),
            '%Y-%m-01'
        ) AS cohort_month
    FROM retail_clean
    GROUP BY CustomerID
)

SELECT
    r.CustomerID,
    c.cohort_month,
    DATE_FORMAT(
        r.InvoiceDate,
        '%Y-%m-01'
    ) AS purchase_month
FROM retail_clean r
JOIN customer_first_purchase c
    ON r.CustomerID = c.CustomerID
LIMIT 20;


-- ------------------------------------------------------------
-- 4. Calculate cohort month number
-- ------------------------------------------------------------
-- cohort_month_number tells us how many months have passed
-- since the customer's acquisition/cohort month.
--
-- 0 = acquisition month
-- 1 = one month after acquisition
-- 2 = two months after acquisition
-- 3 = three months after acquisition, etc.

WITH customer_first_purchase AS (
    SELECT
        CustomerID,
        DATE_FORMAT(
            MIN(InvoiceDate),
            '%Y-%m-01'
        ) AS cohort_month
    FROM retail_clean
    GROUP BY CustomerID
),

customer_activity AS (
    SELECT
        r.CustomerID,
        c.cohort_month,
        DATE_FORMAT(
            r.InvoiceDate,
            '%Y-%m-01'
        ) AS purchase_month
    FROM retail_clean r
    JOIN customer_first_purchase c
        ON r.CustomerID = c.CustomerID
)

SELECT
    CustomerID,
    cohort_month,
    purchase_month,
    TIMESTAMPDIFF(
        MONTH,
        cohort_month,
        purchase_month
    ) AS cohort_month_number
FROM customer_activity
LIMIT 20;


-- ------------------------------------------------------------
-- 5. Calculate active customers for each cohort period
-- ------------------------------------------------------------
-- active_customers = unique customers from a cohort who
-- made at least one purchase during that purchase month.
--
-- Example:
-- cohort_month = December 2009
-- month 0 = customers who purchased in December 2009
-- month 1 = customers who returned and purchased in January 2010
-- month 2 = customers who purchased in February 2010, etc.

WITH customer_first_purchase AS (
    SELECT
        CustomerID,
        DATE_FORMAT(
            MIN(InvoiceDate),
            '%Y-%m-01'
        ) AS cohort_month
    FROM retail_clean
    GROUP BY CustomerID
),

customer_activity AS (
    SELECT DISTINCT
        r.CustomerID,
        c.cohort_month,
        DATE_FORMAT(
            r.InvoiceDate,
            '%Y-%m-01'
        ) AS purchase_month
    FROM retail_clean r
    JOIN customer_first_purchase c
        ON r.CustomerID = c.CustomerID
)

SELECT
    cohort_month,
    TIMESTAMPDIFF(
        MONTH,
        cohort_month,
        purchase_month
    ) AS cohort_month_number,
    COUNT(DISTINCT CustomerID) AS active_customers
FROM customer_activity
GROUP BY
    cohort_month,
    cohort_month_number
ORDER BY
    cohort_month,
    cohort_month_number;


-- ------------------------------------------------------------
-- 6. Calculate cohort size
-- ------------------------------------------------------------
-- cohort_size = number of customers in the cohort during
-- their acquisition month (month 0).
--
-- FIRST_VALUE() gets the month 0 customer count for each cohort.
-- This value becomes the denominator for retention calculation.

WITH customer_first_purchase AS (
    SELECT
        CustomerID,
        DATE_FORMAT(
            MIN(InvoiceDate),
            '%Y-%m-01'
        ) AS cohort_month
    FROM retail_clean
    GROUP BY CustomerID
),

customer_activity AS (
    SELECT DISTINCT
        r.CustomerID,
        c.cohort_month,
        DATE_FORMAT(
            r.InvoiceDate,
            '%Y-%m-01'
        ) AS purchase_month
    FROM retail_clean r
    JOIN customer_first_purchase c
        ON r.CustomerID = c.CustomerID
),

cohort_activity AS (
    SELECT
        cohort_month,
        TIMESTAMPDIFF(
            MONTH,
            cohort_month,
            purchase_month
        ) AS cohort_month_number,
        COUNT(DISTINCT CustomerID) AS active_customers
    FROM customer_activity
    GROUP BY
        cohort_month,
        cohort_month_number
)

SELECT
    cohort_month,
    cohort_month_number,
    active_customers,
    FIRST_VALUE(active_customers) OVER (
        PARTITION BY cohort_month
        ORDER BY cohort_month_number
    ) AS cohort_size
FROM cohort_activity
ORDER BY
    cohort_month,
    cohort_month_number;


-- ------------------------------------------------------------
-- 7. Calculate retention percentage
-- ------------------------------------------------------------
-- Retention % = active customers / cohort size × 100
--
-- Month 0 should always be 100% because the cohort size
-- represents the customers acquired in month 0.

WITH customer_first_purchase AS (
    SELECT
        CustomerID,
        DATE_FORMAT(
            MIN(InvoiceDate),
            '%Y-%m-01'
        ) AS cohort_month
    FROM retail_clean
    GROUP BY CustomerID
),

customer_activity AS (
    SELECT DISTINCT
        r.CustomerID,
        c.cohort_month,
        DATE_FORMAT(
            r.InvoiceDate,
            '%Y-%m-01'
        ) AS purchase_month
    FROM retail_clean r
    JOIN customer_first_purchase c
        ON r.CustomerID = c.CustomerID
),

cohort_activity AS (
    SELECT
        cohort_month,
        TIMESTAMPDIFF(
            MONTH,
            cohort_month,
            purchase_month
        ) AS cohort_month_number,
        COUNT(DISTINCT CustomerID) AS active_customers
    FROM customer_activity
    GROUP BY
        cohort_month,
        cohort_month_number
),

cohort_with_size AS (
    SELECT
        cohort_month,
        cohort_month_number,
        active_customers,
        FIRST_VALUE(active_customers) OVER (
            PARTITION BY cohort_month
            ORDER BY cohort_month_number
        ) AS cohort_size
    FROM cohort_activity
)

SELECT
    cohort_month,
    cohort_month_number,
    active_customers,
    cohort_size,
    ROUND(
        active_customers / cohort_size * 100,
        2
    ) AS retention_pct
FROM cohort_with_size
ORDER BY
    cohort_month,
    cohort_month_number;


-- ------------------------------------------------------------
-- 8. Validate Month 0 customer counts
-- ------------------------------------------------------------
-- This is a separate validation query.
-- It directly counts customers whose purchase_month is equal
-- to their cohort_month.
--
-- These customers are the original/acquired customers
-- for each cohort.

WITH customer_first_purchase AS (
    SELECT
        CustomerID,
        DATE_FORMAT(MIN(InvoiceDate), '%Y-%m-01') AS cohort_month
    FROM retail_clean
    GROUP BY CustomerID
),

customer_activity AS (
    SELECT DISTINCT
        r.CustomerID,
        c.cohort_month,
        DATE_FORMAT(r.InvoiceDate, '%Y-%m-01') AS purchase_month
    FROM retail_clean r
    JOIN customer_first_purchase c
        ON r.CustomerID = c.CustomerID
)

SELECT
    cohort_month,
    COUNT(DISTINCT CustomerID) AS month_0_customers
FROM customer_activity
WHERE purchase_month = cohort_month
GROUP BY cohort_month
ORDER BY cohort_month;


-- ------------------------------------------------------------
-- 9. Create final cohort retention table
-- ------------------------------------------------------------
-- This table stores the final cohort retention analysis
-- for use in later analysis / Power BI.

CREATE TABLE cohort_retention AS

WITH customer_first_purchase AS (
    SELECT
        CustomerID,
        DATE_FORMAT(
            MIN(InvoiceDate),
            '%Y-%m-01'
        ) AS cohort_month
    FROM retail_clean
    GROUP BY CustomerID
),

customer_activity AS (
    SELECT DISTINCT
        r.CustomerID,
        c.cohort_month,
        DATE_FORMAT(
            r.InvoiceDate,
            '%Y-%m-01'
        ) AS purchase_month
    FROM retail_clean r
    JOIN customer_first_purchase c
        ON r.CustomerID = c.CustomerID
),

cohort_activity AS (
    SELECT
        cohort_month,
        TIMESTAMPDIFF(
            MONTH,
            cohort_month,
            purchase_month
        ) AS cohort_month_number,
        COUNT(DISTINCT CustomerID) AS active_customers
    FROM customer_activity
    GROUP BY
        cohort_month,
        cohort_month_number
),

cohort_with_size AS (
    SELECT
        cohort_month,
        cohort_month_number,
        active_customers,
        FIRST_VALUE(active_customers) OVER (
            PARTITION BY cohort_month
            ORDER BY cohort_month_number
        ) AS cohort_size
    FROM cohort_activity
)

SELECT
    cohort_month,
    cohort_month_number,
    active_customers,
    cohort_size,
    ROUND(
        active_customers / cohort_size * 100,
        2
    ) AS retention_pct
FROM cohort_with_size;


-- ------------------------------------------------------------
-- 10. View final cohort retention table
-- ------------------------------------------------------------

SELECT *
FROM cohort_retention
ORDER BY cohort_month, cohort_month_number;