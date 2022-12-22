# Process LARIAC Tiles through TowerScout cooling tower identification model

# get an unprocessed LARIAC tile from the SQL db
# set process_status = 'Processing'

# split the tile into 640x640 subtiles

# run the model against each subtile, saving results to feature layer and tracking total results

# set SQL db row as process_status = 'Completed' & process_result = 'xx features identified in xx minutes/seconds/hours'
# delete the 640x640 subtiles

import os, time, traceback
t1 = time.time()

import os, traceback, torch, random, datetime, arcpy, shutil
from arcgis.gis import GIS
from arcgis.geometry import Polygon, Point
from pathlib import Path

# configuration - see config-sample.py
from config import CONFIG

# connect to esri
gis = GIS("home") # connect to LAC org account
elapsed = round(time.time() - t1, 2)
elapsed_str = str(elapsed) + " seconds" if elapsed < 60 else str(round(elapsed/60, 2)) + " minutes"
print ("connected to arcgis", elapsed_str)

# CONSTANTS
current_path = Path().resolve()

# AGOL layer for Cooling Tower Points
cooling_towers_item = gis.content.get(CONFIG['cooling_towers_layerid'])
cooling_towers_lyr = cooling_towers_item.layers[0]

# Set location of image tiles
tile_folder = Path(CONFIG['lariac_image_path'])

# Set up path to the yolov5 directory and local repo
yolov5_src_path = current_path / 'yolov5'

# Set up path to model weights file and load the TowerScout model
towerscout_weights_path = current_path / 'tower_scout' / 'xl_250_best.pt'

# build the towerscout model
model = torch.hub.load(str(yolov5_src_path), 'custom', path=str(towerscout_weights_path), source='local')
print ("")	

# connect to sde with a connection file
egdb = str(current_path / "data\\" + CONFIG['sde_filename'])
egdb_conn = arcpy.ArcSDESQLExecute(egdb)

# split an image
def split_raster(tile_name, split_folder, tile_size="640 640"):
	print ("creating split raster")
	split_start = time.perf_counter()
	image_file = str(tile_folder / tile_name) + '.jpg'
	arcpy.management.SplitRaster(image_file, str(split_folder), tile_name + '_', "SIZE_OF_TILE", "JPEG", "NEAREST", "1 1", "640 640", 0, "PIXELS", None, None, None, "NONE", "DEFAULT", '')
	elapsed = time.perf_counter() - split_start
	elapsed_str = str(round(elapsed, 2)) + " seconds" if elapsed < 60 else (str(round(elapsed/60, 2)) + " minutes" if elapsed < 3600 else str(round(elapsed/3600, 2)) + " hours")
	print(f'Finished split: {elapsed_str}')
	return split_folder

