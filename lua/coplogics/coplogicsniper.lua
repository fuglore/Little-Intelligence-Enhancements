local tmp_vec1 = Vector3()

function CopLogicSniper.enter(data, new_logic_name, enter_params)
	CopLogicBase.enter(data, new_logic_name, enter_params)

	local objective = data.objective

	data.unit:brain():cancel_all_pathing_searches()

	local old_internal_data = data.internal_data
	local my_data = {
		unit = data.unit,
		detection = data.char_tweak.detection.recon
	}

	if old_internal_data then
		my_data.turning = old_internal_data.turning
		my_data.firing = old_internal_data.firing
		my_data.shooting = old_internal_data.shooting
		my_data.attention_unit = old_internal_data.attention_unit
		my_data.expected_pos = old_internal_data.expected_pos
		my_data.expected_pos_path = old_internal_data.expected_pos_path
		my_data.expected_pos_last_check_t = old_internal_data.expected_pos_last_check_t
		my_data.start_shoot_t = old_internal_data.start_shoot_t
	end

	data.internal_data = my_data
	local key_str = tostring(data.unit:key())
	my_data.detection_task_key = "CopLogicSniper._upd_enemy_detection" .. key_str
	CopLogicIdle._chk_has_old_action(data, my_data)
	CopLogicBase.queue_task(my_data, my_data.detection_task_key, CopLogicSniper._upd_enemy_detection, data, data.t)

	if objective then
		my_data.wanted_stance = objective.stance
		my_data.wanted_pose = objective.pose
		my_data.attitude = objective.attitude or "avoid"
	end

	data.unit:movement():set_cool(false)

	if my_data ~= data.internal_data then
		return
	end

	data.unit:brain():set_attention_settings({
		cbt = true
	})

	my_data.weapon_range = data.char_tweak.weapon[data.unit:inventory():equipped_unit():base():weapon_tweak_data().usage].range

	if data.char_tweak.weapon[data.unit:inventory():equipped_unit():base():weapon_tweak_data().usage].use_laser then
		data.unit:inventory():equipped_unit():base():set_laser_enabled(true)

		my_data.weapon_laser_on = true

		data.unit:base():prevent_main_bones_disabling(true)
		managers.network:session():send_to_peers_synched("sync_unit_event_id_16", data.unit, "brain", HuskCopBrain._NET_EVENTS.weapon_laser_on)
	end
end

function CopLogicSniper._upd_aim(data, my_data)
	local action_taken = CopLogicAttack.action_taken(data, my_data)
	
	if not my_data.reposition then
		if not action_taken and data.attention_obj and AIAttentionObject.REACT_SHOOT <= data.attention_obj.reaction then
			local focus_enemy = data.attention_obj
			--local m_head_pos = data.m_pos:with_z(data.unit:movement():m_head_pos().z)
			
			local am_crouching = data.unit:anim_data().crouch
			local am_standing = data.unit:anim_data().standing
			local target_pos = focus_enemy.verified_pos
			
			if unit_can_stand and CopLogicSniper._chk_stand_visibility(data.m_pos, target_pos, data.visibility_slotmask)  then
				CopLogicAttack._chk_request_action_stand(data)
			elseif unit_can_crouch and CopLogicSniper._chk_crouch_visibility(data.m_pos, target_pos, data.visibility_slotmask) then
				CopLogicAttack._chk_request_action_crouch(data)
			end
		end
	elseif my_data.reposition and not action_taken then
		local objective = data.objective
		my_data.advance_path = {
			mvector3.copy(data.m_pos),
			mvector3.copy(objective.pos)
		}

		if CopLogicTravel._chk_request_action_walk_to_advance_pos(data, my_data, "walk", objective.rot) then
			action_taken = true
		end
	end
	
	return CopLogicAttack._upd_aim(data, my_data)
end

function CopLogicSniper._chk_crouch_visibility(my_pos, target_pos, slotmask)
	mvector3.set(tmp_vec1, my_pos)
	mvector3.set_z(tmp_vec1, my_pos.z + 82.5)

	local ray = World:raycast("ray", tmp_vec1, target_pos, "slot_mask", slotmask, "ray_type", "ai_vision", "report")

	return not ray
end

function CopLogicSniper._chk_stand_visibility(my_pos, target_pos, slotmask)
	mvector3.set(tmp_vec1, my_pos)
	mvector3.set_z(tmp_vec1, my_pos.z + 145)

	local ray = World:raycast("ray", tmp_vec1, target_pos, "slot_mask", slotmask, "ray_type", "ai_vision", "report")

	return not ray
end

function CopLogicSniper._upd_enemy_detection(data)
	managers.groupai:state():on_unit_detection_updated(data.unit)

	data.t = TimerManager:game():time()
	local my_data = data.internal_data
	
	if my_data.has_old_action or my_data.old_action_advancing then
		CopLogicAttack._upd_stop_old_action(data, my_data)
	end
	
	local min_reaction = AIAttentionObject.REACT_AIM
	local delay = CopLogicBase._upd_attention_obj_detection(data, min_reaction, nil)
	local new_attention, new_prio_slot, new_reaction = CopLogicIdle._get_priority_attention(data, data.detected_attention_objects, CopLogicSniper._chk_reaction_to_attention_object)
	local old_att_obj = data.attention_obj

	CopLogicBase._set_attention_obj(data, new_attention, new_reaction)

	if new_reaction and AIAttentionObject.REACT_SCARED <= new_reaction then
		local objective = data.objective
		local wanted_state = nil
		local allow_trans, obj_failed = CopLogicBase.is_obstructed(data, objective, nil, new_attention)

		if allow_trans and obj_failed then
			wanted_state = CopLogicBase._get_logic_state_from_reaction(data)
		end

		if wanted_state and wanted_state ~= data.name then
			if obj_failed then
				data.objective_failed_clbk(data.unit, data.objective)
			end

			if my_data == data.internal_data then
				CopLogicBase._exit(data.unit, wanted_state)
			end

			CopLogicBase._report_detections(data.detected_attention_objects)

			return
		end
	end

	CopLogicSniper._upd_aim(data, my_data)

	delay = data.important and 0 or delay

	CopLogicBase.queue_task(my_data, my_data.detection_task_key, CopLogicSniper._upd_enemy_detection, data, data.t + delay)
	CopLogicBase._report_detections(data.detected_attention_objects)
end

function CopLogicSniper.action_complete_clbk(data, action)
	local action_type = action:type()
	local my_data = data.internal_data

	if action_type == "turn" then
		my_data.turning = nil
		
		if action:expired() then
			CopLogicSniper._upd_aim(data, my_data)
		end
	elseif action_type == "shoot" then
		my_data.shooting = nil
	elseif action_type == "walk" then
		my_data.advacing = nil
		my_data.advancing = nil
		my_data.old_action_advancing = nil

		if action:expired() then
			my_data.reposition = nil
			CopLogicSniper._upd_aim(data, my_data)
		end
	elseif (action_type == "hurt" or action_type == "healed") and data.objective and data.objective.pos then
		if action:expired() then
			my_data.reposition = true
		end
	end
end