/* AIRBNB Project
    Designed to analyze in SQL and Tableau to be able to answer at least the following:
		1. Which city has the highest average daily rate (ADR) for Airbnb rentals? Create a Tableau visualization that shows the top 10 cities 
		with the highest ADR and their average rating score, along with a bar chart that shows the distribution of ADR across all cities in the dataset.

		2. What are the most common amenities that Airbnb hosts offer in different cities? Write an SQL query that lists the top 5 amenities offered in 
		each city, along with the percentage of listings that offer each amenity. Create a Tableau visualization that shows the top 10 amenities offered 
		across all cities and their frequency of occurrence.

		3. How does the availability of Airbnb rentals change over time in different cities? Write an SQL query that calculates the number of available listings 
		for each month in each city, and create a Tableau line chart that shows the trend in availability over time for the top 5 cities in the dataset. 
		You could also include a filter that allows users to select a city and see the availability trend for that city specifically.
*/

/* Analyze and prepare the data
	- Add primary keys, unique keys, etc.
    - Take a look at the data, how it is constructed, different values, inconsistencies, etc.
*/

-- Overall review of the columns
select * from data limit 100;

-- Add primary and unique keys for faster queries and optimized table results
alter table data add primary key (id);
alter table data add unique key (`host id`);

-- Look for inconsistencies in grouping or category values
/*
	- There are 13 values that do not have a neighbourhood group (Woodside neighbourhood).
    - There are different spellings for neighbourhood groups, specifically Brooklyn and Manhattan.
    - There are 44 records with no country code and 15 with no country name, which we know in all cases should be United States (US).
*/
select `neighbourhood group`, count(*) as number_of_records 
from data 
group by `neighbourhood group` 
order by number_of_records desc;

select `country code`, count(*) as number_of_records 
from data 
group by `country code` 
order by number_of_records desc;

select country, count(*) as number_of_records 
from data 
group by country 
order by number_of_records desc;

-- There are some negative availability and empty values
select `availability 365`, count(*) as number_of_records 
from data 
group by `availability 365` 
order by number_of_records desc;

select * from data where `availability 365` = '' or cast(`availability 365` as signed) <= 0;

/*
	- This query allows to filter out only neighbourhood which are missing a neighbourhood value and the value that should be assigned.
    - Only the Woodside neighbourhood does not have a neighbourhood assigned, it should be Queens.
*/
with cte as (
	select neighbourhood, `neighbourhood group` 
	from data
	group by neighbourhood, `neighbourhood group`
	order by neighbourhood asc, `neighbourhood group` asc
)
select cte.* 
from cte 
where (select count(*) from data where neighbourhood = cte.neighbourhood and `neighbourhood group` = '') > 0;

/*
	Update the table with cleaned values
*/
-- We update the identified values directly in the table
update data set `neighbourhood group` = 'Brooklyn' where `neighbourhood group` like '%rook%';
update data set `neighbourhood group` = 'Manhattan' where `neighbourhood group` like '%anhat%';
update data set `neighbourhood group` = 'Queens' where neighbourhood = 'Woodside';

-- For the neighbourhood group, we set an implicit inner join to get the correct values in place
update 
	data d,
(
	select neighbourhood, `neighbourhood group` 
	from data
	where `neighbourhood group` <> ''
	group by neighbourhood, `neighbourhood group`
) d_
set d.`neighbourhood group` = d_.`neighbourhood group`
where d.neighbourhood = d_.neighbourhood;

update data set `country code` = 'US';
update data set country = 'United States';

update data set `availability 365` = '0' where `availability 365` = '' or cast(`availability 365` as signed) <= 0;

-- We take the dollar sign off as all prices are listed in dollars and we change the column data type to int, also replace empty values with 0
update data set price = replace(price, '$', '');
update data set price = replace(price, ',', '.');
update data set price = '0' where price = '';
update data set `service fee` = replace(`service fee`, '$', '');
update data set `service fee` = '0' where `service fee` = '';

alter table data modify column price double;
alter table data modify column `service fee` double;

/*
	Results export to CSV file
*/

select 
	'id', 'NAME', 'host id', 'host_identity_verified', 'host name', 'neighbourhood group', 'neighbourhood', 'latitude', 'longitude', 'country', 'country code',
    'instant_bookable', 'cancellation_policy', 'room type', 'construction year', 'price', 'service fee', 'minimum nights', 'number of reviews', 
    'last review', 'reviews per month', 'review rate number', 'calculated host listings count', 'availability 365', 'house_rules', 'license'
union all
select 
	ifnull(id, ""), ifnull(`NAME`, ""), ifnull(`host id`, ""), ifnull(host_identity_verified, ""), ifnull(`host name`, ""),
    ifnull(
		if(`neighbourhood group` = 'Manhattan', 'New York County', if(`neighbourhood group` = 'Queens', 'Queens County', `neighbourhood group`))
	, ""), 
    ifnull(neighbourhood, ""), 
    ifnull(replace(cast(lat as char), '.', ','), ""), 
    ifnull(replace(cast(`long` as char), '.', ','), ""), 
    ifnull(country, ""), ifnull(`country code`, ""), ifnull(instant_bookable, ""), ifnull(cancellation_policy, ""), ifnull(`room type`, ""),
    ifnull(`Construction year`, ""), ifnull(price, ""), ifnull(`service fee`, ""), ifnull(`minimum nights`, ""),
    ifnull(`number of reviews`, ""), ifnull(`last review`, ""), ifnull(replace(`reviews per month`, '.', ','), ""), ifnull(`review rate number`, ""),
    ifnull(`calculated host listings count`, ""), 
    ifnull(if(cast(`availability 365` as signed) > 365, '365', `availability 365`), ""), 
    ifnull(house_rules, ""), ifnull(license, "")
from data
into outfile 'airbnb.csv' 
fields terminated by ','
enclosed by '"'  
escaped by '"' 
lines terminated by '\r\n';