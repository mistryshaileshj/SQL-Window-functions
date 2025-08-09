
--select * from branchsales

--drop table branchsales

--Alter table branchsales alter column UnitPrice numeric(10, 2)
--Alter table branchsales alter column Quantity int
--Alter table branchsales alter column Tax5_Perc numeric(5, 2)
--Alter table branchsales alter column Sales numeric(10, 2)
--Alter table branchsales alter column InvTime datetime
--Alter table branchsales alter column cogs numeric(10, 2)
--Alter table branchsales alter column GrossMarginPerc numeric(10, 2)
--Alter table branchsales alter column GrossIncome numeric(10, 2)
--Alter table branchsales alter column Rating numeric(10, 2)

--Query - 1
--**Business Case: Track cumulative revenue growth for financial reporting
--This query is useful for retrieving daily sales from the table and calculating a running total of sales using a window function (SUM() OVER). 
--It orders the results chronologically by invdate and accumulates the sales from the start of the dataset up to each row (UNBOUNDED PRECEDING TO CURRENT ROW).
SELECT
    invdate,
    sales,
    SUM(sales) OVER (ORDER BY invdate ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) as running_total
FROM branchsales
ORDER BY invdate;


--Query - 2
--This query is an extension to the above which gives row wise total based on year and month after sorting the resultset
with cte as
(
	Select 
	year(invdate) Yr, month(invdate) Mth
	,cast(year(invdate) as varchar(5)) + '-' + SUBSTRING(datename(month, invdate), 1, 3) Year_Month
	, Sum(Sales) Sales 
	from branchsales 
	group by year(invdate), month(invdate), cast(year(invdate) as varchar(5)) + '-' + SUBSTRING(datename(month, invdate), 1, 3)
)
--select * from cte

SELECT yr, Mth, Year_month
	, sales
    ,Sum(sales) OVER (ORDER BY yr, mth ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) as running_total
FROM cte
ORDER BY yr, mth

--Query - 3
--This query ranks payment records from the sales table based on sales amount in descending order using two window functions: 
--RANK() and DENSE_RANK(). 
--While RANK() leaves gaps when there are ties in sales (e.g., ranks: 1, 1, 3)
--DENSE_RANK() fills those gaps (e.g., 1, 1, 2). 
--This is perfect for leaderboard-style reporting where you want to evaluate top-performing customers or payment types without losing positional context.
SELECT
    Payment,
    sales,
    RANK() OVER (ORDER BY sales DESC) as customer_rank,
    DENSE_RANK() OVER (ORDER BY sales DESC) as dense_rank
FROM branchsales;


--Query - 4
--Monitoring short-term sales performance for a specific period
--This query calculates a 7-day moving average of sales from the branchsales table, focusing on dates between Jan 1 and Jan 15, 2019. 
--Using the AVG() OVER window function, it looks at each row and the six preceding rows (a 7-day window including the current day) to compute a rolling average. 
--If your data has missing dates, you might want to:
---> Create a date calendar CTE
---> Join to ensure no skipped days
---> Use RANGE BETWEEN instead of ROWS if you want to calculate over actual date ranges, not just prior rows
SELECT
    InvDate,
    sales,
    AVG(sales) OVER (
        ORDER BY invdate
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) as seven_day_moving_avg
FROM branchsales
where InvDate >= '01/01/2019' and InvDate <= '01/15/2019'
order by InvDate


--Query - 5
--This query gives you the percentage of total sales against each payment type
--This query uses common table expressions (CTEs) to first compute:
--payment_summary: total sales by each Payment type.
--overall_total: the grand total of all sales.
--In the final SELECT, it combines the two using a CROSS JOIN to calculate each payment type’s percentage contribution to the total sales (pct_of_total).
--A solid use case for generating payment method performance breakdowns — great for dashboards, strategy decks, or identifying which channels drive the most revenue.
WITH productline_summary AS (
    SELECT
        ProductLine,
        SUM(Sales) AS total_sales
    FROM branchsales
    GROUP BY ProductLine
),
overall_total AS (
    SELECT SUM(Sales) AS grand_total FROM branchsales
)
SELECT
    p.ProductLine,
    p.total_sales,
    p.total_sales * 100 / o.grand_total AS pct_of_total
