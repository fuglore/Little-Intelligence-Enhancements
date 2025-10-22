CopBrain._logic_variants.marshal_marksman.attack = CopLogicAttack

CopBrain._logic_variants.triad_boss.attack = LIESBossLogicAttack
CopBrain._logic_variants.deep_boss.attack = LIESDeepBossLogicAttack

CopBrain._logic_variants.tank = CopBrain._logic_variants.triad_boss
CopBrain._logic_variants.tank_medic = CopBrain._logic_variants.triad_boss
CopBrain._logic_variants.tank_mini = CopBrain._logic_variants.triad_boss
CopBrain._logic_variants.tank_hw = CopBrain._logic_variants.triad_boss
CopBrain._logic_variants.piggydozer = CopBrain._logic_variants.triad_boss
CopBrain._logic_variants.biker_boss = CopBrain._logic_variants.triad_boss
CopBrain._logic_variants.drug_lord_boss = CopBrain._logic_variants.triad_boss
CopBrain._logic_variants.hector_boss = CopBrain._logic_variants.triad_boss
CopBrain._logic_variants.mobster_boss = CopBrain._logic_variants.triad_boss
CopBrain._logic_variants.snowman_boss = CopBrain._logic_variants.triad_boss

function CopBrain:post_init()
	self._logics = CopBrain._logic_variants[self._unit:base()._tweak_table]

	self:_reset_logic_data()

	local my_key = tostring(self._unit:key())

	self._unit:character_damage():add_listener("CopBrain_hurt" .. my_key, {
		"dmg_rcv",
		"hurt",
		"light_hurt",
		"heavy_hurt",
		"hurt_sick",
		"shield_knock",
		"counter_tased",
		"taser_tased",
		"concussion"
	}, callback(self, self, "clbk_damage"))
	self._unit:character_damage():add_listener("CopBrain_death" .. my_key, {
		"death"
	}, callback(self, self, "clbk_death"))
	self:_setup_attention_handler()
	
	if not self._logic_data.team then
		local is_civilian = CopDamage.is_civilian(self._unit:base()._tweak_table)
		local team_name = is_civilian and "non_combatant" or self._unit:base():char_tweak().access == "gangster" and "gangster" or "combatant"
		local team_id = tweak_data.levels:get_default_team_ID(team_name)
		managers.groupai:state():set_char_team(self._unit, team_id)
	end

	if not self._current_logic then
		self:set_init_logic("idle")
	end

	if Network:is_server() then
		self:add_pos_rsrv("stand", {
			radius = 30,
			position = mvector3.copy(self._unit:movement():m_pos())
		})

		if not managers.groupai:state():enemy_weapons_hot() then
			self._enemy_weapons_hot_listen_id = "CopBrain" .. my_key

			managers.groupai:state():add_listener(self._enemy_weapons_hot_listen_id, {
				"enemy_weapons_hot"
			}, callback(self, self, "clbk_enemy_weapons_hot"))
		end
	end

	if not self._unit:contour() then
		debug_pause_unit(self._unit, "[CopBrain:post_init] character missing contour extension", self._unit)
	end
end
local loud_bosses = {
	triad_boss = true,
	deep_boss = true,
	drug_lord_boss = true,
	hector_boss = true,
	biker_boss = true,
	mobster_boss = true
}

Hooks:PostHook(CopBrain, "_reset_logic_data", "lies_reset_logic_data", function(self)
	self._logic_data.char_tweak = self._unit:base()._char_tweak or tweak_data.character[self._unit:base()._tweak_table]
	
	if LIES.settings.hhtacs then
		if self._unit:base()._tweak_table == "tank_mini" then
			local difficulty_index = tweak_data:difficulty_to_index(Global.game_settings.difficulty)
			
			if difficulty_index > 6 then
				self._minigunner_firing_buff = {
					id = self._unit:base():add_buff("base_damage", 0),
					amount = 0,
					last_chk_t = self._timer:time()
				}
			end
		end
		
		if loud_bosses[self._unit:base()._tweak_table] then
			managers.groupai:state():register_boss(self._unit)
		end
		
		self:_do_hhtacs_damage_modifiers()
	end
	
	self._logic_data.next_mov_time = self:get_movement_delay()
end)

Hooks:PostHook(CopBrain, "set_spawn_entry", "lies_accessentry", function(self, spawn_entry, tactics_map)
	if spawn_entry.access then
		self._spawn_entry_access = spawn_entry.access
		self._SO_access = managers.navigation:convert_access_flag(spawn_entry.access)
		self._logic_data.SO_access = self._SO_access
		self._logic_data.SO_access_str = spawn_entry.access
		local char_tweaks = deep_clone(self._unit:base()._char_tweak)
		char_tweaks.access = spawn_entry.access
		self._logic_data.char_tweak = char_tweaks
		self._unit:base()._char_tweak = char_tweaks
		self._unit:character_damage()._char_tweak = char_tweaks
		self._unit:movement()._tweak_data = char_tweaks
		self._unit:movement()._action_common_data.char_tweak = char_tweaks
	end
end)

Hooks:PostHook(CopBrain, "convert_to_criminal", "lies_convert_to_criminal", function(self, mastermind_criminal)
	local char_tweaks = deep_clone(self._unit:base()._char_tweak)
	
	char_tweaks.suppression = nil
	char_tweaks.throwable = nil
	char_tweaks.crouch_move = false
	
	if LIES.settings.jokerhurts then
		char_tweaks.damage.hurt_severity = deep_clone(tweak_data.character.presets.hurt_severities.only_light_hurt)
		
		char_tweaks.damage.hurt_severity.explosion = {
			health_reference = 1,
			zones = {
				{
					light = 1
				}
			}
		}
	end
	
	self._logic_data.char_tweak = char_tweaks
	self._unit:base()._char_tweak = char_tweaks
	self._unit:character_damage()._char_tweak = char_tweaks
	self._unit:movement()._tweak_data = char_tweaks
	self._unit:movement()._action_common_data.char_tweak = char_tweaks
end)

