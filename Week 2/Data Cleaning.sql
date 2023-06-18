--clean runner_orders cancellation --
/*UPDATE
   pizza_runner.runner_orders
 SET
   cancellation = NULL 
 WHERE
   cancellation IN ('null', ''); */

 --clean runner_orders distance 
/*UPDATE
   pizza_runner.runner_orders
SET
  distance = NULL 
WHERE
  distance = 'null';*/

-- removing km from distance to allow casting

/*UPDATE pizza_runner.runner_orders
SET distance = 
    TRIM(
      LEFT(
        distance, 
        CHARINDEX('k', distance)-1
        )
        ) 
WHERE
  RIGHT (distance, 2) = 'km';*/

--convert distance to float
/*UPDATE
  pizza_runner.runner_orders
SET
  distance = CAST(TRIM(distance) AS FLOAT);*/

/*ALTER TABLE pizza_runner.runner_orders
ALTER COLUMN distance DECIMAL(10,2);*/


--clean runner_orders duration
/*
UPDATE
  pizza_runner.runner_orders
SET
  duration = NULL 
WHERE
  duration = 'null'; 
*/

--removing 'minutes' from duration

/*UPDATE pizza_runner.runner_orders
SET duration = TRIM(
      LEFT(
        duration, 
        CHARINDEX('m', duration)-1
        )
        ) 
WHERE
  CHARINDEX('m', duration) > 0;*/

--convert duration to INT

/*UPDATE
  pizza_runner.runner_orders
SET
  duration = CAST(duration AS INT)*/ 

/*ALTER TABLE pizza_runner.runner_orders
ALTER COLUMN duration INT;*/

--clean runner_orders pickup_time
/*
UPDATE
  pizza_runner.runner_orders
SET
  pickup_time = NULL 
WHERE
  pickup_time = 'null';

*/
-- set pickup_time in runner orders as DATETIME
/*UPDATE
  pizza_runner.runner_orders
SET
  pickup_time = CAST(pickup_time AS DATETIME2) 
*/

--CUSTOMER ORDERS TABLE CLEANING
--clean customer_orders exclusions

/*UPDATE
  pizza_runner.customer_orders
SET
  exclusions = NULL 
WHERE
  exclusions IN ('null', '');*/

--clean customer_orders extras

/*UPDATE
  pizza_runner.customer_orders
SET
  extras = NULL 
WHERE
  extras IN ('null', ''); 
*/

--convert order_time in customer orders to datetime
/*UPDATE
	pizza_runner.customer_orders
SET
	order_time = CAST(order_time AS datetime2)*/
/*ALTER TABLE pizza_runner.customer_orders
ALTER COLUMN order_time DATETIME2*/

-- Create a new table to store the converted values. The changes are first made in a new table so in case of any errors, you can still fall back to the original
/*CREATE TEMP TABLE pizza_runner.pizza_recipes_converted (
  pizza_id INT,
  toppings NVARCHAR(MAX),
  topping_array NVARCHAR(MAX)
);*/

-- Insert the converted values into the new table
/*  INSERT INTO pizza_runner.pizza_recipes_converted (pizza_id, topping_array)
SELECT pizza_id, STRING_AGG(value, ',') AS topping_array
FROM (
  SELECT pizza_id, value AS topping_array
  FROM pizza_runner.pizza_recipes
  CROSS APPLY STRING_SPLIT(CAST(toppings AS nvarchar(max)), ',')
) AS subquery
GROUP BY pizza_id;
*/



--changing text data type to nvarchar(max) to allow for string operations
ALTER TABLE pizza_runner.pizza_toppings
ALTER COLUMN topping_name nvarchar(max);