--SUPABASE SET-UP  (Part 1 of SQL Phase)
--November 16, 2025
/**
Workflow for set-up:

create tables : events_raw, customers_raw, products_raw
↓ 
-------------------------------------------------------------
events_raw: fill in the blanks  
-------------------------------------------------------------
↓ 
add discount_group field to have no blanks
↓
add year_month  
↓
check orders that proceeded to invoice
↓
add final_net_revenue_usd
↓
zero out returns in final_net_revenue_usd  
↓
create view: events_final
↓
-------------------------------------------------------------
customers_raw: revise column names for easier joins
-------------------------------------------------------------
↓
fill in the blanks
↓
rename common columns with events for final view join   
↓
add_second_purchase_date
↓
create view: customers_final
↓
-------------------------------------------------------------
products_raw: transform one column with foreign font
-------------------------------------------------------------
↓ 
create views: events_final, customers_final, products_final
↓ 
check purchase cycles from customers_final and events_final
↓ 
create view: combined 
↓ 
export as csv 

Proceed to Part 2 of SQL phase 
**/

------------
Check columns
-------------
-- Column list for combined
SELECT column_name
FROM information_schema.columns
WHERE table_name = 'combined'
ORDER BY ordinal_position;

-- Check unique event ids
SELECT event_id,
count(distinct(event_id))
FROM events_raw
GROUP BY event_id; -- 48000 rows


--------
--events    
--------
-- Fill in the blanks in region column.
UPDATE events_raw
SET region_customers = 'NAm'
WHERE (region IS NULL OR region_customers = '')
  AND country IN ('United States', 'Canada');



-- add discount_group field to have no blanks
ALTER TABLE events_raw
ADD COLUMN discount_group text;

UPDATE events_raw
SET discount_group =
    CASE
        WHEN discount_code = 'N/A' THEN 'Full Price'
        ELSE discount_code -- value for rows that are NOT 'N/A'
    END;



-- add year_month for trended visuals later
ALTER TABLE events_raw
ADD COLUMN year_month date;

UPDATE events_raw
SET year_month = DATE_TRUNC('month', event_date)::date;



-- Which orders proceed to invoices
-- Result:  119 rows
-- This confirms that invoices are the right metric for net_revenue and not both orders and invoices


CREATE OR REPLACE VIEW orders_proceed AS 

WITH orders AS (
    SELECT customer_id, product_id, event_date,
           quantity, unit_price_local, net_revenue_usd, is_refunded
    FROM events_final_new
    WHERE event_type = 'order'
),
invoices AS (
    SELECT customer_id, product_id, event_date,
           quantity, unit_price_local, net_revenue_usd, is_refunded
    FROM events_final_new
    WHERE event_type = 'invoice'
)
SELECT
    o.customer_id,
    o.product_id,
    o.event_date AS order_date,
    i.event_date AS invoice_date,
    o.quantity,
    o.unit_price_local,
    o.net_revenue_usd,
    o.is_refunded,
	(i.event_date - o.event_date) AS invoice_lag_days
FROM orders o
LEFT JOIN invoices i
  ON o.customer_id = i.customer_id
 AND o.product_id  = i.product_id
 AND o.quantity    = i.quantity
 AND o.unit_price_local = i.unit_price_local
 AND o.net_revenue_usd  = i.net_revenue_usd
 AND o.is_refunded      = i.is_refunded
WHERE i.event_date is NOT NULL
ORDER BY o.customer_id, o.product_id
;


--SELECT * FROM orders_proceed; 
-- Result 119 rows


/**
First 5 rows
| customer_id | product_id | order_date | invoice_date | quantity | unit_price_local | net_revenue_usd | is_refunded |
| ----------- | ---------- | ---------- | ------------ | -------- | ---------------- | --------------- | ----------- |
| CUST0000002 | PROD0038   | 2025-01-20 | 2025-02-02   | 1        | 189.39           | 137.5           | false       |
| CUST0000005 | PROD0054   | 2025-01-01 | 2025-01-05   | 1        | 290              | 290             | false       |
| CUST0000071 | PROD0098   | 2024-12-18 | 2024-06-09   | 3        | 267.4            | 922.53          | false       |
| CUST0000131 | PROD0053   | 2024-09-12 | 2024-07-13   | 1        | 29               | 29              | false       |
| CUST0000144 | PROD0095   | 2025-09-10 | 2025-10-14   | 10       | 18.52            | 215.94          | false       |

Orders that proceed to invoices
**/



--------------------------
-- Completing the picture
--------------------------

-- Orders not proceed to invoices and Invoices that did not pass through orders
-- Views: orders_not_proceed, invoices_not_orders
-- Then count 

-- Orders that did not proceed to invoices
CREATE OR REPLACE VIEW orders_not_proceed AS
WITH orders AS (
    SELECT customer_id, product_id, event_date,
           quantity, unit_price_local, net_revenue_usd, is_refunded
    FROM events_final_new
    WHERE event_type = 'order'
),
invoices AS (
    SELECT customer_id, product_id, event_date,
           quantity, unit_price_local, net_revenue_usd, is_refunded
    FROM events_final_new
    WHERE event_type = 'invoice'
)
SELECT
    o.customer_id,
    o.product_id,
    o.event_date AS order_date,
    o.quantity,
    o.unit_price_local,
    o.net_revenue_usd,
    o.is_refunded
FROM orders o
LEFT JOIN invoices i
  ON o.customer_id = i.customer_id
 AND o.product_id  = i.product_id
 AND o.quantity    = i.quantity
 AND o.unit_price_local = i.unit_price_local
 AND o.net_revenue_usd  = i.net_revenue_usd
 AND o.is_refunded      = i.is_refunded
WHERE i.event_date IS NULL
;




-- Invoices that did not pass through orders
CREATE OR REPLACE VIEW invoices_not_orders AS
WITH orders AS (
    SELECT customer_id, product_id, event_date,
           quantity, unit_price_local, net_revenue_usd, is_refunded
    FROM events_final_new
    WHERE event_type = 'order'
),
invoices AS (
    SELECT customer_id, product_id, event_date,
           quantity, unit_price_local, net_revenue_usd, is_refunded
    FROM events_final_new
    WHERE event_type = 'invoice'
)
SELECT
    i.customer_id,
    i.product_id,
    i.event_date AS invoice_date,
    i.quantity,
    i.unit_price_local,
    i.net_revenue_usd,
    i.is_refunded
FROM invoices i
LEFT JOIN orders o
  ON o.customer_id = i.customer_id
 AND o.product_id  = i.product_id
 AND o.quantity    = i.quantity
 AND o.unit_price_local = i.unit_price_local
 AND o.net_revenue_usd  = i.net_revenue_usd
 AND o.is_refunded      = i.is_refunded
WHERE o.event_date IS NULL
;





-- Counts
SELECT 'orders_not_proceed' AS category, COUNT(*) AS cnt FROM orders_not_proceed
UNION ALL
SELECT 'invoices_not_orders' AS category, COUNT(*) AS cnt FROM invoices_not_orders
UNION ALL
SELECT 'orders_proceed' AS category, COUNT(*) AS cnt FROM orders_proceed
;



/**
| category            | cnt   |
| ------------------- | ----- |
| orders_not_proceed  | 33482 |
| invoices_not_orders | 14280 |
| orders_proceed      | 119   |
**/







-- Add final_net_revenue_usd to zero out returns
-- and event_type = 'invoice'

ALTER TABLE events_raw
ADD COLUMN final_net_revenue_usd float;

UPDATE events_raw
SET final_net_revenue_usd =
    CASE 
        WHEN event_type = 'invoice' AND is_refunded = FALSE 
        THEN net_revenue_usd
        ELSE 0
    END;
;


-- Check values, orders should be 0, refunds should be 0
-- If is_refunded is true, final_net_revenue_usd should be zero
SELECT net_revenue_usd,
is_refunded,
event_type,
final_net_revenue_usd
FROM events_raw
WHERE is_refunded = true
LIMIT 50;

/**
| net_revenue_usd | is_refunded | event_type | final_net_revenue_usd |
| --------------- | ----------- | ---------- | --------------------- |
| 63              | false       | invoice    | 63                    |
| 10.35           | false       | order      | 0                     |
| 1500            | false       | invoice    | 1500                  |
| 1484.96         | false       | order      | 0                     |
| 17.25           | false       | invoice    | 17.25                 |
| 153.78          | false       | invoice    | 153.78                |
| 163.9           | false       | order      | 0                     |
| 8               | false       | order      | 0                     |
| 784.35          | false       | order      | 0                     |
| 82.26           | false       | invoice    | 82.26                 |
| 180             | false       | order      | 0                     |
| 301.8           | false       | order      | 0                     |
| 348.02          | false       | invoice    | 348.02                |
| 432.01          | false       | invoice    | 432.01                |
| 63              | false       | order      | 0                     |
| 200             | false       | invoice    | 200                   |
| 165             | false       | order      | 0                     |
| 53.99           | false       | order      | 0                     |
| 18.01           | false       | invoice    | 18.01                 |
| 99.72           | false       | order      | 0                     |
| 76.8            | false       | invoice    | 76.8                  |
| 75              | false       | invoice    | 75                    |
| 12              | false       | order      | 0                     |
| 52.47           | false       | order      | 0                     |
| 358.8           | false       | order      | 0                     |
| 57.34           | false       | order      | 0                     |
| 68.75           | false       | order      | 0                     |
| 124.99          | false       | order      | 0                     |
| 25              | false       | invoice    | 25                    |
| 50              | false       | order      | 0                     |
| 115             | false       | invoice    | 115                   |
| 202.5           | false       | order      | 0                     |
| 113.97          | false       | order      | 0                     |
| 13.02           | true        | order      | 0                     |
| 360             | false       | order      | 0                     |
| 287.98          | false       | order      | 0                     |
| 153.78          | false       | invoice    | 153.78                |
| 507.47          | false       | order      | 0                     |
| 6935.96         | false       | order      | 0                     |
| 787.5           | false       | invoice    | 787.5                 |
| 29              | false       | order      | 0                     |
| 75              | false       | order      | 0                     |
| 599.95          | false       | order      | 0                     |
| 1799.99         | false       | invoice    | 1799.99               |
| 38.54           | false       | order      | 0                     |
| 13.12           | false       | order      | 0                     |
| 4000.02         | false       | order      | 0                     |
| 32.99           | false       | invoice    | 32.99                 |
| 2900            | false       | order      | 0                     |
| 332.35          | false       | order      | 0                     |
**/



