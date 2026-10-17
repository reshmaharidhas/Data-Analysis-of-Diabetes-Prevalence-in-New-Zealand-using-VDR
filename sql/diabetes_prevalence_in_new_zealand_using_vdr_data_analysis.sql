SELECT * FROM diabetus_vdr_nz;

CREATE TABLE virtual_diabetus_register_nz_cleaned AS SELECT * FROM diabetus_vdr_nz;

SELECT * FROM virtual_diabetus_register_nz_cleaned;

-- Number of rows
SELECT COUNT(*) FROM virtual_diabetus_register_nz_cleaned;  -- 21 rows
-- Datatype of columns
SHOW COLUMNS FROM virtual_diabetus_register_nz_cleaned;
/*
District	text	
Maori	text	
Pacific people	text	
Indian	text
European/ Other	text
VDR total (age 15-74)	text
VDR total (all ages)	text
Percentage of people in the 15-74 age group	text	*/
--  The datatype of all columns except 'District' needs to be changed to numerical datatypes.
-- Checking for NULL values
SELECT * FROM virtual_diabetus_register_nz_cleaned 
WHERE 
District IS NULL OR 
Maori IS NULL OR 
`Pacific people` IS NULL OR 
Indian IS NULL OR 
`European/ Other` IS NULL OR 
`VDR total (age 15-74)` IS NULL OR 
`VDR total (all ages)` IS NULL OR 
`Percentage of people in the 15-74 age group` IS NULL; -- 0 rows with NULL values.
-- Finding duplicate rows
WITH DuplicateRowsCTE AS(
	SELECT *, DENSE_RANK() OVER(PARTITION BY District ORDER BY District) AS denseRank FROM virtual_diabetus_register_nz_cleaned
)
SELECT * FROM DuplicateRowsCTE WHERE denseRank>1;  -- No duplicate rows based on District name.
-- Checking inconsistencies in data
SELECT District,COUNT(*) FROM virtual_diabetus_register_nz_cleaned GROUP BY District;

