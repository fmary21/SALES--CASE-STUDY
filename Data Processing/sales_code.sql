------table------
select * from `workspace`.`default`.`sales_case_study_2` limit 100;

-----general checks ------

select count(*)
 from `workspace`.`default`.`sales_case_study_2`
 
 select distinct *
 From sales_case_study_2;
 ---------------------------------------------------------------------------------------------------------------------------------

 -------checking for null values------

 SELECT *
FROM sales_case_study_2
WHERE Date IS NULL
   OR Sales IS NULL
   OR `Cost Of Sales` IS NULL
   OR `Quantity Sold` IS NULL;
------------------------------------------------------------------------------------------------------------
   --------checking for duplicate values--------

   SELECT * FROM sales_case_study_2
   GROUP BY  ALL
   HAVING COUNT(*) > 1

   SELECT *, COUNT(*) AS cnt
FROM `workspace`.`default`.`sales_case_study_2`
GROUP BY Date, Sales, `Cost Of Sales`, `Quantity Sold`
HAVING COUNT(*) > 1;
-------------------------------------------------------------------------------------------------------------------------------------------------

   ----- converting date to ( year, day_name, month_name )-----

SELECT
    TO_DATE(Date, 'MM/dd/yyyy') AS date_converted,
    date_format(TO_DATE(Date, 'MM/dd/yyyy'), 'MMMM') AS month_name,
    date_format(TO_DATE(Date, 'MM/dd/yyyy'), 'EEEE') AS day_name,
    YEAR(TO_DATE(Date, 'MM/dd/yyyy')) AS year_number
FROM `workspace`.`default`.`sales_case_study_2`;
------------------------------------------------------------------------------------------------------------------------------------------------

------------create new columns---------------

select count(*) as total_records,
  sum(case when `Cost Of Sales` > 0 then 1 else 0 end) as total_records_with_cost,
  sum(case when `Cost Of Sales` > 0 then `Cost Of Sales` else 0 end) as total_cost,
  sum(case when `Cost Of Sales` > 0 then `Quantity Sold` else 0 end) as total_quantity_sold
from `workspace`.`default`.`sales_case_study_2`

----------------------------------------------------------------------------------------------------------------------------------------

------ Create a temporary view with calculated metrics
CREATE OR REPLACE TEMP VIEW sales_metrics AS
SELECT
    to_date (Date, 'MM/dd/yyyy') AS sale_date,
    Sales AS revenue,
    `Quantity Sold` AS units_sold,
    `Cost Of Sales` AS cost_of_sales,
    (Sales - `Cost Of Sales`) AS gross_profit,
    ROUND((Sales - `Cost Of Sales`) / Sales * 100, 2) AS gross_profit_pct,
    ROUND((Sales - `Cost Of Sales`) / `Quantity Sold`, 2) AS gross_profit_per_unit,
    ROUND(Sales / `Quantity Sold`, 2) AS unit_price
FROM sales_case_study_2;


--------------------------------------------------------------------------------------------------------------------------------------------

-----------------------------Generating table-----------------------
SELECT
    ------------------ original columns
    Date,
    Sales,
    `Cost Of Sales`,
    `Quantity Sold`,

    -------- date transformations
    YEAR(TO_DATE(Date, 'MM/dd/yyyy')) AS year_number,
    date_format(TO_DATE(Date, 'MM/dd/yyyy'), 'MMMM') AS month_name,
    date_format(TO_DATE(Date, 'MM/dd/yyyy'), 'EEEE') AS day_name,

    -----calculated metrics
    (Sales - `Cost Of Sales`) AS gross_profit,
    ROUND((Sales - `Cost Of Sales`) / Sales * 100, 2) AS gross_profit_pct,
    ROUND((Sales - `Cost Of Sales`) / `Quantity Sold`, 2) AS gross_profit_per_unit,
    ROUND(Sales / `Quantity Sold`, 2) AS unit_price,
    ROUND(AVG(Sales / `Quantity Sold`) OVER (), 2) AS avg_unit_price

FROM sales_case_study_2;

