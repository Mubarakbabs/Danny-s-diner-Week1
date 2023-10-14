-- Section C

-- creating a customer_balances table that will allow us answer the questions based on customer_balances
DROP TABLE IF EXISTS customer_balances;
CREATE TEMPORARY TABLE customer_balances (
    customer_id INTEGER,
    bal_date DATE NOT NULL,
    balance DECIMAL(10,2)
);


--calculate net transactions for each day	
	WITH all_txns AS (
		SELECT customer_id,
			   txn_date,
			   SUM(CASE WHEN txn_type = 'deposit' THEN txn_amount
						WHEN txn_type IN ('purchase', 'withdrawal') THEN -txn_amount
						ELSE 0
				   END) AS net_daily_txn
		FROM customer_transactions
		GROUP BY customer_id, txn_date
		
	),
--calculate the balances at the end of each day 
	daily_balances AS (
	SELECT customer_id,
		   txn_date,
			net_daily_txn,
		   SUM(net_daily_txn) OVER (PARTITION BY customer_id ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW ) AS daily_balance
	FROM all_txns
	),
--generate a list of dates for each customer
	all_dates AS(
	SELECT
	DISTINCT customer_id AS gen_id,
	DATE(generate_series(MIN(txn_date)::date, '2020-04-30'::date, '1 day'::interval)) AS generated_date
		FROM all_txns
	GROUP BY customer_id
	)
	,
-- the next two CTEs generate a balance for days on which no transaction occurred
-- first we create a group for each set of dates that will carry the same balance
	null_balances AS (
	SELECT 
	gen_id,
	generated_date,
	daily_balance,
	COUNT(daily_balance) OVER (PARTITION BY gen_id ORDER BY generated_date) AS grp
	FROM
	all_dates ad
	LEFT JOIN daily_balances dbal
	ON (generated_date = txn_date AND customer_id = gen_id)
	)
-- using the groups, we fill in the no_transaction dates
INSERT INTO customer_balances (customer_id, bal_date, balance)
	SELECT 
		gen_id customer_id,
		generated_date bal_date,
	 FIRST_VALUE(daily_balance) OVER (PARTITION BY gen_id, grp) balance
	FROM null_balances
	ORDER BY gen_id, generated_date;

-- Option 1: allocate based on end of month balance
-- note that we can't allocate negative data, so our data allocations will be 0 when the customer's account is overdrawn
WITH end_of_month_balances AS
	(SELECT
	subq.customer_id,
	TO_CHAR(month_end, 'yyyy-mm') AS month,
	CASE WHEN balance < 0 THEN 0 ELSE balance END AS balance
FROM
	(SELECT customer_id, EXTRACT (MONTH FROM bal_date) AS month,
	MAX(bal_date) AS month_end
	FROM customer_balances
	GROUP BY customer_id, month
)
	AS subq
JOIN customer_balances cb
ON (bal_date = month_end AND subq.customer_id = cb.customer_id)
ORDER BY customer_id, month_end)
SELECT month, SUM(balance) AS data_required
FROM end_of_month_balances
GROUP BY month
ORDER BY month;	

-- Option 2: allocate based on last thirty days average
WITH thirty_day_averages AS 
	(SELECT 
	customer_id,
	bal_date,
	AVG(balance) OVER (PARTITION BY customer_id ROWS BETWEEN 30 PRECEDING AND CURRENT ROW) balance
FROM
customer_balances),
daily_requirements AS (
	SELECT
	bal_date,
	SUM(balance) AS data_needed_per_day
FROM
	thirty_day_averages
WHERE balance > 0
GROUP BY bal_date)
SELECT 
	MIN(data_needed_per_day),
	AVG(data_needed_per_day),
	MAX(data_needed_per_day)
FROM daily_requirements;
	
-- Option 3: allocate real time
WITH daily_requirements AS (
	SELECT
	bal_date,
	SUM(balance) AS data_needed_per_day
FROM
	customer_balances
WHERE balance > 0
GROUP BY bal_date)
SELECT 
	MIN(data_needed_per_day),
	AVG(data_needed_per_day),
	MAX(data_needed_per_day)
FROM daily_requirements;

-- D. Extra challenge. Increase allocation based on annual interest rate

SELECT
	customer_id,
	bal_date,
	balance,
	0.06/365 AS daily_interest,
	balance * (1 + (0.06/365)) data_allocation
FROM customer_balances;

-- same as D. but with compound interest

SELECT
	customer_id,
	bal_date,
	balance,
	0.06/365 AS daily_interest,
	SUM(balance * (1 + (0.06/365))) OVER (PARTITION BY customer_id) data_allocation
FROM customer_balances;

--prepare a powerpoint with key data
