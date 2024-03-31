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
LIESBossLogicAttack = LIESBossLogicAttack or class(BossLogicAttack) --for custom maps who override things, i need to make sure i override their overrides for common units

LIESBossLogicAttack._global_throwable_delays = {}

function LIESBossLogicAttack.enter(data, new_logic_name, enter_params)
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

	CopLogicTravel._chk_say_clear(data)

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

function LIESBossLogicAttack._pathing_complete_clbk(data)
	local my_data = data.internal_data

	if my_data.pathing_to_chase_pos then
		LIESBossLogicAttack._process_pathing_results(data, my_data)
	
		if data.attention_obj and AI_REACT_COMBAT <= data.attention_obj.reaction then
			LIESBossLogicAttack._upd_combat_movement(data, my_data)
		end
	end
end

function LIESBossLogicAttack.queued_update(data)
	local my_data = data.internal_data
	data.t = TimerManager:game():time()

	LIESBossLogicAttack._upd_enemy_detection(data, true)
	
	if data.internal_data == my_data then
		if data.attention_obj and AIAttentionObject.REACT_AIM <= data.attention_obj.reaction then
			LIESBossLogicAttack.update(data)
		end
	end

	if my_data ~= data.internal_data then
		return
	end

	LIESBossLogicAttack.queue_update(data, data.internal_data)
end

function LIESBossLogicAttack.queue_update(data, my_data)
	local delay = 0 --whisper mode updates need to be as CONSTANT as possible to keep units moving smoothly and predictably
	
	if not managers.groupai:state():whisper_mode() then
		delay = data.important and 0.2 or 0.5 
	end

	CopLogicBase.queue_task(my_data, my_data.update_queue_id, LIESBossLogicAttack.queued_update, data, data.t + delay, true)
end

function LIESBossLogicAttack.update(data)
	local t = data.t
	local unit = data.unit
	local my_data = data.internal_data

	if my_data.has_old_action or my_data.old_action_advancing then
		CopLogicAttack._upd_stop_old_action(data, my_data)

		if my_data.has_old_action or my_data.old_action_advancing then
			if not my_data.update_queue_id then
				data.brain:set_update_enabled_state(false)

				my_data.update_queue_id = "LIESBossLogicAttack.queued_update" .. tostring(data.key)

				LIESBossLogicAttack.queue_update(data, my_data)
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
		LIESBossLogicAttack._upd_enemy_detection(data, true)

		if my_data ~= data.internal_data then
			return
		end

		cur_att_obj = data.attention_obj
	end

	LIESBossLogicAttack._process_pathing_results(data, my_data)
	local ammo_max, ammo = data.unit:inventory():equipped_unit():base():ammo_info()
	
	local can_keep_moving = data.char_tweak.reload_while_moving_tmp or data.unit:anim_data().reload or ammo > 0
	
	if cur_att_obj and AI_REACT_COMBAT <= cur_att_obj.reaction then
		LIESBossLogicAttack._upd_combat_movement(data, my_data)
	else
		LIESBossLogicAttack._cancel_chase_attempt(data, my_data)
	end
	
	--this isn't even working anyways lol
	--if not data.logic.action_taken then
		--LIESBossLogicAttack._chk_start_action_move_out_of_the_way(data, my_data)
	--end

	if not my_data.update_queue_id then
		data.brain:set_update_enabled_state(false)

		my_data.update_queue_id = "LIESBossLogicAttack.queued_update" .. tostring(data.key)

		LIESBossLogicAttack.queue_update(data, my_data)
	end
end

