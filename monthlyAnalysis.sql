


select 
	
	count(case when [customer_segment] = 'Consumer' then 1 end) as Consumer,
	count(case when [customer_segment] = 'Premium' then 1 end) as Premium,
	count(case when [customer_segment] = 'VIP' then 1 end) as VIP,
	count(case when [customer_segment] = 'Business' then 1 end) as Business

from [E-Commerce_Sales_Analytics].[dbo].[historical_sales_data]





select 
	[customer_country],
	count( DISTINCT customer_id) as countCountry
from [E-Commerce_Sales_Analytics].[dbo].[historical_sales_data]
group by [customer_country]



select 
	[customer_country],
	count(order_id) as countCountry
from [E-Commerce_Sales_Analytics].[dbo].[historical_sales_data]
group by [customer_country]




--region has 5 values, but check whether they mean the same thing in every country before comparing across it.
--trying to find out for each country how many orders come from each region 
select 
	customer_country,
	count(case when region = 'North' then 1 end) as North,
	count(case when region = 'South' then 1 end) as south,
	count(case when region = 'East' then 1 end) as East,
	count(case when region = 'West' then 1 end) as West,
	count(case when region = 'Central' then 1 end) as Central
from [E-Commerce_Sales_Analytics].[dbo].[historical_sales_data]
group by customer_country




--trying to where customer comes from, from each region in their countries


with customers_regions as (

	select 
		customer_country,
		count(distinct case when region = 'North' then customer_id end) as North,
		count(distinct case when region = 'South' then 1 end) as south,
		count(distinct case when region = 'East' then 1 end) as East,
		count(distinct case when region = 'West' then 1 end) as West,
		count(distinct case when region = 'Central' then 1 end) as Central
	from [E-Commerce_Sales_Analytics].[dbo].[historical_sales_data]
	group by customer_country

),

customers_regions_ptc as ( 

select *,
		
	North+South+East+West+Central as total

from customers_regions

)

select 

	customer_country,
    North, South, East, West, Central, total,
    
    -- Multiply by 100.0 to force decimals and prevent SQL's integer division from rounding to 0
    -- NULLIF prevents "Divide by Zero" pipeline crashes if a country somehow has 0 total customers
    round((North * 100.0) / NULLIF(total, 0),2) AS North_Pct,
    round((South * 100.0) / NULLIF(total, 0),2) AS South_Pct,
    round((East * 100.0) / NULLIF(total, 0),2) AS East_Pct,
    round((West * 100.0) / NULLIF(total, 0),2) AS West_Pct,
    round((Central * 100.0) / NULLIF(total, 0),2) AS Central_Pct
	

from customers_regions_ptc




--- Average spending by each segment and country
with customer_seg as (

select customer_country,
	
	count(distinct CASE WHEN customer_segment = 'Business' then customer_id END) as Business,
	count(distinct CASE WHEN customer_segment = 'Consumer' then customer_id END) as Consumer,
	count(distinct CASE WHEN customer_segment = 'Premium' then customer_id END) as Premium,
	count(distinct CASE WHEN customer_segment = 'VIP' then customer_id END) as VIP

from [E-Commerce_Sales_Analytics].[dbo].[historical_sales_data]
group by customer_country

),
customer_ptc as(

select *,
	(Business+Consumer+Premium+VIP) as total

from customer_seg
)

select
	customer_country,
	(Business*100.0)/ nullif(Total,0) as business_ptc,
	(Consumer*100.0)/ nullif(Total,0) as Consumer_ptc,
	(Premium*100.0)/ nullif(Total,0) as Premium_ptc,
	(VIP*100.0)/ nullif(Total,0) as VIP_ptc

from customer_ptc





--Sales & Financial Performance

--Monthly Revenue & Profit Pipeline: Calculate the total net_sales and profit aggregated 
--by month and year using the order_date. Rank the top 5 most profitable months.

select TOP 5
	DATEPART(year, order_date) as year_
	,DATEPART(month, order_date) as month_
	,sum([net_sales]) sumNetSales
	,SUM(profit) AS sumProfit

from [E-Commerce_Sales_Analytics].[dbo].[historical_sales_data]
group by DATEPART(year, order_date), DATEPART(month, order_date) 

order by sumNetSales DESC


--2.Profit Margin Anomaly Detection: Filter for orders where the profit_margin_percentage is negative or below a specific threshold (e.g., 5%). 
--Identify which sales_channel or warehouse is most frequently associated with these loss-making orders.

SELECT sales_channel
     
	,COUNT(order_id) count_losses
	,AVG(profit_margin_percentage) AS avg_negative_margin
FROM [E-Commerce_Sales_Analytics].[dbo].[historical_sales_data]
WHERE profit_margin_percentage <= 0
GROUP BY sales_channel
ORDER BY count([profit_margin_percentage]) desc


--3.	Discount Impact Analysis: Group orders into discount brackets 
--(e.g., No Discount, Low Discount, High Discount) based on the discount_amount. 
--Calculate the average gross_sales and profit for each bracket to determine if high discounts drive higher overall value.





