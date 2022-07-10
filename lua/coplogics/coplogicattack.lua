local mvec3_set = mvector3.set
local mvec3_add = mvector3.add
local mvec3_mul = mvector3.multiply
local mvec3_set_z = mvector3.set_z
local mvec3_sub = mvector3.subtract
local mvec3_dir = mvector3.direction
local mvec3_dot = mvector3.dot
local mvec3_dis = mvector3.distance
local mvec3_dis_sq = mvector3.distance_sq
local mvec3_lerp = mvector3.lerp
local mvec3_norm = mvector3.normalize
local temp_vec1 = Vector3()
local temp_vec2 = Vector3()
local temp_vec3 = Vector3()

function CopLogicAttack.enter(data, new_logic_name, enter_params)
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
	end

	my_data.cover_test_step = 1
	local key_str = tostring(data.key)

	CopLogicIdle._chk_has_old_action(data, my_data)

	my_data.attitude = data.objective and data.objective.attitude or "avoid"
	my_data.weapon_range = data.char_tweak.weapon[data.unit:inventory():equipped_unit():base():weapon_tweak_data().usage].range
	
	if not my_data.weapon_range then
		my_data.weapon_range = {
			optimal = 2000,
			far = 5000,
			close = 1000
		}
	end

	data.unit:brain():set_update_enabled_state(true)

	if data.cool then
		data.unit:movement():set_cool(false)
	end

	if (not data.objective or not data.objective.stance) and data.unit:movement():stance_code() == 1 then
		data.unit:movement():set_stance("hos")
	end

	if my_data ~= data.internal_data then
		return
	end
	
	CopLogicAttack._upd_enemy_detection(data, true)
	
	if my_data ~= data.internal_data then
		return
	end
	
	if data.objective and (data.objective.action_duration or data.objective.action_timeout_t and data.t < data.objective.action_timeout_t) then
		my_data.action_timeout_clbk_id = "CopLogicIdle_action_timeout" .. tostring(data.key)
		local action_timeout_t = data.objective.action_timeout_t or data.t + data.objective.action_duration
		data.objective.action_timeout_t = action_timeout_t

		CopLogicBase.add_delayed_clbk(my_data, my_data.action_timeout_clbk_id, callback(CopLogicIdle, CopLogicIdle, "clbk_action_timeout", data), action_timeout_t)
	end

	data.unit:brain():set_attention_settings({
		cbt = true
	})
end

function CopLogicAttack.queued_update(data)
	local my_data = data.internal_data
	data.t = TimerManager:game():time()
	
	CopLogicAttack._upd_enemy_detection(data, true)
	
	if data.internal_data == my_data then
		if data.attention_obj and AIAttentionObject.REACT_AIM <= data.attention_obj.reaction then
			CopLogicAttack.update(data)
		end
	end

	if data.internal_data == my_data then
		CopLogicAttack.queue_update(data, data.internal_data)
	end
end

function CopLogicAttack.queue_update(data, my_data)
	CopLogicBase.queue_task(my_data, my_data.update_queue_id, data.logic.queued_update, data, data.t + (data.important and 0.2 or 0.7), true)
end

function CopLogicAttack.damage_clbk(data, damage_info)
	CopLogicIdle.damage_clbk(data, damage_info)
	
	if data.important and not data.is_converted then
		if not data.unit:movement():chk_action_forbidden("walk") then
			local my_data = data.internal_data
			local moving_to_cover = my_data.moving_to_cover or my_data.at_cover_shoot_pos

			if not moving_to_cover and not my_data.tasing and not my_data.spooc_attack then
				CopLogicBase.chk_start_action_dodge(data, "hit")
			end
		end
	end
end

function CopLogicAttack._upd_enemy_detection(data, is_synchronous)
	managers.groupai:state():on_unit_detection_updated(data.unit)

	data.t = TimerManager:game():time()
	local my_data = data.internal_data
	local min_reaction = AIAttentionObject.REACT_AIM	
	local delay = CopLogicBase._upd_attention_obj_detection(data, min_reaction, nil)
	local new_attention, new_prio_slot, new_reaction = CopLogicIdle._get_priority_attention(data, data.detected_attention_objects, nil)
	local old_att_obj = data.attention_obj

	CopLogicBase._set_attention_obj(data, new_attention, new_reaction)
	data.logic._chk_exit_attack_logic(data, new_reaction)

	if my_data ~= data.internal_data then
		return
	end

	if new_attention then
		if old_att_obj and old_att_obj.u_key ~= new_attention.u_key then
			CopLogicAttack._cancel_charge(data, my_data)

			my_data.flank_cover = nil

			if not data.unit:movement():chk_action_forbidden("walk") then
				CopLogicAttack._cancel_walking_to_cover(data, my_data)
			end

			CopLogicAttack._set_best_cover(data, my_data, nil)
		end
	elseif old_att_obj then
		CopLogicAttack._cancel_charge(data, my_data)

		my_data.flank_cover = nil
	end

	CopLogicBase._chk_call_the_police(data)

	if my_data ~= data.internal_data then
		return
	end

	data.logic._upd_aim(data, my_data)

	if not is_synchronous then
		CopLogicBase.queue_task(my_data, my_data.detection_task_key, CopLogicAttack._upd_enemy_detection, data, delay and data.t + delay, data.important and true)
	end

	CopLogicBase._report_detections(data.detected_attention_objects)
end

