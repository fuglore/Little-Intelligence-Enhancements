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
		end

		if not l_data.group and l_data.team then
			text_str = l_data.team.id .. ":" .. text_str
		end

		if l_data.spawned_in_phase then
			text_str = text_str .. ":" .. l_data.spawned_in_phase
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

	local group_center = Vector3()

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
			elseif group.objective.moving_in then
				move_type = ":" .. "moving_in"
			elseif group.objective.open_fire then
				move_type = ":" .. "open_fire"
			elseif group.objective.moving_out then
				move_type = ":" .. "moving_out"
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

	-- Lines 2128-2141
	local function _f_draw_attention_on_player(l_data)
		if l_data.attention_obj then
			local my_head_pos = l_data.unit:movement():m_head_pos()
			local e_pos = l_data.attention_obj.m_head_pos
			local dis = mvector3.distance(my_head_pos, e_pos)

			mvector3.step(mid_pos2, my_head_pos, e_pos, 300)
			mvector3.lerp(mid_pos1, my_head_pos, mid_pos2, t % 0.5)
			mvector3.step(mid_pos2, mid_pos1, e_pos, 50)
			focus_enemy_pen:line(mid_pos1, mid_pos2)

			if l_data.attention_obj.unit:base() and l_data.attention_obj.unit:base().is_local_player then
				focus_player_brush:sphere(my_head_pos, 20)
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

Hooks:PostHook(GroupAIStateBesiege, "init", "lies_spawngroups", function(self)
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
		
		self._choose_best_groups = LIES._choose_best_groups
		self._choose_best_group = LIES._choose_best_group
		self._find_spawn_group_near_area = LIES._find_spawn_group_near_area
		self._upd_assault_task = LIES._upd_assault_task
		self._upd_recon_tasks = LIES._upd_recon_tasks
	elseif LIES.settings.spawngroupdelays then
		self._find_spawn_group_near_area = self._find_spawn_group_near_area_LIES
	end
	
	if LIES.settings.fixed_specialspawncaps then
		self._special_unit_types.tank_mini = true
		self._special_unit_types.tank_medic = true
		self._special_unit_types.tank_hw = true
		self._special_unit_types.phalanx_minion = true
	end
end)

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
		managers.enemy:add_delayed_clbk("GroupAIStateBesiege._upd_police_activity", callback(self, self, "_upd_police_activity"), self._t + (next(self._spawning_groups) and 0.4 or 2))
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
	local first_entry = hos_data[1]

	table.remove(hos_data, 1)
	first_entry.clbk()

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
		if unit_data.char_tweak.chatter.go_go and self:chk_say_enemy_chatter(unit_data.unit, unit_data.m_pos, "flank") then
			break
		end
	end
end

function GroupAIStateBesiege:_voice_charge_start(group)
	for u_key, unit_data in pairs(group.units) do
		if unit_data.char_tweak.chatter.go_go and self:chk_say_enemy_chatter(unit_data.unit, unit_data.m_pos, "push") then
			break
		end
	end
end

function GroupAIStateBesiege:_voice_follow_me(group)
	for u_key, unit_data in pairs(group.units) do
		if unit_data.char_tweak.chatter.ready and self:chk_say_enemy_chatter(unit_data.unit, unit_data.m_pos, "follow_me") then
			break
		end
	end
end

function GroupAIStateBesiege:_voice_getcivs(group)
	for u_key, unit_data in pairs(group.units) do
		if unit_data.char_tweak.chatter.suppress and self:chk_say_enemy_chatter(unit_data.unit, unit_data.m_pos, "getcivs") then
			break
		end
	end
end

function GroupAIStateBesiege:_voice_gatherloot(group)
	for u_key, unit_data in pairs(group.units) do
		if unit_data.char_tweak.chatter.suppress and self:chk_say_enemy_chatter(unit_data.unit, unit_data.m_pos, "gatherloot") then
			break
		end
	end
end

