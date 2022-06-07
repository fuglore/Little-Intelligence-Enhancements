local mvec3_set = mvector3.set
local mvec3_set_z = mvector3.set_z
local mvec3_sub = mvector3.subtract
local mvec3_dir = mvector3.direction
local mvec3_dot = mvector3.dot
local mvec3_dis = mvector3.distance
local mvec3_dis_sq = mvector3.distance_sq
local mvec3_lerp = mvector3.lerp
local mvec3_norm = mvector3.normalize
local mvec3_add = mvector3.add
local mvec3_mul = mvector3.multiply
local mvec3_len_sq = mvector3.length_sq
local mvec3_cpy = mvector3.copy
local mvec3_set_length = mvector3.set_length
local mvec3_step = mvector3.step
local mvec3_rotate_with = mvector3.rotate_with
local temp_vec1 = Vector3()
local temp_vec2 = Vector3()
local temp_vec3 = Vector3()
local math_lerp = math.lerp
local math_random = math.random
local math_up = math.UP
local math_abs = math.abs
local math_clamp = math.clamp
local math_min = math.min
local math_max = math.max
local math_sign = math.sign
local mvec3_cpy = mvector3.copy
local mvec3_not_equal = mvector3.not_equal
local math_abs = math.abs
local AI_REACT_IDLE = AIAttentionObject.REACT_IDLE
local AI_REACT_SCARED = AIAttentionObject.REACT_SCARED
local AI_REACT_AIM = AIAttentionObject.REACT_AIM
local AI_REACT_SHOOT = AIAttentionObject.REACT_SHOOT
local AI_REACT_COMBAT = AIAttentionObject.REACT_COMBAT
local AI_REACT_SPECIAL_ATTACK = AIAttentionObject.REACT_SPECIAL_ATTACK

function BossLogicAttack.enter(data, new_logic_name, enter_params)
	CopLogicBase.enter(data, new_logic_name, enter_params)

	local brain_ext = data.brain

	brain_ext:cancel_all_pathing_searches()

	local unit = data.unit
	local char_tweak = data.char_tweak
	local old_internal_data = data.internal_data
	local new_internal_data = {}
	data.internal_data = new_internal_data
	new_internal_data.unit = unit
	new_internal_data.detection = char_tweak.detection.combat

	if old_internal_data then
		new_internal_data.turning = old_internal_data.turning
		new_internal_data.firing = old_internal_data.firing
		new_internal_data.shooting = old_internal_data.shooting
		new_internal_data.attention_unit = old_internal_data.attention_unit
	end

	if data.cool then
		unit:movement():set_cool(false)

		if new_internal_data ~= data.internal_data then
			return
		end
	end

	if not new_internal_data.shooting then
		local new_stance = nil
		local allowed_stances = char_tweak.allowed_stances

		if not allowed_stances or allowed_stances.hos then
			new_stance = "hos"
		elseif allowed_stances.cbt then
			new_stance = "cbt"
		end

		if new_stance then
			data.unit:movement():set_stance(new_stance)

			if new_internal_data ~= data.internal_data then
				return
			end
		end
	end

	local equipped_weap = unit:inventory():equipped_unit()

	if equipped_weap then
		local weap_usage = equipped_weap:base():weapon_tweak_data().usage
		new_internal_data.weapon_range = weap_usage and char_tweak.weapon[weap_usage].range
	end

	local objective = data.objective
	new_internal_data.attitude = objective and objective.attitude or "engage"
	local key_str = tostring(data.key)

	CopLogicIdle._chk_has_old_action(data, new_internal_data)

	if objective and (objective.action_duration or objective.action_timeout_t and data.t < objective.action_timeout_t) then
		new_internal_data.action_timeout_clbk_id = "CopLogicIdle_action_timeout" .. key_str
		local action_timeout_t = objective.action_timeout_t or data.t + objective.action_duration
		objective.action_timeout_t = action_timeout_t

		CopLogicBase.add_delayed_clbk(new_internal_data, new_internal_data.action_timeout_clbk_id, callback(CopLogicIdle, CopLogicIdle, "clbk_action_timeout", data), action_timeout_t)
	end

	brain_ext:set_attention_settings({
		cbt = true
	})
	brain_ext:set_update_enabled_state(true)

	if data.char_tweak.throwable then
		new_internal_data.last_seen_throwable_pos = Vector3()
	end
end

function BossLogicAttack._pathing_complete_clbk(data)
	local my_data = data.internal_data

	if my_data.pathing_to_chase_pos then
		BossLogicAttack._process_pathing_results(data, my_data)
	
		if data.attention_obj and data.attention_obj.reaction >= AI_REACT_COMBAT then
			BossLogicAttack._upd_combat_movement(data, my_data)
		end
	end
end