function CopLogicAttack.update(data)
	local my_data = data.internal_data

	if my_data.has_old_action then
		CopLogicAttack._upd_stop_old_action(data, my_data)
		
		if my_data.has_old_action then
			if not my_data.update_queue_id then
				data.unit:brain():set_update_enabled_state(false)

				my_data.update_queue_id = "CopLogicAttack.queued_update" .. tostring(data.key)

				CopLogicAttack.queue_update(data, my_data)
			end
	
			return
		end
	end

	if CopLogicIdle._chk_relocate(data) then
		return
	end

	if CopLogicAttack._chk_exit_non_walkable_area(data) then
		return
	end

	CopLogicAttack._process_pathing_results(data, my_data)

	if not data.attention_obj or data.attention_obj.reaction < AIAttentionObject.REACT_AIM then
		CopLogicAttack._upd_enemy_detection(data, true)

		if my_data ~= data.internal_data or not data.attention_obj then
			return
		end
	end
	
	if AIAttentionObject.REACT_COMBAT <= data.attention_obj.reaction and not data.unit:movement():chk_action_forbidden("walk") then
		my_data.want_to_take_cover = CopLogicAttack._chk_wants_to_take_cover(data, my_data)
		
		--log(tostring(my_data.attitude))
		
		--[[uncomment to draw cover stuff or whatever
		
		if my_data.moving_to_cover then
			local height = 41
			local line = Draw:brush(Color.blue:with_alpha(0.5), 0.2)
			line:cylinder(data.m_pos, my_data.moving_to_cover[1][1], 5)
			line:cylinder(my_data.moving_to_cover[1][1], my_data.moving_to_cover[1][1] + math.UP * height, 5)
		elseif my_data.in_cover then
			local height = my_data.in_cover[4] and 165 or 82.5
			local line = Draw:brush(Color.red:with_alpha(0.5), 0.2)
			line:cylinder(my_data.in_cover[1][1], my_data.in_cover[1][1] + math.UP * height, 100)
		elseif my_data.best_cover then
			local height = 41
			local line = Draw:brush(Color.green:with_alpha(0.5), 0.2)
			line:cylinder(data.m_pos, my_data.best_cover[1][1], 5)
			line:cylinder(my_data.best_cover[1][1], my_data.best_cover[1][1] + math.UP * height, 5)
		end]]

		CopLogicAttack._update_cover(data)
		CopLogicAttack._upd_combat_movement(data)
	end
	
	if data.is_converted or data.check_crim_jobless or data.team.id == "criminal1" then
		if not data.objective or data.objective.type == "free" then
			if not data.path_fail_t or data.t - data.path_fail_t > 6 then
				managers.groupai:state():on_criminal_jobless(data.unit)

				if my_data ~= data.internal_data then
					return
				end
			end
		end
	end

	if not my_data.update_queue_id then
		data.unit:brain():set_update_enabled_state(false)

		my_data.update_queue_id = "CopLogicAttack.queued_update" .. tostring(data.key)

		CopLogicAttack.queue_update(data, my_data)
	end
end

function CopLogicAttack._chk_wants_to_take_cover(data, my_data)
	local ammo_max, ammo = data.unit:inventory():equipped_unit():base():ammo_info()

	if ammo <= 0 then
		local has_walk_actions = my_data.advancing or my_data.walking_to_cover_shoot_pos or my_data.moving_to_cover or my_data.surprised
	
		if has_walk_actions and not data.unit:movement():chk_action_forbidden("walk") then
			if not data.unit:anim_data().reload and my_data.shooting then
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

	if not data.attention_obj or data.attention_obj.reaction < AIAttentionObject.REACT_COMBAT then
		return
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
end

function CopLogicAttack.chk_should_turn(data, my_data)
	return not my_data.turning and not my_data.has_old_action and not data.unit:movement():chk_action_forbidden("walk") and not my_data.moving_to_cover and not my_data.walking_to_cover_shoot_pos and not my_data.surprised and not my_data.advancing
end

function CopLogicAttack._check_needs_reload(data, my_data)
	if data.unit:anim_data().reload then
		return true
	end
	
	local weapon, weapon_base, ammo_max, ammo

	if alive(data.unit) and data.unit:inventory() then
		weapon = data.unit:inventory():equipped_unit()
	
		if weapon and alive(weapon) then
			weapon_base = weapon and weapon:base()
			ammo_max, ammo = weapon_base:ammo_info()
			local state = data.name
			
			if ammo / ammo_max > 0.2 then
				return true
			end
		end
	end
	
	if not ammo then
		return true
	end
	
	local needs_reload = nil
	
	if ammo <= 1 or ammo / ammo_max <= 0.2 then
		needs_reload = true
	end
	
	if needs_reload then
		local ammo_base = weapon_base and weapon_base:ammo_base()
		
		if ammo_base then
			ammo_base:set_ammo_remaining_in_clip(0)
			
			if not my_data.shooting then
				local shoot_action = {
					body_part = 3,
					type = "shoot"
				}

				if data.unit:brain():action_request(shoot_action) then
					my_data.shooting = true
				end
			end
		end
	end
end