-- Double check:
-- Manually check each column for blanks in Excel or Power Query

/**
Recap:
fill in the blanks  
↓ 
add discount_group  
↓
add year_month  
↓
zero out returns in final_net_revenue_usd  
↓
check
**/



-----------
--customers
-----------

-- Revise column names in customers_raw for joining later
-- Rename the region to region_customers and country to country_customers
/**
This can be done in the Supabase UI Table Editor.
Go to table, click the three dots, Edit table.
**/

-- Fill in the blanks in region field of customers table

UPDATE customers_raw
SET region_customers = 'NAm'
WHERE (region_customers IS NULL OR region_customers = '')
  AND country_customers IN ('United States', 'Canada');
  
UPDATE customers_raw
SET signup_year_month = DATE_TRUNC('month', signup_date)::date;

/**
Summary:
rename common columns with events for final view join  
↓ 
fill in the blanks  
**/



-----------------
OPTIMIZED QUERIES
-----------------
-- Select all fields and add a few more to new view called events_final
-- last_event_date, next_event_date, days_since_last_event, days_to_next_event
-- Use a CTE (Common Table Expression) to calculate window functions only ONCE
-- events_with_lags ewl CTE
-- Remember to ORDER BY event_date since the import process jumbled the rows



-------------------
--events_final view
-------------------

-- Add the last_invoice_date, next_invoice_date
-- and days_since_last_invoice, days_to_next_invoice

