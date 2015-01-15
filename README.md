PostgreSQL/Greenplum & ArcGIS

#######################################################################
Abstract:

This plugin provides functionality to reach out from a PostgreSQL or
Pivotal Greenplum Database to an ArcGIS system, to request and enrich data.



#######################################################################
Installation:

make install



#######################################################################
Deinstallation:

make remove



#######################################################################
Requirements:

You need: ArcGIS "Client ID" & "Client Secret". You can create this by
logging in into the ArcGIS website with your account and create an application.
Basic lookups and reverse lookups are free and don't require account details.



#######################################################################
Configuration:

- verify configuration

SELECT arcgis.check_configuration();


- set ArcGIS client ID

SELECT arcgis.set_client_id('<client id>');


- set ArcGIS client secret

SELECT arcgis.set_client_secret('<client secret>');


- set ArcGIS authentication URL

SELECT arcgis.set_auth_url('<auth URL>');


- set ArcGIS geocode URL

SELECT arcgis.set_geocode_url('<geocode base URL>');


- remove existing configuration

SELECT arcgis.remove_configuration();



#######################################################################
Usage:

- resolve address to geocoordinates

SELECT arcgis.find('<address');

Example: SELECT arcgis.find('380 New York Street Redlands CA 92373');
Example: SELECT * FROM arcgis.find('380 New York Street Redlands CA 92373');


- resolve address to geocoordinates, return address as one string

SELECT arcgis.find_return_point('<address>');

Example: SELECT arcgis.find_return_point('380 New York Street Redlands CA 92373');


- resolve address to geocoordinates, return x (longitude) and y (latitude) as array

SELECT arcgis.find_xy('<address>');

Example: SELECT arcgis.find_xy('380 New York Street Redlands CA 92373');


- resolve address to geocoordinates, return y and x as array, suitable for services like Google Maps

SELECT arcgis.find_xy('<address>');

Example: SELECT arcgis.find_xy('380 New York Street Redlands CA 92373');


- resolve geocoordinates to closest address

SELECT arcgis.reverseGeocode('<longitude>', '<latitude>');

Example: SELECT arcgis.reverseGeocode('-122.148659529', '37.3939849106');
Example: SELECT * FROM arcgis.reverseGeocode('-122.148659529', '37.3939849106');


- resolve geocoordinates to closest address, return address as string

SELECT arcgis.reverseGeocode_string('<longitude>', '<latitude>');

Example: SELECT arcgis.reverseGeocode_string('-122.148659529', '37.3939849106');