function BossLogicAttack.queued_update(data)
	local my_data = data.internal_data
	data.t = TimerManager:game():time()

	BossLogicAttack._upd_enemy_detection(data, true)
	
	if data.internal_data == my_data then
		if data.attention_obj and AIAttentionObject.REACT_AIM <= data.attention_obj.reaction then
			BossLogicAttack.update(data)
		end
	end

	if my_data ~= data.internal_data then
		return
	end

	BossLogicAttack.queue_update(data, data.internal_data)
end

function BossLogicAttack.queue_update(data, my_data)
	local delay = 0 --whisper mode updates need to be as CONSTANT as possible to keep units moving smoothly and predictably
	
	if not managers.groupai:state():whisper_mode() then
		delay = data.important and 0.2 or 0.5 
	end

	CopLogicBase.queue_task(my_data, my_data.update_queue_id, BossLogicAttack.queued_update, data, data.t + delay, true)
end

function BossLogicAttack.update(data)
	local t = data.t
	local unit = data.unit
	local my_data = data.internal_data

	if my_data.has_old_action then
		CopLogicAttack._upd_stop_old_action(data, my_data)

		if my_data.has_old_action then
			if not my_data.update_queue_id then
				data.brain:set_update_enabled_state(false)

				my_data.update_queue_id = "BossLogicAttack.queued_update" .. tostring(data.key)

				BossLogicAttack.queue_update(data, my_data)
			end

			return
		end
	end

	if CopLogicAttack._chk_exit_non_walkable_area(data) or CopLogicIdle._chk_relocate(data) then
		return
	end

	if data.is_converted then
		local objective = data.objective

		if not objective or objective.type == "free" then
			local failed_path_t = data.path_fail_t

			if not failed_path_t or data.t - failed_path_t > 6 then
				managers.groupai:state():on_criminal_jobless(unit)

				if my_data ~= data.internal_data then
					return
				end
			end
		end
	end

	local cur_att_obj = data.attention_obj

	if not cur_att_obj or cur_att_obj.reaction < AI_REACT_AIM then
		BossLogicAttack._upd_enemy_detection(data, true)

		if my_data ~= data.internal_data then
			return
		end

		cur_att_obj = data.attention_obj
	end

	BossLogicAttack._process_pathing_results(data, my_data)
	
	local can_keep_moving = data.char_tweak.reload_while_moving_tmp or data.unit:anim_data().reload
	
	if not can_keep_moving then
		local ammo_max, ammo = data.unit:inventory():equipped_unit():base():ammo_info()
		
		if ammo > 0 then
			can_keep_moving = true
		end
	end
	
	if can_keep_moving then
		if cur_att_obj and AI_REACT_COMBAT <= cur_att_obj.reaction then
			BossLogicAttack._upd_combat_movement(data, my_data)
		else
			BossLogicAttack._cancel_chase_attempt(data, my_data)
		end
	elseif my_data.walking_to_chase_pos then
		local new_action = {
			body_part = 2,
			type = "idle"
		}

		data.unit:brain():action_request(new_action)
	end

	if not data.logic.action_taken then
		BossLogicAttack._chk_start_action_move_out_of_the_way(data, my_data)
	end

	if not my_data.update_queue_id then
		data.brain:set_update_enabled_state(false)

		my_data.update_queue_id = "BossLogicAttack.queued_update" .. tostring(data.key)

		BossLogicAttack.queue_update(data, my_data)
	end
end