function CopLogicAttack._upd_aim(data, my_data)
	local shoot, aim, expected_pos = nil
	local focus_enemy = data.attention_obj

	if focus_enemy and AIAttentionObject.REACT_AIM <= focus_enemy.reaction then
		local last_sup_t = data.unit:character_damage():last_suppression_t()
		
		if not data.char_tweak.always_face_enemy then
			if my_data.low_value_att or data.unit:anim_data().run and my_data.weapon_range.close < focus_enemy.dis then
				local walk_action = my_data.advancing 
			
				if walk_action and walk_action._init_called and walk_action._cur_vel >= 0.1 and not walk_action:stopping() then --do this properly
					local pos_for_dir = walk_action._footstep_pos or walk_action._last_pos
					local walk_dir = pos_for_dir - walk_action._common_data.pos
					walk_dir = walk_dir:with_z(0):normalized()

					mvec3_dir(temp_vec2, data.m_pos, focus_enemy.m_pos)
					mvec3_set_z(temp_vec2, 0)

					local dot = mvec3_dot(walk_dir, temp_vec2)

					if dot < 0.7 then
						shoot = false
						aim = false
					end
				end
			end
		end
		
		local firing_range = 500

		if data.internal_data.weapon_range then
			firing_range = running and data.internal_data.weapon_range.close or data.internal_data.weapon_range.far
		else
			debug_pause_unit(data.unit, "[CopLogicAttack]: Unit doesn't have data.internal_data.weapon_range")
		end
	
		if focus_enemy.verified or focus_enemy.nearly_visible then
			if aim == nil and AIAttentionObject.REACT_AIM <= focus_enemy.reaction then
				if AIAttentionObject.REACT_SHOOT <= focus_enemy.reaction then

					if AIAttentionObject.REACT_SHOOT == focus_enemy.reaction then
						shoot = true
					end
					
					if not shoot and my_data.attitude == "engage" then
						shoot = true
					end

					if not shoot then
						if data.unit:base():has_tag("law") and not data.is_converted then
							if focus_enemy.criminal_record and focus_enemy.criminal_record.assault_t and data.t - focus_enemy.criminal_record.assault_t < 7 then
								shoot = true
							elseif focus_enemy.dis < firing_range then
								shoot = true
							else
								aim = true
							end
						else
							shoot = true
						end
					end

					aim = aim or shoot
				else
					aim = true
				end
			end
		elseif AIAttentionObject.REACT_AIM <= focus_enemy.reaction then
			local time_since_verification = focus_enemy.verified_t and data.t - focus_enemy.verified_t
				
			if time_since_verification and aim == nil then
				local running = data.unit:anim_data().run

				if running and not data.char_tweak.always_face_enemy then
					if time_since_verification < math.lerp(5, 1, math.max(0, focus_enemy.verified_dis - 500) / 600) then
						aim = true
					end
				elseif time_since_verification < 5 then
					aim = true
				end

				if aim and time_since_verification < 3 and AIAttentionObject.REACT_SHOOT <= focus_enemy.reaction then
					if AIAttentionObject.REACT_SHOOT == focus_enemy.reaction then
						shoot = true
					end
					
					if not shoot and my_data.attitude == "engage" then
						shoot = true
					end
					
					if not shoot then
						if data.unit:base():has_tag("law") and not data.is_converted then
							if focus_enemy.criminal_record and focus_enemy.criminal_record.assault_t and data.t - focus_enemy.criminal_record.assault_t < 7 then
								shoot = true
							elseif focus_enemy.dis < firing_range then
								shoot = true
							else
								aim = true
							end
						else
							shoot = true
						end
					end
				end
			end
		end

		CopLogicAttack._chk_enrage(data, focus_enemy)
	end

	if not aim and data.char_tweak.always_face_enemy and focus_enemy and AIAttentionObject.REACT_COMBAT <= focus_enemy.reaction then
		aim = true
	end
	
	if shoot and data.tactics and data.tactics.harass and data.char_tweak.chatter and data.char_tweak.chatter.clear then
		if focus_enemy.is_local_player then
			local cur_state = focus_enemy.unit:movement():current_state()
			
			if cur_state:_is_reloading() then
				managers.groupai:state():chk_say_enemy_chatter(data.unit, data.m_pos, "calloutreload")
			end
		else
			local focus_anim_data = focus_enemy.unit:anim_data()

			if focus_anim_data and focus_anim_data.reload then
				managers.groupai:state():chk_say_enemy_chatter(data.unit, data.m_pos, "calloutreload")
			end
		end
	end
	
	aim = shoot or aim

	if aim or shoot then
		if expected_pos then
			if my_data.attention_unit ~= expected_pos then
				CopLogicBase._set_attention_on_pos(data, mvector3.copy(expected_pos))

				my_data.attention_unit = mvector3.copy(expected_pos)
			end
		elseif focus_enemy.verified then		
			if my_data.attention_unit ~= focus_enemy.u_key then
				CopLogicBase._set_attention(data, focus_enemy)

				my_data.attention_unit = focus_enemy.u_key
			end
		else
			local look_pos = focus_enemy.last_verified_pos or focus_enemy.verified_pos

			if my_data.attention_unit ~= look_pos then
				CopLogicBase._set_attention_on_pos(data, mvector3.copy(look_pos))

				my_data.attention_unit = mvector3.copy(look_pos)
			end
		end
		
		if not my_data.shooting and not my_data.spooc_attack and not data.unit:movement():chk_action_forbidden("action") then
			local shoot_action = {
				body_part = 3,
				type = "shoot"
			}

			if data.unit:brain():action_request(shoot_action) then
				my_data.shooting = true
			end
		end
	else
		if data.unit:movement():chk_action_forbidden("action") or not data.unit:anim_data().reload and CopLogicAttack._check_needs_reload(data, my_data) then
			if my_data.shooting then
				local new_action = {
					body_part = 3,
					type = "idle"
				}

				data.unit:brain():action_request(new_action)
			end
		end
		
		if my_data.advancing then
			local walk_action = my_data.advancing 
			
			if not walk_action._expired and walk_action._init_called and walk_action._cur_vel >= 0.1 and not walk_action:stopping() then --did the init get fucking called properly? yes? please start checking the walk direction
				local walk_pos = mvector3.copy(data.unit:movement():m_head_pos())
				local pos_for_dir = walk_action._footstep_pos or walk_action._last_pos
				local walk_dir_pos = pos_for_dir - walk_action._common_data.pos
				mvec3_norm(walk_dir_pos)
				mvec3_mul(walk_dir_pos, 500)

				mvec3_add(walk_pos, walk_dir_pos)
	
				if my_data.attention_unit ~= walk_pos then
					CopLogicBase._set_attention_on_pos(data, mvector3.copy(walk_pos))

					my_data.attention_unit = mvector3.copy(walk_pos)
				end
			elseif my_data.attention_unit then
				CopLogicBase._reset_attention(data)

				my_data.attention_unit = nil
			end
		elseif my_data.attention_unit then
			CopLogicBase._reset_attention(data)

			my_data.attention_unit = nil
		end
	end
	
	if not my_data.advancing and CopLogicAttack.chk_should_turn(data, my_data) and (focus_enemy or expected_pos) then
		local enemy_pos = expected_pos or focus_enemy.last_verified_pos or focus_enemy.verified_pos

		CopLogicAttack._chk_request_action_turn_to_enemy(data, my_data, data.m_pos, enemy_pos)
	end
	
	if focus_enemy and AIAttentionObject.REACT_COMBAT <= focus_enemy.reaction then
		if LIES.settings.enemy_reaction_level < 3 and focus_enemy.acquire_t and not data.unit:in_slot(16) then
			if not focus_enemy.verified_t or data.t - focus_enemy.verified_t > 2 then
				focus_enemy.acquire_t = data.t
			end
		
			local react_t = 0.7 / LIES.settings.enemy_reaction_level
		
			if shoot then
				if data.t - focus_enemy.acquire_t < react_t then
					aim = true
					shoot = nil
				end
			end
		end
	end

	CopLogicAttack.aim_allow_fire(shoot, aim, data, my_data)
end

function CopLogicAttack._chk_enrage(data, focus_enemy)
	if not data.char_tweak or not data.char_tweak.enrages then
		return
	end
	
	local enrage_data = data.enrage_data or {
		enrage_meter = 0,
		last_chk_t = data.t - 0.2,
		enraged = false,
		enrage_max = 5 + math.random(0, 5)
	}
	
	local dt = data.t - enrage_data.last_chk_t

	local increase = nil
	
	if focus_enemy then
		if AIAttentionObject.REACT_COMBAT <= focus_enemy.reaction and focus_enemy.dis < 1000 then
			if focus_enemy.verified or focus_enemy.verified_t and data.t - focus_enemy.verified_t < 2 then
				increase = true
			end
		end
	end
	
	if increase and not enrage_data.enraged then
		enrage_data.enrage_meter = enrage_data.enrage_meter + dt
		
		if enrage_data.enrage_meter >= enrage_data.enrage_max then
			enrage_data.enraged = true
			enrage_data.enrage_buff_id = data.unit:base():add_buff("base_damage", 1)
			
			if not data.internal_data.turning then
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

					data.unit:brain():action_request(action_data)
					
				end
			end
			
			data.unit:sound():play("tire_blow", nil, true)
			data.unit:sound():play("window_small_shatter", nil, true)
			
			if enrage_data.played_warning then
				data.unit:sound():play("slot_machine_win", nil, true)
				enrage_data.played_warning = nil
			end
			
			enrage_data.enrage_meter = 5
		elseif not enrage_data.played_warning and enrage_data.enrage_meter > enrage_data.enrage_max * 0.75 then
			data.unit:sound():play("slot_machine_rolling_loop", nil, true)

			enrage_data.played_warning = true
		end
	else
		enrage_data.enrage_meter = enrage_data.enrage_meter - dt
		
		if enrage_data.enrage_meter <= 0 then
			if enrage_data.enraged then
				enrage_data.enrage_max = 5 + math.random(0, 5)
			end
			
			enrage_data.enrage_meter = 0
			enrage_data.enraged = false
			
			if enrage_data.enrage_buff_id then
				data.unit:base():remove_buff_by_id("base_damage", enrage_data.enrage_buff_id)
				
				enrage_data.enrage_buff_id = nil
			end
		end
		
		if enrage_data.played_warning then
			data.unit:sound():play("slot_machine_loose", nil, true)
			enrage_data.played_warning = nil
		end
	end
	
	enrage_data.last_chk_t = data.t
	
	data.enrage_data = data.enrage_data or enrage_data
