-- Previously, we couldn't link provinces and towns to the type of water sources, the number of people served by those sources, queue times, or pol-
-- lution data, but we can now. So, what type of relationships can we look at?
-- Things that spring to mind for me:
-- 1. Are there any specific provinces, or towns where some sources are more abundant?
-- 2. We identified that tap_in_home_broken taps are easy wins. Are there any towns where this is a particular problem?

-- To answer question 1, we will need province_name and town_name from the location table. We also need to know type_of_water_source and
-- number_of_people_served from the water_source table.

-- The problem is that the location table uses location_id while water_source only has source_id. 
-- So we won't be able to join these tables directly. But the visits table maps location_id and source_id. 
-- So if we use visits as the table we query from, we can join location where

-- the location_id matches, and water_source where the source_id matches.

-- Before we can analyse, we need to assemble data into a table first. 
-- It is quite complex, but once we're done, the analysis is much simpler!

select loc.province_name, loc.town_name, loc.location_id, v.location_id, v.visit_count
from location as loc
join visits as v
on loc.location_id = v.location_id
where v.visit_count= 1;

-- Now, we can join the water_source table on the key shared between water_source and visits.
select loc.province_name, loc.town_name, loc.location_id, v.location_id, v.visit_count, ws.type_of_water_source, ws.source_id,
ws.number_of_people_served
from location as loc
join visits as v
on loc.location_id= v.location_id
join water_source as ws
on v.source_id = ws.source_id
-- WHERE v.location_id = 'AkHa00103'
where v.visit_count = 1;

-- Ok, now that we verified that the table is joined correctly, we can remove the location_id and visit_count columns.
select loc.province_name, loc.town_name, ws.type_of_water_source, ws.source_id, loc.location_type, v.time_in_queue, 
ws.number_of_people_served
from location as loc
join visits as v
on loc.location_id= v.location_id
join water_source as ws
on v.source_id = ws.source_id
-- WHERE v.location_id = 'AkHa00103'
where v.visit_count = 1;

-- Last one! Now we need to grab the results from the well_pollution table.
-- This one is a bit trickier. The well_pollution table contained only data for well. If we just use JOIN, we will do an inner join, so that only records
-- that are in well_pollution AND visits will be joined. We have to use a LEFT JOIN to join the results from the well_pollution table for well
-- sources, and will be NULL for all of the rest. Play around with the different JOIN operations to make sure you understand why we used LEFT JOIN.

CREATE VIEW combined_analysis_table AS
-- −− This view assembles data from different tables into one to simplify analysis
select loc.province_name, loc.town_name, ws.type_of_water_source, ws.source_id, loc.location_type, v.time_in_queue, wp.results,v.source_id as visit_source_id,
ws.number_of_people_served
from location as loc
join visits as v
on loc.location_id= v.location_id
join water_source as ws
on v.source_id = ws.source_id
-- WHERE v.location_id = 'AkHa00103'
left join well_pollution as wp
on v.source_id= wp.source_id
where v.visit_count = 1
;
-- I tried using right join which is supposed to show null for visits source id conforming to where there is data for wp source id(right) but none for visits source id but it occurred to me that since wp is only for well, it means there will be no null for visit source id since it contains source id for both wells and other type of water. But on using left join, there wil be null values in wp source id (and results column) because there are no source ids for other type of water source on the visit table

-- Chidi's code looks more organised..lol
-- SELECT
-- water_source.type_of_water_source AS source_type,
-- location.town_name,
-- location.province_name,
-- location.location_type,
-- water_source.number_of_people_served AS people_served,
-- visits.time_in_queue,
-- well_pollution.results
-- FROM
-- visits
-- LEFT JOIN
-- well_pollution
-- ON well_pollution.source_id = visits.source_id
-- INNER JOIN
-- location
-- ON location.location_id = visits.location_id
-- INNER JOIN
-- water_source
-- ON water_source.source_id = visits.source_id
-- WHERE
-- visits.visit_count = 1;

select * from combined_analysis_table;

-- THE LAST ANALYSIS
-- We're building another pivot table! This time, we want to break down our data into provinces or towns and source types. If we understand where
-- the problems are, and what we need to improve at those locations, we can make an informed decision on where to send our repair teams.


