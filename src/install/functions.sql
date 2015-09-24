-- code for future features: OAuth, paid features, debug flag, max distance for reverse lookup, resolution for lookup



-- check configuration
--
-- parameters:
--  none
-- return:
--  none
CREATE OR REPLACE FUNCTION arcgis.check_configuration ()
    RETURNS void
AS $BODY$
DECLARE
BEGIN

    -- check "client_id"
    IF arcgis._check_configuration('client_id', FALSE) = FALSE THEN
        RAISE EXCEPTION E'No valid \'client_id\' found in configuration';
    END IF;

    -- check "client_secret"
    IF arcgis._check_configuration('client_secret', FALSE) = FALSE THEN
        RAISE EXCEPTION E'No valid \'client_secret\' found in configuration';
    END IF;

    -- check "auth_url"
    IF arcgis._check_configuration('auth_url', TRUE) = FALSE THEN
        RAISE EXCEPTION E'No valid \'auth_url\' found in configuration';
    END IF;

    -- check "geocode_url"
    IF arcgis._check_configuration('geocode_url', TRUE) = FALSE THEN
        RAISE EXCEPTION E'No valid \'geocode_url\' found in configuration';
    END IF;

END;
$BODY$ LANGUAGE 'plpgsql';



-- check a specific configuration key
--
-- parameters:
--  * parameter name
--  * flag if the parameter must be set
-- return:
--  * TRUE (parameter is ok) or FALSE
CREATE OR REPLACE FUNCTION arcgis._check_configuration (TEXT, BOOLEAN)
    RETURNS boolean
AS $BODY$
DECLARE
    query_txt TEXT;
    record_val RECORD;
    key_name ALIAS FOR $1;
    must_be_set ALIAS FOR $2;
BEGIN
    -- verify if key exists
    query_txt := 'SELECT key, value FROM arcgis.configuration WHERE key = ' || quote_literal(key_name) || '';
    EXECUTE query_txt INTO record_val;

    IF record_val IS NULL THEN
        -- RAISE NOTICE E'No key \'' || key_name || '\' found in configuration';
        RETURN FALSE;
    END IF;


    IF must_be_set = TRUE THEN
        -- verify length of entry
        IF LENGTH(record_val.value) = 0 OR record_val.value IS NULL THEN
            -- RAISE NOTICE E'Key \'' || key_name || '\' is not set';
            RETURN FALSE;
        END IF;
    END IF;

    RETURN TRUE;
END
$BODY$ LANGUAGE 'plpgsql';



-- set a specific configuration parameter
--
-- parameters:
--  * parameter name
--  * parameter value
-- return:
--  none
CREATE OR REPLACE FUNCTION arcgis._set_configuration (TEXT, TEXT)
    RETURNS void
AS $BODY$
DECLARE
    query_txt TEXT;
    key_name ALIAS FOR $1;
    value ALIAS FOR $2;
BEGIN

    -- verify if key exists
    IF arcgis._check_configuration(key_name, FALSE) = FALSE THEN
        RAISE EXCEPTION 'No key "%" found in configuration', key_name;
    END IF;

    -- update value
    query_txt := 'UPDATE arcgis.configuration SET value = ' || quote_literal(value) || ' WHERE key = ' || quote_literal(key_name) || '';
    EXECUTE query_txt;
    PERFORM arcgis._write_configuration();

    RETURN;
END
$BODY$ LANGUAGE 'plpgsql';



-- set client id
--
-- parameters:
--  * ESRi client ID
-- return:
--  none
CREATE OR REPLACE FUNCTION arcgis.set_client_id(TEXT)
    RETURNS void
AS $BODY$
DECLARE
    value ALIAS FOR $1;
BEGIN

    PERFORM arcgis._set_configuration('client_id', value);

    RETURN;
END;
$BODY$ LANGUAGE 'plpgsql';



-- set client secret
--
-- parameters:
--  * ESRi client secret
-- return:
--  none
CREATE OR REPLACE FUNCTION arcgis.set_client_secret(TEXT)
    RETURNS void
