local temp_vec1 = Vector3()

function GroupAIStateBesiege:_draw_enemy_activity(t)
	self:_draw_enemy_importancies()
	
	local draw_data = self._AI_draw_data
	local brush_area = draw_data.brush_area
	local area_normal = -math.UP
	local logic_name_texts = draw_data.logic_name_texts
	local group_id_texts = draw_data.group_id_texts
	local panel = draw_data.panel
	local camera = managers.viewport:get_current_camera()

	if not camera then
		return
	end

	local ws = draw_data.workspace
	local mid_pos1 = Vector3()
	local mid_pos2 = Vector3()
	local focus_enemy_pen = draw_data.pen_focus_enemy
	local focus_player_brush = draw_data.brush_focus_player
	local suppr_period = 0.4
	local suppr_t = t % suppr_period

	if suppr_t > suppr_period * 0.5 then
		suppr_t = suppr_period - suppr_t
	end

	draw_data.brush_suppressed:set_color(Color(math.lerp(0.2, 0.5, suppr_t), 0.85, 0.9, 0.2))

	for area_id, area in pairs(self._area_data) do
		if table.size(area.police.units) > 0 then
			brush_area:half_sphere(area.pos, 22, area_normal)
		end
	end
	
	local function _f_draw_logic_name(u_key, l_data, draw_color)
		local logic_name_text = logic_name_texts[u_key]
		local text_str = l_data.name

		if l_data.objective then
			text_str = text_str .. ":" .. l_data.objective.type 
			
			if l_data.objective.is_default then
				text_str = text_str .. ":" .. "default"
			end
		end

		if not l_data.group and l_data.team then
			text_str = l_data.team.id .. ":" .. text_str
		end
		
		if l_data.internal_data and l_data.internal_data.attitude then
			text_str = text_str .. ":" .. l_data.internal_data.attitude
		end
		
		if l_data.internal_data then
			local add_str = "..."
			
			if l_data.internal_data.want_to_take_cover then
				add_str = "!!!"
			end
			
			text_str = text_str .. ":" .. add_str
		end

		if logic_name_text then
			logic_name_text:set_text(text_str)
		else
			logic_name_text = panel:text({
				name = "text",
				font_size = 20,
				layer = 1,
				text = text_str,
				font = tweak_data.hud.medium_font,
				color = draw_color
			})
			logic_name_texts[u_key] = logic_name_text
		end

		local my_head_pos = mid_pos1

		mvector3.set(my_head_pos, l_data.unit:movement():m_head_pos())
		mvector3.set_z(my_head_pos, my_head_pos.z + 30)

		local my_head_pos_screen = camera:world_to_screen(my_head_pos)

		if my_head_pos_screen.z > 0 then
			local screen_x = (my_head_pos_screen.x + 1) * 0.5 * RenderSettings.resolution.x
			local screen_y = (my_head_pos_screen.y + 1) * 0.5 * RenderSettings.resolution.y

			logic_name_text:set_x(screen_x)
			logic_name_text:set_y(screen_y)

			if not logic_name_text:visible() then
				logic_name_text:show()
			end
		elseif logic_name_text:visible() then
			logic_name_text:hide()
		end
	end

	-- Lines 2047-2090
	local function _f_draw_obj_pos(unit)
		local brush = nil
		local objective = unit:brain():objective()
		local objective_type = objective and objective.type

		if objective_type == "guard" then
			brush = draw_data.brush_guard
		elseif objective_type == "defend_area" then
			brush = draw_data.brush_defend
		elseif objective_type == "free" or objective_type == "follow" or objective_type == "surrender" then
			brush = draw_data.brush_free
		elseif objective_type == "act" then
			brush = draw_data.brush_act
		else
			brush = draw_data.brush_misc
		end

		local obj_pos = nil

		if objective then
			if objective.pos then
				obj_pos = objective.pos
			elseif objective.follow_unit then
				obj_pos = objective.follow_unit:movement():m_head_pos()

				if objective.follow_unit:base().is_local_player then
					obj_pos = obj_pos + math.UP * -30
				end
			elseif objective.nav_seg then
				obj_pos = managers.navigation._nav_segments[objective.nav_seg].pos
			elseif objective.area then
				obj_pos = objective.area.pos
			end
		end

		if obj_pos then
			local u_pos = unit:movement():m_com()

			brush:cylinder(u_pos, obj_pos, 4, 3)
			brush:sphere(u_pos, 24)
		end

		if unit:brain()._logic_data.is_suppressed then
			mvector3.set(mid_pos1, unit:movement():m_pos())
			mvector3.set_z(mid_pos1, mid_pos1.z + 220)
			draw_data.brush_suppressed:cylinder(unit:movement():m_pos(), mid_pos1, 35)
		end
	end
	
	local draw_groups = true
	local group_center = Vector3()
	
	if draw_groups then
		for group_id, group in pairs(self._groups) do
			local nr_units = 0

			for u_key, u_data in pairs(group.units) do
				nr_units = nr_units + 1

				mvector3.add(group_center, u_data.unit:movement():m_com())
			end

			if nr_units > 0 then
				mvector3.divide(group_center, nr_units)

				local gui_text = group_id_texts[group_id]
				local group_pos_screen = camera:world_to_screen(group_center)
				local text = group.team.id .. ":" .. group_id .. ":" .. group.objective.type
				
				local move_type = ":" .. "none"
				
				if group.objective.tactic then
					move_type = ":" .. group.objective.tactic
				elseif group.objective.blockading then
					move_type = ":" .. "blockading"
				elseif group.objective.moving_in then
					move_type = ":" .. "moving_in"
				elseif group.objective.open_fire then
					move_type = ":" .. "open_fire"
				elseif group.objective.moving_out then
					move_type = ":" .. "moving_out"
				elseif group.in_place_t then
					move_type = ":" .. "in_place" .. ":" .. tostring(self._t - group.in_place_t)
				end
				
				text = text .. move_type
				
				if group_pos_screen.z > 0 then
					if not gui_text then
						gui_text = panel:text({
							name = "text",
							font_size = 24,
							layer = 2,
							text = text,
							font = tweak_data.hud.medium_font,
							color = draw_data.group_id_color
						})
						group_id_texts[group_id] = gui_text
					end

					local screen_x = (group_pos_screen.x + 1) * 0.5 * RenderSettings.resolution.x
					local screen_y = (group_pos_screen.y + 1) * 0.5 * RenderSettings.resolution.y

					gui_text:set_x(screen_x)
					gui_text:set_y(screen_y)

					if not gui_text:visible() then
						gui_text:show()
					end
				elseif gui_text and gui_text:visible() then
					gui_text:hide()
				end

				for u_key, u_data in pairs(group.units) do
					draw_data.pen_group:line(group_center, u_data.unit:movement():m_com())
				end
			end

			mvector3.set_zero(group_center)
		end
	end

	-- Lines 2128-2141
	local function _f_draw_attention_on_player(l_data)
		if l_data.attention_obj then
			local my_head_pos = l_data.unit:movement():m_head_pos()
			local e_pos = l_data.attention_obj.m_head_pos
			local dis = mvector3.distance(my_head_pos, e_pos)

			mvector3.step(mid_pos2, my_head_pos, e_pos, 300)
			mvector3.lerp(mid_pos1, my_head_pos, mid_pos2, t % 0.5)
			mvector3.step(mid_pos2, mid_pos1, e_pos, 50)
			
			if l_data.attention_obj.reaction and l_data.attention_obj.reaction < AIAttentionObject.REACT_AIM then
				draw_data.pen_group:line(mid_pos1, mid_pos2)
			else
				focus_enemy_pen:line(mid_pos1, mid_pos2)
			end

			if l_data.attention_obj.unit:base() and l_data.attention_obj.unit:base().is_local_player then
				if l_data.attention_obj.reaction and l_data.attention_obj.reaction < AIAttentionObject.REACT_AIM then
					draw_data.brush_guard:sphere(my_head_pos, 20)
				else
					focus_player_brush:sphere(my_head_pos, 20)
				end
			end
		end
	end

	local groups = {
		{
			group = self._police,
			color = Color(1, 1, 0, 0)
		},
		{
			group = managers.enemy:all_civilians(),
			color = Color(1, 0.75, 0.75, 0.75)
		},
		{
			group = self._ai_criminals,
			color = Color(1, 0, 1, 0)
		}
	}

	for _, group_data in ipairs(groups) do
		for u_key, u_data in pairs(group_data.group) do
			_f_draw_obj_pos(u_data.unit)

			if camera then
				local l_data = u_data.unit:brain()._logic_data

				_f_draw_logic_name(u_key, l_data, group_data.color)
				_f_draw_attention_on_player(l_data)
			end
		end
	end

	for u_key, gui_text in pairs(logic_name_texts) do
		local keep = nil

		for _, group_data in ipairs(groups) do
			if group_data.group[u_key] then
				keep = true

				break
			end
		end

		if not keep then
			panel:remove(gui_text)

			logic_name_texts[u_key] = nil
		end
	end

	for group_id, gui_text in pairs(group_id_texts) do
		if not self._groups[group_id] then
			panel:remove(gui_text)

			group_id_texts[group_id] = nil
		end
	end
end

function GroupAIStateBesiege:_voice_move_in_start(group)
	for u_key, unit_data in pairs(group.units) do
		local brain = unit_data.unit:brain()
		local current_objective = brain:objective()
		
		if current_objective and current_objective.grp_objective == group.objective and unit_data.char_tweak.chatter.go_go and self:chk_say_enemy_chatter(unit_data.unit, unit_data.m_pos, "go_go") then
			break
		end
	end
end

function GroupAIStateBesiege:_voice_move_complete(group)
	for u_key, unit_data in pairs(group.units) do
		local brain = unit_data.unit:brain()
		local current_objective = brain:objective()
		
		if current_objective and current_objective.grp_objective == group.objective and unit_data.char_tweak.chatter.ready and self:chk_say_enemy_chatter(unit_data.unit, unit_data.m_pos, "ready") then
			break
		end
	end
end

function GroupAIStateBesiege:_voice_deathguard_start(group)
	local time = self._t

	for u_key, unit_data in pairs(group.units) do
		local brain = unit_data.unit:brain()
		local current_objective = brain:objective()
		
		if current_objective and current_objective.grp_objective == group.objective and unit_data.char_tweak.chatter.go_go and self:chk_say_enemy_chatter(unit_data.unit, unit_data.m_pos, "go_go") then
			break
		end
	end
end

function GroupAIStateBesiege:_voice_open_fire_start(group)
	for u_key, unit_data in pairs(group.units) do
		local brain = unit_data.unit:brain()
		local current_objective = brain:objective()
		
		if current_objective and current_objective.grp_objective == group.objective and unit_data.char_tweak.chatter.aggressive and self:chk_say_enemy_chatter(unit_data.unit, unit_data.m_pos, "open_fire") then
			break
		end
	end
end

Hooks:PostHook(GroupAIStateBesiege, "init", "lies_spawngroups", function(self)
	self._escorts = {}
	self._MAX_SIMULTANEOUS_SPAWNS = 2

	if LIES.settings.fixed_spawngroups == 2 or LIES.settings.fixed_spawngroups == 4 then
		self._group_type_order = {
			assault = {group_types = {}, index = 1},
			recon = {group_types = {}, index = 1},
			reenforce = {group_types = {}, index = 1},
			cloaker = {group_types = {}, index = 1}
		}
		
		for group_name, info_table in pairs(self._tweak_data.assault.groups) do
			if tweak_data.group_ai.enemy_spawn_groups[group_name] and info_table[1] > 0 then
				table.insert(self._group_type_order.assault.group_types, tostring(group_name))
			end
		end
		
		for group_name, info_table in pairs(self._tweak_data.recon.groups) do
			if tweak_data.group_ai.enemy_spawn_groups[group_name] and info_table[1] > 0 then
				table.insert(self._group_type_order.recon.group_types, tostring(group_name))
			end
		end
		
		self._group_type_order.assault.index = math.random(table.size(self._group_type_order.assault.group_types))
		self._group_type_order.recon.index = math.random(table.size(self._group_type_order.recon.group_types))
		
		self._choose_best_groups = LIES._choose_best_groups
		self._choose_best_group = LIES._choose_best_group
		self._find_spawn_group_near_area = LIES._find_spawn_group_near_area
		self._upd_assault_task = LIES._upd_assault_task
		self._upd_recon_tasks = LIES._upd_recon_tasks
	elseif LIES.settings.spawngroupdelays then
		self._find_spawn_group_near_area = self._find_spawn_group_near_area_LIESspawngroupdelays
	end
	
	if LIES.settings.fixed_specialspawncaps then
		self._special_unit_types.tank_mini = true
		self._special_unit_types.tank_medic = true
		self._special_unit_types.tank_hw = true
		self._special_unit_types.phalanx_minion = true
	end
	
	if LIES.settings.hhtacs then
		self._calculate_difficulty_ratio = self._calculate_difficulty_ratio_hhtacs
		self._check_phalanx_damage_reduction_increase = self._check_phalanx_damage_reduction_increase_LIES
		self.phalanx_damage_reduction_disable = self.phalanx_damage_reduction_disable_LIES
		self._check_spawn_phalanx = self._check_spawn_phalanx_LIES
		
		--checks for groups that have previously spawned to allow for certain scripted events to be overwritten based on it
		Hooks:PostHook(GroupAIStateBesiege, "_check_spawn_timed_groups", "lieshhtacs_checkspawnedgroups", function(self, target_area, task_data)
			if not self._timed_groups then
				return
			end
			
			local cur_group, cur_group_tweak_data, cur_group_individual_data = nil
			local t = TimerManager:game():time()

			for group_id, cur_group_data in pairs(self._timed_groups) do
				if not cur_group_data.has_spawned then
					cur_group_tweak_data = cur_group_data.tweak_data
					cur_group_individual_data = cur_group_data.individual_data
					
					for i = 1, #cur_group_individual_data do
						cur_group = cur_group_individual_data[i]
						
						if not cur_group.needs_spawn then
							cur_group_data.has_spawned = true
							
							break
						end
					end
				end
			end
		end)
	end
	
	if Network:is_server() then
		Hooks:PostHook(GroupAIStateBesiege, "_perform_group_spawning", "lies_upd_group_early", function(self, spawn_task, force, use_last)
			if spawn_task.group.has_spawned and self._groups[spawn_task.group.id] then
				self:_upd_group(spawn_task.group)
			end
		end)
		
		Hooks:PostHook(GroupAIStateBesiege, "on_criminal_nav_seg_change", "lies_check_relocation_for_friendlies", function(self, unit, nav_seg_id)
			if unit and self._player_criminals[unit:key()] then
				self:_on_player_slow_pos_rsrv_upd(unit)
			end
		end)
		
		local dialogue_data_funcs = {
			flank = "_voice_flank_start",
			push = "_voice_charge_start",
			escort_block = "_voice_block_escort_start",
			move_in = "_voice_move_in_start",
			open_fire = "_voice_open_fire_start"
		}
		
		Hooks:PostHook(GroupAIStateBesiege, "_upd_groups", "lies_group_dialogue", function(self)
			for group_id, group in pairs(self._groups) do
				if group.needs_announce_retreat then
					group.needs_announce_retreat = not self:_voice_retreat(group)
				elseif group.dialogue_data and dialogue_data_funcs[group.dialogue_data] then
					local func = dialogue_data_funcs[group.dialogue_data]
					
					self[func](self, group)
				end
			end
		end)
		
		--self:set_debug_draw_state(true)
	end
end)