WITH province_totals AS (-- This CTE calculates the population of each province
SELECT
province_name,
SUM(number_of_people_served) AS total_ppl_serv
FROM
combined_analysis_table
GROUP BY
province_name
)

-- SELECT
-- *
-- FROM
-- province_totals;
SELECT
ct.province_name,
-- These case statements create columns for each type of source.
-- The results are aggregated and percentages are calculated
-- The main query selects the province names, and then like we did last time, we create a bunch of columns for each type of water source with CASE statements, sum each of them together, and calculate percentages.
-- We join the province_totals table to our combined_analysis_table so that the correct value for each province's pt.total_ppl_serv value is used.
-- Finally we group by province_name to get the provincial percentages.
ROUND((SUM(CASE WHEN type_of_water_source = 'river'
THEN number_of_people_served ELSE 0 END) * 100.0 / pt.total_ppl_serv), 0) AS river,
ROUND((SUM(CASE WHEN type_of_water_source = 'shared_tap'
THEN number_of_people_served ELSE 0 END) * 100.0 / pt.total_ppl_serv), 0) AS shared_tap,
ROUND((SUM(CASE WHEN type_of_water_source = 'tap_in_home'
THEN number_of_people_served ELSE 0 END) * 100.0 / pt.total_ppl_serv), 0) AS tap_in_home,
ROUND((SUM(CASE WHEN type_of_water_source = 'tap_in_home_broken'
THEN number_of_people_served ELSE 0 END) * 100.0 / pt.total_ppl_serv), 0) AS tap_in_home_broken,
ROUND((SUM(CASE WHEN type_of_water_source = 'well'
THEN number_of_people_served ELSE 0 END) * 100.0 / pt.total_ppl_serv), 0) AS well
FROM
combined_analysis_table ct
JOIN
province_totals pt ON ct.province_name = pt.province_name
GROUP BY
ct.province_name
ORDER BY
ct.province_name;


-- • Look at the river column, Sokoto has the largest population of people drinking river water. We should send our drilling equipment to Sokoto
-- first, so people can drink safe filtered water from a well.
-- • The majority of water from Amanzi comes from taps, but half of these home taps don't work because the infrastructure is broken. We need to
-- send out engineering teams to look at the infrastructure in Amanzi first. Fixing a large pump, treatment plant or reservoir means that
-- thousands of people will have running water. This means they will also not have to queue for water, so we improve two things at once.

-- Let's aggregate the data per town now. You might think this is simple, but one little town makes this hard. Recall that there are two towns in Maji

-- Ndogo called Harare. One is in Akatsi, and one is in Kilimani. Amina is another example. So when we just aggregate by town, SQL doesn't distin-guish between the different Harare's, so it combines their results.

-- To get around that, we have to group by province first, then by town, so that the duplicate towns are distinct because they are in different towns.

CREATE TEMPORARY TABLE town_aggregates
with town_totalss as (-- This CTE calculates the population of each town
-- Since there are two Harare towns, we have to group by province_name and town_name
SELECT province_name, town_name, SUM(number_of_people_served) AS total_ppl_serv
FROM combined_analysis_table
GROUP BY province_name,town_name
)


SELECT
ct.province_name,
ct.town_name,
ROUND((SUM(CASE WHEN type_of_water_source = 'river'
THEN number_of_people_served ELSE 0 END) * 100.0 / tt.total_ppl_serv), 0) AS river,
ROUND((SUM(CASE WHEN type_of_water_source = 'shared_tap'
THEN number_of_people_served ELSE 0 END) * 100.0 / tt.total_ppl_serv), 0) AS shared_tap,
ROUND((SUM(CASE WHEN type_of_water_source = 'tap_in_home'
THEN number_of_people_served ELSE 0 END) * 100.0 / tt.total_ppl_serv), 0) AS tap_in_home,
ROUND((SUM(CASE WHEN type_of_water_source = 'tap_in_home_broken'
THEN number_of_people_served ELSE 0 END) * 100.0 / tt.total_ppl_serv), 0) AS tap_in_home_broken,
ROUND((SUM(CASE WHEN type_of_water_source = 'well'
THEN number_of_people_served ELSE 0 END) * 100.0 / tt.total_ppl_serv), 0) AS well
FROM
combined_analysis_table ct
JOIN  -- Since the town names are not unique, we have to join on a composite key
town_totalss tt ON ct.province_name = tt.province_name AND ct.town_name = tt.town_name
GROUP BY -- We group by province first, then by town.
ct.province_name,
ct.town_name
ORDER BY
ct.town_name;





