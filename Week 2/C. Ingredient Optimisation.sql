 -- C. Ingredient Optimisation

/*1. What are the standard ingredients for each pizza?*/

SELECT 
       pizza_name,
       STRING_AGG(topping_name, ', ') AS ingredients
FROM pizza_runner.pizza_recipes_converted AS pr 
	JOIN pizza_runner.pizza_names AS pn ON pr.pizza_id = pn.pizza_id
	JOIN pizza_runner.pizza_toppings AS pt ON pr.topping_array = pt.topping_id
GROUP BY pizza_name
;



/*2 What was the most commonly added extra?*/
WITH top_extra AS (
    SELECT 
	 TOP (1) value AS most_common_extra,
                COUNT(value) AS n
    FROM pizza_runner.customer_orders
    CROSS APPLY STRING_SPLIT(extras, ',') AS extra
    GROUP BY value
    ORDER BY n DESC
)
SELECT topping_name AS most_added_extra
FROM pizza_runner.pizza_toppings
JOIN top_extra ON most_common_extra = topping_id;


/*3. What was the most common exclusion? */
WITH top_extra AS (
    SELECT 
	 TOP (1) value AS most_common_exclusion,
                COUNT(value) AS n
    FROM pizza_runner.customer_orders
    CROSS APPLY STRING_SPLIT(exclusions, ',') AS excl
    GROUP BY value
    ORDER BY n DESC
)
SELECT topping_name AS most_common_exclusion
FROM pizza_runner.pizza_toppings
JOIN top_extra ON most_common_exclusion = topping_id;


-- Generate an order item for each record in the customers_orders table in the format of one of the following:
-- Meat Lovers
SELECT order_id,
		c.pizza_id,
       pizza_name
FROM pizza_runner.customer_orders AS c
JOIN pizza_runner.pizza_names n ON c.pizza_id = n.pizza_id;

 --Meat Lovers - Exclude Beef
WITH exclusions_sep AS (
    SELECT 
	*,
	topping_name AS exclusion
    FROM pizza_runner.customer_orders
    CROSS APPLY STRING_SPLIT(exclusions, ',') AS excl
	JOIN pizza_runner.pizza_toppings ON value = topping_id
),
non_exclusions AS (
	SELECT *,
	NULL AS value,
	NULL AS topping_name,
	NULL as topping_id,
	NULL as exclusion
	FROM pizza_runner.customer_orders
	WHERE exclusions is NULL
	),
new_customer_orders AS(
	SELECT * FROM exclusions_sep
	UNION
	SELECT * FROM non_exclusions)
SELECT 
	order_id,
	c.pizza_id,
	CASE WHEN
	exclusion IS NOT NULL 
	THEN pizza_name + ': Exclude ' + exclusion
	ELSE pizza_name END AS order_details
FROM new_customer_orders AS c
JOIN pizza_runner.pizza_names AS pn ON c.pizza_id = pn.pizza_id

 --Meat Lovers - Extra Bacon
WITH extras_sep AS (
    SELECT 
	*,
	topping_name AS extra
    FROM pizza_runner.customer_orders
    CROSS APPLY STRING_SPLIT(extras, ',') AS extra
	JOIN pizza_runner.pizza_toppings ON value = topping_id
),
non_extras AS (
	SELECT *,
	NULL AS value,
	NULL AS topping_name,
	NULL as topping_id,
	NULL as extra
	FROM pizza_runner.customer_orders
	WHERE exclusions is NULL
	),
new_customer_orders AS(
	SELECT * FROM extras_sep
	UNION
	SELECT * FROM non_extras)
SELECT 
	order_id,
	c.pizza_id,
	CASE WHEN
	extra IS NOT NULL 
	THEN pizza_name + ': Extra ' + extra
	ELSE pizza_name END AS order_details
FROM new_customer_orders AS c
JOIN pizza_runner.pizza_names AS pn ON c.pizza_id = pn.pizza_id

 --Meat Lovers - Exclude Cheese, Bacon - Extra Mushroom, Peppers
WITH 
numbered_customer_orders AS (
SELECT *,
ROW_NUMBER() OVER(ORDER BY order_id) AS order_line_id
FROM pizza_runner.customer_orders
),

exclusions_sep AS (
    SELECT 
	order_line_id,
	topping_name AS exclusion
    FROM numbered_customer_orders
    CROSS APPLY STRING_SPLIT(exclusions, ',') AS excl
	JOIN pizza_runner.pizza_toppings ON value = topping_id
),
 extras_sep AS(   
	SELECT 
	order_line_id,
	topping_name AS extra
    FROM numbered_customer_orders
    CROSS APPLY STRING_SPLIT(extras, ',') AS extra
	JOIN pizza_runner.pizza_toppings ON value = topping_id
),
no_changes AS (
	SELECT order_line_id,
	NULL as order_details
	FROM numbered_customer_orders
	WHERE exclusions is NULL AND extras IS NULL
	),
