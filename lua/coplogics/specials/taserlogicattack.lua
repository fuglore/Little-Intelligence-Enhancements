function TaserLogicAttack.queued_update(data)
	local my_data = data.internal_data

	local delay = TaserLogicAttack._upd_enemy_detection(data)

	if my_data ~= data.internal_data then
		CopLogicBase._report_detections(data.detected_attention_objects)

		return
	elseif not data.attention_obj then
		delay = 0.5 + delay * 1.5 
	
		CopLogicBase.queue_task(my_data, my_data.update_task_key, TaserLogicAttack.queued_update, data, data.t + delay, data.important)
		CopLogicBase._report_detections(data.detected_attention_objects)

		return
	end

	if my_data.has_old_action then
		CopLogicAttack._upd_stop_old_action(data, my_data)
		
		if my_data.has_old_action then
			CopLogicBase.queue_task(my_data, my_data.update_task_key, TaserLogicAttack.queued_update, data, data.t + delay, data.important)

			return
		end
	end

	if CopLogicIdle._chk_relocate(data) then
		return
	end

	CopLogicAttack._update_cover(data)

	local unit = data.unit
	local objective = data.objective
	local focus_enemy = data.attention_obj
	local action_taken = my_data.turning or data.unit:movement():chk_action_forbidden("walk") or my_data.moving_to_cover or my_data.walking_to_cover_shoot_pos or my_data.acting or my_data.tasing

	if my_data.tasing then
		action_taken = action_taken or CopLogicAttack._chk_request_action_turn_to_enemy(data, my_data, data.m_pos, focus_enemy.m_pos)
		
		delay = 0.5 + delay * 1.5 
	
		CopLogicBase.queue_task(my_data, my_data.update_task_key, TaserLogicAttack.queued_update, data, data.t + delay, data.important)
		CopLogicBase._report_detections(data.detected_attention_objects)

		return
	end
	
	my_data.attitude = data.objective and data.objective.attitude or "avoid"

	CopLogicAttack._process_pathing_results(data, my_data)

	if AIAttentionObject.REACT_COMBAT <= data.attention_obj.reaction and not data.unit:movement():chk_action_forbidden("walk") then
		my_data.want_to_take_cover = TaserLogicAttack._chk_wants_to_take_cover(data, my_data)
		
		--log(tostring(my_data.attitude))

		CopLogicAttack._update_cover(data)
		CopLogicAttack._upd_combat_movement(data)
	end

	CopLogicBase.queue_task(my_data, my_data.update_task_key, TaserLogicAttack.queued_update, data, data.t + delay, data.important)
	CopLogicBase._report_detections(data.detected_attention_objects)
end

function TaserLogicAttack._chk_wants_to_take_cover(data, my_data)
	local ammo_max, ammo = data.unit:inventory():equipped_unit():base():ammo_info()

	if not my_data.tasing then	
		if ammo <= 0 then
			local has_walk_actions = my_data.advancing or my_data.walking_to_cover_shoot_pos or my_data.moving_to_cover or my_data.surprised
		
			if has_walk_actions and not data.unit:movement():chk_action_forbidden("walk") then
				if not data.unit:anim_data().reload then
					local new_action = {
						body_part = 2,
						type = "idle"
					}

					data.unit:brain():action_request(new_action)
				
					CopLogicAttack._cancel_cover_pathing(data, my_data)
					CopLogicAttack._cancel_charge(data, my_data)
				end
			end
			
			return true
		end
	end

	if not data.attention_obj or data.attention_obj.reaction < AIAttentionObject.REACT_COMBAT then
		return
	end
	
	if data.tase_delay_t and data.tase_delay_t > data.t then
		return true
	end
	
	local aggro_level = LIES.settings.enemy_aggro_level
	
	if aggro_level > 3 then
		return
	end

	if data.is_suppressed or my_data.attitude ~= "engage" or aggro_level < 3 and data.unit:anim_data().reload then
		return true
	end

	if aggro_level < 3 then
		if ammo / ammo_max < 0.2 then
			return true
		end
	end
	
	return CopLogicAttack._chk_wants_to_take_cover(data, my_data)
end

