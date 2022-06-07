function SpoocLogicAttack.enter(data, new_logic_name, enter_params)
	CopLogicBase.enter(data, new_logic_name, enter_params)
	data.unit:brain():cancel_all_pathing_searches()

	local old_internal_data = data.internal_data
	local my_data = {
		unit = data.unit
	}
	data.internal_data = my_data
	my_data.detection = data.char_tweak.detection.combat

	if old_internal_data then
		my_data.turning = old_internal_data.turning
		my_data.firing = old_internal_data.firing
		my_data.shooting = old_internal_data.shooting
		my_data.attention_unit = old_internal_data.attention_unit

		CopLogicAttack._set_best_cover(data, my_data, old_internal_data.best_cover)
		CopLogicAttack._set_nearest_cover(my_data, old_internal_data.nearest_cover)
	end

	local key_str = tostring(data.key)

	my_data.detection_task_key = "CopLogicAttack._upd_enemy_detection" .. key_str

	CopLogicBase.queue_task(my_data, my_data.detection_task_key, CopLogicAttack._upd_enemy_detection, data, data.t)
	CopLogicIdle._chk_has_old_action(data, my_data)

	local objective = data.objective

	if objective then
		my_data.attitude = data.objective.attitude or "avoid"
	end

	my_data.weapon_range = data.char_tweak.weapon[data.unit:inventory():equipped_unit():base():weapon_tweak_data().usage].range

	data.unit:movement():set_cool(false)

	if my_data ~= data.internal_data then
		return
	end

	my_data.cover_test_step = 1
	data.spooc_attack_timeout_t = data.spooc_attack_timeout_t or 0

	data.unit:brain():set_attention_settings({
		cbt = true
	})
	
	data.unit:brain():set_update_enabled_state(true)
end

function SpoocLogicAttack.update(data)
	local t = TimerManager:game():time()
	data.t = t
	local unit = data.unit
	local my_data = data.internal_data

	if my_data.spooc_attack then
		local action_data = my_data.spooc_attack.action
		
		if action_data._flying_strike_data and not action_data._ext_anim.act and action_data._stroke_t and data.t - action_data._stroke_t > 1 or action_data._beating_end_t and action_data._beating_end_t < TimerManager:game():time() then
			if action_data._flying_strike_data then
				SpoocLogicAttack._cancel_spooc_attempt(data, my_data)
			elseif action_data._beating_end_t and action_data._beating_end_t + 12 < TimerManager:game():time() then
				SpoocLogicAttack._cancel_spooc_attempt(data, my_data)
			else
				local attention_objects = data.detected_attention_objects

				for u_key, attention_data in pairs(attention_objects) do
					if AIAttentionObject.REACT_SHOOT <= attention_data.reaction then
						if not attention_data.criminal_record or not attention_data.criminal_record.status then
							if attention_data.verified or attention_data.nearly_visible then
								if attention_data.dis < my_data.weapon_range.close then
									SpoocLogicAttack._cancel_spooc_attempt(data, my_data)
									break
								end
							end
						end
					end
				end
			end
		end
		
		if my_data.spooc_attack then
			if data.internal_data == my_data then
				CopLogicBase._report_detections(data.detected_attention_objects)
			end
		
			return
		end
	end

	if my_data.has_old_action then
		CopLogicAttack._upd_stop_old_action(data, my_data)

		if my_data.has_old_action then
			return
		end
	end

	if CopLogicIdle._chk_relocate(data) then
		return
	end

	CopLogicAttack._process_pathing_results(data, my_data)

	if not data.attention_obj or data.attention_obj.reaction < AIAttentionObject.REACT_AIM then
		CopLogicAttack._upd_enemy_detection(data, true)

		if my_data ~= data.internal_data or not data.attention_obj then
			return
		end
	end

	SpoocLogicAttack._upd_spooc_attack(data, my_data)

	if my_data.spooc_attack then
		return
	elseif my_data.has_played_warning then
		if data.spooc_attack_timeout_t and data.t > data.spooc_attack_timeout_t then
			my_data.has_played_warning = nil
		end
	end

	if AIAttentionObject.REACT_COMBAT <= data.attention_obj.reaction then
		my_data.want_to_take_cover = SpoocLogicAttack._chk_wants_to_take_cover(data, my_data)

		CopLogicAttack._update_cover(data)
		CopLogicAttack._upd_combat_movement(data)
	end

	CopLogicBase._report_detections(data.detected_attention_objects)
end

function SpoocLogicAttack._chk_wants_to_take_cover(data, my_data)
	local ammo_max, ammo = data.unit:inventory():equipped_unit():base():ammo_info()

	if not my_data.spooc_attack then	
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
	
	if data.spooc_attack_timeout_t and data.t < data.spooc_attack_timeout_t then
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