Hooks:PostHook(CopBrain, "clbk_death", "lies_remove_sabo_outline", function(self, my_unit, damage_info)
	if self._sabotage_contour_id then
		self._unit:contour():remove_by_id(self._sabotage_contour_id, true)
		self._sabotage_contour_id = nil
	end
end)

function CopBrain:set_spawn_ai(spawn_ai)
	self._spawn_ai = spawn_ai
	
	if self._logic_data and not self._logic_data.team then
		self._spawnai_wait_until_team_set = true
		
		return
	end

	self:set_update_enabled_state(true)

	if spawn_ai.init_state then
		self:set_logic(spawn_ai.init_state, spawn_ai.params)
	end

	if spawn_ai.stance then
		self._unit:movement():set_stance(spawn_ai.stance)
	end

	if spawn_ai.objective then
		self:set_objective(spawn_ai.objective)
	else
		local new_objective = {
			is_default = true,
			scan = true,
			type = "free",
			pos = not managers.groupai:state():enemy_weapons_hot() and mvector3.copy(self._unit:movement():m_pos())
		}
		
		if new_objective.pos then
			new_objective.nav_seg = managers.navigation:get_nav_seg_from_pos(new_objective.pos)
			new_objective.area = managers.groupai:state():get_area_from_nav_seg_id(new_objective.nav_seg)
		end
		
		self:set_objective(new_objective)
	end
end

function CopBrain:on_team_set(team_data)
	self._logic_data.team = team_data
	
	if self._spawnai_wait_until_team_set then
		self:set_spawn_ai(self._spawn_ai)
		self._spawnai_wait_until_team_set = nil
	end

	self._attention_handler:set_team(team_data)
end

function CopBrain:upd_falloff_sim()
	if self._unit:character_damage():dead() then
		return
	end
	
	self._current_logic.upd_falloff_sim(self._logic_data)
end

function CopBrain:check_upd_aim()
	if self._unit:character_damage():dead() then
		return
	end
	
	if self._current_logic_name == "disabled" or self._current_logic_name == "arrest" then
		return
	end
	
	if not self._logic_data.internal_data or not self._logic_data.internal_data.weapon_range then
		return
	end
	
	self._aim_update_counter = self._aim_update_counter or 0
	
	local vis_state = self._unit:base():lod_stage()
	vis_state = vis_state or 4
	local needs_update = self._aim_update_counter >= vis_state * 2
	
	if not needs_update then
		self._aim_update_counter = self._aim_update_counter + 1
		return
	end
	
	local dt = self._timer:time() - self._logic_data.t 
	
	self._logic_data.t = self._timer:time()
	self._logic_data.dt = dt
	
	if self._current_logic_name == "attack" then
		self._logics.attack._upd_aim(self._logic_data, self._logic_data.internal_data)
	elseif self._current_logic_name == "sniper" then
		self._current_logic._upd_aim(self._logic_data, self._logic_data.internal_data)
	else
		CopLogicAttack._upd_aim(self._logic_data, self._logic_data.internal_data)
	end
	
	self._aim_update_counter = 0
end

local fbi_3_units = {
	[Idstring("units/payday2/characters/ene_fbi_3/ene_fbi_3"):key()] = true,
	[Idstring("units/pd2_dlc_hvh/characters/ene_fbi_hvh_3/ene_fbi_hvh_3"):key()] = true
}

local supposedly_shitty_guns = {
	c45 = true,
	mac11 = true
}
local ludicrous_damage = {
	m4 = true,
	m4_yellow = true,
	ak47 = true
}
local ovk_rifles = {
	m4 = true,
	ak47_ass = true,
	m4_yellow_npc = true
}
local mayhem_rifles = {
	g36 = true
}
local scaling_units = {
	security = true,
	cop = true,
	fbi = true,
	zeal_swat = true,
	zeal_heavy_swat = true,
	gangster = true,
	tank_mini = true
}

local non_scaling_units = {
	fbi_heavy_swat = "zeal_heavy_swat",
	fbi_swat = "zeal_swat",
	city_swat = "zeal_swat",
	swat = "zeal_swat",
	heavy_swat = "zeal_heavy_swat"
}

local no_foff_tank_weapons = {
	m249 = true,
	rpk_lmg = true,
	saiga = true --it'll falloff faster overall due to getting combo'd with real falloff
}

local smgs = {
	mp5 = true,
	ump = true,
	akmsu_smg = true,
	mp9 = true,
	asval_smg = true,
	akmsu_smg = true,
	mp5_tactical = true,
	sr2_smg = true
}

