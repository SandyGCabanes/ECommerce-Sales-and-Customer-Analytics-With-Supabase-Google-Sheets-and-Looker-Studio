# Ecommerce Sales and Customer Analytics 
## Analyst's Report for Main Stakeholders

# Overview  
- Total Revenue is up and healthy, and monthly revenue is stable at around 500k.
![Monthly Revenue](https://github.com/SandyGCabanes/ECommerce-Sales-and-Customer-Analytics-With-Supabase-Google-Sheets-and-Looker-Studio/blob/main/assets/Overview_Bar%20chart.png)
- Strong momentum in non-US markets like Canada, Germany and Australia can help jumpstart new revenue and offset UK softening.
![Country Revenue](https://github.com/SandyGCabanes/ECommerce-Sales-and-Customer-Analytics-With-Supabase-Google-Sheets-and-Looker-Studio/blob/main/assets/Country_Revenue.png)
- Revenue growth is being driven almost entirely by repeat customers.  (96% to 98% of monthly revenue.)  Need to protect loyal customers.
![Repeat Revenue](https://github.com/SandyGCabanes/ECommerce-Sales-and-Customer-Analytics-With-Supabase-Google-Sheets-and-Looker-Studio/blob/main/assets/Repeat%20Customers_Bar%20chart.png)
- Annual plans deliver far higher value per customer vs. Monthly. <br>
  This needs to be prioritized. <br><br>
![Annual vs. Monthly](https://github.com/SandyGCabanes/ECommerce-Sales-and-Customer-Analytics-With-Supabase-Google-Sheets-and-Looker-Studio/blob/main/assets/Annual_vs_Monthly_30pct_crop.PNG)
<br>

- Attachment rates are slipping and refund losses are rising in several product categories.<br>
  Need to investigate causes to define next steps.<br><br>
![Attachment refunds](https://github.com/SandyGCabanes/ECommerce-Sales-and-Customer-Analytics-With-Supabase-Google-Sheets-and-Looker-Studio/blob/main/assets/attachment_refunds_crop.PNG)

# Insights and Strategic Actions:
| Focus Area         | Data Insight                                                                 | Strategic Action                                                             |
|--------------------|-------------------------------------------------------------------------------|------------------------------------------------------------------------------|
| Repeat Customers   | Repeat customers drive practically all of the revenue<br>and growth.          | Strengthen retention programs using cross-sell insights<br>and targeting early repeat behavior . <br> Evaluate acquisition channels for quality vs. volume.|
| Growth Markets     | Canada, Germany and Australia revenues<br>have promising growth.              | Dive into these markets to grow faster.<br> Explore markets with higher repeat rates.             |
| Annual Plans       | Annual Billing brings in far more money<br>per customer than Monthly.         | Expand annual plan offerings and <br>optimize conversion flows.                        |
| Product Attachment | Add-on attachment rate is dropping<br>4.5 percent across total plans.         | Rebuild attachment rate through targeted <br>cross-sell and bundling.          |
| Refunds            | Refunds are rising in Developer Tools, Design,<br>AI Tools, Analytics, AI Productivity, and more,<br>adding up to $348K this year. | Investigate hihg-refund product lines and <br>address root causes. |


# Technical Foundation 
- Revenue integrity was established by isolating non‑refunded invoices as the only source of confirmed revenue.  
- All dates were standardized to month‑start to ensure consistent time‑series aggregation.  
- Window functions were used to identify repeat customers and compute wait_days.  
- A unified semantic layer was created by joining cleaned event, customer, and product views.  
- This layer feeds the Looker Studio dashboard, which is organized into Overview, Repeat Customers, Products, and Sales Details.


---
# Appendix: Technical Discussion for Technical Stakeholders
## 0. Pre-Work: Cleaning data in SQL
Checked for duplicates, blanks, strange fonts from raw stage(staging) to views (intermediate).

## Phase 1: Solving Key SQL Problems - The Data Set-Up

- [SQL scripts used in Supabase for set-up](sql/supabase_scripts_setup.sql)
  
A. Data Integrity: Defining Real Revenue
- Not all Orders proceed to Invoices, and most Invoices do not even pass through Orders stage. 
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
  
## Phase 2: The Strategic Insights From the Looker Studio Dashboard
- After combining the Views into a final semantic layer, csv file can be exported from Supabase and imported it into Google Sheets.
- Dashboard here uses Google Looker Studio visualizations.
- Four pages in the dashboard: Overview, Repeat Customers, Products and Sales Details. [Click to see Looker Studio Dashboard. 60 second loading time.](https://lookerstudio.google.com/s/rGCRCcqr8rs)
- Dashboard demo:
- ![Dashboard demo](https://github.com/SandyGCabanes/ECommerce-Sales-and-Customer-Analytics-With-Supabase-Google-Sheets-and-Looker-Studio/blob/main/assets/output_20260206_75pct.gif)
<br><br>
- [Overview](assets/page1_overview.PNG)
- [Repeat Customers](assets/page2_repeat_customers.PNG)
- [Products](assets/page3_products.PNG)
- [Sales](assets/page4_sales.PNG)

# Tools: Supabase (Postgres SQL), Google Sheets, Google Looker Studio  

[Click Here for the Dataset](https://datadna.onyxdata.co.uk/challenges/november-2025-datadna-ecommerce-analytics-challenge/)


## Key takeaways:
- Total revenue is up, driven by repeat customers.
- Monthly revenue is levelling off, so high-momentum regions can be explored.
- Separately, the business needs to ensure that repeat customers do not churn.
- Future growth will come from stronger annual plan sales, diving into growth markets, maximizing acquisition channels, regaining attachment rate and fixing the rising refund problem.