function GroupAIStateBesiege:_voice_movedin_civs(group)
	for u_key, unit_data in pairs(group.units) do
		if unit_data.char_tweak.chatter.suppress and self:chk_say_enemy_chatter(unit_data.unit, unit_data.m_pos, "movedin_civs") then
			break
		end
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
		objective.interrupt_suppression = true
	elseif grp_objective.type == "retire" then
		objective.type = "defend_area"
		objective.stance = "hos"
		objective.pose = "stand"
		objective.scan = true
		objective.interrupt_dis = 200
	elseif grp_objective.type == "assault_area" then
		objective.type = "defend_area"

		if grp_objective.follow_unit then
			objective.type = "follow"
			objective.follow_unit = grp_objective.follow_unit
			objective.distance = grp_objective.distance
		end

		objective.stance = "hos"
		objective.pose = "stand"
		objective.scan = true
		objective.interrupt_suppression = true
	elseif grp_objective.type == "create_phalanx" then
		objective.type = "phalanx"
		objective.stance = "hos"
		objective.interrupt_dis = nil
		objective.interrupt_health = nil
		objective.interrupt_suppression = nil
		objective.attitude = "avoid"
		objective.path_ahead = true
	elseif grp_objective.type == "hunt" then
		objective.type = "hunt"
		objective.stance = "hos"
		objective.scan = true
		objective.interrupt_dis = 200
	end
	
	if LIES.settings.interruptoncontact then
		if objective.type == "defend_area" or objective.type == "follow" then
			objective.interrupt_on_contact = true
		end
	end

	objective.stance = grp_objective.stance or objective.stance
	objective.pose = grp_objective.pose or objective.pose
	objective.area = grp_objective.area
	objective.nav_seg = grp_objective.nav_seg or objective.area.pos_nav_seg
	objective.attitude = grp_objective.attitude or objective.attitude
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