function TaserLogicAttack._upd_aim(data, my_data, reaction)
	local focus_enemy = data.attention_obj
	local tase = reaction == AIAttentionObject.REACT_SPECIAL_ATTACK
	
	if focus_enemy then
		if tase then
			local has_walk_actions = my_data.advancing or my_data.walking_to_cover_shoot_pos or my_data.moving_to_cover
		
			if tase and has_walk_actions and not data.unit:movement():chk_action_forbidden("walk") then
				local new_action = {
					body_part = 2,
					type = "idle"
				}

				data.unit:brain():action_request(new_action)
			end
			
			local proceed = LIES.settings.enemy_reaction_level > 2 or my_data.has_played_warning
			
			if proceed then	
				if (not my_data.tasing or my_data.tasing.target_u_data ~= focus_enemy) and not data.unit:movement():chk_action_forbidden("walk") and not focus_enemy.unit:movement():zipline_unit() then
					if my_data.attention_unit ~= focus_enemy.u_key then
						CopLogicBase._set_attention(data, focus_enemy)

						my_data.attention_unit = focus_enemy.u_key
					end

					local tase_action = {
						body_part = 3,
						type = "tase"
					}

					if data.unit:brain():action_request(tase_action) then
						my_data.tasing = {
							target_u_data = focus_enemy,
							target_u_key = focus_enemy.u_key,
							start_t = data.t
						}
						
						CopLogicAttack.aim_allow_fire(true, true, data, my_data)
						CopLogicAttack._cancel_charge(data, my_data)
						managers.groupai:state():on_tase_start(data.key, focus_enemy.u_key)
					end
				end
				
				if data.logic.chk_should_turn(data, my_data) then
					local enemy_pos = focus_enemy.m_pos

					CopLogicAttack._chk_request_action_turn_to_enemy(data, my_data, data.m_pos, enemy_pos)
				end
			else
				if not my_data.tasing and (not data.last_charge_snd_play_t or data.t - data.last_charge_snd_play_t > 4) and focus_enemy.verified_dis < 3000 and math.abs(data.m_pos.z - focus_enemy.m_pos.z) < 300 then
					data.last_charge_snd_play_t = data.t

					data.unit:sound():play("taser_charge", nil, true)
				end
			
				if my_data.attention_unit ~= focus_enemy.u_key then
					CopLogicBase._set_attention(data, focus_enemy)

					my_data.attention_unit = focus_enemy.u_key
				end
			
				if data.logic.chk_should_turn(data, my_data) then
					local enemy_pos = focus_enemy.m_pos

					CopLogicAttack._chk_request_action_turn_to_enemy(data, my_data, data.m_pos, enemy_pos)
				end
				
				if not my_data.turning then
					if not data.unit:movement():chk_action_forbidden("walk") then
						local action_data = {
							variant = "surprised",
							body_part = 1,
							type = "act",
							blocks = {
								action = -1,
								walk = -1
							}
						}

						my_data.reacting = data.unit:brain():action_request(action_data)
					end
				end
			end
		else
			if my_data.tasing then
				local new_action = {
					body_part = 3,
					type = "idle"
				}

				data.unit:brain():action_request(new_action)
			end	
		
			CopLogicAttack._upd_aim(data, my_data)
		end
	end
end

function TaserLogicAttack._chk_reaction_to_attention_object(data, attention_data, stationary)
	local reaction = CopLogicIdle._chk_reaction_to_attention_object(data, attention_data, stationary)

	if reaction < AIAttentionObject.REACT_SHOOT or not attention_data.criminal_record or not attention_data.is_person then
		return reaction
	end
	
	if data.tase_delay_t and data.tase_delay_t > data.t then
		return AIAttentionObject.REACT_COMBAT
	end
	
	if attention_data.is_human_player and not attention_data.unit:movement():is_taser_attack_allowed() then
		return AIAttentionObject.REACT_COMBAT
	end

	if (attention_data.is_human_player or not attention_data.unit:movement():chk_action_forbidden("hurt")) and attention_data.verified and attention_data.verified_dis < data.internal_data.tase_distance * 0.9 then
		local vis_ray = data.unit:raycast("ray", data.unit:movement():m_head_pos(), attention_data.m_head_pos, "slot_mask", managers.slot:get_mask("bullet_impact_targets_no_criminals"), "sphere_cast_radius", 30, "ignore_unit", attention_data.unit, "report")
			
		if not vis_ray then
			return AIAttentionObject.REACT_SPECIAL_ATTACK
		end
		
		return AIAttentionObject.REACT_COMBAT
	end

	return reaction
end