function CopBrain:_do_hhtacs_damage_modifiers()
	local difficulty = Global.game_settings and Global.game_settings.difficulty or "normal"
	local difficulty_index = tweak_data:difficulty_to_index(difficulty)

	if self._ludicrous_damage_debuff then
		self._unit:base():remove_buff_by_id("base_damage", self._ludicrous_damage_debuff) 
		
		self._ludicrous_damage_debuff = nil
	end
	
	if self._unit:base()._phalanx_pusher then
		local wanted_dmg = 60 / 100
		self._ludicrous_damage_debuff = self._unit:base():add_buff("base_damage", wanted_dmg)
	elseif self._unit:base()._tweak_table == "old_hoxton_mission" or self._unit:base()._tweak_table == "spa_vip" then
		if supposedly_shitty_guns[self._unit:base()._current_weapon_id] then
			self._ludicrous_damage_debuff = self._unit:base():add_buff("base_damage", 2)
		end
	elseif supposedly_shitty_guns[self._unit:base()._current_weapon_id] and difficulty_index > 3 then
		if scaling_units[self._unit:base()._tweak_table] and difficulty_index > 6 then
			self._ludicrous_damage_debuff = self._unit:base():add_buff("base_damage", -0.6) --almost all guns in this game deal the same fucking damage, its dumb
		else
			self._ludicrous_damage_debuff = self._unit:base():add_buff("base_damage", -0.5)
		end	
	elseif self._unit:base()._tweak_table ~= "marshal_shield" and self._unit:base()._tweak_table ~= "marshal_shield_break" and self._unit:base()._current_weapon_id == "deagle" then
		if scaling_units[self._unit:base()._tweak_table] and difficulty_index > 6 then
			self._ludicrous_damage_debuff = self._unit:base():add_buff("base_damage", -0.4)
		else
			self._ludicrous_damage_debuff = self._unit:base():add_buff("base_damage", 1.5)
		end
	elseif self._unit:base()._tweak_table == "deep_boss" or self._unit:base()._tweak_table == "drug_lord_boss" or self._unit:base()._tweak_table == "mobster_boss" then
		if difficulty_index > 7 then
			local wanted_dmg = 60 / 90
			self._ludicrous_damage_debuff = self._unit:base():add_buff("base_damage", wanted_dmg)
		elseif difficulty_index == 7 then
			local wanted_dmg = 60 / 75
			self._ludicrous_damage_debuff = self._unit:base():add_buff("base_damage", wanted_dmg)
		elseif difficulty_index == 6 then
			local wanted_dmg = 60 / 70
			self._ludicrous_damage_debuff = self._unit:base():add_buff("base_damage", wanted_dmg)
		end
	elseif self._unit:base()._tweak_table == "triad_boss" then
		if difficulty_index > 7 then
			self._ludicrous_damage_debuff = self._unit:base():add_buff("base_damage", 1)
		elseif difficulty_index == 7 then
			self._ludicrous_damage_debuff = self._unit:base():add_buff("base_damage", 0.75)
		elseif difficulty_index == 6 then
			self._ludicrous_damage_debuff = self._unit:base():add_buff("base_damage", 0.5)
		else
			self._ludicrous_damage_debuff = self._unit:base():add_buff("base_damage", 0.25)
		end
	elseif self._unit:base()._tweak_table == "tank" then
		if difficulty_index > 6 then
			if self._unit:base()._current_weapon_id == "benelli" then
				self._ludicrous_damage_debuff = self._unit:base():add_buff("base_damage", -0.5) --225 damage base
			elseif self._unit:base()._current_weapon_id == "saiga" then
				self._ludicrous_damage_debuff = self._unit:base():add_buff("base_damage", -0.45) --around 140-ish damage base on DS
			end
		elseif difficulty_index == 6 and self._unit:base()._current_weapon_id == "saiga" then
			self._ludicrous_damage_debuff = self._unit:base():add_buff("base_damage", 0.6) --100 damage base on mayhem
		end
	elseif difficulty_index > 6 then
		if scaling_units[self._unit:base()._tweak_table] then
			if self._unit:base()._current_weapon_id == "raging_bull" then
				self._ludicrous_damage_debuff = self._unit:base():add_buff("base_damage", -0.5)
			elseif difficulty_index == 8 then
				if ludicrous_damage[self._unit:base()._current_weapon_id] then
					self._ludicrous_damage_debuff = self._unit:base():add_buff("base_damage", -0.6) --90
				elseif self._unit:base()._current_weapon_id == "sg417" then
					self._ludicrous_damage_debuff = self._unit:base():add_buff("base_damage", -0.4) --90
				elseif smgs[self._unit:base()._current_weapon_id] then
					local wanted_dmg = 1 - (50 / 75)
					self._ludicrous_damage_debuff = self._unit:base():add_buff("base_damage", -wanted_dmg)
				end
			end
		elseif difficulty_index == 8 then
			if self._unit:base()._current_weapon_id == "g36" or self._unit:base()._current_weapon_id == "smoke" or self._unit:base()._current_weapon_id == "m4_yellow" then
				self._ludicrous_damage_debuff = self._unit:base():add_buff("base_damage", -0.4) --g36 users deal 75 damage with "good" preset compared to zeal's 90
			elseif self._unit:base()._current_weapon_id == "scar" then
				self._ludicrous_damage_debuff = self._unit:base():add_buff("base_damage", 2) --90
			elseif self._unit:base()._current_weapon_id == "mossberg" then
				self._ludicrous_damage_debuff = self._unit:base():add_buff("base_damage", 0.5) --180
			elseif smgs[self._unit:base()._current_weapon_id] then
				self._ludicrous_damage_debuff = self._unit:base():add_buff("base_damage", 0.5) --45
			end
		elseif difficulty_index == 7 then
			if mayhem_rifles[self._unit:base()._current_weapon_id] then
				self._ludicrous_damage_debuff = self._unit:base():add_buff("base_damage", 0.5) --60
			elseif self._unit:base()._current_weapon_id == "ak47" then
				self._ludicrous_damage_debuff = self._unit:base():add_buff("base_damage", 0.5) --60
			elseif self._unit:base()._current_weapon_id == "scar" then
				self._ludicrous_damage_debuff = self._unit:base():add_buff("base_damage", 1.5) --75
			elseif smgs[self._unit:base()._current_weapon_id] then
				self._ludicrous_damage_debuff = self._unit:base():add_buff("base_damage", 0.5) --45
			elseif self._unit:base()._current_weapon_id == "benelli" then
				self._ludicrous_damage_debuff = self._unit:base():add_buff("base_damage", 0.2) --120 5 meters
			elseif self._unit:base()._current_weapon_id == "mossberg" then
				self._ludicrous_damage_debuff = self._unit:base():add_buff("base_damage", 0.25) --150
			end
		end
	elseif difficulty_index == 6 then
		if mayhem_rifles[self._unit:base()._current_weapon_id] then
			self._ludicrous_damage_debuff = self._unit:base():add_buff("base_damage", 1.25) --45
		elseif self._unit:base()._current_weapon_id == "m4" then
			self._ludicrous_damage_debuff = self._unit:base():add_buff("base_damage", 1.25) --45
		elseif self._unit:base()._current_weapon_id == "ak47_ass" then
			self._ludicrous_damage_debuff = self._unit:base():add_buff("base_damage", -0.1) --45
		elseif self._unit:base()._current_weapon_id == "scar" then
			self._ludicrous_damage_debuff = self._unit:base():add_buff("base_damage", 0.7) --51
		elseif self._unit:base()._current_weapon_id == "mossberg" then
			self._ludicrous_damage_debuff = self._unit:base():add_buff("base_damage", 0.25) --150
		end
	elseif difficulty_index == 5 then
		if ovk_rifles[self._unit:base()._current_weapon_id] then
			self._ludicrous_damage_debuff = self._unit:base():add_buff("base_damage", 0.5) --30
		elseif self._unit:base()._current_weapon_id == "ak47_ass" then
			self._ludicrous_damage_debuff = self._unit:base():add_buff("base_damage", 0.5)
		elseif self._unit:base()._current_weapon_id == "scar" then
			self._ludicrous_damage_debuff = self._unit:base():add_buff("base_damage", 0.5) --45
		elseif self._unit:base()._current_weapon_id == "benelli" or self._unit:base()._current_weapon_id == "r870" then
			self._ludicrous_damage_debuff = self._unit:base():add_buff("base_damage", -0.25) --75 on 5 meters
		end
	elseif difficulty_index < 4 then
		if supposedly_shitty_guns[self._unit:base()._current_weapon_id] then
			if difficulty_index == 2 then
				self._ludicrous_damage_debuff = self._unit:base():add_buff("base_damage", 1)
			else
				self._ludicrous_damage_debuff = self._unit:base():add_buff("base_damage", -0.75)
			end
		elseif smgs[self._unit:base()._current_weapon_id] then
			if difficulty_index == 2 then
				self._ludicrous_damage_debuff = self._unit:base():add_buff("base_damage", 2.5)
			else
				self._ludicrous_damage_debuff = self._unit:base():add_buff("base_damage", -0.5)
			end
		elseif ovk_rifles[self._unit:base()._current_weapon_id] then
			if difficulty_index == 2 then
				self._ludicrous_damage_debuff = self._unit:base():add_buff("base_damage", 4)
			else
				self._ludicrous_damage_debuff = self._unit:base():add_buff("base_damage", 1.5)
			end
		elseif self._unit:base()._current_weapon_id == "r870" then
			if difficulty_index == 2 then
				self._ludicrous_damage_debuff = self._unit:base():add_buff("base_damage", 2)
			else
				self._ludicrous_damage_debuff = self._unit:base():add_buff("base_damage", 0.5)
			end
		end
	elseif smgs[self._unit:base()._current_weapon_id] then
		self._ludicrous_damage_debuff = self._unit:base():add_buff("base_damage", -0.4)
	end