end

function CopLogicAttack.aim_allow_fire(shoot, aim, data, my_data)
	local focus_enemy = data.attention_obj
	
	if not data.unit:movement():chk_action_forbidden("action") then
		if shoot then
			if not my_data.firing then		
				data.unit:movement():set_allow_fire(true)

				my_data.firing = true

				if not data.unit:in_slot(16) and data.char_tweak.chatter and data.char_tweak.chatter.aggressive and managers.groupai:state():is_detection_persistent() then
					managers.groupai:state():chk_say_enemy_chatter(data.unit, data.m_pos, "aggressive")
				end
			end
		elseif my_data.firing then
			data.unit:movement():set_allow_fire(false)

			my_data.firing = nil
		end
	elseif my_data.firing then
		data.unit:movement():set_allow_fire(false)

		my_data.firing = nil
	end
end

function CopLogicAttack._move_back_into_field_position(data, my_data)
	local my_tracker = data.unit:movement():nav_tracker()
	
	if my_tracker:lost() then
		local field_position = my_tracker:field_position()
		
		if mvec3_dis_sq(data.m_pos, field_position) > 900 then	
			local path = {
				mvector3.copy(data.m_pos),
				field_position
			}

			return CopLogicAttack._chk_request_action_walk_to_cover_shoot_pos(data, my_data, path, "run")
		end
	end
end

function CopLogicAttack._update_cover(data)
	local my_data = data.internal_data
	local cover_release_dis_sq = 10000
	local best_cover = my_data.best_cover
	local satisfied = true
	local my_pos = data.m_pos

	if data.attention_obj and data.attention_obj.nav_tracker and AIAttentionObject.REACT_COMBAT <= data.attention_obj.reaction then
		local find_new = not my_data.moving_to_cover and not my_data.walking_to_cover_shoot_pos and not my_data.surprised

		if find_new then
			local enemy_tracker = data.attention_obj.nav_tracker
			local threat_pos = enemy_tracker:field_position()

			if data.objective and data.objective.type == "follow" then
				local near_pos = data.objective.follow_unit:movement():m_pos()

				if (not best_cover or not CopLogicAttack._verify_follow_cover(best_cover[1], near_pos, threat_pos, 200, 1000)) and not my_data.processing_cover_path then
					local follow_unit_area = managers.groupai:state():get_area_from_nav_seg_id(data.objective.follow_unit:movement():nav_tracker():nav_segment())
					local found_cover = managers.navigation:find_cover_in_nav_seg_3(follow_unit_area.nav_segs, data.objective.distance and data.objective.distance * 0.9 or 700, near_pos, threat_pos)

					if found_cover then
						if not follow_unit_area.nav_segs[found_cover[3]:nav_segment()] then
							debug_pause_unit(data.unit, "cover in wrong area")
						end

						satisfied = true
						local better_cover = {
							found_cover
						}

						CopLogicAttack._set_best_cover(data, my_data, better_cover)

						local offset_pos, yaw = CopLogicAttack._get_cover_offset_pos(data, better_cover, threat_pos)

						if offset_pos then
							better_cover[5] = offset_pos
							better_cover[6] = yaw
						end
					end
				end
			else
				local want_to_take_cover = my_data.want_to_take_cover
				local flank_cover = my_data.flank_cover
				local min_dis, max_dis = nil

				if want_to_take_cover then
					min_dis = math.max(data.attention_obj.dis * 0.9, data.attention_obj.dis - 200)
				end

				if not my_data.processing_cover_path and (not best_cover or flank_cover or not CopLogicAttack._verify_cover(best_cover[1], threat_pos, min_dis, max_dis) or my_data.cover_enter_t and data.t - my_data.cover_enter_t > 2) then
					satisfied = false
					local my_vec = my_pos - threat_pos

					if flank_cover then
						local angle = flank_cover.angle
						local sign = flank_cover.sign

						if math.sign(angle) ~= sign then
							angle = -angle + flank_cover.step * sign

							if math.abs(angle) > 90 then
								flank_cover.failed = true
							else
								flank_cover.angle = angle
							end
						else
							flank_cover.angle = -angle
						end
					end

					if flank_cover and not flank_cover.failed then
						mvector3.rotate_with(my_vec, Rotation(flank_cover.angle))
					end

					local optimal_dis = my_vec:length()
					local max_dis = nil

					if want_to_take_cover then
						if optimal_dis < my_data.weapon_range.far then
							optimal_dis = optimal_dis + 400

							mvector3.set_length(my_vec, optimal_dis)
						end

						max_dis = math.max(optimal_dis + 800, my_data.weapon_range.far)
					elseif optimal_dis > my_data.weapon_range.optimal * 1.2 then
						optimal_dis = my_data.weapon_range.optimal

						mvector3.set_length(my_vec, optimal_dis)

						max_dis = my_data.weapon_range.far
					end

					local my_side_pos = threat_pos + my_vec

					mvector3.set_length(my_vec, max_dis)

					local furthest_side_pos = threat_pos + my_vec

					local min_threat_dis, cone_angle = nil

					if flank_cover then
						cone_angle = flank_cover.step
					else
						cone_angle = math.lerp(90, 30, math.min(1, optimal_dis / 3000))
					end

					local search_nav_seg = nil

					if data.objective and data.objective.type == "defend_area" then
						search_nav_seg = data.objective.area and data.objective.area.nav_segs or data.objective.nav_seg
					end

					local found_cover = managers.navigation:find_cover_in_cone_from_threat_pos_1(threat_pos, furthest_side_pos, my_side_pos, nil, cone_angle, min_threat_dis, search_nav_seg, nil, data.pos_rsrv_id)

					if found_cover then
						satisfied = true
						local better_cover = {
							found_cover
						}

						CopLogicAttack._set_best_cover(data, my_data, better_cover)

						local offset_pos, yaw = CopLogicAttack._get_cover_offset_pos(data, better_cover, threat_pos)

						if offset_pos then
							better_cover[5] = offset_pos
							better_cover[6] = yaw
						end
						
						flank_cover = nil
						my_data.flank_cover = nil
					else
						if flank_cover then
							flank_cover.failed = true
						end
						
						my_data.cover_path_failed_t = data.t
					end
				end
			end
		end

		local in_cover = my_data.in_cover

		if in_cover then
			local threat_pos = data.attention_obj.verified_pos
			in_cover[3], in_cover[4] = CopLogicAttack._chk_covered(data, my_pos, threat_pos, data.visibility_slotmask)
		elseif not my_data.moving_to_cover and best_cover and cover_release_dis_sq >= mvector3.distance_sq(best_cover[1][1], my_pos) then
			my_data.in_cover = my_data.best_cover
			my_data.cover_enter_t = data.t
		end
	elseif best_cover and cover_release_dis_sq < mvector3.distance_sq(best_cover[1][1], my_pos) then
		CopLogicAttack._set_best_cover(data, my_data, nil)
	end
