/*
===============================================================================
                    MONTHLY SALES ANALYSIS
===============================================================================
Purpose:
- Analyze monthly sales performance.
- Track the number of unique customers and total quantity sold.
- Identify monthly trends in sales and customer activity.
*/

SELECT
YEAR (order_date) as order_year,
MONTH (order_date) as order_month, SUM (sales_amount) as total_Sales,
COUNT (DISTINCT customer_key) as total_customers,
SUM (quantity) as total_quantity
FROM  [gold.fact_sales]
WHERE order_date IS NOT NULL
GROUP BY YEAR (order_date), MONTH(order_date)
ORDER BY YEAR (order_date), MONTH(order_date);


/*
===============================================================================
                    MONTHLY SALES USING DATETRUNC
===============================================================================
Purpose:
- Group sales transactions by month.
- Calculate total sales, unique customers, and quantity sold.
- Represent each month using its starting date.
*/

SELECT
DATETRUNC(month,order_date) as order_date,
SUM(sales_amount)as total_sales,
COUNT (DISTINCT customer_key) as total_customers,
SUM (quantity) as total_quantity
FROM  [gold.fact_sales]
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(MONTH,order_date)
ORDER BY DATETRUNC(MONTH,order_date);


/*
===============================================================================
                    YEARLY SALES ANALYSIS
===============================================================================
Purpose:
- Calculate yearly sales performance.
- Measure the number of unique customers and total quantity sold.
- Compare business performance across different years.
*/

--What were our yearly sales, number of customers, and total quantity sold?--
SELECT
    YEAR(order_date) AS order_year,
    SUM(sales_amount) AS total_sales,
    COUNT(DISTINCT customer_key) AS total_customers,
    SUM(quantity) AS total_quantity
FROM [gold.fact_sales]
WHERE order_date IS NOT NULL
GROUP BY YEAR(order_date)
ORDER BY YEAR(order_date);


/*
===============================================================================
                    SALES ANALYSIS BY MONTH
===============================================================================
Purpose:
- Analyze sales performance across the months of the year.
- Compare customer activity and quantity sold for each month.
- Identify seasonal patterns in business performance.
*/

--For months--
SELECT
    MONTH(order_date) AS order_year,
    SUM(sales_amount) AS total_sales,
    COUNT(DISTINCT customer_key) AS total_customers,
    SUM(quantity) AS total_quantity
FROM [gold.fact_sales]
WHERE order_date IS NOT NULL
GROUP BY MONTH(order_date)
ORDER BY MONTH(order_date);


/*
===============================================================================
                    CUMULATIVE SALES ANALYSIS
===============================================================================
Purpose:
- Calculate total sales for each month.
- Use a window function to calculate cumulative sales.
- Track the progression of total sales over time.
*/

--Cumulative analysis--
--Calculate the total sales per month--
SELECT order_date,
total_sales,
SUM(total_sales)OVER (ORDER BY order_date) AS running_total_sales
FROM 
(
SELECT 
DATETRUNC(month, order_date) AS order_date,
SUM(sales_amount) AS total_sales
FROM [gold.fact_sales]
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(month,order_date)
)
AS monthly_sales;


/*
===============================================================================
                    MONTHLY SALES AND RUNNING TOTAL
===============================================================================
Purpose:
- Calculate monthly sales using a derived table.
- Calculate the running total with a window function.
- Compare individual monthly sales with cumulative sales.
*/

-- Find the monthly sales and the running total of sales over time
SELECT
    order_date,
    total_sales,
    SUM(total_sales) OVER (ORDER BY order_date) AS running_total_sales
FROM
(
    SELECT
    DATETRUNC(MONTH, order_date) AS order_date,
    SUM(sales_amount) AS total_sales
    FROM [gold.fact_sales]
    WHERE order_date IS NOT NULL
    GROUP BY DATETRUNC(MONTH, order_date)
) AS monthly_sales
ORDER BY order_date;


/*
===============================================================================
                    PRODUCT PERFORMANCE ANALYSIS
===============================================================================
Purpose:
- Calculate yearly sales for each product.
- Compare yearly sales with the product's average sales.
- Identify differences between current and average performance.
- Retrieve previous year's sales for comparison.

SQL Concepts:
- Common Table Expressions (CTEs)
- LEFT JOIN
- Aggregate functions
- Window functions
- CASE WHEN
- LAG()
*/