function LIESBossLogicAttack._upd_aim(data, my_data)
	do 
		return CopLogicAttack._upd_aim(data, my_data) --just...for now
	end


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
		
		CopLogicAttack._chk_enrage(data, focus)
		LIESBossLogicAttack._chk_use_throwable(data, my_data, focus, expected_pos)
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
		
		if data.logic.chk_should_turn(data, my_data) then
			local focus_pos = nil
			focus_pos = (focus.verified or focus.nearly_visible) and focus.m_pos or my_data.attention_unit
			
			if focus_pos then
				CopLogicAttack._chk_request_action_turn_to_enemy(data, my_data, data.m_pos, focus_pos)
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
	
	if reaction and AI_REACT_COMBAT <= reaction then
		if LIES.settings.enemy_reaction_level < 3 and not data.unit:in_slot(16) then
			if not focus.react_t then
				focus.react_t = data.t
			end
			
			if not focus.verified_t or data.t - focus.verified_t > 2 then
				focus.react_t = data.t
			end
		
			local react_t = 2 / LIES.settings.enemy_reaction_level
		
			if shoot then
				if data.t - focus.react_t < react_t then
					aim = true
					shoot = nil
				end
			end
		end
	end
	
	CopLogicAttack.aim_allow_fire(shoot, aim, data, my_data)
end