-- Here the CTE calculates town_totals which returns three columns:
-- province_name,
-- town_name,
-- total_ppl_serv.
-- In the main query we select the province_name and the town_name and then calculate the percentage of people using each source type, using the
-- CASE statements.
-- Then we join town_totals to combined_analysis_table, but this time the town_names are not unique, so we have to join province_name, but we -- check that both the province_name and town_name matches the values in combined_analysis_table.
-- Before we jump into the data, let's store it as a temporary table first, so it is quicker to access.
-- Temporary tables in SQL are a nice way to store the results of a complex query. We run the query once, and the results are stored as a table. The
-- catch? If you close the database connection, it deletes the table, so you have to run it again each time you start working in MySQL. The benefit is
-- that we can use the table to do more calculations, without running the whole query each time.
-- So, let's order the results set by each column. If we order river DESC it confirms what we saw on a provincial level; People are drinking river water
-- in Sokoto.
select * from town_aggregates
order by river desc;

-- There are still many gems hidden in this table. For example, which town has the highest ratio of people who have taps, but have no running water?
SELECT 
    province_name,
    town_name,
    ROUND(tap_in_home_broken / (tap_in_home_broken + tap_in_home) *

100,0) AS Pct_broken_taps
FROM
    town_aggregated_water_access;
-- We can see that Amina has infrastructure installed, but almost none of it is working, and only the capital city, Dahabu's water infrastructure works.
-- Strangely enough, all of the politicians of the past government lived in Dahabu, so they made sure they had water. The point is, look how simple our
-- query is now! It's like we're back at the beginning of our journey!

-- SUMMARY REPORT
-- A PRACTICAL PLAN

-- Our final goal is to implement our plan in the database.
-- We have a plan to improve the water access in Maji Ndogo, so we need to think it through, and as our final task, create a table where our teams
-- have the information they need to fix, upgrade and repair water sources. They will need the addresses of the places they should visit (street
-- address, town, province), the type of water source they should improve, and what should be done to improve it.
-- We should also make space for them in the database to update us on their progress. We need to know if the repair is complete, and the date it was
-- completed, and give them space to upgrade the sources. Let's call this table Project_progress.

