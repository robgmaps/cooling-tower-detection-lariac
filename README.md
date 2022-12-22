# TowerScout Los Angeles County 

This Python script by [LA County eGIS](https://egis-lacounty.hub.arcgis.com/) runs the pre-trained TowerScout model on LARIAC high-resolution imagery to identify cooling towers in Los Angeles County.  The script is based off a [Demo Notebook](https://github.com/agrc/cooling-tower-object-detection/tree/main/demo) by the [Utah Geospatial Resource Center (UGRC)](https://gis.utah.gov/), which is a good reference for setting up and testing the environment. This script was run on Winter 2020 [LARIAC imagery](https://lariac-lacounty.hub.arcgis.com/) with between 4 and 9 inch resolution.

[TowerScout](https://groups.ischool.berkeley.edu/TowerScout/) was developed by a group a UC Berkeley to detect cooling towers from aerial imagery to assist public health officials with Legionella investigations and preparedness. The original [TowerScout GitHub repository](https://github.com/TowerScout/TowerScout) can be referenced for more information about the project and their model training process.

See the README files in the data and QA folders for the results data and more information on our process for checking cooling towers identified by the model.  See also the [map/feature service](https://lacounty.maps.arcgis.com/home/item.html?id=8fcf42dad05b4f64b5595f0b683acc1a) with detection results and QA status.

The primary adaptations of this script from the Demo Notebook are:
1. Split large raster tiles into smaller ones to match what the model expects - in this case we used 640x640 tiles
2. Find geographic coordinates from pixel coordinates returned from the model
3. Save results to ArcGIS Online hosted layer
4. Track tile processing progress in SQL Server
5. Post-process detections to screen against building outlines, parcels and parcel data, and known cooling towers

## Getting Started

### Prerequisites

See the [Demo Notebook](https://github.com/agrc/cooling-tower-object-detection/tree/main/demo) for instructions to set up and test the virtual environment. This script also uses Arcpy, ArcGIS API for Python, and connects to an ArcGIS Online organization.

Our initial step was to break the LARIAC Mosaic into roughly 8200x8200 pixel tiles. Those tiles were stored on a network location accessible by County servers and machines.

### Run the program

The main program file is _lariac_ts_detection.py_.  Set the tile name or number of random tiles to run in the `__main__` section.  Our process was to run 500 or so random tiles at a time concurrently on 3-4 different servers, tracking progress using the [tile index](https://lacounty.maps.arcgis.com/home/item.html?id=8fcf42dad05b4f64b5595f0b683acc1a&sublayer=9#data) stored in SQL Server.  On a standard Windows server or desktop it took about 10 minutes to complete a tile (around 13,000 total tiles were processed).  A faster or more efficient method could be to use containers and/or utilize the GPU/CUDA capabilities of PyTorch.

We found lots of false positives in the detection results, most commonly air conditioners that were not cooling towers. Some next steps could be to better train the model based on our results, and to investigate any upgrades to how the model is implemented (e.g. tile size, capturing other data or metadata, running the program faster).

## Terms of Use

The data herein is for informational purposes, and may not have been prepared for or be suitable for legal, engineering, or surveying intents. The County of Los Angeles reserves the right to change, restrict or discontinue access at any time. All users of the maps and data presented on [https://lacounty.maps.arcgis.com](https://lacounty.maps.arcgis.com) or deriving from any LA County REST URLs, agree to the following Terms of Use as outlined on the County of LA Enterprise GIS (eGIS) Hub ([https://egis-lacounty.hub.arcgis.com/pages/terms-of-use](https://egis-lacounty.hub.arcgis.com/pages/terms-of-use)).
