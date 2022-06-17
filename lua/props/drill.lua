Hooks:PostHook(Drill, "on_sabotage_SO_administered", "lies_drillvoiceline", function(self, receiver_unit)
	if self._saboteur and self._saboteur:key() == receiver_unit:key() then
		local voiceline = nil
		
		if self.is_drill then
			voiceline = "drillsabotage"
		else
			voiceline = "gearsabotage"
		end
	
	
		local brain = receiver_unit:brain()
		
		if brain._logic_data and brain._logic_data.group then
			local m_key = receiver_unit:key()
		
			local group = brain._logic_data.group 

			for u_key, u_data in pairs(group.units) do
				if u_key ~= m_key then
					if u_data.char_tweak.chatter.go_go and managers.groupai:state():chk_say_enemy_chatter(u_data.unit, u_data.m_pos, voiceline) then
						return true
					end
				end
			end
		end
		
		local best_group = nil

		for _, group in pairs(managers.groupai:state()._groups) do
			local group_has_reenforce = group.objective.type == "reenforce_area"
		
			if not best_group or group_has_reenforce then
				best_group = group
				
				if group_has_reenforce then
					break
				end
			elseif not group_has_reenforce and group.objective.type ~= "retire" then
				best_group = group
			end
		end
		
		
		if best_group then
			for u_key, u_data in pairs(best_group.units) do
				if u_key ~= m_key then
					if u_data.char_tweak.chatter.go_go and managers.groupai:state():chk_say_enemy_chatter(u_data.unit, u_data.m_pos, voiceline) then
						return true
					end
				end
			end
		end
	end
end)


Hooks:PostHook(Drill, "on_sabotage_SO_completed", "lies_drilljammedvoiceline", function(self, saboteur)
	if saboteur then
		if self.is_drill then
			saboteur:sound():say("e05", true)
		else
			saboteur:sound():say("e06", true)
		end
	end
end)