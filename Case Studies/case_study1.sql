select * from menu;
select * from members;
select * from sales;

select *
from sales as s
join menu as m
on s.product_id = m.product_id;

-- What is the total amount each customer spent at the restaurant?

select s.customer_id, SUM(price) as total_spent
from sales as s
join menu as m
on s.product_id = m.product_id
group by s.customer_id;

-- How many days has each customer visited the restaurant?

select customer_id, COUNT(DISTINCT order_date) as visit_count 
from sales
group by customer_id;

-- What was the first item from the menu purchased by each customer?
with cte1 as (
select s.customer_id, product_name,
row_number() over(partition by customer_id order by order_date) as row_num
from sales as s
join menu as m
on s.product_id = m.product_id
) select customer_id, product_name
from cte1
where row_num = 1;

-- What is the most purchased item on the menu and how many times was it purchased by all customers?

select product_name, count(product_name) as buying_count
from sales as s
join menu as m
on s.product_id = m.product_id
group by product_name
order by buying_count desc
limit 1;

-- Which item was the most popular for each customer?

with cte2 as (
select customer_id, product_name, count(*) as order_count,
		dense_rank() over(partition by customer_id order by count(*) desc) as rnk
from sales as s
join menu as m
on s.product_id = m.product_id
group by customer_id, product_name
)select * 
from cte2
where rnk = 1;

-- Which item was purchased first by the customer after they became a member?

with cte3 as (
select s.customer_id, order_date, product_name, join_date,
rank() over(partition by s.customer_id order by order_date) as rnk
from sales as s
join menu as m
on s.product_id = m.product_id
join members as mem
on s.customer_id = mem.customer_id
where order_date >= join_date
)select customer_id, product_name
from cte3
where rnk = 1;

-- Which item was purchased just before the customer became a member?

with cte4 as (
select s.customer_id, order_date, product_name, join_date,
rank() over(partition by s.customer_id order by order_date desc) as rnk
from sales as s
join menu as m
on s.product_id = m.product_id
join members as mem
on s.customer_id = mem.customer_id
where order_date < join_date
)select customer_id, product_name
from cte4
where rnk = 1;

-- What is the total items and amount spent for each member before they became a member?

select s.customer_id, count(*) as order_count, sum(price) as total_amount
from sales as s
join menu as m
on s.product_id = m.product_id
join members as mem
on s.customer_id = mem.customer_id
where order_date < join_date
group by s.customer_id;

-- If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?

with cte5 as (
select customer_id,
case 
	when product_name = 'sushi' then price*10*2
    else price*10
    end as points
from sales as s
join menu as m
on s.product_id = m.product_id
) select customer_id, sum(points) as total_points
from cte5
group by customer_id;

-- In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?

with cte6 as (
select s.customer_id, order_date, join_date, product_name, price,
case 
	when s.order_date between join_date and date_add(join_date, interval 7 day) then price*10*2
    when product_name = 'sushi' then price*10*2
    else price*10 end as points
from sales as s
join menu as m
on s.product_id = m.product_id
join members as mem
on s.customer_id = mem.customer_id
where order_date >= join_date and month(order_date) < 2
) select customer_id, sum(points) as total_points
from cte6 
group by customer_id;

-- Determine the name and the price of the product ordered by each customer on all order dates & find out whether the customer was a member on the order date or not

select s.customer_id, order_date, product_name, price,
case 
	when join_date <= order_date then 'Yes'
    else 'No'
    end as member_status
from sales as s
join menu as m
on s.product_id = m.product_id
left join members as mem
on s.customer_id = mem.customer_id;

-- Rank the previous output from pre question based on the order date for each customer. Display null if customer was not a member when food was ordered.

with cte7 as (
select s.customer_id, order_date, product_name, price,
case 
	when join_date <= order_date then 'Yes'
    else 'No'
    end as member_status
from sales as s
join menu as m
on s.product_id = m.product_id
left join members as mem
on s.customer_id = mem.customer_id
) select *,
case 
	when member_status = 'Yes' then rank() over(partition by customer_id, member_status order by order_date)
    else null
    end as order_ranking
from cte7;

-- For each customer, calculate as a percentage how much of the total spend was made after the membership.

with cte8 as(
select s.customer_id,
sum(case
		when order_date >= join_date then price
        else 0
        end) as spend_after_mem,
sum(price) as total_spend
from sales as s
join menu as m
on s.product_id = m.product_id
join members as mem
on s.customer_id = mem.customer_id
group by s.customer_id
) select *, concat(round(spend_after_mem/total_spend *100, 2), '%') as after_mem_perc
from cte8;

WITH product_orders AS (
  SELECT 
    customer_id, 
    s.product_id, 
    product_name,
    order_date,
    LAG(order_date) OVER (PARTITION BY customer_id, s.product_id ORDER BY order_date) AS previous_order_date
  FROM sales AS s
  JOIN menu AS m
  ON s.product_id = m.product_id
)
SELECT 
  customer_id, 
  product_name,
  ROUND(AVG(DATEDIFF(order_date, previous_order_date)),2) AS avg_days_between_orders
FROM product_orders
WHERE previous_order_date IS NOT NULL
GROUP BY customer_id, product_name;

-- Calculate loyalty score depends on total order count, total order date and average order count.

WITH order_summary AS (
  SELECT 
    customer_id, 
    COUNT(DISTINCT order_date) AS active_days,
    COUNT(*) AS total_orders
  FROM sales
  GROUP BY customer_id
),
loyalty_score AS (
  SELECT 
    customer_id, 
    total_orders, 
    active_days, 
    ROUND(total_orders / active_days, 2) AS avg_orders_per_day
  FROM order_summary
)
SELECT 
  customer_id, 
  total_orders, 
  active_days, 
  avg_orders_per_day,
  CASE 
    WHEN avg_orders_per_day >= 2 THEN 'High Loyalty'
    WHEN avg_orders_per_day >= 1 THEN 'Medium Loyalty'
    ELSE 'Low Loyalty'
  END AS loyalty_category
FROM loyalty_score;