CREATE OR REPLACE VIEW events_final AS
SELECT
    e.*,  -- preserves all original columns
    -- Last invoice date up to the current event
    MAX(
        CASE WHEN e.event_type = 'invoice' AND e.is_refunded = FALSE
             THEN e.event_date END
    ) OVER (
        PARTITION BY e.customer_id
        ORDER BY e.event_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS last_invoice_date,

    -- Next invoice date from the current event forward
    MIN(
        CASE WHEN e.event_type = 'invoice' AND e.is_refunded = FALSE
             THEN e.event_date END
    ) OVER (
        PARTITION BY e.customer_id
        ORDER BY e.event_date
        ROWS BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING
    ) AS next_invoice_date,

    -- Days since last invoice (NULL if none yet)
    (e.event_date -
     MAX(
        CASE WHEN e.event_type = 'invoice' AND e.is_refunded = FALSE
             THEN e.event_date END
     ) OVER (
        PARTITION BY e.customer_id
        ORDER BY e.event_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
     )) AS days_since_last_invoice,

    -- Days to next invoice (NULL if none ahead)
    (MIN(
        CASE WHEN e.event_type = 'invoice' AND e.is_refunded = FALSE
             THEN e.event_date END
     ) OVER (
        PARTITION BY e.customer_id
        ORDER BY e.event_date
        ROWS BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING
     ) - e.event_date) AS days_to_next_invoice
FROM events_raw e
ORDER BY e.event_date ASC;

;






-- Count of refunds

SELECT 
DATE_TRUNC('month', event_date)::date as year_month,
is_refunded,
COUNT(event_id) count_refunds
FROM events_final_new
GROUP BY DATE_TRUNC('month', event_date)::date, is_refunded
HAVING is_refunded = TRUE
ORDER BY DATE_TRUNC('month', event_date)::date
;

/**
| year_month | is_refunded | count_refunds |
| ---------- | ----------- | ------------- |
| 2024-04-01 | true        | 16            |
| 2024-05-01 | true        | 59            |
| 2024-06-01 | true        | 55            |
| 2024-07-01 | true        | 52            |
| 2024-08-01 | true        | 61            |
| 2024-09-01 | true        | 53            |
| 2024-10-01 | true        | 64            |
| 2024-11-01 | true        | 50            |
| 2024-12-01 | true        | 47            |
| 2025-01-01 | true        | 60            |
| 2025-02-01 | true        | 55            |
| 2025-03-01 | true        | 63            |
| 2025-04-01 | true        | 58            |
| 2025-05-01 | true        | 58            |
| 2025-06-01 | true        | 56            |
| 2025-07-01 | true        | 63            |
| 2025-08-01 | true        | 63            |
| 2025-09-01 | true        | 42            |
| 2025-10-01 | true        | 30            |
**/

-- Monthly revenues

SELECT 
DATE_TRUNC('month', event_date)::date as year_month,
SUM(final_net_revenue_usd) as revenues_monthly
FROM events_final_new
GROUP BY DATE_TRUNC('month', event_date)::date 
ORDER BY DATE_TRUNC('month', event_date)::date
;
/**
| year_month | revenues_monthly |
| ---------- | ---------------- |
| 2024-04-01 | 121910.57        |
| 2024-05-01 | 506388.55        |
| 2024-06-01 | 497415.93        |
| 2024-07-01 | 515789.25        |
| 2024-08-01 | 514981.49        |
| 2024-09-01 | 485344.2         |
| 2024-10-01 | 497218.31        |
| 2024-11-01 | 539982.86        |
| 2024-12-01 | 510467.54        |
| 2025-01-01 | 503820.91        |
| 2025-02-01 | 435042.44        |
| 2025-03-01 | 551035.06        |
| 2025-04-01 | 536679.05        |
| 2025-05-01 | 491885.35        |
| 2025-06-01 | 557434.55        |
| 2025-07-01 | 535488.2         |
| 2025-08-01 | 504317.43        |
| 2025-09-01 | 496518.91        |
| 2025-10-01 | 373970.69        |
**/





-----------------------
-- customers_final view 
-----------------------
-- Create view customers_final with added second_purchase_date
-- days_since_last_invoice as wait_days
-- second_purchase_date is subsequent purchase date
-- AND sp.rownum =2 ensures left join, nulls for non-matching 
-- with is_repeater flag
-- with signup_year_month

CREATE OR REPLACE VIEW customers_final AS
WITH second_purchases AS (
  SELECT
    customer_id,
    event_date AS second_purchase_date,
    days_since_last_invoice AS wait_days,
    ROW_NUMBER() OVER (
      PARTITION BY customer_id
      ORDER BY event_date ASC
    ) AS rownum
  FROM events_final_new
  WHERE event_type = 'invoice'
)
SELECT
  c.*,
  sp.second_purchase_date,  
  sp.wait_days,
  CASE 
    WHEN sp.rownum = 2 THEN TRUE
    ELSE FALSE
  END AS is_repeater,
  DATE_TRUNC('month', signup_date::date)::date as signup_year_month
FROM customers_raw c
LEFT JOIN second_purchases sp
  ON c.customer_id = sp.customer_id
 AND sp.rownum = 2; 


/**
 -- Count invoices, there should be 2 per repeater customer
 -- If none, then WHERE event_type = 'invoice' is too strict
 -- Result - 3505 rows of repeat customers, so event_type = 'invoice' is not too strict

SELECT customer_id, COUNT(*) AS invoice_count
FROM events_final
WHERE event_type = 'invoice' 
GROUP BY customer_id
HAVING count(*) > 1
ORDER BY invoice_count DESC;
**/







----------------------
--products_final view
----------------------

-- Create products_final view
-- Replace 'Add?on' in product_name with 'Add-on'

CREATE OR REPLACE VIEW products_final AS
select
product_id,
REGEXP_REPLACE(product_name, 'Add.?on', 'Add-on') AS product_name,
category,
is_subscription,
billing_cycle,
base_price_usd,
first_release_date,
vendor,
resale_model,
brand_safe_name,
product_name_orig,
base_price_usd_orig,
base_key,
product_version
FROM products_raw;


------------------
-- SECOND PURCHASE
------------------

-- Days to SECOND PURCHASE - unique per customer
-- Using customers_final view and wait_days
-- Remember this is first to second purchase only

SELECT 
ROUND (avg(wait_days), 2)  avg_wait_days,
ROUND (min(wait_days), 2)  min_wait_days,
ROUND (max(wait_days), 2)  max_wait_days
FROM customers_final
;

/**
| avg_wait_days | min_wait_days | max_wait_days |
| ------------- | ------------- | ------------- |
| 2.60          | 0.00          | 442.00        |
**/




---------------
-- Purchase cycles
---------------
-- Using events_final_view and days_since_last_event 
-- Remember this includes all purchases
SELECT 
ROUND (avg(days_since_last_invoice), 2)  avg_days_since_last_invoice,
ROUND (min(days_since_last_invoice), 2)  min_days_since_last_invoice,
ROUND (max(days_since_last_invoice), 2)  max_days_since_last_invoice
FROM events_final_new
;
/**
| avg_days_since_last_invoice | min_days_since_last_invoice | max_days_since_last_invoice |
| --------------------------- | --------------------------- | --------------------------- |
| 64.78                       | 0.00                        | 540.00                      |
**/






----------
--COMBINED
----------

----------------
-- Process Check
----------------

-- At this point, 
-- -- events_raw is cleaned and events_final view is created
-- -- events_final view is updated based on the overall purchase cycle
-- -- customers_raw is cleaned, and customers_final view is created
-- -- products_raw is cleaned as products_final view is created



-- Run the view combined


CREATE OR REPLACE VIEW combined AS
SELECT
  -- event-level (bring all columns from events_final_new)
  efn.*,

  -- customer-level columns (aliased to avoid collisions)
  c.customer_id            AS customer_id_c,
  c.signup_date,
  c.region_customers,
  c.currency_preference,
  c.segment,
  c.acquisition_channel,
  c.age_band,
  c.country_customers,
  c.country_latitude_customers,
  c.country_longitude_customers,
  c.second_purchase_date,
  c.wait_days,
  c.is_repeater,
  c.signup_year_month,

  -- product-level columns (aliased to avoid collisions)
  p.product_id             AS product_id_p,
  p.product_name,
  p.category,
  p.is_subscription,
  p.billing_cycle,
  p.base_price_usd,
  p.first_release_date,
  p.vendor,
  p.resale_model,
  p.brand_safe_name,
  p.product_name_orig,
  p.base_price_usd_orig,
  p.base_key,
  p.product_version
FROM events_final_new efn
LEFT JOIN customers_final c
  ON efn.customer_id = c.customer_id
LEFT JOIN products_final p
  ON efn.product_id = p.product_id;



/**

-- Export combined view
SELECT * FROM combined;

**/

--------------------
-- Export in chunks
--------------------
-- Export 2024 data first chunk (22296 rows)
SELECT * FROM combined 
WHERE event_date < '2025-01-01';

-- Export 2025 data second chunk (25704 rows)
SELECT * FROM combined 
WHERE event_date >= '2025-01-01'
AND event_date < '2026-01-01';




















--------------------
-- Repeater analysis
--------------------
-- Count distinct repeaters by year_month as check
SELECT
    DATE_TRUNC('month', event_date) AS year_month,
    COUNT(DISTINCT CASE WHEN is_repeater THEN customer_id END) AS repeater
FROM combined
GROUP BY year_month
ORDER BY year_month;


/**
| year_month             | repeater |
| ---------------------- | -------- |
| 2024-04-01 00:00:00+00 | 632      |
| 2024-05-01 00:00:00+00 | 1827     |
| 2024-06-01 00:00:00+00 | 1706     |
| 2024-07-01 00:00:00+00 | 1786     |
| 2024-08-01 00:00:00+00 | 1805     |
| 2024-09-01 00:00:00+00 | 1728     |
| 2024-10-01 00:00:00+00 | 1718     |
| 2024-11-01 00:00:00+00 | 1733     |
| 2024-12-01 00:00:00+00 | 1759     |
| 2025-01-01 00:00:00+00 | 1757     |
| 2025-02-01 00:00:00+00 | 1650     |
| 2025-03-01 00:00:00+00 | 1770     |
| 2025-04-01 00:00:00+00 | 1710     |
| 2025-05-01 00:00:00+00 | 1730     |
| 2025-06-01 00:00:00+00 | 1705     |
| 2025-07-01 00:00:00+00 | 1768     |
| 2025-08-01 00:00:00+00 | 1758     |
| 2025-09-01 00:00:00+00 | 1674     |
| 2025-10-01 00:00:00+00 | 1328     |

**/




-- What is percent of monthly sales from repeaters? 
-- Percent of final_net_revenue_usd from repeaters, output by month
SELECT
    DATE_TRUNC('month', event_date) AS year_month,
    SUM(final_net_revenue_usd) AS total_revenue,
    SUM(CASE WHEN is_repeater THEN final_net_revenue_usd ELSE 0 END) AS revenue_repeater,
    ROUND(
        (SUM(CASE WHEN is_repeater THEN final_net_revenue_usd ELSE 0 END) * 100.0 / NULLIF(SUM(final_net_revenue_usd),0))::numeric,
        2
    ) AS pct_revenue_repeater
FROM combined
GROUP BY year_month
ORDER BY year_month;

/**
-- Most of monthly revenue comes from repeaters
| year_month             | total_revenue | revenue_repeater | pct_revenue_repeater |
| ---------------------- | ------------- | ---------------- | -------------------- |
| 2024-04-01 00:00:00+00 | 121910.57     | 116234.07        | 95.34                |
| 2024-05-01 00:00:00+00 | 506388.55     | 503057.95        | 99.34                |
| 2024-06-01 00:00:00+00 | 497415.93     | 481828.75        | 96.87                |
| 2024-07-01 00:00:00+00 | 515789.25     | 503626.27        | 97.64                |
| 2024-08-01 00:00:00+00 | 514981.49     | 503799.1         | 97.83                |
| 2024-09-01 00:00:00+00 | 485344.2      | 483482.81        | 99.62                |
| 2024-10-01 00:00:00+00 | 497218.31     | 483920.21        | 97.33                |
| 2024-11-01 00:00:00+00 | 539982.86     | 532529.66        | 98.62                |
| 2024-12-01 00:00:00+00 | 510467.54     | 498313.56        | 97.62                |
| 2025-01-01 00:00:00+00 | 503820.91     | 495113.23        | 98.27                |
| 2025-02-01 00:00:00+00 | 435042.44     | 423872.94        | 97.43                |
| 2025-03-01 00:00:00+00 | 551035.06     | 537271.33        | 97.50                |
| 2025-04-01 00:00:00+00 | 536679.05     | 519601.06        | 96.82                |
| 2025-05-01 00:00:00+00 | 491885.35     | 474618.82        | 96.49                |
| 2025-06-01 00:00:00+00 | 557434.55     | 542989.8         | 97.41                |
| 2025-07-01 00:00:00+00 | 535488.2      | 519951.97        | 97.10                |
| 2025-08-01 00:00:00+00 | 504317.43     | 486013.24        | 96.37                |
| 2025-09-01 00:00:00+00 | 496518.91     | 478258.75        | 96.32                |
| 2025-10-01 00:00:00+00 | 373970.69     | 372594.12        | 99.63                |
**/




-- What acquisition channel brings the most repeaters?
-- Count distinct repeaters by acquisition_channel
SELECT
    acquisition_channel,
    COUNT(DISTINCT CASE WHEN is_repeater THEN customer_id END) AS repeaters
FROM combined
GROUP BY acquisition_channel
ORDER BY repeaters DESC;


/**
Paid Search and Social Top the List for Repeater Acquisition 
| acquisition_channel | repeaters |
| ------------------- | --------- |
| Organic             | 988       |
| Paid Search         | 749       |
| Social              | 617       |
| Email               | 590       |
| Affiliate           | 398       |
| Retail Media        | 161       |

**/




-- Count distinct repeaters by channel (sales)
SELECT
    channel,
    COUNT(DISTINCT CASE WHEN is_repeater THEN customer_id END) AS repeaters
FROM combined
GROUP BY channel
ORDER BY repeaters DESC;

/**
Website and Direct Sales top the sales channel list
| channel      | repeaters |
| ------------ | --------- |
| Website      | 3488      |
| Direct Sales | 3244      |
| Reseller     | 2950      |
| Partner      | 2530      |
| Marketplace  | 2510      |
**/


-- Top products purchased by repeaters?
-- Count product_id from repeaters by segment

SELECT
    product_id,
    COUNT(CASE WHEN segment = 'Consumer' THEN product_id END) AS products_consumer_repeater,
    COUNT(CASE WHEN segment = 'SOHO' THEN product_id END) AS products_soho_repeater,
    COUNT(CASE WHEN segment = 'SMB' THEN product_id END) AS products_smb_repeater,
	COUNT(CASE WHEN segment = 'Enterprise' THEN product_id END) AS products_enterprise_repeater
FROM combined
WHERE is_repeater = TRUE
GROUP BY product_id
ORDER BY product_id;



/**
| product_id | products_consumer_repeater | products_soho_repeater | products_smb_repeater | products_enterprise_repeater |
| ---------- | -------------------------- | ---------------------- | --------------------- | ---------------------------- |
| PROD0001   | 295                        | 78                     | 62                    | 7                            |
| PROD0002   | 271                        | 89                     | 69                    | 7                            |
| PROD0003   | 259                        | 71                     | 61                    | 11                           |
| PROD0004   | 260                        | 74                     | 65                    | 12                           |
| PROD0005   | 276                        | 78                     | 61                    | 14                           |
| PROD0006   | 239                        | 70                     | 55                    | 12                           |
| PROD0007   | 307                        | 85                     | 61                    | 13                           |
| PROD0008   | 284                        | 90                     | 47                    | 13                           |
| PROD0009   | 246                        | 91                     | 55                    | 8                            |
| PROD0010   | 268                        | 78                     | 51                    | 10                           |
| PROD0011   | 299                        | 95                     | 70                    | 13                           |
| PROD0012   | 300                        | 70                     | 58                    | 8                            |
| PROD0013   | 279                        | 67                     | 59                    | 13                           |
| PROD0014   | 274                        | 80                     | 67                    | 8                            |
| PROD0015   | 298                        | 80                     | 62                    | 8                            |
| PROD0016   | 281                        | 78                     | 63                    | 9                            |
| PROD0017   | 293                        | 88                     | 55                    | 10                           |
| PROD0018   | 276                        | 92                     | 61                    | 11                           |
| PROD0019   | 287                        | 86                     | 61                    | 16                           |
| PROD0020   | 280                        | 87                     | 56                    | 8                            |
| PROD0021   | 274                        | 79                     | 68                    | 15                           |
| PROD0022   | 270                        | 87                     | 63                    | 10                           |
| PROD0023   | 281                        | 83                     | 62                    | 5                            |
| PROD0024   | 252                        | 92                     | 60                    | 11                           |
| PROD0025   | 300                        | 76                     | 69                    | 12                           |
| PROD0026   | 266                        | 95                     | 59                    | 13                           |
| PROD0027   | 251                        | 77                     | 64                    | 10                           |
| PROD0028   | 283                        | 77                     | 67                    | 14                           |
| PROD0029   | 262                        | 72                     | 67                    | 11                           |
| PROD0030   | 259                        | 76                     | 65                    | 13                           |
| PROD0031   | 277                        | 79                     | 69                    | 7                            |
| PROD0032   | 257                        | 75                     | 65                    | 17                           |
| PROD0033   | 239                        | 83                     | 76                    | 11                           |
| PROD0034   | 279                        | 69                     | 73                    | 9                            |
| PROD0035   | 280                        | 74                     | 56                    | 11                           |
| PROD0036   | 309                        | 77                     | 45                    | 13                           |
| PROD0037   | 273                        | 94                     | 70                    | 8                            |
| PROD0038   | 284                        | 90                     | 49                    | 11                           |
| PROD0039   | 272                        | 88                     | 73                    | 15                           |
| PROD0040   | 296                        | 94                     | 68                    | 13                           |
| PROD0041   | 281                        | 83                     | 56                    | 13                           |
| PROD0042   | 283                        | 70                     | 68                    | 9                            |
| PROD0043   | 283                        | 74                     | 52                    | 13                           |
| PROD0044   | 252                        | 79                     | 72                    | 8                            |
| PROD0045   | 266                        | 78                     | 71                    | 11                           |
| PROD0046   | 255                        | 84                     | 73                    | 16                           |
| PROD0047   | 270                        | 81                     | 63                    | 13                           |
| PROD0048   | 286                        | 83                     | 60                    | 14                           |
| PROD0049   | 265                        | 73                     | 79                    | 11                           |
| PROD0050   | 304                        | 71                     | 65                    | 19                           |
| PROD0051   | 269                        | 79                     | 58                    | 11                           |
| PROD0052   | 274                        | 78                     | 64                    | 8                            |
| PROD0053   | 280                        | 89                     | 61                    | 13                           |
| PROD0054   | 285                        | 79                     | 56                    | 16                           |
| PROD0055   | 294                        | 90                     | 62                    | 10                           |
| PROD0056   | 288                        | 77                     | 56                    | 9                            |
| PROD0057   | 271                        | 72                     | 66                    | 11                           |
| PROD0058   | 273                        | 83                     | 49                    | 16                           |
| PROD0059   | 271                        | 77                     | 58                    | 8                            |
| PROD0060   | 303                        | 77                     | 61                    | 9                            |
| PROD0061   | 245                        | 77                     | 68                    | 17                           |
| PROD0062   | 264                        | 75                     | 68                    | 12                           |
| PROD0063   | 264                        | 90                     | 71                    | 14                           |
| PROD0064   | 276                        | 88                     | 71                    | 7                            |
| PROD0065   | 263                        | 92                     | 63                    | 15                           |
| PROD0066   | 252                        | 81                     | 68                    | 14                           |
| PROD0067   | 292                        | 85                     | 64                    | 8                            |
| PROD0068   | 243                        | 91                     | 71                    | 7                            |
| PROD0069   | 266                        | 80                     | 74                    | 9                            |
| PROD0070   | 302                        | 65                     | 73                    | 5                            |
| PROD0071   | 288                        | 85                     | 64                    | 15                           |
| PROD0072   | 265                        | 86                     | 57                    | 10                           |
| PROD0073   | 290                        | 78                     | 61                    | 13                           |
| PROD0074   | 272                        | 80                     | 62                    | 10                           |
| PROD0075   | 271                        | 71                     | 68                    | 10                           |
| PROD0076   | 269                        | 80                     | 67                    | 9                            |
| PROD0077   | 286                        | 68                     | 59                    | 14                           |
| PROD0078   | 263                        | 76                     | 80                    | 8                            |
| PROD0079   | 255                        | 62                     | 69                    | 6                            |
| PROD0080   | 290                        | 83                     | 61                    | 14                           |
| PROD0081   | 280                        | 87                     | 73                    | 12                           |
| PROD0082   | 253                        | 75                     | 58                    | 14                           |
| PROD0083   | 308                        | 89                     | 56                    | 7                            |
| PROD0084   | 266                        | 75                     | 59                    | 13                           |
| PROD0085   | 282                        | 78                     | 72                    | 9                            |
| PROD0086   | 253                        | 90                     | 63                    | 12                           |
| PROD0087   | 286                        | 71                     | 61                    | 11                           |
| PROD0088   | 272                        | 95                     | 59                    | 11                           |
| PROD0089   | 290                        | 83                     | 55                    | 13                           |
| PROD0090   | 267                        | 95                     | 61                    | 11                           |
| PROD0091   | 270                        | 77                     | 66                    | 12                           |
| PROD0092   | 282                        | 80                     | 77                    | 15                           |
| PROD0093   | 247                        | 88                     | 66                    | 11                           |
| PROD0094   | 291                        | 69                     | 54                    | 10                           |
| PROD0095   | 279                        | 76                     | 69                    | 13                           |
| PROD0096   | 245                        | 95                     | 61                    | 8                            |
| PROD0097   | 271                        | 82                     | 59                    | 7                            |
| PROD0098   | 258                        | 90                     | 71                    | 10                           |
| PROD0099   | 271                        | 82                     | 70                    | 15                           |
| PROD0100   | 290                        | 78                     | 58                    | 8                            |
| PROD0101   | 244                        | 73                     | 69                    | 16                           |
Top products bought by repeaters
**/



-- What discount code do repeaters use most often?
-- Count discount_group by repeaters
-- Result:  Welcome10, BFCM10, NEWCUSTOMER10, SAVE5, BFCM20.
-- Result: Surprisingly, LOYALTY15 is not top among repeaters.



-- Count discount_group by repeaters
SELECT
    discount_group,
    COUNT(CASE WHEN is_repeater	 THEN customer_id END) AS repeaters_count
FROM combined
WHERE is_repeater = TRUE
GROUP BY discount_group
ORDER BY repeaters_count DESC;

/**
Most repeaters paid full price, discounts have minimal impact
| discount_group | repeaters_count |
| -------------- | --------------- |
| Full Price     | 28055           |
| WELCOME10      | 2476            |
| NEWCUSTOMER10  | 2448            |
| BFCM20         | 2424            |
| SAVE5          | 2421            |
| BFCM10         | 2375            |
| LOYALTY15      | 1643            |
| SALE15         | 739             |
| EDU15          | 153             |
| STUDENT20      | 143             |
| EDU20          | 139             |
| STUDENT10      | 136             |
| EDU10          | 136             |
| STUDENT15      | 130             |
**/





--------------------
Market Basket Set-up  
--------------------
-- Market Basket: requires final combined view
-- events_baskets -> events_baskets_min2 -> product_pairs
-- Step 1:
-- Create basket_id in events_baskets View
CREATE OR REPLACE VIEW events_baskets AS
SELECT
  CONCAT(customer_id, '_', event_date) AS basket_id,
  customer_id,
  event_date,
  product_id,
  product_name
FROM combined
WHERE event_type = 'invoice';



SELECT * FROM events_baskets LIMIT 5;


-- Step 2:
-- Use WHERE and a sub-query to filter baskets with >= 2 products
CREATE OR REPLACE VIEW events_baskets_min2 AS
SELECT *
FROM events_baskets
WHERE basket_id IN (
  SELECT basket_id
  FROM events_baskets
  GROUP BY basket_id
  HAVING COUNT(DISTINCT product_id) >= 2
);


SELECT * FROM events_baskets_min2  LIMIT 5;



-- Step 3:
-- product pairs to cross-sell
CREATE OR REPLACE VIEW product_pairs AS
SELECT
  a.product_id   AS product_a_id,
  a.product_name AS product_a_name,
  b.product_id   AS product_b_id,
  b.product_name AS product_b_name,
  COUNT(DISTINCT a.basket_id) AS pair_count
FROM events_baskets_min2 a
JOIN events_baskets_min2 b
  ON a.basket_id = b.basket_id
 AND a.product_id < b.product_id
GROUP BY
  a.product_id, a.product_name,
  b.product_id, b.product_name
ORDER BY pair_count DESC;



-------------------------------------------------
-- Export product_pairs as Market Basket Analysis
-------------------------------------------------
-- Result: 54 rows or pairs
SELECT * FROM product_pairs;




-- Power BI duplication produces both directions, but visuals collapse them.
-- SQL requires a.product_id < b.product_id (or similar) to enforce uniqueness.
-- That condition isn’t needed in Power BI because the aggregation layer handles it.




---------------------------
Export product_pairs as csv
---------------------------

Copy as new tab in Google Sheets for the market basket analysis




----------------------
-- Retention Patterns?
----------------------

-- Conclusion: Signup date is not a good anchor date for cohort calculations
-- Method: Retention or cohort using signup date as anchor
-- Result: Negative values since signup shows invoice dates prior to signup date


WITH base AS (
  SELECT
    customer_id,
    signup_year_month,
    TO_CHAR(event_date, 'YYYYMM') AS event_year_month,

    -- months since signup using age()
    (EXTRACT(YEAR FROM age(event_date, signup_year_month)) * 12
     + EXTRACT(MONTH FROM age(event_date, signup_year_month))) AS months_since_signup
  FROM combined
  WHERE event_date >= signup_year_month
    AND event_type = 'invoice'
),

cohort_activity AS (
  SELECT
    signup_year_month,
    months_since_signup,
    COUNT(DISTINCT customer_id) AS active_customers
  FROM base
  GROUP BY signup_year_month, months_since_signup
),

cohort_size AS (
  SELECT
    signup_year_month,
    COUNT(DISTINCT customer_id) AS cohort_size
  FROM base
  WHERE months_since_signup = 0
  GROUP BY signup_year_month
)

SELECT
  ca.signup_year_month,
  ca.months_since_signup,
  ROUND(100.0 * ca.active_customers / cs.cohort_size, 1) AS retention_rate_pct
FROM cohort_activity ca
JOIN cohort_size cs
  ON ca.signup_year_month = cs.signup_year_month
ORDER BY ca.signup_year_month, ca.months_since_signup;


/**
| signup_year_month | months_since_signup | retention_rate_pct |
| ----------------- | ------------------- | ------------------ |
| 2024-04-01        | 0                   | 100.0              |
| 2024-04-01        | 1                   | 237.5              |
| 2024-04-01        | 2                   | 262.5              |
| 2024-04-01        | 3                   | 212.5              |
| 2024-04-01        | 4                   | 206.3              |
| 2024-04-01        | 5                   | 268.8              |
| 2024-04-01        | 6                   | 212.5              |
| 2024-04-01        | 7                   | 225.0              |
| 2024-04-01        | 8                   | 237.5              |
| 2024-04-01        | 9                   | 256.3              |
| 2024-04-01        | 10                  | 237.5              |
| 2024-04-01        | 11                  | 237.5              |
| 2024-04-01        | 12                  | 237.5              |
| 2024-04-01        | 13                  | 231.3              |
| 2024-04-01        | 14                  | 256.3              |
| 2024-04-01        | 15                  | 231.3              |
| 2024-04-01        | 16                  | 212.5              |
| 2024-04-01        | 17                  | 193.8              |
| 2024-04-01        | 18                  | 206.3              |
| 2024-05-01        | 0                   | 100.0              |
| 2024-05-01        | 1                   | 116.3              |
| 2024-05-01        | 2                   | 95.3               |
| 2024-05-01        | 3                   | 118.6              |
| 2024-05-01        | 4                   | 104.7              |
| 2024-05-01        | 5                   | 90.7               |
| 2024-05-01        | 6                   | 111.6              |
| 2024-05-01        | 7                   | 114.0              |
| 2024-05-01        | 8                   | 102.3              |
| 2024-05-01        | 9                   | 88.4               |
| 2024-05-01        | 10                  | 130.2              |
| 2024-05-01        | 11                  | 95.3               |
| 2024-05-01        | 12                  | 114.0              |
| 2024-05-01        | 13                  | 88.4               |
| 2024-05-01        | 14                  | 114.0              |
| 2024-05-01        | 15                  | 95.3               |
| 2024-05-01        | 16                  | 114.0              |
| 2024-05-01        | 17                  | 62.8               |
| 2024-06-01        | 0                   | 100.0              |
| 2024-06-01        | 1                   | 103.0              |
| 2024-06-01        | 2                   | 103.0              |
| 2024-06-01        | 3                   | 90.9               |
| 2024-06-01        | 4                   | 97.0               |
| 2024-06-01        | 5                   | 87.9               |
| 2024-06-01        | 6                   | 84.8               |
| 2024-06-01        | 7                   | 97.0               |
| 2024-06-01        | 8                   | 100.0              |
| 2024-06-01        | 9                   | 118.2              |
| 2024-06-01        | 10                  | 90.9               |
| 2024-06-01        | 11                  | 115.2              |
| 2024-06-01        | 12                  | 115.2              |
| 2024-06-01        | 13                  | 100.0              |
| 2024-06-01        | 14                  | 66.7               |
| 2024-06-01        | 15                  | 72.7               |
| 2024-06-01        | 16                  | 81.8               |
| 2024-07-01        | 0                   | 100.0              |
| 2024-07-01        | 1                   | 74.4               |
| 2024-07-01        | 2                   | 84.6               |
| 2024-07-01        | 3                   | 82.1               |
| 2024-07-01        | 4                   | 100.0              |
| 2024-07-01        | 5                   | 87.2               |
| 2024-07-01        | 6                   | 84.6               |
| 2024-07-01        | 7                   | 79.5               |
| 2024-07-01        | 8                   | 112.8              |
| 2024-07-01        | 9                   | 97.4               |
| 2024-07-01        | 10                  | 74.4               |
| 2024-07-01        | 11                  | 82.1               |
| 2024-07-01        | 12                  | 112.8              |
| 2024-07-01        | 13                  | 82.1               |
| 2024-07-01        | 14                  | 92.3               |
| 2024-07-01        | 15                  | 48.7               |
| 2024-08-01        | 0                   | 100.0              |
| 2024-08-01        | 1                   | 79.5               |
| 2024-08-01        | 2                   | 84.6               |
| 2024-08-01        | 3                   | 82.1               |
| 2024-08-01        | 4                   | 79.5               |
| 2024-08-01        | 5                   | 89.7               |
| 2024-08-01        | 6                   | 74.4               |
| 2024-08-01        | 7                   | 115.4              |
| 2024-08-01        | 8                   | 120.5              |
| 2024-08-01        | 9                   | 82.1               |
| 2024-08-01        | 10                  | 92.3               |
| 2024-08-01        | 11                  | 110.3              |
| 2024-08-01        | 12                  | 84.6               |
| 2024-08-01        | 13                  | 87.2               |
| 2024-08-01        | 14                  | 53.8               |
| 2024-09-01        | 0                   | 100.0              |
| 2024-09-01        | 1                   | 64.1               |
| 2024-09-01        | 2                   | 82.1               |
| 2024-09-01        | 3                   | 71.8               |
| 2024-09-01        | 4                   | 97.4               |
| 2024-09-01        | 5                   | 82.1               |
| 2024-09-01        | 6                   | 112.8              |
| 2024-09-01        | 7                   | 107.7              |
| 2024-09-01        | 8                   | 123.1              |
| 2024-09-01        | 9                   | 130.8              |
| 2024-09-01        | 10                  | 120.5              |
| 2024-09-01        | 11                  | 123.1              |
| 2024-09-01        | 12                  | 92.3               |
| 2024-09-01        | 13                  | 87.2               |
| 2024-10-01        | 0                   | 100.0              |
| 2024-10-01        | 1                   | 87.5               |
| 2024-10-01        | 2                   | 75.0               |
| 2024-10-01        | 3                   | 92.5               |
| 2024-10-01        | 4                   | 82.5               |
| 2024-10-01        | 5                   | 87.5               |
| 2024-10-01        | 6                   | 72.5               |
| 2024-10-01        | 7                   | 87.5               |
| 2024-10-01        | 8                   | 85.0               |
| 2024-10-01        | 9                   | 107.5              |
| 2024-10-01        | 10                  | 95.0               |
| 2024-10-01        | 11                  | 90.0               |
| 2024-10-01        | 12                  | 62.5               |
| 2024-11-01        | 0                   | 100.0              |
| 2024-11-01        | 1                   | 122.2              |
| 2024-11-01        | 2                   | 97.2               |
| 2024-11-01        | 3                   | 75.0               |
| 2024-11-01        | 4                   | 102.8              |
| 2024-11-01        | 5                   | 108.3              |
| 2024-11-01        | 6                   | 100.0              |
| 2024-11-01        | 7                   | 102.8              |
| 2024-11-01        | 8                   | 116.7              |
| 2024-11-01        | 9                   | 100.0              |
| 2024-11-01        | 10                  | 105.6              |
| 2024-11-01        | 11                  | 63.9               |
| 2024-12-01        | 0                   | 100.0              |
| 2024-12-01        | 1                   | 81.1               |
| 2024-12-01        | 2                   | 81.1               |
| 2024-12-01        | 3                   | 116.2              |
| 2024-12-01        | 4                   | 91.9               |
| 2024-12-01        | 5                   | 73.0               |
| 2024-12-01        | 6                   | 64.9               |
| 2024-12-01        | 7                   | 94.6               |
| 2024-12-01        | 8                   | 121.6              |
| 2024-12-01        | 9                   | 81.1               |
| 2024-12-01        | 10                  | 62.2               |
| 2025-01-01        | 0                   | 100.0              |
| 2025-01-01        | 1                   | 65.2               |
| 2025-01-01        | 2                   | 82.6               |
| 2025-01-01        | 3                   | 78.3               |
| 2025-01-01        | 4                   | 71.7               |
| 2025-01-01        | 5                   | 87.0               |
| 2025-01-01        | 6                   | 73.9               |
| 2025-01-01        | 7                   | 76.1               |
| 2025-01-01        | 8                   | 93.5               |
| 2025-01-01        | 9                   | 58.7               |
| 2025-02-01        | 0                   | 100.0              |
| 2025-02-01        | 1                   | 89.7               |
| 2025-02-01        | 2                   | 102.6              |
| 2025-02-01        | 3                   | 94.9               |
| 2025-02-01        | 4                   | 125.6              |
| 2025-02-01        | 5                   | 105.1              |
| 2025-02-01        | 6                   | 94.9               |
| 2025-02-01        | 7                   | 100.0              |
| 2025-02-01        | 8                   | 64.1               |
| 2025-03-01        | 0                   | 100.0              |
| 2025-03-01        | 1                   | 104.3              |
| 2025-03-01        | 2                   | 89.4               |
| 2025-03-01        | 3                   | 89.4               |
| 2025-03-01        | 4                   | 72.3               |
| 2025-03-01        | 5                   | 108.5              |
| 2025-03-01        | 6                   | 97.9               |
| 2025-03-01        | 7                   | 74.5               |
| 2025-04-01        | 0                   | 100.0              |
| 2025-04-01        | 1                   | 97.1               |
| 2025-04-01        | 2                   | 108.6              |
| 2025-04-01        | 3                   | 97.1               |
| 2025-04-01        | 4                   | 125.7              |
| 2025-04-01        | 5                   | 91.4               |
| 2025-04-01        | 6                   | 62.9               |
| 2025-05-01        | 0                   | 100.0              |
| 2025-05-01        | 1                   | 112.1              |
| 2025-05-01        | 2                   | 136.4              |
| 2025-05-01        | 3                   | 109.1              |
| 2025-05-01        | 4                   | 112.1              |
| 2025-05-01        | 5                   | 60.6               |
| 2025-06-01        | 0                   | 100.0              |
| 2025-06-01        | 1                   | 93.8               |
| 2025-06-01        | 2                   | 112.5              |
| 2025-06-01        | 3                   | 112.5              |
| 2025-06-01        | 4                   | 59.4               |
| 2025-07-01        | 0                   | 100.0              |
| 2025-07-01        | 1                   | 90.0               |
| 2025-07-01        | 2                   | 65.0               |
| 2025-07-01        | 3                   | 57.5               |
| 2025-08-01        | 0                   | 100.0              |
| 2025-08-01        | 1                   | 87.8               |
| 2025-08-01        | 2                   | 85.4               |


**/


-- Group by signup_year_month
SELECT
  signup_year_month,
  months_since_signup,
  COUNT(DISTINCT customer_id) * 100.0 / cohort_size AS retention_rate_pct
FROM (
  SELECT
    customer_id,
    signup_year_month,
    (EXTRACT(YEAR FROM event_date) * 12 + EXTRACT(MONTH FROM event_date))
      - (EXTRACT(YEAR FROM signup_year_month) * 12 + EXTRACT(MONTH FROM signup_year_month)) AS months_since_signup
  FROM combined
  WHERE event_type = 'invoice'
) base
JOIN (
  SELECT
    signup_year_month,
    COUNT(DISTINCT customer_id) AS cohort_size
  FROM combined
  WHERE event_type = 'invoice'
  GROUP BY signup_year_month
) cohorts USING (signup_year_month)
GROUP BY signup_year_month, months_since_signup, cohort_size
ORDER BY signup_year_month, months_since_signup;


/**
| signup_year_month | months_since_signup | retention_rate_pct  |
| ----------------- | ------------------- | ------------------- |
| 2024-01-01        | 3                   | 2.9585798816568047  |
| 2024-01-01        | 4                   | 20.1183431952662722 |
| 2024-01-01        | 5                   | 20.7100591715976331 |
| 2024-01-01        | 6                   | 20.7100591715976331 |
| 2024-01-01        | 7                   | 15.3846153846153846 |
| 2024-01-01        | 8                   | 17.7514792899408284 |
| 2024-01-01        | 9                   | 23.0769230769230769 |
| 2024-01-01        | 10                  | 18.3431952662721893 |
| 2024-01-01        | 11                  | 21.3017751479289941 |
| 2024-01-01        | 12                  | 17.7514792899408284 |
| 2024-01-01        | 13                  | 14.7928994082840237 |
| 2024-01-01        | 14                  | 18.9349112426035503 |
| 2024-01-01        | 15                  | 19.5266272189349112 |
| 2024-01-01        | 16                  | 16.5680473372781065 |
| 2024-01-01        | 17                  | 17.1597633136094675 |
| 2024-01-01        | 18                  | 18.3431952662721893 |
| 2024-01-01        | 19                  | 17.1597633136094675 |
| 2024-01-01        | 20                  | 23.6686390532544379 |
| 2024-01-01        | 21                  | 11.8343195266272189 |
| 2024-02-01        | 2                   | 3.4883720930232558  |
| 2024-02-01        | 3                   | 16.2790697674418605 |
| 2024-02-01        | 4                   | 20.9302325581395349 |
| 2024-02-01        | 5                   | 18.6046511627906977 |
| 2024-02-01        | 6                   | 21.5116279069767442 |
| 2024-02-01        | 7                   | 18.0232558139534884 |
| 2024-02-01        | 8                   | 24.4186046511627907 |
| 2024-02-01        | 9                   | 19.7674418604651163 |
| 2024-02-01        | 10                  | 14.5348837209302326 |
| 2024-02-01        | 11                  | 16.8604651162790698 |
| 2024-02-01        | 12                  | 21.5116279069767442 |
| 2024-02-01        | 13                  | 21.5116279069767442 |
| 2024-02-01        | 14                  | 11.6279069767441860 |
| 2024-02-01        | 15                  | 22.0930232558139535 |
| 2024-02-01        | 16                  | 19.1860465116279070 |
| 2024-02-01        | 17                  | 13.9534883720930233 |
| 2024-02-01        | 18                  | 22.6744186046511628 |
| 2024-02-01        | 19                  | 18.6046511627906977 |
| 2024-02-01        | 20                  | 15.6976744186046512 |
| 2024-03-01        | 1                   | 6.1797752808988764  |
| 2024-03-01        | 2                   | 19.1011235955056180 |
| 2024-03-01        | 3                   | 15.7303370786516854 |
| 2024-03-01        | 4                   | 16.2921348314606742 |
| 2024-03-01        | 5                   | 16.2921348314606742 |
| 2024-03-01        | 6                   | 14.0449438202247191 |
| 2024-03-01        | 7                   | 20.7865168539325843 |
| 2024-03-01        | 8                   | 18.5393258426966292 |
| 2024-03-01        | 9                   | 16.8539325842696629 |
| 2024-03-01        | 10                  | 17.4157303370786517 |
| 2024-03-01        | 11                  | 14.0449438202247191 |
| 2024-03-01        | 12                  | 24.1573033707865169 |
| 2024-03-01        | 13                  | 15.7303370786516854 |
| 2024-03-01        | 14                  | 16.2921348314606742 |
| 2024-03-01        | 15                  | 15.1685393258426966 |
| 2024-03-01        | 16                  | 23.5955056179775281 |
| 2024-03-01        | 17                  | 17.4157303370786517 |
| 2024-03-01        | 18                  | 19.6629213483146067 |
| 2024-03-01        | 19                  | 11.7977528089887640 |
| 2024-04-01        | 0                   | 8.0000000000000000  |
| 2024-04-01        | 1                   | 19.0000000000000000 |
| 2024-04-01        | 2                   | 21.0000000000000000 |
| 2024-04-01        | 3                   | 17.0000000000000000 |
| 2024-04-01        | 4                   | 16.5000000000000000 |
| 2024-04-01        | 5                   | 21.5000000000000000 |
| 2024-04-01        | 6                   | 17.0000000000000000 |
| 2024-04-01        | 7                   | 18.0000000000000000 |
| 2024-04-01        | 8                   | 19.0000000000000000 |
| 2024-04-01        | 9                   | 20.5000000000000000 |
| 2024-04-01        | 10                  | 19.0000000000000000 |
| 2024-04-01        | 11                  | 19.0000000000000000 |
| 2024-04-01        | 12                  | 19.0000000000000000 |
| 2024-04-01        | 13                  | 18.5000000000000000 |
| 2024-04-01        | 14                  | 20.5000000000000000 |
| 2024-04-01        | 15                  | 18.5000000000000000 |
| 2024-04-01        | 16                  | 17.0000000000000000 |
| 2024-04-01        | 17                  | 15.5000000000000000 |
| 2024-04-01        | 18                  | 16.5000000000000000 |
| 2024-05-01        | -1                  | 5.3719008264462810  |
| 2024-05-01        | 0                   | 17.7685950413223140 |
| 2024-05-01        | 1                   | 20.6611570247933884 |
| 2024-05-01        | 2                   | 16.9421487603305785 |
| 2024-05-01        | 3                   | 21.0743801652892562 |
| 2024-05-01        | 4                   | 18.5950413223140496 |
| 2024-05-01        | 5                   | 16.1157024793388430 |
| 2024-05-01        | 6                   | 19.8347107438016529 |
| 2024-05-01        | 7                   | 20.2479338842975207 |
| 2024-05-01        | 8                   | 18.1818181818181818 |
| 2024-05-01        | 9                   | 15.7024793388429752 |
| 2024-05-01        | 10                  | 23.1404958677685950 |
| 2024-05-01        | 11                  | 16.9421487603305785 |
| 2024-05-01        | 12                  | 20.2479338842975207 |
| 2024-05-01        | 13                  | 15.7024793388429752 |
| 2024-05-01        | 14                  | 20.2479338842975207 |
| 2024-05-01        | 15                  | 16.9421487603305785 |
| 2024-05-01        | 16                  | 20.2479338842975207 |
| 2024-05-01        | 17                  | 11.1570247933884298 |
| 2024-06-01        | -2                  | 5.8823529411764706  |
| 2024-06-01        | -1                  | 20.3208556149732620 |
| 2024-06-01        | 0                   | 17.6470588235294118 |
| 2024-06-01        | 1                   | 18.1818181818181818 |
| 2024-06-01        | 2                   | 18.1818181818181818 |
| 2024-06-01        | 3                   | 16.0427807486631016 |
| 2024-06-01        | 4                   | 17.1122994652406417 |
| 2024-06-01        | 5                   | 15.5080213903743316 |
| 2024-06-01        | 6                   | 14.9732620320855615 |
| 2024-06-01        | 7                   | 17.1122994652406417 |
| 2024-06-01        | 8                   | 17.6470588235294118 |
| 2024-06-01        | 9                   | 20.8556149732620321 |
| 2024-06-01        | 10                  | 16.0427807486631016 |
| 2024-06-01        | 11                  | 20.3208556149732620 |
| 2024-06-01        | 12                  | 20.3208556149732620 |
| 2024-06-01        | 13                  | 17.6470588235294118 |
| 2024-06-01        | 14                  | 11.7647058823529412 |
| 2024-06-01        | 15                  | 12.8342245989304813 |
| 2024-06-01        | 16                  | 14.4385026737967914 |
| 2024-07-01        | -3                  | 6.2176165803108808  |
| 2024-07-01        | -2                  | 21.2435233160621762 |
| 2024-07-01        | -1                  | 17.0984455958549223 |
| 2024-07-01        | 0                   | 20.2072538860103627 |
| 2024-07-01        | 1                   | 15.0259067357512953 |
| 2024-07-01        | 2                   | 17.0984455958549223 |
| 2024-07-01        | 3                   | 16.5803108808290155 |
| 2024-07-01        | 4                   | 20.2072538860103627 |
| 2024-07-01        | 5                   | 17.6165803108808290 |
| 2024-07-01        | 6                   | 17.0984455958549223 |
| 2024-07-01        | 7                   | 16.0621761658031088 |
| 2024-07-01        | 8                   | 22.7979274611398964 |
| 2024-07-01        | 9                   | 19.6891191709844560 |
| 2024-07-01        | 10                  | 15.0259067357512953 |
| 2024-07-01        | 11                  | 16.5803108808290155 |
| 2024-07-01        | 12                  | 22.7979274611398964 |
| 2024-07-01        | 13                  | 16.5803108808290155 |
| 2024-07-01        | 14                  | 18.6528497409326425 |
| 2024-07-01        | 15                  | 9.8445595854922280  |
| 2024-08-01        | -4                  | 5.8510638297872340  |
| 2024-08-01        | -3                  | 18.0851063829787234 |
| 2024-08-01        | -2                  | 15.4255319148936170 |
| 2024-08-01        | -1                  | 18.0851063829787234 |
| 2024-08-01        | 0                   | 20.7446808510638298 |
| 2024-08-01        | 1                   | 16.4893617021276596 |
| 2024-08-01        | 2                   | 17.5531914893617021 |
| 2024-08-01        | 3                   | 17.0212765957446809 |
| 2024-08-01        | 4                   | 16.4893617021276596 |
| 2024-08-01        | 5                   | 18.6170212765957447 |
| 2024-08-01        | 6                   | 15.4255319148936170 |
| 2024-08-01        | 7                   | 23.9361702127659574 |
| 2024-08-01        | 8                   | 25.0000000000000000 |
| 2024-08-01        | 9                   | 17.0212765957446809 |
| 2024-08-01        | 10                  | 19.1489361702127660 |
| 2024-08-01        | 11                  | 22.8723404255319149 |
| 2024-08-01        | 12                  | 17.5531914893617021 |
| 2024-08-01        | 13                  | 18.0851063829787234 |
| 2024-08-01        | 14                  | 11.1702127659574468 |
| 2024-09-01        | -5                  | 4.2253521126760563  |
| 2024-09-01        | -4                  | 21.5962441314553991 |
| 2024-09-01        | -3                  | 15.4929577464788732 |
| 2024-09-01        | -2                  | 18.3098591549295775 |
| 2024-09-01        | -1                  | 20.6572769953051643 |
| 2024-09-01        | 0                   | 18.3098591549295775 |
| 2024-09-01        | 1                   | 11.7370892018779343 |
| 2024-09-01        | 2                   | 15.0234741784037559 |
| 2024-09-01        | 3                   | 13.1455399061032864 |
| 2024-09-01        | 4                   | 17.8403755868544601 |
| 2024-09-01        | 5                   | 15.0234741784037559 |
| 2024-09-01        | 6                   | 20.6572769953051643 |
| 2024-09-01        | 7                   | 19.7183098591549296 |
| 2024-09-01        | 8                   | 22.5352112676056338 |
| 2024-09-01        | 9                   | 23.9436619718309859 |
| 2024-09-01        | 10                  | 22.0657276995305164 |
| 2024-09-01        | 11                  | 22.5352112676056338 |
| 2024-09-01        | 12                  | 16.9014084507042254 |
| 2024-09-01        | 13                  | 15.9624413145539906 |
| 2024-10-01        | -6                  | 3.8251366120218579  |
| 2024-10-01        | -5                  | 20.7650273224043716 |
| 2024-10-01        | -4                  | 19.6721311475409836 |
| 2024-10-01        | -3                  | 18.5792349726775956 |
| 2024-10-01        | -2                  | 19.1256830601092896 |
| 2024-10-01        | -1                  | 26.7759562841530055 |
| 2024-10-01        | 0                   | 21.8579234972677596 |
| 2024-10-01        | 1                   | 19.1256830601092896 |
| 2024-10-01        | 2                   | 16.3934426229508197 |
| 2024-10-01        | 3                   | 20.2185792349726776 |
| 2024-10-01        | 4                   | 18.0327868852459016 |
| 2024-10-01        | 5                   | 19.1256830601092896 |
| 2024-10-01        | 6                   | 15.8469945355191257 |
| 2024-10-01        | 7                   | 19.1256830601092896 |
| 2024-10-01        | 8                   | 18.5792349726775956 |
| 2024-10-01        | 9                   | 23.4972677595628415 |
| 2024-10-01        | 10                  | 20.7650273224043716 |
| 2024-10-01        | 11                  | 19.6721311475409836 |
| 2024-10-01        | 12                  | 13.6612021857923497 |
| 2024-11-01        | -7                  | 4.3478260869565217  |
| 2024-11-01        | -6                  | 18.4782608695652174 |
| 2024-11-01        | -5                  | 11.9565217391304348 |
| 2024-11-01        | -4                  | 17.9347826086956522 |
| 2024-11-01        | -3                  | 17.9347826086956522 |
| 2024-11-01        | -2                  | 16.8478260869565217 |
| 2024-11-01        | -1                  | 21.7391304347826087 |
| 2024-11-01        | 0                   | 19.5652173913043478 |
| 2024-11-01        | 1                   | 23.9130434782608696 |
| 2024-11-01        | 2                   | 19.0217391304347826 |
| 2024-11-01        | 3                   | 14.6739130434782609 |
| 2024-11-01        | 4                   | 20.1086956521739130 |
| 2024-11-01        | 5                   | 21.1956521739130435 |
| 2024-11-01        | 6                   | 19.5652173913043478 |
| 2024-11-01        | 7                   | 20.1086956521739130 |
| 2024-11-01        | 8                   | 22.8260869565217391 |
| 2024-11-01        | 9                   | 19.5652173913043478 |
| 2024-11-01        | 10                  | 20.6521739130434783 |
| 2024-11-01        | 11                  | 12.5000000000000000 |
| 2024-12-01        | -8                  | 4.5197740112994350  |
| 2024-12-01        | -7                  | 20.9039548022598870 |
| 2024-12-01        | -6                  | 14.1242937853107345 |
| 2024-12-01        | -5                  | 20.9039548022598870 |
| 2024-12-01        | -4                  | 23.7288135593220339 |
| 2024-12-01        | -3                  | 14.1242937853107345 |
| 2024-12-01        | -2                  | 16.9491525423728814 |
| 2024-12-01        | -1                  | 15.8192090395480226 |
| 2024-12-01        | 0                   | 20.9039548022598870 |
| 2024-12-01        | 1                   | 16.9491525423728814 |
| 2024-12-01        | 2                   | 16.9491525423728814 |
| 2024-12-01        | 3                   | 24.2937853107344633 |
| 2024-12-01        | 4                   | 19.2090395480225989 |
| 2024-12-01        | 5                   | 15.2542372881355932 |
| 2024-12-01        | 6                   | 13.5593220338983051 |
| 2024-12-01        | 7                   | 19.7740112994350282 |
| 2024-12-01        | 8                   | 25.4237288135593220 |
| 2024-12-01        | 9                   | 16.9491525423728814 |
| 2024-12-01        | 10                  | 12.9943502824858757 |
| 2025-01-01        | -9                  | 5.4455445544554455  |
| 2025-01-01        | -8                  | 16.3366336633663366 |
| 2025-01-01        | -7                  | 16.3366336633663366 |
| 2025-01-01        | -6                  | 20.2970297029702970 |
| 2025-01-01        | -5                  | 25.2475247524752475 |
| 2025-01-01        | -4                  | 16.8316831683168317 |
| 2025-01-01        | -3                  | 18.8118811881188119 |
| 2025-01-01        | -2                  | 18.3168316831683168 |
| 2025-01-01        | -1                  | 19.3069306930693069 |
| 2025-01-01        | 0                   | 22.7722772277227723 |
| 2025-01-01        | 1                   | 14.8514851485148515 |
| 2025-01-01        | 2                   | 18.8118811881188119 |
| 2025-01-01        | 3                   | 17.8217821782178218 |
| 2025-01-01        | 4                   | 16.3366336633663366 |
| 2025-01-01        | 5                   | 19.8019801980198020 |
| 2025-01-01        | 6                   | 16.8316831683168317 |
| 2025-01-01        | 7                   | 17.3267326732673267 |
| 2025-01-01        | 8                   | 21.2871287128712871 |
| 2025-01-01        | 9                   | 13.3663366336633663 |
| 2025-02-01        | -10                 | 11.3402061855670103 |
| 2025-02-01        | -9                  | 14.9484536082474227 |
| 2025-02-01        | -8                  | 19.0721649484536082 |
| 2025-02-01        | -7                  | 18.5567010309278351 |
| 2025-02-01        | -6                  | 17.0103092783505155 |
| 2025-02-01        | -5                  | 14.9484536082474227 |
| 2025-02-01        | -4                  | 15.4639175257731959 |
| 2025-02-01        | -3                  | 22.6804123711340206 |
| 2025-02-01        | -2                  | 18.0412371134020619 |
| 2025-02-01        | -1                  | 20.6185567010309278 |
| 2025-02-01        | 0                   | 20.1030927835051546 |
| 2025-02-01        | 1                   | 18.0412371134020619 |
| 2025-02-01        | 2                   | 20.6185567010309278 |
| 2025-02-01        | 3                   | 19.0721649484536082 |
| 2025-02-01        | 4                   | 25.2577319587628866 |
| 2025-02-01        | 5                   | 21.1340206185567010 |
| 2025-02-01        | 6                   | 19.0721649484536082 |
| 2025-02-01        | 7                   | 20.1030927835051546 |
| 2025-02-01        | 8                   | 12.8865979381443299 |
| 2025-03-01        | -11                 | 4.3668122270742358  |
| 2025-03-01        | -10                 | 24.8908296943231441 |
| 2025-03-01        | -9                  | 14.4104803493449782 |
| 2025-03-01        | -8                  | 17.0305676855895197 |
| 2025-03-01        | -7                  | 19.6506550218340611 |
| 2025-03-01        | -6                  | 14.4104803493449782 |
| 2025-03-01        | -5                  | 17.9039301310043668 |
| 2025-03-01        | -4                  | 20.5240174672489083 |
| 2025-03-01        | -3                  | 23.5807860262008734 |
| 2025-03-01        | -2                  | 20.5240174672489083 |
| 2025-03-01        | -1                  | 14.8471615720524017 |
| 2025-03-01        | 0                   | 20.5240174672489083 |
| 2025-03-01        | 1                   | 21.3973799126637555 |
| 2025-03-01        | 2                   | 18.3406113537117904 |
| 2025-03-01        | 3                   | 18.3406113537117904 |
| 2025-03-01        | 4                   | 14.8471615720524017 |
| 2025-03-01        | 5                   | 22.2707423580786026 |
| 2025-03-01        | 6                   | 20.0873362445414847 |
| 2025-03-01        | 7                   | 15.2838427947598253 |
| 2025-04-01        | -12                 | 4.6153846153846154  |
| 2025-04-01        | -11                 | 16.9230769230769231 |
| 2025-04-01        | -10                 | 17.4358974358974359 |
| 2025-04-01        | -9                  | 21.0256410256410256 |
| 2025-04-01        | -8                  | 22.0512820512820513 |
| 2025-04-01        | -7                  | 19.4871794871794872 |
| 2025-04-01        | -6                  | 25.1282051282051282 |
| 2025-04-01        | -5                  | 16.4102564102564103 |
| 2025-04-01        | -4                  | 15.3846153846153846 |
| 2025-04-01        | -3                  | 17.9487179487179487 |
| 2025-04-01        | -2                  | 21.5384615384615385 |
| 2025-04-01        | -1                  | 16.4102564102564103 |
| 2025-04-01        | 0                   | 17.9487179487179487 |
| 2025-04-01        | 1                   | 17.4358974358974359 |
| 2025-04-01        | 2                   | 19.4871794871794872 |
| 2025-04-01        | 3                   | 17.4358974358974359 |
| 2025-04-01        | 4                   | 22.5641025641025641 |
| 2025-04-01        | 5                   | 16.4102564102564103 |
| 2025-04-01        | 6                   | 11.2820512820512821 |
| 2025-05-01        | -13                 | 7.1794871794871795  |
| 2025-05-01        | -12                 | 13.3333333333333333 |
| 2025-05-01        | -11                 | 22.5641025641025641 |
| 2025-05-01        | -10                 | 19.4871794871794872 |
| 2025-05-01        | -9                  | 20.0000000000000000 |
| 2025-05-01        | -8                  | 15.3846153846153846 |
| 2025-05-01        | -7                  | 21.0256410256410256 |
| 2025-05-01        | -6                  | 18.9743589743589744 |
| 2025-05-01        | -5                  | 21.0256410256410256 |
| 2025-05-01        | -4                  | 15.3846153846153846 |
| 2025-05-01        | -3                  | 18.4615384615384615 |
| 2025-05-01        | -2                  | 20.5128205128205128 |
| 2025-05-01        | -1                  | 16.9230769230769231 |
| 2025-05-01        | 0                   | 16.9230769230769231 |
| 2025-05-01        | 1                   | 18.9743589743589744 |
| 2025-05-01        | 2                   | 23.0769230769230769 |
| 2025-05-01        | 3                   | 18.4615384615384615 |
| 2025-05-01        | 4                   | 18.9743589743589744 |
| 2025-05-01        | 5                   | 10.2564102564102564 |
| 2025-06-01        | -14                 | 7.1428571428571429  |
| 2025-06-01        | -13                 | 18.1318681318681319 |
| 2025-06-01        | -12                 | 16.4835164835164835 |
| 2025-06-01        | -11                 | 19.2307692307692308 |
| 2025-06-01        | -10                 | 19.2307692307692308 |
| 2025-06-01        | -9                  | 18.1318681318681319 |
| 2025-06-01        | -8                  | 23.6263736263736264 |
| 2025-06-01        | -7                  | 20.8791208791208791 |
| 2025-06-01        | -6                  | 17.5824175824175824 |
| 2025-06-01        | -5                  | 19.7802197802197802 |
| 2025-06-01        | -4                  | 19.2307692307692308 |
| 2025-06-01        | -3                  | 17.0329670329670330 |
| 2025-06-01        | -2                  | 22.5274725274725275 |
| 2025-06-01        | -1                  | 20.3296703296703297 |
| 2025-06-01        | 0                   | 17.5824175824175824 |
| 2025-06-01        | 1                   | 16.4835164835164835 |
| 2025-06-01        | 2                   | 19.7802197802197802 |
| 2025-06-01        | 3                   | 19.7802197802197802 |
| 2025-06-01        | 4                   | 10.4395604395604396 |
| 2025-07-01        | -15                 | 7.8431372549019608  |
| 2025-07-01        | -14                 | 19.6078431372549020 |
| 2025-07-01        | -13                 | 17.6470588235294118 |
| 2025-07-01        | -12                 | 20.0980392156862745 |
| 2025-07-01        | -11                 | 25.9803921568627451 |
| 2025-07-01        | -10                 | 15.6862745098039216 |
| 2025-07-01        | -9                  | 18.1372549019607843 |
| 2025-07-01        | -8                  | 23.0392156862745098 |
| 2025-07-01        | -7                  | 17.1568627450980392 |
| 2025-07-01        | -6                  | 18.1372549019607843 |
| 2025-07-01        | -5                  | 16.6666666666666667 |
| 2025-07-01        | -4                  | 18.1372549019607843 |
| 2025-07-01        | -3                  | 15.1960784313725490 |
| 2025-07-01        | -2                  | 16.6666666666666667 |
| 2025-07-01        | -1                  | 24.0196078431372549 |
| 2025-07-01        | 0                   | 19.6078431372549020 |
| 2025-07-01        | 1                   | 17.6470588235294118 |
| 2025-07-01        | 2                   | 12.7450980392156863 |
| 2025-07-01        | 3                   | 11.2745098039215686 |
| 2025-08-01        | -16                 | 3.9603960396039604  |
| 2025-08-01        | -15                 | 23.2673267326732673 |
| 2025-08-01        | -14                 | 17.8217821782178218 |
| 2025-08-01        | -13                 | 20.2970297029702970 |
| 2025-08-01        | -12                 | 13.8613861386138614 |
| 2025-08-01        | -11                 | 23.7623762376237624 |
| 2025-08-01        | -10                 | 18.8118811881188119 |
| 2025-08-01        | -9                  | 13.8613861386138614 |
| 2025-08-01        | -8                  | 19.8019801980198020 |
| 2025-08-01        | -7                  | 14.3564356435643564 |
| 2025-08-01        | -6                  | 14.3564356435643564 |
| 2025-08-01        | -5                  | 13.8613861386138614 |
| 2025-08-01        | -4                  | 22.2772277227722772 |
| 2025-08-01        | -3                  | 14.8514851485148515 |
| 2025-08-01        | -2                  | 14.3564356435643564 |
| 2025-08-01        | -1                  | 19.8019801980198020 |
| 2025-08-01        | 0                   | 20.2970297029702970 |
| 2025-08-01        | 1                   | 17.8217821782178218 |
| 2025-08-01        | 2                   | 17.3267326732673267 |

**/


------------------------------------------
-- Decrease wait days -> increase revenue?
------------------------------------------
WITH revenue_per_customer AS (
  SELECT
    customer_id,
    SUM(final_net_revenue_usd) AS total_revenue
  FROM combined
  WHERE event_type = 'invoice'
  GROUP BY customer_id
)
SELECT
  CASE 
    WHEN cf.wait_days = 1 THEN '1-day cycle'
    WHEN cf.wait_days = 2 THEN '2-day cycle'
    WHEN cf.wait_days = 3 THEN '3-day cycle'
    WHEN cf.wait_days = 4 THEN '4-day cycle'
    ELSE 'Other'
  END AS cycle_group,
  AVG(rpc.total_revenue) AS avg_revenue
FROM customers_final cf
JOIN revenue_per_customer rpc
  ON cf.customer_id = rpc.customer_id
WHERE cf.is_repeater = TRUE
GROUP BY cycle_group;



-- Check distribution
WITH revenue_per_customer AS (
  SELECT
    customer_id,
    SUM(final_net_revenue_usd) AS total_revenue
  FROM combined
  WHERE event_type = 'invoice'
  GROUP BY customer_id
)
SELECT wait_days, COUNT(*) AS customer_count, AVG(total_revenue) AS avg_revenue
FROM customers_final cf
JOIN revenue_per_customer rpc
  ON cf.customer_id = rpc.customer_id
WHERE cf.is_repeater = TRUE
GROUP BY wait_days
ORDER BY wait_days;



| wait_days | customer_count | avg_revenue      |
| --------- | -------------- | ---------------- |
| 0         | 3429           | 2580.25086030913 |
| 1         | 1              | 1707.45          |
| 4         | 1              | 1103.28          |
| 8         | 1              | 6269.63          |
| 11        | 2              | 1094.555         |
| 12        | 1              | 114              |
| 14        | 1              | 712.4            |
| 16        | 1              | 360.7            |
| 19        | 1              | 2568.1           |
| 20        | 1              | 445.55           |
| 21        | 1              | 5748.32          |
| 22        | 1              | 1202.47          |
| 27        | 1              | 4142.46          |
| 28        | 1              | 1807.08          |
| 35        | 1              | 44.88            |
| 36        | 2              | 2096.525         |
| 38        | 3              | 2617.46666666667 |
| 44        | 1              | 36               |
| 47        | 1              | 404.51           |
| 51        | 2              | 2919.695         |
| 61        | 1              | 16.6             |
| 64        | 1              | 1038.43          |
| 71        | 2              | 104.395          |
| 72        | 1              | 3162.7           |
| 73        | 1              | 197              |
| 78        | 1              | 1729.26          |
| 80        | 1              | 468.02           |
| 85        | 1              | 292.61           |
| 88        | 1              | 488.38           |
| 92        | 1              | 7345.55          |
| 97        | 2              | 613.455          |
| 99        | 1              | 1992.74          |
| 123       | 1              | 253.2            |
| 130       | 1              | 1602.58          |
| 136       | 1              | 3831.57          |
| 148       | 1              | 4792.2           |
| 149       | 1              | 9456.65          |
| 165       | 1              | 2143.92          |
| 166       | 3              | 1124.57          |
| 175       | 1              | 82.48            |
| 178       | 1              | 2133.77          |
| 183       | 1              | 352.46           |
| 186       | 1              | 153.28           |
| 194       | 1              | 3781.75          |
| 195       | 1              | 281.94           |
| 197       | 1              | 173.58           |
| 204       | 1              | 679.35           |
| 206       | 1              | 148.6            |
| 209       | 1              | 132.11           |
| 230       | 1              | 350.91           |
| 231       | 1              | 161.7            |
| 235       | 1              | 5075.32          |
| 240       | 1              | 496.31           |
| 252       | 1              | 511.75           |
| 253       | 1              | 1335             |
| 264       | 1              | 305.73           |
| 282       | 1              | 32.1             |
| 288       | 1              | 195              |
| 295       | 1              | 339.9            |
| 322       | 1              | 47.12            |
| 355       | 1              | 94.04            |
| 373       | 1              | 683.25           |
| 442       | 1              | 341.71           |
| null      | 3              | 382.226666666667 |



-- Revenue per customer by billing_cycle

SELECT 
billing_cycle,
SUM (final_net_revenue_usd) revenue,
COUNT(DISTINCT customer_id) count_customers,
SUM (final_net_revenue_usd)/ COUNT(DISTINCT customer_id) as revenue_per_customer
FROM combined
WHERE event_date > '2024-12-31'
GROUP BY billing_cycle

;
/**
| billing_cycle | revenue    | count_customers | revenue_per_customer |
| ------------- | ---------- | --------------- | -------------------- |
| Annual        | 4412466.98 | 3853            | 1145.20295354269     |
| Monthly       | 450055.83  | 3832            | 117.446719728601     |
| One-time      | 123669.78  | 465             | 265.956516129032     |
**/


-- Does pricing have an impact on revenues 
-- Knowing that US, UK and Canada are the top revenue drivers
-- Pricing by product and country Result: No impact

SELECT product_name, country,
AVG (base_price_usd) as average_price
FROM combined
WHERE country in ('United States', 'United Kingdom', 'Canada') 
AND product_name in ('Azure AI Studio Annual Standard','Notion AI Annual', 'Figma Professional Monthly')
GROUP BY product_name, country
ORDER BY product_name, average_price DESC
LIMIT 10;

/**
| product_name                    | country        | average_price    |
| ------------------------------- | -------------- | ---------------- |
| Azure AI Studio Annual Standard | United Kingdom | 316.27           |
| Azure AI Studio Annual Standard | Canada         | 316.27           |
| Azure AI Studio Annual Standard | United States  | 316.269999999999 |
| Figma Professional Monthly      | United Kingdom | 15               |
| Figma Professional Monthly      | Canada         | 15               |
| Figma Professional Monthly      | United States  | 15               |
| Notion AI Annual                | United Kingdom | 118.1            |
| Notion AI Annual                | Canada         | 118.1            |
| Notion AI Annual                | United States  | 118.1            |
**/


SELECT * FROM information_schema.tables
WHERE
    table_schema NOT IN ('pg_catalog', 'information_schema', 'auth', 'storage', 'extensions')
    AND table_type = 'BASE TABLE';



SELECT
    tc.table_schema AS dependent_schema,
    tc.table_name AS dependent_table,
    ccu.table_schema AS dependency_schema,
    ccu.table_name AS dependency_table
FROM
    information_schema.table_constraints AS tc
    JOIN information_schema.constraint_column_usage AS ccu
      ON ccu.constraint_name = tc.constraint_name
WHERE
    tc.constraint_type = 'FOREIGN KEY'
    -- Filtering out known Supabase system schemas
    AND tc.table_schema NOT IN ('pg_catalog', 'information_schema', 'auth', 'storage', 'extensions', 'vault', 'realtime');

/**
| dependent_schema | dependent_table | dependency_schema | dependency_table |
| ---------------- | --------------- | ----------------- | ---------------- |
| public           | events_raw      | public            | products_raw     |
| public           | events_raw      | public            | customers_raw    |
Dependency tables are the source, dependent table is the table name.
**/SELECT * FROM information_schema.tables
WHERE
    table_schema NOT IN ('pg_catalog', 'information_schema', 'auth', 'storage', 'extensions')
    AND table_type = 'BASE TABLE';