AS $BODY$
DECLARE
    value ALIAS FOR $1;
BEGIN

    PERFORM arcgis._set_configuration('client_secret', value);

    RETURN;
END;
$BODY$ LANGUAGE 'plpgsql';



-- set authentication URL
--
-- parameters:
--  * ESRi authentication URL
-- return:
--  none
CREATE OR REPLACE FUNCTION arcgis.set_auth_url(TEXT)
    RETURNS void
AS $BODY$
DECLARE
    value ALIAS FOR $1;
BEGIN

    PERFORM arcgis._set_configuration('auth_url', value);

    RETURN;
END;
$BODY$ LANGUAGE 'plpgsql';



-- set geocode URL
--
-- parameters:
--  * ESRi geocode URL
-- return:
--  none
CREATE OR REPLACE FUNCTION arcgis.set_geocode_url(TEXT)
    RETURNS void
AS $BODY$
DECLARE
    value ALIAS FOR $1;
    last_c TEXT;
BEGIN

    last_c := substring(value FROM '.$');
    IF last_c != '/' THEN
        RAISE EXCEPTION 'Last charachter of geocode URL must be a /';
    END IF;

    PERFORM arcgis._set_configuration('geocode_url', value);

    RETURN;
END;
$BODY$ LANGUAGE 'plpgsql';



-- remove configuration
--
-- parameters:
--  none
-- return:
--  none
CREATE OR REPLACE FUNCTION arcgis.remove_configuration()
    RETURNS void
AS $BODY$
DECLARE
BEGIN

    PERFORM arcgis._delete_configuration();

    RETURN;
END;
$BODY$ LANGUAGE 'plpgsql';



-- write configuration
--
-- parameters:
--  none
-- return:
--  none
CREATE OR REPLACE FUNCTION arcgis._write_configuration ()
    RETURNS void
AS $BODY$
DECLARE
    query_str     TEXT;
    rec           RECORD;
    curr_db_oid   TEXT;
    vendor        TEXT;
BEGIN

    -- there is an implicit assumption that if _database_vendor() knows about the vendor, all other places know as well
    vendor := arcgis._database_vendor();

    -- find out the current database OID
    curr_db_oid := arcgis._database_oid();
    -- RAISE NOTICE 'Current database OID: %', curr_db_oid;
    -- RAISE NOTICE 'Database vendor: %', vendor;

    IF vendor = 'PostgreSQL' THEN
        -- PostgreSQL code
        RAISE NOTICE 'Writing configuration for PostgreSQL';
        PERFORM arcgis._delete_configuration_postgresql();
        PERFORM arcgis._write_configuration_to_disk_postgresql();
    ELSEIF vendor = 'Greenplum' THEN
        -- Greenplum code
        RAISE NOTICE 'Writing configuration for Greenplum';
        PERFORM arcgis._delete_configuration_greenplum();
        -- the PostgreSQL code writes the config file into the current directory
        PERFORM arcgis._write_configuration_to_disk_postgresql();
        -- the Greenplum code copies the config file to all segments and the standby master
        PERFORM arcgis._copy_configuration_to_segments_greenplum();

        -- select all segments and the other standby master, exclude the current master (config already written)
        query_str := 'SELECT sc.hostname,
                             sc.address,
                             sc.port,
                             sc.dbid,
                             fe.fselocation
                        FROM gp_segment_configuration sc,
                             pg_filespace_entry fe
                       WHERE sc.dbid = fe.fsedbid
                         AND sc.dbid != gp_execution_dbid()';

        FOR rec IN EXECUTE query_str LOOP
            RAISE DEBUG 'Update database %:%/%', rec.address, rec.port, rec.fselocation;
            PERFORM arcgis._copy_configuration_to_segments_greenplum();
        END LOOP;
    ELSE
        -- who are you?
        RAISE EXCEPTION 'Unknown database vendor!';
    END IF;

END;
$BODY$ LANGUAGE 'plpgsql';



