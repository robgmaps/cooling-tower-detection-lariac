// ARCADE script for attribute rule
// Rule Name: Apply to Building Points
// Apply building level update to all points on the building

var fsDet = FeatureSetByName($datastore, "TowerScout_Detections_Screened", ["ID", "globalid", "BLD_ID_CLOSEST"], false)
var updateList = []
var counter = 0

if ($feature.ApplyToAllBldPoints == 1) {
	var bld_id = $feature.BLD_ID
	var det = Filter(fsDet, 'BLD_ID_CLOSEST = @bld_id')
	var bldDetCount = Count(det)
	for (var d in det) {
		updateList[counter] = {
			'globalid': d.globalid,
			'attributes': {
				'Reviewed': $feature.Reviewed,
				'Confirmed': $feature.Confirmed,
				'Notes': $feature.Notes,
				'Notes_Expanded': $feature.Notes_Expanded
			}
		}
		counter++
	}

	return {
		'result': bldDetCount + ' detection points updated.',
		'edit': [{
			'className': 'TowerScout_Detections_Screened',
			'updates': updateList
		}]
	}
}
else {
	return 'Nothing to update.'
}