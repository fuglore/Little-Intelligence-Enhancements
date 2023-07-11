GroupAIStateBase._nr_important_cops = 12 --gets divided in groupaistatebesiege if theres more than 1 player

local math_up = math.UP
local mvec3_dis_sq = mvector3.distance_sq

function GroupAIStateBase:set_importance_weight(u_key, wgt_report)
	if #wgt_report == 0 then
		return
	end

	local t_rem = table.remove
	local t_ins = table.insert
	local max_nr_imp = self._nr_important_cops
	local imp_adj = 0
	local criminals = self._player_criminals
	local cops = self._police
	
	if wgt_report[2] then
		if self._police[u_key] then
			local u_data = self._police[u_key]
			local crim_data = criminals[wgt_report[1]]
			
			local dis = mvec3_dis_sq(u_data.m_pos, crim_data.m_pos)
			
			wgt_report[2] = dis * wgt_report[2]
		end
	end

	for i_dis_rep = #wgt_report - 1, 1, -2 do
		local c_key = wgt_report[i_dis_rep]
		local c_dis = wgt_report[i_dis_rep + 1]
		local c_record = criminals[c_key]
		local imp_enemies = c_record.important_enemies
		local imp_dis = c_record.important_dis
		local was_imp = nil

		for i_imp = #imp_enemies, 1, -1 do
			if imp_enemies[i_imp] == u_key then
				table.remove(imp_enemies, i_imp)
				table.remove(imp_dis, i_imp)

				was_imp = true

				break
			end
		end

		local i_imp = #imp_dis

		while i_imp > 0 do
			if imp_dis[i_imp] <= c_dis then
				break
			end

			i_imp = i_imp - 1
		end

		if i_imp < max_nr_imp then
			i_imp = i_imp + 1

			while max_nr_imp <= #imp_enemies do
				local dump_e_key = imp_enemies[#imp_enemies]

				self:_adjust_cop_importance(dump_e_key, -1)
				t_rem(imp_enemies)
				t_rem(imp_dis)
			end

			t_ins(imp_enemies, i_imp, u_key)
			t_ins(imp_dis, i_imp, c_dis)

			if not was_imp then
				imp_adj = imp_adj + 1
			end
		elseif was_imp then
			imp_adj = imp_adj - 1
		end
	end

	if imp_adj ~= 0 then
		self:_adjust_cop_importance(u_key, imp_adj)
	end
end

function GroupAIStateBase:_calculate_difficulty_ratio_hhtacs()
	local ramp = tweak_data.group_ai.difficulty_curve_points
	local diff = self._difficulty_value
	local i = 1

	while diff > (ramp[i] or 1) do
		i = i + 1
	end
		
	local previous_ramp = ramp[i - 1] and ramp[i - 1] or 0
	local next_ramp = ramp[i] and ramp[i] or 1
	local diff_lerp = math.abs(previous_ramp - next_ramp)
	local diff = (self._difficulty_value - previous_ramp) / diff_lerp
	
	self._difficulty_point_index = i
	self._difficulty_ramp = diff
end

function GroupAIStateBase:on_unit_pathing_complete(unit)
	if self._draw_enabled then
		local draw_pos = unit:movement():m_pos()

		self._AI_draw_data.brush_guard:cone(draw_pos + math.UP * 82.5, draw_pos, 60)
	end
end

function GroupAIStateBase:on_unit_pathing_failed(unit)
	if self._draw_enabled then
		local draw_pos = unit:movement():m_pos()

		self._AI_draw_data.brush_act:cone(draw_pos + math.UP * 82.5, draw_pos, 60)
	end
end

function GroupAIStateBase:on_objective_failed(unit, objective)
	if not unit:brain() then
		debug_pause_unit(unit, "[GroupAIStateBase:on_objective_failed] error in extension order", unit)

		local fail_clbk = objective.fail_clbk
		objective.fail_clbk = nil

		unit:brain():set_objective(nil)

		if fail_clbk then
			fail_clbk(unit)
		end

		return
	end

	local new_objective = nil
	local u_key = unit:key()
	local u_data = self._police[u_key]
	local valid_and_alive = u_data and unit:brain():is_active() and not unit:character_damage():dead()

	if unit:brain():objective() == objective then
		if valid_and_alive then
			new_objective = {
				is_default = true,
				scan = true,
				type = "free",
				follow_unit = objective.follow_unit,
				no_arrest = objective.no_arrest,
				grp_objective = objective.grp_objective,
				attitude = objective.attitude or objective.grp_objective and objective.grp_objective.attitude,
			}

			if u_data.assigned_area then
				local seg = unit:movement():nav_tracker():nav_segment()

				self:set_enemy_assigned(self:get_area_from_nav_seg_id(seg), u_key)
			end
		end
	end
	
	if objective then
		local fail_clbk = objective.fail_clbk
		objective.fail_clbk = nil
	end

	if new_objective then
		unit:brain():set_objective(new_objective)
	end

	if fail_clbk then
		fail_clbk(unit)
	end
	
	--if valid_and_alive and u_data.group and not u_data.unit:movement():cool() then
	--	self:_upd_group(u_data.group)
	--end
end

function GroupAIStateBase:report_aggression(unit)
	local u_key = unit:key()
	local u_sighting = self._criminals[u_key]

	if not u_sighting then
		return
	end

	u_sighting.assault_t = self._t
	self:criminal_spotted(u_sighting.unit)
end

function GroupAIStateBase:register_criminal(unit)
	local u_key = unit:key()
	local ext_mv = unit:movement()
	local tracker = ext_mv:nav_tracker()
	local seg = tracker:nav_segment()
	local is_AI = nil

	if unit:base()._tweak_table then
		is_AI = true
	end

	local is_deployable = unit:base().sentry_gun
	local u_sighting = {
		arrest_timeout = -100,
		engaged_force = 0,
		dispatch_t = 0,
		undetected = true,
		unit = unit,
		ai = is_AI,
		tracker = tracker,
		seg = seg,
		area = self:get_area_from_nav_seg_id(seg),
		pos = mvector3.copy(ext_mv:m_pos()),
		m_pos = ext_mv:m_pos(),
		m_det_pos = ext_mv:m_detect_pos(),
		det_t = -100,
		engaged = {},
		important_enemies = not is_AI and {} or nil,
		important_dis = not is_AI and {} or nil,
		is_deployable = is_deployable
	}
	self._criminals[u_key] = u_sighting

	if is_AI then
		self._ai_criminals[u_key] = u_sighting
		u_sighting.so_access = managers.navigation:convert_access_flag(tweak_data.character[unit:base()._tweak_table].access)
	elseif not is_deployable then
		self._player_criminals[u_key] = u_sighting
	end

	if not is_deployable then
		self._char_criminals[u_key] = u_sighting
	end

	if not unit:base().is_local_player then
		managers.enemy:on_criminal_registered(unit)
	end

	if is_AI then
		unit:movement():set_team(self._teams[tweak_data.levels:get_default_team_ID("player")])
	end
end

function GroupAIStateBase:on_criminal_nav_seg_change(unit, nav_seg_id)
	return
end

function GroupAIStateBase:_set_rescue_state(state) --this causes a crash in vanilla randomly
	return
end


function GroupAIStateBase:chk_say_teamAI_combat_chatter(unit)
	if not self:is_detection_persistent() then
		return
	end

	local drama_amount = self._drama_data.amount
	local frequency_lerp = drama_amount
	local delay_tweak = tweak_data.sound.criminal_sound.combat_callout_delay
	local delay = math.lerp(delay_tweak[1], delay_tweak[2], frequency_lerp)
	local delay_t = self._teamAI_last_combat_chatter_t + delay

	if self._t < delay_t then
		return
	end

	local frequency_lerp_clamp = math.clamp(frequency_lerp^2, 0, 1)
	local chance_tweak = tweak_data.sound.criminal_sound.combat_callout_chance
	local chance = math.lerp(chance_tweak[1], chance_tweak[2], frequency_lerp_clamp)

	if chance < math.random() then
		return
	end
	
	self._teamAI_last_combat_chatter_t = self._t
	unit:sound():say("g90", true, true)
end

function GroupAIStateBase:_determine_objective_for_criminal_AI(unit)
	local objective, closest_dis, closest_record = nil
	
	if self._converted_police[unit:key()] then
		local m_key = unit:key()
		local owner
		
		for pl_key, pl_record in pairs(self._player_criminals) do
			if alive(pl_record.unit) and pl_record.minions then
				if pl_record.minions[m_key] then
					owner = pl_record.unit
					break
				end
			end
		end
		
		if owner then
			objective = {
				scan = true,
				is_default = true,
				type = "follow",
				follow_unit = owner
			}
			
			return objective
		end
	end
	
	local ai_pos = (self._ai_criminals[unit:key()] or self._police[unit:key()]).m_pos

	for pl_key, pl_record in pairs(self._player_criminals) do
		if pl_record.status ~= "dead" then
			local my_dis = mvector3.distance(ai_pos, pl_record.m_pos)

			if not closest_dis or my_dis < closest_dis then
				closest_dis = my_dis
				closest_record = pl_record
			end
		end
	end

	if closest_record then
		objective = {
			scan = true,
			is_default = true,
			type = "follow",
			follow_unit = closest_record.unit
		}
	end

	local ai_pos = (self._ai_criminals[unit:key()] or self._police[unit:key()]).m_pos
	local skip_hostage_trade_time_reset = nil

	if not objective and self:is_ai_trade_possible() then
		local guard_time = managers.trade:get_guard_hostage_time()

		if guard_time > 6 then
			local hostage = managers.trade:get_best_hostage(ai_pos)
			skip_hostage_trade_time_reset = hostage

			if hostage and mvector3.distance(ai_pos, hostage.m_pos) > 1500 then
				self._guard_hostage_trade_time_map = self._guard_hostage_trade_time_map or {}
				local time = Application:time()
				local unit_key = unit:key()
				local last_time = self._guard_hostage_trade_time_map[unit_key]

				if not last_time or time > last_time + 7 then
					self._guard_hostage_trade_time_map[unit_key] = time

					return {
						scan = true,
						type = "free",
						stance = "hos",
						nav_seg = hostage.tracker:nav_segment()
					}
				end
			end
		end
	end

	if not skip_hostage_trade_time_reset then
		self._guard_hostage_trade_time_map = nil
	end

	return objective
end

function GroupAIStateBase:register_security_camera(unit, state)
	if not state and (self._security_cameras[unit:key()] or unit:base()._destroyed) then
		if not self._disabled_security_cameras then
			self._disabled_security_cameras = {}
		end
	
		if not unit:base()._destroyed then
			self._disabled_security_cameras[unit:key()] = not state and unit or nil
		else
			self._disabled_security_cameras[unit:key()] = nil
		end
	end
	
	self._security_cameras[unit:key()] = state and unit or nil
end

Hooks:PostHook(GroupAIStateBase, "_clbk_switch_enemies_to_not_cool", "lies_switch_tweaks_for_guards", function(self)
	if not self._set_altered_tweakdatas then
		for u_key, unit_data in pairs(self._police) do
			if unit_data.unit:base()._loudtweakdata then
				unit_data.unit:base():change_and_sync_char_tweak(unit_data.unit:base()._loudtweakdata)
			end
		end
		
		self._set_altered_tweakdatas = true
	end
end)

Hooks:PostHook(GroupAIStateBase, "register_rescueable_hostage", "lies_hrt_reg", function(self, unit, rescue_area)
	local u_key = unit:key()
	local rescue_area = rescue_area or self:get_area_from_nav_seg_id(unit:movement():nav_tracker():nav_segment())
	
	local rescueable_hostages = self._rescueable_hostages or {}
	rescueable_hostages[u_key] = rescue_area
	self._rescueable_hostages = rescueable_hostages
end)


Hooks:PostHook(GroupAIStateBase, "unregister_rescueable_hostage", "lies_hrt_unreg", function(self, u_key)
	local rescueable_hostages = self._rescueable_hostages or {}
	rescueable_hostages[u_key] = nil
	self._rescueable_hostages = rescueable_hostages

end)

function GroupAIStateBase:print_objective(objective)
	if objective then
		log("objective info:")
		
		log(objective.type)
		
		if objective.is_default then
			log("objective is default")
		end
		
		if objective.forced then
			log("forced objective")
		end
		
		if objective.stance then
			log(objective.stance)
		end
		
		if objective.attitude then
			log(objective.attitude)
		end
		
		if objective.path_style then
			log(objective.path_style)
		end
		
		if objective.action then
			log("objective has action type " ..tostring(objective.action.type)..":"..tostring(objective.action.variant))
		end
		
		if objective.element then
			log("objective has element: " .. tostring(objective.element._id))
		end
	else
		log("no objective")
		
		return
	end

	local cmpl_clbk = objective.complete_clbk
	
	if cmpl_clbk then
		log("objective has completion clbk")
	end
	
	local fail_clbk = objective.fail_clbk
	
	if fail_clbk then
		log("objective has fail clbk")
	end
	
	local act_start_clbk = objective.action_start_clbk
	
	if act_start_clbk then
		log("objective has action start clbk")
	end
	
	local ver_clbk = objective.verification_clbk
	
	if ver_clbk then
		log("objective has verification clbk")
	end
	
	local area = objective.area
	
	if area then
		log("objective has area, drawing pillar")
		
		local line = Draw:brush(Color.blue:with_alpha(0.5), 5)
		line:cylinder(area.pos, area.pos + math_up * 1000, 100)
	end
	
	local followup_SO = objective.followup_SO
	
	if followup_SO then
		log("objective has follow up SO")
		
		if followup_SO.type then
			local followup_SO_type_str = followup_SO.type and tostring(followup_SO.type) or "lmao what"
			
			log("f. SO has type: " .. followup_SO_type_str .. "")
		end
	end
	
	local grp_objective = objective.grp_objective
	
	if grp_objective then
		local grp_objective_type_str = grp_objective.type and tostring(grp_objective.type) or "lmao what"
	
		log("objective has group objective!!! type: " .. grp_objective_type_str .. "")
	end
	
	local followup_objective = objective.followup_objective
	
	if followup_objective then
		log("objective has followup objective")
		
		if followup_objective.type then
			local followup_objective_type_str = followup_objective.type and tostring(followup_objective.type) or "lmao what"
			
			log("f. objective has type: " .. followup_objective_type_str .. "")
		end
	end
end