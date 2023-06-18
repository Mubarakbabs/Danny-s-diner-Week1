--D. Pricing and Ratings

--1. Revenue so far without charges
WITH pizza_revenue AS
(
    SELECT order_id, 
        pizza_id,
        CASE WHEN pizza_id = 1 THEN 12 ELSE 10 END AS revenue
    FROM pizza_runner.customer_orders
)
SELECT SUM(revenue)
FROM pizza_revenue;


/*--2. 
What if there was an additional $1 charge for any pizza extras?
Add cheese is $1 extra*/
WITH 
	pizza_revenue AS
(
    SELECT 
		order_id, 
        pizza_id,
        CASE WHEN pizza_id = 1 THEN 12 ELSE 10 END AS revenue,
         COALESCE(LEN(REPLACE(TRIM(extras), ', ', '')),0) AS extra_revenue
    FROM pizza_runner.customer_orders
)
SELECT SUM(revenue + extra_revenue) AS total_revenue
FROM pizza_revenue;


/*3.The Pizza Runner team now wants to add an additional ratings system that allows customers to rate their runner, how would you design an additional table for this new dataset - generate a schema for this new table and insert your own data for ratings for each successful customer order between 1 to 5.*/
DROP TABLE IF EXISTS pizza_runner.ratings;
CREATE TABLE pizza_runner.ratings (
    "order_id" INT,
    "rating" INT
);
INSERT INTO pizza_runner.ratings
    (order_id, rating)
VALUES
    (1, 4),
    (2, 5),
    (3, 3),
    (4, 3),
    (5, 5),
    (7, 4),
    (8, 1),
    (10, 2);


/*4. Using your newly generated table - can you join all of the information together to form a table which has the following information for successful deliveries?
customer_id
order_id
runner_id
rating
order_time
pickup_time
Time between order and pickup
Delivery duration
Average speed
Total number of pizzas*/
SELECT
    customer_id,
    c.order_id,
    runner_id,
    rating,
    order_time,
    pickup_time,
    DATEDIFF(MINUTE, order_time, pickup_time) AS response_time,
    duration,
    duration / distance AS average_speed,
    COUNT(c.order_id) AS number_of_pizzas
FROM pizza_runner.customer_orders AS c
JOIN pizza_runner.runner_orders AS run ON c.order_id = run.order_id
JOIN pizza_runner.ratings AS rat ON c.order_id = rat.order_id
GROUP BY
    customer_id,
    c.order_id,
    runner_id,
    rating,
    order_time,
    pickup_time,
    DATEDIFF(MINUTE, order_time, pickup_time),
    duration,
    duration/distance;


/* If a Meat Lovers pizza was $12 and Vegetarian $10 fixed prices with no cost for extras and each runner is paid $0.30 per kilometre traveled - how much money does Pizza Runner have left over after these deliveries?
*/
WITH pizza_revenue AS
(
    SELECT order_id, 
        CASE WHEN pizza_id = 1 THEN 12 ELSE 10 END AS revenue
    FROM pizza_runner.customer_orders
),
runner_costs AS
(
    SELECT order_id, 
        distance * 0.3 AS delivery_cost
    FROM pizza_runner.runner_orders
)
SELECT SUM(revenue) - SUM(runner_costs.delivery_cost) AS leftover_money
FROM pizza_revenue
JOIN runner_costs ON pizza_revenue.order_id = runner_costs.order_id;