-- write configuration to disk (PostgreSQL/Greenplum)
--
-- parameters:
--  none
-- return:
--  none
CREATE OR REPLACE FUNCTION arcgis._write_configuration_to_disk_postgresql ()
    RETURNS void
AS $BODY$


# get current database OID
res = plpy.execute("SELECT arcgis._database_oid() AS db")
curr_db_oid = res[0]["db"]


# read configuration
res = plpy.execute("SELECT * FROM arcgis.configuration ORDER BY key")

# open config file (local to data directory)
f = open('arcgis_config.' + curr_db_oid, 'w')

# write section header
f.write('[arcgis]\n')

for row in res:
    #plpy.info(row["key"] + '=' + row["value"])
    f.write(row["key"] + '=' + row["value"] + '\n')

f.close()


return None

$BODY$ LANGUAGE 'plpythonu';



-- copy configuration to disk on all segments (Greenplum)
--
-- parameters:
--  none
-- return:
--  none
CREATE OR REPLACE FUNCTION arcgis._copy_configuration_to_segments_greenplum ()
    RETURNS void
AS $BODY$

import subprocess
from subprocess import CalledProcessError


# get current database OID
res = plpy.execute("SELECT arcgis._database_oid() AS db")
curr_db_oid = res[0]["db"]

# select all segments and the other standby master, exclude the current master (config already written)
# by selecting the data here and not in the calling function, we avoid the need to verify the input data
query_str = """SELECT sc.hostname AS hostname,
                      sc.address AS address,
                      sc.port AS port,
                      sc.dbid AS dbid,
                      fe.fselocation AS fselocation
                 FROM gp_segment_configuration sc,
                      pg_filespace_entry fe
                WHERE sc.dbid = fe.fsedbid
                  AND sc.dbid != gp_execution_dbid()
             ORDER BY sc.dbid"""
res = plpy.execute(query_str)
for row in res:
    #plpy.info('Update: ' + str(row["address"]) + ':' + str(row["fselocation"]) + '/')
    # implicit assumption that Greenplum runs on Unix only (that is: Linux + Solaris)
    # scp option -B will not ask for password, but rather fail if the file cannot be copied
    scp_string = ['scp', '-B', '-q', 'arcgis_config.' + curr_db_oid, str(row["address"]) + ':' + str(row["fselocation"]) + '/']
    #plpy.info(' '.join(scp_string))
    try:
        res = subprocess.check_call(scp_string, stdin=None, shell=False)
    except CalledProcessError as e:
        plpy.error('Failed to copy config to ' + str(row["address"]) + ':' + str(row["fselocation"]) + '/')


return None

$BODY$ LANGUAGE 'plpythonu';



-- delete configuration
--
-- parameters:
--  none
-- return:
--  none
CREATE OR REPLACE FUNCTION arcgis._delete_configuration ()
    RETURNS void
AS $BODY$
DECLARE
    vendor        TEXT;
BEGIN

    -- there is an implicit assumption that if _database_vendor() knows about the vendor, all other places know as well
    vendor := arcgis._database_vendor();

    IF vendor = 'PostgreSQL' THEN
        -- PostgreSQL code
        PERFORM arcgis._delete_configuration_postgresql();
    ELSEIF vendor = 'Greenplum' THEN
        -- Greenplum code
        PERFORM arcgis._delete_configuration_greenplum();
    ELSE
        -- who are you?
        RAISE EXCEPTION 'Unknown database vendor!';
    END IF;

END;
$BODY$ LANGUAGE 'plpgsql';



-- delete configuration (PostgreSQL)
--
-- parameters:
--  none
-- return:
--  none
CREATE OR REPLACE FUNCTION arcgis._delete_configuration_postgresql ()
    RETURNS void
AS $BODY$

import os


# get current database OID
res = plpy.execute("SELECT arcgis._database_oid() AS db")
curr_db_oid = res[0]["db"]

file_path = 'arcgis_config.' + curr_db_oid