with discount_ptc as (

	select order_id, 
		discount_amount,
		gross_sales,
		round((discount_amount* 100) / nullif(gross_sales,0),2) as discount_ptc,
		profit

	from [E-Commerce_Sales_Analytics].[dbo].[historical_sales_data]

)

SELECT 
	
	CASE WHEN discount_ptc = 0 THEN 'No Discount'
		 WHEN discount_ptc > 0 and discount_ptc <=50 THEN 'Low Discount'
		 WHEN discount_ptc > 50 THEN 'High Discount'
	END as discount_buckets,

	
	COUNT(order_id) AS total_orders,
	ROUND(avg(discount_ptc),2) as avg_discount_ptc,
    ROUND(AVG(gross_sales),2) AS avg_gross_sales,
    ROUND(AVG(profit),2) AS avg_profit

FROM discount_ptc
GROUP BY CASE WHEN discount_ptc = 0 THEN 'No Discount'
		 WHEN discount_ptc > 0 and discount_ptc <=50 THEN 'Low Discount'
		 WHEN discount_ptc > 50 THEN 'High Discount'
	END



--5. Demographic Sales Heatmap: Create a pivot table summarizing total quantity and average 
--net_sales by gender and customer_age bins (e.g., 18-25, 26-35, 36-45, 46+). 


select 
	CASE WHEN customer_age >=18 and customer_age <= 25 then '18-25' 
		 WHEN customer_age >=26 and customer_age <= 35 then '26-35'
		 WHEN customer_age >=36 and customer_age <= 45 then '36-45'
		 WHEN customer_age >=46 then '46+'
	END age_bins,
	gender,
	count(quantity) as order_count,
	round(AVG(net_sales),2) avg_net


from [E-Commerce_Sales_Analytics].[dbo].[historical_sales_data]
group by CASE WHEN customer_age >=18 and customer_age <= 25 then '18-25' 
		 WHEN customer_age >=26 and customer_age <= 35 then '26-35'
		 WHEN customer_age >=36 and customer_age <= 45 then '36-45'
		 WHEN customer_age >=46 then '46+'
	END,
	gender
order by round(AVG(net_sales),2),gender






--6. Loyalty Program Conversion: Calculate the ratio of loyalty_points_redeemed to loyalty_points_earned per customer. Determine 
--if customers with higher redemption ratios have higher customer_rating scores or order frequencies (customer_order_count). 

with ptc_points as(
	select 

		   round((loyalty_points_redeemed * 100)/ nullif(loyalty_points_earned,0),2) ptc_points_spent,

		   customer_rating,
		   customer_order_count

	from [E-Commerce_Sales_Analytics].[dbo].[historical_sales_data]


)

select
	
	CASE WHEN ptc_points_spent >=0 and ptc_points_spent <= 25 then 'low_spent' 
		 WHEN ptc_points_spent >=26 and ptc_points_spent <= 50 then 'low_medium'
		 WHEN ptc_points_spent >=50 and ptc_points_spent <= 75 then 'high_medium'
		 WHEN ptc_points_spent >=75 then 'high_spent'
	END PTC_points_spent,

	round(avg(customer_rating),2) avg_rating,
    sum(customer_order_count) freq
	

from ptc_points
group by CASE WHEN ptc_points_spent >=0 and ptc_points_spent <= 25 then 'low_spent' 
		 WHEN ptc_points_spent >=26 and ptc_points_spent <= 50 then 'low_medium'
		 WHEN ptc_points_spent >=50 and ptc_points_spent <= 75 then 'high_medium'
		 WHEN ptc_points_spent >=75 then 'high_spent'
	END






WITH customer_level_points AS (
    SELECT 
        customer_id,
        -- Sum the points per customer to get their true lifetime ratio
        ROUND((SUM(loyalty_points_redeemed) * 100.0) / NULLIF(SUM(loyalty_points_earned), 0), 2) AS ptc_points_spent,
        AVG(customer_rating) AS avg_customer_rating,
        MAX(customer_order_count) AS true_order_count -- Assuming this column represents their total orders
    FROM [E-Commerce_Sales_Analytics].[dbo].[historical_sales_data]
    GROUP BY customer_id
)
SELECT 
    CASE 
         WHEN ptc_points_spent >= 0 AND ptc_points_spent < 25 THEN 'low_spent' 
         WHEN ptc_points_spent >= 25 AND ptc_points_spent < 50 THEN 'low_medium'
         WHEN ptc_points_spent >= 50 AND ptc_points_spent < 75 THEN 'high_medium'
         WHEN ptc_points_spent >= 75 THEN 'high_spent'
    END AS PTC_points_spent,
    
    ROUND(AVG(avg_customer_rating), 2) AS avg_rating,
    ROUND(AVG(true_order_count), 1) AS avg_frequency

FROM customer_level_points
WHERE ptc_points_spent IS NOT NULL
GROUP BY 
    CASE 
         WHEN ptc_points_spent >= 0 AND ptc_points_spent < 25 THEN 'low_spent' 
         WHEN ptc_points_spent >= 25 AND ptc_points_spent < 50 THEN 'low_medium'
         WHEN ptc_points_spent >= 50 AND ptc_points_spent < 75 THEN 'high_medium'
         WHEN ptc_points_spent >= 75 THEN 'high_spent'
    END