/* DATA CLEANING */
-- Rename columns in the table.
ALTER TABLE virtual_diabetus_register_nz_cleaned RENAME COLUMN District TO district;
ALTER TABLE virtual_diabetus_register_nz_cleaned 
RENAME COLUMN Maori TO maori,
RENAME COLUMN `Pacific people` TO pacific_people,
RENAME COLUMN Indian TO indian,
RENAME COLUMN `European/ Other` TO european_or_others,
RENAME COLUMN `VDR total (age 15-74)` TO vdr_total_aged_15_to_74,
RENAME COLUMN `VDR total (all ages)` TO vdr_total_all_ages,
RENAME COLUMN `Percentage of people in the 15-74 age group` TO vdr_pct_aged_15_to_74;
-- Trimming extra spaces around text data in all columns.
UPDATE virtual_diabetus_register_nz_cleaned SET district=TRIM(district);
UPDATE virtual_diabetus_register_nz_cleaned SET maori=TRIM(maori);
UPDATE virtual_diabetus_register_nz_cleaned SET pacific_people=TRIM(pacific_people);
UPDATE virtual_diabetus_register_nz_cleaned SET indian=TRIM(indian);
UPDATE virtual_diabetus_register_nz_cleaned SET european_or_others=TRIM(european_or_others);
UPDATE virtual_diabetus_register_nz_cleaned SET vdr_total_aged_15_to_74=TRIM(vdr_total_aged_15_to_74);
UPDATE virtual_diabetus_register_nz_cleaned SET vdr_total_all_ages=TRIM(vdr_total_all_ages);
UPDATE virtual_diabetus_register_nz_cleaned SET vdr_pct_aged_15_to_74=TRIM(vdr_pct_aged_15_to_74);
-- Removing inconsistencies in text data of all columns except 'District'.
UPDATE virtual_diabetus_register_nz_cleaned SET 
maori=REPLACE(maori,",",""),
pacific_people=REPLACE(pacific_people,",",""),
indian=REPLACE(indian,",",""),
european_or_others=REPLACE(european_or_others,",",""),
vdr_total_aged_15_to_74=REPLACE(vdr_total_aged_15_to_74,",",""),
vdr_total_all_ages=REPLACE(vdr_total_all_ages,",",""),
vdr_pct_aged_15_to_74=REPLACE(vdr_pct_aged_15_to_74,"%","");
-- Changing datatype of columns to INT.
ALTER TABLE virtual_diabetus_register_nz_cleaned 
MODIFY maori INT,
MODIFY pacific_people INT,
MODIFY indian INT,
MODIFY european_or_others INT,
MODIFY vdr_total_aged_15_to_74 INT,
MODIFY vdr_total_all_ages INT;
-- Changing datatype of the last column in the table to float.
ALTER TABLE virtual_diabetus_register_nz_cleaned MODIFY vdr_pct_aged_15_to_74 FLOAT;
-- Rechecking the datatype of columns in the table.
SHOW COLUMNS FROM virtual_diabetus_register_nz_cleaned;
-- FEATURE ENGINEERING
-- Create new column named 'island'
ALTER TABLE virtual_diabetus_register_nz_cleaned ADD island VARCHAR(100);
UPDATE virtual_diabetus_register_nz_cleaned SET island=CASE 
WHEN district IN ('Auckland','Bay of Plenty','Counties Manukau','Hawkes Bay','Hutt','MidCentral','Northland','Tairawhiti','Taranaki','Waikato','Wairarapa','Waitemata','Whanganui') THEN 'North' 
WHEN district="Unknown/Unassigned" THEN "Unknown" 
ELSE 'South' 
END;
-- Creating new column 'most_dominant_ethnicity' 
ALTER TABLE virtual_diabetus_register_nz_cleaned ADD COLUMN dominant_ethnicity VARCHAR(255);
UPDATE virtual_diabetus_register_nz_cleaned SET dominant_ethnicity=CASE 
GREATEST(maori,pacific_people,indian,european_or_others) 
WHEN maori THEN 'Maori' 
WHEN pacific_people THEN 'Pacific' 
WHEN indian THEN 'Indian' 
ELSE "European or others" 
END;
-- Creating new column 'least_dominant_ethnicity' 
ALTER TABLE virtual_diabetus_register_nz_cleaned ADD COLUMN least_dominant_ethnicity VARCHAR(255);
UPDATE virtual_diabetus_register_nz_cleaned SET least_dominant_ethnicity=CASE 
LEAST(maori,pacific_people,indian,european_or_others) 
WHEN maori THEN 'Maori' 
WHEN pacific_people THEN 'Pacific' 
WHEN indian THEN 'Indian' 
ELSE "European or others" 
END;



/* Analysis on cleaned dataset */
-- Which district in New Zealand has more Maori people with diabetus in VDR?
-- Query 1: Using multiple CTE to find the district where more maori people have diabetus.
WITH MaoriMaxPeopleCTE AS (
	SELECT *,MAX(maori) OVER(ORDER BY district) AS maxMaori FROM virtual_diabetus_register_nz_cleaned
),
MaxMaoriDenseRankCTE AS (
	SELECT *,DENSE_RANK() OVER(ORDER BY maxMaori DESC) AS denseRank FROM MaoriMaxPeopleCTE
),
MaxMaoriRowNumCTE AS(
	SELECT *,ROW_NUMBER() OVER(ORDER BY maxMaori DESC) AS rowNum FROM MaxMaoriDenseRankCTE
)
SELECT * FROM MaxMaoriRowNumCTE WHERE rowNum=1; -- Waikato has 7659 maori people with diabetus.
-- Query2: Easy & simple query to find the district where more maori people have diabetus.
SELECT district,maori FROM virtual_diabetus_register_nz_cleaned ORDER BY maori DESC LIMIT 1;


-- What are the top 5 districts with high diabetus for Maori people in NZ?
SELECT district,maori FROM virtual_diabetus_register_nz_cleaned ORDER BY maori DESC LIMIT 5;
/*
Waikato
Counties Manukau
Northland
Bay of Plenty
Waitemata */

-- What are the top 5 districts in NZ with high diabetus for Indians?
SELECT district,indian FROM virtual_diabetus_register_nz_cleaned ORDER BY indian DESC LIMIT 5;
/* Counties Manukau
Auckland
Waitemata
Waikato
Capital and Coast */

-- Which island has many districts with VDR?
SELECT island,COUNT(*) FROM virtual_diabetus_register_nz_cleaned GROUP BY island; -- North has 13 districts, South has 7 districts, & 1 unknown district

