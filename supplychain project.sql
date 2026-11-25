#Your supply chain manager wants to understand which products have
#the highest daily demand to help prioritize inventory planning.

SELECT id, sku, item_label,category, daily_demand,safety_cover_days
FROM items
ORDER BY daily_demand DESC;

#identify products with daily demand greater than 50 units to prioritize inventory monitoring:
SELECT sku, item_label,category, daily_demand
FROM items
WHERE daily_demand > 50
ORDER BY daily_demand DESC;

#Your supply chain manager wants to understand which product categories generate the greatest demand 
#so the company can prioritize inventory planning and supplier coordination
SELECT category,count(*) AS total_products,SUM(daily_demand) AS total_demand ,avg(daily_demand) AS avg_demand
FROM items
GROUP BY category
ORDER BY total_demand DESC;

#Your supply chain manager wants to identify product categories that generate significant daily demand.
#The company plans to prioritize inventory planning for categories 
#with a combined daily demand exceeding 100 units.

SELECT category,count(*) AS total_products,SUM(daily_demand) AS total_demand 
FROM items
GROUP BY category
HAVING total_demand > 100
ORDER BY total_demand DESC;



SELECT category, AVG(unit_cost) AS avg_cost, MAX(unit_cost) AS max_cost
FROM items
GROUP BY category
HAVING avg_cost >25
ORDER BY avg_cost DESC;


#Your inventory manager wants to estimate how many units of safety stock 
#should be maintained for each product.
#The company calculates its target safety stock using:
#Safety Stock=Daily Demand*Safety Cover Days

SELECT sku, item_label, daily_demand,safety_cover_days ,(daily_demand*safety_cover_days) AS safety_stock
FROM items
HAVING safety_stock > 100
ORDER BY safety_stock DESC;


#Identify High-Cost, High-Demand Products:
#Daily Purchasing Cost=Unit Cost*Daily Demand

SELECT sku, item_label, (unit_cost*daily_demand) AS purchasing_cost
FROM items
HAVING purchasing_cost > 500
ORDER BY purchasing_cost DESC;

#Identify Products with Above-Average Costs:
SELECT sku, unit_cost
FROM items
WHERE unit_cost > (
SELECT AVG(unit_cost)
FROM items);

#Inventory Demand Classification:

SELECT count(*) AS num_products,
CASE
    WHEN daily_demand > 100 THEN 'high_demand'
    WHEN daily_demand BETWEEN 50 AND 100 THEN 'medium_demand'
    WHEN daily_demand < 50 THEN 'low_demand'
END AS demand_category
FROM items
GROUP BY demand_category;

#Identify the Most Expensive Products in Each Category:
#identify the three products with the highest unit costs within each category

WITH ranking AS(
SELECT sku,item_label,category,unit_cost,
  RANK() OVER(
     PARTITION BY category
     ORDER BY unit_cost DESC) AS rnk
FROM items)
SELECT sku,item_label,category,unit_cost,rnk
FROM ranking
WHERE rnk <=3;

#Identifying Inventory Replenishment Priorities
#Identify products that account for more than 30% of their category's total safety stock requirement
#Safety Stock=Daily Demand*Safety Cover Days


WITH stock AS(
SELECT sku, category, (daily_demand*safety_cover_days) AS safety_stock,
SUM(daily_demand*safety_cover_days) OVER(
PARTITION BY category) AS total_safety_stock
FROM items)

SELECT sku, category, safety_stock,
(safety_stock/total_safety_stock)*100 AS per_saf_stock
FROM stock
WHERE (safety_stock/total_safety_stock)*100 > 30;

-- Identify each supplier's number of distinct products purchased and their percentage 
-- of the company's total product portfolio to assess supplier dependency.

SELECT sp.supplier_name, COUNT(DISTINCT p.item_id) AS num_products,
(SELECT COUNT(DISTINCT id) FROM items) AS total_prod,
(COUNT(DISTINCT p.item_id) /
        (SELECT COUNT(DISTINCT id) FROM items)) * 100 AS percentage 
FROM suppliers AS sp
INNER JOIN purchase_orders AS p
ON sp.id = p.supplier_id
GROUP BY sp.id,sp.supplier_name
ORDER BY percentage DESC;

-- -- Identify suppliers whose estimated delivery times 
-- exceed their quoted lead times by more than 20%, highlighting potential delivery reliability issues.
-- Estimated Delivery Time=quoted_lead_days*lateness_factor

SELECT supplier_name, quoted_lead_days, (quoted_lead_days * lateness_factor) AS est_delivery_time,
(((quoted_lead_days * lateness_factor)-quoted_lead_days)/(quoted_lead_days))*100 AS percentage_delay
FROM suppliers
WHERE (((quoted_lead_days * lateness_factor)-quoted_lead_days)/(quoted_lead_days))*100 >20
ORDER BY percentage_delay DESC;

-- -- Compare average estimated delivery times and supplier 
-- counts across geographic regions to identify potential supply chain delivery risks.
SELECT supplier_region, COUNT(*) AS num_suppliers, avg(quoted_lead_days * lateness_factor) AS avg_est_delivery_time
FROM suppliers
GROUP BY supplier_region
ORDER BY avg_est_delivery_time DESC;

-- Analyze purchasing activity by counting purchase orders for each supplier,
-- including suppliers with no orders, to assess supplier utilization.

SELECT s.supplier_name, COUNT(p.supplier_id) AS order_nums
FROM suppliers AS s
LEFT JOIN purchase_orders AS p ON s.id = p.supplier_id
GROUP BY s.id,s.supplier_name;

-- Identify products purchased exclusively from a single supplier to assess supplier dependency and potential supply chain risks.

SELECT i.id, i.item_label, MAX(s.supplier_name), COUNT(DISTINCT p.supplier_id) AS num_suppliers
FROM items AS i
LEFT JOIN purchase_orders AS p ON i.id = p.item_id 
LEFT JOIN suppliers AS s ON p.supplier_id = s.id
GROUP BY i.id, i.item_label
HAVING num_suppliers=1;

-- Analyze purchasing activity across product categories and supplier regions to identify geographic sourcing patterns and potential regional dependencies.
SELECT i.category, s.supplier_region, COUNT(p.id) AS num_orders
FROM items AS i
LEFT JOIN purchase_orders AS p ON i.id = p.item_id 
LEFT JOIN suppliers AS s ON p.supplier_id = s.id
GROUP BY i.category, s.supplier_region
ORDER BY num_orders DESC;


-- Calculate each supplier's percentage contribution to total purchase orders and classify supplier dependency levels to assess purchasing concentration risk.
WITH od AS(
SELECT s.id AS supplier_id, s.supplier_name AS supplier_name ,
COUNT(p.id)*100/SUM(COUNT(p.id)) OVER () AS supplier_order_per
FROM suppliers AS s
LEFT JOIN purchase_orders AS p ON s.id = p.supplier_id
GROUP BY s.id, s.supplier_name)

SELECT supplier_id, supplier_name, supplier_order_per,
CASE 
   WHEN supplier_order_per > 10 THEN 'High Dep'
   WHEN supplier_order_per BETWEEN 5 AND 10 THEN 'Med Dep'
   WHEN supplier_order_per < 5 THEN 'Low Dep'
END AS per
FROM od
ORDER BY supplier_order_per DESC;