ORDER BY 
    avg_frequency DESC;







--7. Geographic Penetration: Identify the top 3 customer_country and 
--region combinations by total gross_sales. Within those regions, find the most popular payment_method.


WITH paymentMethodAnalysis as (
	select 
		 customer_country,
		 region,
		 payment_method,
		 count(payment_method) countPM,
		 round(sum(gross_sales),2) sumSale
 

	from [E-Commerce_Sales_Analytics].[dbo].[historical_sales_data]
	--where customer_country = 'UK'
	group by customer_country,
	 payment_method,
	 region

),


paymentMethodAnalysisP2 AS (
	select *,
	
		rank() over(partition by customer_country order by countPM desc) as pm_rank

	from paymentMethodAnalysis
--order by sumSale
)

select *


from paymentMethodAnalysisP2
where pm_rank <=5 and customer_country ='USA'
--ORDER BY customer_country, region





WITH TopRegions AS (
    -- Step 1: Find the top 3 country/region combinations globally by gross sales
    SELECT TOP 3 
        customer_country, 
        region, 
        SUM(gross_sales) AS total_sales
    FROM [E-Commerce_Sales_Analytics].[dbo].[historical_sales_data]
    GROUP BY 
        customer_country, 
        region
    ORDER BY 
        total_sales DESC
),
PaymentMethodRanks AS (
    -- Step 2: Join those top 3 regions back to the raw data to count payment methods
    SELECT 
        tr.customer_country,
        tr.region,
        tr.total_sales,
        h.payment_method,
        COUNT(h.order_id) AS pm_count,
        RANK() OVER(PARTITION BY tr.customer_country, tr.region ORDER BY COUNT(h.order_id) DESC) as pm_rank
    FROM TopRegions tr
    INNER JOIN [E-Commerce_Sales_Analytics].[dbo].[historical_sales_data] h
        ON tr.customer_country = h.customer_country 
        AND tr.region = h.region
    GROUP BY 
        tr.customer_country, 
        tr.region, 
        tr.total_sales,
        h.payment_method
)
-- Step 3: Filter for only the #1 most popular payment method in those top areas
SELECT 
    customer_country,
    region,
    total_sales,
    payment_method AS most_popular_payment,
    pm_count
FROM PaymentMethodRanks
WHERE pm_rank = 1
ORDER BY total_sales DESC;



--8. Delivery SLA Compliance: Create a new Boolean column indicating whether an order was delivered on time 
--(delivery_days <= estimated_delivery_days). Calculate the on-time delivery rate grouped by shipping_method and warehouse. 

select shipping_method
	,warehouse

    ,round(avg(case 
		when delivery_days <= estimated_delivery_days then 1.0 else 0.0 
	 end),2) * 100 on_time_delivery_rate_pct

from [E-Commerce_Sales_Analytics].[dbo].[historical_sales_data]
group by shipping_method,
	warehouse
order by on_time_delivery_rate_pct


--9. Shipping Cost Efficiency: Calculate the average shipping_cost per unit (quantity) 
--for each warehouse. Identify which warehouse has the highest cost overhead per item shipped. 

select
	 warehouse
	,ROUND(SUM(shipping_cost) / SUM(quantity * 1.0), 2) AS avg_cost_per_unit
from [E-Commerce_Sales_Analytics].[dbo].[historical_sales_data]
group by warehouse
order by avg([shipping_cost]) desc



--12. Channel Performance Matrix: Cross-tabulate marketing_channel against sales_channel to 
--find the most lucrative combinations (e.g., Email Marketing driving Mobile App sales) by summing net_sales. 


select
	 marketing_channel

	,sum(case when sales_channel = 'Mobile App' then net_sales
	 end) as 'Mobile App'
	 ,sum(case when sales_channel = 'Marketplace' then net_sales
	 end) as 'Marketplace'
	 ,sum(case when sales_channel = 'Social Media' then net_sales
	 end) as 'Social Media'
	 ,sum(case when sales_channel = 'Website' then net_sales
	 end) as 'Website'

	 ,round(SUM(net_sales),2) AS Total_Sales

	
from [E-Commerce_Sales_Analytics].[dbo].[historical_sales_data]

group by marketing_channel





--14. Data Cleansing Strategy: Identify all columns with missing values (e.g., return_status, return_reason, coupon_code, campaign_name).
--Write a script to impute categorical nulls with "Not Applicable" and numerical nulls with 0.0. 

SELECT 
    order_id,
    customer_id,
    -- Impute numerical nulls with 0.0
    ISNULL(return_status, 0.0) AS return_status,
    ISNULL(coupon_code, 0.0) AS coupon_code,
    
    -- Impute categorical nulls with 'Not Applicable'
    ISNULL(return_reason, 'Not Applicable') AS return_reason,
    ISNULL(campaign_name, 'Not Applicable') AS campaign_name
    
FROM [E-Commerce_Sales_Analytics].[dbo].[historical_sales_data];
