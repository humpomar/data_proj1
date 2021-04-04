-- -------------------------------------------------------------------------- CONFIRMED + LOOKUP + TESTS

CREATE OR REPLACE TABLE t_martina_humpolik_projekt_SQL_covid AS ( 	
	SELECT 
		cd.date,
		CASE WHEN weekday(cd.date) IN (5, 6) THEN 1 ELSE 0 END AS weekend,
		cd.country, lt.iso3,
		cd.confirmed AS daily_confirmed,	
		ct.tests_performed AS daily_tests_performed
	FROM covid19_basic_differences AS cd
	LEFT JOIN lookup_table AS lt
		ON cd.country = lt.country AND lt.province IS NULL
	LEFT JOIN covid19_tests ct
			ON lt.iso3 = ct.ISO	AND cd.date = ct.`date` AND ct.entity = 'tests performed'
);
			
-- ---------------------------------------- LOOKUP + COUNTRIES + ECONOMIES + RELIGIONS + LIFE EXPECTANCY 
	
CREATE OR REPLACE TABLE t_martina_humpolik_projekt_SQL_countries AS (
	SELECT lt.country, lt.iso3,
		CASE WHEN c.country != lt.country THEN c.country END AS alternative_name,
		lt.population, 
		c.hemisphere, c.population_density, c.median_age_2018,
		e19.mortality_under5_2019, e19.GDP_per_capita_2019, e17.gini_2017,
		ROUND(r.chris/lt.population, 2) AS christianity_share,
		ROUND(r.isl/lt.population, 2) AS islam_share,
		ROUND(r.unaf/lt.population, 2) AS unaffiliated_share,
		ROUND(r.hind/lt.population, 2) AS hinduism_share,
		ROUND(r.bud/lt.population, 2) AS buddhism_share,
		ROUND(r.folk/lt.population, 2) AS folk_relig_share,
		ROUND(r.other/lt.population, 2) AS other_relig_share,
		ROUND(r.jud/lt.population, 2) AS judaism_share,
		le.life_exp_diff_2015_1965
	
	FROM (SELECT * FROM lookup_table WHERE province IS NULL) AS lt

	-- getting hemisphere, population density and median age from COUNTRIES
	LEFT JOIN (
		SELECT
			country,
			CASE WHEN country = 'Namibia' THEN 'NAM'
				WHEN country = 'East Timor' THEN 'TLS'
				ELSE iso3 END AS iso3,
			CASE WHEN north > 0 AND south < 0 THEN 'equat'
				WHEN north < 0 THEN 'south'
				WHEN south > 0 THEN 'north' END AS hemisphere,
			population_density,
			median_age_2018
		FROM countries WHERE country NOT IN ('Timor-Leste', 'Northern Ireland') ) AS c
	ON lt.iso3 = c.iso3

	-- getting GDP/population and moratily in 2019 from ECONOMIES
	LEFT JOIN (
		SELECT
			country,
			ROUND(GDP/population) AS GDP_per_capita_2019,
			mortaliy_under5 AS mortality_under5_2019
		FROM economies WHERE `year` = 2019 ) AS e19
	ON lt.country = e19.country OR c.country = e19.country

	-- getting gini in 2017 from ECONOMIES
	LEFT JOIN (
		SELECT
			country,
			gini AS gini_2017
		FROM economies WHERE `year` = 2017 ) AS e17
	ON lt.country = e17.country OR c.country = e17.country

	-- getting religion shares from RELIGIONS	
	LEFT JOIN (	
		SELECT country,
			SUM(CASE WHEN religion = 'Christianity' THEN population ELSE 0 END) AS chris,
			SUM(CASE WHEN religion = 'Islam' THEN population ELSE 0 END) AS isl,
			SUM(CASE WHEN religion = 'Unaffiliated Religions' THEN population ELSE 0 END) AS unaf,
			SUM(CASE WHEN religion = 'Hinduism' THEN population ELSE 0 END) AS hind,
			SUM(CASE WHEN religion = 'Buddhism' THEN population ELSE 0 END) AS bud,
			SUM(CASE WHEN religion = 'Folk Religions' THEN population ELSE 0 END) AS folk,
			SUM(CASE WHEN religion = 'Other Religions' THEN population ELSE 0 END) AS other,
			SUM(CASE WHEN religion = 'Judaism' THEN population ELSE 0 END) AS jud	
		FROM religions WHERE `year` = 2020
		GROUP BY country ) AS r
	ON lt.country = r.country OR c.country = r.country	

		-- getting life expectancy difference from LIFE EXPECTANCY
	LEFT JOIN (
		SELECT exp2015.iso3, 
			ROUND(exp2015.life_expectancy - exp1965.life_expectancy, 2) AS life_exp_diff_2015_1965
		FROM (SELECT * FROM life_expectancy WHERE `year` = 2015) AS exp2015
		JOIN (SELECT * FROM life_expectancy WHERE `year` = 1965) AS exp1965
		ON exp2015.iso3 = exp1965.iso3 ) AS le
	ON le.iso3 = lt.iso3
);

-- -------------------------------------------------------------------------------- COUNTRIES + WEATHER
	
