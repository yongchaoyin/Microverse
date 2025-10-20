extends Node

class_name RelationshipUtils

static func calculate_closeness(rel: Dictionary) -> float:
	var affection = float(rel.get("affection", 0.0))
	var trust = float(rel.get("trust", 0.0))
	var familiarity = float(rel.get("familiarity", 0.0))
	return (affection * 0.4) + (trust * 0.35) + (familiarity * 0.25)

static func calculate_conflict_potential(rel: Dictionary) -> float:
	var affection = float(rel.get("affection", 0.0))
	var trust = float(rel.get("trust", 0.0))
	var respect = float(rel.get("respect", 0.0))
	var cordiality = float(rel.get("cordiality", 0.0))
	return ((-affection) * 0.35) + ((-trust) * 0.35) + ((-cordiality) * 0.2) + ((-respect) * 0.1)

static func calculate_romance_potential(rel: Dictionary) -> float:
	var affection = float(rel.get("affection", 0.0))
	var romance = float(rel.get("romance", 0.0))
	var trust = float(rel.get("trust", 0.0))
	return (affection * 0.35) + (romance * 0.5) + (trust * 0.15)

static func should_decay(rel: Dictionary, threshold_hours: float) -> bool:
	var last_interaction := int(rel.get("last_interaction", 0))
	var now := Time.get_unix_time_from_system()
	return (now - last_interaction) > threshold_hours * 3600.0

