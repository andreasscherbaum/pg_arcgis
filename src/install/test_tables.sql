CREATE TABLE test_arcgis.pivotal_addresses (
  id           SERIAL       NOT NULL PRIMARY KEY,
  address      TEXT         NOT NULL,
  lat          TEXT,
  lng          TEXT,
  location_tmp TEXT
);
SELECT AddGeometryColumn('test_arcgis', 'pivotal_addresses', 'location', '4326', 'POINT', 2);


-- INSERT INTO test_arcgis.pivotal_addresses (address) VALUES
-- ('3495 Deer Creek Road Palo Alto, CA 94304'),
-- -- ('No. 38 Xiaoyun Road, Beijing, Chaoyang District, 100027 China'),
-- ('38 Xiaoyun Road, Beijing, 100027 China'),
-- ('City Gate, Mahon, Cork, Ireland'),
-- ('AM Kronberger Hang 2A, Schwalbach Frankfurt 65824, Germany'),
-- ('Bentima House, 168-172 Old Street, London EC1V 9BP, United Kingdom'),
-- ('Ribera del Loira 8, Edifico Paris, Campo de las Naciones, Madrid 28042, Spain'),
-- ('Via Spadolini, 5, Edificio A, Milano 20141, Italy'),
-- -- ('C Wing 4th Floor, Fortune 2000, Bandra Kurla Complex, Bandra (East), Mumbai 400 051, India'),
-- ('2000 Bandra Kurla Complex, Bandra East, Mumbai, Maharashtra, 400051, IND'),
-- ('625 Avenue of the Americas, Second Floor, New York, NY 10011-2020, United States'),
-- -- ('80 Quai Voltaire, CS 21002, Bezons Cedex 95876, France'),
-- ('80 Quai Voltaire, Bezons Cedex 95876, France'),
-- ('875 Howard St, Fifth Floor, San Francisco, CA 94103, United States'),
-- -- ('18th Floor, Gangnam Finance Center, 152 Teheran-ro, Gangnam-gu, Seoul, 135-984, Korea'),
-- ('152 Teheran-ro, Seoul, 135-984, Korea'),
-- -- ('1 Changi Business Park Central 1, #08-101, One@Changi City, Singapore 486036'),
-- ('1 Changi Business Park Central 1, #08-101, Changi City, Singapore 486036'),
-- ('207 Pacific Highway, St Leonards, Sydney, NSW, 2065, Australia'),
-- -- ('Shinjuku Maynds Tower 25th Floor, 2-1-1 Yoyogi Shibuya-ku, Tokyo 151-0053, Japan'),
-- ('2-1-1 Yoyogi Shibuya-ku, Tokyo 151-0053, Japan'),
-- ('1 Toronto Street, Suite 1100, Toronto, Ontario, M5C 2V6, Canada'),
-- ('Edisonbaan 14b , 3439 MN Nieuwegein, 3430 AB Nieuwegein, Netherlands PO Box 97, Netherlands')
-- ;


-- load prepopulated data
COPY test_arcgis.pivotal_addresses (address, lat, lng, location_tmp) FROM '/home/gpadmin/pivotal-addresses.txt' WITH DELIMITER AS E'\t';
-- COPY test_arcgis.pivotal_addresses (address, lat, lng, location_tmp) TO '/home/gpadmin/pivotal-addresses.txt' WITH DELIMITER AS E'\t';

-- UPDATE test_arcgis.pivotal_addresses SET location_tmp = arcgis.find_return_point(address);
UPDATE test_arcgis.pivotal_addresses SET location = ST_GeomFromText('POINT(' || location_tmp || ')', 4326) WHERE location_tmp IS NOT NULL;
UPDATE test_arcgis.pivotal_addresses SET lng = ST_X(location), lat = ST_Y(location) WHERE location_tmp IS NOT NULL;
CREATE INDEX test_arcgis_pivotal_addresses_location ON test_arcgis.pivotal_addresses USING gist(location);