CREATE OR REPLACE TABLE t_martina_humpolik_projekt_SQL_weather AS (	
	SELECT 
		c.country, c.iso3,
		w.`date`, w.rain_hours, w.max_wind,
		w_day.avg_day_temperature
	FROM (
		SELECT
			country,
			CASE WHEN country = 'Namibia' THEN 'NAM'
				WHEN country = 'East Timor' THEN 'TLS'
				ELSE iso3 END AS iso3,
			capital_city,
			CASE WHEN capital_city = 'Praha' THEN 'Prague' 
				WHEN capital_city = 'Wien' THEN 'Vienna' 
				WHEN capital_city = 'Warszawa' THEN 'Warsaw'
				WHEN capital_city = 'Roma' THEN 'Rome'
				WHEN capital_city = 'Bruxelles [Brussel]' THEN 'Brussels'		
				WHEN capital_city = 'Luxembourg [Luxemburg/L' THEN 'Luxembourg'			
				WHEN capital_city = 'Lisboa' THEN 'Lisbon'	
				WHEN capital_city = 'Helsinki [Helsingfors]' THEN 'Helsinki'		
				WHEN capital_city = 'Athenai' THEN 'Athens'
				WHEN capital_city = 'Bucuresti' THEN 'Bucharest'
				WHEN capital_city = 'Kyiv' THEN 'Kiev'
				END AS capital_alt
		FROM countries WHERE country NOT IN ('Timor-Leste', 'Northern Ireland') ) AS c

	-- getting rain hours and max wind from the complete weather table
	JOIN (
		SELECT city, `date`,
			SUM(CASE WHEN rain > 0 THEN 3 ELSE 0 END) AS rain_hours,
			MAX(wind) AS max_wind
		FROM weather
		GROUP BY city, `date`) AS w
	ON w.city = c.capital_city OR w.city = c.capital_alt

	-- getting average temperature from the day part of weather table	
	JOIN (
		SELECT city, `date`, 
			AVG(temp) AS avg_day_temperature 
		FROM weather
		WHERE `hour` IN (6, 9, 12, 15, 18) AND temp IS NOT NULL
		GROUP BY city, `date`) AS w_day
	ON w_day.city = w.city AND w_day.`date` = w.`date`
);
	
-- ----------------------------------------------------------------------------------------- FINAL TABLE	

CREATE OR REPLACE TABLE t_martina_humpolik_projekt_SQL_final AS (
	SELECT
		covid.`date`,
		covid.weekend,
		covid.country,
		covid.iso3,
		countr.hemisphere,	
	
		CASE WHEN countr.hemisphere = 'equat' THEN 'summer'
			WHEN MONTH(covid.`date`) IN (3, 4, 5) AND countr.hemisphere = 'north' THEN 'spring'
			WHEN MONTH(covid.`date`) IN (3, 4, 5) AND countr.hemisphere = 'south' THEN 'autumn'
			WHEN MONTH(covid.`date`) IN (6, 7, 8) AND countr.hemisphere = 'north' THEN 'summer'
			WHEN MONTH(covid.`date`) IN (6, 7, 8) AND countr.hemisphere = 'south' THEN 'winter'
			WHEN MONTH(covid.`date`) IN (9, 10, 11) AND countr.hemisphere = 'north' THEN 'autumn'		
			WHEN MONTH(covid.`date`) IN (9, 10, 11) AND countr.hemisphere = 'south' THEN 'spring'
			WHEN MONTH(covid.`date`) IN (12, 1, 2) AND countr.hemisphere = 'north' THEN 'winter'
			WHEN MONTH(covid.`date`) IN (12, 1, 2) AND countr.hemisphere = 'south' THEN 'summer'
			END AS season,
	
		covid.daily_confirmed,	
		covid.daily_tests_performed,
		
		countr.population, 
		countr.population_density,
		countr.median_age_2018,
		countr.mortality_under5_2019,
		
		countr.GDP_per_capita_2019,
		countr.gini_2017,
	
		countr.christianity_share,
		countr.islam_share,
		countr.unaffiliated_share,
		countr.hinduism_share,
		countr.buddhism_share,
		countr.folk_relig_share,
		countr.other_relig_share,
		countr.judaism_share,
		countr.life_exp_diff_2015_1965,

		weath.rain_hours,
		weath.max_wind,
		weath.avg_day_temperature
	
	FROM t_martina_humpolik_projekt_SQL_covid AS covid
	
	LEFT JOIN t_martina_humpolik_projekt_SQL_weather AS weath
	ON weath.iso3 = covid.iso3 AND weath.`date` = covid.`date`
	
	LEFT JOIN t_martina_humpolik_projekt_SQL_countries AS countr
	ON countr.iso3 = covid.iso3
);


-- Count of NOT NULL values in economies
-- gini: 2017 (67), 2018 (29), 2019 (0), 2020 (0) >>> using 2017
-- GDP: 2017 (245), 2018 (243), 2019 (231), 2020 (0) >>> using 2019
-- mortality: 2017 (239), 2018 (239), 2019 (239), 2020 (0) >>> using 2019