end

Hooks:PostHook(CopBrain, "set_group", "lies_reset_weapons", function(self, group)
	if not Network:is_server() then
		return
	end
	
	local weap_name = self._unit:base():default_weapon_name()

	if LIES.settings.hhtacs then
		if fbi_3_units[self._unit:name():key()] then
			self._unit:base():change_and_sync_char_tweak("fbi")
		end
		
		local difficulty = Global.game_settings and Global.game_settings.difficulty or "normal"
		local difficulty_index = tweak_data:difficulty_to_index(difficulty)
		
		if self._unit:base()._phalanx_pusher then
			if self._unit:inventory()._shield_unit then
				World:delete_unit(self._unit:inventory()._shield_unit)
				--self._unit:inventory()._shield_unit = nil
			end
			
			self._unit:inventory()._shield_unit_name = "units/pd2_dlc_usm2/characters/ene_acc_marshal_shield_1/marshal_shield_1"			
			self._unit:base():change_and_sync_char_tweak("biker_boss")
			
			local char_tweaks = deep_clone(self._unit:base()._char_tweak)
			char_tweaks.crouch_move = false
			char_tweaks.allowed_poses = {
				stand = true
			}
			char_tweaks.walk_only = true
			char_tweaks.dodge = nil
			self._logic_data.char_tweak = char_tweaks
			self._unit:base()._char_tweak = char_tweaks
			self._unit:character_damage()._char_tweak = char_tweaks
			self._unit:movement()._tweak_data = char_tweaks
			self._unit:movement()._action_common_data.char_tweak = char_tweaks
			
			if not self._unit:base()._ate_phalanx_pusher_damage then
				local damage = 200
				
				if difficulty_index < 5 then
					damage = 75
				elseif difficulty_index < 6 then
					damage = 150
				elseif difficulty_index < 8 then
					damage = 250
				end
				
				self._unit:character_damage():damage_simple({
					damage = damage,
					attacker_unit = self._unit,
					pos = self._unit:position(),
					attack_dir = math.UP
				})
				
				self._unit:base()._ate_phalanx_pusher_damage = true
			end
		end
	
		local not_america = tweak_data.group_ai._not_america
		
		if not_america and difficulty == "sm_wish" and not self._unit:base()._loudtweakdata then
			if non_scaling_units[self._unit:base()._tweak_table] then
				local new_tweak_name = non_scaling_units[self._unit:base()._tweak_table]
				self._unit:base():change_and_sync_char_tweak(new_tweak_name)
			end
		end
		
		if scaling_units[self._unit:base()._tweak_table] and difficulty_index > 6 then
			self._needs_falloff = {
				id = self._unit:base():add_buff("base_damage", 0),
				amount = 0
			}
		end
	end
	
	if self._unit:base()._old_weapon and weap_name ~= self._unit:base()._old_weapon then
		self._unit:base()._old_weapon = nil
		PlayerInventory.destroy_all_items(self._unit:inventory())

		self._unit:inventory():add_unit_by_name(weap_name, true)
		
		if self._unit:base()._phalanx_pusher then
			if self._unit:inventory()._shield_unit then
				World:delete_unit(self._unit:inventory()._shield_unit)
				--self._unit:inventory()._shield_unit = nil
			end
		end
	end
	
	if LIES.settings.hhtacs then
		if self._unit:base()._tweak_table == "tank" and no_foff_tank_weapons[self._unit:base()._current_weapon_id] then
			self._needs_falloff = {
				id = self._unit:base():add_buff("base_damage", 0),
				amount = 0
			}
		end
	
		self:_do_hhtacs_damage_modifiers()
	end
	
	if self._spawn_entry_access then
		local access_str = self._spawn_entry_access
		self._SO_access = managers.navigation:convert_access_flag(access_str)
		self._logic_data.SO_access = self._SO_access
		self._logic_data.SO_access_str = access_str
		local char_tweaks = deep_clone(self._unit:base()._char_tweak)
		char_tweaks.access = access_str
		self._logic_data.char_tweak = char_tweaks
		self._unit:base()._char_tweak = char_tweaks
		self._unit:character_damage()._char_tweak = char_tweaks
		self._unit:movement()._tweak_data = char_tweaks
		self._unit:movement()._action_common_data.char_tweak = char_tweaks
	end
end)

