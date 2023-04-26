local tmp_vec1 = Vector3()
local tmp_vec2 = Vector3()

local mvec3_set = mvector3.set
local mvec3_norm = mvector3.normalize
local mvec3_dir = mvector3.direction
local mvec3_dot = mvector3.dot
local mvec3_set_z = mvector3.set_z
local mvec3_sub = mvector3.subtract
local mvec3_dis = mvector3.distance
local mvec3_dis_sq = mvector3.distance_sq

local m_rot_x = mrotation.x
local m_rot_y = mrotation.y
local m_rot_z = mrotation.z

function CopLogicBase.chk_am_i_aimed_at(data, attention_obj, max_dot)
	if not attention_obj.is_person or not attention_obj.is_alive then
		return
	end

	if attention_obj.dis < 700 and max_dot > 0.3 then
		max_dot = math.lerp(0.3, max_dot, (attention_obj.dis - 50) / 650)
	end

	local enemy_look_dir = tmp_vec1
	local weapon_rot = nil

	if attention_obj.is_husk_player then
		mvec3_set(enemy_look_dir, attention_obj.unit:movement():detect_look_dir())
	else
		if attention_obj.is_local_player then
			m_rot_y(attention_obj.unit:movement():m_head_rot(), enemy_look_dir)
		else
			if attention_obj.unit:inventory() and attention_obj.unit:inventory():equipped_unit() then
				if attention_obj.unit:movement()._stance.values[3] >= 0.6 then
					local weapon_fire_obj = attention_obj.unit:inventory():equipped_unit():get_object(Idstring("fire"))

					if alive(weapon_fire_obj) then
						weapon_rot = weapon_fire_obj:rotation()
					end
				end
			end

			if weapon_rot then
				m_rot_y(weapon_rot, enemy_look_dir)
			else
				m_rot_z(attention_obj.unit:movement():m_head_rot(), enemy_look_dir)
			end
		end

		mvec3_norm(enemy_look_dir)
	end

	local enemy_vec = tmp_vec2

	mvec3_dir(enemy_vec, attention_obj.m_head_pos, data.unit:movement():m_com())

	return max_dot < mvec3_dot(enemy_vec, enemy_look_dir)
end

function CopLogicBase._report_detections(enemies)
	local group = managers.groupai:state()

	for key, data in pairs(enemies) do
		if data.verified and data.criminal_record and AIAttentionObject.REACT_SUSPICIOUS <= data.reaction then
			group:criminal_spotted(data.unit)
		end
	end
end

function CopLogicBase.should_duck_on_alert(data, alert_data)
	return --let other things tell to crouch
end