function GroupAIStateBesiege:_on_player_slow_pos_rsrv_upd(unit)
	if not alive(unit) then
		return
	end
	
	local p_key = unit:key()
	local minions = self._player_criminals[p_key].minions
	
	for _, u_data in pairs(self._ai_criminals) do
		if alive(u_data.unit) then
			local ai_unit = u_data.unit
			
			if ai_unit:brain() then
				local objective = ai_unit:brain():objective()
				
				if not objective or objective.type == "free" or objective.type == "follow" and objective.follow_unit and alive(objective.follow_unit) and objective.follow_unit:key() == p_key then
					ai_unit:brain():_on_player_slow_pos_rsrv_upd()
				end
			end
		end
	end
	
	if minions then
		for u_key, u_data in pairs(minions) do
			if alive(u_data.unit) then
				local ai_unit = u_data.unit
				
				if ai_unit:brain() then
					local objective = ai_unit:brain():objective()
					
					if not objective or objective.type == "free" or objective.type == "follow" and objective.follow_unit and alive(objective.follow_unit) and objective.follow_unit:key() == p_key then
						ai_unit:brain():_on_player_slow_pos_rsrv_upd()
					end
				end
			end
		end
	end
end

function GroupAIStateBesiege:_register_escort(unit)
	self._escorts = self._escorts or {}
	
	local u_key = unit:key()
	local all_civs = managers.enemy:all_civilians()
	local u_data = all_civs[u_key]
	
	if u_data then
		self._escorts[u_key] = u_data
	end
end

function GroupAIStateBesiege:_unregister_escort(key)
	self._escorts = self._escorts or {}
	self._escorts[key] = nil
end

function GroupAIStateBesiege:_upd_police_activity()
	self._police_upd_task_queued = false

	if self._police_activity_blocked then
		return
	end
	
	if not self._last_upd_t then
		self._last_upd_t = self._t
	end

	if self._ai_enabled then
		self:_upd_SO()
		self:_upd_grp_SO()
		self:_check_spawn_phalanx()
		self:_check_phalanx_group_has_spawned()
		self:_check_phalanx_damage_reduction_increase()

		if self._enemy_weapons_hot then
			
			--in vanilla, if a group gets partially spawned in one update,
			--the next update might result in groupai not adding a new group to spawn 
			--until after that update because the group spawning gets updated late
			--kind of a picky thing to get hung up on but it kinda bothers me so i fixed it here
			local updated_group_spawning = nil
			
			if next(self._spawning_groups) then
				self:_upd_group_spawning()
				
				updated_group_spawning = true
			end
			
			self:_claculate_drama_value()
			self:_update_criminal_reveal()
			self:_upd_regroup_task()
			self:_upd_reenforce_tasks()
			self:_upd_recon_tasks()
			self:_upd_assault_task()
			self:_begin_new_tasks()
			
			if not updated_group_spawning then
				self:_upd_group_spawning()
			end
			
			self:_upd_groups()
		end
		
		self._last_upd_t = self._t
	end

	self:_queue_police_upd_task()
end

function GroupAIStateBesiege:_update_criminal_reveal()
	if not self._disabled_security_cameras then
		self._disabled_security_cameras = {}
		
		if SecurityCamera and SecurityCamera.cameras then
			for i = 1, #SecurityCamera.cameras do
				local unit = SecurityCamera.cameras[i]
				
				if unit and alive(unit) then
					self._disabled_security_cameras[unit:key()] = unit
				end
			end
		end
	end
	
	
	for camera_key, camera in pairs(self._disabled_security_cameras) do
		if camera and alive(camera) and not camera:base()._destroyed then
			camera:base():_detect_criminals_loud(self._t, self._char_criminals)
		else
			self._disabled_security_cameras[camera_key] = nil
		end
	end
end

function GroupAIStateBesiege:force_spawn_group(group, group_types, guarantee)
	local best_groups = {}
	local total_weight = self:_choose_best_groups(best_groups, group, group_types, self._tweak_data[self._task_data.assault.active and "assault" or "recon"].groups, 1)

	if total_weight > 0 or guarantee then
		local spawn_group, spawn_group_type = self:_choose_best_group(best_groups, total_weight or 1)

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

			self:_spawn_in_group(spawn_group, spawn_group_type, grp_objective)
			self:_upd_group_spawning(true)
			
			return true
		end
	end
end

function GroupAIStateBesiege:_verify_group_objective(group)
	local is_objective_broken = nil
	local grp_objective = group.objective
	local coarse_path = grp_objective.coarse_path
	local nav_segments = managers.navigation._nav_segments

	if coarse_path then
		for i_node, node in ipairs(coarse_path) do
			local nav_seg_id = node[1]

			if nav_segments[nav_seg_id].disabled then
				is_objective_broken = true

				break
			end
		end
	end
	
	if grp_objective.follow_unit and not alive(grp_objective.follow_unit) then
		is_objective_broken = true
	end

	if not is_objective_broken then
		return
	end

	local new_area = nil
	local tested_nav_seg_ids = {}

	for u_key, u_data in pairs(group.units) do
		u_data.tracker:move(u_data.m_pos)

		local nav_seg_id = u_data.tracker:nav_segment()

		if not tested_nav_seg_ids[nav_seg_id] then
			tested_nav_seg_ids[nav_seg_id] = true
			local areas = self:get_areas_from_nav_seg_id(nav_seg_id)

			for _, test_area in pairs(areas) do
				for test_nav_seg, _ in pairs(test_area.nav_segs) do
					if not nav_segments[test_nav_seg].disabled then
						new_area = test_area

						break
					end
				end

				if new_area then
					break
				end
			end
		end

		if new_area then
			break
		end
	end

	if not new_area then
		print("[GroupAIStateBesiege:_verify_group_objective] could not find replacement area to", grp_objective.area)

		return
	end

	group.objective = {
		moving_out = false,
		type = grp_objective.type,
		area = new_area
	}
end

function GroupAIStateBesiege:assign_enemy_to_group_ai(unit, team_id)
	local u_tracker = unit:movement():nav_tracker()
	local seg = u_tracker:nav_segment()
	local area = self:get_area_from_nav_seg_id(seg)
	local current_unit_type = tweak_data.levels:get_ai_group_type()
	local u_name = unit:name()

	local group_desc = {
		size = 1,
		type = "custom"
	}
	local group = self:_create_group(group_desc)
	group.team = self._teams[team_id]
	local grp_objective = nil
	local objective = unit:brain():objective()
	local grp_obj_type = self._task_data.assault.active and "assault_area" or "recon_area"

	if objective then
		grp_objective = {
			type = grp_obj_type,
			area = objective.area or objective.nav_seg and self:get_area_from_nav_seg_id(objective.nav_seg) or area
		}
		objective.grp_objective = grp_objective
	else
		grp_objective = {
			type = grp_obj_type,
			area = area
		}
	end

	grp_objective.moving_out = false
	group.objective = grp_objective
	group.has_spawned = true

	self:_add_group_member(group, unit:key())
	self:set_enemy_assigned(area, unit:key())
end

function GroupAIStateBesiege:_check_spawn_phalanx_LIES()
	if self._phalanx_center_pos and self._task_data and self._task_data.assault.active and not self._phalanx_spawn_group and (self._task_data.assault.phase == "build" or self._task_data.assault.phase == "sustain") then
		local now = TimerManager:game():time()
		local respawn_delay = tweak_data.group_ai.phalanx.spawn_chance.respawn_delay

		if not self._phalanx_despawn_time or now >= self._phalanx_despawn_time + respawn_delay then
			local spawn_chance_start = tweak_data.group_ai.phalanx.spawn_chance.start
			self._phalanx_current_spawn_chance = self._phalanx_current_spawn_chance or spawn_chance_start
			self._phalanx_last_spawn_check = self._phalanx_last_spawn_check or now
			self._phalanx_last_chance_increase = self._phalanx_last_chance_increase or now
			local spawn_chance_increase = tweak_data.group_ai.phalanx.spawn_chance.increase
			local spawn_chance_max = tweak_data.group_ai.phalanx.spawn_chance.max

			if self._phalanx_current_spawn_chance < spawn_chance_max and spawn_chance_increase > 0 then
				local chance_increase_intervall = tweak_data.group_ai.phalanx.chance_increase_intervall

				if now >= self._phalanx_last_chance_increase + chance_increase_intervall then
					self._phalanx_last_chance_increase = now
					self._phalanx_current_spawn_chance = math.min(spawn_chance_max, self._phalanx_current_spawn_chance + spawn_chance_increase)
				end
			end

			if self._phalanx_current_spawn_chance > 0 then
				local check_spawn_intervall = tweak_data.group_ai.phalanx.check_spawn_intervall

				if now >= self._phalanx_last_spawn_check + check_spawn_intervall then
					self._phalanx_last_spawn_check = now

					if math.random() <= self._phalanx_current_spawn_chance then
						self:_spawn_phalanx()
					end
				end
			end
		end
	end
end

function GroupAIStateBesiege:_check_phalanx_damage_reduction_increase_LIES()
	local law1team = self:_get_law1_team()
	local damage_reduction_max = tweak_data.group_ai.phalanx.vip.damage_reduction.max
	local damage_reduction = law1team.damage_reduction
	
	if damage_reduction then
		if damage_reduction < damage_reduction_max then
			local now = TimerManager:game():time()
			local increase_intervall = tweak_data.group_ai.phalanx.vip.damage_reduction.increase_intervall
			local last_increase = self._phalanx_damage_reduction_last_increase

			if now > last_increase + increase_intervall then
				last_increase = now
				local dmg_reduct = math.min(damage_reduction_max, damage_reduction + tweak_data.group_ai.phalanx.vip.damage_reduction.increase)

				self:set_phalanx_damage_reduction_buff(dmg_reduct)

				self._phalanx_damage_reduction_last_increase = last_increase

				if alive(self:phalanx_vip()) then
					self:phalanx_vip():sound():say("cpw_a05", true, true)
				end
			end
		end
		
		local group = self._phalanx_spawn_group
		
		if not group then
			self:phalanx_damage_reduction_disable()
			
			return
		end

		if group.set_to_phalanx_group_obj then
			if not self._phalanx_center_pos_old then
				self._phalanx_center_pos_old = mvector3.copy(self._phalanx_center_pos)
			end	

			if group.objective.moving_out then
				local done_moving = nil
				
				if not done_moving then
					for u_key, u_data in pairs(group.units) do
						local objective = u_data.unit:brain():objective()

						if objective then
							if objective.grp_objective ~= group.objective then
								-- Nothing
							elseif not objective.in_place then
								done_moving = false
							elseif done_moving == nil then
								done_moving = true
							end
						end
					end
				end

				if done_moving == true then
					group.objective.moving_out = nil
					group.objective.repositioned_shields = nil
					group.in_place_t = self._t
				end
			end
			
			if not group.objective.moving_out then
				self:_set_objective_to_phalanx_group_LIES(group)
			end
		end
	end
end

function GroupAIStateBesiege:phalanx_damage_reduction_disable_LIES()
	self:set_phalanx_damage_reduction_buff(-1)

	self._phalanx_damage_reduction_last_increase = nil
	self._phalanx_center_pos = self._phalanx_center_pos_old and mvector3.copy(self._phalanx_center_pos_old) or self._phalanx_center_pos
end

