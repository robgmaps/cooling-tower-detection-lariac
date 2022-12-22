-- A collection of SQL Server queries to join detections to other data in our databases
-- You'd need actual data and supplemental tables to do these joins, this file is meant as more of a reference for queries that were run in our LA County databases as part of the QA process

-- copy detections to feature class with ArcGIS Pro (takes like 4 hours)
-- (table tmp_TowerScout_Detections)
-- add fields: AIN, BLD_ID, BLD_ID_Closest, Non_Small_Res, DPH_AIN, DPH_BLD_ID, CDC_Cluster, CDC_Confirmation, CDC_Confidence

-- geom2229 column (missed that step in feature class to feature class tool)
alter table tmp_TowerScout_Detections add Shape2229 Geometry;
update tmp_TowerScout_Detections set Shape2229 = geometry::Point(POINT_X, POINT_Y, 2229);

with s1 as (
select 
	MIN(Shape2229.STEnvelope().STPointN(1).STX) as X1
	,MIN(Shape2229.STEnvelope().STPointN(1).STY) as Y1 
	,MAX(Shape2229.STEnvelope().STPointN(3).STX) as X2 
	,MAX(Shape2229.STEnvelope().STPointN(3).STY) as Y2 
from tmp_TowerScout_Detections )
select X1, Y1, X2, Y2 from s1;

create spatial index idx_Shape2229 on tmp_TowerScout_Detections (Shape2229) with ( BOUNDING_BOX = (xmin=6273853.10711985, ymin=1566708.30725656, xmax=6672167.2907954, ymax=2124414.56258222) );

-- AIN and BLD
with t as (
	select a.AIN as ain_join, b.OBJECTID as objectid_join from ASSR_PARCELS a, tmp_TowerScout_Detections_2229 b where a.AIN is not null and a.AIN <> '' and a.Shape.STIntersects(b.Shape) = 1
)
update tmp_TowerScout_Detections_2229 set AIN = ain_join from t where OBJECTID = objectid_join;

with t as (
	select a.BLD_ID as bld_id_join, b.OBJECTID as objectid_join from LARIAC_BUILDINGS_2020 a, tmp_TowerScout_Detections_2229 b where a.BLD_ID is not null and a.BLD_ID <> '' and a.Shape.STIntersects(b.Shape) = 1
)
update tmp_TowerScout_Detections_2229 set BLD_ID = bld_id_join from t where OBJECTID = objectid_join; 

/***************
-- BLD_ID_Closest (w/in 30 feet)
***************/
update tmp_TowerScout_Detections_2229 set BLD_ID_Closest = BLD_ID;
with t as (
	select a.BLD_ID as bld_id_join, b.OBJECTID as objectid_join, a.Shape.STDistance(b.Shape) as dist from LARIAC_BUILDINGS_2020 a, tmp_TowerScout_Detections_2229 b where a.BLD_ID is not null and a.BLD_ID <> '' and a.Shape.STDistance(b.Shape) is not null and a.Shape.STDistance(b.Shape) <= 30
)
update tmp_TowerScout_Detections_2229 set BLD_ID_Closest = (select top 1 bld_id_join from t where OBJECTID = objectid_join order by dist) where BLD_ID is null;

-- AIN_Closest (w/in 30 feet)
alter table tmp_TowerScout_Detections_2229 add AIN_Closest varchar(10);
update tmp_TowerScout_Detections_2229 set AIN_Closest = AIN;
with t as (
	select a.AIN as ain_join, b.OBJECTID as objectid_join, a.Shape.STDistance(b.Shape) as dist from ASSR_PARCELS a, tmp_TowerScout_Detections_2229 b where a.AIN is not null and a.AIN <> '' and a.Shape.STDistance(b.Shape) is not null and a.Shape.STDistance(b.Shape) <= 30
)
update tmp_TowerScout_Detections_2229 set AIN_Closest = (select top 1 ain_join from t where OBJECTID = objectid_join order by dist) where AIN is null;

-- Non_Small_Res - drop everything residential with under 5 units
with t as (
	select AIN as AIN_join, UseCode, UseType, UseDescription from ASSR_PARCELS where (AIN is not null and AIN <> '') and not (UseType = 'Residential' and UseCode not like '05%')
) 
update tmp_TowerScout_Detections_2229 set Non_Small_Res = 1 from t where AIN_Closest = AIN_join; 