if os.path.isfile(file_path):
    os.unlink(file_path)


return None

$BODY$ LANGUAGE 'plpythonu';



-- delete configuration (Greenplum)
--
-- parameters:
--  none
-- return:
--  none
CREATE OR REPLACE FUNCTION arcgis._delete_configuration_greenplum ()
    RETURNS void
AS $BODY$

import subprocess
from subprocess import CalledProcessError


# get current database OID
res = plpy.execute("SELECT arcgis._database_oid() AS db")
curr_db_oid = res[0]["db"]

# select all segments and both masters
# by selecting the data here and not in the calling function, we avoid the need to verify the input data
# unlike the _copy_configuration_to_segments_greenplum() function, do not exclude the current dbid
query_str = """SELECT sc.hostname AS hostname,
                      sc.address AS address,
                      sc.port AS port,
                      sc.dbid AS dbid,
                      fe.fselocation AS fselocation
                 FROM gp_segment_configuration sc,
                      pg_filespace_entry fe
                WHERE sc.dbid = fe.fsedbid
             ORDER BY sc.dbid DESC"""
res = plpy.execute(query_str)
for row in res:
    #plpy.info('Delete: ' + str(row["address"]) + ':' + str(row["fselocation"]) + '/')
    # implicit assumption that Greenplum runs on Unix only (that is: Linux + Solaris)
    # ssh will not ask for password, but rather fail if the connection cannot be established
    ssh_string = ['ssh', '-o', 'PasswordAuthentication=no', '-q', '-T', str(row["address"]), 'rm -f ' + str(row["fselocation"]) + '/' + 'arcgis_config.' + curr_db_oid + '']
    #plpy.info(' '.join(ssh_string))
    try:
        res = subprocess.check_call(ssh_string, stdin=None, shell=False)
    except CalledProcessError as e:
        plpy.error('Failed to delete config on ' + str(row["address"]) + ':' + str(row["fselocation"]) + '/')


return None

$BODY$ LANGUAGE 'plpythonu';



-- return the current database oid
--
-- parameters:
--  none
-- return:
--  - database name
CREATE OR REPLACE FUNCTION arcgis._database_oid ()
    RETURNS TEXT
AS $BODY$
DECLARE
    query_str TEXT;
    rec       RECORD;
BEGIN

    -- find out the current database name
    query_str := 'SELECT oid::TEXT AS dboid
                    FROM pg_database
                   WHERE datname = current_database()';
    EXECUTE query_str INTO rec;
    RETURN rec.dboid;

END;
$BODY$ LANGUAGE 'plpgsql' IMMUTABLE;



-- return the current database name
--
-- parameters:
--  none
-- return:
--  - database name
CREATE OR REPLACE FUNCTION arcgis._database_name ()
    RETURNS TEXT
AS $BODY$
DECLARE
    query_str TEXT;
    rec       RECORD;
BEGIN

    -- find out the current database name
    query_str := 'SELECT datname::TEXT AS dbname
                    FROM pg_database
                   WHERE datname = current_database()';
    EXECUTE query_str INTO rec;
    RETURN rec.dbname;

END;
$BODY$ LANGUAGE 'plpgsql' IMMUTABLE;



-- validate a database name
--
-- parameters:
--  - database name
-- return:
--  none (will break if the name is not ok)
CREATE OR REPLACE FUNCTION arcgis._validate_database_name (db TEXT)
    RETURNS void
AS $BODY$
BEGIN

    -- validate the name: the name is used in filesystem operations, so only allow specific characters
    IF db !~ '^[a-zA-Z0-9_]+$' THEN
        RAISE EXCEPTION 'Database name (%) is not valid', db;
    END IF;

    RETURN;

END;
$BODY$ LANGUAGE 'plpgsql' IMMUTABLE;



-- identify the vendor of the database product
--
-- parameters:
--  none
-- return:
--  - "PostgreSQL"
--  - "Greenplum"
CREATE OR REPLACE FUNCTION arcgis._database_vendor ()
    RETURNS TEXT
