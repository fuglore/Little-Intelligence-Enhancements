function SkirmishTweakData:setup_hhtacs()
	if self._hhtacs then
		return
	end

	if LIES.settings.fixed_spawngroups < 3 then	
		local dumb_groups = {
			tac_swat_shotgun_rush = true,
			tac_swat_shotgun_flank = true,
			tac_swat_rifle = true,
			tac_swat_rifle_flank = true
		}

		for i = 1, #self.assault.groups do
			local weights = self.assault.groups[i]
			local weight_for_coolboys = 0
			
			for group_id, group_type in pairs(weights) do
				if dumb_groups[group_id] then
					weight_for_coolboys = weight_for_coolboys + weights[group_id][3]
				end
			end
			
			local weight_smg = weight_for_coolboys / 3
			local weight_rifle = weight_for_coolboys - weight_smg
			
			weights["tac_swat_rifle_flank"] = {
				weight_rifle,
				weight_rifle,
				weight_rifle
			}
			
			weights["tac_swat_smg"] = {
				weight_smg,
				weight_smg,
				weight_smg
			}
			
			for group_id, group_type in pairs(weights) do
				if not tweak_data.group_ai.enemy_spawn_groups[group_id] then
					weights[group_id] = {0, 0, 0}
				end
			end
		end
	end
	
	self._hhtacs = true
end