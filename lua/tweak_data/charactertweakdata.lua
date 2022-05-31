Hooks:PostHook(CharacterTweakData, "init", "lies_fix_nosup", function(self, tweak_data)
	self:fix_no_supress()
end)

function CharacterTweakData:fix_no_supress()
	if self.medic then
		self.medic.no_suppressed_reaction = true
	end
	
	if self.inside_man then
		self.inside_man.no_suppressed_reaction = true
	end
	
	if self.old_hoxton_mission then
		self.old_hoxton_mission.no_suppressed_reaction = true
	end
	
	if self.spa_vip then
		self.spa_vip.no_suppressed_reaction = true
	end
end