AS $BODY$
DECLARE
    query_str TEXT;
    rec       RECORD;
BEGIN

    query_str := 'SELECT version() AS version';
    EXECUTE query_str INTO rec;

    -- find out if 'Greenplum' string appears in database version string
    IF position('Greenplum' in rec.version) > 0 THEN
        RETURN 'Greenplum';
    END IF;

    IF position('PostgreSQL' in rec.version) > 0 THEN
        RETURN 'PostgreSQL';
    END IF;

    RAISE EXCEPTION 'Unknown database vendor: %', rec.version;

    RETURN '';

END;
-- this function is defined IMMUTABLE in order to execute it on Greenplum segments
-- it can be safely assumed that the database vendor will not change
$BODY$ LANGUAGE 'plpgsql' IMMUTABLE;



-- write configuration to disk
SELECT arcgis._write_configuration();



-- ##########################################################################################
-- regular code starts here


-- Reminder: longitude = x, latitude = y


-- create a data type holding longitude, latitude and the well known id
CREATE TYPE arcgis.location_type AS (x FLOAT8, y FLOAT8, wkid TEXT);

-- create type holding an entire address record
CREATE TYPE arcgis.address_type as (address TEXT, neighborhood TEXT, city TEXT, subregion TEXT, region TEXT, postal TEXT, postalext TEXT, countrycode TEXT, loc_name TEXT, x FLOAT8, y FLOAT8, wkid TEXT);



-- lookup (geocode) an address to geo coordinates
--
-- parameters:
--  * address
-- return:
--  * address record (type arcgis.location_type)
CREATE OR REPLACE FUNCTION arcgis.find(address VARCHAR)
    RETURNS arcgis.location_type
AS $BODY$

import json
import urllib2, urllib

from time import sleep
from pprint import pprint


usr_struct = {'text': address, 'f': 'json'}

plpy.notice('resolving: ' + address)

# try multiple times in case the lookup fails the first time (happens sometimes)
for attempt in range(3):
    try:
        # todo: use configured geocoder address
        data = urllib2.urlopen('http://geocode.arcgis.com/arcgis/rest/services/World/GeocodeServer/find?%s&f=json&outSR=4326&category=Address,Postal&outFields=*' % urllib.urlencode(usr_struct)).read()
        #plpy.notice('test' + data)

        # sometimes an 400 error (no data found) is returned, another loop is unnecessary
        j = json.loads(data)
        if 'error' in j:
            if j['error']['code'] == 400:
                break

        # simplified version of the query
        # data = urllib2.urlopen('http://geocode.arcgis.com/arcgis/rest/services/World/GeocodeServer/find?%s' % urllib.urlencode(usr_struct)).read()

        # this only breaks if the urlopen() was successful (no network error), else another attempt is made
        break
    except:
        # failed too often
        plpy.error("failed to connect GeocodeServer for: " + address)


#plpy.notice(data)
#plpy.notice('number elements in list: ' + str(len(data)))

j = json.loads(data)

if 'error' in j:
    if j['error']['code'] == 400:
        # not really an error, just no match for the lookup
        plpy.notice('no geocoordinates found for: ' + address)
    else:
        plpy.error('encountered an error: ' + str(j['error']['code']))
    return None

# nothing found
if len(j['locations']) == 0:
    plpy.notice('no geocoordinates found for: ' + address)
    return None


# returns Y first, then X - suitable for other mapping services
#return [ j['locations'][0]['feature']['geometry']['x'], j['locations'][0]['feature']['geometry']['y'] ]
#return [ j['locations'][0]['feature']['geometry']['y'], j['locations'][0]['feature']['geometry']['x'] ]

# create a result structure
ret_struct = {}
ret_struct['x'] = j['locations'][0]['feature']['geometry']['x']
ret_struct['y'] = j['locations'][0]['feature']['geometry']['y']
ret_struct['wkid'] = j['spatialReference']['wkid']

return ret_struct