end

function CopLogicAttack._verify_cover(cover, threat_pos, min_dis, max_dis)
	local threat_dis = mvec3_dis(cover[1], threat_pos)

	if min_dis and threat_dis < min_dis or max_dis and max_dis < threat_dis then
		return
	end

	return true
end

function CopLogicAttack._process_pathing_results(data, my_data)
	if not data.pathing_results then
		return
	end

	local pathing_results = data.pathing_results
	data.pathing_results = nil
	
	local path = pathing_results[my_data.cover_path_search_id]

	if path then
		my_data.processing_cover_path = nil
		my_data.cover_path_search_id = nil
	
		if path ~= "failed" then
			my_data.cover_path = path
		else
			CopLogicAttack._set_best_cover(data, my_data, nil)

			my_data.cover_path_failed_t = TimerManager:game():time()
		end
	end

	path = pathing_results[my_data.charge_path_search_id]

	if path then
		my_data.charge_path_search_id = nil
		my_data.charge_pos = nil
	
		if path ~= "failed" then
			my_data.charge_path = path
		else
			my_data.charge_path_failed_t = TimerManager:game():time()
		end	
	end

	path = pathing_results[my_data.expected_pos_path_search_id]

	if path then
		if path ~= "failed" then
			my_data.expected_pos_path = path
		end

		my_data.expected_pos_path_search_id = nil
	end
end