CREATE TABLE test_arcgis.emc_addresses (
  id           SERIAL       NOT NULL PRIMARY KEY,
  state        TEXT         NOT NULL,
  street       TEXT         NOT NULL,
  city         TEXT         NOT NULL,
  zip          TEXT         NOT NULL,
  lat          TEXT,
  lng          TEXT,
  location_tmp TEXT
);
SELECT AddGeometryColumn('test_arcgis', 'emc_addresses', 'location', '4326', 'POINT', 2);

-- load prepopulated data
-- COPY test_arcgis.emc_addresses (state, street, city, zip) FROM '/home/gpadmin/emc-addresses-parsed.txt' WITH DELIMITER AS E'\t';
COPY test_arcgis.emc_addresses (state, street, city, zip, location_tmp) FROM '/home/gpadmin/emc-addresses-load.txt' WITH DELIMITER AS E'\t';

-- UPDATE test_arcgis.emc_addresses SET location_tmp = arcgis.find_return_point(street || ', ' || city || ', ' || state || ', ' || zip);
-- UPDATE test_arcgis.emc_addresses SET location_tmp = arcgis.find_return_point(street || ', ' || city || ' ' || zip || ', ' || state) WHERE location_tmp IS NULL;

UPDATE test_arcgis.emc_addresses SET location = ST_GeomFromText('POINT(' || location_tmp || ')', 4326) WHERE location_tmp IS NOT NULL;
UPDATE test_arcgis.emc_addresses SET lng = ST_X(location), lat = ST_Y(location) WHERE location_tmp IS NOT NULL;

-- COPY test_arcgis.emc_addresses (state, street, city, zip, location_tmp) TO '/home/gpadmin/emc-addresses-load.txt' WITH DELIMITER AS E'\t';
CREATE INDEX test_arcgis_emc_addresses_location ON test_arcgis.emc_addresses USING gist(location);


CREATE TABLE test_arcgis.target_shops (
  id           SERIAL       NOT NULL PRIMARY KEY,
  name         TEXT         NOT NULL,
  state        TEXT         NOT NULL,
  street       TEXT         NOT NULL,
  city         TEXT         NOT NULL,
  zip          TEXT         NOT NULL,
  url          TEXT         NOT NULL,
  phone        TEXT         NOT NULL,
  lat          TEXT,
  lng          TEXT,
  location_tmp TEXT
);
SELECT AddGeometryColumn('test_arcgis', 'target_shops', 'location', '4326', 'POINT', 2);

-- COPY test_arcgis.target_shops (state, url, name, street, city, zip, phone) FROM '/home/gpadmin/target-shops.txt' WITH DELIMITER AS E'\t';

-- UPDATE test_arcgis.target_shops SET location_tmp = arcgis.find_return_point(street || ', ' || city || ', ' || state || ', ' || zip);
-- UPDATE test_arcgis.target_shops SET location_tmp = arcgis.find_return_point(street || ', ' || city || ' ' || zip || ', ' || state) WHERE location_tmp IS NULL;

-- load prepopulated data
COPY test_arcgis.target_shops (name, state, street, city, zip, url, phone, lat, lng, location_tmp) FROM '/home/gpadmin/target-shops.txt' WITH DELIMITER AS E'\t';

UPDATE test_arcgis.target_shops SET location = ST_GeomFromText('POINT(' || location_tmp || ')', 4326) WHERE location_tmp IS NOT NULL;
UPDATE test_arcgis.target_shops SET lng = ST_X(location), lat = ST_Y(location) WHERE location_tmp IS NOT NULL;
-- COPY test_arcgis.target_shops (name, state, street, city, zip, url, phone, lat, lng, location_tmp) TO '/home/gpadmin/target-shops.txt' WITH DELIMITER AS E'\t';
CREATE INDEX test_arcgis_target_shops_location ON test_arcgis.target_shops USING gist(location);


ANALYZE test_arcgis.pivotal_addresses;
ANALYZE test_arcgis.emc_addresses;
ANALYZE test_arcgis.target_shops;

