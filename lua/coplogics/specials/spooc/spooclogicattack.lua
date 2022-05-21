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
end

function SpoocLogicAttack.update(data)
	local t = TimerManager:game():time()
	data.t = t
	local unit = data.unit
	local my_data = data.internal_data

	if my_data.spooc_attack then
		if my_data.spooc_attack.action._beating_end_t and my_data.spooc_attack.action._beating_end_t < TimerManager:game():time() then			
			local attention_objects = data.detected_attention_objects

			for u_key, attention_data in pairs(attention_objects) do
				if AIAttentionObject.REACT_SHOOT <= attention_data.reaction then
					if not attention_data.criminal_record or not attention_data.criminal_record.status then
						if attention_data.verified or attention_data.nearly_visible then
							if data.attention_obj.dis < my_data.weapon_range.close then
								SpoocLogicAttack._cancel_spooc_attempt(data, my_data)
								break
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
	end

	if AIAttentionObject.REACT_COMBAT <= data.attention_obj.reaction then
		my_data.want_to_take_cover = SpoocLogicAttack._chk_wants_to_take_cover(data, my_data)

		CopLogicAttack._update_cover(data)
		CopLogicAttack._upd_combat_movement(data)
	end

	CopLogicBase._report_detections(data.detected_attention_objects)
end

function SpoocLogicAttack._chk_wants_to_take_cover(data, my_data)
	if not data.attention_obj or data.attention_obj.reaction < AIAttentionObject.REACT_COMBAT then
		return
	end
	
	if data.spooc_attack_timeout_t and data.t < data.spooc_attack_timeout_t then
		return true
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
			SpoocLogicAttack._upd_aim(data, my_data)
		end
	elseif action_type == "turn" then
		my_data.turning = nil
		
		if action:expired() then
			SpoocLogicAttack._upd_aim(data, my_data)
		end
	elseif action_type == "spooc" then
		data.spooc_attack_timeout_t = TimerManager:game():time() + math.lerp(data.char_tweak.spooc_attack_timeout[1], data.char_tweak.spooc_attack_timeout[2], math.random())
		
		
		if not data.brain._next_grenade_use_t or data.brain._next_grenade_use_t < data.t then
			if action:complete() and data.char_tweak.spooc_attack_use_smoke_chance > 0 and math.random() <= data.char_tweak.spooc_attack_use_smoke_chance then
				managers.groupai:state():detonate_smoke_grenade(data.m_pos + math.UP * 10, data.unit:movement():m_head_pos(), math.lerp(15, 30, math.random()), false)
			end
		end

		my_data.spooc_attack = nil
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