function LIESBossLogicAttack._upd_combat_movement(data, my_data)
	if LIESBossLogicAttack.no_movement or data.next_mov_time and data.t < data.next_mov_time then
		return
	end

	local t = data.t
	local focus_enemy = data.attention_obj
	local enemy_visible = focus_enemy.verified
	local action_taken = data.logic.action_taken(data, my_data)
	local chase = nil

	if not action_taken then
		if my_data.chase_path then
			local enemy_dis = enemy_visible and focus_enemy.dis or focus_enemy.verified_dis
			local run_dist = enemy_visible and 800 or 400
			local speed = "run"
								
			if data.char_tweak.walk_only then
				speed = "walk"
			elseif not data.enrage_data or not data.enrage_data.enraged then
				speed = enemy_dis < run_dist and "walk" or speed
			end
			
			my_data.at_shoot_pos = nil

			LIESBossLogicAttack._chk_request_action_walk_to_chase_pos(data, my_data, speed)
		elseif not my_data.chase_path_search_id and focus_enemy.nav_tracker then
			if data.unit:anim_data().reload or data._visor_broken then
				if focus_enemy.verified and (focus_enemy.dis < 1400 or data._visor_broken and focus_enemy.aimed_at) and CopLogicAttack._can_move(data) then
					local from_pos = mvec3_cpy(data.m_pos)
					local threat_tracker = focus_enemy.nav_tracker
					local threat_head_pos = focus_enemy.m_head_pos
					local max_walk_dis = 400
					local vis_required = nil
					local retreat_to, is_fail = CopLogicAttack._find_retreat_position(data, from_pos, focus_enemy.m_pos, threat_head_pos, threat_tracker, max_walk_dis, nil)

					if retreat_to then
						local to_pos = retreat_to
						local second_retreat_pos, retry_is_fail
						
						if is_fail then
							second_retreat_pos, retry_is_fail = CopLogicAttack._find_retreat_position(data, retreat_to, focus_enemy.m_pos, threat_head_pos, threat_tracker, max_walk_dis, vis_required)
							
							to_pos = second_retreat_pos
						end
					
						local dis = mvec3_dis_sq(from_pos, to_pos)
						
						if dis > 10000 then
							local retreat_path = {
								retreat_to
							}
							
							if second_retreat_pos then
								retreat_path[#retreat_path + 1] = second_retreat_pos
							end

							my_data.chase_path = retreat_path
							
							local speed = data.char_tweak.walk_only and "walk" or "run"
							
							if LIESBossLogicAttack._chk_request_action_walk_to_chase_pos(data, my_data, speed) then
								my_data.defensive_move = true
								my_data.cover_test_step = 0
								my_data.at_shoot_pos = nil
								
								return
							end
						end
					end
				end
			end
			
			if not data.unit:anim_data().reload then
				if not my_data.at_shoot_pos then
					if my_data.chase_path_failed_t and data.t - my_data.chase_path_failed_t < 1 or data._visor_broken then
						if not enemy_visible and focus_enemy.verified_t and t - focus_enemy.verified_t < 4 then
							local my_tracker = data.unit:movement():nav_tracker()
							local aim_pos = focus_enemy.verified_pos
							
							if not my_data.cover_test_step then
								my_data.cover_test_step = 0
							end
							
							while my_data.cover_test_step < 3 do
								local shoot_from_pos = CopLogicAttack._peek_for_pos_sideways(data, my_data, my_tracker, aim_pos, 165, true)
								
								if shoot_from_pos then
									local path = {
										shoot_from_pos
									}
								
									my_data.chase_path = path
									
									if LIESBossLogicAttack._chk_request_action_walk_to_chase_pos(data, my_data, "run") then
										my_data.defensive_move = true
										my_data.walking_to_shoot_pos = true										
										return
									end
									
									break
								else
									my_data.cover_test_step = my_data.cover_test_step + 1
								end
							end
						end
					end
				end
				
				if not my_data.chase_path_failed_t or data.t - my_data.chase_path_failed_t > 1 then
					local height_diff = math_abs(data.m_pos.z - focus_enemy.m_pos.z)

					if height_diff < 300 then
						chase = true
					else
						local engage = my_data.attitude == "engage" and not data._visor_broken

						if enemy_visible then
							if focus_enemy.dis > 1000 or engage and focus_enemy.dis > 500 then
								chase = true
							end
						elseif focus_enemy.verified_dis > 1000 or engage and focus_enemy.verified_dis > 500 or not focus_enemy.verified_t or t - focus_enemy.verified_t > 2 then
							chase = true
						end
					end

					if chase and focus_enemy.nav_tracker then
						my_data.chase_pos = nil
						local chase_pos = focus_enemy.nav_tracker:field_position()
						local pos_on_wall = CopLogicAttack._find_charge_pos(data, my_data, focus_enemy.nav_tracker, 700)

						if pos_on_wall and mvec3_not_equal(chase_pos, pos_on_wall) then
							my_data.chase_pos = pos_on_wall
						end

						if my_data.chase_pos then
							local my_pos = data.unit:movement():nav_tracker():field_position()
							my_data.chase_path_search_id = tostring(data.unit:key()) .. "chase"
							my_data.pathing_to_chase_pos = true

							data.brain:add_pos_rsrv("path", {
								radius = 60,
								position = mvec3_cpy(my_data.chase_pos)
							})
							data.brain:search_for_path(my_data.chase_path_search_id, my_data.chase_pos)
						else
							my_data.chase_path_failed_t = t
						end
					else
						my_data.chase_pos = nil
					end
				end
			end
		end
	elseif my_data.walking_to_chase_pos and not my_data.use_flank_pos_when_chasing and not my_data.defensive_move and not my_data.moving_out_of_the_way then
		if data._visor_broken then
			if focus_enemy.verified and focus_enemy.dis < 700 then
				LIESBossLogicAttack._cancel_chase_attempt(data, my_data)
				
				return
			end
		end
	end
end

function LIESBossLogicAttack._confirm_retreat_position_visless(retreat_pos, threat_pos, threat_head_pos, threat_tracker)
	local retreat_head_pos = mvector3.copy(retreat_pos)

	mvector3.add(retreat_head_pos, Vector3(0, 0, 160))

	local slotmask = managers.slot:get_mask("AI_visibility") + managers.slot:get_mask("enemy_shield_check")
	local ray_res = World:raycast("ray", retreat_head_pos, threat_head_pos, "slot_mask", slotmask, "ray_type", "ai_vision", "report")

	if ray_res then
		return true
	end

	return false
end

function LIESBossLogicAttack.action_complete_clbk(data, action)
	local action_type = action:type()
	local my_data = data.internal_data

	if action_type == "walk" then
		my_data.advancing = nil
		my_data.old_action_advancing = nil

		if my_data.walking_to_chase_pos then
			my_data.walking_to_chase_pos = nil
		end

		if my_data.moving_out_of_the_way then
			my_data.moving_out_of_the_way = nil
		end
		
		if my_data.defensive_move then
			my_data.defensive_move = nil
		end
		
		if action:expired() then
			if my_data.walking_to_shoot_pos then
				my_data.at_shoot_pos = true
			end
		end
		
		my_data.walking_to_shoot_pos = nil

		LIESBossLogicAttack._cancel_chase_attempt(data, my_data)
	elseif action_type == "shoot" then
		my_data.shooting = nil
	elseif action_type == "reload" or action_type == "heal" or action_type == "healed" then
		if action:expired() then
			LIESBossLogicAttack._upd_aim(data, my_data)
		end
	elseif action_type == "act" then
		if my_data.gesture_arrest then
			my_data.gesture_arrest = nil
		elseif action:expired() then
			LIESBossLogicAttack._upd_aim(data, my_data)
		end
	elseif action_type == "turn" then
		my_data.turning = nil
	elseif action_type == "hurt" then
		LIESBossLogicAttack._cancel_chase_attempt(data, my_data)

		if action:expired() and action:hurt_type() ~= "death" then
			LIESBossLogicAttack._upd_aim(data, my_data)
		end
	end
end

function LIESBossLogicAttack._cancel_chase_attempt(data, my_data)
	my_data.chase_path = nil

	if my_data.walking_to_chase_pos then
		if not data.unit:movement():chk_action_forbidden("walk") then
			data.unit:brain():action_request({
				body_part = 2,
				type = "idle"
			})
		else
			my_data.old_action_advancing = my_data.advancing
		end
	elseif my_data.pathing_to_chase_pos then
		data.brain:rem_pos_rsrv("path")

		if data.active_searches[my_data.chase_path_search_id] then
			managers.navigation:cancel_pathing_search(my_data.chase_path_search_id)

			data.active_searches[my_data.chase_path_search_id] = nil
		elseif data.pathing_results then
			data.pathing_results[my_data.chase_path_search_id] = nil
		end

		my_data.chase_path_search_id = nil
		my_data.pathing_to_chase_pos = nil

		data.unit:brain():cancel_all_pathing_searches()
	elseif my_data.chase_pos then
		my_data.chase_pos = nil
	end
end

function LIESBossLogicAttack._chk_use_throwable(data, my_data, focus, ...)
	local throwable = data.char_tweak.throwable

	if not throwable then
		return
	end

	if not focus.criminal_record or focus.is_deployable then
		return
	end

	if not focus.last_verified_pos then
		return
	end

	if data.used_throwable_t and data.t < data.used_throwable_t then
		return
	end
	
	if LIESBossLogicAttack._global_throwable_delays and LIESBossLogicAttack._global_throwable_delays[data.unit:base()._tweak_table] and LIESBossLogicAttack._global_throwable_delays[data.unit:base()._tweak_table] > data.t then
		return
	end

	local time_since_verification = focus.verified_t

	if not time_since_verification then
		return
	end

	time_since_verification = data.t - time_since_verification

	if time_since_verification > 5 then
		return
	end

	local mov_ext = data.unit:movement()

	if mov_ext:chk_action_forbidden("action") then
		return
	end

	local head_pos = mov_ext:m_head_pos()
	local throw_dis = focus.verified_dis
	local distance_check = throwable ~= "molotov" and 600 or 400

	if throw_dis < distance_check then
		return
	end

	if throw_dis > 2000 then
		return
	end
	
	local last_seen_pos = mvec3_cpy(focus.last_verified_m_pos)
	
	local target_vec = temp_vec3
	mvec3_dir(target_vec, data.m_pos, last_seen_pos)
	mvec3_set_z(target_vec, 0)
	local my_fwd = data.unit:movement():m_fwd()
	local dot = mvector3.dot(target_vec, my_fwd)

	if dot < 0.6 then
		return
	end

	local throw_from = head_pos + mov_ext:m_head_rot():y() * 50

	local slotmask = managers.slot:get_mask("world_geometry")

	if throwable == "launcher_frag" or throwable == "launcher_incendiary" then
		last_seen_pos = focus.last_verified_m_pos:with_z(focus.last_verified_m_pos.z + 1)
		slotmask = managers.slot:get_mask("bullet_impact_targets_no_criminals")
	end
	
	
	local obstructed = nil
	
	if throwable == "launcher_frag" or throwable == "launcher_incendiary" then
		obstructed = data.unit:raycast("ray", throw_from, last_seen_pos, "slot_mask", slotmask, "report")
	else
		mvec3_set_z(last_seen_pos, last_seen_pos.z + 15)
		obstructed = data.unit:raycast("ray", throw_from, last_seen_pos, "sphere_cast_radius", 15, "slot_mask", slotmask, "report")
	end

	if obstructed then
		return
	end

	local throw_dir = Vector3()

	mvec3_lerp(throw_dir, throw_from, last_seen_pos, 0.3)
	mvec3_sub(throw_dir, throw_from)

	local dis_lerp = math_clamp((throw_dis - 1000) / 1000, 0, 1)
	local compensation = math_lerp(0, 300, dis_lerp)

	mvec3_set_z(throw_dir, throw_dir.z + compensation)
	mvec3_norm(throw_dir)
	
	local delay = data.char_tweak.throwable_delay or 10
	
	if data.char_tweak.global_delay then
		LIESBossLogicAttack._global_throwable_delays[data.unit:base()._tweak_table] = data.t + data.char_tweak.global_delay
	end
	
	data.used_throwable_t = data.t + delay

	if throwable ~= "launcher_frag" and throwable ~= "launcher_incendiary" and mov_ext:play_redirect("throw_grenade") then
		data.unit:sound():play("clk_baton_swing", nil, true)
		managers.network:session():send_to_peers_synched("play_distance_interact_redirect", data.unit, "throw_grenade")
	else		
		data.unit:sound():play("grenade_gas_npc_fire", nil, true)
	end

	ProjectileBase.throw_projectile_npc(throwable, throw_from, throw_dir, data.unit)
end

function LIESBossLogicAttack._upd_enemy_detection(data, is_synchronous)
	managers.groupai:state():on_unit_detection_updated(data.unit)

	data.t = TimerManager:game():time()
	local my_data = data.internal_data
	local min_reaction = AI_REACT_AIM
	local delay = CopLogicBase._upd_attention_obj_detection(data, min_reaction, nil)
	local new_attention, new_prio_slot, new_reaction = CopLogicIdle._get_priority_attention(data, data.detected_attention_objects, nil)
	local old_att_obj = data.attention_obj

	CopLogicBase._set_attention_obj(data, new_attention, new_reaction)
	data.logic._chk_exit_attack_logic(data, new_reaction)

	if my_data ~= data.internal_data then
		return
	end

	if not new_attention and old_att_obj then
		LIESBossLogicAttack._cancel_chase_attempt(data, my_data)

		my_data.att_chase_chk = nil
	end

	CopLogicBase._chk_call_the_police(data)

	if my_data ~= data.internal_data then
		return
	end

	CopLogicAttack._upd_aim(data, my_data)

	if not is_synchronous then
		CopLogicBase.queue_task(my_data, my_data.detection_task_key, LIESBossLogicAttack._upd_enemy_detection, data, data.t + delay, true)
	end

	CopLogicBase._report_detections(data.detected_attention_objects)
end

LIESDeepBossLogicAttack = LIESDeepBossLogicAttack or class(LIESBossLogicAttack)
LIESDeepBossLogicAttack._keep_player_focus_t = 10

function LIESDeepBossLogicAttack.damage_clbk(data, damage_info)
	LIESBossLogicAttack.damage_clbk(data, damage_info)

	if not data.unit:character_damage():dead() and data.unit:character_damage().health_ratio and data.unit:character_damage():health_ratio() < 0.4 then
		data.unit:sound():say(data.unit:sound().combat_str_alt or "combat_alt", true)
	end
end