---------------------------------------------------------------------------------------------------------------------
--------------CREATE TABLE sales_case_study_processed AS
SELECT
    -- original columns
    Date,
    Sales,
    `Cost Of Sales`,
    `Quantity Sold`,

    -- date transformations
    TO_DATE(Date, 'MM/dd/yyyy') AS sale_date,
    YEAR(TO_DATE(Date, 'MM/dd/yyyy')) AS year_number,
    date_format(TO_DATE(Date, 'MM/dd/yyyy'), 'MMMM') AS month_name,
    date_format(TO_DATE(Date, 'MM/dd/yyyy'), 'EEEE') AS day_name,

    -- calculated metrics per row
    (Sales - `Cost Of Sales`) AS gross_profit,
    ROUND( try_divide((Sales - `Cost Of Sales`), Sales) * 100, 2 ) AS gross_profit_pct,
    ROUND( try_divide((Sales - `Cost Of Sales`), `Quantity Sold`), 2 ) AS gross_profit_per_unit,
    ROUND( try_divide(Sales, `Quantity Sold`), 2 ) AS unit_price,

    ---------------------------overall average unit price
    ROUND(AVG( try_divide(Sales, `Quantity Sold`) ) OVER (), 2) AS avg_unit_price,

    --------daily unit price
    ROUND(
        try_divide(
            SUM(Sales) OVER (PARTITION BY TO_DATE(Date, 'MM/dd/yyyy')),
            SUM(`Quantity Sold`) OVER (PARTITION BY TO_DATE(Date, 'MM/dd/yyyy'))
        ),
    2) AS daily_unit_price,

    --------- promotion period
    CASE
        WHEN TO_DATE(Date, 'MM/dd/yyyy') BETWEEN DATE('2024-01-01') AND DATE('2024-01-10') THEN 'Period 1'
        WHEN TO_DATE(Date, 'MM/dd/yyyy') BETWEEN DATE('2024-02-01') AND DATE('2024-02-10') THEN 'Period 2'
        WHEN TO_DATE(Date, 'MM/dd/yyyy') BETWEEN DATE('2024-03-01') AND DATE('2024-03-10') THEN 'Period 3'
        ELSE 'No Promo'
    END AS promo_period,

    --------- PRICE ELASTICITY OF DEMAND (PED) - fully wrapped in try_divide

    try_divide(
       ---- %ΔQ numerator
        (
            SUM(`Quantity Sold`) OVER (
                PARTITION BY 
                CASE
                    WHEN TO_DATE(Date, 'MM/dd/yyyy') BETWEEN DATE('2024-01-01') AND DATE('2024-01-10') THEN 'Period 1'
                    WHEN TO_DATE(Date, 'MM/dd/yyyy') BETWEEN DATE('2024-02-01') AND DATE('2024-02-10') THEN 'Period 2'
                    WHEN TO_DATE(Date, 'MM/dd/yyyy') BETWEEN DATE('2024-03-01') AND DATE('2024-03-10') THEN 'Period 3'
                END
            )
            -
            SUM(`Quantity Sold`) OVER (PARTITION BY 'No Promo')
        )
        /
        NULLIF(SUM(`Quantity Sold`) OVER (PARTITION BY 'No Promo'), 0),

        -- %ΔP denominator
        (
            AVG( try_divide(Sales, `Quantity Sold`) ) OVER (
                PARTITION BY 
                CASE
                    WHEN TO_DATE(Date, 'MM/dd/yyyy') BETWEEN DATE('2024-01-01') AND DATE('2024-01-10') THEN 'Period 1'
                    WHEN TO_DATE(Date, 'MM/dd/yyyy') BETWEEN DATE('2024-02-01') AND DATE('2024-02-10') THEN 'Period 2'
                    WHEN TO_DATE(Date, 'MM/dd/yyyy') BETWEEN DATE('2024-03-01') AND DATE('2024-03-10') THEN 'Period 3'
                END
            )
            -
            AVG( try_divide(Sales, `Quantity Sold`) ) OVER (PARTITION BY 'No Promo')
        )
        /
        NULLIF(AVG( try_divide(Sales, `Quantity Sold`) ) OVER (PARTITION BY 'No Promo'), 0)
    ) AS price_elasticity

FROM sales_case_study_2;

---------------------------------------------------------------------------------------------------------------------------
