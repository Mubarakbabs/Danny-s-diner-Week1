-- 1. How many customers has Foodie-Fi ever had?
SELECT 
    COUNT(DISTINCT customer_id)
FROM
    subscriptions;

-- 2. What is the monthly distribution of trial plan start_date values for our dataset - use the start of the month as the group by value 
SELECT 
    DATE_FORMAT(start_date, '%Y-%m') AS month,
    COUNT(*) AS n_trials
FROM
    subscriptions
WHERE
    plan_id = 0
GROUP BY month
ORDER BY month;

-- 3. What plan start_date values occur after the year 2020 for our dataset? Show the breakdown by count of events for each plan_name
SELECT 
    plan_name,
    DATE_FORMAT(start_date, '%Y-%m') AS month,
    COUNT(*)
FROM
    subscriptions
        JOIN
    plans USING (plan_id)
WHERE
    YEAR(start_date) > 2020
GROUP BY plan_name , month
ORDER BY plan_name , month;

-- 4. What is the customer count and percentage of customers who have churned rounded to 1 decimal place?

SELECT COUNT(*) AS n_churn,
	CONCAT(FORMAT(COUNT(*)/(SELECT COUNT(*) FROM subscriptions), 2) * 100, "%") AS perc_churn
FROM subscriptions
WHERE plan_id = 4

-- 5. How many customers have churned straight after their initial free trial - what percentage is this rounded to the nearest whole number?
-- I solved this using two methods. One with subqueries and one with window functions. The one with window functions is 2x faster (0.015) while subquery (0.031)
-- method 1: using subquery
WITH churned_customers AS 
(
SELECT customer_id, plan_id
FROM subscriptions
WHERE customer_id IN 
	(SELECT customer_id
	FROM subscriptions
	WHERE plan_id = 4))
SELECT COUNT(DISTINCT customer_id) AS churned_straight, 
CONCAT(FORMAT(COUNT(DISTINCT customer_id)*100/(SELECT COUNT(DISTINCT customer_id) FROM churned_customers),2), "%") AS perc_of_churn
FROM churned_customers
WHERE customer_id NOT IN (SELECT customer_id
FROM churned_customers
WHERE plan_id IN (1,2,3));

-- method 2: using window function
WITH plan_list AS (
SELECT 
	customer_id, 
	plan_id, 
    LAG(plan_id) OVER(partition by customer_id ORDER BY plan_id) AS previous_plan
FROM subscriptions
)
SELECT COUNT(customer_id) AS churned_straight, 
CONCAT(FORMAT(COUNT(customer_id)*100/(SELECT COUNT(*) FROM subscriptions WHERE plan_id=4),2), "%") AS perc_of_churn
FROM plan_list
WHERE plan_id = 4 and previous_plan = 0


-- 6. What is the number and percentage of customer plans after their initial free trial?
SELECT COUNT(*) AS after_free_trial, 
	CONCAT(FORMAT(COUNT(*)*100/(SELECT COUNT(*) FROM subscriptions WHERE plan_id != 4),2), "%") AS perc_of_total_plans
FROM subscriptions
WHERE plan_id IN (1,2,3)

-- 7. What is the customer count and percentage breakdown of all 5 plan_name values at 2020-12-31?

WITH active_plans AS(
-- active plans are plans where the customer hasn't made another plan/churned
SELECT 
	customer_id,
	plan_id,
    LEAD(plan_id) OVER (PARTITION BY customer_id ORDER BY start_date) AS next_plan
FROM subscriptions
WHERE start_date < "2020-12-31"
)

 SELECT
 	plan_name,
     COUNT(plan_id),
     CONCAT(FORMAT(COUNT(*)*100/(SELECT COUNT(*) FROM active_plans WHERE plan_id != 4 AND next_plan IS NULL),2), "%") AS perc_of_total_plans
 FROM active_plans
 JOIN plans
 USING (plan_id)
 WHERE plan_id !=4 AND next_plan IS NULL
 GROUP BY plan_name



-- 8. How many customers have upgraded to an annual plan in 2020?
SELECT COUNT(*)
FROM subscriptions
WHERE plan_id = 3 and YEAR(start_date) = 2020

-- 9. How many days on average does it take for a customer to an annual plan from the day they join Foodie-Fi?
WITH annual_customers AS
(SELECT customer_id, plan_id, start_date
FROM subscriptions
WHERE plan_id = 3),
date_joined AS
(SELECT customer_id, plan_id, start_date
FROM subscriptions
WHERE plan_id = 0),
number_of_days AS
(
SELECT ac.customer_id, datediff(ac.start_date, dj.start_date) AS no_of_days
FROM annual_customers AS ac
JOIN date_joined AS dj
USING(customer_id))
SELECT AVG (no_of_days) AS average_days_to_annual
FROM number_of_days;
-- 10. Can you further breakdown this average value into 30 day periods (i.e. 0-30 days, 31-60 days etc)
 WITH annual_customers AS
(SELECT customer_id, plan_id, start_date
FROM subscriptions
WHERE plan_id = 3),
date_joined AS
(SELECT customer_id, plan_id, start_date
FROM subscriptions
WHERE plan_id = 0),
number_of_days AS
(
SELECT ac.customer_id, datediff(ac.start_date, dj.start_date) AS no_of_days
FROM annual_customers AS ac
JOIN date_joined AS dj
USING(customer_id))
SELECT 
CASE WHEN FORMAT(no_of_days, 1)/30 <=1.0 THEN "0-30 days"
WHEN FORMAT(no_of_days, 1)/30 <=2.0 THEN "30-60 days"
WHEN FORMAT(no_of_days, 1)/30 <=3.0 THEN "60-90 days"
WHEN FORMAT(no_of_days, 1)/30 <=4.0 THEN "90-120 days"
WHEN FORMAT(no_of_days, 1)/30 <=5.0 THEN "120-150 days"
WHEN FORMAT(no_of_days, 1)/30 <=6.0 THEN "150-180 days"
ELSE "above 180 days" END AS days_range,
COUNT(*) AS number_of_users
FROM number_of_days
GROUP BY days_range;

-- 11. How many customers downgraded from a pro monthly to a basic monthly plan in 2020?
WITH plan_list AS (
SELECT 
	customer_id, 
	plan_id,
    start_date,
    LAG(plan_id) OVER(partition by customer_id ORDER BY start_date) AS previous_plan
FROM subscriptions
WHERE customer_id IN (SELECT customer_id FROM subscriptions WHERE plan_id = 2)
)
SELECT COUNT(*) AS downgraded
FROM plan_list
WHERE plan_id = 1 and previous_plan = 2