Hooks:PostHook(CopBrain, "on_reload", "lies_on_reload", function(self)
	if not Network:is_server() then
		return
	end
	
	self._logic_data.char_tweak = self._unit:base()._char_tweak or tweak_data.character[self._unit:base()._tweak_table]
	
	if self._spawn_entry_access then
		local access_str = self._spawn_entry_access
		self._SO_access = managers.navigation:convert_access_flag(access_str)
		self._logic_data.SO_access = self._SO_access
		self._logic_data.SO_access_str = access_str
		local char_tweaks = deep_clone(self._unit:base()._char_tweak)
		char_tweaks.access = access_str
		self._logic_data.char_tweak = char_tweaks
		self._unit:base()._char_tweak = char_tweaks
		self._unit:character_damage()._char_tweak = char_tweaks
		self._unit:movement()._tweak_data = char_tweaks
		self._unit:movement()._action_common_data.char_tweak = char_tweaks
	end
	
	local weap_name = self._unit:base():default_weapon_name()
	
	if self._unit:base()._phalanx_pusher then
		if self._unit:inventory()._shield_unit then
			World:delete_unit(self._unit:inventory()._shield_unit)
			--self._unit:inventory()._shield_unit = nil
		end
	end
	
	if self._unit:base()._old_weapon and weap_name ~= self._unit:base()._old_weapon then
		self._unit:base()._old_weapon = nil
		PlayerInventory.destroy_all_items(self._unit:inventory())

		self._unit:inventory():add_unit_by_name(weap_name, true)
		
		if self._unit:base()._phalanx_pusher then
			if self._unit:inventory()._shield_unit then
				World:delete_unit(self._unit:inventory()._shield_unit)
				--self._unit:inventory()._shield_unit = nil
			end
		end
	end
	
	if LIES.settings.hhtacs then
		self:_do_hhtacs_damage_modifiers()
	end
end)

Hooks:PostHook(CopBrain, "clbk_death", "lies_clbk_death", function(self, unit, dmg_info)
	self:rem_all_pos_rsrv()
end)

function CopBrain:add_pos_rsrv(rsrv_name, pos_rsrv)
	if self._unit:character_damage():dead() then
		return
	end

	local pos_reservations = self._logic_data.pos_rsrv

	if pos_reservations[rsrv_name] then
		managers.navigation:unreserve_pos(pos_reservations[rsrv_name])
	end

	pos_rsrv.filter = self._logic_data.pos_rsrv_id

	managers.navigation:add_pos_reservation(pos_rsrv)

	pos_reservations[rsrv_name] = pos_rsrv

	if not pos_rsrv.id then
		debug_pause_unit(self._unit, "[CopBrain:add_pos_rsrv] missing id", inspect(pos_rsrv))

		return
	end
end

function CopBrain:set_pos_rsrv(rsrv_name, pos_rsrv)
	if self._unit:character_damage():dead() then
		return
	end

	local pos_reservations = self._logic_data.pos_rsrv

	if pos_reservations[rsrv_name] == pos_rsrv then
		return
	end

	if pos_reservations[rsrv_name] then
		managers.navigation:unreserve_pos(pos_reservations[rsrv_name])
	end

	if not pos_rsrv.id then
		debug_pause_unit(self._unit, "[CopBrain:set_pos_rsrv] missing id", inspect(pos_rsrv))

		return
	end

	pos_reservations[rsrv_name] = pos_rsrv
end

function CopBrain:_on_player_slow_pos_rsrv_upd()
	if self:is_criminal() then
		if not self._logic_data.objective or self._logic_data.objective.type == "free" then
			self._logic_data.path_fail_t = nil
		elseif self._current_logic._on_player_slow_pos_rsrv_upd then
			self._current_logic._on_player_slow_pos_rsrv_upd(self._logic_data)
		end
	end
end

function CopBrain:get_movement_delay()
	if LIES.settings.enemy_travel_level < 4 then
		local base_delay = 0.2 + 0.7 * math.random()
		
		if self._logic_data.important then
			base_delay = base_delay / 1 + math.random()
		end
		
		base_delay = base_delay / LIES.settings.enemy_travel_level
		
		return base_delay
	else
		return -1
	end
end

function CopBrain:on_suppressed(state)
	if state ~= self._logic_data.is_suppressed then
		self._logic_data.is_suppressed = state or nil
		
		if self._logic_data.is_suppressed then
			if self._current_logic.on_suppressed_state then
				self._current_logic.on_suppressed_state(self._logic_data)
			end
		end
	end
end

