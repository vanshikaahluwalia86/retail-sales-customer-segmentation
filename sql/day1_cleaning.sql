-- =========================================================
-- RETAIL SALES AND CUSTOMER SEGMENTATION ANALYTICS
-- Day 1: Database Setup, Data Import, Cleaning & Validation
-- Dataset: UCI Online Retail II
-- =========================================================


-- =========================================================
-- 1. DATABASE SETUP
-- =========================================================

CREATE DATABASE retail_analytics;

USE retail_analytics;

-- Verify that the correct database is selected
SELECT DATABASE();


-- =========================================================
-- 2. CREATE RAW TRANSACTION TABLE
-- =========================================================

CREATE TABLE retail_raw (
    Invoice VARCHAR(20),
    StockCode VARCHAR(20),
    Description VARCHAR(255),
    Quantity INT,
    InvoiceDate DATETIME,
    Price DECIMAL(10,2),
    CustomerID VARCHAR(20),
    Country VARCHAR(100)
);


-- =========================================================
-- 3. ENABLE LOCAL FILE IMPORT
-- =========================================================

SHOW VARIABLES LIKE 'local_infile';

SET GLOBAL local_infile = 1;

SHOW VARIABLES LIKE 'local_infile';


-- =========================================================
-- 4. IMPORT RAW DATA
-- =========================================================
-- The LOAD DATA LOCAL INFILE command was executed through
-- the MySQL Terminal client because MySQL Workbench rejected
-- the local file request during import.
--
-- Both yearly CSV files were imported into the same
-- retail_raw table.


-- 2009-2010 data
-- ---------------------------------------------------------
-- LOAD DATA LOCAL INFILE
-- '/Users/vanshikaahluwalia/retail-sales-customer-segmentation/data/raw/online_retail_2009_2010.csv'
-- INTO TABLE retail_raw
-- FIELDS TERMINATED BY ','
-- ENCLOSED BY '"'
-- LINES TERMINATED BY '\n'
-- IGNORE 1 ROWS
-- (
--     Invoice,
--     StockCode,
--     Description,
--     Quantity,
--     @InvoiceDate,
--     Price,
--     CustomerID,
--     Country
-- )
-- SET InvoiceDate = STR_TO_DATE(@InvoiceDate, '%d/%m/%y %H:%i');


-- 2010-2011 data
-- ---------------------------------------------------------
-- LOAD DATA LOCAL INFILE
-- '/Users/vanshikaahluwalia/retail-sales-customer-segmentation/data/raw/online_retail_2010_2011.csv'
-- INTO TABLE retail_raw
-- FIELDS TERMINATED BY ','
-- ENCLOSED BY '"'
-- LINES TERMINATED BY '\n'
-- IGNORE 1 ROWS
-- (
--     Invoice,
--     StockCode,
--     Description,
--     Quantity,
--     @InvoiceDate,
--     Price,
--     CustomerID,
--     Country
-- )
-- SET InvoiceDate = STR_TO_DATE(@InvoiceDate, '%d/%m/%y %H:%i');


-- =========================================================
-- 5. INITIAL DATA INSPECTION
-- =========================================================

USE retail_analytics;

-- Preview imported transactions
SELECT *
FROM retail_raw
LIMIT 20;


-- Check total number of imported rows
SELECT COUNT(*) AS total_rows
FROM retail_raw;


-- Check date coverage
SELECT
    MIN(InvoiceDate) AS earliest_date,
    MAX(InvoiceDate) AS latest_date
FROM retail_raw;


-- =========================================================
-- 6. NULL / MISSING VALUE CHECK
-- =========================================================

SELECT
    COUNT(*) AS total_rows,
    COUNT(Invoice) AS invoice_present,
    COUNT(StockCode) AS stockcode_present,
    COUNT(Description) AS description_present,
    COUNT(Quantity) AS quantity_present,
    COUNT(InvoiceDate) AS date_present,
    COUNT(Price) AS price_present,
    COUNT(CustomerID) AS customer_present,
    COUNT(Country) AS country_present
FROM retail_raw;


-- Specifically check missing Customer IDs
SELECT COUNT(*) AS missing_customer_ids
FROM retail_raw
WHERE CustomerID IS NULL;


-- =========================================================
-- 7. CANCELLATION CHECK
-- =========================================================

-- In the Online Retail II dataset, invoices beginning
-- with 'C' represent cancellations.

SELECT COUNT(*) AS cancellation_rows
FROM retail_raw
WHERE Invoice LIKE 'C%';


-- Inspect cancellation examples
SELECT *
FROM retail_raw
WHERE Invoice LIKE 'C%'
LIMIT 10;


-- =========================================================
-- 8. NEGATIVE QUANTITY CHECK
-- =========================================================

SELECT COUNT(*) AS negative_quantity_rows
FROM retail_raw
WHERE Quantity < 0;