FROM productline_summary p
CROSS JOIN overall_total o;

--Query - 6
--This query provides the first and last sale date for a customer.
--It helps you to check the customer lifecycle and helps to gauge a customer buying behaviour and assist in customer retention analysis
--When did this customer first engage with our brand ?
--What’s the lifecycle length? (Last_SaleDt - First_SaleDt) ?
--What is the total bill count for a customer ?
SELECT
    customerid,
	Min(InvDate) First_SaleDt,
    Max(InvDate) Last_SaleDt,
	datediff(day, Min(InvDate), Max(InvDate)) Sales_Gap_Days,
	count(InvoiceId) Total_Bill_Count
FROM branchsales
group by customerid


--Query - 7
--Query to analyse Month-On-Month Sales change
--same query can also be used to analyse year-on-year sales considering year of sales
--This query uses a CTE to aggregate sales by month, then applies the LAG() window function to fetch the sales value from the previous month. 
--The result includes each month’s sales, the previous month's sales, and the change in sales (delta). The ISNULL(..., 0) ensures clean output by replacing nulls (e.g., for the first month) with 0s.
--LAG(column, offset) lets you look back at a previous row without self-joins — ideal for calculating trends, shifts, or deltas across a time series.
with cte as
(
select month(invdate) Mth, Sum(sales) Sales
from branchsales
group by month(invdate)
)

SELECT
    mth,
    Sales,
    isnull(LAG(sales, 1) OVER (ORDER BY mth), 0) as previous_month_sales,
    isnull(Sales - LAG(sales, 1) OVER (ORDER BY mth), 0) as sale_change
FROM cte;


--Query - 8
--Query to get top 3 products sold for a category based on sales amount
--using ROW_NUMBER() OVER with paritition and order by resets the group after the group name change
--and order by helps to sequence the dataset based on sales in descending order
SELECT *
FROM (
    SELECT
        category,
        productline,
        sales,
        ROW_NUMBER() OVER (PARTITION BY category ORDER BY sales DESC) as rank_in_category
    FROM branchsales
) ranked
WHERE rank_in_category <= 3;


--Query - 9
--Multi-Dimensional Sales Analysis
--Understand sales performance across multiple dimensions which can be achieved by using Grouping sets
SELECT
    COALESCE(branch, 'All Branches') as branch,
    COALESCE(category, 'All Categories') as category,
    COALESCE(productline, 'All Products') as channel,
    SUM(Sales) as total_sales,
    COUNT(*) as transaction_count,
    AVG(Sales) as avg_transaction_value
FROM branchsales
GROUP BY GROUPING SETS (
    (Branch, category, ProductLine),
    (Branch, category),
    (Branch, ProductLine),
	(Branch),
    (category),
    (ProductLine),
    ()
)
ORDER BY Branch, category, ProductLine;


--Query - 10
--This query analyzes customer buying behavior by calculating the gap between consecutive purchases.
--It uses the LEAD() function to find each customer’s next purchase date after a given transaction.
--Then, DATEDIFF() computes the number of days between the current purchase and the next one.
--This helps identify purchase frequency, spot inactivity patterns, and flag customers who may be at risk of churn.
--Finally, it also helps to filter out only those customers where the difference between current and next purchase is > 30
select * from
(
SELECT
    customerid,
    InvDate,
    LEAD(InvDate, 1) OVER (
        PARTITION BY customerid
        ORDER BY InvDate
    ) as next_purchase_date,
    DATEDIFF(day,
		invdate,
        LEAD(InvDate, 1) OVER (
            PARTITION BY customerid
            ORDER BY InvDate
        )
    ) as days_between_purchases
FROM branchsales
) as a
where a.days_between_purchases > 30