function CopLogicAttack._upd_combat_movement(data)
	if data.unit:movement():chk_action_forbidden("walk") then
		return
	end
	
	local my_data = data.internal_data
	
	local action_taken = data.logic.action_taken(data, my_data)
	
	if action_taken then
		return
	end
	
	action_taken = action_taken or CopLogicAttack._move_back_into_field_position(data, my_data)

	action_taken = action_taken or CopLogicAttack._upd_pose(data, my_data)
	
	if action_taken then
		return
	end
	
	if my_data.processing_cover_path or my_data.charge_path_search_id then
		return
	end
	
	local focus_enemy = data.attention_obj
	
	if not focus_enemy or AIAttentionObject.REACT_COMBAT > focus_enemy.reaction then
		return
	end
	
	local in_cover = my_data.in_cover
	local best_cover = my_data.best_cover
	
	if in_cover and best_cover and in_cover[1] ~= best_cover[1] then
		in_cover = false
	end
	
	local aggro_level = LIES.settings.enemy_aggro_level
	local takz = LIES.settings.hhtacs

	local enemy_visible = focus_enemy.verified
	local enemy_visible_soft = focus_enemy.verified_t and data.t - focus_enemy.verified_t < 2
	local enemy_visible_softer = focus_enemy.verified_t and data.t - focus_enemy.verified_t < 5
	local engage = nil
	
	if not my_data.want_to_take_cover or aggro_level > 2 then
		engage = my_data.attitude == "engage"
	end
	
	local engage = not my_data.want_to_take_cover and my_data.attitude == "engage" or aggro_level > 2 and my_data.attitude == "engage"
	
	if data.is_converted then
		if not in_cover then
			if my_data.cover_path then
				action_taken = CopLogicAttack._chk_request_action_walk_to_cover(data, my_data)
			elseif best_cover and (not my_data.cover_path_failed_t or data.t - my_data.cover_path_failed_t > 5) then
				local search_id = tostring(data.key) .. "cover"

				if data.unit:brain():search_for_path_to_cover(search_id, best_cover[1], best_cover[5]) then
					my_data.cover_path_search_id = search_id
					my_data.processing_cover_path = best_cover
				end
				
				action_taken = true
			end
		end
		
		return
	end

	if in_cover then
		CopLogicAttack._cancel_cover_pathing(data, my_data)
	
		local can_charge = not my_data.charge_path_failed_t or data.t - my_data.charge_path_failed_t > 6
		
		if can_charge then
			if my_data.flank_cover and my_data.flank_cover.failed or data.objective and data.objective.grp_objective and data.objective.grp_objective.charge or aggro_level > 3 and engage or aggro_level > 1 and engage and (not data.tactics or not data.tactics.ranged_fire) then
				if my_data.charge_path then
					local path = my_data.charge_path
					my_data.charge_path = nil
					action_taken = CopLogicAttack._chk_request_action_walk_to_cover_shoot_pos(data, my_data, path, "run")
				elseif not my_data.charge_path_search_id and data.attention_obj.nav_tracker then
					my_data.charge_pos = CopLogicTravel._get_pos_on_wall(data.attention_obj.nav_tracker:field_position(), my_data.weapon_range.optimal, 45, nil)

					if my_data.charge_pos then
						my_data.charge_path_search_id = "charge" .. tostring(data.key)

						data.unit:brain():search_for_path(my_data.charge_path_search_id, my_data.charge_pos, nil, nil, nil)
						
						action_taken = true
					else
						my_data.charge_path_search_id = nil
						my_data.charge_path_failed_t = TimerManager:game():time()
					end
				end
			end
		end
		
		if action_taken then
			return
		end
		
		if engage then
			if not enemy_visible_soft and my_data.cover_test_step <= 2 and my_data.cover_enter_t and data.t - my_data.cover_enter_t > 4 then
				local height = nil

				if in_cover[4] then
					height = 160
				else
					height = 80
				end

				local my_tracker = data.unit:movement():nav_tracker()
				local shoot_from_pos = CopLogicAttack._peek_for_pos_sideways(data, my_data, my_tracker, focus_enemy.m_head_pos, height)

				if shoot_from_pos then
					local path = {
						my_tracker:position(),
						shoot_from_pos
					}
					action_taken = CopLogicAttack._chk_request_action_walk_to_cover_shoot_pos(data, my_data, path, "run")
				else
					if not my_data.flank_cover then
						local sign = math.random() < 0.5 and -1 or 1
						local step = 30
						my_data.flank_cover = {
							step = step,
							angle = step * sign,
							sign = sign
						}
					end
					
					my_data.cover_test_step = 1
					
					CopLogicAttack._set_best_cover(data, my_data, nil)
					CopLogicAttack._cancel_cover_pathing(data, my_data)
					best_cover = nil
					in_cover = nil
				end
			elseif not my_data.flank_cover and my_data.cover_test_step > 2 then
				local sign = math.random() < 0.5 and -1 or 1
				local step = 30
				my_data.flank_cover = {
					step = step,
					angle = step * sign,
					sign = sign
				}
				
				CopLogicAttack._set_best_cover(data, my_data, nil)
				CopLogicAttack._cancel_cover_pathing(data, my_data)
				best_cover = nil
				in_cover = nil
			end
		end
			
		if action_taken then
			return
		end
		
		if enemy_visible and data.important and (not in_cover or not in_cover[4]) then
			if not my_data.turning and not data.unit:movement():chk_action_forbidden("walk") and CopLogicAttack._can_move(data) then
				if data.is_suppressed and data.t - data.unit:character_damage():last_suppression_t() < 0.7 then
					action_taken = CopLogicBase.chk_start_action_dodge(data, "scared")
				end

				if not action_taken and focus_enemy.is_person and focus_enemy.dis < 2000 then
					local dodge = nil

					if focus_enemy.is_local_player then
						local e_movement_state = focus_enemy.unit:movement():current_state()

						if not e_movement_state:_is_reloading() and not e_movement_state:_interacting() and not e_movement_state:is_equipping() then
							dodge = true
						end
					else
						local e_anim_data = focus_enemy.unit:anim_data()

						if (e_anim_data.move or e_anim_data.idle) and not e_anim_data.reload then
							dodge = true
						end
					end

					if dodge and focus_enemy.aimed_at then
						action_taken = CopLogicBase.chk_start_action_dodge(data, "preemptive")
					end
				end
			end
		end
	else
		if my_data.cover_path then
			action_taken = CopLogicAttack._chk_request_action_walk_to_cover(data, my_data)
		elseif best_cover and (not my_data.cover_path_failed_t or data.t - my_data.cover_path_failed_t > 5) then
			CopLogicAttack._cancel_cover_pathing(data, my_data)
			
			local search_id = tostring(data.key) .. "cover"

			if data.unit:brain():search_for_path_to_cover(search_id, best_cover[1], best_cover[5]) then
				my_data.cover_path_search_id = search_id
				my_data.processing_cover_path = best_cover

				CopLogicAttack._cancel_charge(data, my_data)
				
				action_taken = true
			end
		end
		
		if action_taken then
			return
		end
		
		if enemy_visible and data.important then
			if not my_data.turning and not data.unit:movement():chk_action_forbidden("walk") and CopLogicAttack._can_move(data) then
				if data.is_suppressed and data.t - data.unit:character_damage():last_suppression_t() < 0.7 then
					action_taken = CopLogicBase.chk_start_action_dodge(data, "scared")
				end

				if not action_taken and focus_enemy.is_person and focus_enemy.dis < 2000 then
					local dodge = nil

					if focus_enemy.is_local_player then
						local e_movement_state = focus_enemy.unit:movement():current_state()

						if not e_movement_state:_is_reloading() and not e_movement_state:_interacting() and not e_movement_state:is_equipping() then
							dodge = true
						end
					else
						local e_anim_data = focus_enemy.unit:anim_data()

						if (e_anim_data.move or e_anim_data.idle) and not e_anim_data.reload then
							dodge = true
						end
					end

					if dodge and focus_enemy.aimed_at then
						action_taken = CopLogicBase.chk_start_action_dodge(data, "preemptive")
					end
				end
			end
		end
		
		if action_taken then
			return
		end
		
		if enemy_visible_softer and (not best_cover or my_data.flank_cover and my_data.flank_cover.failed or my_data.cover_path_failed_t and data.t - my_data.cover_path_failed_t <= 5) then
			if takz and data.important and data.group and data.group.size > 1 then
				action_taken = CopLogicAttack._find_friend_pos(data, my_data)
			end
			
			if action_taken then
				return
			end
			
			if engage and (aggro_level > 2 or not my_data.at_cover_shoot_pos or my_data.cover_enter_t and my_data.cover_enter_t > 5) then
				local can_charge = not my_data.charge_path_failed_t or data.t - my_data.charge_path_failed_t > 6
				
				if can_charge then
					if my_data.charge_path then
						local path = my_data.charge_path
						my_data.charge_path = nil
						action_taken = CopLogicAttack._chk_request_action_walk_to_cover_shoot_pos(data, my_data, path, "run")
					elseif not my_data.charge_path_search_id and data.attention_obj.nav_tracker then
						my_data.charge_pos = CopLogicAttack._find_flank_pos(data, my_data, focus_enemy.nav_tracker, my_data.weapon_range.optimal)

						if my_data.charge_pos then
							my_data.charge_path_search_id = "charge" .. tostring(data.key)

							data.unit:brain():search_for_path(my_data.charge_path_search_id, my_data.charge_pos, nil, nil, nil)
							
							action_taken = true
						else
							my_data.charge_path_failed_t = TimerManager:game():time()
						end
					end
				end
			end
			
			if action_taken then
				return
			end
			
			action_taken = CopLogicAttack._chk_start_action_move_back(data, my_data, focus_enemy, false)
		end
	end
end

