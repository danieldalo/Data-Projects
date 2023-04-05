-- The headers are imported through the table data import wizard
-- Delete previous imported rows in tables so we can later add data through the LOAD DATA LOCAL INFILE statement
TRUNCATE TABLE `name-basics`;
TRUNCATE TABLE `title-basics`;
TRUNCATE TABLE `title-crew`;
TRUNCATE TABLE `title-episodes`;
TRUNCATE TABLE `title-principals`;
TRUNCATE TABLE `title-ratings`;

/*
	Load data from tsv files into each table
*/
LOAD DATA LOCAL INFILE 'C:/Users/ddalo/Documents/_Data Analysis/Data Samples/IMDB/name-basics.tsv'
INTO TABLE `name-basics` 
CHARACTER SET 'utf8mb4'
FIELDS TERMINATED BY '\t' 
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

LOAD DATA LOCAL INFILE 'C:/Users/ddalo/Documents/_Data Analysis/Data Samples/IMDB/title-basics.tsv'
INTO TABLE `title-basics` 
CHARACTER SET 'utf8mb4'
FIELDS TERMINATED BY '\t' 
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

LOAD DATA LOCAL INFILE 'C:/Users/ddalo/Documents/_Data Analysis/Data Samples/IMDB/title-crew.tsv'
INTO TABLE `title-crew` 
CHARACTER SET 'utf8mb4'
FIELDS TERMINATED BY '\t' 
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

LOAD DATA LOCAL INFILE 'C:/Users/ddalo/Documents/_Data Analysis/Data Samples/IMDB/title-episodes.tsv'
INTO TABLE `title-episodes` 
CHARACTER SET 'utf8mb4'
FIELDS TERMINATED BY '\t' 
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

LOAD DATA LOCAL INFILE 'C:/Users/ddalo/Documents/_Data Analysis/Data Samples/IMDB/title-ratings.tsv'
INTO TABLE `title-ratings` 
CHARACTER SET 'utf8mb4'
FIELDS TERMINATED BY '\t' 
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

LOAD DATA LOCAL INFILE 'C:/Users/ddalo/Documents/_Data Analysis/Data Samples/IMDB/title-principals.tsv'
INTO TABLE `title-principals` 
CHARACTER SET 'utf8mb4'
FIELDS TERMINATED BY '\t' 
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

/*
	Table indexes preparation (cast columns to int and apply primary and foreign keys)
*/
update `title-basics` set tconst=cast(replace(tconst, 'tt', '') as signed);
alter table `title-basics` modify column tconst int;
alter table `title-basics` add primary key(tconst);

update `title-ratings` set tconst=cast(replace(tconst, 'tt', '') as signed);
alter table `title-ratings` modify column tconst int;
alter table `title-ratings` add primary key(tconst);

update `title-episodes` set tconst=cast(replace(tconst, 'tt', '') as signed);
alter table `title-episodes` modify column tconst int;
alter table `title-episodes` add primary key(tconst);
-- Create new aggregated table of episodes after cleaning table
update `title-episodes` set parentTconst=cast(replace(parentTconst, 'tt', '') as signed);
alter table `title-episodes` modify column parentTconst int;
delete from `title-episodes` where parentTconst not in (select tconst from `title-basics` group by tconst) or seasonNumber is null;
create table title_episodes_agg
	with cte as (
		select 
			parentTconst, 
			max(cast(seasonNumber as signed)) as seasonNumber, 
			sum(1) as episodeNumber
		from `title-episodes`
		group by parentTconst
    )
    select cte.*, round(cte.episodeNumber / cte.seasonNumber, 2) as avgEpisodesSeason from cte;
alter table title_episodes_agg add foreign key(parentTconst) references `title-basics`(tconst);
alter table title_episodes_agg add primary key(parentTconst);

update `name-basics` set nconst=cast(replace(nconst, 'nm', '') as signed);
alter table `name-basics` modify column nconst int;
alter table `name-basics` add primary key(nconst);