function CopLogicBase.is_obstructed(data, objective, strictness, attention)
	local my_data = data.internal_data
	attention = attention or data.attention_obj

	if not objective or objective.is_default or (objective.in_place or not objective.nav_seg) and not objective.action then
		return true, false
	end

	if objective.interrupt_suppression and data.is_suppressed then
		return true, true
	end

	strictness = strictness or 0

	if objective.interrupt_health then
		local health_ratio = data.unit:character_damage():health_ratio()
		local too_much_damage = health_ratio < 1 and health_ratio * (1 - strictness) < objective.interrupt_health
		local is_dead = data.unit:character_damage():dead()

		if too_much_damage or is_dead then
			return true, true
		end
	end

	if objective.interrupt_dis then
		if attention and (AIAttentionObject.REACT_COMBAT <= attention.reaction or data.cool and AIAttentionObject.REACT_SURPRISED <= attention.reaction) then
			if objective.interrupt_dis == -1 then
				return true, true
			elseif math.abs(attention.m_pos.z - data.m_pos.z) < 250 then
				local enemy_dis = attention.dis * (1 - strictness)

				if not attention.verified then
					enemy_dis = 2 * attention.dis * (1 - strictness)
				end

				if attention.is_very_dangerous then
					enemy_dis = enemy_dis * 0.25
				end

				if enemy_dis < objective.interrupt_dis then
					return true, true
				end
			end

			if objective.pos and math.abs(attention.m_pos.z - objective.pos.z) < 250 then
				local enemy_dis = mvector3.distance(objective.pos, attention.m_pos) * (1 - strictness)

				if enemy_dis < objective.interrupt_dis then
					return true, true
				end
			end
		elseif objective.interrupt_dis == -1 and not data.unit:movement():cool() then
			return true, true
		end
	end
	
	if not data.cool and attention and AIAttentionObject.REACT_COMBAT <= attention.reaction and not objective.in_place and objective.type == "defend_area" and (not objective.grp_objective or objective.grp_objective.type ~= "retire") then
		if data.unit:base():has_tag("spooc") or data.unit:base()._tweak_table == "shadow_spooc" then
			data.spooc_attack_timeout_t = data.spooc_attack_timeout_t or 0
			SpoocLogicAttack._chk_play_charge_spooc_sound(data, my_data, attention)
		
			if attention.nav_tracker and attention.is_person and attention.criminal_record and not attention.criminal_record.status and not my_data.spooc_attack and AIAttentionObject.REACT_SHOOT <= attention.reaction and data.spooc_attack_timeout_t < data.t and attention.verified_dis < (my_data.want_to_take_cover and 1500 or 2500) and not data.unit:movement():chk_action_forbidden("walk") and not SpoocLogicAttack._is_last_standing_criminal(attention) and not attention.unit:movement():zipline_unit() and attention.unit:movement():is_SPOOC_attack_allowed() then
				return true, true
			end
		end
		
		if data.unit:base():has_tag("taser") then
			TaserLogicAttack._chk_play_charge_weapon_sound(data, my_data, attention)
		
			if AIAttentionObject.REACT_SPECIAL_ATTACK <= attention.reaction then
				return true, true
			end
		
			local reaction = TaserLogicAttack._chk_reaction_to_attention_object(data, attention) 
			
			if reaction == AIAttentionObject.REACT_SPECIAL_ATTACK then
				return true, true
			end
		end
		
		if data.unit:inventory():shield_unit() then
			local shield_base = data.unit:inventory():shield_unit():base()
			local use_data = shield_base and shield_base.get_use_data and shield_base:get_use_data()
			
			if use_data then
				if shield_base:is_charging() then
					return true, true
				end
			end
		end
	end
	
	if objective.interrupt_on_contact and not objective.in_place then
		if attention and AIAttentionObject.REACT_COMBAT <= attention.reaction then
			local aggro_level = LIES.settings.enemy_aggro_level
			
			if attention.verified_t and data.t - attention.verified_t <= 15 then
				local z_diff = 0
				
				if not data.tactics or not data.tactics.sniper or attention.m_pos.z - data.m_pos.z > -250 then
					z_diff = math.abs(attention.m_pos.z - data.m_pos.z)
				end
				
				local enemy_dis = attention.dis * (1 - strictness)
				local interrupt_dis = data.tactics and data.tactics.ranged_fire and 3000 or data.tactics and data.tactics.sniper and 4000 or 1500
				
				interrupt_dis = interrupt_dis * (1 - strictness)
				
				if z_diff > 250 then
					z_diff = z_diff - 250
					
					interrupt_dis = math.lerp(interrupt_dis, interrupt_dis * 0.25, z_diff / 250)
				end

				if enemy_dis < interrupt_dis then
					return true, true
				end
			end
		end
	end

	return false, false
end

