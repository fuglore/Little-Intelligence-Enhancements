function CopBase:default_weapon_name()
	local m_weapon_id = self._default_weapon_id
	
	
	if LIES.settings.hhtacs then
		if self._tweak_table == "chavez_boss" then
			m_weapon_id = "ak47"
		end
	end
	
	local weap_ids = tweak_data.character.weap_ids

	for i_weap_id, weap_id in ipairs(weap_ids) do
		if m_weapon_id == weap_id then
			return tweak_data.character.weap_unit_names[i_weap_id]
		end
	end
end