update `title-principals` set tconst=cast(replace(tconst, 'tt', '') as signed);
update `title-principals` set nconst=cast(replace(nconst, 'nm', '') as signed);
alter table `title-principals` modify column tconst int;
alter table `title-principals` modify column nconst int;
-- Some rows from the columns we need to make foreign keys do not have a match on the parent tables, so we delete those records as we won't need them
delete from `title-principals` where tconst not in (select tconst from `title-basics` group by tconst);
delete from `title-principals` where nconst not in (select nconst from `name-basics` group by nconst);
-- Create foreign keys
alter table `title-principals` add foreign key(tconst) references `title-basics`(tconst);
alter table `title-principals` add foreign key(nconst) references `name-basics`(nconst);

/*
	Data peaking
*/
select * from `name-basics` limit 100;
select * from `title-basics` limit 100;
select * from `title-crew` limit 100;
select * from `title-episodes` limit 100;
select * from `title-ratings` limit 100;
select * from `title-principals` limit 100;

/*
	Data preparation
*/
-- We create an intermediate table for all the info regarding the title
create table title_basics_plus
select 
	tb.tconst, 
    tb.titleType, 
    tb.primaryTitle, 
    tb.originalTitle, 
    tb.isAdult, 
    tb.startYear, 
    tb.endYear, 
    tb.runtimeMinutes, 
    jt.genres, 
    tr.averageRating, 
    tr.numVotes,
    te.seasonNumber,
    te.episodeNumber,
    te.avgEpisodesSeason
    
from `title-basics` tb
    
cross join json_table(CONCAT('["', replace(genres, ',', '","'), '"]'), '$[*]' COLUMNS (genres TEXT PATH '$')) jt
left join `title-ratings` tr on tb.tconst = tr.tconst
left join title_episodes_agg te on tb.tconst = te.parentTconst;

-- We add a foreign key to the main titles table
alter table title_basics_plus add foreign key(tconst) references `title-basics`(tconst);

-- We add the crew information to each title and create a final table for easier access
create table titles
with title as (
	select tconst from `title-basics` group by tconst
)
select 
	t.*,
    tp.nconst, 
    tp.category, 
    nb.primaryName, 
    nb.birthYear, 
    nb.deathYear,
    -- Get number of years from death till 2023 if it applies
	case
		when nb.deathYear is null then null
		else 2023 - cast(deathYear as signed)
	end as numYearsFromDeath
    
from title tb

left join title_basics_plus t on t.tconst = tb.tconst
left join `title-principals` tp on tp.tconst = tb.tconst
left join `name-basics` nb on nb.nconst = tp.nconst;

/*
	Exporting results to csv
*/
-- Adding an id as primary key to make queries faster and to be able to extract in parts
alter table titles add id int primary key auto_increment first;

-- Extractions
select 
	'id', 'tconst', 'titleType', 'primaryTitle', 'originalTitle', 'isAdult', 'startYear', 'endYear', 'runtimeMinutes', 
    'genres', 'averageRating', 'numVotes', 'seasonNumber', 'episodeNumber', 'avgEpisodesSeason', 'nconst', 'category', 
    'primaryName', 'birthYear', 'deathYear', 'numYearsFromDeath'
union all
select 
	ifnull(id, ""), ifnull(tconst, ""), ifnull(titleType, ""), ifnull(primaryTitle, ""), ifnull(originalTitle, ""), ifnull(isAdult, ""), 
    ifnull(startYear, ""), ifnull(endYear, ""), ifnull(runtimeMinutes, ""), ifnull(genres, ""), ifnull(averageRating, ""), 
    ifnull(numVotes, ""), ifnull(seasonNumber, ""), ifnull(episodeNumber, ""), ifnull(avgEpisodesSeason, ""), 
    ifnull(nconst, ""), ifnull(category, ""), ifnull(primaryName, ""), ifnull(birthYear, ""), ifnull(deathYear, ""), ifnull(numYearsFromDeath, "")
from titles where titleType = 'movie' and startYear >= 2000 and numVotes > 0
into outfile 'IMDB_Movies.csv' 
fields terminated by ','
enclosed by '"'  
escaped by '"' 
lines terminated by '\r\n';