WITH yearly_product_sales AS
(
SELECT 
YEAR(f.order_date) AS order_year,
p.product_name,
SUM(f.sales_amount) AS current_sales
FROM [gold.fact_sales] f
LEFT JOIN [gold.dim_products] p
ON f.product_key = p.product_key 
WHERE f.order_date IS NOT NULL
GROUP BY
YEAR(f.order_date),
p.product_name
)
SELECT
order_year,
product_name,
current_sales,
AVG(current_sales) OVER (PARTITION BY product_name) avg_sales,
current_sales - AVG(current_sales) OVER (PARTITION BY product_name) AS diff_avg,
CASE WHEN current_sales - AVG(current_sales) OVER (PARTITION BY product_name) > 0 THEN 'Above AVG'
     WHEN current_sales - AVG(current_sales) OVER (PARTITION BY product_name) < 0 THEN 'Below AVG'
     ELSE 'Avg'
     END avg_change,
LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) py_sales
FROM yearly_product_sales
ORDER BY product_name,order_year;


/*
===============================================================================
                    CATEGORY SALES CONTRIBUTION
===============================================================================
Purpose:
- Calculate total sales for each product category.
- Compare category-level sales with overall sales.
- Calculate the percentage contribution of each category.
- Rank categories by total sales.

SQL Concepts:
- Common Table Expressions (CTEs)
- LEFT JOIN
- SUM() OVER()
- CAST()
- ROUND()
*/

WITH category_sales AS
(
SELECT 
category,
SUM(sales_amount) total_sales
FROM [gold.fact_sales] f
LEFT JOIN [gold.dim_products] p
ON p.product_key = f.product_key
GROUP BY category)

SELECT 
category,
total_sales,
SUM(total_sales) OVER () overall_sales,
ROUND(
CAST(total_sales AS float) / SUM(total_sales) OVER () * 100,
2
) as Percentage_of_total
FROM category_sales
ORDER BY total_sales DESC;


/*
===============================================================================
                    PRODUCT COST SEGMENTATION
===============================================================================
Purpose:
- Categorize products according to their cost ranges.
- Count the number of products within each segment.
- Identify the distribution of products across cost categories.

SQL Concepts:
- Common Table Expressions (CTEs)
- CASE WHEN
- COUNT()
- GROUP BY
*/

WITH product_segments AS (
SELECT 
product_key,
product_name,
cost, 
CASE WHEN cost < 100 THEN 'Below'
     WHEN cost BETWEEN 100 AND 500 THEN '100-500'
     WHEN cost BETWEEN 500 AND 1000 THEN '500-1000'
     ELSE 'Above 1000'
END cost_range 
FROM [gold.dim_products])

SELECT 
cost_range,
COUNT(product_key) AS total_products
FROM product_segments
GROUP BY cost_range
ORDER BY total_products DESC;


/*
===============================================================================
                    CUSTOMER SPENDING SEGMENTATION
===============================================================================
Purpose:
- Calculate total spending for each customer.
- Identify the first and last order dates.
- Calculate the duration of each customer's purchasing activity.
- Classify customers into VIP, Regular, and New segments.
- Count customers within each segment.

Segmentation Criteria:
- VIP: Customer lifespan is at least 12 months and spending exceeds 5000.
- Regular: Customer lifespan is at least 12 months and spending is 5000 or less.
- New: Customers who do not meet the above criteria.

SQL Concepts:
- Common Table Expressions (CTEs)
- LEFT JOIN
- SUM(), MIN(), MAX()
- DATEDIFF()
- CASE WHEN
- GROUP BY
*/

WITH customer_spending AS
(
 SELECT 
 c.customer_key,
 SUM(f.sales_amount) AS total_spending,
 MIN(order_date) AS first_order,
 MAX(order_date) AS last_order,
 DATEDIFF (month,MIN(order_date),MAX(order_date) ) AS lifespan
 FROM [gold.fact_sales] f
 LEFT JOIN [gold.dim_customers] c
 ON f.customer_key = c.customer_key  
 GROUP BY c.customer_key
 )
 SELECT 
 customer_segment,
 COUNT(customer_key) AS total_customers
 FROM (
 SELECT 
 customer_key,
 CASE
      WHEN lifespan >= 12 AND total_spending > 5000 THEN 'VIP'
      WHEN lifespan >= 12 AND total_spending <=5000 THEN 'Regular'
      ELSE 'New'
      END customer_segment
 FROM customer_spending ) t
 GROUP BY customer_segment;