-- CREATE TABLE Project_progress (
-- Project_id SERIAL PRIMARY KEY,
/* Project_id −− Unique key for sources in case we visit the same

source more than once in the future.

*/
-- source_id VARCHAR(20) NOT NULL REFERENCES water_source(source_id) ON DELETE CASCADE ON UPDATE CASCADE,
/* source_id −− Each of the sources we want to improve should exist,

and should refer to the source table. This ensures data integrity.

Address VARCHAR(50), −− Street address
Town VARCHAR(30),
Province VARCHAR(30),
Source_type VARCHAR(50),
Improvement VARCHAR(50), −− What the engineers should do at that place
Source_status VARCHAR(50) DEFAULT 'Backlog' CHECK (Source_status IN ('Backlog', 'In progress', 'Complete')),
/* Source_status −− We want to limit the type of information engineers can give us, so we
limit Source_status.
− By DEFAULT all projects are in the "Backlog" which is like a TODO list.
− CHECK() ensures only those three options will be accepted. This helps to maintain clean data.
*/
-- Date_of_completion DATE, −− Engineers will add this the day the source has been upgraded.
-- Comments TEXT −− Engineers can leave comments. We use a TEXT type that has no limit on char length



CREATE TABLE Project_progress (
Project_id SERIAL PRIMARY KEY,
source_id VARCHAR(20) NOT NULL REFERENCES water_source(source_id) ON DELETE CASCADE ON UPDATE CASCADE,
Address VARCHAR(50),
Town VARCHAR(30),
Province VARCHAR(30),
Source_type VARCHAR(50),
Improvement VARCHAR(50),
Source_status VARCHAR(50) DEFAULT 'Backlog' CHECK (Source_status IN ('Backlog', 'In progress', 'Complete')),
Date_of_completion DATE,
Comments TEXT
);


-- At a high level, the Improvements are as follows:
-- 1. Rivers → Drill wells
-- 2. wells: if the well is contaminated with chemicals → Install RO filter
-- 3. wells: if the well is contaminated with biological contaminants → Install UV and RO filter
-- 4. shared_taps: if the queue is longer than 30 min (30 min and above) → Install X taps nearby where X number of taps is calculated using X
-- = FLOOR(time_in_queue / 30).
-- 5. tap_in_home_broken → Diagnose local infrastructure

-- Can you see that for wells and shared taps we have some IF logic, so we should be thinking CASE functions! Let's take the various Improvements
-- one by one, then combine them into one query at the end.
-- To make this simpler, we can start with this query to gather all the info from different tables and filter accordingly:
CREATE VIEW sourcee_to_improve AS
-- This shows sources to be improved
SELECT loc.address, loc.province_name, loc.town_name,
ws.type_of_water_source, ws.source_id, wp.results, visits.time_in_queue
from water_source as ws
left join well_pollution as wp
-- selecting all of the source_ids from ws whether they have a well pollution result or not
on ws.source_id= wp.source_id
JOIN
-- using join here to get all corresponding sourcce from the previous table (with result and no result) that was visited. We are joining visits to ws and not wp even though theyboth have source ids because it will return result for only where visits source id match wp source id and the result will be biased because it only contains result for well only
-- join visits because location does not have a common key with wp and ws
visits as visits ON ws.source_id = visits.source_id
JOIN
-- using join here to get all of their location
location as loc ON loc.location_id = visits.location_id

where visits.visit_count= 1
AND ( -- AND one of the following (OR) options must be true as well.
wp.results != 'Clean'
OR ws.type_of_water_source IN ('tap_in_home_broken','river')
OR (ws.type_of_water_source = 'shared_tap' AND visits.time_in_queue>=30)

);

select * from sourcee_to_improve;



-- Step 1: Wells
-- Let's start with wells. Depending on whether they are chemically contaminated, or biologically contaminated — we'll decide on the interventions.

-- Use some control flow logic to create Install UV filter or Install RO filter values in the Improvement column where the results of the pollu-
-- tion tests were Contaminated: Biological and Contaminated: Chemical respectively. Think about the data you'll need, and which table to find it in. Use ELSE NULL for the final alternative.

INSERT INTO project_progress (source_id, Address, Town, Province, source_type, Improvement
 )


SELECT 
source_id,
address,
town_name,
province_name,
type_of_water_source,
CASE 
  WHEN type_of_water_source = 'well' AND results = 'Contaminated: Biological' THEN 'Install UV filter'
  WHEN type_of_water_source = 'well' AND results = 'Contaminated: Chemical' THEN 'Install RO filter'
 WHEN type_of_water_source = 'river' THEN 'Drill well'
  WHEN type_of_water_source = 'shared_tap' AND time_in_queue > 30 THEN CONCAT("Install ", FLOOR(time_in_queue/30), " taps nearby") 
   WHEN type_of_water_source = 'tap_in_home_broken' THEN 'Diagnose local infrastructure'

   -- I am using FLOOR() here because I want to round the calculation down. Say the queue time is 45 min. The result of 45/30 = 1.5, which could
-- round up to 2. We only want to install a second tap if the queue is > 60 min. Using FLOOR() will round down everything below 59 mins to one extra
-- tap, and if the queue is 60 min, we will install two taps, and so on.
    ELSE null
   END AS Improvement
   
FROM sourcee_to_improve;

-- Step 2: Rivers
-- Now for the rivers. We upgrade those by drilling new wells nearby.- done above
-- Step 4: In-home taps

-- Lastly, let's look at in-home taps, specifically broken ones. These taps indicate broken infrastructure. So these need to be inspected by our engi-
-- neers.

-- LESSON LEARNT
-- When a particular column is not included before the creation of a view, to include it, you will need to recreate the view with a new name