function CopLogicBase.queue_task(internal_data, id, func, data, exec_t, asap)
	if not id then
		log("bad task queued")
		log(tostring(data.name))
	end

	if internal_data.unit and internal_data ~= internal_data.unit:brain()._logic_data.internal_data then
		log("task queued from the wrong logic")
		log(tostring(data.name))
	end

	local qd_tasks = internal_data.queued_tasks

	if qd_tasks then
		if qd_tasks[id] then
			log("task queued twice")
			log(tostring(data.name))
			log(tostring(func))
		end

		qd_tasks[id] = true
	else
		internal_data.queued_tasks = {
			[id] = true
		}
	end

	managers.enemy:queue_task(id, func, data, exec_t, callback(CopLogicBase, CopLogicBase, "on_queued_task", internal_data), asap)
end

function CopLogicBase._set_attention_obj(data, new_att_obj, new_reaction)
	local old_att_obj = data.attention_obj
	data.attention_obj = new_att_obj

	if new_att_obj then
		new_reaction = new_reaction or new_att_obj.settings.reaction
		new_att_obj.reaction = new_reaction
		local new_crim_rec = new_att_obj.criminal_record
		local is_same_obj, contact_chatter_time_ok = nil

		if old_att_obj then
			if old_att_obj.u_key == new_att_obj.u_key then
				is_same_obj = true
				contact_chatter_time_ok = new_crim_rec and data.t - new_crim_rec.det_t > 15

				if new_att_obj.stare_expire_t and new_att_obj.stare_expire_t < data.t then
					if new_att_obj.settings.pause then
						new_att_obj.stare_expire_t = nil
						new_att_obj.pause_expire_t = data.t + math.lerp(new_att_obj.settings.pause[1], new_att_obj.settings.pause[2], math.random())
					end
				elseif new_att_obj.pause_expire_t and new_att_obj.pause_expire_t < data.t then
					if not new_att_obj.settings.attract_chance or math.random() < new_att_obj.settings.attract_chance then
						new_att_obj.pause_expire_t = nil
						new_att_obj.stare_expire_t = data.t + math.lerp(new_att_obj.settings.duration[1], new_att_obj.settings.duration[2], math.random())
					else
						debug_pause_unit(data.unit, "skipping attraction")

						new_att_obj.pause_expire_t = data.t + math.lerp(new_att_obj.settings.pause[1], new_att_obj.settings.pause[2], math.random())
					end
				end
			else
				if old_att_obj.criminal_record then
					managers.groupai:state():on_enemy_disengaging(data.unit, old_att_obj.u_key)
				end

				if new_crim_rec then
					managers.groupai:state():on_enemy_engaging(data.unit, new_att_obj.u_key)
				end
			end
		else
			contact_chatter_time_ok = new_crim_rec and data.t - new_crim_rec.det_t > 15
		
			if new_crim_rec then
				managers.groupai:state():on_enemy_engaging(data.unit, new_att_obj.u_key)
			end			
		end

		if not is_same_obj then
			if new_att_obj.settings.duration then
				new_att_obj.stare_expire_t = data.t + math.lerp(new_att_obj.settings.duration[1], new_att_obj.settings.duration[2], math.random())
				new_att_obj.pause_expire_t = nil
			end
			
			if new_att_obj.acquire_t then
				if not new_att_obj.verified_t or data.t - new_att_obj.verified_t > 2 then
					new_att_obj.react_t = data.t
				else
					local t_since_last_pick = math.clamp(data.t - new_att_obj.acquire_t, 0, 2)
					
					new_att_obj.react_t = data.t - t_since_last_pick
				end
				
			elseif not new_att_obj.react_t then
				new_att_obj.react_t = data.t
			end
				

			new_att_obj.acquire_t = data.t
		end

		if data.char_tweak.chatter and AIAttentionObject.REACT_SHOOT <= new_reaction and new_att_obj.verified and new_att_obj.is_person then
			if data.char_tweak.chatter.contact and contact_chatter_time_ok then
				managers.groupai:state():chk_say_enemy_chatter(data.unit, data.m_pos, "contact")
			elseif new_crim_rec then
				if not new_crim_rec.gun_called_out and data.char_tweak.chatter.criminalhasgun then
					new_crim_rec.gun_called_out = managers.groupai:state():chk_say_enemy_chatter(data.unit, data.m_pos, "criminalhasgun")
				end
			end
		end
	elseif old_att_obj and old_att_obj.criminal_record then
		managers.groupai:state():on_enemy_disengaging(data.unit, old_att_obj.u_key)
	end
