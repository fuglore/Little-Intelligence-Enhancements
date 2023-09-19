local shotgun_groups = {
	tac_swat_shotgun_rush = true,
	tac_swat_shotgun_flank = true,
	tac_shield_wall_charge = true
}

local shotguns = {
	r870 = true,
	benelli = true
}

local shotgun_unit_types = {
	CS_swat_R870 = true,
	FBI_swat_R870 = true,
	CS_heavy_R870 = true,
	FBI_heavy_R870 = true,
}

local fbi_3_units = {
	[Idstring("units/payday2/characters/ene_fbi_3/ene_fbi_3"):key()] = true,
	[Idstring("units/pd2_dlc_hvh/characters/ene_fbi_hvh_3/ene_fbi_hvh_3"):key()] = true
}

function CopBase:default_weapon_name(selection_name)
	local weap_ids = tweak_data.character.weap_ids
	local weap_unit_names = tweak_data.character.weap_unit_names
	
	if selection_name and self._default_weapons then
		local weapon_id = self._default_weapons[selection_name]

		if weapon_id then
			for i_weap_id, weap_id in ipairs(weap_ids) do
				if weapon_id == weap_id then
					return weap_unit_names[i_weap_id]
				end
			end
		end
	end
	
	local difficulty = Global.game_settings and Global.game_settings.difficulty or "normal"
	local difficulty_index = tweak_data:difficulty_to_index(difficulty)

	local m_weapon_id = self._default_weapon_id

	if LIES.settings.hhtacs then
		if fbi_3_units[self._unit:name():key()] then
			m_weapon_id = "r870"
			
			local char_tweaks = deep_clone(self._char_tweak)
			char_tweaks.safe_weapon = "mp5"
			
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
	
		if not LIES.smg_groups then
			LIES.smg_groups = {}
			
			LIES.smg_groups["tac_swat_smg"] = true
		end
		
		local group_type = self._unit:brain()._logic_data and self._unit:brain()._logic_data.group and self._unit:brain()._logic_data.group.type
	
		if difficulty == "sm_wish" then
			if m_weapon_id == "dmr" then
				m_weapon_id = "heavy_zeal_sniper"
			end
			
			if m_weapon_id == "m4" or m_weapon_id == "mp5" or m_weapon_id == "ak47_ass" or m_weapon_id == "g36" then	
				local zeal_types = {
					swat = true,
					heavy_swat = true
				}
				
				--log(self._tweak_table)
				
				if self._tweak_table == "taser" then
					m_weapon_id = "m4_yellow"
				elseif self._tweak_table == "medic" and not shotguns[m_weapon_id] then
					m_weapon_id = "mp5"
				elseif zeal_types[self._tweak_table] then
					if self._shotgunner then
						m_weapon_id = "benelli"
					elseif self._unit_type and shotgun_unit_types[self._unit_type] then
						m_weapon_id = "benelli"
						self._shotgunner = true
					elseif LIES.smg_groups[group_type] then
						m_weapon_id = "ump"
					end
					
					if m_weapon_id == "m4" or m_weapon_id == "ak47_ass" or m_weapon_id == "g36" then
						m_weapon_id = "sg417"

						if not self._char_tweak.throwable then
							local char_tweaks = deep_clone(self._char_tweak)
							
							char_tweaks.safe_weapon = "raging_bull"
							
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
					elseif LIES.smg_groups[group_type] and not shotguns[m_weapon_id] then
						if tweak_data.group_ai._not_america == "russia" then
							m_weapon_id = "akmsu_smg"
						else
							m_weapon_id = "ump"
						end
					elseif m_weapon_id == "mp5" then
						m_weapon_id = "m4"
					end
				end
			elseif m_weapon_id == "r870" then
				m_weapon_id = "benelli"
				
				if self._tweak_table ~= "tank" and self._tweak_table ~= "tank_hw" then
					self._shotgunner = true
				end
			end
		elseif difficulty_index > 6 and m_weapon_id == "r870" then
			m_weapon_id = "benelli"
			
			if self._tweak_table ~= "tank" and self._tweak_table ~= "tank_hw" then
				self._shotgunner = true
			end
		elseif LIES.smg_groups[group_type] and not shotguns[m_weapon_id] then
			if tweak_data.group_ai._not_america == "russia" then
				m_weapon_id = "akmsu_smg"
			elseif difficulty_index > 5 and group_type ~= "tac_reenforce" then
				m_weapon_id = "ump"
			else
				m_weapon_id = "mp5"
			end
		elseif tweak_data.group_ai._not_america and (difficulty_index < 6 or difficulty_index > 7) and m_weapon_id == "g36" then
			m_weapon_id = "m4"
		elseif self._tweak_table == "taser" then
			m_weapon_id = "m4_yellow"
		elseif self._tweak_table == "medic" and not shotguns[m_weapon_id] then
			m_weapon_id = "mp5"
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
			
			if difficulty_index > 6 and m_weapon_id == "r870" then
				m_weapon_id = "benelli"	
				self._shotgunner = true
			end
		end
	elseif m_weapon_id == "m4" or m_weapon_id == "mp5" or m_weapon_id == "ak47_ass" then	
		if LIES.settings.fixed_spawngroups > 2 and difficulty == "sm_wish" then
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

	for i_weap_id, weap_id in ipairs(weap_ids) do
		if m_weapon_id == weap_id then
			self._current_weapon_id = m_weapon_id
			if not self._old_weapon then
				self._old_weapon = weap_unit_names[i_weap_id]
			end
			
			return weap_unit_names[i_weap_id]
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

function CopBase:change_and_sync_char_tweak(new_tweak_name)
	if not Network:is_server() then
		return
	end

	local new_tweak_data = tweak_data.character[new_tweak_name]

	if not new_tweak_data then
		return
	end

	if new_tweak_name == self._tweak_table then
		return
	end

	local old_tweak_data = self._char_tweak
	self._tweak_table = new_tweak_name
	self._char_tweak = new_tweak_data
	
	if not Global.game_settings.single_player then
		managers.network:session():send_to_peers_synched("sync_change_char_tweak", self._unit, new_tweak_name)
	end
	
	self:_chk_call_tweak_data_changed_listeners(old_tweak_data, new_tweak_data)
end