modified_customer_orders AS (
SELECT order_line_id,
	STRING_AGG(order_details, ' ') AS order_details
FROM(
SELECT order_line_id,
'Extra: ' + STRING_AGG (extra, ', ') AS order_details
FROM extras_sep
GROUP BY order_line_id
UNION
SELECT order_line_id, 'Exclude: ' + STRING_AGG(exclusion, ', ') AS order_details
FROM exclusions_sep excl
GROUP BY order_line_id) AS joined
GROUP BY order_line_id)
SELECT * 
FROM numbered_customer_orders AS base
JOIN
(SELECT * FROM modified_customer_orders
UNION
SELECT order_line_id, order_details
FROM no_changes) As other
ON base.order_line_id = other.order_line_id;


 --Generate an alphabetically ordered comma separated ingredient list for each pizza order from the customer_orders table and add a 2x in front of any relevant ingredients
 --For example: "Meat Lovers: 2xBacon, Beef, ... , Salami"
WITH 
numbered_customer_orders AS (
SELECT *,
ROW_NUMBER() OVER(ORDER BY order_id) AS order_line_id
FROM pizza_runner.customer_orders
),
--this extracts the list of exclusions for each order
exclusions_sep AS (
    SELECT 
	order_line_id,
	topping_name AS exclusion
    FROM numbered_customer_orders
    CROSS APPLY STRING_SPLIT(exclusions, ',') AS excl
	JOIN pizza_runner.pizza_toppings ON value = topping_id
),
--this extracts all extras and their associated order
 extras_sep AS(   
	SELECT 
	c.order_line_id,
	topping_name AS extra
    FROM 
  numbered_customer_orders c
  JOIN pizza_runner.pizza_recipes r ON c.pizza_id = r.pizza_id 
  CROSS APPLY string_split (extras, ',')
  JOIN pizza_runner.pizza_toppings ON value = topping_id
),
--this extracts the base ingredients for all orders 
no_extras AS (
	SELECT order_line_id,
	topping_name as ingredients
	FROM
	numbered_customer_orders c
    JOIN pizza_runner.pizza_recipes r ON c.pizza_id = r.pizza_id 
	CROSS APPLY string_split (CAST(toppings AS nvarchar(max)), ',')
	JOIN pizza_runner.pizza_toppings ON value = topping_id
	),
ingredient_list AS (
	SELECT order_line_id, ingredients
	FROM no_extras
	EXCEPT
	SELECT order_line_id, exclusion AS ingredients
	FROM exclusions_sep
	UNION ALL
	SELECT order_line_id, extra AS ingredients
	FROM extras_sep
	),
ingredient_with_count AS (
	SELECT order_line_id, 
	ingredients, 
	COUNT(ingredients) AS ing_count,
	CASE WHEN COUNT(ingredients)>1
	THEN CAST(COUNT(ingredients) AS nvarchar) + 'x' + ingredients
	ELSE ingredients END AS final_toppings
	FROM ingredient_list
	GROUP BY order_line_id, ingredients)
--case when won't work within string_agg, so we add a count for all ingredients

SELECT order_line_id,
	STRING_AGG(
 final_toppings,
	', ') AS order_details
FROM ingredient_with_count
GROUP BY order_line_id;


 --What is the total quantity of each ingredient used in all delivered pizzas sorted by most frequent first?
WITH 
numbered_customer_orders AS (
SELECT *,
ROW_NUMBER() OVER(ORDER BY order_id) AS order_line_id
FROM pizza_runner.customer_orders
)
,
exclusions_count AS (
SELECT
	value AS topping_id,
	COUNT(value) AS n_exclusions
  FROM
  numbered_customer_orders c
  JOIN pizza_runner.pizza_recipes r ON c.pizza_id = r.pizza_id 
  CROSS APPLY string_split(exclusions, ',')
  GROUP BY value
  ),
extras_count AS (
	SELECT 
	value AS topping_id,
	COUNT(value) AS n_extras --n_extras includes all base ingredients and extras added
  FROM
  numbered_customer_orders c
  JOIN pizza_runner.pizza_recipes r ON c.pizza_id = r.pizza_id 
  CROSS APPLY string_split (CAST(toppings AS nvarchar(max))+', '+extras, ',')
  GROUP BY value
  ),
no_toppings AS (

SELECT
value AS topping_id,
--CAST(value AS nvarchar) AS topping_id,
COUNT(value) AS topping_count
  FROM
  numbered_customer_orders c
  JOIN pizza_runner.pizza_recipes r ON c.pizza_id = r.pizza_id 
  CROSS APPLY string_split (TRIM(CAST(toppings AS nvarchar(max))), ',')
  WHERE extras IS NULL AND exclusions IS NULL
 GROUP BY c.pizza_id, value
 )
SELECT 
TRIM(total.topping_id),
SUM(total_ingredients)
FROM
(
SELECT 
TRIM(n.topping_id) AS topping_id,
--using sum to aggregate again because some of the ids didn't aggregate in previous CTEs
topping_count + n_extras - COALESCE(n_exclusions, 0) AS total_ingredients
FROM
no_toppings AS n
LEFT JOIN exclusions_count AS excl ON n.topping_id = excl.topping_id
LEFT JOIN extras_count AS extr ON n.topping_id = extr.topping_id) AS total
GROUP BY TRIM(total.topping_id)


