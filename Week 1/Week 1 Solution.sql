/* --------------------
   Case Study Questions
   --------------------*/

-- 1. What is the total amount each customer spent at the restaurant?
WITH totals AS
(
    SELECT
        customer_id,
        product_name,
		m1.price,
        COUNT(product_name) AS quantity,
        (COUNT(product_name) * m1.price) AS amount_bought
    FROM
        dannys_diner.sales
    LEFT JOIN
        dannys_diner.menu AS m1 ON sales.product_id = m1.product_id
    GROUP BY
        customer_id, product_name, m1.price
)
SELECT
    customer_id,
    SUM(amount_bought) AS total_purchases
FROM
    totals
WHERE
    customer_id IS NOT NULL
GROUP BY
    customer_id
ORDER BY
    customer_id;


		
-- 2. How many days has each customer visited the restaurant?
SELECT
    customer_id,
    COUNT(order_date) AS no_of_visits
FROM
    dannys_diner.sales
GROUP BY
    customer_id
ORDER BY
    customer_id;
 
-- 3. What was the first item from the menu purchased by each customer?
SELECT DISTINCT
    customer_id,
    FIRST_VALUE(product_name) OVER (PARTITION BY customer_id ORDER BY order_date ASC) AS first_buy
FROM
    dannys_diner.sales
LEFT JOIN
    dannys_diner.menu ON sales.product_id = menu.product_id
ORDER BY
    customer_id;

-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?
SELECT TOP 1
    product_name,
    COUNT(m.product_id) AS number_bought
FROM
    dannys_diner.sales AS s
LEFT JOIN
    dannys_diner.menu AS m ON s.product_id = m.product_id
GROUP BY
    product_name
ORDER BY
    number_bought DESC;

-- 5. Which item was the most popular for each customer?
WITH items_bought AS (
    SELECT
        sales.customer_id,
        product_name,
        COUNT(product_name) AS quantity
    FROM
        dannys_diner.sales
    LEFT JOIN
        dannys_diner.menu ON sales.product_id = menu.product_id
    GROUP BY
        customer_id, product_name
)
SELECT DISTINCT
    customer_id,
    FIRST_VALUE(product_name) OVER (PARTITION BY customer_id ORDER BY quantity DESC) AS most_popular_item
FROM
    items_bought;
	   
-- 6. Which item was purchased first by the customer after they became a member?
SELECT DISTINCT
    members.customer_id,
    FIRST_VALUE(product_name) OVER (PARTITION BY members.customer_id ORDER BY order_date) AS first_buy
FROM
    dannys_diner.sales
LEFT JOIN
    dannys_diner.menu ON sales.product_id = menu.product_id
LEFT JOIN
    dannys_diner.members ON sales.customer_id = members.customer_id
WHERE
    order_date > join_date;
-- 7. Which item was purchased just before the customer became a member?
WITH pre_membership AS (
    SELECT 
		members.customer_id, 
		product_name,
		order_date
    FROM dannys_diner.sales
    LEFT JOIN dannys_diner.menu ON sales.product_id = menu.product_id
    LEFT JOIN dannys_diner.members ON sales.customer_id = members.customer_id
    WHERE order_date < join_date
)
SELECT DISTINCT
    customer_id,
    FIRST_VALUE(product_name) OVER (PARTITION BY customer_id ORDER BY order_date DESC) AS last_buy
FROM
    pre_membership;


-- 8. What is the total items and amount spent for each member before they became a member?
WITH pre_membership AS (
    SELECT 
		sales.customer_id, 
		price, 
		sales.product_id
    FROM dannys_diner.sales
    LEFT JOIN dannys_diner.menu ON sales.product_id = menu.product_id
    LEFT JOIN dannys_diner.members ON sales.customer_id = members.customer_id
    WHERE order_date < join_date
)
SELECT
    customer_id,
    COUNT(*) AS total_items,
    SUM(price) AS amount_spent
FROM
    pre_membership
GROUP BY
    customer_id;
-- 9.  If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
WITH all_sales AS (
    SELECT
		members.customer_id,
		price,
		product_name
    FROM dannys_diner.sales
    LEFT JOIN dannys_diner.menu ON sales.product_id = menu.product_id
    LEFT JOIN dannys_diner.members ON sales.customer_id = members.customer_id
    WHERE order_date >= join_date
),
pointstable AS (
    SELECT
        customer_id,
        SUM(price) * 10 AS points,
        CASE
            WHEN product_name = 'sushi' THEN 10
            ELSE 0
        END AS sushi_points
    FROM
        all_sales
    GROUP BY
        customer_id, product_name
)
SELECT
    customer_id,
    SUM(points) + SUM(sushi_points) AS total_points
FROM
    pointstable
GROUP BY
    customer_id;

-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?
 
WITH all_sales AS (
    SELECT 
		members.customer_id,
        CASE
            WHEN order_date >= join_date AND order_date <= DATEADD(DAY, 7, join_date) THEN price * 20
            WHEN order_date > join_date THEN price * 10
        END AS points,
        CASE
            WHEN product_name = 'sushi' THEN price * 10
            ELSE 0
        END AS sushi_points
    FROM
        dannys_diner.sales
    LEFT JOIN
        dannys_diner.menu ON sales.product_id = menu.product_id
    LEFT JOIN
        dannys_diner.members ON sales.customer_id = members.customer_id
)
SELECT
    customer_id,
    SUM(points) + SUM(sushi_points) AS total_points
FROM
    all_sales
GROUP BY
    customer_id
HAVING
    customer_id IN ('A', 'B');