function BossLogicAttack._upd_aim(data, my_data)
	local shoot, aim, expected_pos = nil
	local focus = data.attention_obj
	local reaction = focus and focus.reaction

	if focus then
		local focus_visible = focus.verified

		if AI_REACT_AIM <= reaction then
			if focus_visible or focus.nearly_visible then
				local weapon_range = my_data.weapon_range
				local walk_action = my_data.advancing
				local running = walk_action and not walk_action:stopping() and walk_action:haste() == "run"

				if reaction < AI_REACT_SHOOT then
					aim = true

					if running and math.lerp(weapon_range.close, weapon_range.optimal, 0) < focus.dis then
						local walk_to_pos = data.unit:movement():get_walk_to_pos()

						if walk_to_pos then
							mvec3_dir(temp_vec1, data.m_pos, walk_to_pos)
							mvec3_dir(temp_vec2, data.m_pos, focus.m_pos)
							mvec3_set_z(temp_vec1, 0)
							mvec3_set_z(temp_vec2, 0)

							if mvec3_dot(temp_vec1, temp_vec2) < 0.6 then
								aim = nil
							end
						end
					end
				else
					local firing_range = running and weapon_range.close or weapon_range.far
					local last_sup_t = data.unit:character_damage():last_suppression_t()

					if last_sup_t then
						local sup_t_ver = 7

						if running then
							sup_t_ver = sup_t_ver * 0.3
						end

						if not focus_visible then
							local vis_ray_data = focus.vis_ray

							if vis_ray_data and firing_range < vis_ray_data.distance then
								sup_t_ver = sup_t_ver * 0.5
							else
								sup_t_ver = sup_t_ver * 0.2
							end
						end

						shoot = sup_t_ver > data.t - last_sup_t
					end

					if not shoot and focus_visible then
						if focus.verified_dis < firing_range then
							shoot = true
						elseif focus.criminal_record and focus.criminal_record.assault_t and data.t - focus.criminal_record.assault_t < 2 then
							shoot = true
						end
					end

					if not shoot and my_data.attitude == "engage" then
						if focus_visible then
							if reaction == AI_REACT_SHOOT then
								shoot = true
							end
						elseif my_data.firing then
							local time_since_verification = focus.verified_t and data.t - focus.verified_t

							if time_since_verification and time_since_verification < 3.5 then
								shoot = true
							end
						end
					end

					aim = aim or shoot or focus.verified_dis < firing_range
				end
			else
				local time_since_verification = focus.verified_t
				local walk_action = my_data.advancing
				local running = walk_action and not walk_action:stopping() and walk_action:haste() == "run"

				if time_since_verification then
					time_since_verification = data.t - time_since_verification

					if running then
						local dis_lerp = math_clamp((focus.verified_dis - 500) / 600, 0, 1)
						aim = time_since_verification < math_lerp(5, 1, dis_lerp)
					elseif time_since_verification < 5 then
						aim = true
					end

					if aim and my_data.shooting and AI_REACT_SHOOT <= reaction then
						if running then
							local look_pos = focus.last_verified_pos or focus.verified_pos
							local same_height = math_abs(look_pos.z - data.m_pos.z) < 250

							if same_height and time_since_verification < 2 then
								shoot = true
							end
						elseif time_since_verification < 3 then
							shoot = true
						end
					end
				end

				if not shoot and (not focus.last_verified_pos or time_since_verification and time_since_verification > 5) then
					--expected_pos = CopLogicAttack._get_expected_attention_position(data, my_data)

					if expected_pos then
						if running then
							local watch_dir = temp_vec1

							mvec3_set(watch_dir, expected_pos)
							mvec3_sub(watch_dir, data.m_pos)
							mvec3_set_z(watch_dir, 0)

							local watch_pos_dis = mvec3_norm(watch_dir)
							local walk_to_pos = data.unit:movement():get_walk_to_pos()
							local walk_vec = temp_vec2

							mvec3_set(walk_vec, walk_to_pos)
							mvec3_sub(walk_vec, data.m_pos)
							mvec3_set_z(walk_vec, 0)
							mvec3_norm(walk_vec)

							local watch_walk_dot = mvec3_dot(watch_dir, walk_vec)

							if watch_pos_dis < 500 or watch_pos_dis < 1000 and watch_walk_dot > 0.85 then
								aim = true
							end
						else
							aim = true
						end
					end
				end
			end
		end

		if not aim and data.char_tweak.always_face_enemy and AI_REACT_COMBAT <= reaction and (expected_pos or focus.last_verified_pos) then
			aim = true
		end

		BossLogicAttack._chk_use_throwable(data, my_data, focus, expected_pos)

		if data.logic.chk_should_turn(data, my_data) then
			local focus_pos = nil
			focus_pos = (focus_visible or focus.nearly_visible) and focus.m_pos or expected_pos or focus.last_verified_pos or focus.verified_pos

			CopLogicAttack._chk_request_action_turn_to_enemy(data, my_data, data.m_pos, focus_pos)
		end
	end

	if aim or shoot then
		if focus.verified or focus.nearly_visible then
			if my_data.attention_unit ~= focus.u_key then
				CopLogicBase._set_attention(data, focus)

				my_data.attention_unit = focus.u_key
			end
		else
			local look_pos = expected_pos or focus.last_verified_pos or focus.verified_pos

			if my_data.attention_unit ~= look_pos then
				CopLogicBase._set_attention_on_pos(data, mvec3_cpy(look_pos))

				my_data.attention_unit = mvec3_cpy(look_pos)
			end
		end

		if not my_data.shooting and not my_data.spooc_attack and not data.unit:anim_data().reload and not data.unit:movement():chk_action_forbidden("action") then
			local shoot_action = {
				body_part = 3,
				type = "shoot"
			}

			if data.brain:action_request(shoot_action) then
				my_data.shooting = true
			end
		end
	else
		if my_data.shooting and not data.unit:anim_data().reload then
			local new_action = {
				body_part = 3,
				type = "idle"
			}

			data.brain:action_request(new_action)
		end

		if my_data.attention_unit then
			CopLogicBase._reset_attention(data)

			my_data.attention_unit = nil
		end
	end

	CopLogicAttack.aim_allow_fire(shoot, aim, data, my_data)
end
