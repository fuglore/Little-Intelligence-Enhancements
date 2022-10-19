local shotgun_groups = {
	tac_swat_shotgun_rush = true,
	tac_swat_shotgun_flank = true,
	tac_shield_wall_charge = true
}

function CopBase:default_weapon_name()
	local m_weapon_id = self._default_weapon_id

	if LIES.settings.hhtacs then
		if Global.game_settings.difficulty == "sm_wish" then
			if m_weapon_id == "dmr" then
				m_weapon_id = "heavy_zeal_sniper"
			end
			
			if m_weapon_id == "m4" or m_weapon_id == "mp5" then	
				local zeal_types = {
					swat = true,
					heavy_swat = true
				}
				
				if zeal_types[self._tweak_table] then
					if self._unit:brain()._logic_data and self._unit:brain()._logic_data.group and self._unit:brain()._logic_data.group.type ~= "custom" then
						local l_data = self._unit:brain()._logic_data
						
						if shotgun_groups[l_data.group.type] then
							m_weapon_id = "benelli"
							self._shotgunner = true
						end
					elseif self._shotgunner then
						m_weapon_id = "benelli"
					end
					
					if m_weapon_id == "m4" then
						m_weapon_id = "sg417"

						if not self._char_tweak.throwable then
							local char_tweaks = deep_clone(self._char_tweak)
						
							char_tweaks.throwable = "launcher_frag"
							
							if self._tweak_table ~= "drug_lord_boss" then
								char_tweaks.throwable_delay = 30
								char_tweaks.global_delay = 5
							end
							
							self._char_tweak = char_tweaks
							
							if self._unit:brain()._logic_data then
								self._unit:brain()._logic_data.char_tweak = char_tweaks
							end
							
							self._unit:character_damage()._char_tweak = char_tweaks
							self._unit:movement()._tweak_data = char_tweaks
							
							if self._unit:movement()._action_common_data then
								self._unit:movement()._action_common_data.char_tweak = char_tweaks
							end
						end
					end
				end
			end
		end
	
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
	elseif m_weapon_id == "m4" or m_weapon_id == "mp5" then	
		if Global.game_settings.difficulty == "sm_wish" then
			local zeal_types = {
				swat = true,
				heavy_swat = true
			}
			
			if zeal_types[self._tweak_table] then
				if self._shotgunner then
					m_weapon_id = "benelli"
				elseif self._unit:brain()._logic_data and self._unit:brain()._logic_data.group and self._unit:brain()._logic_data.group.type ~= "custom" then
					local l_data = self._unit:brain()._logic_data
					
					if shotgun_groups[l_data.group.type] then
						m_weapon_id = "benelli"
						self._shotgunner = true
					end
				end
			end
		end
	end
	
	local weap_ids = tweak_data.character.weap_ids

	for i_weap_id, weap_id in ipairs(weap_ids) do
		if m_weapon_id == weap_id then
			self._current_weapon_id = m_weapon_id
			if not self._old_weapon then
				self._old_weapon = tweak_data.character.weap_unit_names[i_weap_id]
			end
			
			return tweak_data.character.weap_unit_names[i_weap_id]
		end
	end
end

function CopBase:change_buff_by_id(name, id, value)
	if not Network:is_server() then
		return
	end

	local buff_list = self._buffs[name]

	if not buff_list then
		return
	end
	
	local old_value = buff_list.buffs[id]

	buff_list.buffs[id] = value
	
	if old_value ~= value then
		self:_refresh_buff_total(name)
	end
end