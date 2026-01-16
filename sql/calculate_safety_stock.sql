-- (1)we need to check how many times a product has been ordered in a day - total products sold in a day ... 
-- ...we need :  order_purchase_timestamp,order_id  from olist_orders --left table || order_id, product_id (order_items table)--1st right table table||product_id, product_category_name(product table) --2ndright table
--...we want all the order_id from olist order 
--...SOLUTION: select product_id from product table, product_name from product table 
--...          inner join  olist_order_items
--...          left join olist_products
---...          make a new column called total_products_sold_per_day fill this with COUNT() product_id , group by product_id and date 
----we need to calculate (1) for over a week then take (a) average -- average item sold/ mean  && (b) standard deviation - to calcukae whih day sale was different 
WITH DailyCounts AS (
	select ooi.product_id,
		op.product_category_name,
		DATE(oo.order_purchase_timestamp) as order_date,
		COUNT(ooi.product_id) AS total_sale_per_day
	from olist_orders as oo
		inner join olist_order_items as ooi on oo.order_id = ooi.order_id
		left join olist_products as op on ooi.product_id = op.product_id
	where oo.order_status IN ('delivered', 'shipped', 'invoiced') -- reflects actual decrement in inventory 
	group by ooi.product_id,
		op.product_category_name,
		order_date
),
DailyStats AS (
	SELECT product_id,
		product_category_name,
		AVG(total_sale_per_day) AS avg_daily_demand,
		COALESCE (
			SQRT(
				AVG(total_sale_per_day * total_sale_per_day) - (
					AVG(total_sale_per_day) * AVG(total_sale_per_day)
				)
			),
			0
		) AS demand_variance
	FROM DailyCounts
	GROUP BY product_id,
		product_category_name
),
-- (2) We need to measure Logistics Performance (Lead Time)
-- ...Goal: Find how long it takes from "Click" to "Doorstep" and how much that wait varies.
-- ...Logic: 
--    STEP 1: Calculate raw days per order in 'all_lead_time'.
--    STEP 2: Aggregate those days by product_id in 'lead_time_stats'.
--    STEP 3: Use the Variance formula to find standard_deviation_lead_time (logistics risk).
all_lead_time as (
	SELECT oo.order_id,
		oo.order_purchase_timestamp,
		oo.order_delivered_customer_date,
		JULIANDAY(oo.order_delivered_customer_date) - JULIANDAY(oo.order_purchase_timestamp) AS lead_time
	FROM olist_orders as oo
	WHERE oo.order_delivered_customer_date is not null
		and oo.order_status = 'delivered'
),
lead_time_stats as(
	select ooi.product_id,
		op.product_category_name,
		count(DISTINCT alt.order_id) as unique_delivery_counts,
		---- Count unique trips to validate statistical significance
		---- Average Lead Time (The 'PC' or Performance Cycle in our formula)
		AVG(alt.lead_time) as average_lead_time,
		-- Standard Deviation (Logistics Uncertainty)
		-- We use COALESCE to ensure products with 1 delivery show 0 risk instead of NULL
		COALESCE (
			sqrt(
				avg(alt.lead_time * alt.lead_time) -(avg(alt.lead_time) * avg(alt.lead_time))
			),
			0
		) as lead_time_variance
	from all_lead_time as alt
		inner join olist_order_items as ooi on alt.order_id = ooi.order_id
		left join olist_products as op on ooi.product_id = op.product_id
	group by ooi.product_id
)
/*
 Merging Demand Patterns (DailyStats) with Logistics Performance (LeadTimeStats).
 
 CRITICAL DESIGN CHOICE: LEFT JOIN
 -- If we used an INNER JOIN: We would accidentally delete products that are selling 
 (status: shipped/invoiced) but haven't completed a full delivery cycle yet.
 --Using the LEFT JOIN: Products with missing logistics data show up with NULL 
 lead times. This signals to a manager: "We are selling this, but we don't have 
 enough historical logistics data to calculate a statistical safety stock yet."
 */
SELECT ds.product_id,
	ds.product_category_name,
	lts.unique_delivery_counts,
	ds.avg_daily_demand,
	ds.demand_variance,
	lts.average_lead_time,
	lts.lead_time_variance,
	1.645 * SQRT(
		(
			lts.average_lead_time * POWER(ds.demand_variance, 2) +(
				POWER(ds.avg_daily_demand, 2) * POWER(lts.lead_time_variance, 2)
			)
		)
	) as suggested_safety_stock
FROM DailyStats ds
	LEFT JOIN lead_time_stats lts ON ds.product_id = lts.product_id
WHERE suggested_safety_stock > 0
ORDER BY suggested_safety_stock DESC;