function GroupAIStateBesiege:_set_objective_to_phalanx_group_LIES(group)
	local aggression_level = LIES.settings.enemy_aggro_level

	if group.in_place_t and self._t - group.in_place_t < tweak_data.group_ai.phalanx.move_interval then
		if not group.objective.repositioned_shields then
			CopLogicPhalanxMinion:chk_should_reposition()
			group.objective.repositioned_shields = true
		end
		
		return
	end

	if self._task_data.assault and self._task_data.assault.target_areas[1] then
		group.has_set_target = self.get_nav_seg_id_from_area(self._task_data.assault.target_areas[1])

		if group.has_set_target then
			local m_nav_seg = group.objective.nav_seg
			local target_seg = group.has_set_target
			
			local params = {
				from_seg = m_nav_seg,
				to_seg = target_seg,
				access = {
					"walk"
				},
				id = "GroupAI_LIESPHALANX",
				access_pos = "shield"
			}

			local path = managers.navigation:search_coarse(params)
				
			if path then
				local next_seg_i = 2		
				local next_seg = path[next_seg_i][1]
				local area = self:get_area_from_nav_seg_id(next_seg)
				self._phalanx_center_pos = mvector3.copy(area.pos)
				
				local grp_objective = {
					type = "create_phalanx",
					area = area,
					nav_seg = next_seg,
					pos = self._phalanx_center_pos,
					haste = "walk"
				}

				self:_set_objective_to_enemy_group(group, grp_objective)
				
				self:_verify_group_objective(group)
				
				for u_key, u_data in pairs(group.units) do
					local brain = u_data.unit:brain()
					local current_objective = brain:objective()

					if (not current_objective or current_objective.is_default or current_objective.grp_objective and current_objective.grp_objective ~= group.objective and not current_objective.grp_objective.no_retry) and (not group.objective.follow_unit or alive(group.objective.follow_unit)) then
						local objective = self._create_objective_from_group_objective(group.objective, u_data.unit)

						if objective and brain:is_available_for_assignment(objective) then
							self:set_enemy_assigned(objective.area or group.objective.area, u_key)

							if objective.element then
								objective.element:clbk_objective_administered(u_data.unit)
							end

							u_data.unit:brain():set_objective(objective)
						end
					end
				end
				
				CopLogicPhalanxMinion._reposition_phalanx(nil)
			end
			
			
		end
	end
end

function GroupAIStateBesiege:_get_special_unit_type_count(special_type)
	if not self._special_units[special_type] then
		return 0
	end
	
	if special_type == "tank" then
		local tanks = table.size(self._special_units[special_type])

		if self._special_units["tank_mini"] then
			tanks = tanks + table.size(self._special_units["tank_mini"])
		end

		if self._special_units["tank_medic"] then
			tanks = tanks + table.size(self._special_units["tank_medic"])
		end
		
		if self._special_units["tank_hw"] then
			tanks = tanks + table.size(self._special_units["tank_hw"])
		end

		return tanks
	elseif special_type == "medic" then
		local medics = table.size(self._special_units[special_type])
		
		if self._special_units["tank_medic"] then
			medics = medics + table.size(self._special_units["tank_medic"])
		end
		
		return medics
	elseif special_type == "shield" then
		local shields = table.size(self._special_units[special_type])
		
		if self._special_units["phalanx_minion"] then
			shields = shields + table.size(self._special_units["phalanx_minion"])
		end
		
		return shields
	else
		return table.size(self._special_units[special_type])
	end
end

Hooks:PostHook(GroupAIStateBesiege, "_upd_assault_task", "lies_retire", function(self)
	local copsretire = LIES.settings.copsretire
	
	if not self._last_upd_t then
		self._last_upd_t = self._t
	end
	
	local task_data = self._task_data.assault

	if task_data and task_data.target_areas and task_data.target_areas[1] then
		if not task_data.old_target_pos then
			local target_pos
			
			local target_pos = task_data.target_areas[1].pos
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
				task_data.old_target_pos = mvector3.copy(nearest_pos)
				task_data.old_target_pos_t = 0
			end
		else		
			local target_pos = task_data.old_target_pos
			local nearest_pos, nearest_dis, best_z = nil

			for criminal_key, criminal_data in pairs(self._player_criminals) do
				if not criminal_data.status or criminal_data.status == "electrified" then
					local dis = mvector3.distance(target_pos, criminal_data.m_pos)
					local z_dis = math.abs(criminal_data.m_pos.z - target_pos.z)
					
					if not best_z or best_z <= 250 and z_dis <= 250 or z_dis < best_z then
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
	end
	
	if not copsretire then		
		return
	end
	
	if copsretire then
		if self._hunt_mode then
		
		elseif not task_data or not task_data.active then
			self:_assign_assault_groups_to_retire()
		elseif task_data.phase == "fade" then
			self:_assign_assault_groups_to_retire()
		elseif task_data.said_retreat then
			self:_assign_assault_groups_to_retire()
		end
	end
end)

function GroupAIStateBesiege:_upd_regroup_task()
	local regroup_task = self._task_data.regroup

	if regroup_task.active then
		self:_assign_assault_groups_to_retire()

		if regroup_task.end_t < self._t or not LIES.settings.copsretire and self._drama_data.zone == "low" then
			self:_end_regroup_task()
		end
	end
end

function GroupAIStateBesiege:_queue_police_upd_task()
	--log("a")
	if not self._police_upd_task_queued then
		self._police_upd_task_queued = true
		
		if Network:is_server() then --essentially, if theres less players, more important enemies are allowed instead of just 3
			if not Global.game_settings.single_player then
				local new_value = 12 / table.size(self:all_player_criminals()) 

				self._nr_important_cops = new_value
			end
		end
		
		--moving this to a delayed callback makes sure it not take up space in the enemy manager tasks
		managers.enemy:add_delayed_clbk("GroupAIStateBesiege._upd_police_activity", callback(self, self, "_upd_police_activity"), self._t + 1)
	end
end

function GroupAIStateBesiege:force_end_assault_phase(force_regroup)
	local task_data = self._task_data.assault

	if task_data.active then
		task_data.phase = "fade"
		task_data.force_end = true

		if force_regroup then
			task_data.force_regroup = true

			managers.enemy:reschedule_delayed_clbk(GroupAIStateBesiege._upd_police_activity, self._t)
		end
	end

	self:set_assault_endless(false)
end

function GroupAIStateBesiege:_upd_hostage_task()
	self._hostage_upd_key = nil
	local hos_data = self._hostage_data
	local first_entry = self._hostage_data[1]
	
	if first_entry then
		first_entry.clbk()
	end

	table.remove(self._hostage_data, 1)

	if not self._hostage_upd_key and #hos_data > 0 then
		self._hostage_upd_key = "GroupAIStateBesiege:_upd_hostage_task"

		managers.enemy:add_delayed_clbk(self._hostage_upd_key, callback(self, self, "_upd_hostage_task"), self._t + 1)
	end
end

function GroupAIStateBesiege:add_to_surrendered(unit, update)
	local hos_data = self._hostage_data
	local nr_entries = #hos_data
	local entry = {
		u_key = unit:key(),
		clbk = update
	}

	if not self._hostage_upd_key then
		self._hostage_upd_key = "GroupAIStateBesiege:_upd_hostage_task"

		managers.enemy:add_delayed_clbk(self._hostage_upd_key, callback(self, self, "_upd_hostage_task"), self._t + 1)
	end

	table.insert(hos_data, entry)
end

function GroupAIStateBesiege:remove_from_surrendered(unit)
	local hos_data = self._hostage_data
	local u_key = unit:key()

	for i, entry in ipairs(hos_data) do
		if u_key == entry.u_key then
			table.remove(hos_data, i)

			break
		end
	end

	if #hos_data == 0 then
		managers.enemy:remove_delayed_clbk(self._hostage_upd_key)

		self._hostage_upd_key = nil
	end
end


function GroupAIStateBesiege:_voice_flank_start(group)
	for u_key, unit_data in pairs(group.units) do
		local brain = unit_data.unit:brain()
		local current_objective = brain:objective()
		
		if current_objective and current_objective.grp_objective == group.objective and unit_data.char_tweak.chatter.go_go and self:chk_say_enemy_chatter(unit_data.unit, unit_data.m_pos, "flank") then
			break
		end
	end
end

function GroupAIStateBesiege:_voice_retreat(group)
	for u_key, unit_data in pairs(group.units) do
		local brain = unit_data.unit:brain()
		local current_objective = brain:objective()
		
		if current_objective and current_objective.grp_objective == group.objective and unit_data.char_tweak.chatter.go_go and self:chk_say_enemy_chatter(unit_data.unit, unit_data.m_pos, "retreat") then
			return true
		end
	end
end

function GroupAIStateBesiege:_voice_charge_start(group)
	for u_key, unit_data in pairs(group.units) do
		local brain = unit_data.unit:brain()
		local current_objective = brain:objective()
		
		if current_objective and current_objective.grp_objective == group.objective and unit_data.char_tweak.chatter.go_go and self:chk_say_enemy_chatter(unit_data.unit, unit_data.m_pos, "push") then
			break
		end
	end
end

function GroupAIStateBesiege:_voice_follow_me(group)
	for u_key, unit_data in pairs(group.units) do
		local brain = unit_data.unit:brain()
		local current_objective = brain:objective()
		
		if current_objective and current_objective.grp_objective == group.objective and unit_data.char_tweak.chatter.ready and self:chk_say_enemy_chatter(unit_data.unit, unit_data.m_pos, "follow_me") then
			break
		end
	end
end

function GroupAIStateBesiege:_voice_block_escort_start(group)
	for u_key, unit_data in pairs(group.units) do
		local brain = unit_data.unit:brain()
		local current_objective = brain:objective()
		
		if current_objective and current_objective.grp_objective == group.objective and unit_data.char_tweak.chatter.ready and self:chk_say_enemy_chatter(unit_data.unit, unit_data.m_pos, "block_escort") then
			break
		end
	end
end

function GroupAIStateBesiege:_voice_getcivs(group)
	for u_key, unit_data in pairs(group.units) do
		local brain = unit_data.unit:brain()
		local current_objective = brain:objective()
		
		if current_objective and current_objective.grp_objective == group.objective and unit_data.char_tweak.chatter.suppress and self:chk_say_enemy_chatter(unit_data.unit, unit_data.m_pos, "getcivs") then
			break
		end
	end
end

function GroupAIStateBesiege:_voice_gatherloot(group)
	for u_key, unit_data in pairs(group.units) do
		local brain = unit_data.unit:brain()
		local current_objective = brain:objective()
		
		if current_objective and current_objective.grp_objective == group.objective and unit_data.char_tweak.chatter.suppress and self:chk_say_enemy_chatter(unit_data.unit, unit_data.m_pos, "gatherloot") then
			break
		end
	end
end

function GroupAIStateBesiege:_voice_movedin_civs(group)
	for u_key, unit_data in pairs(group.units) do
		local brain = unit_data.unit:brain()
		local current_objective = brain:objective()
		
		if current_objective and current_objective.grp_objective == group.objective and unit_data.char_tweak.chatter.suppress and self:chk_say_enemy_chatter(unit_data.unit, unit_data.m_pos, "movedin_civs") then
			break
		end
	end
end

function GroupAIStateBesiege:_assign_assault_groups_to_retire()
	if LIES.settings.copsretire then
		local function suitable_grp_func(group)
			if group.objective.type == "assault_area" then
				self:_assign_group_to_retire(group)
				
				group.dialogue_data = nil
				
				group.needs_announce_retreat = not self:_voice_retreat(group)
			end
		end
		
		self:_assign_groups_to_retire(self._tweak_data.recon.groups, suitable_grp_func)
	else
		local function suitable_grp_func(group)
			if group.objective.type == "assault_area" then
				local regroup_area = nil

				if next(group.objective.area.criminal.units) then
					for other_area_id, other_area in pairs(group.objective.area.neighbours) do
						if not next(other_area.criminal.units) then
							regroup_area = other_area

							break
						end
					end
				end

				regroup_area = regroup_area or group.objective.area
				local grp_objective = {
					stance = "hos",
					attitude = "avoid",
					pose = "crouch",
					type = "recon_area",
					area = regroup_area
				}

				self:_set_objective_to_enemy_group(group, grp_objective)
				group.dialogue_data = nil
				
				group.needs_announce_retreat = not self:_voice_retreat(group)
			end
		end

		self:_assign_groups_to_retire(self._tweak_data.recon.groups, suitable_grp_func)
	end
end

function GroupAIStateBesiege:on_objective_complete(unit, objective)
	local new_objective, so_element = nil

	if objective.followup_objective then
		if not objective.followup_objective.trigger_on then
			new_objective = objective.followup_objective
		else
			new_objective = {
				is_default = objective.is_default,
				scan = objective.scan,
				type = "free",
				no_arrest = objective.no_arrest,
				grp_objective = objective.grp_objective,
				attitude = objective.attitude or objective.grp_objective and objective.grp_objective.attitude,
				followup_objective = objective.followup_objective,
				interrupt_dis = objective.interrupt_dis,
				interrupt_health = objective.interrupt_health
			}
		end
	elseif objective.followup_SO then
		local current_SO_element = objective.followup_SO
		so_element = current_SO_element:choose_followup_SO(unit)
		new_objective = so_element and so_element:get_objective(unit)
	end

	if new_objective then
		if new_objective.nav_seg then
			local u_key = unit:key()
			local u_data = self._police[u_key]

			if u_data and u_data.assigned_area then
				self:set_enemy_assigned(self._area_data[new_objective.nav_seg], u_key)
			end
		end
	else
		local seg = unit:movement():nav_tracker():nav_segment()
		local area_data = self:get_area_from_nav_seg_id(seg)

		if self:rescue_state() and tweak_data.character[unit:base()._tweak_table].rescue_hostages then
			for u_key, u_data in pairs(managers.enemy:all_civilians()) do
				if seg == u_data.tracker:nav_segment() then
					local so_id = u_data.unit:brain():wants_rescue()

					if so_id then
						local so = self._special_objectives[so_id]
						local so_data = so.data
						local so_objective = so_data.objective
						new_objective = self.clone_objective(so_objective)

						if so_data.admin_clbk then
							so_data.admin_clbk(unit)
						end

						self:remove_special_objective(so_id)

						break
					end
				end
			end
		end

		if not new_objective and objective.type == "free" then
			new_objective = {
				is_default = true,
				scan = true,
				type = "free",
				no_arrest = objective.no_arrest,
				grp_objective = objective.grp_objective,
				attitude = objective.attitude or objective.grp_objective and objective.grp_objective.attitude
			}
		end

		if not area_data.is_safe then
			area_data.is_safe = true

			self:_on_nav_seg_safety_status(seg, {
				reason = "guard",
				unit = unit
			})
		end
	end

	objective.fail_clbk = nil

	unit:brain():set_objective(new_objective)
	
	local u_key = unit:key()
	local u_data = self._police[u_key]

	if objective.complete_clbk then
		objective.complete_clbk(unit)
	end

	if so_element then
		so_element:clbk_objective_administered(unit)
	end