-- Check quantity range
SELECT
    MIN(Quantity) AS minimum_quantity,
    MAX(Quantity) AS maximum_quantity
FROM retail_raw;


-- =========================================================
-- 9. INVALID PRICE CHECK
-- =========================================================

SELECT COUNT(*) AS non_positive_prices
FROM retail_raw
WHERE Price <= 0;


-- Inspect examples
SELECT *
FROM retail_raw
WHERE Price <= 0
LIMIT 20;


-- =========================================================
-- 10. DUPLICATE CHECK
-- =========================================================

SELECT
    Invoice,
    StockCode,
    Description,
    Quantity,
    InvoiceDate,
    Price,
    CustomerID,
    Country,
    COUNT(*) AS duplicate_count
FROM retail_raw
GROUP BY
    Invoice,
    StockCode,
    Description,
    Quantity,
    InvoiceDate,
    Price,
    CustomerID,
    Country
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC
LIMIT 20;


-- =========================================================
-- 11. CREATE CLEAN TRANSACTION TABLE
-- =========================================================
-- Cleaning rules:
-- 1. Remove rows without a CustomerID
-- 2. Remove cancellation invoices
-- 3. Remove non-positive quantities
-- 4. Remove non-positive prices
-- 5. Remove exact duplicate rows using DISTINCT
-- 6. Calculate transaction-level revenue
--
-- Revenue = Quantity × Price

CREATE TABLE retail_clean AS
SELECT DISTINCT
    TRIM(Invoice) AS Invoice,
    TRIM(StockCode) AS StockCode,
    TRIM(Description) AS Description,
    Quantity,
    InvoiceDate,
    Price,
    TRIM(CustomerID) AS CustomerID,
    TRIM(Country) AS Country,
    Quantity * Price AS Revenue
FROM retail_raw
WHERE
    CustomerID IS NOT NULL
    AND Invoice NOT LIKE 'C%'
    AND Quantity > 0
    AND Price > 0;


-- =========================================================
-- 12. VERIFY CLEANED DATA
-- =========================================================

-- Number of rows after cleaning
SELECT COUNT(*) AS clean_rows
FROM retail_clean;


-- Preview cleaned transactions
SELECT *
FROM retail_clean
LIMIT 10;


-- Confirm that invalid records were removed
SELECT
    SUM(CustomerID IS NULL) AS null_customers,
    SUM(Invoice LIKE 'C%') AS cancellations,
    SUM(Quantity <= 0) AS invalid_quantities,
    SUM(Price <= 0) AS invalid_prices
FROM retail_clean;


-- =========================================================
-- 13. REVENUE VALIDATION
-- =========================================================

SELECT
    SUM(Revenue) AS total_revenue
FROM retail_clean;


-- =========================================================
-- 14. DATE VALIDATION
-- =========================================================

SELECT
    MIN(InvoiceDate) AS first_transaction,
    MAX(InvoiceDate) AS last_transaction
FROM retail_clean;


-- =========================================================
-- 15. YEAR-LEVEL VALIDATION
-- =========================================================

SELECT
    YEAR(InvoiceDate) AS year,
    COUNT(*) AS transaction_lines,
    SUM(Revenue) AS revenue
FROM retail_clean
GROUP BY YEAR(InvoiceDate)
ORDER BY year;


-- =========================================================
-- 16. TOP COUNTRIES — INITIAL DATA CHECK
-- =========================================================

SELECT
    Country,
    COUNT(*) AS transaction_lines,
    SUM(Revenue) AS revenue
FROM retail_clean
GROUP BY Country
ORDER BY revenue DESC
LIMIT 10;


-- =========================================================
-- 17. CUSTOMER / ORDER / PRODUCT COUNTS
-- =========================================================

SELECT
    COUNT(DISTINCT CustomerID) AS unique_customers
FROM retail_clean;


SELECT
    COUNT(DISTINCT Invoice) AS unique_invoices
FROM retail_clean;


-- =========================================================
-- 18. ADD INDEXES FOR ANALYTICAL QUERIES
-- =========================================================
-- Indexes improve lookup and filtering performance,
-- especially for CustomerID, dates and products.

ALTER TABLE retail_clean
ADD INDEX idx_customer (CustomerID),
ADD INDEX idx_invoice_date (InvoiceDate),
ADD INDEX idx_stockcode (StockCode);


-- =========================================================
-- 19. FINAL DAY 1 VALIDATION
-- =========================================================

SELECT
    COUNT(*) AS clean_rows,
    COUNT(DISTINCT Invoice) AS orders,
    COUNT(DISTINCT CustomerID) AS customers,
    COUNT(DISTINCT StockCode) AS products,
    ROUND(SUM(Revenue), 2) AS total_revenue,
    MIN(InvoiceDate) AS first_date,
    MAX(InvoiceDate) AS last_date
FROM retail_clean;

