-- 1. How many unique nodes are there on the Data Bank system?
SELECT COUNT(DISTINCT node_id) AS unique_nodes
FROM customer_nodes;

--2. What is the number of nodes per region?
SELECT r.region_name, COUNT(DISTINCT cn.node_id) AS nodes_per_region
FROM regions r
LEFT JOIN customer_nodes cn ON r.region_id = cn.region_id
GROUP BY r.region_name;

--3. How many customers are allocated to each region?
SELECT r.region_name, COUNT(DISTINCT cn.customer_id) AS customers_per_region
FROM regions r
LEFT JOIN customer_nodes cn ON r.region_id = cn.region_id
GROUP BY r.region_name;

--4. How many days on average are customers reallocated to a different node?
SELECT AVG(end_date-start_date) AS avg_reallocation_days
FROM customer_nodes;

--5. What is the median, 80th, and 95th percentile for this same reallocation days metric for each region?
SELECT
  region_name,
  PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY  (end_date - start_date)) AS median_reallocation_days,
  PERCENTILE_CONT(0.80) WITHIN GROUP (ORDER BY  (end_date - start_date)) AS percentile_80_reallocation_days,
  PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY  (end_date - start_date)) AS percentile_95_reallocation_days
FROM
  regions r
LEFT JOIN
  customer_nodes cn ON r.region_id = cn.region_id
GROUP BY
  r.region_name;

