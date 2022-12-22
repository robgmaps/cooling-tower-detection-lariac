-- a few queries to run as the program is running, to check progress toward completion and resolve any errors in processing

select FILENAME, PROCESS_STATUS, PROCESS_RESULTS from TOWERSCOUT_IMAGETILEINDEX where PROCESS_STATUS = 'Processing' order by FILENAME;

select top 5 * from TOWERSCOUT_IMAGETILEINDEX where PROCESS_STATUS = 'Complete';

with c1 as (select count(*) as c1 from TOWERSCOUT_IMAGETILEINDEX where PROCESS_STATUS = 'Complete'),
c2 as (select count(*) as c2 from  TOWERSCOUT_IMAGETILEINDEX)
select c1/cast(c2 as numeric) from c1, c2;

select count(*) as c1 from TOWERSCOUT_IMAGETILEINDEX where PROCESS_STATUS <> 'Complete' or PROCESS_STATUS is null;

select FILENAME, PROCESS_STATUS, PROCESS_RESULTS from TOWERSCOUT_IMAGETILEINDEX where FILENAME = 'L6_6376_1889c'

-- update TOWERSCOUT_IMAGETILEINDEX set PROCESS_STATUS = null, PROCESS_RESULTS = null where FILENAME = 'L6_6461_1842d';
-- update TOWERSCOUT_IMAGETILEINDEX set PROCESS_STATUS = null, PROCESS_RESULTS = null where FILENAME = 'L6_6477_1857d';
-- update TOWERSCOUT_IMAGETILEINDEX set PROCESS_STATUS = null where FILENAME = 'L6_6630_2047c';

-- update TOWERSCOUT_IMAGETILEINDEX set PROCESS_STATUS = 'Complete', PROCESS_RESULTS = 'Found 0 features in 12.84 minutes' where FILENAME = 'L6_6366_2090b';