with t as (
	select AIN as AIN_join, UseCode, UseType, UseDescription from ASSR_PARCELS where not ( (AIN is not null and AIN <> '') and not (UseType = 'Residential' and UseCode not like '05%') )
) 
update tmp_TowerScout_Detections set Non_Small_Res = 0 from t where AIN_Closest = AIN_join; 

update tmp_TowerScout_Detections set Non_Small_Res = null where Non_Small_Res <> 1; 

alter table tmp_TowerScout_Detections alter column Non_Small_Res type bit;

-- In_DPH_Parcel, In_DPH_BLD
-- tmp_DPH_Parcels_BLD = AIN, BLD_ID
update tmp_TowerScout_Detections_2229 set In_DPH_Parcel = 1 from tmp_DPH_Parcels_BLD b where AIN_Closest = b.AIN; 
update tmp_TowerScout_Detections_2229 set In_DPH_BLD_ID = 1 from tmp_DPH_Parcels_BLD b where BLD_ID_Closest = b.BLD_ID;

-- CDC_Confirmation, CDC_Confidence, CDC_Cluster, CDC_Selected, CDC_Inside_Boundary, CDC_Meets_Threshold
-- tmp_CDC_Clusters
alter table tmp_TowerScout_Detections drop column CDC_Selected;
alter table tmp_TowerScout_Detections drop column CDC_Inside_Boundary;
alter table tmp_TowerScout_Detections drop column CDC_Meets_Threshold;

alter table tmp_TowerScout_Detections add CDC_Selected bit;
alter table tmp_TowerScout_Detections add CDC_Inside_Boundary bit;
alter table tmp_TowerScout_Detections add CDC_Meets_Threshold bit;

alter table tmp_CDC_Clusters add AIN varchar(10);
alter table tmp_CDC_Clusters add BLD_ID varchar(20);

update tmp_TowerScout_Detections set CDC_Confirmation = Confirmation, CDC_Confidence = confidence, CDC_Cluster = Cluster__, CDC_Selected = selected, CDC_Inside_Boundary = inside_boundary, CDC_Meets_Threshold = meets_threshold from tmp_CDC_Clusters b where AIN_Closest = b.AIN or BLD_ID_Closest = b.BLD_ID; 

with t as (
	select a.AIN as ain_join, b.OBJECTID as objectid_join, a.Shape.STDistance(b.Shape) as dist from ASSR_PARCELS a, tmp_CDC_Clusters_2229 b where a.AIN is not null and a.AIN <> '' and a.Shape.STDistance(b.Shape) is not null and a.Shape.STDistance(b.Shape) <= 15
)
update tmp_CDC_Clusters_2229 set AIN = (select top 1 ain_join from t where OBJECTID = objectid_join order by dist) where AIN is null;

with t as (
	select a.AIN as ain_join, b.OBJECTID as objectid_join from ASSR_PARCELS a, tmp_CDC_Clusters b where a.AIN is not null and a.AIN <> '' and a.Shape.STIntersects(b.Shape) = 1
)
update tmp_CDC_Clusters set AIN = ain_join from t where OBJECTID = objectid_join;


with t as (
	select a.BLD_ID as bld_join, b.OBJECTID as objectid_join, a.Shape.STDistance(b.Shape) as dist from LARIAC_BUILDINGS_2020 a, tmp_CDC_Clusters_2229 b where a.BLD_ID is not null and a.BLD_ID <> '' and a.Shape.STDistance(b.Shape) is not null and a.Shape.STDistance(b.Shape) <= 15
)
update tmp_CDC_Clusters_2229 set BLD_ID = (select top 1 bld_join from t where OBJECTID = objectid_join order by dist) where BLD_ID is null;

update tmp_CDC_Clusters set AIN = null, BLD_ID = null;

update tmp_TowerScout_Detections_2229 set CDC_Confirmation = Confirmation, CDC_Confidence = b.confidence, CDC_Cluster = Cluster__, CDC_Selected = selected, CDC_Inside_Boundary = inside_boundary, CDC_Meets_Threshold = meets_threshold from tmp_CDC_Clusters_2229 b where AIN_Closest = b.AIN or BLD_ID_Closest = b.BLD_ID; 

/****************************
-- update IDs
****************************/
update tmp_TowerScout_Detections_2229 set ID = OBJECTID;

/****************************
-- in LAC
****************************/
select count(b.*) from DPW_COUNTY_BOUNDARY a join tmp_TowerScout_Detections_2229 b on a.Shape.STContains(b.Shape) = 1;