$BODY$
LANGUAGE 'plpythonu' VOLATILE STRICT;

-- SELECT arcgis.find('380 New York Street Redlands CA 92373');
-- SELECT * FROM arcgis.find('380 New York Street Redlands CA 92373');



-- lookup (geocode) an address to geo coordinates
--
-- parameters:
--  * address
-- return:
--  * longitude and latitude, as string
CREATE OR REPLACE FUNCTION arcgis.find_return_point(address VARCHAR)
    RETURNS TEXT AS $BODY$
DECLARE
    query_str TEXT;
    ret_str   TEXT;
    rec       RECORD;
BEGIN

    EXECUTE 'SELECT * FROM arcgis.find(' || quote_literal(address) || ');' INTO rec;
    -- returns NULL if nothing is found
    RETURN CAST(rec.x::TEXT || ' ' || rec.y::TEXT AS TEXT);

END;
$BODY$
LANGUAGE 'plpgsql' VOLATILE STRICT;



-- lookup (geocode) an address to geo coordinates
--
-- parameters:
--  * address
-- return:
--  * longitude and latitude, as array
CREATE OR REPLACE FUNCTION arcgis.find_xy(address VARCHAR)
    RETURNS FLOAT8[] AS $BODY$
DECLARE
    rec RECORD;
BEGIN

    EXECUTE 'SELECT * FROM arcgis.find(' || quote_literal(address) || ');' INTO rec;
    -- returns array with NULLs, if nothing is found
    RETURN ARRAY[rec.x, rec.y];

END;
$BODY$ LANGUAGE 'plpgsql' VOLATILE STRICT;

-- SELECT arcgis.find_xy('380 New York Street Redlands CA 92373');
-- SELECT * FROM arcgis.find_xy('380 New York Street Redlands CA 92373');
-- SELECT (arcgis.find_xy('380 New York Street Redlands CA 92373'))[1];
-- SELECT (arcgis.find_xy('380 New York Street Redlands CA 92373'))[2];



-- lookup (geocode) an address to geo coordinates
--
-- parameters:
--  * address
-- return:
--  * latitude and longitude, as array (suitable for services like Google Maps)
CREATE OR REPLACE FUNCTION arcgis.find_yx(address VARCHAR)
    RETURNS FLOAT8[] AS $BODY$
DECLARE
    rec RECORD;
BEGIN

    EXECUTE 'SELECT * FROM arcgis.find(' || quote_literal(address) || ');' INTO rec;
    -- returns array with NULLs, if nothing is found
    RETURN ARRAY[rec.y, rec.x];

END;
$BODY$ LANGUAGE 'plpgsql' VOLATILE STRICT;

-- SELECT arcgis.find_yx('380 New York Street Redlands CA 92373');
-- SELECT * FROM arcgis.find_yx('380 New York Street Redlands CA 92373');
-- SELECT (arcgis.find_yx('380 New York Street Redlands CA 92373'))[1];
-- SELECT (arcgis.find_yx('380 New York Street Redlands CA 92373'))[2];



-- lookup geocoordinates to the nearest address
--
-- parameters:
--  * longitude (x)
--  * latitude (y)
-- return:
--  * address (type arcgis.address_type)
CREATE OR REPLACE FUNCTION arcgis.reverseGeocode(x FLOAT8, y FLOAT8)
    RETURNS arcgis.address_type
AS $BODY$

import json
import urllib2, urllib

from time import sleep
from pprint import pprint


usr_struct = {'location': str(x) + ',' + str(y), 'f': 'json'}