function TaserLogicAttack._upd_enemy_detection(data)
	managers.groupai:state():on_unit_detection_updated(data.unit)

	data.t = TimerManager:game():time()
	local my_data = data.internal_data
	local min_reaction = AIAttentionObject.REACT_AIM

	local delay = CopLogicBase._upd_attention_obj_detection(data, min_reaction, nil)

	local under_multiple_fire = nil

	for key, enemy_data in pairs(data.detected_attention_objects) do
		if enemy_data.dmg_t and data.t - enemy_data.dmg_t < 1.2 then
			under_multiple_fire = (under_multiple_fire or 0) + 1

			if under_multiple_fire > 2 then
				under_multiple_fire = true

				break
			end
		end
	end

	local find_new_focus_enemy = nil
	local tasing = my_data.tasing
	local tased_u_key = tasing and tasing.target_u_key
	local tase_in_effect = tasing and tasing.target_u_data.unit:movement():tased()

	if tase_in_effect or tasing and data.t - tasing.start_t < math.max(1, data.char_tweak.weapon.is_rifle.aim_delay_tase[2] * 1.5) then
		if under_multiple_fire then
			find_new_focus_enemy = true
		end
	else
		find_new_focus_enemy = true
	end

	if not find_new_focus_enemy then
		return delay
	end

	local new_attention, new_prio_slot, new_reaction = CopLogicIdle._get_priority_attention(data, data.detected_attention_objects, TaserLogicAttack._chk_reaction_to_attention_object)
	local old_att_obj = data.attention_obj

	CopLogicBase._set_attention_obj(data, new_attention, new_reaction)
	CopLogicAttack._chk_exit_attack_logic(data, new_reaction)

	if my_data ~= data.internal_data then
		return
	end

	if new_attention then
		if old_att_obj then
			if old_att_obj.u_key ~= new_attention.u_key then
				CopLogicAttack._cancel_charge(data, my_data)

				if not data.unit:movement():chk_action_forbidden("walk") then
					CopLogicAttack._cancel_walking_to_cover(data, my_data)
				end

				CopLogicAttack._set_best_cover(data, my_data, nil)
				TaserLogicAttack._chk_play_charge_weapon_sound(data, my_data, new_attention)
			end
		else
			TaserLogicAttack._chk_play_charge_weapon_sound(data, my_data, new_attention)
		end
	elseif old_att_obj then
		CopLogicAttack._cancel_charge(data, my_data)
	end

	TaserLogicAttack._upd_aim(data, my_data, new_reaction)
	
	return delay
end


function TaserLogicAttack._chk_play_charge_weapon_sound(data, my_data, focus_enemy)
	if not my_data.tasing and (not data.last_charge_snd_play_t or data.t - data.last_charge_snd_play_t > math.lerp(15, 30, focus_enemy.verified_dis / 3000)) and focus_enemy.verified_dis < 3000 and math.abs(data.m_pos.z - focus_enemy.m_pos.z) < 300 then
		data.last_charge_snd_play_t = data.t

		data.unit:sound():play("taser_charge", nil, true)
	end
end

function TaserLogicAttack.action_complete_clbk(data, action)
	local my_data = data.internal_data
	local action_type = action:type()

	if action_type == "walk" then
		my_data.advancing = nil
		my_data.in_cover = nil
		
		CopLogicAttack._cancel_cover_pathing(data, my_data)
		CopLogicAttack._cancel_charge(data, my_data)
		
		if my_data.surprised then
			my_data.surprised = false
		elseif my_data.moving_to_cover then
			if action:expired() then
				my_data.in_cover = my_data.moving_to_cover
				my_data.cover_enter_t = data.t
				my_data.cover_test_step = 1
			end

			my_data.moving_to_cover = nil
		elseif my_data.walking_to_cover_shoot_pos then
			my_data.walking_to_cover_shoot_pos = nil
			my_data.at_cover_shoot_pos = true
		end
		
		if action:expired() then
			data.logic._upd_aim(data, my_data) --on finishing a walk action, enemies will try to turn to attention at the end of it
			data.logic._upd_combat_movement(data)
		end
	elseif action_type == "shoot" then
		my_data.shooting = nil
	elseif action_type == "turn" then
		my_data.turning = nil
		
		if action:expired() then
			data.logic._upd_aim(data, my_data)
		end
	elseif action_type == "heal" then
		if action:expired() then
			CopLogicAttack._cancel_cover_pathing(data, my_data)
		
			data.logic._upd_aim(data, my_data)
		end
	elseif action_type == "hurt" or action_type == "healed" then
		CopLogicAttack._cancel_cover_pathing(data, my_data)

		if data.is_converted or data.important and action:expired() and not CopLogicBase.chk_start_action_dodge(data, "hit") then
			data.logic._upd_aim(data, my_data)
		end
	elseif action_type == "dodge" then
		local timeout = action:timeout()

		if timeout then
			data.dodge_timeout_t = TimerManager:game():time() + math.lerp(timeout[1], timeout[2], math.random())
		end

		CopLogicAttack._cancel_cover_pathing(data, my_data)

		if action:expired() then
			data.logic._upd_aim(data, my_data)
		end
	elseif action_type == "act" then	
		if action:expired() then
			if my_data.reacting then
				my_data.has_played_warning = data.t
				my_data.reacting = nil
			end
		
			data.logic._upd_aim(data, my_data)
		end
	elseif action_type == "tase" then
		if action:expired() and my_data.tasing then
			local record = managers.groupai:state():criminal_record(my_data.tasing.target_u_key)

			if record and record.status and record.status ~= "electrified" then
				data.tase_delay_t = TimerManager:game():time() + 45
			end
		end

		managers.groupai:state():on_tase_end(my_data.tasing.target_u_key)
		
		my_data.has_played_warning = nil
		my_data.tasing = nil
	end
end