-- Find the total number of maori people aged between 15 to 74 with VDR in each island?
SELECT island,SUM(maori) FROM virtual_diabetus_register_nz_cleaned GROUP BY island;  -- North=44087, South=11033, unknown=33

-- Find the total number of indian people aged between 15 to 74 with VDR in each island?
SELECT island,SUM(indian) FROM virtual_diabetus_register_nz_cleaned GROUP BY island;  -- North=24182, South=3944, unknown=8

-- Find the total number of european or other people aged between 15 to 74 with VDR in each island?
SELECT island,SUM(european_or_others) FROM virtual_diabetus_register_nz_cleaned GROUP BY island;  -- North=108235, South=51667, unknown=43

-- Find the total number of pacific people aged between 15 to 74 with VDR in each island?
SELECT island,SUM(pacific_people) FROM virtual_diabetus_register_nz_cleaned GROUP BY island;  -- North=42267, South=6025, unknown=20

-- Find the total number of people registered with diabetus aged between 15 to 74 in New Zealand irrespective of ethnicities?
SELECT island,SUM(vdr_total_aged_15_to_74) AS total_people FROM virtual_diabetus_register_nz_cleaned GROUP BY island;
/*
North	218771
South	72669
Unknown	104
*/

-- Find the maximum number of people with diabetus in each districts by ethnicity?
SELECT district,
GREATEST(maori,pacific_people,indian,european_or_others) AS max_num_people_across_ethnicities 
FROM virtual_diabetus_register_nz_cleaned;

-- Find which ethnicity has highest number of people with diabetus between 15 to 74 in each districts?
SELECT district,GREATEST(maori,pacific_people,indian,european_or_others) AS max_num_people_among_all_ethnicity,
CASE 
GREATEST(maori,pacific_people,indian,european_or_others) 
WHEN maori THEN 'Maori' 
WHEN pacific_people THEN 'Pacific' 
WHEN indian THEN 'Indian' 
ELSE "European or others" 
END AS ethnicity 
FROM virtual_diabetus_register_nz_cleaned;

-- Which district has highest number of people with diabetus aged between 15 to 74?
WITH TotalMaxPeopleAged15To74CTE AS (
	SELECT * FROM virtual_diabetus_register_nz_cleaned ORDER BY vdr_total_aged_15_to_74 DESC
)
SELECT * FROM TotalMaxPeopleAged15To74CTE LIMIT 1;  -- Counties Manukau

-- Which district has the highest number of people with diabetus among all ages?
WITH TotalMaxPeopleAllAgesCTE AS (
	SELECT * FROM virtual_diabetus_register_nz_cleaned ORDER BY vdr_total_all_ages DESC
)
SELECT * FROM TotalMaxPeopleAllAgesCTE LIMIT 1;  -- Counties Manukau

-- Which district has the least number of people with diabetus in New Zealand among all ages?
SELECT * FROM virtual_diabetus_register_nz_cleaned ORDER BY vdr_total_all_ages LIMIT 1;  -- 133 people from Unknown districts

-- Other than unknown districts, which district has the least number of people with diabetus in New Zealand among all ages?
SELECT * FROM virtual_diabetus_register_nz_cleaned WHERE district NOT LIKE 'Unknown/Unassigned' ORDER BY vdr_total_all_ages LIMIT 1;
/* 2104 people from West Coast district */

-- Find the districts where there are highest number of diabetus in Europeans or other ethnicities in New Zealand?
WITH MaxNumPeopleDiabetusByEthnicitiesCTE AS (
	SELECT district,GREATEST(maori,pacific_people,indian,european_or_others) AS max_num_people_among_all_ethnicity,
CASE 
GREATEST(maori,pacific_people,indian,european_or_others) 
WHEN maori THEN 'Maori' 
WHEN pacific_people THEN 'Pacific' 
WHEN indian THEN 'Indian' 
ELSE "European or others" 
END AS ethnicity 
FROM virtual_diabetus_register_nz_cleaned
)
SELECT * FROM MaxNumPeopleDiabetusByEthnicitiesCTE WHERE ethnicity LIKE 'European or others' ORDER BY district;
/* 
Auckland
Bay of Plenty
Canterbury
Capital and Coast
Hawkes Bay
Hutt
MidCentral
Nelson Marlborough
South Canterbury
Southern
Taranaki
Unknown/Unassigned
Waikato
Wairarapa
Waitemata
West Coast
Whanganui */

