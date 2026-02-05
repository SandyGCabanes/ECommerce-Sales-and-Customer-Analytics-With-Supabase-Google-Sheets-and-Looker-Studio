# Ecommerce Sales and Customer Analytics 
## Tools: Supabase (Postgres SQL), Google Sheets, Google Looker Studio  
[Click Here for the Dataset](https://datadna.onyxdata.co.uk/challenges/november-2025-datadna-ecommerce-analytics-challenge/)

# Overview  
- Revenue growth is being driven almost entirely by repeat customers.  Need to protect this revenue stream with loyalty boosting efforts.
- Monthly revenue is levelling off. Strong momentum in key markets like Germany and Australia can help jumpstart new revenue.
- Annual plans deliver far higher value per customer. This needs to be prioritized.
- Attachment rates for add‑ons are slipping and refund losses are rising in several product categories.  Need to investigate causes to craft next steps.
- In terms of process: This report establishes a unified revenue definition as a single source of truth,  so that teams see consistent numbers across the dashboard.

# Key Insights
- ![Insights and Actions Table](assets/6.focus_areas.PNG)

- [Dashboards Section](#dashboards)


# Technical Foundation 
- Revenue integrity was established by isolating non‑refunded invoices as the only source of confirmed revenue.  
- All dates were standardized to month‑start to ensure consistent time‑series aggregation.  
- Window functions were used to identify repeat customers and compute wait_days.  
- A unified semantic layer was created by joining cleaned event, customer, and product views.  
- This layer feeds the Looker Studio dashboard, which is organized into Overview, Repeat Customers, Products, and Sales Details.

# Strategic Actions  
- Strengthen retention programs targeting early repeat behavior.  
- Expand annual plan offerings and optimize conversion flows.  
- Investigate high‑refund product lines and address root causes.  
- Rebuild attachment rate through targeted cross‑sell and bundling.  
- Evaluate acquisition channels for quality rather than volume.  
- Explore growth markets where repeat behavior is strongest.

---
# Appendix: Technical Discussion  
## 0. Pre-Work: Cleaning data in SQL
Checked for duplicates, blanks, strange fonts from raw stage(staging) to views (intermediate).

## Phase 1: Solving Key SQL Problems - The Data Set-Up

- [SQL scripts used in Supabase for set-up](sql/supabase_scripts_setup.sql)
  
A. Data Integrity: Defining Real Revenue
- A common complaint is that dashboards do not contain correct information. Not all Orders proceed to Invoices, and most Invoices do not even pass through Orders stage. 

```
| category            | cnt   |
| ------------------- | ----- |
| orders_not_proceed  | 33482 |
| invoices_not_orders | 14280 |
| orders_proceed      | 119   | 
```
- To provide a Single Source of Truth and accurate Sales figures, only invoice data are pulled if they are not refunded. This is added as another field.
  
```
-- SQL pulls in only invoices 
--  Removes anything that is not confirmed revenue
ALTER TABLE events_raw
ADD COLUMN final_net_revenue_usd float;

UPDATE events_raw
SET final_net_revenue_usd =
    CASE 
        WHEN event_type = 'invoice' AND is_refunded = FALSE 
        THEN net_revenue_usd
        ELSE 0
    END; 
 ```


B. Data Integrity: Cleaning Up Time Series
- Monthly standardization was needed for the dashboard, especially for monthly revenue.
```
-- SQL year_month column
-- Adding a column and populating it with the first day of the month 
-- Using DATE_TRUNC to enable accurate time-series trending

ALTER TABLE events_raw
ADD COLUMN year_month date;

UPDATE events_raw
SET year_month = DATE_TRUNC('month', event_date)::date;      
```


C. Metric Creation: Spotting Repeat Customers
- To track loyalty, this SQL script defines the flag for repeat customers by tracking who was buying more than once, using window functions.
- The idea is check the purchase events of each customer and a repeater is someone who had a second purchase ever.
- Here, ROW_NUMBER() + OVER() is used to flag repeat customers where row number = 2.

```
-- SQL Action: Marking repeat customers
-- Joining the days_since_last_invoice from previous events_final_new view to customers_raw
-- Using Window Functions to identify customer's purchase order

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
```

D. Performance: Building The Final View as SSOT
- Finally, all clean data views (intermediate) for each of the initial tables into one simple View (mart)for the dashboard.

```
-- SQL Action: Creating the final semantic layer
CREATE OR REPLACE VIEW combined AS
SELECT
  -- event-level (bring all columns from events_final_new)
  efn.*,

  -- customer-level columns (aliased to avoid collisions)
  c.customer_id            AS customer_id_c,
  -- all other fields
  -- plus new fields defined in views:
  c.wait_days,
  c.is_repeater,
  c.signup_year_month,

  -- product-level columns (aliased to avoid collisions)
  p.product_id             AS product_id_p,
  p.product_name,
  -- plus all other fields
FROM events_final_new efn
LEFT JOIN customers_final c
  ON efn.customer_id = c.customer_id
LEFT JOIN products_final p
  ON efn.product_id = p.product_id;    
```

E. Preliminary Exploration of Monthly Revenue
- Now with the combined view, true monthly revenue can be analyzed. 
- The SQL figures showed that these have levelled off at around 500K per month.
```
-- Monthly revenue

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

```
Preliminary analysis was also done in Postgres SQL in Supabase. 

- [SQL scripts used in Supabase for preliminary analysis ](sql/supabase_scripts_analysis.sql) 
- [Back to top](#summary)

  
## Phase 2: The Strategic Insights From the Looker Studio Dashboard
- After combining the Views into a final semantic layer, csv file can be exported from Supabase and imported it into Google Sheets.
- Dashboard here uses Google Looker Studio visualizations.
- Four pages in the dashboard: Overview, Repeat Customers, Products and Sales Details.
- 
  ### Dashboards
- ![Overview](assets/page1_overview.PNG)
- ![Repeat Customers](assets/page2_repeat_customers.PNG)
- ![Products](assets/page3_products.PNG)
- ![Sales](assets/page4_sales.PNG)
[Back to top - Technical Foundation](#technical-foundation)

- Recap of the key Data Insights and the Strategic Actions.

- ![Insights and Actions Table](assets/6.focus_areas.PNG)

## Key takeaways:
- Total revenue is up, driven by repeat customers.
- Monthly revenue is levelling off, so high-momentum regions can be explored.
- Separately, the business needs to ensure that repeat customers do not churn.
- Future growth will come from stronger annual plan sales, diving into growth markets, maximizing acquisition channels, regaining attachment rate and fixing the rising refund problem.

