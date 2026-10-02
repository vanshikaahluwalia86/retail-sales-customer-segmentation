-- ============================================================
-- PHASE 2: BUSINESS ANALYSIS
-- Project: Retail Sales and Customer Segmentation Analytics
-- Purpose: Analyze revenue, products, countries, and customers
-- ============================================================


-- ============================================================
-- 1. CHECK CLEAN DATASET SIZE
-- ============================================================

-- Count the total number of rows in the cleaned dataset.
SELECT COUNT(*) AS clean_rows
FROM retail_clean;


-- ============================================================
-- 2. MONTHLY REVENUE
-- ============================================================

-- Calculate total revenue for each year and month.
-- Revenue is calculated at the transaction-row level and
-- aggregated to the monthly level.
SELECT
    YEAR(InvoiceDate) AS year,
    MONTH(InvoiceDate) AS month,
    SUM(Revenue) AS monthly_revenue
FROM retail_clean
GROUP BY
    YEAR(InvoiceDate),
    MONTH(InvoiceDate)
ORDER BY
    year,
    month;


-- Format the month as YYYY-MM-01 for easier time-series analysis.
SELECT
    DATE_FORMAT(InvoiceDate, '%Y-%m-01') AS month,
    ROUND(SUM(Revenue), 2) AS monthly_revenue
FROM retail_clean
GROUP BY DATE_FORMAT(InvoiceDate, '%Y-%m-01')
ORDER BY month;


-- ============================================================
-- 3. MONTH-OVER-MONTH REVENUE ANALYSIS
-- ============================================================

-- Create a monthly revenue table using a CTE.
WITH monthly_revenue AS (
    SELECT
        DATE_FORMAT(InvoiceDate, '%Y-%m-01') AS month,
        SUM(Revenue) AS revenue
    FROM retail_clean
    GROUP BY DATE_FORMAT(InvoiceDate, '%Y-%m-01')
)

-- LAG() gets the revenue from the previous month.
SELECT
    month,
    ROUND(revenue, 2) AS revenue,
    ROUND(
        LAG(revenue) OVER (ORDER BY month),
        2
    ) AS previous_month_revenue
FROM monthly_revenue
ORDER BY month;


-- Calculate the percentage growth in revenue compared
-- with the previous month.
WITH monthly_revenue AS (
    SELECT
        DATE_FORMAT(InvoiceDate, '%Y-%m-01') AS month,
        SUM(Revenue) AS revenue
    FROM retail_clean
    GROUP BY DATE_FORMAT(InvoiceDate, '%Y-%m-01')
),

revenue_with_previous AS (
    SELECT
        month,
        revenue,
        LAG(revenue) OVER (ORDER BY month) AS previous_revenue
    FROM monthly_revenue
)

SELECT
    month,
    ROUND(revenue, 2) AS revenue,
    ROUND(previous_revenue, 2) AS previous_revenue,
    ROUND(
        ((revenue - previous_revenue) / previous_revenue) * 100,
        2
    ) AS revenue_growth_pct
FROM revenue_with_previous
ORDER BY month;


-- ============================================================
-- 4. TOP PRODUCTS BY REVENUE
-- ============================================================

-- Identify the top 10 products generating the highest revenue.
SELECT
    StockCode,
    Description,
    SUM(Quantity) AS units_sold,
    ROUND(SUM(Revenue), 2) AS revenue
FROM retail_clean
GROUP BY
    StockCode,
    Description
ORDER BY revenue DESC
LIMIT 10;


-- ============================================================
-- 5. TOP PRODUCTS BY UNITS SOLD
-- ============================================================

-- Identify the top 10 products based on quantity sold.
SELECT
    StockCode,
    Description,
    SUM(Quantity) AS units_sold,
    ROUND(SUM(Revenue), 2) AS revenue
FROM retail_clean
GROUP BY
    StockCode,
    Description
ORDER BY units_sold DESC
LIMIT 10;