update tmp_TowerScout_Detections_2229 set In_LAC = tmp_TowerScout_Detections_2229.Shape.STIntersects(b.Shape) from DPW_COUNTY_BOUNDARY b;

/****************************
-- Distance
****************************/
 -- closest distance
with t as (
	select a.ID as id_join, b.ID as id_join_2, a.Shape.STDistance(b.Shape) as dist from tmp_TowerScout_Detections_2229 a, tmp_TowerScout_Detections_2229 b where a.ID <> b.ID and a.Shape.STDistance(b.Shape) is not null and a.Shape.STDistance(b.Shape) < 1000
)
update tmp_TowerScout_Detections_2229 set Dist_Nearest_Point = (select top 1 round(dist, 5) from t where ID = id_join order by dist);

select top 1 a.ID as id_join, b.ID as id_join_2, a.Shape.STDistance(b.Shape) as dist from tmp_TowerScout_Detections_2229 a, tmp_TowerScout_Detections_2229 b where a.ID <> b.ID and a.Shape.STDistance(b.Shape) is not null and a.ID = 100 order by a.Shape.STDistance(b.Shape);

/****************************
-- CSA
****************************/
select CITY_TYPE, LCITY, LABEL from GIS_Boundaries_Political.eGIS.BOS_COUNTYWIDE_STATISTICAL_AREAS;

select CITY_TYPE, LCITY, LABEL, count(ID) as count_detections,  from BOS_COUNTYWIDE_STATISTICAL_AREAS

with t as (
	select a.CITY_TYPE as city_type_join, a.LCITY, a.LABEL, b.ID as id_join from BOS_COUNTYWIDE_STATISTICAL_AREAS a, tmp_TowerScout_Detections_2229 b where a.Shape.STIntersects(b.Shape) = 1
)
update tmp_TowerScout_Detections_2229 set CSA_LCITY = LCITY, CSA_LABEL = LABEL, CITY_TYPE = city_type_join from t where ID = id_join;

select CITY_TYPE, count(ID) from tmp_TowerScout_Detections_2229 group by CITY_TYPE order by CITY_TYPE;

/****************************
-- Group by buildings, parcels, CSAs, Unincorporated, sd
****************************/
-- table tmp_TowerScout_ASSR_PARCELS - AIN, OWNER, UseType, DETECTIONS_COUNT, AVG_NEAREST, 
-- table tmp_TowerScout_LARIAC_BUILDINGS_2020 - BLD_ID, ..., DETECTIONS_COUNT, AVG_NEAREST
-- table tmp_TowerScout_CSA - CSA_LABEL, CITY_TYPE, DETECTIONS_COUNT, AVG_NEAREST

select t.*, b.AIN_Closest, b.Run_Time, Non_Small_Res from t right join tmp_TowerScout_Detections b on AIN_join = AIN where AIN_join is not null order by UseCode;

select distinct UseCode, UseType, UseDescription, Non_Small_Res from t right join tmp_TowerScout_Detections b on AIN_join = AIN where AIN_join is not null and Non_Small_Res <> 1 order by UseCode;

-- set all the t/f to false where null
update tmp_TowerScout_Detections set Non_Small_Res = 0 where Non_Small_Res is null or Non_Small_Res <> 1;
update tmp_TowerScout_Detections set In_DPH_Parcel = 0 where In_DPH_Parcel is null or In_DPH_Parcel <> 1;
update tmp_TowerScout_Detections set In_DPH_BLD = 0 where In_DPH_BLD is null or In_DPH_BLD <> 1;

-- the CSV dataset (full)
select ID, X, Y, TS_Confidence, AIN_Closest as AIN, BLD_ID_Closest as BLD_ID, Non_Small_Res, In_DPH_Parcel, In_DPH_BLD_ID as In_DPH_BLD, CDC_Cluster, CDC_Confirmation, CDC_Confidence, CDC_Selected, CDC_Inside_Boundary, CDC_Meets_Threshold, NEAR_DIST, CSA_LABEL, CITY_TYPE as CSA_CITY_TYPE, '' as Reviewed, '' as Confirmed, '' as Notes, Run_Time, Tile_Name, Point_X, Point_Y from tmp_TowerScout_Detections_2229;

-- the CSV dataset (screened)
create table tmp_TowerScout_Detections_Screened as 