-- In which districts does the Maori people have more number of diabetus?
WITH MaxNumPeopleDiabetusByEthnicitiesCTE AS (
	SELECT district,GREATEST(maori,pacific_people,indian,european_or_others) AS max_num_people_among_all_ethnicity,
CASE 
GREATEST(maori,pacific_people,indian,european_or_others) 
WHEN maori THEN 'Maori' 
WHEN pacific_people THEN 'Pacific' 
WHEN indian THEN 'Indian' 
ELSE "European or others" 
END AS ethnicity 
FROM virtual_diabetus_register_nz_cleaned
)
SELECT * FROM MaxNumPeopleDiabetusByEthnicitiesCTE WHERE ethnicity LIKE 'Maori';
/* Lakes, Northland, Tairawhiti */

-- In which districts do Indians have highest number of diabetus cases?
WITH MaxNumPeopleDiabetusByEthnicitiesCTE AS (
	SELECT district,GREATEST(maori,pacific_people,indian,european_or_others) AS max_num_people_among_all_ethnicity,
CASE 
GREATEST(maori,pacific_people,indian,european_or_others) 
WHEN maori THEN 'Maori' 
WHEN pacific_people THEN 'Pacific' 
WHEN indian THEN 'Indian' 
ELSE "European or others" 
END AS ethnicity 
FROM virtual_diabetus_register_nz_cleaned
)
SELECT * FROM MaxNumPeopleDiabetusByEthnicitiesCTE WHERE ethnicity LIKE 'Indian';  
-- Indians are not ranking highest in the number of diabetic cases in New Zealand.

-- Find which ethnicities have the least number of diabetic cases in each districts?
WITH LeastNumPeopleDiabetusByEthnicitiesCTE AS (
	SELECT district,LEAST(maori,pacific_people,indian,european_or_others) AS least_num_people_among_all_ethnicity,
CASE 
LEAST(maori,pacific_people,indian,european_or_others) 
WHEN maori THEN 'Maori' 
WHEN pacific_people THEN 'Pacific' 
WHEN indian THEN 'Indian' 
ELSE "European or others" 
END AS ethnicity 
FROM virtual_diabetus_register_nz_cleaned
)
SELECT * FROM LeastNumPeopleDiabetusByEthnicitiesCTE;
-- Find which ethnicity have the most less number of diabetic cases across districts in New Zealand?
WITH LeastNumPeopleDiabetusByEthnicitiesCTE AS (
	SELECT district,LEAST(maori,pacific_people,indian,european_or_others) AS least_num_people,
CASE 
LEAST(maori,pacific_people,indian,european_or_others) 
WHEN maori THEN 'Maori' 
WHEN pacific_people THEN 'Pacific' 
WHEN indian THEN 'Indian' 
ELSE "European or others" 
END AS ethnicity 
FROM virtual_diabetus_register_nz_cleaned
),
CountGroupByEthnicityCTE AS (
	SELECT ethnicity,COUNT(*) FROM LeastNumPeopleDiabetusByEthnicitiesCTE GROUP BY ethnicity ORDER BY COUNT(*) DESC
)
SELECT * FROM CountGroupByEthnicityCTE;


-- Show which ethnicities are ranking highest and lowest in total number of diabetic cases aged between 15 to 74?
SELECT district,
LEAST(maori,pacific_people,indian,european_or_others) AS least_num_people,
CASE 
LEAST(maori,pacific_people,indian,european_or_others) 
WHEN maori THEN 'Maori' 
WHEN pacific_people THEN 'Pacific' 
WHEN indian THEN 'Indian' 
ELSE "European or others" 
END AS ethnicity_of_less_diabetic_cases,
GREATEST(maori,pacific_people,indian,european_or_others) AS highest_num_people,
CASE 
GREATEST(maori,pacific_people,indian,european_or_others) 
WHEN maori THEN 'Maori' 
WHEN pacific_people THEN 'Pacific' 
WHEN indian THEN 'Indian' 
ELSE "European or others" 
END AS ethnicity_of_highest_diabetic_cases  
FROM virtual_diabetus_register_nz_cleaned;



SELECT * FROM virtual_diabetus_register_nz_cleaned;