# try multiple times in case the lookup fails the first time (happens sometimes)
for attempt in range(3):
    try:
        # todo: use configured geocoder address
        data = urllib2.urlopen('http://geocode.arcgis.com/arcgis/rest/services/World/GeocodeServer/reverseGeocode?%s&f=json&outSR=4326&langCode=US&distance=10000' % urllib.urlencode(usr_struct)).read()

        # sometimes an 400 error (no data found) is returned, another loop is unnecessary
        j = json.loads(data)
        if 'error' in j:
            if j['error']['code'] == 400:
                break

        # simplified version of the query
        # data = urllib2.urlopen('http://geocode.arcgis.com/arcgis/rest/services/World/GeocodeServer/reverseGeocode?%s&f=json&outSR=4326&langCode=US' % urllib.urlencode(usr_struct)).read()

        # this only breaks if the urlopen() was successful (no network error), else another attempt is made
        break
    except:
        # failed too often
        plpy.error("failed to connect GeocodeServer for: " + str(x) + ', ' + str(y))


#plpy.notice(data)
#plpy.notice('number elements in list: ' + str(len(data)))

j = json.loads(data)

if 'error' in j:
    if j['error']['code'] == 400:
        # not really an error, just no match for the lookup
        plpy.notice('no address found for: ' + str(x) + ',' + str(y))
    else:
        plpy.error('encountered an error: ' + str(j['error']['code']))
    return None


# create a result structure
ret_struct = { }
ret_struct["address"] = j['address']['Address']
ret_struct["neighborhood"] = j['address']['Neighborhood']
ret_struct["city"] = j['address']['City']
ret_struct["subregion"] = j['address']['Subregion']
ret_struct["region"] = j['address']['Region']
ret_struct["postal"] = j['address']['Postal']
ret_struct["postalext"] = j['address']['PostalExt']
ret_struct["countrycode"] = j['address']['CountryCode']
ret_struct["loc_name"] = j['address']['Loc_name']
ret_struct["x"] = j['location']['x']
ret_struct["y"] = j['location']['y']
ret_struct["wkid"] = j['location']['spatialReference']['wkid']

return ret_struct

$BODY$
LANGUAGE 'plpythonu' VOLATILE STRICT;

-- SELECT arcgis.reverseGeocode('-122.148659529', '37.3939849106');
-- SELECT * FROM arcgis.reverseGeocode('-122.148659529', '37.3939849106');



-- lookup geocoordinates to the nearest address
--
-- parameters:
--  * longitude (x)
--  * latitude (y)
-- return:
--  * address (as string)
CREATE OR REPLACE FUNCTION arcgis.reverseGeocode_string(x FLOAT8, y FLOAT8)
    RETURNS TEXT AS $BODY$
DECLARE
    rec RECORD;
    ret TEXT;
BEGIN
    ret := 'SELECT * FROM arcgis.reverseGeocode(' || quote_literal(x) || ', ' || quote_literal(y) || ');';
    -- RAISE NOTICE 'query: %', ret;
    EXECUTE ret INTO rec;
    IF rec IS NULL THEN
        RETURN NULL;
    END IF;

    ret := '';

    -- address
    IF LENGTH(rec.address) > 0 THEN
        IF LENGTH(ret) > 0 THEN
            ret := ret || ', ';
        END IF;
        ret := ret || rec.address;
    END IF;

    -- city
    IF LENGTH(rec.city) > 0 THEN
        IF LENGTH(ret) > 0 THEN
            ret := ret || ', ';
        END IF;
        ret := ret || rec.city;
    END IF;

    -- region
    IF LENGTH(rec.region) > 0 THEN
        IF LENGTH(ret) > 0 THEN
            ret := ret || ', ';
        END IF;
        ret := ret || rec.region;
    END IF;

    -- postal
    IF LENGTH(rec.postal) > 0 THEN
        IF LENGTH(ret) > 0 THEN
            ret := ret || ', ';
        END IF;
        ret := ret || rec.postal;
    END IF;

    -- countrycode
    IF LENGTH(rec.countrycode) > 0 THEN
        IF LENGTH(ret) > 0 THEN
            ret := ret || ', ';
        END IF;
        ret := ret || rec.countrycode;
    END IF;

    RETURN ret;

END;
$BODY$ LANGUAGE 'plpgsql' VOLATILE STRICT;


-- SELECT arcgis.reverseGeocode_string('-122.148659529', '37.3939849106');