function CopBrain:set_objective(new_objective, params)
	if self._logic_data and not self._logic_data.team then
		self._spawn_ai = self._spawn_ai or {}
		
		if self._spawn_ai.objective and not self._spawn_ai.followup_objective then
			self._spawn_ai.followup_objective = new_objective
		elseif not self._spawn_ai.objective then
			self._spawn_ai.objective = new_objective
		end
		
		self._spawnai_wait_until_team_set = true
		
		return
	end

	local old_objective = self._logic_data.objective
	
	--if new_objective and self._logic_data.char_tweak.is_escort then
		--managers.groupai:state():print_objective(new_objective)
	--end
	
	if new_objective and self._logic_data.char_tweak.buddy then
		local level = Global.level_data and Global.level_data.level_id

		if new_objective.element then
			if tweak_data.levels[level] and tweak_data.levels[level].ignored_so_elements and tweak_data.levels[level].ignored_so_elements[new_objective.element._id] then
				if new_objective.complete_clbk then
					new_objective.complete_clbk(self._unit, self._logic_data)
				end
				
				if new_objective.action_start_clbk then
					new_objective.action_start_clbk(self._unit)
				end
				
				return
			end
		end
		
		if tweak_data.levels[level].trigger_follower_behavior_element and new_objective.element and tweak_data.levels[level].trigger_follower_behavior_element[new_objective.element._id] then
			self._logic_data.check_crim_jobless = true
		end

		if new_objective.stance == "ntl" then
			new_objective.stance = nil
		end
	end
	
	if new_objective and new_objective.element and new_objective.needs_admin_clbk then
		new_objective.element:clbk_objective_administered(self._unit)
	end
	
	if new_objective and new_objective.followup_SO and not new_objective.followup_objective then
		local current_SO_element = new_objective.followup_SO
		local so_element = current_SO_element:choose_followup_SO(self._unit)
		followup_objective = so_element and so_element:get_objective(self._unit)
		
		if followup_objective and not followup_objective.trigger_on then
			followup_objective.needs_admin_clbk = true
			new_objective.followup_objective = followup_objective
			new_objective.followup_SO = nil
		end
	end
	
	if new_objective and self:objective_is_sabotage(new_objective) then
		new_objective.sabotage = true

		local dialogue_said = new_objective.sabo_voiceline and new_objective.sabo_voiceline == "none"
		
		if not dialogue_said then
			local m_key = self._logic_data.key
			local voiceline = new_objective.sabo_voiceline or "gensabotage"
			
			if self._logic_data.group then
				local group = self._logic_data.group 

				for u_key, u_data in pairs(group.units) do
					if u_key ~= m_key then
						if u_data.char_tweak.chatter.go_go and managers.groupai:state():chk_say_enemy_chatter(u_data.unit, u_data.m_pos, voiceline) then
							dialogue_said = true
							
							break
						end
					end
				end
			end
			
			if not dialogue_said then
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
								dialogue_said = true
								
								break
							end
						end
					end
				end
			end
		end
		
		if LIES.settings.hhtacs then
			if not self._sabotage_contour_id then
				self._sabotage_contour_id = self._unit:contour():add("highlight_character", true)
			end
		elseif self._sabotage_contour_id then
			self._unit:contour():remove_by_id(self._sabotage_contour_id, true)
			self._sabotage_contour_id = nil
		end
	elseif self._sabotage_contour_id then
		self._unit:contour():remove_by_id(self._sabotage_contour_id, true)
		self._sabotage_contour_id = nil
	end
	
	self._logic_data.objective = new_objective

	if new_objective and new_objective.followup_objective and new_objective.followup_objective.interaction_voice then
		self._unit:network():send("set_interaction_voice", new_objective.followup_objective.interaction_voice)
	elseif old_objective and old_objective.followup_objective and old_objective.followup_objective.interaction_voice then
		self._unit:network():send("set_interaction_voice", "")
	end

	self._current_logic.on_new_objective(self._logic_data, old_objective, params)
end

function CopBrain:search_for_coarse_immediate(search_id, to_seg, verify_clbk, access_neg)
	local params = {
		from_tracker = self._unit:movement():nav_tracker(),
		to_seg = to_seg,
		access = {
			"walk"
		},
		id = search_id,
		verify_clbk = verify_clbk,
		access_pos = self._logic_data.char_tweak.access,
		access_neg = access_neg
	}

	return managers.navigation:search_coarse(params)
end

function CopBrain:search_for_path(search_id, to_pos, prio, access_neg, nav_segs)
	if not prio then
		prio = CopLogicTravel.get_pathing_prio(self._logic_data)
	end

	local params = {
		tracker_from = self._unit:movement():nav_tracker(),
		pos_to = to_pos,
		result_clbk = callback(self, self, "clbk_pathing_results", search_id),
		id = search_id,
		prio = prio,
		access_pos = self._SO_access,
		access_pos_str = self._logic_data.SO_access_str,
		access_neg = access_neg,
		nav_segs = nav_segs
	}
	
	self._logic_data.active_searches[search_id] = true

	managers.navigation:search_pos_to_pos(params)

	return true
end

function CopBrain:search_for_path_from_pos(search_id, from_pos, to_pos, prio, access_neg, nav_segs)
	if not prio then
		prio = CopLogicTravel.get_pathing_prio(self._logic_data)
	end

	local params = {
		pos_from = from_pos,
		pos_to = to_pos,
		result_clbk = callback(self, self, "clbk_pathing_results", search_id),
		id = search_id,
		prio = prio,
		access_pos = self._SO_access,
		access_pos_str = self._logic_data.SO_access_str,
		access_neg = access_neg,
		nav_segs = nav_segs
	}
	
	self._logic_data.active_searches[search_id] = true
	managers.navigation:search_pos_to_pos(params)

	return true
end

function CopBrain:search_for_path_to_cover(search_id, cover, offset_pos, access_neg)
	if not prio then
		prio = CopLogicTravel.get_pathing_prio(self._logic_data)
		--log("Waaaah")
	end

	local params = {
		tracker_from = self._unit:movement():nav_tracker(),
		tracker_to = cover[3],
		prio = prio,
		result_clbk = callback(self, self, "clbk_pathing_results", search_id),
		id = search_id,
		access_pos = self._SO_access,
		access_pos_str = self._logic_data.SO_access_str,
		access_neg = access_neg
	}
	
	if offset_pos then
		params.pos_to = mvector3.copy(offset_pos)
		params.tracker_to = nil
	end

	self._logic_data.active_searches[search_id] = true
	managers.navigation:search_pos_to_pos(params)

	return true
end