end

function GroupAIStateBesiege:on_defend_travel_end(unit, objective)
	local seg = objective.nav_seg
	local area = self:get_area_from_nav_seg_id(seg)

	if not area.is_safe then
		area.is_safe = true

		self:_on_area_safety_status(area, {
			reason = "guard",
			unit = unit
		})
	end
	
	local u_key = unit:key()
	local unit_data = self._police[u_key]
	
	if unit_data then
		if unit_data.char_tweak.chatter.ready then
			self:chk_say_enemy_chatter(unit_data.unit, unit_data.m_pos, "in_pos")
		end
	end
end

local group_upd_funcs = {
	assault_area = "_assign_enemy_group_to_assault",
	recon_area = "_assign_enemy_group_to_recon",
	reenforce_area = "_assign_enemy_group_to_reenforce"
}

function GroupAIStateBesiege:_upd_group(group)
	if not group or not group.has_spawned then
		return
	end
	
	if group.objective.type and group_upd_funcs[group.objective.type] then
		local func = group_upd_funcs[group.objective.type]
		
		self[func](self, group)
		
		self:_verify_group_objective(group)
		
		for u_key, u_data in pairs(group.units) do
			local brain = u_data.unit:brain()
			local current_objective = brain:objective()

			if (not current_objective or current_objective.is_default or current_objective.grp_objective and current_objective.grp_objective ~= group.objective and not current_objective.grp_objective.no_retry) and (not group.objective.follow_unit or alive(group.objective.follow_unit)) then
				local objective = self._create_objective_from_group_objective(group.objective, u_data.unit)

				if objective and brain:is_available_for_assignment(objective) then
					self:set_enemy_assigned(objective.area or group.objective.area, u_key)

					if objective.element then
						objective.element:clbk_objective_administered(u_data.unit)
					end

					u_data.unit:brain():set_objective(objective)
				end
			end
		end
	end
end

function GroupAIStateBesiege:_assign_enemy_group_to_assault(group)
	local task_data = self._task_data.assault
	local phase = task_data and task_data.phase
	
	if not phase then
		return
	end

	if group.has_spawned and group.objective.type == "assault_area" then
		if group.objective.moving_out then
			local done_moving = nil

			for u_key, u_data in pairs(group.units) do
				local objective = u_data.unit:brain():objective()

				if objective then
					if objective.grp_objective ~= group.objective then
						-- Nothing
					elseif not objective.in_place then
						done_moving = false
					elseif done_moving == nil then
						done_moving = true
					end
				end
			end

			if done_moving == true then
				group.objective.moving_out = nil
				group.in_place_t = self._t
				group.objective.moving_in = nil

				self:_voice_move_complete(group)
			end
		else
			group.objective.moving_in = nil
		end

		if not group.objective.moving_in then
			self:_set_assault_objective_to_group(group, phase)
		end
	end
end

function GroupAIStateBesiege:_assign_enemy_group_to_recon_sweep(group)
	local task_data = self._task_data.recon.sweep_task

	if group.has_spawned and group.objective.type == "recon_area" then
		if group.objective.moving_out then
			local done_moving = nil

			for u_key, u_data in pairs(group.units) do
				local objective = u_data.unit:brain():objective()

				if objective then
					if objective.grp_objective ~= group.objective then
						-- Nothing
					elseif not objective.in_place then
						done_moving = false
					elseif done_moving == nil then
						done_moving = true
					end
				end
			end

			if done_moving == true then
				task_data.visited_areas[group.objective.area.id] = true

				group.objective.moving_out = nil
				group.in_place_t = self._t
				group.objective.moving_in = nil
			end
		end

		if not group.objective.moving_out then
			self:_set_recon_sweep_objective_to_group(group)
		end
	end
end

function GroupAIStateBesiege:_assign_enemy_group_to_recon(group)
	if self._task_data.recon.sweep_task then
		self:_assign_enemy_group_to_recon_sweep(group)
		
		return
	end

	if group.has_spawned and group.objective.type == "recon_area" then
		if group.objective.moving_out then
			local done_moving = nil

			for u_key, u_data in pairs(group.units) do
				local objective = u_data.unit:brain():objective()

				if objective then
					if objective.grp_objective ~= group.objective then
						-- Nothing
					elseif not objective.in_place then
						done_moving = false
					elseif done_moving == nil then
						done_moving = true
					end
				end
			end

			if done_moving == true then
				if group.objective.moved_in then
					group.visited_areas = group.visited_areas or {}
					group.visited_areas[group.objective.area] = true
					
					if group.objective.area.hostages then
						self:_voice_movedin_civs(group)
					end
				end

				group.objective.moving_out = nil
				group.in_place_t = self._t
				group.objective.moving_in = nil

				self:_voice_move_complete(group)
			end
		end

		if not group.objective.moving_in then
			self:_set_recon_objective_to_group(group)
		end
	end
end

function GroupAIStateBesiege:_assign_enemy_group_to_reenforce(group)
	if group.has_spawned and group.objective.type == "reenforce_area" then
		local locked_up_in_area = nil

		if group.objective.moving_out then
			local done_moving = true

			for u_key, u_data in pairs(group.units) do
				local objective = u_data.unit:brain():objective()

				if not objective or objective.is_default or objective.grp_objective and objective.grp_objective ~= group.objective then
					if objective then
						if objective.area then
							locked_up_in_area = objective.area
						elseif objective.nav_seg then
							locked_up_in_area = self:get_area_from_nav_seg_id(objective.nav_seg)
						else
							locked_up_in_area = self:get_area_from_nav_seg_id(u_data.tracker:nav_segment())
						end
					else
						locked_up_in_area = self:get_area_from_nav_seg_id(u_data.tracker:nav_segment())
					end
				elseif not objective.in_place then
					done_moving = false
				end
			end

			if done_moving then
				group.objective.moving_out = nil
				group.in_place_t = self._t
				group.objective.moving_in = nil

				self:_voice_move_complete(group)
			end
		end

		if not group.objective.moving_in then
			if locked_up_in_area and locked_up_in_area ~= group.objective.area then
				-- Nothing
			elseif not group.objective.moving_out then
				self:_set_reenforce_objective_to_group(group)
			end
		end
	end
end

function GroupAIStateBesiege._create_objective_from_group_objective(grp_objective, receiving_unit)
	local objective = {
		grp_objective = grp_objective
	}

	if grp_objective.element then
		objective = grp_objective.element:get_random_SO(receiving_unit)

		if not objective then
			return
		end

		objective.grp_objective = grp_objective

		return
	elseif grp_objective.type == "defend_area" or grp_objective.type == "recon_area" or grp_objective.type == "reenforce_area" then
		objective.type = "defend_area"
		objective.stance = "hos"
		objective.pose = "crouch"
		objective.scan = true
		objective.interrupt_dis = 200
	elseif grp_objective.type == "retire" then
		objective.type = "defend_area"
		objective.stance = "hos"
		objective.pose = "stand"
		objective.scan = true
		objective.interrupt_dis = 200
		objective.no_arrest = true
	elseif grp_objective.type == "assault_area" then
		objective.type = "defend_area"

		if grp_objective.follow_unit then
			objective.type = "follow"
			objective.follow_unit = grp_objective.follow_unit
			objective.distance = grp_objective.distance
		end
		
		
		objective.no_arrest = true
		objective.stance = "hos"
		objective.pose = "stand"
		objective.scan = true
	elseif grp_objective.type == "create_phalanx" then
		objective.type = "phalanx"
		objective.stance = "hos"
		objective.interrupt_dis = nil
		objective.interrupt_health = nil
		objective.interrupt_suppression = nil
		objective.attitude = "avoid"
		objective.path_ahead = true
		
		objective.no_arrest = true
	elseif grp_objective.type == "hunt" then
		objective.type = "hunt"
		objective.stance = "hos"
		objective.scan = true
		objective.interrupt_dis = 200
	end

	objective.stance = grp_objective.stance or objective.stance
	objective.pose = grp_objective.pose or objective.pose
	objective.area = grp_objective.area
	objective.nav_seg = grp_objective.nav_seg or objective.area.pos_nav_seg
	objective.attitude = grp_objective.attitude or objective.attitude
	objective.interrupt_on_contact = grp_objective.interrupt_on_contact
	
	if not objective.no_arrest then
		if objective.attitude == "engage" then
			objective.no_arrest = true
		end
	end
	
	objective.interrupt_dis = grp_objective.interrupt_dis or objective.interrupt_dis
	objective.interrupt_health = grp_objective.interrupt_health or objective.interrupt_health
	objective.interrupt_suppression = grp_objective.interrupt_suppression or objective.interrupt_suppression
	objective.pos = grp_objective.pos

	if grp_objective.scan ~= nil then
		objective.scan = grp_objective.scan
	end

	if grp_objective.coarse_path then
		objective.path_style = "coarse_complete"
		objective.path_data = grp_objective.coarse_path
	end

	return objective
end

function GroupAIStateBesiege:_chk_crimin_proximity_to_unit(unit)
	if not alive(unit) or not unit:movement() then
		return 4
	end

	local u_key = unit:key()
	local pos = unit:movement():m_pos()
	local nearby = 0
	local mvec3_dis = mvector3.distance_sq
	
	for c_key, c_data in pairs(self._char_criminals) do
		if c_key ~= u_key then
			if not c_data.status or c_data.status == "electrified" then
				if mvec3_dis(pos, c_data.unit:movement():m_pos()) < 2500000 then
					nearby = nearby + 1
				end
			end
		end
	end
	
	return nearby
end

function GroupAIStateBesiege:_get_group_forwardmost_unit(group)
	local coarse_path = group.objective.coarse_path
	local forwardmost_i_nav_point = #coarse_path

	while forwardmost_i_nav_point > 0 do
		local nav_seg = coarse_path[forwardmost_i_nav_point][1]
		local area = self:get_area_from_nav_seg_id(nav_seg)

		for u_key, u_data in pairs(group.units) do
			if area.nav_segs[u_data.unit:movement():nav_tracker():nav_segment()] then
				return u_data
			end
		end

		forwardmost_i_nav_point = forwardmost_i_nav_point - 1
	end
end

function GroupAIStateBesiege:_get_group_area(group)
	local best_distance, best_area 

	for u_key, u_data in pairs(group.units) do 
		if u_data.unit and alive(u_data.unit) then
			local nav_seg = managers.navigation:get_nav_seg_from_pos(u_data.unit:movement():m_pos())
			local my_dis = mvector3.distance_sq(u_data.unit:movement():m_pos(), group.objective.area.pos)
			local mine_is_better = not best_distance or my_dis < best_distance

			if mine_is_better then
				local my_area = self:get_area_from_nav_seg_id(nav_seg)
					
				best_distance = my_dis
				best_area = my_area
			end
		end
	end
	
	return best_area
end

function GroupAIStateBesiege:_chk_group_engaging_area(group, dis_to_check, provide_support, impatient)
	dis_to_check = dis_to_check * dis_to_check
	
	local old_engaging_area = group.objective.old_engaging_area or nil
	local best_dis, best_u_area
	
	for u_key, u_data in pairs(group.units) do
		if u_data.unit and alive(u_data.unit) then
			local brain = u_data.unit:brain()
			local objective = brain:objective()

			if objective and objective.grp_objective == group.objective and group.objective.area  then
				local dis = mvector3.distance_sq(group.objective.area.pos, u_data.m_pos)
				
				if not best_dis or dis < best_dis then
					best_dis = dis
					
					local nav_seg = managers.navigation:get_nav_seg_from_pos(u_data.m_pos, true)
					local area = self:get_area_from_nav_seg_id(nav_seg)
					best_u_area = area
				end
			end
		end
	end
	
	if best_u_area then
		for u_key, u_data in pairs(group.units) do
			if u_data.unit and alive(u_data.unit) then
				local brain = u_data.unit:brain()
				local objective = brain:objective()
				local logic_data = brain._logic_data
		
				if objective and objective.grp_objective == group.objective and logic_data then
					local focus_enemy = logic_data.attention_obj
					
					if focus_enemy and focus_enemy.verified_t and logic_data.t - focus_enemy.verified_t <= 15 and focus_enemy.last_verified_m_pos and AIAttentionObject.REACT_COMBAT <= focus_enemy.reaction then
						if mvector3.distance_sq(focus_enemy.m_pos, focus_enemy.last_verified_m_pos) < dis_to_check / 2 and mvector3.distance_sq(logic_data.m_pos, focus_enemy.last_verified_m_pos) < dis_to_check then
							local nav_seg = managers.navigation:get_nav_seg_from_pos(focus_enemy.m_pos, true)
							local target_area = self:get_area_from_nav_seg_id(nav_seg)
							
							return best_u_area, target_area
						end
					end
				end
			end
		end
	end
end

function GroupAIStateBesiege:_get_group_forwardmost_coarse_path_index_from_unit(u_key)
	local u_data = self._police[u_key]

	if not u_data then
		return
	end
	
	if not u_data.group then
		return
	end
	
	local group = u_data.group
	
	if not group.objective then
		return
	end
	
	local coarse_path = group.objective.coarse_path
	
	if not coarse_path then
		return
	end
	
	local coarse_path_size = #coarse_path
	local forwardmost_i_nav_point = #coarse_path

	while forwardmost_i_nav_point > 0 do
		local nav_seg = coarse_path[forwardmost_i_nav_point][1]
		local area = self:get_area_from_nav_seg_id(nav_seg)

		for u_key, u_data in pairs(group.units) do
			if area.nav_segs[u_data.unit:movement():nav_tracker():nav_segment()] then
				return forwardmost_i_nav_point, coarse_path_size
			end
		end

		forwardmost_i_nav_point = forwardmost_i_nav_point - 1
	end