function GroupAIStateBesiege:_set_assault_objective_to_group(group, phase)
	if not group.has_spawned then
		return
	end

	local phase_is_anticipation = phase == "anticipation"
	local current_objective = group.objective
	local approach, open_fire, push, pull_back, charge, hard_charge = nil
	local obstructed_area = self:_chk_group_areas_tresspassed(group)
	local group_leader_u_key, group_leader_u_data = self._determine_group_leader(group.units)
	local tactics_map = nil
	local aggression_level = LIES.settings.enemy_aggro_level

	if group_leader_u_data and group_leader_u_data.tactics then
		tactics_map = {}

		for _, tactic_name in ipairs(group_leader_u_data.tactics) do
			tactics_map[tactic_name] = true
		end

		if current_objective.tactic then
			if not tactics_map[current_objective.tactic] then
				current_objective.tactic = nil
			elseif current_objective.tactic == "deathguard" then
				for u_key, u_data in pairs(self._char_criminals) do
					if u_data.status and current_objective.follow_unit == u_data.unit then
						local crim_nav_seg = u_data.tracker:nav_segment()

						if current_objective.area.nav_segs[crim_nav_seg] then
							return
						else
							current_objective.tactic = nil
						end
					else
						current_objective.tactic = nil
					end
				end
			end
		end
		
		if not current_objective.moving_in and not current_objective.tactic then
			for i_tactic, tactic_name in ipairs(group_leader_u_data.tactics) do
				if tactic_name == "deathguard" and not phase_is_anticipation then
					local closest_crim_u_data, closest_crim_dis_sq = nil

					for u_key, u_data in pairs(self._char_criminals) do
						if u_data.status then
							local closest_u_id, closest_u_data, closest_u_dis_sq = self._get_closest_group_unit_to_pos(u_data.m_pos, group.units)

							if closest_u_dis_sq and (not closest_crim_dis_sq or closest_u_dis_sq < closest_crim_dis_sq) then
								closest_crim_u_data = u_data
								closest_crim_dis_sq = closest_u_dis_sq
							end
						end
					end

					if closest_crim_u_data then
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
								moving_in = true,
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
				elseif tactic_name == "charge" and not phase_is_anticipation then
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

	local objective_area = nil

	if obstructed_area then
		if current_objective.moving_out and phase_is_anticipation then
			pull_back = true
		elseif charge and not current_objective.charge then
			if aggression_level > 3 then
				hard_charge = true
			else
				push = true
			end
		elseif current_objective.open_fire and not current_objective.pushed and (not tactics_map or not tactics_map.ranged_fire) then
			local t_in_place = aggression_level > 2 and 7 or aggression_level > 1 and 15
		
			if t_in_place and group.in_place_t and self._t - group.in_place_t > t_in_place then
				hard_charge = true
			else
				push = true
			end
		else
			open_fire = true
		end
	else
		local obstructed_path_index = self:_chk_coarse_path_obstructed(group)

		if obstructed_path_index then
			if aggression_level > 3 and current_objective.attitude == "engage" then
				objective_area = self:get_area_from_nav_seg_id(group.objective.coarse_path[math.max(obstructed_path_index, 1)][1])
				push = true
			else
				objective_area = self:get_area_from_nav_seg_id(group.objective.coarse_path[math.max(obstructed_path_index - 1, 1)][1])
				pull_back = true
			end
		elseif not current_objective.moving_out then
			local has_criminals_close = nil

			if not current_objective.moving_out then
				for area_id, neighbour_area in pairs(current_objective.area.neighbours) do
					if next(neighbour_area.criminal.units) then
						has_criminals_close = true

						break
					end
				end
			end
			
			--groups that have begun aggressive pushes will chase down players properly, aggression_level 4 chases constantly if the assault is happening
			if charge or group.is_chasing or aggression_level > 3 and not phase_is_anticipation and (not tactics_map or not tactics_map.flank) then 
				push = true
			elseif not has_criminals_close or not group.in_place_t then
				approach = true
			elseif not phase_is_anticipation and not current_objective.open_fire then
				open_fire = true
			elseif not phase_is_anticipation and group.in_place_t then
				if aggression_level > 2 then
					push = true
				elseif aggression_level > 1 then
					if group.is_chasing or not tactics_map or not tactics_map.ranged_fire or self._t - group.in_place_t > 7 then
						push = true
					end
				elseif group.is_chasing or not tactics_map or not tactics_map.ranged_fire or self._t - group.in_place_t > 15 then
					push = true
				end
			elseif phase_is_anticipation and current_objective.open_fire then
				pull_back = true
			end
		end
	end

	objective_area = objective_area or current_objective.area
	
	if hard_charge or aggression_level > 3 and push then
		local closest_crim_u_data, closest_crim_dis_sq = nil

		for u_key, u_data in pairs(self._char_criminals) do
			if not u_data.status then
				local closest_u_id, closest_u_data, closest_u_dis_sq = self._get_closest_group_unit_to_pos(u_data.m_pos, group.units)

				if closest_u_dis_sq then
					if not closest_crim_dis_sq or closest_u_dis_sq < closest_crim_dis_sq then
						closest_crim_u_data = u_data
						closest_crim_dis_sq = closest_u_dis_sq
					end
				end
			end
		end

		if closest_crim_u_data then
			local search_params = {
				id = "GroupAI_charge",
				from_seg = current_objective.area.pos_nav_seg,
				to_tracker = closest_crim_u_data.tracker,
				access_pos = self._get_group_acces_mask(group)
			}
			local coarse_path = managers.navigation:search_coarse(search_params)

			if coarse_path then
				local grp_objective = {
					stance = "hos",
					open_fire = true,
					pushed = true,
					charge = true,
					interrupt_dis = nil,
					distance = 1200,
					type = "assault_area",
					attitude = "engage",
					moving_in = true,
					follow_unit = closest_crim_u_data.unit,
					area = self:get_area_from_nav_seg_id(coarse_path[#coarse_path][1]),
					coarse_path = coarse_path
				}
				group.is_chasing = true
				
				self:_voice_charge_start(group)
				self:_set_objective_to_enemy_group(group, grp_objective)
			end
		end	
	elseif open_fire then
		local grp_objective = {
			attitude = "engage",
			pose = "stand",
			type = "assault_area",
			stance = "hos",
			open_fire = true,
			charge = aggression_level > 3,
			tactic = current_objective.tactic,
			area = obstructed_area or current_objective.area,
			coarse_path = {
				{
					objective_area.pos_nav_seg,
					mvector3.copy(current_objective.area.pos)
				}
			}
		}

		self:_set_objective_to_enemy_group(group, grp_objective)
		self:_voice_open_fire_start(group)
	elseif approach or push then
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

				if not push and tactics_map and tactics_map.flank then
					local assault_from_area = found_areas[search_area]

					if assault_from_area ~= "init" then
						local cop_units = assault_from_area.police.units

						for u_key, u_data in pairs(cop_units) do
							if u_data.group and u_data.group ~= group and u_data.group.objective.type == "assault_area" then
								assault_from_here = false

								if not alternate_assault_area or math.random() < 0.5 then
									local search_params = {
										id = "GroupAI_assault",
										from_seg = current_objective.area.pos_nav_seg,
										to_seg = search_area.pos_nav_seg,
										access_pos = self._get_group_acces_mask(group),
										verify_clbk = callback(self, self, "is_nav_seg_safe")
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
						verify_clbk = callback(self, self, "is_nav_seg_safe")
					}
					assault_path = managers.navigation:search_coarse(search_params)

					if assault_path then
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
			flank = true
			assault_area = alternate_assault_area
			found_areas[assault_area] = alternate_assault_area_from
			assault_path = alternate_assault_path
		end

		if assault_area and assault_path then
			local assault_area = push and assault_area or found_areas[assault_area] == "init" and objective_area or found_areas[assault_area]

			if #assault_path > 2 and assault_area.nav_segs[assault_path[#assault_path - 1][1]] then
				table.remove(assault_path)
			end

			local used_grenade = nil

			if push then
				local detonate_pos = nil

				if charge then
					for c_key, c_data in pairs(assault_area.criminal.units) do
						detonate_pos = c_data.unit:movement():m_pos()

						break
					end
				end

				local first_chk = math.random() < 0.5 and self._chk_group_use_flash_grenade or self._chk_group_use_smoke_grenade
				local second_chk = first_chk == self._chk_group_use_flash_grenade and self._chk_group_use_smoke_grenade or self._chk_group_use_flash_grenade
				used_grenade = first_chk(self, group, self._task_data.assault, detonate_pos)
				used_grenade = used_grenade or second_chk(self, group, self._task_data.assault, detonate_pos)
			else
				if flank then
					self:_voice_flank_start(group)
				else
					self:_voice_move_in_start(group)
				end
			end
			
			--if a group is chasing/charging then they should be able to enter the area even without a grenade, or, if there's other cops assigned to the area.
			local can_push = used_grenade
			
			if not can_push then
				if aggression_level > 2 then
					can_push = true
				elseif aggression_level > 1 then
					can_push = charge or group.is_chasing
				end
			end
			
			if not push or can_push then 
				if push then --only play the charge voicelines if actually charging
					self:_voice_charge_start(group)
				end
				
				local attitude = "avoid"
				
				if push then
					attitude = "engage"
				elseif not phase_is_anticipation and aggression_level > 1 then
					attitude = "engage"
				end

				local grp_objective = {
					type = "assault_area",
					stance = "hos",
					area = assault_area,
					coarse_path = assault_path,
					pose = push and "crouch" or "stand",
					attitude = attitude,
					moving_in = push and true or nil,
					open_fire = push or nil,
					pushed = push or nil,
					charge = charge or aggression_level > 3,
					interrupt_dis = nil
				}
				group.is_chasing = group.is_chasing or push

				self:_set_objective_to_enemy_group(group, grp_objective)
			end
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
			local forwardmost_i_nav_point = self:_get_group_forwardmost_coarse_path_index(group)

			if forwardmost_i_nav_point and forwardmost_i_nav_point > 1 then
				local nearest_safe_nav_seg_id = current_objective.coarse_path[forwardmost_i_nav_point - 1][1]
				retreat_area = self:get_area_from_nav_seg_id(nearest_safe_nav_seg_id)
			end
		end

		if retreat_area then
			local new_grp_objective = {
				attitude = "avoid",
				stance = "hos",
				pose = "crouch",
				type = "assault_area",
				area = retreat_area,
				coarse_path = {
					{
						retreat_area.pos_nav_seg,
						mvector3.copy(retreat_area.pos)
					}
				}
			}
			group.is_chasing = nil

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
					local nav_point = current_objective.coarse_path[forwardmost_i_nav_point]

					if not self:is_nav_seg_safe(nav_point[1]) then
						for i = 0, #current_objective.coarse_path - forwardmost_i_nav_point do
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

function GroupAIStateBesiege:_set_objective_to_enemy_group(group, grp_objective)
	group.objective = grp_objective

	if grp_objective.area then
		--if a group is already in the objective area, they shouldn't need to check for being in place later
		if grp_objective.type == "retire" or not self:_chk_group_area_presence(group, grp_objective.area) then
			grp_objective.moving_out = true
		elseif not group.in_place then
			group.in_place = true
			group.in_place_t = self._t
			grp_objective.moving_out = nil
			
			if group.objective.moved_in then
				group.visited_areas = group.visited_areas or {}
				group.visited_areas[group.objective.area] = true
			end
		end

		if not grp_objective.nav_seg and grp_objective.coarse_path then
			grp_objective.nav_seg = grp_objective.coarse_path[#grp_objective.coarse_path][1]
		end
	end

	grp_objective.assigned_t = self._t

	if self._AI_draw_data and self._AI_draw_data.group_id_texts[group.id] then
		self._AI_draw_data.panel:remove(self._AI_draw_data.group_id_texts[group.id])

		self._AI_draw_data.group_id_texts[group.id] = nil
	end
end

--if a detonate_pos gets set, the function doesn't complete because shooter_u_data doesn't get set, this fixes that
--this also fixes enemies not announcing flash grenades but being able to announce smokes 
--if they can announce smokes, they should naturally be able to announce flashes too

function GroupAIStateBesiege:_chk_group_use_smoke_grenade(group, task_data, detonate_pos)
	if task_data.use_smoke and not self:is_smoke_grenade_active() then
		local shooter_pos, shooter_u_data = nil
		local duration = tweak_data.group_ai.smoke_grenade_lifetime

		for u_key, u_data in pairs(group.units) do
			if u_data.tactics_map and u_data.tactics_map.smoke_grenade then
				if not detonate_pos then
					local nav_seg_id = u_data.tracker:nav_segment()
					local nav_seg = managers.navigation._nav_segments[nav_seg_id]

					for neighbour_nav_seg_id, door_list in pairs(nav_seg.neighbours) do
						local area = self:get_area_from_nav_seg_id(neighbour_nav_seg_id)

						if task_data.target_areas[1].nav_segs[neighbour_nav_seg_id] or next(area.criminal.units) then
							local random_door_id = door_list[math.random(#door_list)]

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
				else
					shooter_u_data = u_data
					shooter_pos = mvector3.copy(u_data.m_pos)
				end

				if detonate_pos and shooter_u_data then
					self:detonate_smoke_grenade(detonate_pos, shooter_pos, duration, false)

					task_data.use_smoke_timer = self._t + math.lerp(tweak_data.group_ai.smoke_and_flash_grenade_timeout[1], tweak_data.group_ai.smoke_and_flash_grenade_timeout[2], math.rand(0, 1)^0.5)
					task_data.use_smoke = false

					if shooter_u_data.char_tweak.chatter.smoke and not shooter_u_data.unit:sound():speaking(self._t) then
						self:chk_say_enemy_chatter(shooter_u_data.unit, shooter_u_data.m_pos, "smoke")
					end

					return true
				end
			end
		end
	end
end

function GroupAIStateBesiege:_chk_group_use_flash_grenade(group, task_data, detonate_pos)
	if task_data.use_smoke and not self:is_smoke_grenade_active() then
		local shooter_pos, shooter_u_data = nil
		local duration = tweak_data.group_ai.flash_grenade_lifetime

		for u_key, u_data in pairs(group.units) do
			if u_data.tactics_map and u_data.tactics_map.flash_grenade then
				if not detonate_pos then
					local nav_seg_id = u_data.tracker:nav_segment()
					local nav_seg = managers.navigation._nav_segments[nav_seg_id]

					for neighbour_nav_seg_id, door_list in pairs(nav_seg.neighbours) do
						if task_data.target_areas[1].nav_segs[neighbour_nav_seg_id] then
							local random_door_id = door_list[math.random(#door_list)]

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
				else
					shooter_pos = mvector3.copy(u_data.m_pos)
					shooter_u_data = u_data
				end

				if detonate_pos and shooter_u_data then
					self:detonate_smoke_grenade(detonate_pos, shooter_pos, duration, true)

					task_data.use_smoke_timer = self._t + math.lerp(tweak_data.group_ai.smoke_and_flash_grenade_timeout[1], tweak_data.group_ai.smoke_and_flash_grenade_timeout[2], math.random()^0.5)
					task_data.use_smoke = false

					if shooter_u_data.char_tweak.chatter.smoke and not shooter_u_data.unit:sound():speaking(self._t) then --if they can shout smoke, they'll shout flash, just in case
						self:chk_say_enemy_chatter(shooter_u_data.unit, shooter_u_data.m_pos, "flash_grenade")
					end

					return true
				end
			end
		end
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

function GroupAIStateBesiege:_find_spawn_group_near_area_LIES(target_area, allowed_groups, target_pos, max_dis, verify_clbk)
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