Hooks:PostHook(CopBrain, "_add_pathing_result", "lies_pathing", function(self, search_id, path)
	if path and path ~= "failed" then
		--local line2 = Draw:brush(Color.green:with_alpha(0.5), 3)
		
		if line2 then
			for i = 1, #path do
				if path[i + 1] then
					local cur_nav_point = path[i]
					
					if not cur_nav_point.z then
						if alive(cur_nav_point) then
							cur_nav_point = CopActionWalk._nav_point_pos(cur_nav_point:script_data())
						end
					end
					
					if cur_nav_point.z then
						local next_nav_point = path[i + 1]
						
						if not next_nav_point.z then
							if alive(next_nav_point) then
								next_nav_point = CopActionWalk._nav_point_pos(next_nav_point:script_data())
							end
						end
						
						if next_nav_point.z then
							line2:cylinder(cur_nav_point, next_nav_point, 20)
						end
					end
				end
			end
		end
	
		self._logic_data.t = self._timer:time()
		self._logic_data.dt = self._timer:delta_time()

		--enemies in logictravel and logicattack will perform their appropriate actions as soon as possible once pathing has finished
		
		if self._current_logic._pathing_complete_clbk and not LIES.settings.highperformance then
			managers.groupai:state():on_unit_pathing_complete(self._unit)
		
			self._current_logic._pathing_complete_clbk(self._logic_data)
		end
	else
		managers.groupai:state():on_unit_pathing_failed(self._unit)
	end
end)

function CopBrain:_chk_use_cover_grenade(unit)
	if not Network:is_server() or not self._logic_data.char_tweak.dodge_with_grenade or not self._logic_data.attention_obj or self._unit:character_damage():dead() then
		return
	end

	local t = TimerManager:game():time()
	
	if not self._next_grenade_use_t or self._next_grenade_use_t < t then
		if self._logic_data.char_tweak.dodge_with_grenade.smoke then
			local duration_tweak = self._logic_data.char_tweak.dodge_with_grenade.smoke.duration
			local duration = math.lerp(duration_tweak[1], duration_tweak[2], math.random())

			managers.groupai:state():detonate_smoke_grenade(self._logic_data.m_pos + math.UP * 10, self._unit:movement():m_head_pos(), duration, false, true)

			self._next_grenade_use_t = t + duration
		elseif self._logic_data.char_tweak.dodge_with_grenade.flash then
			local duration_tweak = self._logic_data.char_tweak.dodge_with_grenade.flash.duration
			local duration = math.lerp(duration_tweak[1], duration_tweak[2], math.random())

			managers.groupai:state():detonate_smoke_grenade(self._logic_data.m_pos + math.UP * 10, self._unit:movement():m_head_pos(), duration, true, true)

			self._next_grenade_use_t = t + duration
		end
	end
end

local walk_blocked_actions = {
	hurt = true,
	healed = true,
	heal = true,
	walk = true,
	act = true,
	dodge = true
}

function CopBrain:action_complete_clbk(action)
	if self._unit:character_damage():dead() then
		return
	end
	
	local action_type = action:type()
	
	if walk_blocked_actions[action_type] then
		if action_type ~= "walk" then
			self._unit:movement():upd_m_head_pos()
		end
		
		if not self:is_criminal() then
			local delay = self:get_movement_delay()
			
			if delay > 0 then
				self._logic_data.next_mov_time = self._timer:time() + delay
			end
		end
	end
	
	self._current_logic.action_complete_clbk(self._logic_data, action)
end

function CopBrain:request_stillness(t)
	self._logic_data.next_mov_time = self._timer:time() + t
end

function CopBrain:is_criminal()
	if self._unit:in_slot(16) or self._logic_data.team and (self._logic_data.team.id == tweak_data.levels:get_default_team_ID("player") or self._logic_data.team.friends[tweak_data.levels:get_default_team_ID("player")]) then
		return true
	end
end

local safe_weapons = {
	c45 = true,
	raging_bull = true,
	deagle = true,
	mp5 = true --hrt swaps to this
}

local unsafe_weapons = {
	sg417 = true,
	r870 = true,
	benelli = true,
	mp5_tactical = true
}

function CopBrain:request_switch_to_safe_weapon(t)
	if self._logic_data.safe_weapon_cooldown_t and self._timer:time() < self._logic_data.safe_weapon_cooldown_t then
		return
	end

	if self._logic_data.safe_equipped then
		self._logic_data.safe_weapon_t = self._timer:time() + t
		
		return
	end

	if not self._logic_data.char_tweak or not self._logic_data.char_tweak.safe_weapon then
		return
	end
	
	if safe_weapons[self._unit:base()._current_weapon_id] or not unsafe_weapons[self._unit:base()._current_weapon_id] then
		return
	end
	
	local safe_weapon_id = self._logic_data.char_tweak.safe_weapon

	self._logic_data.safe_equipped = true
	self._logic_data.safe_weapon_t = self._timer:time() + t
	
	if not self._logic_data.safe_weapon_name then
		local weap_ids = tweak_data.character.weap_ids
		local weap_unit_names = tweak_data.character.weap_unit_names
		
		for i_weap_id, weap_id in ipairs(weap_ids) do
			if safe_weapon_id == weap_id then
				self._logic_data.safe_weapon_name = weap_unit_names[i_weap_id]
				
				break
			end
		end
	end
	
	local safe_weapon_name = self._logic_data.safe_weapon_name
	
	self._unit:base()._shotgunner = nil
	self._unit:base()._current_weapon_id = safe_weapon_id
	self._unit:base()._old_weapon = safe_weapon_name
	
	PlayerInventory.destroy_all_items(self._unit:inventory())

	self._unit:inventory():add_unit_by_name(safe_weapon_name, true)

	self:_do_hhtacs_damage_modifiers()

	return true
end

function CopBrain:request_switch_to_normal_weapon(t)
	if not self._logic_data.safe_equipped or self._logic_data.safe_weapon_t and self._logic_data.safe_weapon_t > self._timer:time() then
		return
	end
	
	self._logic_data.safe_equipped = nil
	self._logic_data.safe_weapon_cooldown_t = self._timer:time() + t

	local weap_name = self._unit:base():default_weapon_name()
	
	if self._unit:base()._old_weapon and weap_name ~= self._unit:base()._old_weapon then
		self._unit:base()._old_weapon = nil
		PlayerInventory.destroy_all_items(self._unit:inventory())

		self._unit:inventory():add_unit_by_name(weap_name, true)
	end
	
	self:_do_hhtacs_damage_modifiers()
	
	return true
