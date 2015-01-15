create type test_arcgis.earthquake as (ts timestamp, latitude float8, longitude float8, depth float8, magnitude float8, magtype text, nbstations integer, gap integer, distance float8, rms float8, source text, eventid text, version bigint);

create or replace function test_arcgis.hourly_earthquake() returns setof test_arcgis.earthquake as $$

import csv, urllib2

data = csv.reader(urllib2.urlopen('http://earthquake.usgs.gov/earthquakes/feed/csv/1.0/hour'))

next(data, None)  # Skip the csv header

for line in data:

   yield [None if x is "" else x for x in line]

$$ language plpythonu volatile;


create or replace function test_arcgis.daily_earthquake() returns setof test_arcgis.earthquake as $$

import csv, urllib2

data = csv.reader(urllib2.urlopen('http://earthquake.usgs.gov/earthquakes/feed/csv/1.0/day'))

next(data, None)  # Skip the csv header

for line in data:

   yield [None if x is "" else x for x in line]

$$ language plpythonu volatile;

