Hooks:PostHook(CopBase, "init", "lies_spicy_compatibility", function(self, unit)
	if LIES.settings.hhtacs then
		self.default_weapon_name = self.default_weapon_name_hhtacs
	end
end)

function CopBase:default_weapon_name_hhtacs()
	local m_weapon_id = self._default_weapon_id
	
	if self._chosen_weapon_name then
		return self._chosen_weapon_name
	end
	
	if LIES.settings.hhtacs then
		local security_vars = {
			security = true,
			security_mex = true,
			security_mex_no_pager = true
		}
		
		local cop_vars = {
			cop = true,
			cop_scared = true,
			cop_female = true
		}
	
		if self._tweak_table == "chavez_boss" then
			m_weapon_id = "ak47"
		elseif security_vars[self._tweak_table] then
			local security_weapon_ids = {
				"c45",
				"mp5",
				"raging_bull"
			}
			
			m_weapon_id = security_weapon_ids[math.random(#security_weapon_ids)]
		elseif cop_vars[self._tweak_table] then
			local police_weapon_ids = {
				"mp5",
				"raging_bull",
				"r870",
				"c45"
			}
			
			m_weapon_id = police_weapon_ids[math.random(#police_weapon_ids)]
		end
	end
	
	local weap_ids = tweak_data.character.weap_ids

	for i_weap_id, weap_id in ipairs(weap_ids) do
		if m_weapon_id == weap_id then
			self._chosen_weapon_name = tweak_data.character.weap_unit_names[i_weap_id]
		
			return self._chosen_weapon_name
		end
	end
end