extends Node

signal relationship_changed(ai_id: String, target_id: String, relationship_data: Dictionary)
signal tags_changed(ai_id: String, target_id: String, tags: Array)
signal milestone_unlocked(ai_id: String, target_id: String, milestone_id: String)
signal relationship_removed(ai_id: String, target_id: String)

