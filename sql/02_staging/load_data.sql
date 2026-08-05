-- ============================================================================
-- Olist E-Commerce Analytics
-- 02_staging/load_data.sql  (LOAD DATA LOCAL INFILE version)
--
-- Prerequisite:
--   - local_infile = ON (server GLOBAL + client OPT_LOCAL_INFILE=1)
--   - Raw Kaggle CSVs present in the /data folder of this repo
--
-- IMPORTANT: adjust the file paths below to match your local machine if your
-- repo is not at D:/Projetos ETL/Olist_retail/data/
-- ============================================================================

USE olist_ecommerce;

-- ----------------------------------------------------------------------------
-- 0. Clean slate (safe to re-run). Children first, then parents.
-- ----------------------------------------------------------------------------
SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE order_reviews;
TRUNCATE TABLE order_payments;
TRUNCATE TABLE order_items;
TRUNCATE TABLE orders;
TRUNCATE TABLE products;
TRUNCATE TABLE sellers;
TRUNCATE TABLE customers;
SET FOREIGN_KEY_CHECKS = 1;

-- ----------------------------------------------------------------------------
-- 1. CUSTOMERS
-- ----------------------------------------------------------------------------
LOAD DATA LOCAL INFILE 'D:/Projetos ETL/Olist_retail/data/olist_customers_dataset.csv'
INTO TABLE customers
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(customer_id, customer_unique_id, customer_zip_code_prefix, customer_city, customer_state);

-- ----------------------------------------------------------------------------
-- 2. SELLERS
-- ----------------------------------------------------------------------------
LOAD DATA LOCAL INFILE 'D:/Projetos ETL/Olist_retail/data/olist_sellers_dataset.csv'
INTO TABLE sellers
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(seller_id, seller_zip_code_prefix, seller_city, seller_state);

-- ----------------------------------------------------------------------------
-- 3. PRODUCTS (CSV has 3 extra columns we don't keep: name/description length,
-- photos qty -- captured into throwaway user variables and discarded)
-- ----------------------------------------------------------------------------
LOAD DATA LOCAL INFILE 'D:/Projetos ETL/Olist_retail/data/olist_products_dataset.csv'
INTO TABLE products
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(product_id, product_category_name, @name_lenght, @description_lenght, @photos_qty,
 @weight_g, @length_cm, @height_cm, @width_cm)
SET
    product_weight_g  = NULLIF(@weight_g, ''),
    product_length_cm = NULLIF(@length_cm, ''),
    product_height_cm = NULLIF(@height_cm, ''),
    product_width_cm  = NULLIF(@width_cm, '');

-- ----------------------------------------------------------------------------
-- 4. ORDERS (blank date fields converted to NULL, not '0000-00-00')
-- ----------------------------------------------------------------------------
LOAD DATA LOCAL INFILE 'D:/Projetos ETL/Olist_retail/data/olist_orders_dataset.csv'
INTO TABLE orders
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(order_id, customer_id, order_status, @purchase_ts, @approved_at,
 @delivered_carrier_date, @delivered_customer_date, @estimated_delivery_date)
SET
    order_purchase_timestamp      = NULLIF(@purchase_ts, ''),
    order_approved_at             = NULLIF(@approved_at, ''),
    order_delivered_carrier_date  = NULLIF(@delivered_carrier_date, ''),
    order_delivered_customer_date = NULLIF(@delivered_customer_date, ''),
    order_estimated_delivery_date = NULLIF(@estimated_delivery_date, '');

-- ----------------------------------------------------------------------------
-- 5. ORDER_ITEMS
-- ----------------------------------------------------------------------------
LOAD DATA LOCAL INFILE 'D:/Projetos ETL/Olist_retail/data/olist_order_items_dataset.csv'
INTO TABLE order_items
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(order_id, order_item_id, product_id, seller_id, @shipping_limit_date, price, freight_value)
SET shipping_limit_date = NULLIF(@shipping_limit_date, '');

