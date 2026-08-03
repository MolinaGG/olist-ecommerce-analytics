-- ============================================================================
-- Olist E-Commerce Analytics
-- 01_schema/create_tables.sql
--
-- Purpose : Lean, optimized relational schema (7 core tables) for the Olist
--           Brazilian E-Commerce Public Dataset (Kaggle).
--
-- Notes   :
--   - `geolocation` is intentionally NOT a core table. It is only used at
--     staging time (02_staging) to enrich zip_code_prefix -> city/state,
--     then discarded. This keeps the operational schema lean.
--   - `products.product_category_name_english` has no source column in the
--     raw `olist_products_dataset.csv`. It will be populated in the staging
--     step via a join against `product_category_name_translation.csv`
--     (imported into a temporary table, then dropped). Left NULL-able here.
--   - Column names intentionally mirror the original Kaggle CSV headers
--     wherever possible, so the MySQL Workbench "Table Data Import Wizard"
--     can map fields with zero manual renaming.
-- ============================================================================

CREATE DATABASE IF NOT EXISTS olist_ecommerce
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE olist_ecommerce;

-- Drop in FK-safe order (children first) in case of re-run during development
DROP TABLE IF EXISTS order_reviews;
DROP TABLE IF EXISTS order_payments;
DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS sellers;
DROP TABLE IF EXISTS customers;

-- ----------------------------------------------------------------------------
-- 1. CUSTOMERS
-- ----------------------------------------------------------------------------
CREATE TABLE customers (
    customer_id            VARCHAR(32)     NOT NULL,
    customer_unique_id     VARCHAR(32)     NOT NULL,
    customer_zip_code_prefix VARCHAR(5)    NULL,
    customer_city           VARCHAR(100)   NULL,
    customer_state          CHAR(2)        NULL,
    PRIMARY KEY (customer_id),
    INDEX idx_customers_state (customer_state)
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- 2. SELLERS
-- ----------------------------------------------------------------------------
CREATE TABLE sellers (
    seller_id               VARCHAR(32)    NOT NULL,
    seller_zip_code_prefix  VARCHAR(5)     NULL,
    seller_city             VARCHAR(100)   NULL,
    seller_state             CHAR(2)       NULL,
    PRIMARY KEY (seller_id),
    INDEX idx_sellers_state (seller_state)
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- 3. PRODUCTS  (merged with product_category_name_translation)
-- ----------------------------------------------------------------------------
CREATE TABLE products (
    product_id                     VARCHAR(32)   NOT NULL,
    product_category_name          VARCHAR(100)  NULL,
    product_category_name_english  VARCHAR(100)  NULL,  -- populated in 02_staging
    product_weight_g               INT           NULL,
    product_length_cm              INT           NULL,
    product_height_cm              INT           NULL,
    product_width_cm               INT           NULL,
    PRIMARY KEY (product_id),
    INDEX idx_products_category_en (product_category_name_english)
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- 4. ORDERS
-- ----------------------------------------------------------------------------
CREATE TABLE orders (
    order_id                       VARCHAR(32)  NOT NULL,
    customer_id                    VARCHAR(32)  NOT NULL,
    order_status                   VARCHAR(20)  NOT NULL,
    order_purchase_timestamp       DATETIME     NOT NULL,
    order_approved_at              DATETIME     NULL,
    order_delivered_carrier_date   DATETIME     NULL,
    order_delivered_customer_date  DATETIME     NULL,
    order_estimated_delivery_date  DATETIME     NULL,
    PRIMARY KEY (order_id),
    INDEX idx_orders_customer (customer_id),
    INDEX idx_orders_status (order_status),
    INDEX idx_orders_purchase_ts (order_purchase_timestamp),
    CONSTRAINT fk_orders_customer
        FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- 5. ORDER_ITEMS  (grain: one row per item within an order)
-- ----------------------------------------------------------------------------
CREATE TABLE order_items (
    order_id            VARCHAR(32)   NOT NULL,
    order_item_id        INT          NOT NULL,
    product_id           VARCHAR(32)  NOT NULL,
    seller_id             VARCHAR(32) NOT NULL,
    shipping_limit_date    DATETIME   NULL,
    price                 DECIMAL(10,2) NOT NULL,
    freight_value          DECIMAL(10,2) NOT NULL,
    PRIMARY KEY (order_id, order_item_id),
    INDEX idx_order_items_product (product_id),
    INDEX idx_order_items_seller (seller_id),
    CONSTRAINT fk_order_items_order
        FOREIGN KEY (order_id) REFERENCES orders(order_id),
    CONSTRAINT fk_order_items_product
        FOREIGN KEY (product_id) REFERENCES products(product_id),
    CONSTRAINT fk_order_items_seller
        FOREIGN KEY (seller_id) REFERENCES sellers(seller_id)
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- 6. ORDER_PAYMENTS  (grain: one row per payment installment/method per order)
-- ----------------------------------------------------------------------------
CREATE TABLE order_payments (
    order_id               VARCHAR(32)  NOT NULL,
    payment_sequential      INT         NOT NULL,
    payment_type            VARCHAR(20) NOT NULL,
    payment_installments     INT        NOT NULL,
    payment_value             DECIMAL(10,2) NOT NULL,
    PRIMARY KEY (order_id, payment_sequential),
    CONSTRAINT fk_order_payments_order
        FOREIGN KEY (order_id) REFERENCES orders(order_id)
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- 7. ORDER_REVIEWS  (grain: one row per review)
-- ----------------------------------------------------------------------------
CREATE TABLE order_reviews (
    review_id               VARCHAR(32)  NOT NULL,
    order_id                VARCHAR(32)  NOT NULL,
    review_score             INT         NOT NULL,
    review_comment_title      VARCHAR(255) NULL,
    review_creation_date       DATETIME  NULL,
    review_answer_timestamp    DATETIME  NULL,
    PRIMARY KEY (review_id),
    INDEX idx_reviews_order (order_id),
    CONSTRAINT fk_order_reviews_order
        FOREIGN KEY (order_id) REFERENCES orders(order_id)
) ENGINE=InnoDB;

-- ============================================================================
-- End of 01_schema/create_tables.sql
-- Next step: 02_staging/load_data.sql (import CSVs + populate
-- product_category_name_english + data quality checks)
-- ============================================================================
