/* B. Runner and Customer Experience*/

/*1. How many runners signed up for each 1 week period? (i.e. week starts 2021-01-01)*/
SELECT CEILING(DATEPART(DAYOFYEAR, registration_date)/7.0) AS week, COUNT(*)
FROM pizza_runner.runners
GROUP BY CEILING(DATEPART(DAYOFYEAR, registration_date)/7.0);

/*2 What was the average time in minutes it took for each runner to arrive at the Pizza Runner HQ to pickup the order?
*/
SELECT AVG(DATEDIFF(MINUTE, order_time, pickup_time))
FROM pizza_runner.customer_orders AS c
JOIN pizza_runner.runner_orders AS o
    ON c.order_id = o.order_id
WHERE pickup_time IS NOT NULL;



/*3 Is there any relationship between the number of pizzas and how long the order takes to prepare? Yees there is
 */
SELECT c.order_id, COUNT(pizza_id) AS n_pizzas, AVG(DATEDIFF(MINUTE, order_time, pickup_time)) AS time_taken
FROM pizza_runner.customer_orders AS c
JOIN pizza_runner.runner_orders AS r
    ON c.order_id = r.order_id
WHERE pickup_time IS NOT NULL
GROUP BY c.order_id
ORDER BY n_pizzas;
-- Yes. There's an almost linear positive relationship. Could be a point of process improvement


/*4.What was the average distance travelled for each customer?*/
SELECT customer_id, AVG(distance)
FROM pizza_runner.customer_orders AS c
JOIN pizza_runner.runner_orders AS r
    ON c.order_id = r.order_id
GROUP BY customer_id;

/*5.What was the difference between the longest and shortest delivery times for all orders?*/
SELECT MAX(DATEDIFF(MINUTE, order_time, pickup_time)) - MIN(DATEDIFF(MINUTE, order_time, pickup_time)) AS range_dev
FROM pizza_runner.customer_orders AS c
JOIN pizza_runner.runner_orders AS r
    ON c.order_id = r.order_id;


/*6. What was the average speed for each runner for each delivery and do you notice any trend for these values?
*/
SELECT runner_id, AVG(distance*1.0/duration) AS speed
FROM pizza_runner.runner_orders
GROUP BY runner_id;



/*7. What is the successful delivery percentage for each runner?*/
WITH success AS (
    SELECT runner_id, COUNT(*) AS n_complete
    FROM pizza_runner.runner_orders
    WHERE cancellation IS NULL
    GROUP BY runner_id
),
attempts AS (
    SELECT runner_id, COUNT(*) AS n_attempts
    FROM pizza_runner.runner_orders
    GROUP BY runner_id
)
SELECT 
	attempts.runner_id, 
	CONCAT(success.n_complete*100/attempts.n_attempts, '%') AS success_rate
FROM attempts
LEFT JOIN success
    ON attempts.runner_id = success.runner_id;
