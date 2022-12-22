## QA Folder

Following completion of the program run, it was necessary to check results against imagery to determine false postitives or any missed cooling towers. For this task we:
1. Loaded results into a SQL Server database containing other reference information.
2. Grouped data by building outlines and parcels, the database tables mirror the structure of the ArcGIS Online (AGOL) [map service](https://lacounty.maps.arcgis.com/home/item.html?id=8fcf42dad05b4f64b5595f0b683acc1a) 
3. Screened results to include only points that are 1) in LA County, 2) within 30 feet of a building, and 3) within 30 feet of a parcel that is not low-rise residential.
4. Set up the [map service](https://lacounty.maps.arcgis.com/home/item.html?id=8fcf42dad05b4f64b5595f0b683acc1a) to serve data from the database and allow editing features
5. Developed a web-based tool for reviewing detections using ArcGIS Experience Builder

The /sql folder here contains example SQL queries calculate the supplemental information (buildings, parcels, etc) for the detection points. 

The /arcade folder here contains example Arcade scripts for adding efficiencies to the process, for example applying a building review to all points detected on that building. These files are saved in .js extension based on similarities of Arcade with JavaScript.

The web-based tool for editing features is not shared publically. The screenshots in this folder give an idea of how it worked and what functionality is available.