function SpoocLogicAttack.action_complete_clbk(data, action)
	local action_type = action:type()
	local my_data = data.internal_data

	if action_type == "walk" then
		my_data.advancing = nil

		if my_data.surprised then
			my_data.surprised = false
		elseif my_data.moving_to_cover then
			if action:expired() then
				my_data.in_cover = my_data.moving_to_cover

				CopLogicAttack._set_nearest_cover(my_data, my_data.in_cover)

				my_data.cover_enter_t = data.t
				my_data.cover_sideways_chk = nil
			end

			my_data.moving_to_cover = nil
		elseif my_data.walking_to_cover_shoot_pos then
			my_data.walking_to_cover_shoot_pos = nil
		end
	elseif action_type == "shoot" then
		my_data.shooting = nil
	elseif action_type == "act" then	
		if action:expired() then
			if my_data.reacting then
				my_data.has_played_warning = data.t
				my_data.reacting = nil
			end
		
			SpoocLogicAttack._upd_aim(data, my_data)
		end
	elseif action_type == "turn" then
		my_data.turning = nil
		
		if action:expired() then
			SpoocLogicAttack._upd_aim(data, my_data)
		end
	elseif action_type == "spooc" then
		data.spooc_attack_timeout_t = TimerManager:game():time() + math.lerp(data.char_tweak.spooc_attack_timeout[1], data.char_tweak.spooc_attack_timeout[2], math.random())

		data.brain:_chk_use_cover_grenade(unit)

		my_data.spooc_attack = nil
		my_data.has_played_warning = nil
	elseif action_type == "dodge" then
		local timeout = action:timeout()

		if timeout then
			data.dodge_timeout_t = TimerManager:game():time() + math.lerp(timeout[1], timeout[2], math.random())
		end

		CopLogicAttack._cancel_cover_pathing(data, my_data)

		if action:expired() then
			SpoocLogicAttack._upd_aim(data, my_data)
		end
	end
end

function SpoocLogicAttack._chk_play_charge_spooc_sound(data, my_data, focus_enemy)
	if not my_data.spooc_attack and (not data.last_spooc_snd_play_t or data.t - data.last_spooc_snd_play_t > 6) and focus_enemy.verified_dis < 2500 and math.abs(data.m_pos.z - focus_enemy.m_pos.z) < 300 then
		data.last_spooc_snd_play_t = data.t

		data.unit:sound():play("clk_c01x_plu", nil, true)
	end
end

function SpoocLogicAttack._upd_spooc_attack(data, my_data)
	local focus_enemy = data.attention_obj

	if focus_enemy.nav_tracker and focus_enemy.is_person and focus_enemy.criminal_record and not focus_enemy.criminal_record.status and not my_data.spooc_attack and AIAttentionObject.REACT_SHOOT <= focus_enemy.reaction and data.spooc_attack_timeout_t < data.t and focus_enemy.verified_dis < (my_data.want_to_take_cover and 1500 or 2500) and not data.unit:movement():chk_action_forbidden("walk") and not SpoocLogicAttack._is_last_standing_criminal(focus_enemy) and not focus_enemy.unit:movement():zipline_unit() and focus_enemy.unit:movement():is_SPOOC_attack_allowed() then
		if focus_enemy.verified and ActionSpooc.chk_can_start_spooc_sprint(data.unit, focus_enemy.unit) and not data.unit:raycast("ray", data.unit:movement():m_head_pos(), focus_enemy.m_head_pos, "slot_mask", managers.slot:get_mask("bullet_impact_targets_no_criminals"), "ignore_unit", focus_enemy.unit, "report") then
			if my_data.attention_unit ~= focus_enemy.u_key then
				CopLogicBase._set_attention(data, focus_enemy)

				my_data.attention_unit = focus_enemy.u_key
			end
			
			if LIES.settings.specialdelay then
				SpoocLogicAttack._chk_play_charge_spooc_sound(data, my_data, focus_enemy)
			end
			
			if not LIES.settings.specialdelay or my_data.has_played_warning then
				local action = SpoocLogicAttack._chk_request_action_spooc_attack(data, my_data)

				if action then
					my_data.spooc_attack = {
						start_t = data.t,
						target_u_data = focus_enemy,
						action = action
					}

					return true
				end
			elseif not my_data.turning then
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

		if ActionSpooc.chk_can_start_flying_strike(data.unit, focus_enemy.unit) then
			if my_data.attention_unit ~= focus_enemy.u_key then
				CopLogicBase._set_attention(data, focus_enemy)

				my_data.attention_unit = focus_enemy.u_key
			end
			
			if LIES.settings.specialdelay then
				SpoocLogicAttack._chk_play_charge_spooc_sound(data, my_data, focus_enemy)
			end
			
			if not LIES.settings.specialdelay or my_data.has_played_warning then
				local action = SpoocLogicAttack._chk_request_action_spooc_attack(data, my_data, true)

				if action then
					my_data.spooc_attack = {
						start_t = data.t,
						target_u_data = focus_enemy,
						action = action
					}

					return true
				end
			elseif not my_data.turning then
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
	end
end