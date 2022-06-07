Hooks:PostHook(LevelsTweakData, "init", "lies_fixed_ai_obj", function(self)
	self.spa.ignored_so_elements = {
		[101834] = true,
		[103318] = true
	}

	self.spa.trigger_follower_behavior_element = {[135558] = true}
	self.hox_2.ignored_so_elements = {[102290] = true}
end)