end

function GroupAIStateBesiege:_assign_enemy_groups_to_assault(phase)
	for group_id, group in pairs(self._groups) do
		if group.has_spawned and group.objective.type == "assault_area" then
			if group.objective.moving_out then
				local done_moving = nil

				for u_key, u_data in pairs(group.units) do
					local objective = u_data.unit:brain():objective()

					if objective then
						if objective.grp_objective ~= group.objective then
							-- Nothing
						elseif not objective.in_place then
							done_moving = false
						elseif done_moving == nil then
							done_moving = true
						end
					end
				end

				if done_moving == true then
					group.objective.moving_out = nil
					group.in_place_t = self._t
					group.objective.moving_in = nil

					self:_voice_move_complete(group)
				end
			else
				group.objective.moving_in = nil
			end

			if not group.objective.moving_in then
				self:_set_assault_objective_to_group(group, phase)
			end
		end
	end
end

function GroupAIStateBesiege:_set_assault_objective_to_group(group, phase)
	if not group.has_spawned then
		return
	end

	local phase_is_anticipation = phase == "anticipation"
	local current_objective = group.objective
	local approach, open_fire, push, pull_back, charge, reassign, hard_charge = nil
	local obstructed_area = self:_chk_group_areas_tresspassed(group)
	local group_leader_u_key, group_leader_u_data = self._determine_group_leader(group.units)
	local tactics_map = nil
	local aggression_level = LIES.settings.enemy_aggro_level
	local forwardmost_i_nav_point = nil
	local needs_reassignment
	local too_campy = self._task_data.assault.old_target_pos_t and self._task_data.assault.old_target_pos_t > 30

	if group_leader_u_data and group_leader_u_data.tactics then
		tactics_map = {}
		
		local add_gas, added_gas
		
		if LIES.settings.hhtacs then
			local difficulty = Global.game_settings and Global.game_settings.difficulty or "normal"
			local difficulty_index = tweak_data:difficulty_to_index(difficulty)
			
			if difficulty_index > 4 then
				add_gas = true
			end
		end
		
		local valid_block_types = {
			ranged_fire = true,
			sniper = true,
			shield = true,
			blockade = true
		}
		
		for _, tactic_name in ipairs(group_leader_u_data.tactics) do
			if tactic_name ~= "ranged_fire" or not too_campy then
				tactics_map[tactic_name] = true
			end
			
			if add_gas and not added_gas and tactic_name == "ranged_fire" then
				tactics_map["gas"] = true
				added_gas = true
			end
		end
		
		if not group_leader_u_data.tactics.charge then
			local add_blockade
			
			for i_tactic, tactic_name in ipairs(group_leader_u_data.tactics) do
				if valid_block_types[tactic_name] then 
					add_blockade = true
					
					break
				end
			end
			
			if add_blockade then
				tactics_map["blockade"] = true
			end
		end

		if current_objective.tactic then
			if not tactics_map[current_objective.tactic] then
				current_objective.tactic = nil
			elseif current_objective.tactic == "shield" then
				if alive(current_objective.follow_unit) then
					local f_unit = current_objective.follow_unit
					
					if self._escorts[f_unit:key()] then
						local tracker = self._escorts[f_unit:key()].tracker
						local f_brain = f_unit:brain()
						
						if f_brain._current_logic_name == "escort" then
							current_objective.area = self:get_area_from_nav_seg_id(tracker:nav_segment())
							current_objective.coarse_path = {
								{
									current_objective.area.pos_nav_seg,
									current_objective.area.pos
								}
							}
							current_objective.nav_seg = nil

							self:_set_objective_to_enemy_group(group, current_objective)
							self:_voice_block_escort_start(group)
							
							group.dialogue_data = "escort_block"

							return
						else
							current_objective.tactic = nil
						end
					else
						current_objective.tactic = nil
					end
				else
					current_objective.tactic = nil
				end
			elseif current_objective.tactic == "deathguard" then
				if alive(current_objective.follow_unit) then
					for u_key, u_data in pairs(self._char_criminals) do
						if current_objective.follow_unit:key() == u_key then
							if u_data.status and u_data.status ~= "electrified" then
								local crim_nav_seg = u_data.tracker:nav_segment()

								if current_objective.area.nav_segs[crim_nav_seg] then
									return
								else
									current_objective.tactic = nil
									
									break
								end
							else
								current_objective.tactic = nil
								
								break
							end
						end
					end
				else
					current_objective.tactic = nil
				end
			elseif current_objective.tactic == "flank" then
				if alive(current_objective.follow_unit) then
					for u_key, u_data in pairs(self._char_criminals) do
						if current_objective.follow_unit:key() == u_key then
							if not u_data.status or u_data.status == "electrified" then
								local players_nearby = self:_chk_crimin_proximity_to_unit(u_data.unit)
								
								if players_nearby > 0 then
									current_objective.tactic = nil
									
									break
								else
									current_objective.area = self:get_area_from_nav_seg_id(u_data.tracker:nav_segment())
									current_objective.coarse_path = {
										{
											current_objective.area.pos_nav_seg,
											current_objective.area.pos
										}
									}
									current_objective.nav_seg = nil

									self:_set_objective_to_enemy_group(group, current_objective)

								
									return
								end
							else
								current_objective.tactic = nil
								
								break
							end
						end
					end
				else
					current_objective.tactic = nil
				end
			end
			
			current_objective.interrupt_on_contact = nil
			needs_reassignment = not current_objective.tactic
		end
		
		if not needs_reassignment and not current_objective.tactic then
			for i_tactic, tactic_name in ipairs(group_leader_u_data.tactics) do
				if LIES.settings.hhtacs and tactic_name == "shield" then
					local chosen_escort_u_data
				
					for u_key, u_data in pairs(self._escorts) do
						if alive(u_data.unit) then
							local f_brain = u_data.unit:brain()
						
							if f_brain._current_logic_name == "escort" then
								local go_for_this_escort = true
								local f_tracker = u_data.tracker
								local f_area = self:get_area_from_nav_seg_id(f_tracker:nav_segment())
								
								for other_group_id, other_group in pairs(self._groups) do
									if other_group ~= group and other_group.objective.tactic == "shield" and other_group.objective.area == f_area then
										go_for_this_escort = nil
									end
								end
								
								if go_for_this_escort then
									chosen_escort_u_data = u_data
									
									break
								end
							end
						end
					end
					
					if chosen_escort_u_data then
						local search_params = {
							id = "GroupAI_squadblock",
							from_tracker = group_leader_u_data.unit:movement():nav_tracker(),
							to_tracker = chosen_escort_u_data.tracker,
							access_pos = self._get_group_acces_mask(group)
						}
						local coarse_path = managers.navigation:search_coarse(search_params)

						if coarse_path then							
							local grp_objective = {
								distance = 700,
								type = "assault_area",
								attitude = "engage",
								tactic = "shield",
								follow_unit = chosen_escort_u_data.unit,
								area = self:get_area_from_nav_seg_id(coarse_path[#coarse_path][1]),
								coarse_path = coarse_path
							}

							self:_set_objective_to_enemy_group(group, grp_objective)

							return
						end
					end
				elseif tactic_name == "deathguard" and not phase_is_anticipation then
					local closest_crim_u_data, closest_crim_dis_sq = nil

					--small change here to make sure tased players don't get deathguarded, as they're not really "downed"
					for u_key, u_data in pairs(self._char_criminals) do
						if u_data.unit and alive(u_data.unit) then
							if u_data.status and u_data.status ~= "electrified" then
								local closest_u_id, closest_u_data, closest_u_dis_sq = self._get_closest_group_unit_to_pos(u_data.m_pos, group.units)
							
								if closest_u_dis_sq and (not closest_crim_dis_sq or closest_u_dis_sq < closest_crim_dis_sq) then
									closest_crim_u_data = u_data
									closest_crim_dis_sq = closest_u_dis_sq
								end
							end
						end
					end

					if closest_crim_u_data and closest_crim_dis_sq < 640000 then
						local search_params = {
							id = "GroupAI_deathguard",
							from_tracker = group_leader_u_data.unit:movement():nav_tracker(),
							to_tracker = closest_crim_u_data.tracker,
							access_pos = self._get_group_acces_mask(group)
						}
						local coarse_path = managers.navigation:search_coarse(search_params)

						if coarse_path then
							local grp_objective = {
								distance = 800,
								type = "assault_area",
								attitude = "engage",
								tactic = "deathguard",
								follow_unit = closest_crim_u_data.unit,
								area = self:get_area_from_nav_seg_id(coarse_path[#coarse_path][1]),
								coarse_path = coarse_path
							}
							group.is_chasing = true

							self:_set_objective_to_enemy_group(group, grp_objective)
							self:_voice_deathguard_start(group)

							return
						end
					end
				elseif LIES.settings.hhtacs and tactic_name == "flank" then 
					local closest_crim_u_data, closest_crim_dis_sq = nil
					local crim_dis_sq_chk = not closest_crim_dis_sq or closest_crim_dis_sq > closest_u_dis_sq
					
					--"hunter" tactic added onto flank, find a criminal that is not downed and too far from their friends, hunt them down
					for u_key, u_data in pairs(self._char_criminals) do
						if u_data.unit and alive(u_data.unit) then
							if not u_data.status or u_data.status == "electrified" then
								local players_nearby = self:_chk_crimin_proximity_to_unit(u_data.unit)

								if players_nearby and players_nearby <= 0 then
									local closest_u_id, closest_u_data, closest_u_dis_sq = self._get_closest_group_unit_to_pos(u_data.m_pos, group.units)
									
									if closest_u_dis_sq and crim_dis_sq_chk then
										closest_crim_u_data = u_data
										closest_crim_dis_sq = closest_u_dis_sq
									end
								end
							end
						end
					end
					
					if closest_crim_u_data then
						local search_params = {
							id = "GroupAI_hunter",
							from_tracker = group_leader_u_data.unit:movement():nav_tracker(),
							to_tracker = closest_crim_u_data.tracker,
							access_pos = self._get_group_acces_mask(group)
						}
						local coarse_path = managers.navigation:search_coarse(search_params)
					
						if coarse_path then
							local grp_objective = {
								distance = 800,
								type = "assault_area",
								attitude = "engage",
								tactic = "flank",
								follow_unit = closest_crim_u_data.unit,
								area = self:get_area_from_nav_seg_id(coarse_path[#coarse_path][1]),
								coarse_path = coarse_path
							}
							group.is_chasing = true

							self:_set_objective_to_enemy_group(group, grp_objective)

							return
						end
					end
				elseif tactic_name == "charge" and not phase_is_anticipation and not LIES.settings.interruptoncontact then
					if aggression_level > 3 then
						charge = true
					elseif aggression_level > 1 then
						if group.in_place_t and self._t - group.in_place_t > 4 then
							charge = true
						end
					elseif group.in_place_t and (self._t - group.in_place_t > 15 or self._t - group.in_place_t > 4 and self._drama_data.amount <= tweak_data.drama.low) then
						--units can now charge preemptively if they're not moving in, saving some wasted updates and allowing for aggressive movement earlier
						charge = true
					end
				end
			end
		end
	end
	
	if aggression_level > 3 then
		if tactics_map and tactics_map.shield then
			tactics_map.shield = nil
		end
	end

	local objective_area = nil
	local target_area = nil

	if obstructed_area then
		if phase_is_anticipation then
			pull_back = true
		elseif tactics_map and tactics_map.ranged_fire or tactics_map and tactics_map.sniper then
			pull_back = true
		elseif charge and not current_objective.charge then
			push = true
		elseif current_objective.open_fire and (not tactics_map or not tactics_map.ranged_fire) then
			push = true
		else
			open_fire = true
			target_area = obstructed_area
		end
	else
		if current_objective.moving_out then
			if current_objective.blockading then
				if self._task_data.assault.target_areas and self._task_data.assault.target_areas[1] then --woah, the area we're going to is WAY off, get back on track
					if current_objective.area and mvector3.distance_sq(current_objective.area.pos, self._task_data.assault.target_areas[1].pos) > 36000000 then
						needs_reassignment = true
					end
				end
			end
			
			if needs_reassignment then
				objective_area = self:_get_group_area(group)
				
				pull_back = true
			end
			
			if not needs_reassignment then
				if not current_objective.blockading then
					local dis = tactics_map and tactics_map.ranged_fire and 2000 or tactics_map and tactics_map.sniper and 4000 or 1250
					local impatient
					
					if tactics_map and tactics_map.sniper then
						impatient = false
					elseif group.in_place_t then
						if aggression_level > 2 then
							impatient = not (tactics_map and tactics_map.ranged_fire) and self._t - group.in_place_t > 2 or self._t - group.in_place_t > 15
						else
							impatient = not (tactics_map and tactics_map.ranged_fire) and self._t - group.in_place_t > 7 or self._t - group.in_place_t > 20
						end
					end
					
					if aggression_level < 2 then
						dis = dis * 1.5
					elseif aggression_level > 2 then
						dis = dis / (aggression_level - 1)
					end
					
					local engaging_area
					
					engaging_area, target_area = self:_chk_group_engaging_area(group, dis, tactics_map and tactics_map.provide_support, impatient)
				end
					
				if engaging_area then
					if phase_is_anticipation then
						pull_back = true
					else
						open_fire = true
					end
					
					objective_area = engaging_area
				else
					local obstructed_path_index = self:_chk_coarse_path_obstructed(group)		
					
					if obstructed_path_index then
						if aggression_level > 3 and current_objective.attitude == "engage" then
							objective_area = self:get_area_from_nav_seg_id(current_objective.coarse_path[math.max(obstructed_path_index, 1)][1])
							reassign = obstructed_path_index
						else
							objective_area = self:get_area_from_nav_seg_id(current_objective.coarse_path[math.max(obstructed_path_index - 1, 1)][1])
							reassign = obstructed_path_index - 1
						end
					end
				end
			end
		elseif not current_objective.moving_out then
			local impatient
			local has_criminals_close 
			local engaging
			
			if not LIES.settings.interruptoncontact then
				for area_id, neighbour_area in pairs(current_objective.area.neighbours) do
					if next(neighbour_area.criminal.units) then
						has_criminals_close = true
						target_area = neighbour_area
					end
				end
			end
		
			if not has_criminals_close then
				local dis = tactics_map and tactics_map.ranged_fire and 2000 or tactics_map and tactics_map.sniper and 4000 or 1250
				local impatient
				
				if tactics_map and tactics_map.sniper then
					impatient = false
				elseif group.in_place_t then
					if aggression_level > 2 then
						impatient = not (tactics_map and tactics_map.ranged_fire) and self._t - group.in_place_t > 2 or self._t - group.in_place_t > 15
					else
						impatient = not (tactics_map and tactics_map.ranged_fire) and self._t - group.in_place_t > 7 or self._t - group.in_place_t > 20
					end
				end
				
				if aggression_level < 2 then
					dis = dis * 1.5
				elseif aggression_level > 2 then
					dis = dis / (aggression_level - 1)
				end
				
				engaging, target_area = self:_chk_group_engaging_area(group, dis, tactics_map and tactics_map.provide_support, impatient)
				has_criminals_close = engaging and true
			end
			
			if not engaging and LIES.settings.interruptoncontact then
				for area_id, neighbour_area in pairs(current_objective.area.neighbours) do
					if next(neighbour_area.criminal.units) then
						has_criminals_close = true
						target_area = neighbour_area
					end
				end
			end
			
			if not engaging then
				if tactics_map and tactics_map.sniper then
					impatient = false
				elseif group.in_place_t then
					if aggression_level > 2 then
						impatient = not (tactics_map and tactics_map.ranged_fire) or self._t - group.in_place_t > 7
					else
						impatient = not (tactics_map and tactics_map.ranged_fire) and self._t - group.in_place_t > 2 or self._t - group.in_place_t > 15
					end
				end
			end
			
			--groups that have begun aggressive pushes will chase down players properly, aggression_level 4 chases constantly if the assault is happening
			if charge then --if a shield group has charge, then it'll still charge
				push = true
			elseif not has_criminals_close and not engaging or not group.in_place_t then
				approach = true
			elseif not phase_is_anticipation and not current_objective.open_fire then
				open_fire = true
			elseif not phase_is_anticipation and group.in_place_t and (not tactics_map or not tactics_map.shield and not tactics_map.sniper) then
				if impatient then
					push = true
				elseif engaging and current_objective.area ~= engaging then
					open_fire = true
					objective_area = engaging
				end
			elseif phase_is_anticipation and current_objective.open_fire then
				pull_back = true
			elseif engaging and current_objective.area ~= engaging then
				open_fire = true
				objective_area = engaging
			end
		end
	end
	
	if not objective_area then
		objective_area = obstructed_area or objective_area or current_objective.area
	end

	if open_fire then
		local grp_objective = {
			attitude = "engage",
			pose = "stand",
			type = "assault_area",
			stance = "hos",
			open_fire = true,
			area = objective_area,
			interrupt_on_contact = true,
			target_area = target_area,
			coarse_path = {
				{
					objective_area.pos_nav_seg,
					mvector3.copy(objective_area.pos)
				}
			}
		}
		
		grp_objective.old_engaging_area = objective_area
		
		if target_area then
			local used_grenade, use_gas
			local detonate_pos = nil
				
			if tactics_map and tactics_map.gas then
				if self._task_data.assault.old_target_pos_t and self._task_data.assault.old_target_pos_t > 15 then
					use_gas = true
				end
			end
			
			if use_gas then
				local old_target_pos = self._task_data.assault.old_target_pos
				
				if old_target_pos then	
					for c_key, c_data in pairs(target_area.criminal.units) do
						if math.abs(c_data.m_pos.z - old_target_pos.z) <= 250 and mvector3.distance(c_data.m_pos, old_target_pos) <= 600 then
							detonate_pos = c_data.unit:movement():m_pos()
						end
					end
				end
			end
			
			if use_gas and detonate_pos then
				used_grenade = self:_chk_group_use_gas_grenade(group, self._task_data.assault, detonate_pos)
				
				if used_grenade then
					group.in_place_t = self._t
					used_grenade = nil
					
					return
				elseif not charge then
					detonate_pos = nil
				end
			end
				
			if not used_grenade then
				local first_chk = math.random() < 0.5 and self._chk_group_use_flash_grenade or self._chk_group_use_smoke_grenade
				local second_chk = first_chk == self._chk_group_use_flash_grenade and self._chk_group_use_smoke_grenade or self._chk_group_use_flash_grenade
				used_grenade = first_chk(self, group, self._task_data.assault, detonate_pos, assault_area)
				used_grenade = used_grenade or second_chk(self, group, self._task_data.assault, detonate_pos, assault_area)
			end
		end

		self:_set_objective_to_enemy_group(group, grp_objective)
		self:_voice_open_fire_start(group)
	elseif approach or push then
		local enabled
		
		if enabled and not push and tactics_map and tactics_map.blockade and aggression_level < 4 then
			local occupied_areas = {}
			local blockade_help_areas = {}
			local v3_dis_sq = mvector3.distance_sq
			local fwd_vec = temp_vec1
			local current_assault_target_area = self._task_data.assault.target_areas and self._task_data.assault.target_areas[1]
			
			--the gist is that there'll always be at least one non-blockading group who is engaging, and then a huge set of blockading groups behind those guys, in a conga-line
			--not all enemy groups go into blockade, ensuring theres a steady stream of cops pushing in at all times
			--blockade groups will also detect if there is literally no one making an engagement or push, and try to do that themselves,
			--other groups will automatically readjust to match
			--god is dead
			
			for other_group_id, other_group in pairs(self._groups) do
				if other_group.has_spawned and other_group ~= group and other_group.in_place_t and other_group.objective and other_group.objective.type == "assault_area" then
					if other_group.objective.blockading then
						if not blockade_help_areas[other_group.objective.area.id] and not occupied_areas[other_group.objective.area.id] then
							blockade_help_areas[other_group.objective.area.id] = other_group.objective.area
						end
						
						for other_area_id, other_area in pairs(other_group.objective.area.neighbours) do
							if not occupied_areas[other_area_id] and not blockade_help_areas[other_area_id] and other_area_id ~= objective_area.id then
								if not current_assault_target_area or v3_dis_sq(current_assault_target_area.pos, other_area.pos) <= 36000000 then
									blockade_help_areas[other_area_id] = other_area
								end
							end
						end
					elseif other_group.objective.area and other_group.objective.area.id ~= objective_area.id and not occupied_areas[other_group.objective.area.id] then
						occupied_areas[other_group.objective.area.id] = other_group.objective.area
						
						if other_group.objective.target_area then
							mvector3.set(fwd_vec, other_group.objective.area.pos)
							mvector3.subtract(fwd_vec, other_group.objective.target_area.pos)
							
							local navsegs = managers.navigation:get_nav_segments_in_direction(other_group.objective.area.pos_nav_seg, fwd_vec)
							
							if navsegs then
								for nav_seg_id, _ in pairs(navsegs) do
									local seg_area = self:get_area_from_nav_seg_id(nav_seg_id)
									
									if not occupied_areas[seg_area.id] and v3_dis_sq(seg_area.pos, other_group.objective.target_area.pos) <= 2250000 then
										if not current_assault_target_area or v3_dis_sq(current_assault_target_area.pos, seg_area.pos) <= 36000000 then
											occupied_areas[seg_area.id] = seg_area
										end
									end
								end
							end
						end
					end
				end
			end
			
			for area_id, area in pairs(occupied_areas) do
				for other_area_id, other_area in pairs(area.neighbours) do
					if not occupied_areas[other_area_id] and not blockade_help_areas[other_area_id] and other_area_id ~= objective_area.id then
						blockade_help_areas[other_area_id] = other_area
					end
				end
			end
			
			if table.size(occupied_areas) > 0 and table.size(blockade_help_areas) > 0 then
				local best_police_count, best_dis, block_path
				local best_area = objective_area
				
				local search_params = {
					id = "GroupAI_assault",
					from_seg = objective_area.pos_nav_seg,
					access_pos = self._get_group_acces_mask(group),
					verify_clbk = callback(self, self, "is_nav_seg_safe")
				}
				
				for area_id, area in pairs(blockade_help_areas) do
					if not next(area.criminal.units) then
						local nr_police = table.size(area.police.units)
						local dis = v3_dis_sq(area.pos, objective_area.pos)
							
						if not best_police_count or nr_police <= best_police_count then
							if not best_dis or dis < best_dis then
								search_params.to_seg = area.pos_nav_seg
								local path = managers.navigation:search_coarse(search_params)
								
								if path then
									block_path = path
									best_area = area
									best_police_count = nr_police
									best_dis = dis
								end
							end
						end
					end
				end
				
				if best_area and block_path then
					local new_grp_objective = {
						attitude = "avoid",
						pose = "crouch",
						type = "assault_area",
						stance = "hos",
						blockading = true,
						area = best_area,
						coarse_path = block_path
					}

					self:_set_objective_to_enemy_group(group, new_grp_objective)
					
					return
				end
			end
		end
	
		local assault_area, alternate_assault_area, alternate_assault_area_from, assault_path, alternate_assault_path, flank = nil
		local to_search_areas = {
			objective_area
		}
		local found_areas = {
			[objective_area] = "init"
		}

		repeat
			local search_area = table.remove(to_search_areas, 1)
			
			if next(search_area.criminal.units) then
				local assault_from_here = true

				if not push and tactics_map and tactics_map.flank or not push and LIES.settings.hhtacs then
					local assault_from_area = found_areas[search_area]

					if assault_from_area ~= "init" then
						for other_group_id, other_group in pairs(self._groups) do
							if other_group.has_spawned and other_group ~= group and other_group.objective and other_group.objective.type == "assault_area" and other_group.objective.area and assault_from_area.id == other_group.objective.area.id then
								assault_from_here = false
								
								if not alternate_assault_area or math.random() < 0.5 then
									local search_params = {
										id = "GroupAI_assault",
										from_seg = objective_area.pos_nav_seg,
										to_seg = search_area.pos_nav_seg,
										access_pos = self._get_group_acces_mask(group),
										verify_clbk = approach and callback(self, self, "is_nav_seg_safe")
									}
									alternate_assault_path = managers.navigation:search_coarse(search_params)

									if alternate_assault_path then
										self:_merge_coarse_path_by_area(alternate_assault_path)

										alternate_assault_area = search_area
										alternate_assault_area_from = assault_from_area
									end
								end

								found_areas[search_area] = nil

								break
							end
						end
					end
				end

				if assault_from_here then
					local search_params = {
						id = "GroupAI_assault",
						from_seg = current_objective.area.pos_nav_seg,
						to_seg = search_area.pos_nav_seg,
						access_pos = self._get_group_acces_mask(group),
						verify_clbk = approach and callback(self, self, "is_nav_seg_safe")
					}
					assault_path = managers.navigation:search_coarse(search_params)

					if assault_path then
						self:_merge_coarse_path_by_area(assault_path)

						assault_area = search_area

						break
					end
				end
			else
				for other_area_id, other_area in pairs(search_area.neighbours) do
					if not found_areas[other_area] then
						table.insert(to_search_areas, other_area)

						found_areas[other_area] = search_area
					end
				end
			end
		until #to_search_areas == 0

		if not assault_area and alternate_assault_area then
			flank = nil
			assault_area = alternate_assault_area
			found_areas[assault_area] = alternate_assault_area_from
			assault_path = alternate_assault_path
		end

		if assault_area and assault_path then
			--set objective area, if we're pushing, the assault area will be the area with criminals, if we aren't, then we set it to the area we'd come in FROM
			--we have to verify if the area we are currently in isn't already right next to the criminals just in case, which is the "init" check here
			assault_area = push and assault_area or found_areas[assault_area] == "init" and objective_area or found_areas[assault_area]
			
			--if the objective area we set above's nav segs are included in the coarse path, we stop early
			if #assault_path > 1 and assault_area.nav_segs[assault_path[#assault_path - 1][1]] then
				table.remove(assault_path)
			end
			
			--pushing tries to make use of a grenade just before entry
			local used_grenade, use_gas

			if push then 
				local detonate_pos = nil
				
				if tactics_map and tactics_map.gas then
					if self._task_data.assault.old_target_pos_t and self._task_data.assault.old_target_pos_t > 7 then
						use_gas = true
					end
				end
				
				if charge or use_gas then
					local old_target_pos = self._task_data.assault.old_target_pos
					
					if old_target_pos then	
						for c_key, c_data in pairs(assault_area.criminal.units) do
							if mvector3.distance(c_data.m_pos, old_target_pos) <= 700 then
								detonate_pos = c_data.unit:movement():m_pos()
							end
						end
					end
				end
				
				if use_gas and detonate_pos then
					used_grenade = self:_chk_group_use_gas_grenade(group, self._task_data.assault, detonate_pos)
					
					if used_grenade then
						group.in_place_t = self._t
						used_grenade = nil
						
						return
					elseif not charge then
						detonate_pos = nil
					end
				end
					
				if not used_grenade then
					local first_chk = math.random() < 0.5 and self._chk_group_use_flash_grenade or self._chk_group_use_smoke_grenade
					local second_chk = first_chk == self._chk_group_use_flash_grenade and self._chk_group_use_smoke_grenade or self._chk_group_use_flash_grenade
					used_grenade = first_chk(self, group, self._task_data.assault, detonate_pos, assault_area)
					used_grenade = used_grenade or second_chk(self, group, self._task_data.assault, detonate_pos, assault_area)
				end
			else
				if flank then
					self:_voice_flank_start(group)
				else
					self:_voice_move_in_start(group)
				end
			end
			
			--essentially ensure the group uses a grenade if they can, this check wasn't here originally in some very old builds of the game
			--in vanilla, groups can only push if they deploy a grenade as a result of the check being added, i guess they thought enemies were too aggressive
			local can_push = used_grenade
			
			if not can_push then
				if not tactics_map or not tactics_map.ranged_fire or not tactics_map.sniper or charge then
					can_push = true
				elseif self._task_data.assault.cs_grenade_active_t and self._task_data.assault.cs_grenade_active_t < self._t or self._drama_data.amount <= tweak_data.drama.low and aggression_level > 2 then
					can_push = charge or self._drama_data.amount <= tweak_data.drama.low
				end
			end
			
			if not push or can_push then 
				if push then --only play the charge voicelines if actually charging
					self:_voice_charge_start(group)
					
					if assault_path then
						--if players are camping in a corner and not doing anything, send cops to push into that position
						local c_pos
						
						for c_key, c_data in pairs(assault_area.criminal.units) do
							c_pos = c_data.unit:movement():m_pos()
							
							break
						end
						
						if c_pos then
							assault_path[#assault_path][2] = c_pos
						end
					end
				end

				local attitude = phase_is_anticipation and "avoid" or "engage"
				
				if push then
					attitude = "engage"
				end

				local grp_objective = {
					type = "assault_area",
					stance = "hos",
					area = assault_area,
					coarse_path = assault_path,
					pose = push and "crouch" or "stand",
					interrupt_on_contact = push or nil,
					old_engaging_area = current_objective.old_engaging_area,
					attitude = attitude,
					moving_in = push and true or nil,
					open_fire = push or nil,
					pushed = push or nil,
					charge = charge or push and aggression_level > 3,
					interrupt_dis = nil
				}
				group.is_chasing = group.is_chasing or push
				
				if push then
					group.dialogue_data = "push"
				elseif flank then
					group.dialogue_data = "flank"
				else
					group.dialogue_data = "move_in"
				end

				self:_set_objective_to_enemy_group(group, grp_objective)
				
				return
			end
		end
	elseif reassign then --instead of using pull_back for reassignment purposes, use this to keep the objective itself consistent, reassigned groups don't re-set dialogue data
		if objective_area then
			local new_grp_objective = clone(current_objective)
			
			new_grp_objective.area = objective_area
			new_grp_objective.nav_seg = nil
			
			if new_grp_objective.coarse_path then
				local new_coarse_path = {}
				forwardmost_i_nav_point = forwardmost_i_nav_point or self:_get_group_forwardmost_coarse_path_index(group)
				
				new_coarse_path[#new_coarse_path + 1] = new_grp_objective.coarse_path[forwardmost_i_nav_point]
				
				for i = forwardmost_i_nav_point + 1, reassign do
					new_coarse_path[#new_coarse_path + 1] = new_grp_objective.coarse_path[i]
				end
				
				new_grp_objective.coarse_path = new_coarse_path
			end

			self:_set_objective_to_enemy_group(group, new_grp_objective)
			
			return
		end
	elseif pull_back then
		local retreat_area = nil
		
		if objective_area then --objective area gets set for pulling back but is never used, this ensures that it does *try* to get used
			if not next(objective_area.criminal.units) then
				retreat_area = objective_area
			end
		end
		
		if not retreat_area then
			for u_key, u_data in pairs(group.units) do
				local nav_seg_id = u_data.tracker:nav_segment()

				if self:is_nav_seg_safe(nav_seg_id) then
					retreat_area = self:get_area_from_nav_seg_id(nav_seg_id)

					break
				end
			end
		end

		if not retreat_area and current_objective.coarse_path then
			forwardmost_i_nav_point = forwardmost_i_nav_point or self:_get_group_forwardmost_coarse_path_index(group)

			if forwardmost_i_nav_point and forwardmost_i_nav_point > 1 then
				local nearest_safe_nav_seg_id = current_objective.coarse_path[forwardmost_i_nav_point - 1][1]
				retreat_area = self:get_area_from_nav_seg_id(nearest_safe_nav_seg_id)
			end
		end

		if retreat_area then
			local new_grp_objective = {
				attitude = phase_is_anticipation and "avoid" or "engage",
				stance = "hos",
				type = "assault_area",
				area = retreat_area,
				interrupt_on_contact = current_objective.interrupt_on_contact,
				old_engaging_area = current_objective.old_engaging_area,
				coarse_path = {
					{
						retreat_area.pos_nav_seg,
						mvector3.copy(retreat_area.pos)
					}
				}
			}
			group.is_chasing = nil
			
			group.dialogue_data = nil

			self:_set_objective_to_enemy_group(group, new_grp_objective)

			return
		end
	end
end

function GroupAIStateBesiege:_assign_enemy_groups_to_recon()
	for group_id, group in pairs(self._groups) do
		if group.has_spawned and group.objective.type == "recon_area" then
			if group.objective.moving_out then
				local done_moving = nil

				for u_key, u_data in pairs(group.units) do
					local objective = u_data.unit:brain():objective()

					if objective then
						if objective.grp_objective ~= group.objective then
							-- Nothing
						elseif not objective.in_place then
							done_moving = false
						elseif done_moving == nil then
							done_moving = true
						end
					end
				end

				if done_moving == true then
					if group.objective.moved_in then
						group.visited_areas = group.visited_areas or {}
						group.visited_areas[group.objective.area] = true
						
						if group.objective.area.hostages then
							self:_voice_movedin_civs(group)
						end
					end

					group.objective.moving_out = nil
					group.in_place_t = self._t
					group.objective.moving_in = nil

					self:_voice_move_complete(group)
				end
			end

			if not group.objective.moving_in then
				self:_set_recon_objective_to_group(group)
			end
		end
	end
end

function GroupAIStateBesiege:_begin_recon_sweep_task(recon_areas, target_positions)
	self._task_data.recon.sweep_task = {
		use_smoke = true,
		use_spawn_event = true,
		visited_areas = {},
		target_positions = target_positions,
		target_areas = recon_areas,
		start_t = self._t,
		sweep = true
	}

	self._task_data.recon.next_dispatch_t = nil
end

function GroupAIStateBesiege:_upd_recon_sweep_task()
	local task_data = self._task_data.recon.sweep_task
	
	if not task_data then
		return
	end
	
	local t = self._t
	
	for u_key, u_data in pairs(self._char_criminals) do
		if (not u_data.status or u_data.status == "electrified") and alive(u_data.unit) then
			if not u_data.undetected and t - u_data.det_t < 9 then
				self._task_data.recon.sweep_task = nil
				
				return
			end
		end
	end
	
	local visited_areas = task_data.visited_areas
	
	local search_complete = true
	
	for area_id, area in pairs(task_data.target_areas) do
		if not visited_areas[area_id] then
			search_complete = nil
		end
	end
	
	if search_complete then
		if t - task_data.start_t > 180 then
			self._task_data.recon.sweep_task = nil
		
			for u_key, u_data in pairs(self._char_criminals) do
				self:criminal_spotted(u_data.unit, true)
			end
			
			return
		else
			local all_areas = self._area_data
			local valid_criminal_pos = {}
			
			for u_key, u_data in pairs(self._char_criminals) do
				if alive(u_data.unit) then
					valid_criminal_pos[u_key] = mvector3.copy(u_data.pos)
				end
			end

			local mvec3_dis = mvector3.distance_sq
			local candidate_areas = {}
			
			for key, pos in pairs(valid_criminal_pos) do
				for area_id, area in pairs(all_areas) do
					if not next(area.police.units) then
						if mvec3_dis(pos, area.pos) < 1440000 and self:chk_area_leads_to_enemy(area.pos_nav_seg, area.pos_nav_seg, true) then
							candidate_areas[area_id] = area
						end
					end
				end
			end
			
			task_data.target_areas = candidate_areas
			task_data.target_positions = valid_criminal_pos
		end
	end

	self:_assign_enemy_groups_to_recon_sweep(task_data)
	self:_assign_assault_groups_to_retire()

	local nr_wanted = 24 - self:_count_police_force("recon")

	if nr_wanted <= 0 then
		return
	end
	
	local target_area
	
	for area_id, area in pairs(task_data.target_areas) do
		if table.size(area.neighbours) < 2 and not visited_areas[area_id] and not next(area.police.units) then
			target_area = area
			
			break
		end
	end
	
	if not target_area then
		for area_id, area in pairs(task_data.target_areas) do
			if not visited_areas[area_id] and not next(area.police.units) then
				target_area = area
				
				break
			end
		end
	end
	
	if target_area then
		local spawn_group, spawn_group_type
				
		if LIES.settings.fixed_spawngroups == 2 or LIES.settings.fixed_spawngroups == 4 then
			spawn_group, spawn_group_type = self:_find_spawn_group_near_area(target_area, self._tweak_data.recon.groups, nil, nil, nil, "recon")
		else
			spawn_group, spawn_group_type = self:_find_spawn_group_near_area(target_area, self._tweak_data.recon.groups, nil, nil, nil)
		end

		if spawn_group then			
			local grp_objective = {
				attitude = "avoid",
				stance = "hos",
				type = "recon_area",
				area = spawn_group.area,
				coarse_path = {
					{
						spawn_group.area.pos_nav_seg,
						spawn_group.area.pos
					}
				}
			}
			
			visited_areas[spawn_group.area.id] = true
			self:_spawn_in_group(spawn_group, spawn_group_type, grp_objective)

			used_group = true
		else
			visited_areas[target_area.id] = true
		end
	end
end

function GroupAIStateBesiege:_assign_enemy_groups_to_recon_sweep(task_data)
	for group_id, group in pairs(self._groups) do
		if group.has_spawned and group.objective.type == "recon_area" then
			if group.objective.moving_out then
				local done_moving = nil

				for u_key, u_data in pairs(group.units) do
					local objective = u_data.unit:brain():objective()

					if objective then
						if objective.grp_objective ~= group.objective then
							-- Nothing
						elseif not objective.in_place then
							done_moving = false
						elseif done_moving == nil then
							done_moving = true
						end
					end
				end

				if done_moving == true then
					task_data.visited_areas[group.objective.area.id] = true

					group.objective.moving_out = nil
					group.in_place_t = self._t
					group.objective.moving_in = nil
				end
			end

			if not group.objective.moving_out then
				self:_set_recon_sweep_objective_to_group(group)
			end
		end
	end
end

function GroupAIStateBesiege:_set_recon_sweep_objective_to_group(group)
	if not group.has_spawned then
		return
	end
	
	local current_objective = group.objective
	local task_data = self._task_data.recon.sweep_task
	local visited_areas = task_data.visited_areas
	
	if visited_areas[current_objective.area.id] then
		local sweep_path, target_area
		
		for area_id, area in pairs(task_data.target_areas) do
			if table.size(area.neighbours) < 2 and not visited_areas[area_id] and not next(area.police.units) then
				local search_params = {
					id = "GroupAI_reconsweep",
					from_seg = current_objective.area.pos_nav_seg,
					to_seg = area.pos_nav_seg,
					access_pos = self._get_group_acces_mask(group)
				}
				
				local coarse_path = managers.navigation:search_coarse(search_params)

				if coarse_path then
					target_area = area
					sweep_path = coarse_path
				
					break
				else
					visited_areas[area_id] = true
				end
			end
		end
		
		if not target_area then
			for area_id, area in pairs(task_data.target_areas) do
				if not visited_areas[area_id] and not next(area.police.units) then
					local search_params = {
						id = "GroupAI_reconsweep",
						from_seg = current_objective.area.pos_nav_seg,
						to_seg = area.pos_nav_seg,
						access_pos = self._get_group_acces_mask(group)
					}
				
					local coarse_path = managers.navigation:search_coarse(search_params)

					if coarse_path then
						target_area = area
						sweep_path = coarse_path
					
						break
					else
						visited_areas[area_id] = true
					end
				end
			end
		end
		
		if target_area and sweep_path then
			local grp_objective = {
				pose = "stand",
				type = "recon_area",
				stance = "hos",
				attitude = "avoid",
				area = target_area,
				coarse_path = sweep_path
			}

			self:_set_objective_to_enemy_group(group, grp_objective)
		end
	end
end

function GroupAIStateBesiege:_set_recon_objective_to_group(group)
	if not group.has_spawned then
		return
	end

	local current_objective = group.objective
	local target_area = current_objective.target_area or current_objective.area

	if not target_area.loot and not target_area.hostages or not current_objective.moving_out and current_objective.moved_in and group.in_place_t and self._t - group.in_place_t > 15 then
		local recon_area = nil
		local to_search_areas = {
			current_objective.area
		}
		local found_areas = {
			[current_objective.area] = "init"
		}

		repeat
			local search_area = table.remove(to_search_areas, 1)

			if search_area.loot or search_area.hostages then
				local occupied = nil

				for test_group_id, test_group in pairs(self._groups) do
					if test_group ~= group and (test_group.objective.target_area == search_area or test_group.objective.area == search_area) then
						occupied = true

						break
					end
				end

				if not occupied and group.visited_areas and group.visited_areas[search_area] then
					occupied = true
				end

				if not occupied then
					local is_area_safe = not next(search_area.criminal.units)

					if is_area_safe then
						recon_area = search_area

						break
					else
						recon_area = recon_area or search_area
					end
				end
			end

			if not next(search_area.criminal.units) then
				for other_area_id, other_area in pairs(search_area.neighbours) do
					if not found_areas[other_area] then
						table.insert(to_search_areas, other_area)

						found_areas[other_area] = search_area
					end
				end
			end
		until #to_search_areas == 0

		if recon_area then
			local coarse_path = {
				{
					recon_area.pos_nav_seg,
					recon_area.pos
				}
			}
			local last_added_area = recon_area

			while found_areas[last_added_area] ~= "init" do
				last_added_area = found_areas[last_added_area]

				table.insert(coarse_path, 1, {
					last_added_area.pos_nav_seg,
					last_added_area.pos
				})
			end

			local grp_objective = {
				scan = true,
				pose = "stand",
				type = "recon_area",
				stance = "hos",
				attitude = "avoid",
				area = current_objective.area,
				target_area = recon_area,
				coarse_path = coarse_path
			}

			self:_set_objective_to_enemy_group(group, grp_objective)

			current_objective = group.objective
		end
	end

	if current_objective.target_area then
		if current_objective.moving_out and not current_objective.moving_in and current_objective.coarse_path then
			local forwardmost_i_nav_point = self:_get_group_forwardmost_coarse_path_index(group)

			if forwardmost_i_nav_point and forwardmost_i_nav_point > 1 then
				for i = forwardmost_i_nav_point + 1, #current_objective.coarse_path do
					local nav_point = current_objective.coarse_path[i]

					if not self:is_nav_seg_safe(nav_point[1]) then
						for i = 0, #current_objective.coarse_path - i do
							table.remove(current_objective.coarse_path)
						end

						local grp_objective = {
							attitude = "avoid",
							scan = true,
							pose = "stand",
							type = "recon_area",
							stance = "hos",
							area = self:get_area_from_nav_seg_id(current_objective.coarse_path[#current_objective.coarse_path][1]),
							target_area = current_objective.target_area
						}

						self:_set_objective_to_enemy_group(group, grp_objective)

						return
					end
				end
			end
		end

		if not current_objective.moving_out and not current_objective.area.neighbours[current_objective.target_area.id] then
			local search_params = {
				id = "GroupAI_recon",
				from_seg = current_objective.area.pos_nav_seg,
				to_seg = current_objective.target_area.pos_nav_seg,
				access_pos = self._get_group_acces_mask(group),
				verify_clbk = callback(self, self, "is_nav_seg_safe")
			}
			local coarse_path = managers.navigation:search_coarse(search_params)

			if coarse_path then
				self:_merge_coarse_path_by_area(coarse_path)
				table.remove(coarse_path)

				local grp_objective = {
					scan = true,
					pose = "stand",
					type = "recon_area",
					stance = "hos",
					attitude = "avoid",
					area = self:get_area_from_nav_seg_id(coarse_path[#coarse_path][1]),
					target_area = current_objective.target_area,
					coarse_path = coarse_path
				}

				self:_set_objective_to_enemy_group(group, grp_objective)
			end
		end

		if not current_objective.moving_out and current_objective.area.neighbours[current_objective.target_area.id] then
			local grp_objective = {
				stance = "hos",
				scan = true,
				pose = "crouch",
				type = "recon_area",
				attitude = "avoid",
				area = current_objective.target_area
			}

			self:_set_objective_to_enemy_group(group, grp_objective)

			group.objective.moving_in = true

			if next(current_objective.target_area.criminal.units) then
				self:_chk_group_use_smoke_grenade(group, {
					use_smoke = true,
					target_areas = {
						grp_objective.area
					}
				})
			end
			
			if current_objective.target_area.hostages then
				self:_voice_getcivs(group)
			elseif current_objective.target_area.loot then
				self:_voice_gatherloot(group)
			end
		end
	end
end

function GroupAIStateBesiege:_chk_group_area_presence(group, area_to_chk)
	if not area_to_chk then
		return
	end
	
	local group_in_area = nil

	for u_key, u_data in pairs(group.units) do
	
		if u_data.tracker and alive(u_data.tracker) then
			local nav_seg = u_data.tracker:nav_segment()

			if area_to_chk.nav_segs[nav_seg] then
				group_in_area = true
			else
				group_in_area = nil
			end
		end
	end
	
	return group_in_area
end


--if a detonate_pos gets set, the function doesn't complete because shooter_u_data doesn't get set, this fixes that
--this also fixes enemies not announcing flash grenades but being able to announce smokes 
--if they can announce smokes, they should naturally be able to announce flashes too

function GroupAIStateBesiege:_chk_group_use_smoke_grenade(group, task_data, detonate_pos, target_area)
	if task_data.use_smoke and not self:is_smoke_grenade_active() then
		local shooter_pos, shooter_u_data = nil
		local duration = tweak_data.group_ai.smoke_grenade_lifetime
		
		if not target_area then
			target_area = task_data.target_areas[1]
		end

		for u_key, u_data in pairs(group.units) do
			if u_data.tactics_map and u_data.tactics_map.smoke_grenade then
				if not u_data.unit:movement():chk_action_forbidden("action") then
					if not detonate_pos then
						local nav_seg_id = u_data.tracker:nav_segment()
						local nav_seg = managers.navigation._nav_segments[nav_seg_id]

						for neighbour_nav_seg_id, door_list in pairs(nav_seg.neighbours) do
							if target_area.nav_segs[neighbour_nav_seg_id] then
								local random_door_id = door_list[math.random(#door_list)]

								if type(random_door_id) == "number" then
									detonate_pos = managers.navigation._room_doors[random_door_id].center
								else
									detonate_pos = random_door_id:script_data().element:nav_link_end_pos()
								end

								shooter_pos = mvector3.copy(u_data.m_pos)
								shooter_u_data = u_data

								break
							elseif managers.navigation._nav_segments[neighbour_nav_seg_id] then 
								local neighbour_seg_data = managers.navigation._nav_segments[neighbour_nav_seg_id]
								
								for over_neighbour_nav_seg_id, over_door_list in pairs(neighbour_seg_data.neighbours) do
									if target_area.nav_segs[over_neighbour_nav_seg_id] then
										local random_door_id = over_door_list[math.random(#over_door_list)]

										if type(random_door_id) == "number" then
											detonate_pos = managers.navigation._room_doors[random_door_id].center
										else
											detonate_pos = random_door_id:script_data().element:nav_link_end_pos()
										end

										shooter_pos = mvector3.copy(u_data.m_pos)
										shooter_u_data = u_data

										break
									end
								end
							end
						end
					else
						shooter_u_data = u_data
						shooter_pos = mvector3.copy(u_data.m_pos)
					end
				end

				if detonate_pos and shooter_u_data then
					self:detonate_smoke_grenade(detonate_pos, shooter_pos, duration, false)

					task_data.use_smoke_timer = self._t + math.lerp(tweak_data.group_ai.smoke_and_flash_grenade_timeout[1], tweak_data.group_ai.smoke_and_flash_grenade_timeout[2], math.rand(0, 1)^0.5)
					task_data.use_smoke = false
					
					if shooter_u_data.unit:movement():play_redirect("throw_grenade") then
						managers.network:session():send_to_peers_synched("play_distance_interact_redirect", shooter_u_data.unit, "throw_grenade")
					end
					
					if shooter_u_data.char_tweak.chatter.smoke and not shooter_u_data.unit:sound():speaking(self._t) then
						self:chk_say_enemy_chatter(shooter_u_data.unit, shooter_u_data.m_pos, "smoke")
					end

					return true
				end
			end
		end
	end
end

function GroupAIStateBesiege:_chk_group_use_flash_grenade(group, task_data, detonate_pos, target_area)
	if task_data.use_smoke and not self:is_smoke_grenade_active() then
		local shooter_pos, shooter_u_data = nil
		local duration = tweak_data.group_ai.flash_grenade_lifetime
		
		if not target_area then
			target_area = task_data.target_areas[1]
		end
		
		for u_key, u_data in pairs(group.units) do
			if u_data.tactics_map and u_data.tactics_map.flash_grenade then
				if not u_data.unit:movement():chk_action_forbidden("action") then
					if not detonate_pos then
						local nav_seg_id = u_data.tracker:nav_segment()
						local nav_seg = managers.navigation._nav_segments[nav_seg_id]

						for neighbour_nav_seg_id, door_list in pairs(nav_seg.neighbours) do
							if target_area.nav_segs[neighbour_nav_seg_id] then
								local random_door_id = door_list[math.random(#door_list)]

								if type(random_door_id) == "number" then
									detonate_pos = managers.navigation._room_doors[random_door_id].center
								else
									detonate_pos = random_door_id:script_data().element:nav_link_end_pos()
								end

								shooter_pos = mvector3.copy(u_data.m_pos)
								shooter_u_data = u_data

								break
							elseif managers.navigation._nav_segments[neighbour_nav_seg_id] then 
								local neighbour_seg_data = managers.navigation._nav_segments[neighbour_nav_seg_id]
								
								for over_neighbour_nav_seg_id, over_door_list in pairs(neighbour_seg_data.neighbours) do
									if target_area.nav_segs[over_neighbour_nav_seg_id] then
										local random_door_id = over_door_list[math.random(#over_door_list)]

										if type(random_door_id) == "number" then
											detonate_pos = managers.navigation._room_doors[random_door_id].center
										else
											detonate_pos = random_door_id:script_data().element:nav_link_end_pos()
										end

										shooter_pos = mvector3.copy(u_data.m_pos)
										shooter_u_data = u_data

										break
									end
								end
							end
						end
					else
						shooter_pos = mvector3.copy(u_data.m_pos)
						shooter_u_data = u_data
					end
				end

				if detonate_pos and shooter_u_data then
					self:detonate_smoke_grenade(detonate_pos, shooter_pos, duration, true)

					task_data.use_smoke_timer = self._t + math.lerp(tweak_data.group_ai.smoke_and_flash_grenade_timeout[1], tweak_data.group_ai.smoke_and_flash_grenade_timeout[2], math.random()^0.5)
					task_data.use_smoke = false
					
					if shooter_u_data.unit:movement():play_redirect("throw_grenade") then
						managers.network:session():send_to_peers_synched("play_distance_interact_redirect", shooter_u_data.unit, "throw_grenade")
					end

					if shooter_u_data.char_tweak.chatter.smoke and not shooter_u_data.unit:sound():speaking(self._t) then --if they can shout smoke, they'll shout flash, just in case
						self:chk_say_enemy_chatter(shooter_u_data.unit, shooter_u_data.m_pos, "flash_grenade")
					end

					return true
				end
			end
		end
	end
end

function GroupAIStateBesiege:_chk_group_use_gas_grenade(group, task_data, detonate_pos)
	local shooter_pos, shooter_u_data, shooter_dis_sq = nil
	local duration = tweak_data.group_ai.smoke_grenade_lifetime
	
	if not detonate_pos or task_data.next_allowed_cs_grenade_t and self._t < task_data.next_allowed_cs_grenade_t then
		return
	end

	for u_key, u_data in pairs(group.units) do
		if u_data.tactics_map and u_data.tactics_map.ranged_fire then
			if not u_data.unit:movement():chk_action_forbidden("action") then
				local dis = mvector3.distance_sq(detonate_pos, u_data.m_pos)

				if not shooter_dis_sq or dis < shooter_dis_sq then
					shooter_dis_sq = dis
					shooter_u_data = u_data
					shooter_pos = mvector3.copy(u_data.m_pos)
				end
			end
		end
	end

	if detonate_pos and shooter_u_data then
		local dir = Vector3()
		mvector3.direction(dir, shooter_pos, detonate_pos)
		local rot = Rotation()
		mrotation.set_look_at(rot, dir, math.UP)
		
		local grenade = World:spawn_unit(Idstring("units/pd2_dlc_drm/weapons/smoke_grenade_tear_gas/smoke_grenade_tear_gas"), detonate_pos, rot)

		grenade:base():set_properties({
			radius = 400,
			damage = 6,
			duration = duration
		})
		grenade:base():detonate()
		
		local cs_grenade_cooldown = duration * 2
		cs_grenade_cooldown = cs_grenade_cooldown + cs_grenade_cooldown + cs_grenade_cooldown * math.random()
		
		task_data.cs_grenade_active_t = self._t + duration
		task_data.next_allowed_cs_grenade_t = self._t + cs_grenade_cooldown
		
		if not DeadLocke then
			local closest_crim_data, closest_crim_dis_sq
			
			for c_key, c_data in pairs(self._criminals) do
				if not c_data.is_deployable then
					local dis = mvector3.distance_sq(c_data.m_pos, detonate_pos)
					
					if dis <= 360000 then
						if not closest_crim_dis_sq or dis < closest_crim_dis_sq then
							closest_crim_data = c_data
							closest_crim_dis_sq = dis
						end
					end
				end
			end
			
			if closest_crim_data then
				closest_crim_data.unit:sound():say("g42x_any", true)
			end
		end
		
		if shooter_u_data.unit:movement():play_redirect("throw_grenade") then
			managers.network:session():send_to_peers_synched("play_distance_interact_redirect", shooter_u_data.unit, "throw_grenade")
		end
		
		return true
	end
end

local function make_dis_id(from, to)
	local f = from < to and from or to
	local t = to < from and from or to

	return tostring(f) .. "-" .. tostring(t)
end

local function spawn_group_id(spawn_group)
	return spawn_group.mission_element:id()
end

function GroupAIStateBesiege:_find_spawn_group_near_area_LIESspawngroupdelays(target_area, allowed_groups, target_pos, max_dis, verify_clbk)
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
									dis = dis + mvec3_dis(current, nxt)
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
	local dis_limit = max_dis and max_dis or 5000 * 5000

	for i, dis in pairs(valid_spawn_group_distances) do
		local my_wgt = math.lerp(1, 0.2, math.min(1, dis / dis_limit)) * 5
		local my_spawn_group = valid_spawn_groups[i]
		local my_group_types = my_spawn_group.mission_element:spawn_groups()
		my_spawn_group.distance = dis
		total_weight = total_weight + self:_choose_best_groups(candidate_groups, my_spawn_group, my_group_types, allowed_groups, my_wgt)
	end

	if total_weight == 0 then
		return
	end

	for _, group in ipairs(candidate_groups) do
		table.insert(self._debug_weights, clone(group))
	end

	return self:_choose_best_group(candidate_groups, total_weight)
end