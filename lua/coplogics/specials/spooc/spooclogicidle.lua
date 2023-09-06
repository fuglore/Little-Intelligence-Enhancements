local hide_anims = {
	e_so_sneak_wait_crh = true,
	e_so_sneak_wait_crh_var2 = true,
	e_so_sneak_wait_crh_var3 = true,
	e_so_sneak_wait_stand = true,
	e_so_hide_under_car_enter = true,
	e_so_hide_2_5m_vent_enter = true,
	e_so_hide_behind_door_enter = true,
	e_so_hide_ledge_enter = true
}

function SpoocLogicIdle._upd_enemy_detection(data)
	managers.groupai:state():on_unit_detection_updated(data.unit)

	data.t = TimerManager:game():time()
	local my_data = data.internal_data
	local min_reaction = not data.cool and AIAttentionObject.REACT_SCARED
	CopLogicBase._upd_attention_obj_detection(data, min_reaction, nil)
	
	local delay = 0
	
	if not managers.groupai:state():whisper_mode() then
		delay = (data.unit:anim_data().hide or data.unit:anim_data().hide_loop) and 0.5 or data.important and 0.7 or 1.4
	end
	
	local new_attention, new_prio_slot, new_reaction = CopLogicIdle._get_priority_attention(data, data.detected_attention_objects)

	CopLogicBase._set_attention_obj(data, new_attention, new_reaction)

	if new_reaction and AIAttentionObject.REACT_SUSPICIOUS < new_reaction then
		local objective = data.objective
		local wanted_state = nil
		local allow_trans, obj_failed = CopLogicBase.is_obstructed(data, objective, nil, new_attention)

		if allow_trans then
			wanted_state = CopLogicBase._get_logic_state_from_reaction(data)
		end

		if wanted_state and wanted_state ~= data.name then
			if obj_failed then
				data.objective_failed_clbk(data.unit, data.objective)
			end

			if my_data == data.internal_data then
				CopLogicBase._exit(data.unit, wanted_state)
			end
		end
	end

	if my_data == data.internal_data then
		CopLogicBase._chk_call_the_police(data)

		if my_data ~= data.internal_data then
			return delay
		end
	end

	SpoocLogicIdle._chk_exit_hiding(data)

	if my_data ~= data.internal_data then
		return delay
	end

	return delay
end

function SpoocLogicIdle._exit_hiding(data)
	if data.unit:anim_data().to_idle then
		return
	end

	--some hiding actions block out "idle/action" meaning that the cloaker cant get out when hiding, do it like this instead
	local action = {
		variant = "idle",
		body_part = 1,
		type = "act",
		blocks = {
			heavy_hurt = -1,
			idle = -1,
			action = -1,
			turn = -1,
			light_hurt = -1,
			walk = -1,
			fire_hurt = -1,
			hurt = -1,
			expl_hurt = -1
		}
	}

	data.unit:brain():action_request(action)
	data.unit:brain():set_objective()
end

function SpoocLogicIdle.damage_clbk(data, damage_info)
	local res = SpoocLogicIdle.super.damage_clbk(data, damage_info)
	
	local hiding = data.unit:anim_data().hide_loop or data.unit:anim_data().hide
	
	if not hiding then
		local act_act = data.unit:movement():get_action(1)
		
		if act_act and act_act:type() == "act" then
			local variant = act_act._action_desc.variant
			
			if hide_anims[variant] then
				hiding = true
			end
		end
	end

	if hiding then
		SpoocLogicIdle._exit_hiding(data)
	end

	return res
end

function SpoocLogicIdle.exit(data, new_logic_name, enter_params)
	local hiding = data.unit:anim_data().hide_loop or data.unit:anim_data().hide
	
	if not hiding then
		local act_act = data.unit:movement():get_action(1)
		
		if act_act and act_act:type() == "act" then
			local variant = act_act._action_desc.variant
			
			if hide_anims[variant] then
				hiding = true
			end
		end
	end
	
	if hiding then
		local action = {
			variant = "idle",
			body_part = 1,
			type = "act",
			blocks = {
				heavy_hurt = -1,
				idle = -1,
				action = -1,
				turn = -1,
				light_hurt = -1,
				walk = -1,
				fire_hurt = -1,
				hurt = -1,
				expl_hurt = -1
			}
		}

		data.unit:brain():action_request(action)
	end
	
	CopLogicBase.exit(data, new_logic_name, enter_params)

	local my_data = data.internal_data

	data.unit:brain():cancel_all_pathing_searches()
	CopLogicBase.cancel_queued_tasks(my_data)
	CopLogicBase.cancel_delayed_clbks(my_data)

	if my_data.best_cover then
		managers.navigation:release_cover(my_data.best_cover[1])
	end

	if my_data.nearest_cover then
		managers.navigation:release_cover(my_data.nearest_cover[1])
	end

	data.brain:rem_pos_rsrv("path")
end

function SpoocLogicIdle._chk_exit_hiding(data)
	local hiding = data.unit:anim_data().hide_loop or data.unit:anim_data().hide
	
	if not hiding then
		local act_act = data.unit:movement():get_action(1)
		
		if act_act and act_act:type() == "act" then
			local variant = act_act._action_desc.variant
			
			if hide_anims[variant] then
				hiding = true
			end
		end
	end

	if hiding then		
		for u_key, attention_data in pairs(data.detected_attention_objects) do
			if data.enemy_slotmask and attention_data.unit:in_slot(data.enemy_slotmask) then				
				if attention_data.dis < 1500 and (attention_data.verified or attention_data.nearly_visible or attention_data.verified_t) then
					SpoocLogicIdle._exit_hiding(data)
				elseif attention_data.dis < 700 then
					if attention_data.nav_tracker then
						local my_nav_seg_id = data.unit:movement():nav_tracker():nav_segment()
						local enemy_areas = managers.groupai:state():get_areas_from_nav_seg_id(attention_data.nav_tracker:nav_segment())

						for _, area in ipairs(enemy_areas) do
							if area.nav_segs[my_nav_seg_id] then
								SpoocLogicIdle._exit_hiding(data)

								break
							end
						end
					end
				end
			end
		end
	end
end