-- ----------------------------------------------------------------------------
-- 6. ORDER_PAYMENTS
-- ----------------------------------------------------------------------------
LOAD DATA LOCAL INFILE 'D:/Projetos ETL/Olist_retail/data/olist_order_payments_dataset.csv'
INTO TABLE order_payments
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(order_id, payment_sequential, payment_type, payment_installments, payment_value);

-- ----------------------------------------------------------------------------
-- 7. ORDER_REVIEWS (CSV has review_comment_message, which we don't keep --
-- captured into a throwaway variable and discarded)
-- ----------------------------------------------------------------------------
LOAD DATA LOCAL INFILE 'D:/Projetos ETL/Olist_retail/data/olist_order_reviews_dataset.csv'
INTO TABLE order_reviews
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(review_id, order_id, review_score, @comment_title, @comment_message, @creation_date, @answer_ts)
SET
    review_comment_title    = NULLIF(@comment_title, ''),
    review_creation_date    = NULLIF(@creation_date, ''),
    review_answer_timestamp = NULLIF(@answer_ts, '');

-- ----------------------------------------------------------------------------
-- 8. CATEGORY TRANSLATION (temporary staging table)
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS category_translation_staging;
CREATE TABLE category_translation_staging (
    product_category_name          VARCHAR(100),
    product_category_name_english  VARCHAR(100)
);

LOAD DATA LOCAL INFILE 'D:/Projetos ETL/Olist_retail/data/product_category_name_translation.csv'
INTO TABLE category_translation_staging
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(product_category_name, product_category_name_english);

-- Populate the English category name on products
-- (SQL_SAFE_UPDATES disabled temporarily: this UPDATE...JOIN has no WHERE on a
-- key column, which Workbench's Safe Update Mode blocks by default -- Error 1175)
SET SQL_SAFE_UPDATES = 0;

UPDATE products p
JOIN category_translation_staging t
    ON p.product_category_name = t.product_category_name
SET p.product_category_name_english = t.product_category_name_english;

SET SQL_SAFE_UPDATES = 1;

DROP TABLE IF EXISTS category_translation_staging;

-- ----------------------------------------------------------------------------
-- 9. DATA QUALITY CHECKS
-- ----------------------------------------------------------------------------

-- 9.1 Row counts per table (expected ~ customers 99441, sellers 3095,
-- products 32951, orders 99441, order_items 112650, order_payments 103886,
-- order_reviews 99224 -- exact figures vary slightly by Kaggle version)
SELECT 'customers' AS table_name, COUNT(*) AS row_count FROM customers
UNION ALL SELECT 'sellers', COUNT(*) FROM sellers
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'orders', COUNT(*) FROM orders
UNION ALL SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL SELECT 'order_payments', COUNT(*) FROM order_payments
UNION ALL SELECT 'order_reviews', COUNT(*) FROM order_reviews;

-- 9.2 Products still missing an English category name
SELECT COUNT(*) AS products_without_english_category
FROM products
WHERE product_category_name_english IS NULL;

-- 9.3 Orders marked 'delivered' but missing a delivery date
SELECT COUNT(*) AS delivered_orders_missing_delivery_date
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NULL;

-- 9.4 Order items with invalid price/freight
SELECT COUNT(*) AS invalid_price_or_freight
FROM order_items
WHERE price <= 0 OR freight_value < 0;

-- 9.5 Reviews with an out-of-range score
SELECT COUNT(*) AS invalid_review_scores
FROM order_reviews
WHERE review_score NOT BETWEEN 1 AND 5;

-- 9.6 Orphan order_items (should be 0, FK-enforced)
SELECT COUNT(*) AS orphan_order_items
FROM order_items oi
LEFT JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_id IS NULL;

-- 9.7 Order status distribution
SELECT order_status, COUNT(*) AS total
FROM orders
GROUP BY order_status
ORDER BY total DESC;

-- ============================================================================
-- End of 02_staging/load_data.sql
-- Next step: 03_views/vw_supplier_performance.sql (CTEs + window functions)
-- ============================================================================