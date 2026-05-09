Hooks:PostHook(LevelsTweakData, "init", "lies_fixed_ai_obj", function(self)
	self.spa.trigger_follower_behavior_element = {[135558] = true}
	self.framing_frame_3.fallback_patrol_element = 105142
end)

function LevelsTweakData:setup_hhtacs()
	self.rvd1.trigger_follower_behavior_element = {[100026] = true} --mr blonde assist
end