-- ============================================================
-- 6. TOP COUNTRIES BY REVENUE
-- ============================================================

-- Compare countries based on orders, customers, and revenue.
SELECT
    Country,
    COUNT(DISTINCT Invoice) AS orders,
    COUNT(DISTINCT CustomerID) AS customers,
    ROUND(SUM(Revenue), 2) AS revenue
FROM retail_clean
GROUP BY Country
ORDER BY revenue DESC
LIMIT 10;


-- ============================================================
-- 7. COUNTRY REVENUE SHARE
-- ============================================================

-- Calculate each country's percentage contribution
-- to the total company revenue.
SELECT
    Country,
    ROUND(SUM(Revenue), 2) AS revenue,
    ROUND(
        SUM(Revenue) /
        (SELECT SUM(Revenue) FROM retail_clean) * 100,
        2
    ) AS revenue_share_pct
FROM retail_clean
GROUP BY Country
ORDER BY revenue DESC
LIMIT 10;


-- ============================================================
-- 8. CUSTOMER-LEVEL REVENUE
-- ============================================================

-- Calculate revenue, orders, and units purchased
-- for each customer.
SELECT
    CustomerID,
    COUNT(DISTINCT Invoice) AS orders,
    SUM(Quantity) AS units_purchased,
    ROUND(SUM(Revenue), 2) AS total_revenue
FROM retail_clean
GROUP BY CustomerID
ORDER BY total_revenue DESC
LIMIT 20;


-- ============================================================
-- 9. AVERAGE ORDER VALUE (AOV)
-- ============================================================

-- AOV = Total Revenue / Number of Orders.
-- An order is represented by a distinct Invoice.
-- AOV measures the average amount spent per order.
SELECT
    ROUND(SUM(Revenue), 2) AS total_revenue,
    COUNT(DISTINCT Invoice) AS total_orders,
    ROUND(
        SUM(Revenue) / COUNT(DISTINCT Invoice),
        2
    ) AS average_order_value
FROM retail_clean;


-- ============================================================
-- 10. CUSTOMER FIRST PURCHASE DATE
-- ============================================================

-- Find the first purchase date for every customer.
-- This is later used to classify customers as New or Repeat.
SELECT
    CustomerID,
    MIN(InvoiceDate) AS first_purchase_date
FROM retail_clean
GROUP BY CustomerID
ORDER BY first_purchase_date
LIMIT 20;


-- Find the first purchase month for every customer.
WITH customer_first_purchase AS (
    SELECT
        CustomerID,
        MIN(DATE_FORMAT(InvoiceDate, '%Y-%m-01')) AS first_purchase_month
    FROM retail_clean
    GROUP BY CustomerID
)

SELECT *
FROM customer_first_purchase
ORDER BY first_purchase_month
LIMIT 20;


-- ============================================================
-- 11. NEW VS REPEAT CUSTOMERS
-- ============================================================

-- A customer is classified as:
-- New    -> purchase occurs in their first purchase month
-- Repeat -> purchase occurs after their first purchase month
WITH customer_first_purchase AS (
    SELECT
        CustomerID,
        MIN(DATE_FORMAT(InvoiceDate, '%Y-%m-01')) AS first_purchase_month
    FROM retail_clean
    GROUP BY CustomerID
)

SELECT
    DATE_FORMAT(r.InvoiceDate, '%Y-%m-01') AS purchase_month,
    CASE
        WHEN DATE_FORMAT(r.InvoiceDate, '%Y-%m-01')
             = c.first_purchase_month
        THEN 'New'
        ELSE 'Repeat'
    END AS customer_type,
    COUNT(DISTINCT r.CustomerID) AS customers,
    ROUND(SUM(r.Revenue), 2) AS revenue
FROM retail_clean r
JOIN customer_first_purchase c
    ON r.CustomerID = c.CustomerID
GROUP BY
    purchase_month,
    customer_type
ORDER BY
    purchase_month,
    customer_type;


