# Ecommerce Sales and Customer Analytics 
## Tools: Supabase (Postgres SQL), Google Sheets, Google Looker Studio  
[Click Here for the Dataset](https://datadna.onyxdata.co.uk/challenges/november-2025-datadna-ecommerce-analytics-challenge/)

# Overview  
- Revenue growth is being driven almost entirely by repeat customers.  Need to protect this revenue stream with loyalty boosting efforts.
- Monthly revenue is levelling off. Strong momentum in key markets like Germany and Australia can help jumpstart new revenue.
  ![Monthly Revenue](https://github.com/SandyGCabanes/ECommerce-Sales-and-Customer-Analytics-With-Supabase-Google-Sheets-and-Looker-Studio/blob/main/assets/Ecommerce%20Analytics%20DataDNA_Overview_Bar%20chart.png)
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
- To provide a Single Source of Truth and accurate Sales figures, only invoice data are pulled if they are not refunded. This is added as another field.

B. Data Integrity: Cleaning Up Time Series
- Monthly standardization was needed for the dashboard, especially for monthly revenue.

C. Metric Creation: Spotting Repeat Customers
- To track loyalty, this SQL script defines the flag for repeat customers by tracking who was buying more than once, using window functions.
- The idea is check the purchase events of each customer and a repeater is someone who had a second purchase ever.
- Here, ROW_NUMBER() + OVER() is used to flag repeat customers where row number = 2.


D. Performance: Building The Final View as SSOT
- Finally, all clean data views (intermediate) for each of the initial tables into one simple View (mart)for the dashboard.


E. Preliminary Exploration of Monthly Revenue
- Now with the combined view, true monthly revenue can be analyzed. 
- The SQL figures showed that these have levelled off at around 500K per month.

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

