
--1. What is the unique count and total amount for each transaction type?
SELECT txn_type,
       COUNT(DISTINCT customer_id) AS unique_count,
       SUM(txn_amount) AS total_amount
FROM customer_transactions
GROUP BY txn_type;

-- 2.What is the average total historical deposit counts and amounts for all customers?
WITH cte AS (
    SELECT customer_id,
           COUNT(CASE WHEN txn_type = 'deposit' THEN 1 ELSE NULL END) AS deposit_count,
           SUM(CASE WHEN txn_type = 'deposit' THEN txn_amount ELSE 0 END) AS total_deposit_amount
    FROM customer_transactions
    GROUP BY customer_id)

SELECT AVG(deposit_count) AS average_deposit_count,
       AVG(total_deposit_amount) AS average_deposit_amount
FROM cte;

--3. For each month, how many Data Bank customers make more than 1 deposit and either 1 purchase or 1 withdrawal in a single month?
SELECT EXTRACT(MONTH FROM txn_date) AS month,
       COUNT(DISTINCT CASE
            WHEN txn_type IN ('purchase', 'withdrawal') THEN customer_id
            ELSE NULL
       END) AS customers_with_purchase_or_withdrawal,
       COUNT(DISTINCT CASE
            WHEN txn_type = 'deposit' THEN customer_id
            ELSE NULL
       END) AS customers_with_deposit
FROM customer_transactions
GROUP BY EXTRACT(MONTH FROM txn_date)
HAVING 
	COUNT(DISTINCT CASE WHEN txn_type = 'deposit' THEN customer_id ELSE NULL END) > 0 -- deposits > 1
  AND (COUNT(DISTINCT CASE WHEN txn_type IN ('purchase', 'withdrawal') THEN customer_id ELSE NULL END) > 0) -- made a purchase/withdrawal
   ;



--4. What is the closing balance for each customer at the end of the month?
-- I first did this inefficiently
/* WITH monthly_txns AS (
    SELECT customer_id,
           EXTRACT(MONTH FROM txn_date) AS month,
           SUM(CASE WHEN txn_type = 'deposit' THEN txn_amount
                    WHEN txn_type IN ('purchase', 'withdrawal') THEN -txn_amount
                    ELSE 0
               END) AS net_monthly_txn
    FROM customer_transactions
    GROUP BY customer_id, EXTRACT(MONTH FROM txn_date)
)
SELECT customer_id,
       month,
       net_monthly_txn + 
	   	COALESCE(LAG(net_monthly_txn) OVER (PARTITION BY customer_id ORDER BY month), 0) AS cum_monthly_balance
	   
FROM monthly_txns; */

WITH monthly_txns AS (
    SELECT customer_id,
           EXTRACT(MONTH FROM txn_date) AS month,
           SUM(CASE WHEN txn_type = 'deposit' THEN txn_amount
                    WHEN txn_type IN ('purchase', 'withdrawal') THEN -txn_amount
                    ELSE 0
               END) AS net_monthly_txn
    FROM customer_transactions
    GROUP BY customer_id, EXTRACT(MONTH FROM txn_date)
)
SELECT customer_id,
       month,
       SUM(net_monthly_txn) OVER (PARTITION BY customer_id ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW ) AS monthly_balance
FROM monthly_txns;

--5. What is the percentage of customers who increase their closing balance by more than 5%?
WITH monthly_txn AS (
    SELECT customer_id,
           EXTRACT(MONTH FROM txn_date) AS month,
           SUM(CASE WHEN txn_type = 'deposit' THEN txn_amount
                    WHEN txn_type IN ('purchase', 'withdrawal') THEN -txn_amount
                    ELSE 0
               END)  AS net_monthly_txn
	FROM customer_transactions
    GROUP BY customer_id, EXTRACT(MONTH FROM txn_date)
),
monthly_balances AS (
	SELECT customer_id,
           month,
            SUM (net_monthly_txn) OVER (PARTITION BY customer_id ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW ) AS monthly_balance
	FROM monthly_txn
)
SELECT month,
       COUNT(CASE WHEN (monthly_balance - previous_monthly_balance) / NULLIF(previous_monthly_balance, 0) > 0.05 THEN 1 ELSE NULL END) AS customers_increase_by_5_percent_or_more,
       COUNT(*) AS total_customers
FROM (
    SELECT customer_id,
           month,
		   monthly_balance,
			LAG(monthly_balance) OVER (PARTITION BY customer_id ORDER BY month) AS previous_monthly_balance
	FROM monthly_balances
) AS subquery
GROUP BY month
ORDER BY month;