select ID, X, Y, TS_Confidence, AIN_Closest as AIN, BLD_ID_Closest as BLD_ID, Non_Small_Res, In_DPH_Parcel, In_DPH_BLD_ID as In_DPH_BLD, CDC_Cluster, CDC_Confirmation, CDC_Confidence, CDC_Selected, CDC_Inside_Boundary, CDC_Meets_Threshold, NEAR_DIST, CSA_LABEL, CITY_TYPE as CSA_CITY_TYPE, '' as Reviewed, '' as Confirmed, '' as Notes, Run_Time, Tile_Name, Point_X, Point_Y, Shape into tmp_TowerScout_Detections_Screened from tmp_TowerScout_Detections_2229 where BLD_ID_Closest is not null and AIN_Closest is not null and in_LAC_Land = 1 and Non_Small_Res = 1;

-- buildings dataset
create table tmp_TowerScout_Buildings as 

with b as (
	select BLD_ID, HEIGHT, Shape.STAsBinary() as shape_binary from LARIAC_BUILDINGS_2020
),
t as (
	select BLD_ID_Closest as BLD_ID, HEIGHT, count(ID) as count_detections, avg(NEAR_DIST) as avg_distance, avg(TS_Confidence) as avg_confidence, b.shape_binary
	from tmp_TowerScout_Detections_2229 a join b on a.BLD_ID_Closest = b.BLD_ID 
	where BLD_ID_Closest is not null and AIN_Closest is not null and in_LAC_Land = 1 and Non_Small_Res = 1
	group by BLD_ID_Closest, HEIGHT, shape_binary
)
select BLD_ID, Height, count_detections, avg_distance, avg_confidence, geometry::STGeomFromWKB(shape_binary, 2229) as Shape
into tmp_TowerScout_Buildings
from t;

-- parcels dataset
create table tmp_TowerScout_Parcels as 

with b as (
	select AIN, UseType, UseDescription, OwnerFullName, Shape.STAsBinary() as shape_binary from ASSR_PARCELS
),
t as (
	select AIN_Closest as AIN,  UseType, UseDescription, OwnerFullName, count(ID) as count_detections, avg(NEAR_DIST) as avg_distance, avg(TS_Confidence) as avg_confidence, b.shape_binary
	from tmp_TowerScout_Detections_2229 a join b on a.AIN_Closest = b.AIN 
	where BLD_ID_Closest is not null and AIN_Closest is not null and in_LAC_Land = 1 and Non_Small_Res = 1
	group by AIN_Closest, shape_binary, UseType, UseDescription, OwnerFullName
)
select AIN, UseType, UseDescription, OwnerFullName, count_detections, avg_distance, avg_confidence, geometry::STGeomFromWKB(shape_binary, 2229) as Shape
into tmp_TowerScout_Parcels
from t;

select count(distinct AIN_Closest) from tmp_TowerScout_Detections_2229 where in_LAC_Land = 1 and (AIN_Closest is not null or BLD_ID_Closest is not null) and Non_Small_Res = 1;

-- in a parcel but not a building -

select count(*) from tmp_TowerScout_Detections_2229 where BLD_ID_Closest is null and AIN_Closest is not null;

-- 12/09/2022 Datasets
select ID, x, y, case when Reviewed = 1 then 'Yes' else 'No' end as Reviewed, Confirmed, Notes, Notes_Expanded, TS_Confidence as Confidence, NEAR_DIST, AIN_Closest as AIN, BLD_ID_Closest as BLD_ID, BLD_Area, BLD_Height, Parcel_SQFT, CSA_LABEL, CSA_CITY_TYPE, CDC_Cluster, CDC_Confidence, CDC_Confirmation, CDC_Selected, CDC_Inside_Boundary, CDC_Meets_Threshold, Tile_Name, Run_Time from TowerScout_Detections_Screened;

select BLD_ID, case when Reviewed = 1 then 'Yes' else 'No' end as Reviewed, Confirmed, Notes, Notes_Expanded, case when Reviewed = 1 and ApplyToAllBldPoints = 1 then 'Yes' when Reviewed = 1 and ApplyToAllBldPoints = 0 then 'No' else '' end as ApplyToAllBldPoints, Observed_CTs, count_detections, avg_confidence, avg_distance, Height, BLD_Area from TowerScout_Buildings;

select AIN, count_detections, avg_confidence, avg_distance, UseType, UseDescription, OwnerFullName, Parcel_SQFT from TowerScout_Parcels;