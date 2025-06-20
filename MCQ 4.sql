-- 1. How many UV filters do we have to install in total
SELECT * FROM md_water_services.project_progress
where Improvement like '%UV filter%';
-- Answer- 5374

-- 2. -- If you were to modify the query to include the percentage of people served by only dirty wells as a water source, which part of the town_aggregated_water_access CTE would you need to change?

-- SELECT
-- 	ct.province_name,
-- 	ct.town_name,
-- 	ROUND((SUM(CASE WHEN source_type = 'river'
-- 		THEN people_served ELSE 0 END) * 100.0 / tt.total_ppl_serv), 0) AS river,
-- 	ROUND((SUM(CASE WHEN source_type = 'shared_tap'
-- 		THEN people_served ELSE 0 END) * 100.0 / tt.total_ppl_serv), 0) AS shared_tap,
-- 	ROUND((SUM(CASE WHEN source_type = 'tap_in_home'
-- 		THEN people_served ELSE 0 END) * 100.0 / tt.total_ppl_serv), 0) AS tap_in_home,
-- 	ROUND((SUM(CASE WHEN source_type = 'tap_in_home_broken'
-- 		THEN people_served ELSE 0 END) * 100.0 / tt.total_ppl_serv), 0) AS tap_in_home_broken,
-- 	ROUND((SUM(CASE WHEN source_type = 'well' AND ct.results != "Clean" 
-- 		THEN people_served ELSE 0 END) * 100.0 / tt.total_ppl_serv), 0) AS well 
--     
-- -- ct.results != "Clean" THIS QUEREY WHICH YOU ADD TO FILTER
-- -- the percentage of people served by only dirty wells as a water source,
-- -- which part of the town_aggregated_water_access
--                
-- FROM
-- 	combined_analysis_table AS ct
-- JOIN -- Since the town names are not unique, we have to join on a composite key
-- 	town_totals AS tt 
-- ON 
-- 	ct.province_name = tt.province_name 
-- 	AND ct.town_name = tt.town_name
-- GROUP BY -- We group by province first, then by town.
-- 	ct.province_name,
-- 	ct.town_name
-- ORDER BY
-- 	ct.town_name;
--     
-- ---------> ANSWER: Add AND combined_analysis_table.results != "Clean" to the well CASE statement.

-- 3. Which province should we send drilling equipment to first?
SELECT 
Province, count(improvement), Improvement
 FROM md_water_services.project_progress
where Improvement like '%Drill well%'
group by Province, Improvement;
-- answer= Sokoto

-- 4. Why was the LEFT JOIN operation used with the well_pollution table in the queries?
-- ANSWER: To include all records from visits and only matching well records from well_pollution

-- 5. Which towns should we upgrade shared taps first?

-- Towns like Bello, Abidjan and Zuri have a lot of people using shared taps, so we will send out teams to those
-- towns first.
-- answer- Bello, Abidjan and Zuri

-- or 

select * from town_aggregates
 where town_name != 'Rural'
order by shared_tap desc;

-- 6. Which of the following improvements is suggested for a chemically contaminated well with a queue time of over 30 minutes?

-- ANSWER: Install RO filter.

-- 7 What is the maximum percentage of the population using rivers in a single town in the Amanzi province?


select * from town_aggregates

where province_name= 'Amanzi'
order by river desc;

-- answer= 8%

-- 8 
-- In which province(s) do all towns have less than 50% access to home taps (including working and broken)?
select province_name, town_name, sum( tap_in_home + tap_in_home_broken) as home_taps from town_aggregates
group by province_name, town_name

order by province_name;
-- answer Hawassa

-- 9. Suppose our finance minister would like to have data to calculate the total cost of the water infrastructure upgrades in Maji Ndogo. You are provided with a list that details both the types and the quantities of upgrades needed. Each type of upgrade has a specific unit cost in USD.

-- Example infrastructure_cost table:

-- Improvement	Unit_cost_USD
-- Drill well

-- 8,500

-- Install UV and RO filter

-- 4,200

-- Diagnose local infrastructure

-- 350

-- ...

-- …

-- Using this list, and the data in the md_water_services database, how would you calculate the total cost of all the infrastructure upgrades in Maji Ndogo?

SELECT 
    Improvement, count(Improvement )* 350
FROM
    project_progress
WHERE
    Improvement = 'Diagnose local infrastructure'
    group by Improvement;
    
    -- answer 
 --    Query the project_progress database to find the quantities of each type of upgrade. Then, use a JOIN operation with the infrastructure_cost table to align the unit costs. Finally, multiply the unit cost for each type by its respective count and sum these totals for an overall estimated cost.
 
 -- 10 What does the following query describe?
 
 SELECT
project_progress.Project_id, 
project_progress.Town, 
project_progress.Province, 
project_progress.Source_type, 
project_progress.Improvement,
Water_source.number_of_people_served,
RANK() OVER(PARTITION BY Province ORDER BY number_of_people_served )
FROM  project_progress 
JOIN water_source 
ON water_source.source_id = project_progress.source_id
WHERE Improvement = "Drill Well"
ORDER BY Province DESC, number_of_people_served;

-- ANSWER: 
-- The query joins the project_progress and water_source tables. 
-- It then ranks the projects where drilling a well was recommended within each province,
-- by the number of people served by the water source. Using this table, 
-- engineers can be sent to the locations to drill wells where it is most needed.















