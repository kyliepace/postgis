-- populating a table
INSERT INTO ch01.highways (gid, feature, name, state, geom)
SELECT gid, feature, name, state, ST_Transform(geom, 2163)
FROM ch01.highways_staging
WHERE feature LIKE 'Principal Highway%'

-- find restaurants within one mile of a highway
SELECT f.franchise, COUNT(DISTINCT r.id) As total
FROM
  ch01.restaurants as r INNER JOIN
  ch01.lu_franchises as f ON r.franchise = f.id INNER JOIN
  ch01.highways as h ON ST_DWithin(r.geom,h.geom,1609) -- spatial join within 1609m
GROUP BY f.franchise
ORDER BY total DESC;


-- show geometry of hardee's within 20 miles of US Route 1
SELECT r.geom
FROM ch01.restaurants r
WHERE EXISTS (
  SELECT gid
  FROM ch01.highways
  WHERE
    ST_DWithin(r.geom, geom, 1609*20) AND
    name = 'US Route 1' AND
    state = 'MD' AND
    r.franchise = 'HDE'
);

-- cast postgreSQL polygon type to postGIS geometry
SELECT
  polygon('((10,20), (30,40), (35,40), (10,20))')::geometry;

-- update SRID
SELECT UpdateGeometrySRID('ch03', 'bayarea_bridges', 'geom', 2227);
--or (newer way, postGIS 2.0+)
ALTER TABLE ch03.bayarea_bridges
  ALTER COLUMN geom TYPE geometry(LINESTRING, 2227)
    USING ST_SetSRID(geom,2227)



-- outputting geometry in various formats
SELECT
  ST_AsGML(geom, 5) as GML,
  ST_AsKML(geom, 5) as KML,
  ST_AsGeoJSON(geom, 5) as GeoJSON
FROM
  (SELECT ST_GeomFromText('LINESTRING(2 48 1, 0 51 1)', 4326) AS geom) X;


  -- create geometry from text
  SELECT geom::geometry(LineString,4326) INTO constrained_geoms
  FROM (
    VALUES
      (ST_GeomFromText('LINESTRING(-80 28, -90 29)', 4326)),
      (ST_GeomFromText('LINESTRING(10 28, 9 29, 7 30)', 4326))
  ) As x(geom);



-- /////// GEOCODER ///////
--turn textual representation of street address into geographic position e.g. PostGIS TIGER
CREATE EXTENSION fuzzystrmatch;
CREATE EXTENSION postgis_tiger_geocoder;

-- grating permissions to TIGER
GRANT USAGE ON SCHEMA tiger TO PUBLIC;
GRANT USAGE ON SCHEMA tiger_data TO PUBLIC;
GRANT SELECT, REFERENCES, TRIGGER
  ON ALL TABLES IN SCHEMA tiger TO PUBLIC;
GRANT SELECT, REFERENCES, TRIGGER
  ON ALL TABLES IN SCHEMA tiger_data TO PUBLIC;
GRANT EXECUTE
  ON ALL FUNCTIONS IN SCHEMA tiger TO PUBLIC;
ALTER DEFAULT PRIVILEGES IN SCHEMA tiger_data
GRANT SELECT, REFERENCES
  ON TABLES TO PUBLIC;

  -- to load data, create a folder to house the TIGER zip files and a temp folder to extract and process them.
  -- create a directory called gisdata and a subdirectory called temp in the location you specified in the tiger.loader variables table's staging_fold field
  -- generate script (for linux/mac) e.g. for national data
  \t
  \a
  \o /gisdata/nationscript.sh
  SELECT loader_generate_nation_script('sh');
  \o

-- after data have loaded, add indexes
SELECT install_missing_indexes();

-- normalize addresses with TIGER
SELECT normalize_address (a) As addy
FROM (
  VALUES
    ('ONE E PIMA ST STE 999, TUCSON, AZ'),
    ('4758 Reno Road, DC 20017'),
    ('1 Palisades, Denver, CO')
) X(a);

-- normalize addresses with PAGC, which can decipher spelled street numbers
CREATE EXTENSION address_standardizer;

WITH A AS (
  SELECT pagc_normalize_address(a) As addy
  FROM (
    VALUES
      ('1021 New Hampshare Avenue, Washington, DC 20010')
  ) X(a)
)
SELECT
  (addy).address As num,
  (addy).stateabbrev As st
FROM A;