function CopLogicAttack._peek_for_pos_sideways(data, my_data, from_racker, peek_to_pos, height)
	local unit = data.unit
	local my_tracker = from_racker
	local enemy_pos = peek_to_pos
	local my_pos = unit:movement():m_pos()
	local back_vec = my_pos - enemy_pos

	mvector3.set_z(back_vec, 0)
	mvector3.set_length(back_vec, 75)

	local back_pos = my_pos + back_vec
	local ray_params = {
		allow_entry = true,
		trace = true,
		tracker_from = my_tracker,
		pos_to = back_pos
	}
	local ray_res = managers.navigation:raycast(ray_params)
	back_pos = ray_params.trace[1]
	local back_polar = (back_pos - my_pos):to_polar()
	local right_polar = back_polar:with_spin(back_polar.spin + 90):with_r(100 + 80 * my_data.cover_test_step)
	local right_vec = right_polar:to_vector()
	local right_pos = back_pos + right_vec
	ray_params.pos_to = right_pos
	local ray_res = managers.navigation:raycast(ray_params)
	local shoot_from_pos, found_shoot_from_pos = nil
	local ray_softness = 150
	local stand_ray = World:raycast("ray", ray_params.trace[1] + math.UP * height, enemy_pos, "slot_mask", data.visibility_slotmask, "ray_type", "ai_vision")

	if not stand_ray or mvector3.distance(stand_ray.position, enemy_pos) < ray_softness then
		shoot_from_pos = ray_params.trace[1]
		found_shoot_from_pos = true
	end

	if not found_shoot_from_pos then
		local left_pos = back_pos - right_vec
		ray_params.pos_to = left_pos
		local ray_res = managers.navigation:raycast(ray_params)
		local stand_ray = World:raycast("ray", ray_params.trace[1] + math.UP * height, enemy_pos, "slot_mask", data.visibility_slotmask, "ray_type", "ai_vision")

		if not stand_ray or mvector3.distance(stand_ray.position, enemy_pos) < ray_softness then
			shoot_from_pos = ray_params.trace[1]
			found_shoot_from_pos = true
		end
	end
	
	if found_shoot_from_pos then
		return shoot_from_pos
	elseif my_data.cover_test_step <= 2 then
		my_data.cover_test_step = my_data.cover_test_step + 1
		
		return CopLogicAttack._peek_for_pos_sideways(data, my_data, from_racker, peek_to_pos, height)
	else
		return
	end
end

function CopLogicAttack._find_friend_pos(data, my_data)
	local look_for_shields
			
	if data.tactics and data.tactics.shield_cover then
		look_for_shields = true
	end
	
	local best_pos, best_dis, has_shield, has_medic
	local m_tracker = data.unit:movement():nav_tracker()
	local m_field_pos = m_tracker:field_position()
	local dis_sq = mvec3_dis_sq
	local m_key = data.key
	local focus_enemy = data.attention_obj
	
	for u_key, u_data in pairs(data.group.units) do
		if u_key ~= m_key then
			local is_shield = look_for_shields and u_data.unit:base():has_tag("shield")
			local is_medic = u_data.unit:base():has_tag("medic")
			
			if is_shield or is_medic then
				local buddy_logic_data = u_data.unit:brain()._logic_data
				
				if buddy_logic_data then
					if focus_enemy.nav_tracker and buddy_logic_data.internal_data and buddy_logic_data.internal_data.optimal_pos then
						local bud_opti_pos = buddy_logic_data.internal_data.optimal_pos
						
						if dis_sq(data.m_pos, bud_opti_pos) > 22500 then
							local retreat_to = CopLogicAttack._find_retreat_position(bud_opti_pos, focus_enemy.m_pos, focus_enemy.m_head_pos, focus_enemy.nav_tracker, 100, nil)
							
							if retreat_to and LIES:_path_is_straight_line(m_field_pos, retreat_to, data) then
								local m_dis = dis_sq(m_field_pos, retreat_to)
								
								if not best_dis or best_dis > m_dis then
									best_dis = m_dis
									best_pos = retreat_to
									has_shield = true
									has_medic = is_medic --idfk
								end
							end
						end
					elseif buddy_logic_data.unit:movement():nav_tracker() then
						local fall_pos = CopLogicTravel._get_pos_on_wall(u_data.m_pos, 300, 45, nil)
						
						if fall_pos and LIES:_path_is_straight_line(m_field_pos, fall_pos, data) then
							local m_dis = dis_sq(m_field_pos, fall_pos)
							
							if not has_medic or best_dis > m_dis then
								best_dis = m_dis
								best_pos = fall_pos
								has_shield = is_shield
								has_medic = true
								look_for_shields = nil
							end
						end
					end
				end
			end
		end
	end
	
	if best_pos then
		CopLogicAttack._cancel_cover_pathing(data, my_data)

		local new_action_data = {
			variant = "run",
			body_part = 2,
			type = "walk",
			nav_path = {
				mvector3.copy(data.m_pos),
				best_pos
			}
		}
		
		my_data.advancing = data.unit:brain():action_request(new_action_data)

		if my_data.advancing then
			my_data.surprised = true

			return true
		end
	end
end

function CopLogicAttack._find_retreat_position(from_pos, threat_pos, threat_head_pos, threat_tracker, max_dist, vis_required)
	local nav_manager = managers.navigation
	local nr_rays = 7
	local ray_dis = max_dist or 1000
	local step = 180 / nr_rays
	local offset = math.random(step)
	local dir = math.random() < 0.5 and -1 or 1
	step = step * dir
	local step_rot = Rotation(step)
	local offset_rot = Rotation(offset)
	local offset_vec = mvector3.copy(threat_pos)

	mvector3.subtract(offset_vec, from_pos)
	mvector3.normalize(offset_vec)
	mvector3.multiply(offset_vec, ray_dis)
	mvector3.rotate_with(offset_vec, Rotation((90 + offset) * dir))

	local to_pos = nil
	local from_tracker = nav_manager:create_nav_tracker(from_pos)
	local ray_params = {
		trace = true,
		tracker_from = from_tracker
	}
	local rsrv_desc = {
		radius = 60
	}
	local fail_position = nil

	repeat
		to_pos = mvector3.copy(from_pos)

		mvector3.add(to_pos, offset_vec)

		ray_params.pos_to = to_pos
		local ray_res = nav_manager:raycast(ray_params)

		if ray_res then
			local position = ray_params.trace[1]
			
			if vis_required then
				position = CopLogicAttack._confirm_retreat_position(position, threat_pos, threat_head_pos, threat_tracker)
				
				if not position then
					if not fail_position then
						rsrv_desc.position = ray_params.trace[1]
						local is_free = nav_manager:is_pos_free(rsrv_desc)

						if is_free then
							fail_position = ray_params.trace[1]
						end
					end
				end
			elseif not CopLogicAttack._confirm_retreat_position_visless(position, threat_pos, threat_head_pos, threat_tracker) then
				if not fail_position then
					rsrv_desc.position = ray_params.trace[1]
					local is_free = nav_manager:is_pos_free(rsrv_desc)

					if is_free then
						fail_position = ray_params.trace[1]
					end
				end
				
				position = nil
			end
			
			if position then
				rsrv_desc.position = position
				local is_free = nav_manager:is_pos_free(rsrv_desc)

				if is_free then
					managers.navigation:destroy_nav_tracker(from_tracker)

					return position
				end
			end
		elseif not fail_position then
			local position = ray_params.trace[1]
			
			if vis_required then
				position = CopLogicAttack._confirm_retreat_position(position, threat_pos, threat_head_pos, threat_tracker)
			elseif not CopLogicAttack._confirm_retreat_position_visless(position, threat_pos, threat_head_pos, threat_tracker) then
				position = nil
			end
			
			if position then
				rsrv_desc.position = position
				local is_free = nav_manager:is_pos_free(rsrv_desc)

				if is_free then
					fail_position = position
				end
			end
		end

		mvector3.rotate_with(offset_vec, step_rot)

		nr_rays = nr_rays - 1
	until nr_rays == 0

	managers.navigation:destroy_nav_tracker(from_tracker)

	if fail_position then
		return fail_position
	end

	return nil
