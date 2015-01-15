CREATE TABLE arcgis.configuration (
  id            SERIAL              NOT NULL PRIMARY KEY,
  key           TEXT                NOT NULL,
  value         TEXT
);

-- bootstrap configuration
INSERT INTO arcgis.configuration (key, value) VALUES ('client_id', '');
INSERT INTO arcgis.configuration (key, value) VALUES ('client_secret', '');
INSERT INTO arcgis.configuration (key, value) VALUES ('auth_url', 'https://www.arcgis.com/sharing/oauth2/token');
INSERT INTO arcgis.configuration (key, value) VALUES ('geocode_url', 'http://geocode.arcgis.com/arcgis/rest/services/');