end

local yeahitssabo = {
	untie = true,
	sabotage_device_low = true,
	sabotage_device_mid = true,
	sabotage_device_high = true
}

function CopBrain:objective_is_sabotage(objective)
	local data = self._logic_data
	
	if not data then
		return
	end
	
	local objective = objective or self._logic_data.objective
	
	if not objective or objective.grp_objective or data.cool then
		return
	end
	
	if objective.sabotage then
		return true
	end
	
	local is_civilian = CopDamage.is_civilian(data.unit:base()._tweak_table)
	
	if not data.team or not data.team.foes[tweak_data.levels:get_default_team_ID("player")] or is_civilian or loud_bosses[data.unit:base()._tweak_table] then
		return
	end
	
	if not objective.action then 
		if not objective.followup_objective or not objective.followup_objective.action then
			return
		elseif objective.followup_objective.element then
			local element = objective.followup_objective.element
			local variant = objective.followup_objective.action.variant
			
			if yeahitssabo[variant] then
				return true
			end

			if element:_is_nav_link() then
				if not variant or not CopActionAct._act_redirects.script[variant] and not string.begins(variant, "e_so") then
					return
				end
			elseif not variant or string.begins(variant, "AI_") or string.begins(variant, "e_nl") then
				return
			end

			if not element._events then
				return
			end
			
			if element._events["anim_start"] and next(element._events["anim_start"]) or element._events["complete"] and next(element._events["complete"]) then
				return true
			else
				return
			end
		elseif yeahitssabo[objective.action.variant] then
			return true
		end
	elseif objective.element then
		local element = objective.element
		local variant = objective.action.variant
		
		if yeahitssabo[variant] then
			return true
		end
		
		if element:_is_nav_link() then
			if not variant or not CopActionAct._act_redirects.script[variant] and not string.begins(variant, "e_so") then
				return
			end
		elseif not variant or string.begins(variant, "AI") or string.begins(variant, "e_nl")  then
			return
		end

		if not element._events then
			return
		end
		
		if element._events["anim_start"] and next(element._events["anim_start"]) or element._events["complete"] and next(element._events["complete"]) then
			return true
		else
			return
		end
	elseif yeahitssabo[objective.action.variant] then
		return true
	elseif not objective.sabo_voiceline then
		return
	end
	
	return true
end

function CopBrain:clbk_pathing_results(search_id, path, do_not_cache)
	local dead_nav_link_id = self._nav_links_to_check_on_results and self._nav_links_to_check_on_results[search_id]

	if dead_nav_link_id then
		if path then
			for i, nav_point in ipairs(path) do
				if not nav_point.x and (not alive(nav_point) or nav_point:script_data().element:id() == dead_nav_link_id) then
					path = nil

					break
				end
			end

			self._nav_links_to_check_on_results[search_id] = nil

			if not next(self._nav_links_to_check_on_results) then
				self._nav_links_to_check_on_results = nil
			end
		else
			self._nav_links_to_check_on_results[search_id] = nil

			if not next(self._nav_links_to_check_on_results) then
				self._nav_links_to_check_on_results = nil
			end
		end
	end

	self:_add_pathing_result(search_id, path)

	if path then
		local t = nil

		for i, nav_point in ipairs(path) do
			if not nav_point.x and nav_point:script_data().element:nav_link_delay() > 0 then
				t = t or TimerManager:game():time()

				nav_point:set_delay_time(t + nav_point:script_data().element:nav_link_delay())
			end
		end
		
		if not do_not_cache then
			local cached_path_info_params = {
				start_pos = path[1],
				end_pos = path[#path],
				path = path,
				access_pos = self._SO_access,
				access_pos_str = self._logic_data.SO_access_str,
				last_useful_t = t or TimerManager:game():time()
			}
			
			managers.navigation:_add_LIES_cached_path(cached_path_info_params)
		end
	end
end

function CopBrain:clbk_group_member_attention_verified(member_unit, attention_u_key)
	local att_unit_data, is_new = self._current_logic.identify_attention_obj_instant(self._logic_data, attention_u_key)
	
	if att_unit_data then
		att_unit_data.verified_t = att_unit_data.verified_t or -100
		att_unit_data.lost_track = nil
		att_unit_data.last_verified_pos = mvector3.copy(att_unit_data.verified_pos)
		att_unit_data.last_verified_m_pos = mvector3.copy(att_unit_data.verified_m_pos)
		att_unit_data.last_verified_dis = att_unit_data.verified_dis
	end
end

function CopBrain:update(unit, t, dt)
	local logic = self._current_logic

	if logic.update then
		local needs_skip_update = LIES.settings.highperformance
			
		if needs_skip_update then
			self._logic_update_counter = self._logic_update_counter or 0
		
			local vis_state = self._unit:base():lod_stage()
			vis_state = vis_state or 4
			local needs_update = self._logic_update_counter >= vis_state
			
			if not needs_update then
				self._logic_update_counter = self._logic_update_counter + 1
				return
			end
		end
	
		self._logic_update_counter = 0
		
		local l_data = self._logic_data
		
		local true_dt = t - l_data.t
		
		l_data.t = t
		l_data.dt = true_dt

		logic.update(l_data)
	end
end

function CopBrain:search_for_coarse_path_to_pos(search_id, to_pos, to_seg, verify_clbk, access_neg)
	local params = {
		from_tracker = self._unit:movement():nav_tracker(),
		to_seg = to_seg,
		to_pos = to_pos,
		access = {
			"walk"
		},
		id = search_id,
		results_clbk = callback(self, self, "clbk_coarse_pathing_results", search_id),
		verify_clbk = verify_clbk,
		access_pos = self._logic_data.char_tweak.access,
		access_neg = access_neg
	}
	self._logic_data.active_searches[search_id] = 2

	managers.navigation:search_coarse(params)

	return true
end