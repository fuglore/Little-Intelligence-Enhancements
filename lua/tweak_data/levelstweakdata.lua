Hooks:PostHook(LevelsTweakData, "init", "lies_fixed_ai_obj", function(self)
	self.spa.trigger_follower_behavior_element = {[135558] = true}
	self.hox_2.ignored_so_elements = {[102290] = true}
	
	self.hox_1.follow_by_default = true
end)