-- Count the number of unique customers classified as
-- New or Repeat.
WITH customer_first_purchase AS (
    SELECT
        CustomerID,
        MIN(DATE_FORMAT(InvoiceDate, '%Y-%m-01')) AS first_purchase_month
    FROM retail_clean
    GROUP BY CustomerID
),

classified AS (
    SELECT
        r.CustomerID,
        DATE_FORMAT(r.InvoiceDate, '%Y-%m-01') AS purchase_month,
        c.first_purchase_month,
        CASE
            WHEN DATE_FORMAT(r.InvoiceDate, '%Y-%m-01')
                 = c.first_purchase_month
            THEN 'New'
            ELSE 'Repeat'
        END AS customer_type
    FROM retail_clean r
    JOIN customer_first_purchase c
        ON r.CustomerID = c.CustomerID
)

SELECT
    customer_type,
    COUNT(DISTINCT CustomerID) AS customers
FROM classified
GROUP BY customer_type;


-- ============================================================
-- 12. REPEAT PURCHASE RATE
-- ============================================================

-- First calculate the number of orders for each customer.
WITH customer_orders AS (
    SELECT
        CustomerID,
        COUNT(DISTINCT Invoice) AS order_count
    FROM retail_clean
    GROUP BY CustomerID
)

-- A repeat customer is a customer with more than one order.
-- Repeat Purchase Rate =
-- Repeat Customers / Total Customers × 100
SELECT
    COUNT(*) AS total_customers,
    SUM(order_count > 1) AS repeat_customers,
    ROUND(
        SUM(order_count > 1) / COUNT(*) * 100,
        2
    ) AS repeat_purchase_rate_pct
FROM customer_orders;


-- ============================================================
-- 13. CUSTOMER ORDER FREQUENCY
-- ============================================================

-- Identify customers with the highest number of orders.
SELECT
    CustomerID,
    COUNT(DISTINCT Invoice) AS order_count,
    ROUND(SUM(Revenue), 2) AS revenue
FROM retail_clean
GROUP BY CustomerID
ORDER BY order_count DESC
LIMIT 20;


-- ============================================================
-- 14. CREATE CUSTOMER SUMMARY TABLE
-- ============================================================

-- Create one row per customer containing key customer metrics.
-- This table will be reused later for customer segmentation.
CREATE TABLE customer_summary AS
SELECT
    CustomerID,
    MIN(InvoiceDate) AS first_purchase_date,
    MAX(InvoiceDate) AS last_purchase_date,
    COUNT(DISTINCT Invoice) AS order_count,
    SUM(Quantity) AS total_units,
    ROUND(SUM(Revenue), 2) AS total_revenue,
    ROUND(
        SUM(Revenue) / COUNT(DISTINCT Invoice),
        2
    ) AS average_order_value
FROM retail_clean
GROUP BY CustomerID;


-- Check the newly created customer summary table.
SELECT *
FROM customer_summary
LIMIT 10;


-- ============================================================
-- 15. CUSTOMER REVENUE BANDS
-- ============================================================

-- Group customers into revenue bands based on their
-- total lifetime revenue.
SELECT
    CASE
        WHEN total_revenue < 100 THEN 'Under 100'
        WHEN total_revenue < 500 THEN '100-499'
        WHEN total_revenue < 1000 THEN '500-999'
        WHEN total_revenue < 5000 THEN '1000-4999'
        ELSE '5000+'
    END AS revenue_band,
    COUNT(*) AS customers,
    ROUND(SUM(total_revenue), 2) AS revenue
FROM customer_summary
GROUP BY
    CASE
        WHEN total_revenue < 100 THEN 'Under 100'
        WHEN total_revenue < 500 THEN '100-499'
        WHEN total_revenue < 1000 THEN '500-999'
        WHEN total_revenue < 5000 THEN '1000-4999'
        ELSE '5000+'
    END
ORDER BY revenue_band;


-- ============================================================
-- END OF DAY 2 BUSINESS ANALYSIS
-- ============================================================