end

function CopLogicBase._upd_attention_obj_detection(data, min_reaction, max_reaction)
	local t = data.t
	local detected_obj = data.detected_attention_objects
	local my_data = data.internal_data
	local my_key = data.key
	local my_pos = data.cool and data.unit:movement():m_head_pos() or data.m_pos:with_z(data.unit:movement():m_head_pos().z)
	local my_access = data.SO_access
	local all_attention_objects = managers.groupai:state():get_AI_attention_objects_by_filter(data.SO_access_str, data.team)
	local my_head_fwd = nil
	local my_tracker = data.unit:movement():nav_tracker()
	--local chk_vis_func = my_tracker.check_visibility
	local is_detection_persistent = managers.groupai:state():is_detection_persistent()
	local is_weapons_hot = managers.groupai:state():enemy_weapons_hot()
	local delay = managers.groupai:state():whisper_mode() and 0 or 2
	
	local player_importance_wgt = data.unit:in_slot(managers.slot:get_mask("enemies")) and {}

	local function _angle_chk(attention_pos, dis, strictness)
		mvector3.direction(tmp_vec1, my_pos, attention_pos)

		my_head_fwd = my_head_fwd or data.unit:movement():m_head_rot():z()
		local angle = mvector3.angle(my_head_fwd, tmp_vec1)
		local angle_max = math.lerp(180, my_data.detection.angle_max, math.clamp((dis - 150) / 700, 0, 1))

		if angle_max > angle * strictness then
			return true
		end
	end

	local function _angle_and_dis_chk(handler, settings, attention_pos)
		attention_pos = attention_pos or handler:get_detection_m_pos()
		local dis = mvector3.direction(tmp_vec1, my_pos, attention_pos)
		local dis_multiplier, angle_multiplier = nil
		local max_dis = math.min(my_data.detection.dis_max, settings.max_range or my_data.detection.dis_max)

		if settings.detection and settings.detection.range_mul then
			max_dis = max_dis * settings.detection.range_mul
		end

		dis_multiplier = dis / max_dis

		if settings.uncover_range and my_data.detection.use_uncover_range and dis < settings.uncover_range then
			return -1, 0
		end

		if dis_multiplier < 1 then
			if not is_weapons_hot and settings.notice_requires_FOV then
				my_head_fwd = my_head_fwd or data.unit:movement():m_head_rot():z()
				local angle = mvector3.angle(my_head_fwd, tmp_vec1)

				if angle < 55 and not my_data.detection.use_uncover_range and settings.uncover_range and dis < settings.uncover_range then
					return -1, 0
				end

				local angle_max = math.lerp(180, my_data.detection.angle_max, math.clamp((dis - 150) / 700, 0, 1))
				angle_multiplier = angle / angle_max

				if angle_multiplier < 1 then
					return angle, dis_multiplier
				end
			else
				return 0, dis_multiplier
			end
		end
	end

	local function _nearly_visible_chk(attention_info, detect_pos)
		local near_pos = tmp_vec1

		mvec3_set(near_pos, detect_pos)

		local near_vis_ray = World:raycast("ray", my_pos, near_pos, "slot_mask", data.visibility_slotmask, "ray_type", "ai_vision", "report")

		if near_vis_ray then
			local side_vec = tmp_vec2

			mvec3_set(side_vec, my_pos)
			mvec3_sub(side_vec, detect_pos)
			mvector3.cross(side_vec, side_vec, math.UP)
			mvector3.set_length(side_vec, 29)
			mvector3.set(near_pos, detect_pos)
			mvector3.add(near_pos, side_vec)

			near_vis_ray = World:raycast("ray", my_pos, near_pos, "slot_mask", data.visibility_slotmask, "ray_type", "ai_vision", "report")

			if near_vis_ray then
				mvector3.multiply(side_vec, -2)
				mvector3.add(near_pos, side_vec)

				near_vis_ray = World:raycast("ray", my_pos, near_pos, "slot_mask", data.visibility_slotmask, "ray_type", "ai_vision", "report")
			end
		end

		if not near_vis_ray then
			attention_info.nearly_visible = true
			attention_info.release_t = nil

			if attention_info.last_verified_pos then
				mvec3_set(attention_info.last_verified_pos, near_pos)
				attention_info.last_verified_m_pos = near_pos:with_z(attention_info.m_pos.z)
			else
				attention_info.last_verified_pos = mvector3.copy(near_pos)
				attention_info.last_verified_m_pos = near_pos:with_z(attention_info.m_pos.z)
			end
		end
	end

	local function _chk_record_acquired_attention_importance_wgt(attention_info)
		if not player_importance_wgt or not attention_info.is_human_player then
			return
		end

		local weight = mvector3.direction(tmp_vec1, attention_info.m_head_pos, my_pos)
		local e_fwd = nil

		if attention_info.is_husk_player then
			e_fwd = attention_info.unit:movement():detect_look_dir()
		else
			e_fwd = attention_info.unit:movement():m_head_rot():y()
		end

		local dot = mvector3.dot(e_fwd, tmp_vec1)
		weight = weight * weight * (1 - dot)

		table.insert(player_importance_wgt, attention_info.u_key)
		table.insert(player_importance_wgt, weight)
	end

	local function _chk_record_attention_obj_importance_wgt(u_key, attention_info)
		if not player_importance_wgt then
			return
		end

		local is_human_player, is_local_player, is_husk_player = nil

		if attention_info.unit:base() then
			is_local_player = attention_info.unit:base().is_local_player
			is_husk_player = not is_local_player and attention_info.unit:base().is_husk_player
			is_human_player = is_local_player or is_husk_player
		end

		if not is_human_player then
			return
		end

		local weight = mvector3.direction(tmp_vec1, attention_info.handler:get_detection_m_pos(), my_pos)
		local e_fwd = nil

		if is_husk_player then
			e_fwd = attention_info.unit:movement():detect_look_dir()
		else
			e_fwd = attention_info.unit:movement():m_head_rot():y()
		end

		local dot = mvector3.dot(e_fwd, tmp_vec1)
		weight = weight * weight * (1 - dot)

		table.insert(player_importance_wgt, u_key)
		table.insert(player_importance_wgt, weight)
	end

	for u_key, attention_info in pairs(all_attention_objects) do
		if u_key ~= my_key and not detected_obj[u_key] then
			local settings = attention_info.handler:get_attention(my_access, min_reaction, max_reaction, data.team)

			if settings then
				local acquired = nil
				local attention_pos = attention_info.handler:get_detection_m_pos()

				if _angle_and_dis_chk(attention_info.handler, settings, attention_pos) then
					local vis_ray = is_detection_persistent and nil or World:raycast("ray", my_pos, attention_pos, "slot_mask", data.visibility_slotmask, "ray_type", "ai_vision")

					if not vis_ray or vis_ray.unit:key() == u_key then
						acquired = true
						
						if is_weapons_hot then 
							detected_obj[u_key] = CopLogicBase.identify_attention_obj_instant(data, u_key)
						else
							detected_obj[u_key] = CopLogicBase._create_detected_attention_object_data(data.t, data.unit, u_key, attention_info, settings)
						end
					end
				end

				if not acquired then
					_chk_record_attention_obj_importance_wgt(u_key, attention_info)
				end
			end
		end
	end

	for u_key, attention_info in pairs(detected_obj) do
		if min_reaction and attention_info.reaction < min_reaction or max_reaction and attention_info.reaction > max_reaction then
			detected_obj[u_key] = nil
		elseif t < attention_info.next_verify_t then
			if AIAttentionObject.REACT_SUSPICIOUS <= attention_info.reaction then
				delay = math.min(attention_info.next_verify_t - t, delay)
			end
		else
			attention_info.next_verify_t = t + (attention_info.identified and attention_info.verified and attention_info.settings.verification_interval or attention_info.settings.notice_interval or attention_info.settings.verification_interval)
			delay = math.min(delay, attention_info.settings.verification_interval)
			
			if not data.cool then
				if not attention_info.identified then
					local noticable = nil
					attention_info.notice_progress = nil
					attention_info.prev_notice_chk_t = nil
					attention_info.identified = true
					attention_info.release_t = t + attention_info.settings.release_delay
					attention_info.identified_t = t
					noticable = true

					data.logic.on_attention_obj_identified(data, u_key, attention_info)

					if noticable ~= false and attention_info.settings.notice_clbk then
						attention_info.settings.notice_clbk(data.unit, noticable)
					end
				end
			elseif not attention_info.identified then
				local noticable = nil
				local angle, dis_multiplier = _angle_and_dis_chk(attention_info.handler, attention_info.settings)

				if angle then
					local attention_pos = attention_info.handler:get_detection_m_pos()
					local vis_ray = World:raycast("ray", my_pos, attention_pos, "slot_mask", data.visibility_slotmask, "ray_type", "ai_vision")

					if not vis_ray or vis_ray.unit:key() == u_key then
						noticable = true
					end
				end

				local delta_prog = nil
				local dt = t - attention_info.prev_notice_chk_t

				if noticable then
					if angle == -1 then
						delta_prog = 1
					else
						local min_delay = my_data.detection.delay[1]
						local max_delay = my_data.detection.delay[2]
						local angle_mul_mod = 0.25 * math.min(angle / my_data.detection.angle_max, 1)
						local dis_mul_mod = 0.75 * dis_multiplier
						local notice_delay_mul = attention_info.settings.notice_delay_mul or 1

						if attention_info.settings.detection and attention_info.settings.detection.delay_mul then
							notice_delay_mul = notice_delay_mul * attention_info.settings.detection.delay_mul
						end

						local notice_delay_modified = math.lerp(min_delay * notice_delay_mul, max_delay, dis_mul_mod + angle_mul_mod)
						
						if attention_info.is_husk_player then
							local peer = managers.network:session():peer_by_unit(attention_info.unit)
							local latency = peer and Network:qos(peer:rpc()).ping or nil
							
							if latency then
								local ping = latency / 1000
								
								notice_delay_modified = notice_delay_modified + ping + 0.02
							end	
						end
							
						delta_prog = notice_delay_modified > 0 and dt / notice_delay_modified or 1
					end
				else
					delta_prog = dt * -0.125
				end

				attention_info.notice_progress = attention_info.notice_progress + delta_prog

				if attention_info.notice_progress > 1 then
					attention_info.notice_progress = nil
					attention_info.prev_notice_chk_t = nil
					attention_info.identified = true
					attention_info.release_t = t + attention_info.settings.release_delay
					attention_info.identified_t = t
					noticable = true

					data.logic.on_attention_obj_identified(data, u_key, attention_info)
				elseif attention_info.notice_progress < 0 then
					CopLogicBase._destroy_detected_attention_object_data(data, attention_info)

					noticable = false
				else
					noticable = attention_info.notice_progress
					attention_info.prev_notice_chk_t = t

					if data.cool and AIAttentionObject.REACT_SCARED <= attention_info.settings.reaction then
						managers.groupai:state():on_criminal_suspicion_progress(attention_info.unit, data.unit, noticable)
					end
				end

				if noticable ~= false and attention_info.settings.notice_clbk then
					attention_info.settings.notice_clbk(data.unit, noticable)
				end
			end

			if attention_info.identified then
				delay = math.min(delay, attention_info.settings.verification_interval)
				attention_info.nearly_visible = nil
				local verified, vis_ray = nil
				local attention_pos = attention_info.handler:get_detection_m_pos()
				local dis = mvector3.distance(data.m_pos, attention_info.m_pos)

				if dis < my_data.detection.dis_max * 1.2 and (not attention_info.settings.max_range or dis < attention_info.settings.max_range * (attention_info.settings.detection and attention_info.settings.detection.range_mul or 1) * 1.2) then
					local detect_pos = attention_pos

					local in_FOV = not attention_info.settings.notice_requires_FOV or data.enemy_slotmask and attention_info.unit:in_slot(data.enemy_slotmask) or _angle_chk(attention_pos, dis, 0.8)
					
					if in_FOV then
						vis_ray = World:raycast("ray", my_pos, detect_pos, "slot_mask", data.visibility_slotmask, "ray_type", "ai_vision")

						if not vis_ray or vis_ray.unit:key() == u_key then
							verified = true
						end
					end

					attention_info.verified = verified
				end

				attention_info.dis = dis
				attention_info.vis_ray = vis_ray and vis_ray.dis or nil
				local is_ignored = false

				if attention_info.unit:movement() and attention_info.unit:movement().is_cuffed then
					is_ignored = attention_info.unit:movement():is_cuffed()
				end

				if is_ignored then
					CopLogicBase._destroy_detected_attention_object_data(data, attention_info)
				elseif verified then
					attention_info.release_t = nil
					attention_info.verified_t = t

					mvector3.set(attention_info.verified_pos, attention_pos)

					attention_info.last_verified_pos = mvector3.copy(attention_pos)
					attention_info.last_verified_m_pos = mvector3.copy(attention_info.m_pos)
					attention_info.verified_dis = dis
				elseif data.enemy_slotmask and attention_info.unit:in_slot(data.enemy_slotmask) then
					if attention_info.criminal_record and AIAttentionObject.REACT_COMBAT <= attention_info.settings.reaction then
						if not is_detection_persistent and mvector3.distance(attention_pos, attention_info.criminal_record.pos) > 700 then
							CopLogicBase._destroy_detected_attention_object_data(data, attention_info)
						else
							delay = math.min(0.2, delay)
							attention_info.verified_pos = attention_info.criminal_record.pos:with_z(attention_pos.z)
							attention_info.verified_dis = dis

							if data.logic._chk_nearly_visible_chk_needed(data, attention_info, u_key) and attention_info.dis < 2000 then
								_nearly_visible_chk(attention_info, attention_pos)
							end
						end
					elseif attention_info.release_t and attention_info.release_t < t then
						CopLogicBase._destroy_detected_attention_object_data(data, attention_info)
					else
						attention_info.release_t = attention_info.release_t or t + attention_info.settings.release_delay
					end
				elseif attention_info.release_t and attention_info.release_t < t then
					CopLogicBase._destroy_detected_attention_object_data(data, attention_info)
				else
					attention_info.release_t = attention_info.release_t or t + attention_info.settings.release_delay
				end
			end
		end

		_chk_record_acquired_attention_importance_wgt(attention_info)
	end

	if player_importance_wgt then
		managers.groupai:state():set_importance_weight(data.key, player_importance_wgt)
	end

	return delay
end

function CopLogicBase.death_clbk(data, damage_info)
	if data.enrage_data and data.enrage_data.played_warning then
		local is_dead = data.unit:character_damage():dead()
		if is_dead then
			data.unit:sound():play("slot_machine_loose", nil, true)
		else
			data.unit:sound():corpse_play("slot_machine_loose", nil, true)
		end
		
		data.enrage_data.played_warning = nil
	end
end