# PROCESS A SINGLE FULL-SIZE TILE
def process_tile(tile_name, tile_size="640 640", delete_subtiles=False):
	print ("processing tile", tile_name)
	tile_start = time.time()

	# set tile as in progress
	sql = "UPDATE DPH.DPH.TOWERSCOUT_IMAGETILEINDEX set PROCESS_STATUS = 'Processing' where FILENAME = '%s';" % tile_name
	r = egdb_conn.execute(sql)
	
	# reference or make a folder for the subtiles
	image_folder = Path('data\\' + tile_name)
	if not image_folder.exists():
		image_folder.mkdir()
		image_folder = split_raster(tile_name, image_folder, tile_size)

	# process the subtiles and store results
	images = list(image_folder.glob('**/*.JPG'))
	image_count = len(images)
	cooling_towers_features = []

	# Loop through the subtiles
	for c, i in enumerate(images):
		subtile_start = time.perf_counter()
		print ('\n', i)
		results = model(i)
		results.print()
			
		df = results.pandas().xyxy[0]
		if (len(df)):
			# results.save()
			print (df)

			# get the world file
			tile_base = str(i).split('\\')[-1].split('.')[0]
			world_file = str(image_folder) + "\\" + tile_base + '.JGw'

			with open(world_file, "r") as f:
				lines = f.readlines()

				# create points for feature layer
				for index, row in df.iterrows():
					# get geographic coordinates from pixels and jgw file
					# x1 = Ax + By + C
					# y1 = Dx + Ey + F
					# where order in world file lines is A, D, B, E, C, F
					xmin = (float(lines[0]) * row['xmin']) + (float(lines[2]) * row['ymin']) + float(lines[4])
					ymin = (float(lines[1]) * row['xmin']) + (float(lines[3]) * row['ymin']) + float(lines[5])
					xmax = (float(lines[0]) * row['xmax']) + (float(lines[2]) * row['ymax']) + float(lines[4])
					ymax = (float(lines[1]) * row['xmax']) + (float(lines[3]) * row['ymax']) + float(lines[5])
					
					polygon = Polygon({'spatialReference': {'latestWkid': 2229}, 
						'rings': [[ 
							[ xmin, ymax ], [ xmax, ymax ], [ xmax, ymin ], [ xmin, ymin ], [ xmin, ymax ] 
						]]
					})
					# buffer the box by x feet
					polygon = polygon.buffer(5)

					# make a center point for points layer
					# next time, save both the polygon and the point for detections
					centroid = polygon.centroid
					point = Point({'spatialReference': {'latestWkid': 2229}, "x": centroid[0], "y": centroid[1]})
					# print (polygon)
					# print (xmin, ymin)

					# make geometry into feature
					feature_dict = {
						"attributes": {
							"run_time": datetime.datetime.now(),
							"confidence": row['confidence'],
							"tile_name": tile_base,
						},
						"geometry": point,
					}
					print (feature_dict)
					cooling_towers_features.append(feature_dict)

		print(f'Finished subtile: {time.perf_counter() - subtile_start:.2f}s')
		print (round(c/image_count*100, 1), "percent complete")

	# save results to AGOL feature layer
	if len(cooling_towers_features):
		cooling_towers_lyr.edit_features(adds=cooling_towers_features)

	print(len(cooling_towers_features), "features detected")

	# update the database
	elapsed = time.time() - tile_start
	elapsed_str = str(round(elapsed, 2)) + " seconds" if elapsed < 60 else (str(round(elapsed/60, 2)) + " minutes" if elapsed < 3600 else str(round(elapsed/3600, 2)) + " hours")
	sql = "UPDATE DPH.DPH.TOWERSCOUT_IMAGETILEINDEX set PROCESS_STATUS = 'Complete', PROCESS_RESULTS = 'Found %s features in %s' where FILENAME = '%s';" % (str(len(cooling_towers_features)), elapsed_str, tile_name, )
	r = egdb_conn.execute(sql)

	# clear the temp folder
	if delete_subtiles:
		shutil.rmtree(str(image_folder))

	print(f'\nFinished tile: {elapsed_str} -', len(cooling_towers_features), "features detected")

# run a random group of unprocessed tiles
def process_tiles(n=None):
	batch_time = time.perf_counter()

	for c in range(n):
		sql = "SELECT top 1 FILENAME from DPH.DPH.TOWERSCOUT_IMAGETILEINDEX where PROCESS_STATUS is null order by newid();"
		tile_name = egdb_conn.execute(sql)
		if not tile_name:
			print ("No unprocessed tiles remaining")
			break

		print ("\nSTARTING", tile_name, "\n")
		process_tile(tile_name, delete_subtiles=True)
		print ("Finished", c+1, "of", n, "tiles")

	print(f'Finished process tiles: {(time.perf_counter() - batch_time)/3600:.2f} hours\n', n, "tiles completed")

# MAIN
if __name__ == "__main__":
	# run a batch of tiles, or process a single tile
	# our process was to run 500 or so random tiles at a time concurrently on different servers (there are ~13k full-size LARIAC tiles)
	# it takes about 10 minutes to run a full-size tile

	# process_tiles(100)
	# process_tile('L6_6413_1931b')

	elapsed = round(time.time() - t1, 2)
	elapsed_str = str(elapsed) + " seconds" if elapsed < 60 else str(round(elapsed/60, 2)) + " minutes"
	print ("finished __main__!", elapsed_str)