if RequiredScript == "lib/managers/menumanager" then
	_G.LIES = {
		mod_path = ModPath,
		loc_path = ModPath .. "loc/",
		save_path = SavePath .. "LittleIntelligenceEnhancementS.txt",
		default_loc_path = ModPath .. "loc/en.txt",
		options_path = ModPath .. "menu/options.txt",
		version = "V3.48",
		settings = {
			lua_cover = false,
			jokerhurts = false,
			enemy_aggro_level = 2,
			specialdelay = false, --https://c.tenor.com/s9LwSLYtxlwAAAAC/bingus-bingus-combat.gif
			fixed_spawngroups = 1,
			fixed_specialspawncaps = false,
			copsretire = false,
			interruptoncontact = false,
			teamaihelpers = false,
			spawngroupdelays = false
		}
	}
	LIES.update_url = "https://raw.githubusercontent.com/fuglore/Little-Intelligence-Enhancements/auto-updates/autoupdate.json"

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
		local ray_params = {
			allow_entry = false,
			pos_from = pos_from,
			pos_to = pos_to
		}

		if not managers.navigation:raycast(ray_params) then
			local slotmask = managers.slot:get_mask("world_geometry")
			local ray_from = pos_from:with_z(pos_from.z + 51)
			local ray_to = pos_to:with_z(pos_to.z + 51)
			
			if u_data then
				if not u_data.unit:raycast("ray", ray_to, ray_from, "slot_mask", slotmask, "ray_type", "body mover", "sphere_cast_radius", 50, "bundle", 9, "report") then
					return true
				else
					return
				end
			else
				if not World:raycast("ray", ray_to, ray_from, "slot_mask", slotmask, "ray_type", "body mover", "sphere_cast_radius", 50, "bundle", 9, "report") then
					return true
				else
					return
				end
			end
		end
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
		
		nav_path = CopActionWalk._calculate_simplified_path(path[1], nav_path, 3, true, true)
		
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

	function LIES:_find_spawn_group_near_area(target_area, allowed_groups, target_pos, max_dis, verify_clbk, task_data)
		local all_areas = self._area_data
		local mvec3_dis = mvector3.distance_sq
		max_dis = max_dis and max_dis * max_dis
		local t = self._t
		local valid_spawn_groups = {}
		local valid_spawn_group_distances = {}
		local total_dis = 0
		target_pos = target_pos or target_area.pos
		local to_search_areas = {
			target_area
		}
		local found_areas = {
			[target_area.id] = true
		}

		repeat
			local search_area = table.remove(to_search_areas, 1)
			local spawn_groups = search_area.spawn_groups

			if spawn_groups then
				for _, spawn_group in ipairs(spawn_groups) do
					if spawn_group.delay_t <= t and (not verify_clbk or verify_clbk(spawn_group)) then
						local dis_id = make_dis_id(spawn_group.nav_seg, target_area.pos_nav_seg)

						if not self._graph_distance_cache[dis_id] then
							local coarse_params = {
								access_pos = "swat",
								from_seg = spawn_group.nav_seg,
								to_seg = target_area.pos_nav_seg,
								id = dis_id
							}
							local path = managers.navigation:search_coarse(coarse_params)

							if path and #path >= 2 then
								local dis = 0
								local current = spawn_group.pos

								for i = 2, #path do
									local nxt = path[i][2]

									if current and nxt then
										dis = dis + mvector3.distance(current, nxt)
									end

									current = nxt
								end

								self._graph_distance_cache[dis_id] = dis
							end
						end

						if self._graph_distance_cache[dis_id] then
							local my_dis = self._graph_distance_cache[dis_id]

							if not max_dis or my_dis < max_dis then
								total_dis = total_dis + my_dis
								valid_spawn_groups[spawn_group_id(spawn_group)] = spawn_group
								valid_spawn_group_distances[spawn_group_id(spawn_group)] = my_dis
							end
						end
					end
				end
			end

			for other_area_id, other_area in pairs(all_areas) do
				if not found_areas[other_area_id] and other_area.neighbours[search_area.id] then
					table.insert(to_search_areas, other_area)

					found_areas[other_area_id] = true
				end
			end
		until #to_search_areas == 0

		if not next(valid_spawn_group_distances) then
			return
		end

		local time = TimerManager:game():time()
		local timer_can_spawn = false

		for id in pairs(valid_spawn_groups) do
			if not self._spawn_group_timers[id] or self._spawn_group_timers[id] <= time then
				timer_can_spawn = true

				break
			end
		end

		if not LIES.settings.spawngroupdelays then
			if not timer_can_spawn then
				self._spawn_group_timers = {}
			end
		end

		for id in pairs(valid_spawn_groups) do
			if self._spawn_group_timers[id] and time < self._spawn_group_timers[id] then
				valid_spawn_groups[id] = nil
				valid_spawn_group_distances[id] = nil
			end
		end

		if total_dis == 0 then
			total_dis = 1
		end

		local total_weight = 0
		local candidate_groups = {}
		self._debug_weights = {}
		local dis_limit = 5000

		for i, dis in pairs(valid_spawn_group_distances) do
			local my_wgt = math.lerp(1, 0.2, math.min(1, dis / dis_limit)) * 5
			local my_spawn_group = valid_spawn_groups[i]
			local my_group_types = my_spawn_group.mission_element:spawn_groups()
			my_spawn_group.distance = dis
			total_weight = total_weight + self:_choose_best_groups(candidate_groups, my_spawn_group, my_group_types, allowed_groups, my_wgt, task_data)
		end

		if total_weight == 0 then
			return
		end

		for _, group in ipairs(candidate_groups) do
			table.insert(self._debug_weights, clone(group))
		end

		return self:_choose_best_group(candidate_groups, total_weight)
	end

	function LIES:_choose_best_groups(best_groups, group, group_types, allowed_groups, my_wgt, task_data)	
		local total_weight = 0
		local group_type_order, group_order_index, wanted_group
		
		if task_data then
			group_type_order = self._group_type_order[task_data].group_types			
			group_order_index = self._group_type_order[task_data].index
			
			self._group_type_order[task_data].index = self._group_type_order[task_data].index + 1
			
			wanted_group = group_type_order[group_order_index]
		end
		
		--log(tostring(wanted_group))
		
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
	
	function LIES:_choose_best_group(best_groups, total_weight)
		local rand_wgt = total_weight * math.random()
		local best_grp, best_grp_type = nil
		
		for i = 1, #best_groups do
			local candidate = best_groups[i]
			
			rand_wgt = rand_wgt - candidate.wght
			
			if rand_wgt <= 0 then
				self._spawn_group_timers[spawn_group_id(candidate.group)] = TimerManager:game():time() + math.random(15, 20)
				
				best_grp = candidate.group
				best_grp_type = candidate.group_type
				best_grp.delay_t = self._t + best_grp.interval

				break
			end
		end

		return best_grp, best_grp_type
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
			local on = item:value() == "on"
			LIES.settings.lua_cover = on

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
		
		MenuCallbackHandler.callback_lies_specialdelay = function(self, item)
			local on = item:value() == "on"
			LIES.settings.specialdelay = on

			LIES:Save()
		end
		
		MenuCallbackHandler.callback_lies_fixed_spawngroups = function(self, item)
			local value = item:value()
			LIES.settings.fixed_spawngroups = value

			LIES:Save()
		end
		
		MenuCallbackHandler.callback_lies_fixed_specialspawncaps = function(self, item)
			local on = item:value() == "on"
			LIES.settings.fixed_specialspawncaps = on

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
		
		MenuCallbackHandler.callback_lies_interruptoncontact = function(self, item)
			local on = item:value() == "on"
			LIES.settings.interruptoncontact = on

			LIES:Save()
		end
		
		MenuCallbackHandler.callback_lies_spawngroupdelays = function(self, item)
			local on = item:value() == "on"
			LIES.settings.spawngroupdelays = on

			LIES:Save()
		end
		
		--called when the menu is closed
		MenuCallbackHandler.callback_lies_close = function(self)
		end

		--load settings from user's mod settings txt
		LIES:Load()
		
		if type(LIES.settings.fixed_spawngroups) ~= "number" then
			log("oh")
			LIES.settings.fixed_spawngroups = 1
			
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
