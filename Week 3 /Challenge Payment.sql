DROP TABLE IF EXISTS payments;
CREATE TABLE payments (
    customer_id INTEGER,
    plan_id INTEGER,
    payment_date DATE,
    amount_paid DECIMAL(5 , 2 )
);

INSERT INTO payments
-- temp tables aren't as reusable as I thought so I will recreate the next_plans as a cte to be reused
WITH RECURSIVE 
next_plans AS (
SELECT customer_id, 
plan_id AS current_plan, 
LEAD(plan_id) OVER (PARTITION BY customer_id) AS next_plan,
start_date AS current_plan_start,
LEAD(start_date) OVER(PARTITION BY customer_id) AS next_plan_start
FROM subscriptions),
-- CTE for basic to pro
basic_pro AS (
SELECT *
FROM next_plans
WHERE 
current_plan =1 AND next_plan IN (2,3)),

basic_pro_final AS (
SELECT 
customer_id,
current_plan,
next_plan,
current_plan_start,
next_plan_start
FROM basic_pro

UNION ALL

SELECT customer_id, 
current_plan, 
next_plan,
DATE_ADD(current_plan_start,INTERVAL 1 month) AS current_plan_start,
next_plan_start
FROM basic_pro_final
WHERE DATE_ADD(current_plan_start,INTERVAL 1 month)<next_plan_start
),
-- CTE for pro monthly to annual
monthly_annual AS (
SELECT *
FROM next_plans
WHERE 
current_plan =2 AND next_plan=3),

monthly_annual_final AS (
SELECT 
customer_id,
current_plan,
next_plan,
current_plan_start,
next_plan_start
FROM monthly_annual

UNION ALL

SELECT customer_id, 
current_plan, 
next_plan,
DATE_ADD(current_plan_start,INTERVAL 1 month) AS current_plan_start,
next_plan_start
FROM monthly_annual_final
WHERE DATE_ADD(current_plan_start,INTERVAL 1 month)<next_plan_start
),

-- CTE for churned subs
churned_monthly AS (
SELECT *
FROM next_plans
WHERE 
current_plan IN (1,2) AND next_plan=4),

churned_monthly_dates AS (
SELECT 
customer_id,
current_plan,
next_plan,
current_plan_start,
next_plan_start
FROM churned_monthly

UNION ALL

SELECT customer_id, 
current_plan, 
next_plan,
DATE_ADD(current_plan_start,INTERVAL 1 month) AS current_plan_start,
next_plan_start
FROM churned_monthly_dates
WHERE DATE_ADD(current_plan_start,INTERVAL 1 month)<next_plan_start
),
churned_annual AS (
SELECT *
FROM next_plans
WHERE 
current_plan = 3 AND next_plan=4),

churned_annual_dates AS (
SELECT 
customer_id,
current_plan,
next_plan,
current_plan_start,
next_plan_start
FROM churned_annual

UNION ALL

SELECT customer_id, 
current_plan, 
next_plan,
DATE_ADD(current_plan_start,INTERVAL 1 year) AS current_plan_start,
next_plan_start
FROM churned_annual_dates
WHERE DATE_ADD(current_plan_start,INTERVAL 1 year)<next_plan_start
),
churned_final AS (
SELECT * FROM churned_monthly_dates
UNION ALL 
SELECT * FROM churned_annual_dates
),

-- CTE for continued subs
continued_monthly AS (
SELECT *
FROM next_plans
WHERE 
current_plan IN (1,2) AND next_plan IS NULL),

continued_monthly_dates AS (
SELECT 
customer_id,
current_plan,
next_plan,
current_plan_start,
"2021-04-30" AS next_plan_start
FROM continued_monthly

UNION ALL

SELECT customer_id, 
current_plan, 
next_plan,
DATE_ADD(current_plan_start,INTERVAL 1 month) AS current_plan_start,
next_plan_start
FROM continued_monthly_dates
WHERE DATE_ADD(current_plan_start,INTERVAL 1 month)<next_plan_start
),
continued_annual AS (
SELECT *
FROM next_plans
WHERE 
current_plan = 3 AND next_plan IS NULL),

continued_annual_dates AS (
SELECT 
customer_id,
current_plan,
next_plan,
current_plan_start,
"2021-04-30" AS next_plan_start
FROM continued_annual

UNION ALL

SELECT customer_id, 
current_plan, 
next_plan,
DATE_ADD(current_plan_start,INTERVAL 1 year) AS current_plan_start,
next_plan_start
FROM continued_annual_dates
WHERE DATE_ADD(current_plan_start,INTERVAL 1 year)<next_plan_start
),
continued_final AS (
SELECT * FROM continued_monthly_dates
UNION ALL 
SELECT * FROM continued_annual_dates
),

-- combine all outputs in one
all_outputs AS(
SELECT * FROM basic_pro_final
UNION ALL
SELECT * FROM monthly_annual_final
UNION ALL
SELECT * FROM churned_final
UNION ALL
SELECT * FROM continued_final)

-- final query

SELECT
customer_id,
current_plan AS plan_id,
current_plan_start AS payment_date,

CASE WHEN current_plan IN (2,3) AND LAG(all_outputs.current_plan) OVER w = 1
THEN price - 9.9
ELSE price END AS amount_paid

FROM all_outputs
INNER JOIN
plans ON current_plan = plan_id

WINDOW w  AS (PARTITION BY customer_id ORDER BY current_plan_start)
;
