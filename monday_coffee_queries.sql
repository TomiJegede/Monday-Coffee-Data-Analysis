-- Monday Coffee Data Analysis

SELECT * FROM city;
SELECT * FROM customers;
SELECT * FROM products;
SELECT * FROM sales
LIMIT 20;

-- Reports & Data Analysis

-- Q1. Coffee consumers count
-- How many people in each city are estimated to consume coffee, given that 25% of the population does?

SELECT city_name, 
		ROUND((population * 0.25)/1000000, 2) AS coffee_consumers_in_millions
FROM city  -- we are dividing by 1M to simplify the calculation, this is common practice in Analytics
ORDER BY 2 DESC;

-- Q2. Total revenue from coffee sales
-- What is the total revenue generated from coffee sales across all cities in the last quarter of 2023?

SELECT SUM(total) AS total_revenue
FROM sales
WHERE EXTRACT(YEAR FROM sale_date) = 2023
	AND 
	EXTRACT(QUARTER FROM sale_date) = 4;

-- To get the total revenue according to city, the query can be adjusted
SELECT cy.city_name AS city_name,
SUM(s.total) AS total_revenue
FROM sales AS s
JOIN customers AS c ON s.customer_id = c.customer_id
JOIN city AS cy ON cy.city_id = c.city_id
WHERE EXTRACT(YEAR FROM s.sale_date) = 2023
	AND 
	EXTRACT(QUARTER FROM s.sale_date) = 4
GROUP BY cy.city_name
ORDER BY SUM(s.total) DESC;

-- Q3. Sales count for each product
-- How many units of each coffee product has been sold?

SELECT p.product_name,
	COUNT(s.sale_id) AS total_orders
FROM products AS p
JOIN sales AS s ON s.product_id = p.product_id
GROUP BY 1
ORDER BY 2 DESC;

-- Q4. Average sales amount per city
-- What is the average sales amount per customer in each city

-- I need to find each city and their total sale, no of customers in each city
SELECT cy.city_name AS city_name,
	SUM(s.total) AS total_revenue,
	COUNT(DISTINCT s.customer_id) AS total_customers,
	ROUND(
		SUM(s.total)::numeric/
		COUNT(DISTINCT s.customer_id)::numeric,2) AS avg_sale_per_customer
FROM sales AS s -- we're adding the ::numeric as a type cast to avoid errors
JOIN customers AS c ON s.customer_id = c.customer_id
JOIN city AS cy ON cy.city_id = c.city_id
GROUP BY cy.city_name
ORDER BY SUM(s.total) DESC;

-- Q5. City population and coffee consumers
-- Provide a list of cities along with their estimated population and coffee consumers
-- Estimated consumers is defined as 25% of total population
-- Return the city name, total current customers, estimated customers

WITH city_table AS
	(SELECT city_name,
	ROUND((population * 0.25)/1000000 , 2) AS coffee_consumers_in_millions
	FROM city),
customers_table AS
	(SELECT cy.city_name,
		COUNT(DISTINCT c.customer_id) AS unique_customers
	FROM sales AS s 
	JOIN customers AS c ON s.customer_id = c.customer_id
	JOIN city AS cy ON cy.city_id = c.city_id
	GROUP BY 1)
SELECT ct.city_name, ct.coffee_consumers_in_millions, cut.unique_customers
FROM city_table AS ct
JOIN customers_table AS cut
ON cut.city_name = ct.city_name;

-- Q6. Top selling products by city
-- What are the top 3 selling products in each city based on the sales volume?

SELECT *
FROM
	(SELECT c.city_name,
		p.product_name,
		COUNT(s.sale_id) AS total_orders,
		DENSE_RANK() OVER(PARTITION BY c.city_name ORDER BY COUNT(s.sale_id) DESC) as rnk
		--you can't use rnk to filter the data bcos a column created using a window function is not an 
		--actual column
	FROM sales AS s
	JOIN products AS p
	ON s.product_id = p.product_id
	JOIN customers AS ct 
	ON ct.customer_id = s.customer_id
	JOIN city AS c
	ON c.city_id = ct.city_id
	GROUP BY 1, 2) AS t1 --doing this will create a new table where rnk will now become a column
WHERE rnk <= 3;

-- Q7. Customer segmentation by city
-- How many unique customers are there in each city who have purchased coffee products?

SELECT *
FROM products;
SELECT cy.city_name,
		COUNT(DISTINCT c.customer_id) AS unique_customers
