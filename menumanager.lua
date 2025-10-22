if RequiredScript == "lib/managers/menumanager" then
	_G.LIES = {
		mod_path = ModPath,
		loc_path = ModPath .. "loc/",
		save_path = SavePath .. "LittleIntelligenceEnhancementS.txt",
		default_loc_path = ModPath .. "loc/en.txt",
		options_path = ModPath .. "menu/options.txt",
		version = "V8.47",
		settings = {
			lua_cover = false,
			jokerhurts = false,
			extra_chatter = true,
			enemy_aggro_level = 2,
			enemy_reaction_level = 1,
			enemy_travel_level = 1,
			fixed_spawngroups = 1,
			copsretire = false,
			nav_link_interval = 1,
			coplimit = 1,
			interruptoncontact = true,
			teamaihelpers = true,
			spawngroupdelays = 1,
			hhtacs = false,
			highperformance = false
		}
	}
	LIES.update_url = "https://raw.githubusercontent.com/fuglore/Little-Intelligence-Enhancements/auto-updates/autoupdate.json"

	TheFixesPreventer = TheFixesPreventer or {}
	TheFixesPreventer.fix_hostages_not_moving = true
	TheFixesPreventer.crash_no_unit_type_aistatebesiege = true
	TheFixesPreventer.crash_criminal_obj_complete_aistatebase = true
	TheFixesPreventer.crash_upd_aim_coplogicattack = true
	TheFixesPreventer.crash_aim_allow_fire_coplogicattack = true
	TheFixesPreventer.civvie_goes_to_player = true

	function LIES:tprint(tbl, indent, depth)
		depth = depth or 2
		indent = indent or 0
		local toprint = string.rep(" ", indent) .. "{\r\n"
		indent = indent + 2
		
		if type(tbl) ~= "table" then
			toprint = "type is not table, type is " .. type(tbl) .. " with value of " .. tostring(tbl)
			
			return toprint
		else
			for k, v in pairs(tbl) do
				toprint = toprint .. string.rep(" ", indent)

				if type(k) == "number" then
					toprint = toprint .. "[" .. k .. "] = "
				elseif type(k) == "string" then
					toprint = toprint .. k .. "= "
				end

				if type(v) == "number" then
					toprint = toprint .. v .. ",\r\n"
				elseif type(v) == "string" then
					toprint = toprint .. "\"" .. v .. "\",\r\n"
				elseif type(v) == "table" then
					if depth > 0 then
						toprint = toprint .. LIES:tprint(v, indent, depth - 1) .. ",\r\n"
					end
				else
					toprint = toprint .. "\"" .. tostring(v) .. "\",\r\n"
				end
			end
		end

		toprint = toprint .. string.rep(" ", indent - 2) .. "}"

		return toprint
	end

	function LIES:UseLuaCover()
		return self.settings.lua_cover
	end

	function LIES:Load()
		local file = io.open(LIES.save_path, "r")

		if file then
			for k, v in pairs(json.decode(file:read("*all"))) do
				LIES.settings[k] = v
			end
		else
			LIES:Save()
		end
	end

	function LIES:Save()
		local file = io.open(LIES.save_path,"w+")

		if file then
			file:write(json.encode(LIES.settings))
			file:close()
		end
	end
	
	local mvec3_cpy = mvector3.copy
	
	function LIES:find_cover_in_cone_from_threat_pos_1(threat_pos, furthest_pos, near_pos, search_from_pos, angle, min_dis, nav_seg, optimal_threat_dis, rsrv_filter)
		local copied_threat_pos = threat_pos and mvec3_cpy(threat_pos) or nil
		
		return managers.navigation:_find_cover_through_lua(copied_threat_pos, near_pos, furthest_pos, min_dis, search_from_pos)
	end

	function LIES:find_cover_in_nav_seg_3(nav_seg_id, max_near_dis, near_pos, threat_pos)
		local copied_threat_pos = threat_pos and mvec3_cpy(threat_pos) or nil

		return managers.navigation:_find_cover_in_seg_through_lua(copied_threat_pos, near_pos, nav_seg_id)
	end

	function LIES:find_cover_from_threat(nav_seg_id, optimal_threat_dis, near_pos, threat_pos)
		local copied_threat_pos = threat_pos and mvec3_cpy(threat_pos) or nil

		return managers.navigation:_find_cover_in_seg_through_lua(threat_pos, near_pos, nav_seg_id)
	end
	
	function LIES:find_cover_near_pos_1(near_pos, threat_pos, max_near_dis, min_threat_dis, allow_fwd)
		local copied_threat_pos = threat_pos and mvec3_cpy(threat_pos) or nil
		
		return managers.navigation:_find_cover_through_lua(copied_threat_pos, near_pos, nil, min_threat_dis, nil, max_near_dis)
	end
	
	function LIES:find_cover_away_from_pos(near_pos, threat_pos, nav_seg_id)
		local copied_threat_pos = threat_pos and mvec3_cpy(threat_pos) or nil
		
		return managers.navigation:_find_cover_in_seg_through_lua(copied_threat_pos, near_pos, nav_seg_id)
	end

	function LIES:_path_is_straight_line(pos_from, pos_to, u_data)
		if not pos_from.z then
			if alive(pos_from) then
				pos_from = CopActionWalk._nav_point_pos(pos_from:script_data())
			else
				return
			end
		end
		
		if not pos_to.z then
			if alive(pos_to) then
				pos_to = CopActionWalk._nav_point_pos(pos_to:script_data())
			else
				return
			end
		end

		if math.abs(pos_from.z - pos_to.z) > 60 then 
			return
		end
		
		local ray = CopActionWalk._chk_shortcut_pos_to_pos(pos_from, pos_to)

		return not ray 
	end
	
	function LIES:_optimize_path(path, u_data)		
		if #path <= 2 then
			return path
		end

		local opt_path = {}
		local nav_path = {}
		
		for i = 1, #path do
			local nav_point = path[i]

			if nav_point.x then
				nav_path[#nav_path + 1] = nav_point
			elseif alive(nav_point) then
				nav_path[#nav_path + 1] = {
					element = nav_point:script_data().element,
					c_class = nav_point
				}
			else
				return path
			end
		end
		
		nav_path = CopActionWalk._calculate_simplified_path(path[1], nav_path, 1, true, true)
		
		for i = 1, #nav_path do
			local nav_point = nav_path[i]
			
			if nav_point.c_class then
				opt_path[#opt_path + 1] = nav_point.c_class
			else
				opt_path[#opt_path + 1] = nav_point
			end
		end

		return opt_path
	end


	local function make_dis_id(from, to)
		local f = from < to and from or to
		local t = to < from and from or to

		return tostring(f) .. "-" .. tostring(t)
	end

	local function spawn_group_id(spawn_group)
		return spawn_group.mission_element:id()
	end
	
	function LIES:_upd_recon_tasks()
		local task_data = self._task_data.recon.tasks[1]

		self:_assign_enemy_groups_to_recon()

		if not task_data then
			return
		end

		local t = self._t

		self:_assign_assault_groups_to_retire()

		local target_pos = task_data.target_area.pos
		local nr_wanted = self:_get_difficulty_dependent_value(self._tweak_data.recon.force) - self:_count_police_force("recon")

		if nr_wanted <= 0 then
			return
		end

		local used_event, used_spawn_points, reassigned = nil

		if task_data.use_spawn_event then
			task_data.use_spawn_event = false

			if self:_try_use_task_spawn_event(t, task_data.target_area, "recon") then
				used_event = true
			end
		end

		if not used_event then
			local used_group = nil

			if next(self._spawning_groups) then
				used_group = true
			else
				local spawn_group, spawn_group_type = self:_find_spawn_group_near_area(task_data.target_area, self._tweak_data.recon.groups, nil, nil, callback(self, self, "_verify_anticipation_spawn_point"), "recon")

				if spawn_group then
					local grp_objective = {
						attitude = "avoid",
						scan = true,
						stance = "hos",
						type = "recon_area",
						area = spawn_group.area,
						target_area = task_data.target_area
					}

					self:_spawn_in_group(spawn_group, spawn_group_type, grp_objective)

					used_group = true
				end
			end
		end

		if used_event or used_spawn_points or reassigned then
			table.remove(self._task_data.recon.tasks, 1)

			self._task_data.recon.next_dispatch_t = t + math.ceil(self:_get_difficulty_dependent_value(self._tweak_data.recon.interval)) + math.random() * self._tweak_data.recon.interval_variation
		end
	end

	function LIES:_upd_assault_task()
		local task_data = self._task_data.assault

		if LIES.settings.copsretire then
			local task_data = self._task_data.assault
			
			if self._hunt_mode then
			
			elseif task_data.phase == "fade" then
				self:_assign_assault_groups_to_retire()
			elseif task_data.said_retreat then
				self:_assign_assault_groups_to_retire()
			elseif not task_data or not task_data.active then
				self:_assign_assault_groups_to_retire()
			end
		end

		if LIES.settings.hhtacs then
			if self._bosses and next(self._bosses) then
				if self._hunt_mode ~= "boss" then
					local old_hunt = self._hunt_mode
					self._old_hunt_mode = old_hunt
				end
				
				self._hunt_mode = "boss"

				if task_data.phase == "anticipation" or task_data.phase == "fade" or not task_data.active then
					self:start_extend_assault()
				end
			elseif self._hunt_mode == "boss" then
				local old_hunt = self._old_hunt_mode
				self._hunt_mode = old_hunt
				self._old_hunt_mode = nil
			end
		end

		if not task_data.active then
			return
		end

		local t = self._t

		self:_assign_recon_groups_to_retire()

		local force_pool = self:_get_difficulty_dependent_value(self._tweak_data.assault.force_pool) * self:_get_balancing_multiplier(self._tweak_data.assault.force_pool_balance_mul)
		local task_spawn_allowance = force_pool - (self._hunt_mode and 0 or task_data.force_spawned)

		if task_data.phase == "anticipation" then
			if task_spawn_allowance <= 0 then
				print("spawn_pool empty: -----------FADE-------------")

				task_data.phase = "fade"
				task_data.phase_end_t = t + self._tweak_data.assault.fade_duration
			elseif task_data.phase_end_t < t or self._drama_data.zone == "high" then
				self._assault_number = self._assault_number + 1

				managers.mission:call_global_event("start_assault")
				managers.hud:start_assault(self._assault_number)
				managers.groupai:dispatch_event("start_assault", self._assault_number)
				self:_set_rescue_state(false)

				task_data.phase = "build"
				task_data.phase_end_t = self._t + self._tweak_data.assault.build_duration
				task_data.is_hesitating = nil

				self:set_assault_mode(true)
				managers.trade:set_trade_countdown(false)
			else
				managers.hud:check_anticipation_voice(task_data.phase_end_t - t)
				managers.hud:check_start_anticipation_music(task_data.phase_end_t - t)

				if task_data.is_hesitating and task_data.voice_delay < self._t then
					if self._hostage_headcount > 0 then
						local best_group = nil

						for _, group in pairs(self._groups) do
							if not best_group or group.objective.type == "reenforce_area" then
								best_group = group
							elseif best_group.objective.type ~= "reenforce_area" and group.objective.type ~= "retire" then
								best_group = group
							end
						end

						if best_group and self:_voice_delay_assault(best_group) then
							task_data.is_hesitating = nil
						end
					else
						task_data.is_hesitating = nil
					end
				end
			end
		elseif task_data.phase == "build" then
			if task_spawn_allowance <= 0 then
				task_data.phase = "fade"
				task_data.phase_end_t = t + self._tweak_data.assault.fade_duration
			elseif task_data.phase_end_t < t or self._drama_data.zone == "high" then
				local sustain_duration = math.lerp(self:_get_difficulty_dependent_value(self._tweak_data.assault.sustain_duration_min), self:_get_difficulty_dependent_value(self._tweak_data.assault.sustain_duration_max), math.random()) * self:_get_balancing_multiplier(self._tweak_data.assault.sustain_duration_balance_mul)

				managers.modifiers:run_func("OnEnterSustainPhase", sustain_duration)

				task_data.phase = "sustain"
				task_data.phase_end_t = t + sustain_duration
			end
		elseif task_data.phase == "sustain" then
			local end_t = self:assault_phase_end_time()
			task_spawn_allowance = managers.modifiers:modify_value("GroupAIStateBesiege:SustainSpawnAllowance", task_spawn_allowance, force_pool)

			if task_spawn_allowance <= 0 then
				task_data.phase = "fade"
				task_data.phase_end_t = t + self._tweak_data.assault.fade_duration
			elseif end_t < t and not self._hunt_mode then
				task_data.phase = "fade"
				task_data.phase_end_t = t + self._tweak_data.assault.fade_duration
			end
		else
			local end_assault = false
			local enemies_left = self:_count_police_force("assault")

			if not self._hunt_mode then
				local enemies_defeated_time_limit = 30
				local drama_engagement_time_limit = 60

				if managers.skirmish:is_skirmish() then
					enemies_defeated_time_limit = 0
					drama_engagement_time_limit = 0
				end

				local min_enemies_left = 50
				local enemies_defeated = enemies_left < min_enemies_left
				local taking_too_long = t > task_data.phase_end_t + enemies_defeated_time_limit

				if enemies_defeated or taking_too_long then
					self:_assign_assault_groups_to_retire()
				
					if not task_data.said_retreat then
						task_data.said_retreat = true

						self:_police_announce_retreat()
					elseif task_data.phase_end_t < t then
						local drama_pass = self._drama_data.amount < tweak_data.drama.assault_fade_end
						local engagement_pass = self:_count_criminals_engaged_force(11) <= 10
						local taking_too_long = t > task_data.phase_end_t + drama_engagement_time_limit

						if drama_pass and engagement_pass or taking_too_long then
							end_assault = true
						end
					end
				end

				if task_data.force_end or end_assault then
					print("assault task clear")

					task_data.active = nil
					task_data.phase = nil
					task_data.said_retreat = nil
					task_data.force_end = nil
					local force_regroup = task_data.force_regroup
					task_data.force_regroup = nil

					if self._draw_drama then
						self._draw_drama.assault_hist[#self._draw_drama.assault_hist][2] = t
					end

					managers.mission:call_global_event("end_assault")
					self:_begin_regroup_task(force_regroup)

					return
				end
			end
		end

		if self._drama_data.amount <= tweak_data.drama.low then
			for criminal_key, criminal_data in pairs(self._player_criminals) do
				self:criminal_spotted(criminal_data.unit)

				for group_id, group in pairs(self._groups) do
					if group.objective.charge then
						for u_key, u_data in pairs(group.units) do
							u_data.unit:brain():clbk_group_member_attention_identified(nil, criminal_key)
						end
					end
				end
			end
		end

		local primary_target_area = task_data.target_areas[1]

		if self:is_area_safe_assault(primary_target_area) then
			local target_pos = primary_target_area.pos
			local nearest_area, nearest_dis = nil

			for criminal_key, criminal_data in pairs(self._player_criminals) do
				if not criminal_data.status then
					local dis = mvector3.distance_sq(target_pos, criminal_data.m_pos)

					if not nearest_dis or dis < nearest_dis then
						nearest_dis = dis
						nearest_area = self:get_area_from_nav_seg_id(criminal_data.tracker:nav_segment())
					end
				end
			end

			if nearest_area then
				primary_target_area = nearest_area
				task_data.target_areas[1] = nearest_area
			end
		end

		if not self._last_upd_t then
			self._last_upd_t = self._t
		end

		if not task_data.old_target_pos then
			local target_pos
			
			local target_pos = primary_target_area.pos
			local nearest_pos, nearest_dis = nil

			for criminal_key, criminal_data in pairs(self._player_criminals) do
				if not criminal_data.status or criminal_data.status == "electrified" then
					local dis = mvector3.distance_sq(target_pos, criminal_data.m_pos)

					if not nearest_dis or dis < nearest_dis then
						nearest_dis = dis
						nearest_pos = criminal_data.m_pos
					end
				end
			end
			
			if nearest_pos then
				task_data.old_target_pos = mvec3_cpy(nearest_pos)
				task_data.old_target_pos_t = 0
			end
		else		
			local target_pos = task_data.old_target_pos
			local nearest_pos, nearest_dis, best_z = nil

			for criminal_key, criminal_data in pairs(self._player_criminals) do
				if not criminal_data.status or criminal_data.status == "electrified" then
					local dis = mvector3.distance(target_pos, criminal_data.m_pos)
					local z_dis = math.abs(criminal_data.m_pos.z - target_pos.z)
					
					if not best_z or best_z <= 350 and z_dis <= 350 or z_dis < best_z then
						if not nearest_dis or dis < nearest_dis then
							nearest_dis = dis
							nearest_pos = criminal_data.m_pos
							best_z = z_dis
						end
					end
				end
			end
			
			if nearest_pos and (best_z > 250 or nearest_dis > 600) then
				task_data.old_target_pos = mvector3.copy(nearest_pos)
				task_data.old_target_pos_t = 0
			elseif nearest_pos then
				local t_since_upd = self._t - self._last_upd_t
				task_data.old_target_pos_t = task_data.old_target_pos_t and task_data.old_target_pos_t + t_since_upd or t_since_upd
			else --all players invalid for this, so lets empty it
				task_data.old_target_pos = nil
				task_data.old_target_pos_t = nil
			end
		end

		local nr_wanted = task_data.force - self:_count_police_force("assault")

		if task_data.phase == "anticipation" then
			nr_wanted = nr_wanted - 5
		end

		if nr_wanted > 0 and task_data.phase ~= "fade" then
			local used_event = nil

			if task_data.use_spawn_event and task_data.phase ~= "anticipation" then
				task_data.use_spawn_event = false

				if self:_try_use_task_spawn_event(t, primary_target_area, "assault") then
					used_event = true
				end
			end

			if not used_event then
				if next(self._spawning_groups) then
					-- Nothing
				else
					self:_check_spawn_timed_groups(primary_target_area, task_data)
				
					local spawn_group, spawn_group_type = self:_find_spawn_group_near_area(primary_target_area, self._tweak_data.assault.groups, nil, nil, nil, "assault")

					if spawn_group then
						local grp_objective = {
							attitude = "avoid",
							stance = "hos",
							pose = "crouch",
							type = "assault_area",
							area = spawn_group.area,
							coarse_path = {
								{
									spawn_group.area.pos_nav_seg,
									spawn_group.area.pos
								}
							}
						}

						self:_spawn_in_group(spawn_group, spawn_group_type, grp_objective, task_data)
					end
				end
			end
		end

		if task_data.phase ~= "anticipation" then
			if task_data.use_smoke_timer < t then
				task_data.use_smoke = true
			end

			self:detonate_queued_smoke_grenades()
		end

		self:_assign_enemy_groups_to_assault(task_data.phase)
	end

	function LIES:_choose_best_groups(best_groups, group, group_types, allowed_groups, my_wgt, task_data)	
		local total_weight = 0
		local group_type_order, group_order_index, wanted_group
		
		if task_data and self._group_type_order[task_data] then
			group_type_order = self._group_type_order[task_data].group_types			
			group_order_index = self._group_type_order[task_data].index
			
			self._group_type_order[task_data].index = self._group_type_order[task_data].index + 1
			
			wanted_group = group_type_order[group_order_index]
		end

		for _, group_type in ipairs(group_types) do
			if not wanted_group or wanted_group == group_type then
				if tweak_data.group_ai.enemy_spawn_groups[group_type] then
					local group_tweak = tweak_data.group_ai.enemy_spawn_groups[group_type]
					local special_type, spawn_limit, current_count = nil
					local cat_weights = allowed_groups[group_type]

					if cat_weights then				
						local cat_weight = cat_weights[1]
						
						table.insert(best_groups, {
							group = group,
							group_type = group_type,
							wght = cat_weight,
							cat_weight = cat_weight,
							dis_weight = cat_weight
						})

						total_weight = total_weight + cat_weight
					end
				end
			end
		end

		if group_type_order and self._group_type_order[task_data].index > #group_type_order then
			self._group_type_order[task_data].index = 1
		end
		
		return total_weight
	end
	
	function LIES:check_for_updates()
		dohttpreq(self.update_url, function(json_data, http_id)
			self:set_update_data(json_data)
		end)
	end
	
	function LIES:set_update_data(json_data)
		if json_data:is_nil_or_empty() then
			return
		end
		
		local received_data = json.decode(json_data)
		
		for _, data in pairs(received_data) do
			if data.version then
				LIES.received_version = data.version
				log("LIES: Received update data.")
				break
			end
		end
	end
	
	Hooks:Add("LocalizationManagerPostInit", "LocalizationManagerPostInit_LIES", function( loc )
		loc:load_localization_file( LIES.default_loc_path)
	end)
	
	--add the menu callbacks for when menu options are changed
	Hooks:Add( "MenuManagerInitialize", "MenuManagerInitialize_LIES", function(menu_manager)		
		MenuCallbackHandler.callback_lies_lua_cover = function(self, item)
			local value = item:value()
			LIES.settings.lua_cover = value
			
			if managers.navigation then
				managers.navigation:_change_funcs()
			end
			
			LIES:Save()
		end
		
		MenuCallbackHandler.callback_lies_extra_chatter = function(self, item)
			local on = item:value() == "on"
			LIES.settings.extra_chatter = on

			LIES:Save()
		end
		
		MenuCallbackHandler.callback_lies_jokerhurts = function(self, item)
			local on = item:value() == "on"
			LIES.settings.jokerhurts = on

			LIES:Save()
		end
		
		MenuCallbackHandler.callback_lies_enemy_aggro_level = function(self, item)
			local value = item:value()
			LIES.settings.enemy_aggro_level = value

			LIES:Save()
		end
		
		MenuCallbackHandler.callback_lies_enemy_travel_level = function(self, item)
			local value = item:value()
			LIES.settings.enemy_travel_level = value

			LIES:Save()
		end
		
		MenuCallbackHandler.callback_lies_enemy_reaction_level = function(self, item)
			local value = item:value()
			LIES.settings.enemy_reaction_level = value

			LIES:Save()
		end
		
		MenuCallbackHandler.callback_lies_fixed_spawngroups = function(self, item)
			local value = item:value()
			LIES.settings.fixed_spawngroups = value
			
			LIES.smg_groups = nil

			LIES:Save()
		end

		MenuCallbackHandler.callback_lies_copsretire = function(self, item)
			local on = item:value() == "on"
			LIES.settings.copsretire = on

			LIES:Save()
		end
		
		MenuCallbackHandler.callback_lies_teamaihelpers = function(self, item)
			local on = item:value() == "on"
			LIES.settings.teamaihelpers = on

			LIES:Save()
		end
		
		MenuCallbackHandler.callback_lies_nav_link_interval = function(self, item)
			local value = item:value()
			LIES.settings.nav_link_interval = value

			LIES:Save()
		end
		
		MenuCallbackHandler.callback_lies_coplimit = function(self, item)
			local value = item:value()
			LIES.settings.coplimit = value

			LIES:Save()
		end
		
		MenuCallbackHandler.callback_lies_interruptoncontact = function(self, item)
			local on = item:value() == "on"
			LIES.settings.interruptoncontact = on

			LIES:Save()
		end
		
		MenuCallbackHandler.callback_lies_spawngroupdelays = function(self, item)
			local value = item:value()
			LIES.settings.spawngroupdelays = value

			LIES:Save()
		end
		
		MenuCallbackHandler.callback_lies_hhtacs = function(self, item)
			local on = item:value() == "on"
			LIES.settings.hhtacs = on

			LIES:Save()
		end
		
		MenuCallbackHandler.callback_lies_highperformance = function(self, item)
			local on = item:value() == "on"
			LIES.settings.highperformance = on
			log("high performance mode: "..tostring(LIES.settings.highperformance))

			LIES:Save()
		end
		
		--called when the menu is closed
		MenuCallbackHandler.callback_lies_close = function(self)
		end

		--load settings from user's mod settings txt
		LIES:Load()
		
		if type(LIES.settings.spawngroupdelays) ~= "number" then
			log("LIES: Thanks for downloading the newest version. <3")
			LIES.settings.spawngroupdelays = LIES.settings.spawngroupdelays == true and 2 or 1
			
			LIES:Save()
		end
		
		if type(LIES.settings.fixed_spawngroups) ~= "number" then
			log("LIES: Thanks for downloading the newest version. <3")
			LIES.settings.fixed_spawngroups = 1
			
			LIES:Save()
		elseif LIES.settings.fixed_spawngroups > 2 then
			log("LIES: Thanks for downloading the newest version. <3")
			LIES.settings.fixed_spawngroups = 1
			
			LIES:Save()
		end
		
		if type(LIES.settings.lua_cover) ~= "number" then
			log("LIES: Thanks for downloading the newest version. <3")
			LIES.settings.lua_cover = LIES.settings.lua_cover == true and 2 or 1
			
			LIES:Save()
		elseif LIES.settings.lua_cover > 2 then
			log("LIES: Thanks for downloading the newest version. <3")
			LIES.settings.lua_cover = 2
			
			LIES:Save()
		end

		--create menus
		MenuHelper:LoadFromJsonFile(LIES.options_path, LIES, LIES.settings)
		
		if not Global.checked_for_updates_lies then
			log("LIES: Checking for update data.")
			LIES:check_for_updates()
			Global.checked_for_updates_lies = true
		end
	end)
end
