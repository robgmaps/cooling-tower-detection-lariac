// set the Reviewed status based on Confirmed input, saving a step of having to updated both fields

if (IsEmpty($feature.Confirmed)) {
	return 0
}
else {
	return 1
}