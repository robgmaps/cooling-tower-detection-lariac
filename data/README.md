## Data Folder

This folder contains the output from running the program in late 2022 on LARIAC 2020 imagery.  The output includes detected cooling towers along with the parcel AIN, LARIAC Building ID, square footage, and other supplemental information deemed helpful to the results QA process.

See the ArcGIS Online (AGOL) [map service](https://lacounty.maps.arcgis.com/home/item.html?id=8fcf42dad05b4f64b5595f0b683acc1a) for additional metadata about all the data collected and to use in GIS for further analysis.

Additionally, this folder is used to store the database connection file (.sde) for access to the SQL Server database, as well as temporary image files that are created as part of the detection program runs.

The sql/ folder includes random SQL queries used to update the supplemental information with (buildings, parcels, etc) for the detection points.