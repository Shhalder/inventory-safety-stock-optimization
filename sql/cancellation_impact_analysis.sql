--Cancelation 
select ooi.product_id,
    SUM(
        CASE
            when oo.order_status = 'canceled' THEN 1
            ELSE 0
        END
    ) * 1.0 / COUNT(*) AS cancelation_rate
from olist_orders as oo
    inner join olist_order_items as ooi on oo.order_id = ooi.order_id
group by ooi.product_id --	having cancelation_rate > 0
SELECT COUNT(DISTINCT ooi.product_id) AS distinct_product_ids
FROM olist_order_items ooi;
SELECT COUNT(DISTINCT ooi.product_id) AS risky_products,
    COUNT(*) * 1.0 / (
        SELECT COUNT(*)
        FROM olist_order_items
    ) AS share_of_order_items
FROM olist_order_items ooi
    JOIN olist_orders oo ON oo.order_id = ooi.order_id
WHERE oo.order_status = 'canceled';
--Inference: Cancellation not significant 
--Only ~1.3% of products ever see cancellations
--Only ~0.48% of order items are canceled
--Cancellations are low-volume and long-tail
--They do not materially affect aggregate demand