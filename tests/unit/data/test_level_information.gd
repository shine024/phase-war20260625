class_name LevelInformationDataTest
extends GdUnitTestSuite

const LevelInformation = preload("res://data/level_information.gd")


func test_level_info_returns_dictionary() -> void:
	var info = LevelInformation.get_level_info(1)
	assert_dict(info).is_not_null()


func test_level_info_contains_expected_fields() -> void:
	var info = LevelInformation.get_level_info(1)
	assert_dict(info).contains_keys(["name", "description"])