FROM sales AS s 
JOIN customers AS c ON s.customer_id = c.customer_id
JOIN city AS cy ON cy.city_id = c.city_id
WHERE
	s.product_id IN (1,2,3,4,5,6,7,8,9,10,11,12,13,14)
	-- you can also write it as BETWEEN 1 AND 14
GROUP BY 1;

--Q8. Average sales vs. rent
-- Find each city and their average sale per customer and avg rent per customer

WITH city_table AS
	(SELECT cy.city_name,
		SUM(s.total) AS total_revenue
		COUNT(DISTINCT s.customer_id) AS total_customers,
		ROUND(
			SUM(s.total)::numeric/
			COUNT(DISTINCT s.customer_id)::numeric,2) AS avg_sale_per_customer
	FROM sales AS s 
	JOIN customers AS c ON s.customer_id = c.customer_id
	JOIN city AS cy ON cy.city_id = c.city_id
	GROUP BY 1),
city_rent AS
	(SELECT city_name, estimated_rent
	FROM city)
SELECT ct.city_name, cr.estimated_rent, ct.total_customers, ct.avg_sale_per_customer,
	ROUND(cr.estimated_rent::numeric/ct.total_customers::numeric, 2) AS avg_rent_per_customer
FROM city_table AS ct
JOIN city_rent AS cr
ON cr.city_name = ct.city_name
ORDER BY 4 DESC;

-- Q9. Monthly Sales growth
-- sales growth rate: calculate the percentage growth or decline in sales over different time periods(monthly)

WITH monthly_sale AS
	(SELECT cy.city_name,
		EXTRACT(MONTH FROM sale_date) AS month,
		EXTRACT(YEAR FROM sale_date) AS year,
		SUM(s.total) AS total_sale
	FROM sales AS s 
	JOIN customers AS c ON s.customer_id = c.customer_id
	JOIN city AS cy ON cy.city_id = c.city_id
	GROUP BY 1, 2, 3
	ORDER BY 1, 3, 2),
growth_ratio_tab AS
		(SELECT city_name, month, year,
			total_sale AS current_month_sale,
			LAG(total_sale, 1) OVER(PARTITION BY city_name) AS last_month_sale
		FROM monthly_sale)
SELECT city_name, month, year,
		current_month_sale,
		last_month_sale,
		ROUND((current_month_sale - last_month_sale)::numeric/
		last_month_sale::numeric * 100, 2) AS growth_ratio -- the formula to calculate the grwoth ratio
FROM growth_ratio_tab
WHERE last_month_sale IS NOT NULL;

--Q10 Market Potential Analysis
-- Identify the top 3 cities based on highest sales, return the city name,
-- total sale, total rent, total customers, estimated coffee consumer

WITH city_table AS
	(SELECT cy.city_name,
		SUM(s.total) AS total_revenue,
		COUNT(DISTINCT s.customer_id) AS total_customers,
		ROUND(
			SUM(s.total)::numeric/
			COUNT(DISTINCT s.customer_id)::numeric,2) AS avg_sale_per_customer
	FROM sales AS s 
	JOIN customers AS c ON s.customer_id = c.customer_id
	JOIN city AS cy ON cy.city_id = c.city_id
	GROUP BY 1),
city_rent AS
	(SELECT city_name, estimated_rent,
	ROUND((population * 0.25)/1000000 , 2) AS estimated_coffee_consumers_millions
	FROM city)
SELECT ct.city_name, ct.total_revenue,
	cr.estimated_rent AS total_rent, 
	ct.total_customers,
	estimated_coffee_consumers_millions,
	ct.avg_sale_per_customer,
	ROUND(cr.estimated_rent::numeric/ct.total_customers::numeric, 2) AS avg_rent_per_customer
FROM city_table AS ct
JOIN city_rent AS cr
ON cr.city_name = ct.city_name
ORDER BY 2 DESC
LIMIT 3;

/*
-- Recommendations (Top 3 cities for Monday Coffee to invest in)
City 1: Pune
Pune has the highest revenue, it's average rent per customer is really low compared to other cities.
It also has high average customer sales. 

City 2: Delhi
Delhi has the fifth highest revenue and the highest estimated coffee consumers
which is 7.7M, this means Monday Coffee can acquire more customers in this city.
It's average rent per customer is also relatively low with a high average customer sales. 
 
City 3: Japur
Japur has the fourth highest revenue, but unlike Bangalore (which has an average rent 
per customer of 761), its average rent per customer is just 156.52. This figure is the lowest 
among the top 5 cities based on revenue.