end

function CopLogicAttack._confirm_retreat_position_visless(retreat_pos, threat_pos, threat_head_pos, threat_tracker)
	local retreat_head_pos = mvector3.copy(retreat_pos)

	mvector3.add(retreat_head_pos, Vector3(0, 0, 82.5))

	local slotmask = managers.slot:get_mask("bullet_blank_impact_targets")
	local ray_res = World:raycast("ray", retreat_head_pos, threat_head_pos, "slot_mask", slotmask, "ray_type", "ai_vision")

	if not ray_res then
		return true
	end

	return false
end

function CopLogicAttack._upd_pose(data, my_data)
	local unit_can_stand = not data.char_tweak.allowed_poses or data.char_tweak.allowed_poses.stand
	local unit_can_crouch = not data.char_tweak.allowed_poses or data.char_tweak.allowed_poses.crouch
	local stand_objective = data.objective and data.objective.pose == "stand"
	local crouch_objective = data.objective and data.objective.pose == "crouch"
	local need_cover = my_data.want_to_take_cover and (not my_data.in_cover or not my_data.in_cover[4])
	
	if not unit_can_stand or need_cover and my_data.cover_test_step and my_data.cover_test_step < 3 then
		if not data.unit:anim_data().crouch and unit_can_crouch then
			return CopLogicAttack._chk_request_action_crouch(data)
		end
	else
		if not data.unit:anim_data().stand and unit_can_stand then
			return CopLogicAttack._chk_request_action_stand(data)
		end
	end
end

function CopLogicAttack.action_complete_clbk(data, action)
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
			CopLogicAttack._upd_aim(data, my_data) --check if i need to turn again
		end
	elseif action_type == "heal" then
		CopLogicAttack._cancel_cover_pathing(data, my_data)
		
		if action:expired() then
			data.logic._upd_aim(data, my_data)
		end
	elseif action_type == "hurt" or action_type == "healed" then
		CopLogicAttack._cancel_cover_pathing(data, my_data)

		if action:expired() then
			if data.is_converted or not CopLogicBase.chk_start_action_dodge(data, "hit") then
				data.logic._upd_aim(data, my_data)
			end
		end
	elseif action_type == "dodge" then
		local timeout = action:timeout()

		if timeout then
			data.dodge_timeout_t = TimerManager:game():time() + math.lerp(timeout[1], timeout[2], math.random())
		end

		CopLogicAttack._cancel_cover_pathing(data, my_data)

		if action:expired() then
			CopLogicAttack._upd_aim(data, my_data)
		end
	end
end

function CopLogicAttack._chk_request_action_walk_to_cover(data, my_data)
	CopLogicAttack._correct_path_start_pos(data, my_data.cover_path)

	local haste = nil
	local pose = nil
	local i = 1
	local travel_dis = 0
	
	repeat
		if my_data.cover_path[i + 1] then
			travel_dis = travel_dis + mvector3.distance_sq(my_data.cover_path[i], my_data.cover_path[i + 1])
			i = i + 1
		else
			break
		end
	until travel_dis > 400 or i >= #my_data.cover_path
	
	if travel_dis > 200 then
		haste = "run"
	end
	
	if travel_dis > 400 then
		pose = "stand"
	else
		pose = data.unit:anim_data().crouch and "crouch"
	end

	haste = haste or "walk"
	pose = pose or data.is_suppressed and "crouch" or "stand"

	if pose == "crouch" and data.char_tweak.crouch_move ~= true then
		pose = "stand"
	end
	
	local end_pose = "crouch"

	if data.char_tweak.allowed_poses then
		if not data.char_tweak.allowed_poses.crouch then
			pose = "stand"
			end_pose = "stand"
		elseif not data.char_tweak.allowed_poses.stand then
			pose = "crouch"
			end_pose = "crouch"
		end
	end

	local new_action_data = {
		type = "walk",
		body_part = 2,
		nav_path = my_data.cover_path,
		variant = haste,
		pose = pose,
		end_pose = end_pose
	}
	my_data.cover_path = nil
	my_data.advancing = data.unit:brain():action_request(new_action_data)

	if my_data.advancing then
		my_data.moving_to_cover = my_data.best_cover
		my_data.at_cover_shoot_pos = nil
		my_data.in_cover = nil

		data.brain:rem_pos_rsrv("path")
	end
end

function CopLogicAttack._pathing_complete_clbk(data)
	local my_data = data.internal_data

	if my_data.processing_cover_path or my_data.charge_path_search_id then
		data.logic._process_pathing_results(data, my_data)
		
		if my_data.cover_path then
			CopLogicAttack._chk_request_action_walk_to_cover(data, my_data)
		elseif my_data.charge_path then
			local path = my_data.charge_path
			my_data.charge_path = nil
			action_taken = CopLogicAttack._chk_request_action_walk_to_cover_shoot_pos(data, my_data, path, "run")
		end
	end
end

function CopLogicAttack.is_available_for_assignment(data, new_objective)
	local my_data = data.internal_data

	if my_data.exiting then
		return
	end

	if new_objective and new_objective.forced then
		return true
	end

	if data.unit:movement():chk_action_forbidden("walk") then
		return
	end

	if data.path_fail_t and data.t < data.path_fail_t + 6 then
		return
	end

	local att_obj = data.attention_obj

	if not att_obj or att_obj.reaction < AIAttentionObject.REACT_AIM then
		return true
	end

	if not new_objective or new_objective.type == "free" then
		return true
	end

	if new_objective then
		local allow_trans, obj_fail = CopLogicBase.is_obstructed(data, new_objective, 0.2)

		if obj_fail then
			return
		end
	end

	return true
end

function CopLogicAttack._chk_covered(data, cover_pos, threat_pos, slotmask)
	local ray_from = temp_vec1

	mvec3_set(ray_from, math.UP)
	mvec3_mul(ray_from, 82.5)
	mvec3_add(ray_from, cover_pos)

	local ray_to_pos = threat_pos

	local low_ray = data.unit:raycast("ray", ray_from, ray_to_pos, "slot_mask", slotmask, "ray_type", "ai_vision", "report")
	local high_ray = nil

	if low_ray then		
		mvec3_set_z(ray_from, ray_from.z + 82.5)

		high_ray = data.unit:raycast("ray", ray_from, ray_to_pos, "slot_mask", slotmask, "ray_type", "ai_vision", "report")
	end

	return low_ray, high_ray
end