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

function CopLogicBase._report_detections(enemies)
	local group = managers.groupai:state()

	for key, data in pairs(enemies) do
		if data.verified and data.criminal_record and AIAttentionObject.REACT_SUSPICIOUS <= data.reaction then
			group:criminal_spotted(data.unit)
		end
	end
end

function CopLogicBase.on_objective_unit_damaged(data, unit, attacker_unit)
	if not alive(data.unit) then
		return
	end

	if unit and unit:character_damage():dead() then
		data.objective.destroy_clbk_key = nil
		data.objective.death_clbk_key = nil

		data.objective_failed_clbk(data.unit, data.objective)
	end
end

function CopLogicBase.should_duck_on_alert(data, alert_data)
	return --let other things tell to crouch
end

function CopLogicBase.upd_falloff_sim(data)
	local my_data = data.internal_data
	local focus_enemy = data.attention_obj
	data.t = TimerManager:game():time()
	
	if data.brain._minigunner_firing_buff then
		local minigunner_firing_buff = data.brain._minigunner_firing_buff
		
		local dt = data.t - minigunner_firing_buff.last_chk_t
		
		--log(dt)
		
		if dt > 0.35 then
			if dt > 1 then
				minigunner_firing_buff.amount = 0
			elseif my_data.firing then
				local increase = 0.25 * dt
				minigunner_firing_buff.amount = math.clamp(minigunner_firing_buff.amount + increase, 0, 1)
			else
				local decrease = -dt
				minigunner_firing_buff.amount = math.clamp(minigunner_firing_buff.amount + decrease, 0, 1)
			end

			data.unit:base():change_buff_by_id("base_damage", minigunner_firing_buff.id, minigunner_firing_buff.amount)
			minigunner_firing_buff.last_chk_t = data.t
		end
	end
	
	if data.brain._needs_falloff then
		local falloff_sim = data.brain._needs_falloff
		local old_amount = falloff_sim.amount
		
		if focus_enemy and AIAttentionObject.REACT_COMBAT <= focus_enemy.reaction then
			focus_enemy.dis = mvec3_dis(data.m_pos, focus_enemy.m_pos)
			
			if focus_enemy.dis > 3000 then
				if data.unit:base()._shotgunner then
					falloff_sim.amount = 1 - (15 / 375)
				else
					falloff_sim.amount = 1 - (30 / 90)
				end
				
				if falloff_sim.amount ~= old_amount then
					data.unit:base():change_buff_by_id("base_damage", falloff_sim.id, -falloff_sim.amount)
				end
			elseif focus_enemy.dis > 2000 then
				if data.unit:base()._shotgunner then
					falloff_sim.amount = 1 - (45 / 375)
				else
					falloff_sim.amount = 1 - (60 / 90)
				end
				
				if falloff_sim.amount ~= old_amount then
					data.unit:base():change_buff_by_id("base_damage", falloff_sim.id, -falloff_sim.amount)
				end
			elseif focus_enemy.dis > 1000 then
				if data.unit:base()._shotgunner then
					falloff_sim.amount = 1 - (60 / 375)
				else
					falloff_sim.amount = 1 - (70 / 90)
				end
				
				if falloff_sim.amount ~= old_amount then
					data.unit:base():change_buff_by_id("base_damage", falloff_sim.id, -falloff_sim.amount)
				end
			elseif focus_enemy.dis > 500 then
				if data.unit:base()._shotgunner then
					falloff_sim.amount = 1 - (120 / 375)
				else
					falloff_sim.amount = 1 - (80 / 90)
				end
				
				if falloff_sim.amount ~= old_amount then
					data.unit:base():change_buff_by_id("base_damage", falloff_sim.id, -falloff_sim.amount)
				end
			elseif data.unit:base()._shotgunner then
				falloff_sim.amount = 1 - (150 / 375)
				
				if falloff_sim.amount ~= old_amount then
					data.unit:base():change_buff_by_id("base_damage", falloff_sim.id, -falloff_sim.amount)
				end
			elseif falloff_sim.amount > 0 then
				falloff_sim.amount = 0
				
				if falloff_sim.amount ~= old_amount then
					data.unit:base():change_buff_by_id("base_damage", falloff_sim.id, 0)
				end
			end
		elseif falloff_sim.amount > 0 then
			falloff_sim.amount = 0
			data.unit:base():change_buff_by_id("base_damage", falloff_sim.id, 0)
		end
	end
end

function CopLogicBase.check_sabotage_objective_not_allowed(data, objective)
	if not objective then
		return
	end
	
	if not data.brain:objective_is_sabotage(objective) then
		return
	end
	
	if data.objective and objective ~= data.objective and data.objective.sabotage then
		return true
	end

	if LIES.settings.hhtacs and not managers.skirmish:is_skirmish() then
		if not data.group or data.SO_access_str == "security" or data.group and data.group.objective and (data.group.objective.type == "assault_area" or data.group.objective.type == "retire") then
			if not data.tactics or not data.tactics.sabotage then
				return true
			end
		end
	end
	
	if objective.pos then
		if data.attention_obj and data.attention_obj.nav_tracker and AIAttentionObject.REACT_COMBAT <= data.attention_obj.reaction then
			if data.attention_obj.verified and math.abs(objective.pos.z - data.attention_obj.m_pos.z) < 250 and mvec3_dis_sq(objective.pos, data.attention_obj.m_pos) < 490000 then
				return true
			end
		end

		local objective_nav_seg = managers.navigation:get_nav_seg_from_pos(objective.pos)

		local all_criminals = managers.groupai:state():all_char_criminals()

		for u_key, u_data in pairs(all_criminals) do
			if not u_data.status or u_data.status == "electrified" then
				local crim_area = managers.groupai:state():get_area_from_nav_seg_id(u_data.tracker:nav_segment())

				if crim_area.nav_segs[objective_nav_seg] then
					return true
				end
			end
		end
	end
	
	if data.attention_obj and data.attention_obj.nav_tracker and AIAttentionObject.REACT_COMBAT <= data.attention_obj.reaction then
		if data.attention_obj.verified and math.abs(data.m_pos.z - data.attention_obj.m_pos.z) < 250 and mvec3_dis_sq(data.m_pos, data.attention_obj.m_pos) < 490000 then
			return true
		end
	end

	local my_seg = data.unit:movement():nav_tracker():nav_segment()

	local all_criminals = managers.groupai:state():all_char_criminals()

	for u_key, u_data in pairs(all_criminals) do
		if not u_data.status or u_data.status == "electrified" then
			local crim_area = managers.groupai:state():get_area_from_nav_seg_id(u_data.tracker:nav_segment())

			if crim_area.nav_segs[my_seg] then
				return true
			end
		end
	end
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
	
	if objective.sabotage then
		if objective.pos then
			if data.attention_obj and data.attention_obj.nav_tracker and AIAttentionObject.REACT_COMBAT <= data.attention_obj.reaction then
				if data.attention_obj.verified and math.abs(objective.pos.z - data.attention_obj.m_pos.z) < 250 and mvec3_dis_sq(objective.pos, data.attention_obj.m_pos) < 490000 then
					return true, true
				end
			end

			local objective_nav_seg = managers.navigation:get_nav_seg_from_pos(objective.pos)

			local all_criminals = managers.groupai:state():all_char_criminals()

			for u_key, u_data in pairs(all_criminals) do
				if not u_data.status or u_data.status == "electrified" then
					local crim_area = managers.groupai:state():get_area_from_nav_seg_id(u_data.tracker:nav_segment())

					if crim_area.nav_segs[objective_nav_seg] then
						return true, true
					end
				end
			end
		end
		
		
		if data.attention_obj and data.attention_obj.nav_tracker and AIAttentionObject.REACT_COMBAT <= data.attention_obj.reaction then
			if data.attention_obj.verified and math.abs(data.m_pos.z - data.attention_obj.m_pos.z) < 250 and mvec3_dis_sq(data.m_pos, data.attention_obj.m_pos) < 490000 then
				return true, true
			end
		end

		local my_seg = data.unit:movement():nav_tracker():nav_segment()

		local all_criminals = managers.groupai:state():all_char_criminals()

		for u_key, u_data in pairs(all_criminals) do
			if not u_data.status or u_data.status == "electrified" then
				local crim_area = managers.groupai:state():get_area_from_nav_seg_id(u_data.tracker:nav_segment())

				if crim_area.nav_segs[my_seg] then
					return true, true
				end
			end
		end
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
		
			if attention.verified and attention.nav_tracker and attention.is_person and attention.criminal_record and not attention.criminal_record.status and not my_data.spooc_attack and AIAttentionObject.REACT_SHOOT <= attention.reaction and data.spooc_attack_timeout_t < data.t and attention.verified_dis < (my_data.want_to_take_cover and 1500 or 2500) and not data.unit:movement():chk_action_forbidden("walk") and not SpoocLogicAttack._is_last_standing_criminal(attention) and not attention.unit:movement():zipline_unit() and attention.unit:movement():is_SPOOC_attack_allowed() then
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
					return true, false
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
		log(tostring(data.unit:base()._tweak_table))
	end

	if internal_data.unit and internal_data ~= internal_data.unit:brain()._logic_data.internal_data then
		log("task queued from the wrong logic")
		log(tostring(data.name))
		log(tostring(data.unit:base()._tweak_table))
		log(tostring(id))
	end

	local qd_tasks = internal_data.queued_tasks

	if qd_tasks then
		if qd_tasks[id] then
			log("task queued twice")
			log(tostring(data.name))
			log(tostring(data.unit:base()._tweak_table))
			log(tostring(id))
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
					local t_since_verified = new_att_obj.verified_t and math.clamp(data.t - new_att_obj.verified_t, 0, 2) or 0
					
					new_att_obj.react_t = data.t + math.max(t_since_last_pick, t_since_verified)
				end
			elseif not new_att_obj.react_t then
				new_att_obj.react_t = data.t
			end
				

			new_att_obj.acquire_t = data.t
		end

		if data.char_tweak.chatter and AIAttentionObject.REACT_SHOOT <= new_reaction and new_att_obj.verified and new_att_obj.is_person then
			if data.char_tweak.chatter.contact and contact_chatter_time_ok then
				local said = managers.groupai:state():chk_say_enemy_chatter(data.unit, data.m_pos, "contact")
							
				if not said and data.unit:base().has_tag and data.unit:base():has_tag("special") then
					if not data.next_priority_speak_t or data.next_priority_speak_t < data.t then
						if data.unit:sound():say("c01", true) then
							data.next_priority_speak_t = data.t + 4
						end
					end
				end
			elseif new_crim_rec and data.char_tweak.chatter then
				if not new_crim_rec.gun_called_out and data.char_tweak.chatter.criminalhasgun then
					new_crim_rec.gun_called_out = managers.groupai:state():chk_say_enemy_chatter(data.unit, data.m_pos, "criminalhasgun")
				end
			end
		end
	elseif old_att_obj and old_att_obj.criminal_record then
		managers.groupai:state():on_enemy_disengaging(data.unit, old_att_obj.u_key)
	end
end

function CopLogicBase._upd_suspicion(data, my_data, attention_obj)
	local function _exit_func()
		attention_obj.unit:movement():on_uncovered(data.unit)

		local reaction, state_name = nil

		if attention_obj.dis < 2000 and attention_obj.verified and not data.char_tweak.no_arrest and not attention_obj.forced then
			reaction = AIAttentionObject.REACT_ARREST
			state_name = "arrest"
		else
			reaction = AIAttentionObject.REACT_COMBAT
			state_name = "attack"
		end

		attention_obj.reaction = reaction
		local allow_trans, obj_failed = CopLogicBase.is_obstructed(data, data.objective, nil, attention_obj)

		if allow_trans then
			if obj_failed then
				data.objective_failed_clbk(data.unit, data.objective)

				if my_data ~= data.internal_data then
					return true
				end
			end

			CopLogicBase._exit(data.unit, state_name)

			return true
		end
	end

	local dis = attention_obj.dis
	local susp_settings = attention_obj.unit:base():suspicion_settings()
	local hhtacs = LIES.settings.hhtacs

	if attention_obj.verified and attention_obj.settings.uncover_range and dis < math.min(attention_obj.settings.max_range, attention_obj.settings.uncover_range) * susp_settings.range_mul then
		attention_obj.unit:movement():on_suspicion(data.unit, true)
		managers.groupai:state():criminal_spotted(attention_obj.unit)

		return _exit_func()
	elseif attention_obj.verified and attention_obj.settings.suspicion_range and dis < math.min(attention_obj.settings.max_range, attention_obj.settings.suspicion_range) * susp_settings.range_mul then
		local my_head_fwd = data.unit:movement():m_head_rot():z()
		mvector3.direction(tmp_vec1, data.unit:movement():m_head_pos(), attention_obj.verified_pos)
		local angle = mvector3.angle(my_head_fwd, tmp_vec1)
		local angle_max
		
		if hhtacs then
			angle_max = math.lerp(180, my_data.detection.angle_max, math.clamp(dis / 200, 0, 1))
		else
			angle_max = math.lerp(180, my_data.detection.angle_max, math.clamp((dis - 150) / 700, 0, 1))
		end
		
		if angle < angle_max then
			if attention_obj.last_suspicion_t then
				local dt = data.t - attention_obj.last_suspicion_t
				local range_mul = susp_settings.range_mul
				
				if hhtacs then
					range_mul = math.lerp(range_mul, 1, 0.75)
				end
				
				local range_max = (attention_obj.settings.suspicion_range - (attention_obj.settings.uncover_range or 0)) * susp_settings.range_mul
				local range_min = (attention_obj.settings.uncover_range or 0) * susp_settings.range_mul
				local mul = 1 - (dis - range_min) / range_max
				local settings_mul
				
				if hhtacs then
					settings_mul = math.lerp(susp_settings.buildup_mul, 1, 0.75) / attention_obj.settings.suspicion_duration
				else
					settings_mul = susp_settings.buildup_mul / attention_obj.settings.suspicion_duration
				end
				
				local progress = dt * mul * settings_mul
				attention_obj.uncover_progress = (attention_obj.uncover_progress or 0) + progress

				if attention_obj.uncover_progress < 1 then
					attention_obj.unit:movement():on_suspicion(data.unit, attention_obj.uncover_progress)
					managers.groupai:state():on_criminal_suspicion_progress(attention_obj.unit, data.unit, attention_obj.uncover_progress)
				else
					attention_obj.unit:movement():on_suspicion(data.unit, true)
					managers.groupai:state():criminal_spotted(attention_obj.unit)

					return _exit_func()
				end
			else
				attention_obj.uncover_progress = 0
			end
		elseif attention_obj.uncover_progress then
			if attention_obj.last_suspicion_t then
				local dt = data.t - attention_obj.last_suspicion_t
				attention_obj.uncover_progress = attention_obj.uncover_progress - dt

				if attention_obj.uncover_progress <= 0 then
					attention_obj.uncover_progress = nil
					attention_obj.last_suspicion_t = nil

					attention_obj.unit:movement():on_suspicion(data.unit, false)
				else
					attention_obj.unit:movement():on_suspicion(data.unit, attention_obj.uncover_progress)
				end
			end
		end
		
		if attention_obj.uncover_progress then
			attention_obj.last_suspicion_t = data.t
		end
	elseif attention_obj.uncover_progress then
		if attention_obj.last_suspicion_t then
			local dt = data.t - attention_obj.last_suspicion_t
			attention_obj.uncover_progress = attention_obj.uncover_progress - dt

			if attention_obj.uncover_progress <= 0 then
				attention_obj.uncover_progress = nil
				attention_obj.last_suspicion_t = nil

				attention_obj.unit:movement():on_suspicion(data.unit, false)
			else
				attention_obj.unit:movement():on_suspicion(data.unit, attention_obj.uncover_progress)
			end
		else
			attention_obj.last_suspicion_t = data.t
		end
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
	local hhtacs = LIES.settings.hhtacs
	
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
			local range_mul = settings.detection.range_mul
			
			if hhtacs then
				range_mul = math.lerp(range_mul, 1, 0.75)
			end
			
			max_dis = max_dis * range_mul
		end

		dis_multiplier = dis / max_dis

		if settings.uncover_range and my_data.detection.use_uncover_range and dis < settings.uncover_range then
			return hhtacs and 0 or -1, hhtacs and dis_multiplier or 0
		end

		if dis_multiplier < 1 then
			if not is_weapons_hot and settings.notice_requires_FOV then
				my_head_fwd = my_head_fwd or data.unit:movement():m_head_rot():z()
				local angle = mvector3.angle(my_head_fwd, tmp_vec1)
				
				if hhtacs then
					if not my_data.detection.use_uncover_range and settings.uncover_range and dis < settings.uncover_range then
						local att_unit = handler:unit()
						
						if att_unit:movement() then
							local att_unit_pos = att_unit:movement():m_pos()
							local uncover_dis = mvec3_dis(att_unit_pos, data.m_pos)
							
							if uncover_dis <= 90 then --*bump*
								return -1, 0
							end
						end
						
						if angle < 55 then
							return -1, 0
						end
					end
				elseif angle < 55 and not my_data.detection.use_uncover_range and settings.uncover_range and dis < settings.uncover_range then
					return -1, 0
				end
				
				if hhtacs then
					angle_max = math.lerp(180, my_data.detection.angle_max, math.clamp(dis / 200, 0, 1))	
				else
					angle_max = math.lerp(180, my_data.detection.angle_max, math.clamp((dis - 150) / 700, 0, 1))
				end
				
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
			mvector3.set_length(side_vec, 30)
			mvec3_set(near_pos, detect_pos)
			mvector3.add(near_pos, side_vec)

			near_vis_ray = World:raycast("ray", my_pos, near_pos, "slot_mask", data.visibility_slotmask, "ray_type", "ai_vision", "report")

			if near_vis_ray then
				mvector3.multiply(side_vec, -2)
				mvector3.add(near_pos, side_vec)

				near_vis_ray = World:raycast("ray", my_pos, near_pos, "slot_mask", data.visibility_slotmask, "ray_type", "ai_vision", "report")
				
				if near_vis_ray then
					mvec3_set(near_pos, detect_pos)
					mvector3.add(near_pos, math.UP * 30)
					
					near_vis_ray = World:raycast("ray", my_pos, near_pos, "slot_mask", data.visibility_slotmask, "ray_type", "ai_vision", "report")
				end
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
		local e_fwd = attention_info.unit:movement():detect_look_dir()

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
			
			if not data.cool and is_weapons_hot then
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
				
				local attention_pos = attention_info.handler:get_detection_m_pos()
				
				if angle then
					local vis_ray = World:raycast("ray", my_pos, attention_pos, "slot_mask", data.visibility_slotmask, "ray_type", "ai_vision")

					if not vis_ray or vis_ray.unit:key() == u_key then
						noticable = true
					end
				end

				local delta_prog = 0
				local dt = t - attention_info.prev_notice_chk_t
				
				attention_info.real_pos = mvector3.copy(attention_pos)

				if noticable then
					local attention_pos = attention_info.handler:get_detection_m_pos()
					attention_info.notice_t = t
					attention_info.notice_pos = mvector3.copy(attention_info.m_pos)
					attention_info.last_notice_pos = mvector3.copy(attention_pos)
					attention_info.noticed = true
				
					if angle == -1 then
						if attention_info.is_husk_player then
							local peer = managers.network:session():peer_by_unit(attention_info.unit)
							local latency = peer and Network:qos(peer:rpc()).ping or nil
							
							if latency then
								local ping = latency / 1000
								
								delta_prog = dt / ping + 0.02
							end	
						else
							delta_prog = 1
						end
					else
						local min_delay = attention_info.settings.delay_override and attention_info.settings.delay_override[1] or my_data.detection.delay[1]
						local max_delay = attention_info.settings.delay_override and attention_info.settings.delay_override[2] or my_data.detection.delay[2]
						local angle_mul_mod = 0.25 * math.min(angle / my_data.detection.angle_max, 1)
						local dis_mul_mod = 0.75 * dis_multiplier

						local notice_delay_mul = attention_info.settings.notice_delay_mul or 1

						if attention_info.settings.detection and attention_info.settings.detection.delay_mul then
							if hhtacs then
								local mul = attention_info.settings.detection.delay_mul
								mul = math.lerp(mul, 1, 0.75) --detection risk affects detection rate 75% less
								
								notice_delay_mul = notice_delay_mul * mul
							else
								notice_delay_mul = notice_delay_mul * attention_info.settings.detection.delay_mul
							end
						end

						local notice_delay_modified = math.lerp(min_delay * notice_delay_mul, max_delay, math.clamp(dis_mul_mod + angle_mul_mod, 0, 1))
						
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
					attention_info.noticed = nil
					
					delta_prog = dt * -0.125
					
					local attention_pos = attention_info.handler:get_detection_m_pos()
					
					if attention_info.last_notice_pos then
						local lerp = math.clamp(mvector3.distance(attention_pos, attention_info.last_notice_pos) / 400)
						
						if attention_info.notice_t and data.t - attention_info.notice_t < math.lerp(2, 0.2, lerp) then					
							attention_info.notice_pos = mvector3.copy(attention_info.m_pos)
						end
					end
				end

				attention_info.notice_progress = math.clamp(attention_info.notice_progress + delta_prog, 0, 1)

				if attention_info.notice_progress == 1 then
					attention_info.notice_progress = nil
					attention_info.prev_notice_chk_t = nil
					attention_info.identified = true
					attention_info.release_t = t + attention_info.settings.release_delay
					attention_info.identified_t = t
					noticable = true

					data.logic.on_attention_obj_identified(data, u_key, attention_info)
				elseif attention_info.notice_progress == 0 and not attention_info.being_chased and (not hhtacs or not attention_info.notice_t or not attention_info.detected_criminal or attention_info.detected_criminal and t - attention_info.notice_t > 2) then
					CopLogicBase._destroy_detected_attention_object_data(data, attention_info)

					noticable = false
				else
					noticable = math.clamp(attention_info.notice_progress, 0.01, 1)
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
						if data.logic._keep_player_focus_t and attention_info.is_human_player and attention_info.verified_t and data.t - attention_info.verified_t < data.logic._keep_player_focus_t then
							delay = math.min(0.2, delay)
							attention_info.verified_pos = attention_info.criminal_record.pos:with_z(attention_pos.z)
							attention_info.verified_dis = dis

							if data.logic._chk_nearly_visible_chk_needed(data, attention_info, u_key) and attention_info.dis < 2000 then
								_nearly_visible_chk(attention_info, attention_pos)
							end
						elseif not is_detection_persistent and mvector3.distance(attention_pos, attention_info.criminal_record.pos) > 700 then
							CopLogicBase._destroy_detected_attention_object_data(data, attention_info)
						else
							delay = math.min(0.2, delay)
							attention_info.verified_pos = attention_info.criminal_record.pos:with_z(attention_pos.z)
							attention_info.verified_dis = dis

							if data.logic._chk_nearly_visible_chk_needed(data, attention_info, u_key) and attention_info.dis < 2000 then
								_nearly_visible_chk(attention_info, attention_pos)
							end
						end
					elseif is_detection_persistent and AIAttentionObject.REACT_COMBAT <= attention_info.settings.reaction then
						delay = math.min(0.2, delay)
						mvector3.set(attention_info.verified_pos, attention_pos)
						attention_info.verified_dis = dis
						
						if data.logic._chk_nearly_visible_chk_needed(data, attention_info, u_key) and attention_info.dis < 2000 then
							_nearly_visible_chk(attention_info, attention_pos)
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

function CopLogicBase.on_new_objective(data, old_objective)
	if old_objective and old_objective.follow_unit and alive(old_objective.follow_unit) then
		if old_objective.destroy_clbk_key then
			old_objective.follow_unit:base():remove_destroy_listener(old_objective.destroy_clbk_key)

			old_objective.destroy_clbk_key = nil
		end

		if old_objective.death_clbk_key then
			old_objective.follow_unit:character_damage():remove_listener(old_objective.death_clbk_key)

			old_objective.death_clbk_key = nil
		end
	end

	local new_objective = data.objective

	if new_objective and new_objective.follow_unit and not new_objective.destroy_clbk_key then
		local ext_brain = data.unit:brain()
		local destroy_clbk_key = "objective_" .. new_objective.type .. tostring(data.unit:key())
		new_objective.destroy_clbk_key = destroy_clbk_key

		new_objective.follow_unit:base():add_destroy_listener(destroy_clbk_key, callback(ext_brain, ext_brain, "on_objective_unit_destroyed"))

		if new_objective.follow_unit:character_damage() then
			new_objective.death_clbk_key = destroy_clbk_key

			new_objective.follow_unit:character_damage():add_listener(destroy_clbk_key, {
				"death",
				"hurt"
			}, callback(ext_brain, ext_brain, "on_objective_unit_damaged"))
		end
	end
end

function CopLogicBase._evaluate_reason_to_surrender(data, my_data, aggressor_unit)
	local surrender_tweak = data.char_tweak.surrender

	if not surrender_tweak then
		return
	end

	if surrender_tweak.base_chance >= 1 then
		return 0
	end

	local t = data.t

	if data.surrender_window and data.surrender_window.window_expire_t < t then
		data.unit:brain():on_surrender_chance()

		return
	end
	
	if LIES.settings.hhtacs and managers.groupai:state():phalanx_vip() then
		return
	end

	local hold_chance = 1
	local surrender_chk = {
		health = function (health_surrender)
			local health_ratio = data.unit:character_damage():health_ratio()

			if health_ratio < 1 then
				local min_setting, max_setting = nil

				for k, v in pairs(health_surrender) do
					if not min_setting or k < min_setting.k then
						min_setting = {
							k = k,
							v = v
						}
					end

					if not max_setting or max_setting.k < k then
						max_setting = {
							k = k,
							v = v
						}
					end
				end

				if health_ratio < max_setting.k then
					hold_chance = hold_chance * (1 - math.lerp(min_setting.v, max_setting.v, math.max(0, health_ratio - min_setting.k) / (max_setting.k - min_setting.k)))
				end
			end
		end,
		aggressor_dis = function (agg_dis_surrender)
			local agg_dis = mvec3_dis(data.m_pos, aggressor_unit:movement():m_newest_pos())
			local min_setting, max_setting = nil

			for k, v in pairs(agg_dis_surrender) do
				if not min_setting or k < min_setting.k then
					min_setting = {
						k = k,
						v = v
					}
				end

				if not max_setting or max_setting.k < k then
					max_setting = {
						k = k,
						v = v
					}
				end
			end

			if agg_dis < max_setting.k then
				hold_chance = hold_chance * (1 - math.lerp(min_setting.v, max_setting.v, math.max(0, agg_dis - min_setting.k) / (max_setting.k - min_setting.k)))
			end
		end,
		weapon_down = function (weap_down_surrender)
			local anim_data = data.unit:anim_data()

			if anim_data.reload or anim_data.hurt or anim_data.fumble then
				hold_chance = hold_chance * (1 - weap_down_surrender)
			elseif data.unit:movement():stance_name() == "ntl" then
				hold_chance = hold_chance * (1 - weap_down_surrender)
			end

			local ammo_max, ammo = data.unit:inventory():equipped_unit():base():ammo_info()

			if ammo == 0 then
				hold_chance = hold_chance * (1 - weap_down_surrender)
			end
		end,
		flanked = function (flanked_surrender)
			local dis = mvec3_dir(tmp_vec1, data.m_pos, aggressor_unit:movement():m_newest_pos())

			if dis > 250 then
				local fwd_dot = mvec3_dot(data.unit:movement():m_fwd(), tmp_vec1)

				if fwd_dot < -0.5 then
					hold_chance = hold_chance * (1 - flanked_surrender)
				end
			end
		end,
		unaware_of_aggressor = function (unaware_of_aggressor_surrender)
			local att_info = data.detected_attention_objects[aggressor_unit:key()]

			if not att_info or not att_info.identified or t - att_info.identified_t < 1 then
				hold_chance = hold_chance * (1 - unaware_of_aggressor_surrender)
			end
		end,
		enemy_weap_cold = function (enemy_weap_cold_surrender)
			if not managers.groupai:state():enemy_weapons_hot() then
				hold_chance = hold_chance * (1 - enemy_weap_cold_surrender)
			end
		end,
		isolated = function (isolated_surrender)
			if data.group and data.group.has_spawned and data.group.initial_size > 1 then
				local has_support = nil
				local max_dis_sq = 722500

				for u_key, u_data in pairs(data.group.units) do
					if u_key ~= data.key and mvec3_dis_sq(data.m_pos, u_data.m_pos) < max_dis_sq then
						has_support = true

						break
					end

					if not has_support then
						hold_chance = hold_chance * (1 - isolated_surrender)
					end
				end
			end
		end,
		pants_down = function (pants_down_surrender)
			local not_cool_t = data.unit:movement():not_cool_t()

			if (not not_cool_t or t - not_cool_t < 1.5) and not managers.groupai:state():enemy_weapons_hot() then
				hold_chance = hold_chance * (1 - pants_down_surrender)
			end
		end
	}

	for reason, reason_data in pairs(surrender_tweak.reasons) do
		surrender_chk[reason](reason_data)
	end

	if hold_chance >= 1 - (surrender_tweak.significant_chance or 0) then
		return 1
	end

	for factor, factor_data in pairs(surrender_tweak.factors) do
		surrender_chk[factor](factor_data)
	end

	if data.surrender_window then
		hold_chance = hold_chance * (1 - data.surrender_window.chance_mul)
	end

	if surrender_tweak.violence_timeout then
		local violence_t = data.unit:character_damage():last_suppression_t()

		if violence_t then
			local violence_dt = t - violence_t

			if violence_dt < surrender_tweak.violence_timeout then
				hold_chance = hold_chance + (1 - hold_chance) * (1 - violence_dt / surrender_tweak.violence_timeout)
			end
		end
	end

	return hold_chance < 1 and hold_chance
end

function CopLogicBase.chk_start_action_dodge(data, reason)
	if not data.char_tweak.dodge or not data.char_tweak.dodge.occasions[reason] then
		return
	end

	if data.dodge_timeout_t and data.t < data.dodge_timeout_t or data.dodge_chk_timeout_t and data.t < data.dodge_chk_timeout_t or data.unit:movement():chk_action_forbidden("walk") then
		return
	end

	local dodge_tweak = data.char_tweak.dodge.occasions[reason]
	data.dodge_chk_timeout_t = TimerManager:game():time() + math.lerp(dodge_tweak.check_timeout[1], dodge_tweak.check_timeout[2], math.random())

	if dodge_tweak.chance == 0 or dodge_tweak.chance < math.random() then
		return
	end

	local rand_nr = math.random()
	local total_chance = 0
	local variation, variation_data = nil

	for test_variation, test_variation_data in pairs(dodge_tweak.variations) do
		total_chance = total_chance + test_variation_data.chance

		if test_variation_data.chance > 0 and rand_nr <= total_chance then
			variation = test_variation
			variation_data = test_variation_data

			break
		end
	end

	local dodge_dir = Vector3()
	local face_attention = nil

	if data.attention_obj and AIAttentionObject.REACT_COMBAT <= data.attention_obj.reaction then
		mvec3_set(dodge_dir, data.attention_obj.m_pos)
		mvec3_sub(dodge_dir, data.m_pos)
		mvector3.set_z(dodge_dir, 0)
		mvector3.normalize(dodge_dir)

		if mvector3.dot(data.unit:movement():m_fwd(), dodge_dir) >= 0 then
			face_attention = true
		end
		
		mvector3.cross(dodge_dir, dodge_dir, math.UP)
	else
		mvector3.set(dodge_dir, math.UP)
		mvector3.random_orthogonal(dodge_dir)
	end

	local dodge_dir_reversed = false

	if math.random() < 0.5 then
		mvector3.negate(dodge_dir)

		dodge_dir_reversed = not dodge_dir_reversed
	end

	local prefered_space = 180
	local min_space = 130
	local ray_to_pos = tmp_vec1

	mvec3_set(ray_to_pos, dodge_dir)
	mvector3.multiply(ray_to_pos, prefered_space)
	mvector3.add(ray_to_pos, data.m_pos)

	local ray_params = {
		trace = true,
		tracker_from = data.unit:movement():nav_tracker(),
		pos_to = ray_to_pos
	}
	local ray_hit1 = managers.navigation:raycast(ray_params)
	local dis = nil

	if ray_hit1 then
		local hit_vec = tmp_vec2

		mvec3_set(hit_vec, ray_params.trace[1])
		mvec3_sub(hit_vec, data.m_pos)
		mvec3_set_z(hit_vec, 0)

		dis = mvector3.length(hit_vec)

		mvec3_set(ray_to_pos, dodge_dir)
		mvector3.multiply(ray_to_pos, -prefered_space)
		mvector3.add(ray_to_pos, data.m_pos)

		ray_params.pos_to = ray_to_pos
		local ray_hit2 = managers.navigation:raycast(ray_params)

		if ray_hit2 then
			mvec3_set(hit_vec, ray_params.trace[1])
			mvec3_sub(hit_vec, data.m_pos)
			mvec3_set_z(hit_vec, 0)

			local prev_dis = dis
			dis = mvector3.length(hit_vec)

			if prev_dis < dis and min_space < dis then
				mvector3.negate(dodge_dir)

				dodge_dir_reversed = not dodge_dir_reversed
			end
		else
			mvector3.negate(dodge_dir)

			dis = nil
			dodge_dir_reversed = not dodge_dir_reversed
		end
	end

	if ray_hit1 and dis and dis < min_space then --we tried left and right crossed, if we're against an attention object, try back and forward
		if data.attention_obj and AIAttentionObject.REACT_COMBAT <= data.attention_obj.reaction then
			face_attention = nil
			mvec3_set(dodge_dir, data.m_pos)
			mvec3_sub(dodge_dir, data.attention_obj.m_pos)
			mvector3.set_z(dodge_dir, 0)
			mvector3.normalize(dodge_dir)

			dodge_dir_reversed = false
			
			mvec3_set(ray_to_pos, dodge_dir)
			mvector3.multiply(ray_to_pos, prefered_space)
			mvector3.add(ray_to_pos, data.m_pos)

			local ray_params = {
				trace = true,
				tracker_from = data.unit:movement():nav_tracker(),
				pos_to = ray_to_pos
			}
			local ray_hit1 = managers.navigation:raycast(ray_params)
			local dis = nil
			
			if ray_hit1 then
				local hit_vec = tmp_vec2

				mvec3_set(hit_vec, ray_params.trace[1])
				mvec3_sub(hit_vec, data.m_pos)
				mvec3_set_z(hit_vec, 0)

				dis = mvector3.length(hit_vec)

				mvec3_set(ray_to_pos, dodge_dir)
				mvector3.multiply(ray_to_pos, -prefered_space)
				mvector3.add(ray_to_pos, data.m_pos)

				ray_params.pos_to = ray_to_pos
				local ray_hit2 = managers.navigation:raycast(ray_params)

				if ray_hit2 then
					mvec3_set(hit_vec, ray_params.trace[1])
					mvec3_sub(hit_vec, data.m_pos)
					mvec3_set_z(hit_vec, 0)

					local prev_dis = dis
					dis = mvector3.length(hit_vec)

					if prev_dis < dis and min_space < dis then
						mvector3.negate(dodge_dir)

						dodge_dir_reversed = not dodge_dir_reversed
					end
				else
					mvector3.negate(dodge_dir)

					dis = nil
					dodge_dir_reversed = not dodge_dir_reversed
				end
			end
			
			if ray_hit1 and dis and dis < min_space then --no success
				return
			end
		else
			return
		end
	end

	local dodge_side = nil

	if face_attention then
		if dodge_dir_reversed then
			dodge_side = "l"
		else
			dodge_side = "r"
		end
	else
		local fwd_dot = mvec3_dot(dodge_dir, data.unit:movement():m_fwd())
		local my_right = tmp_vec1

		mrotation.x(data.unit:movement():m_rot(), my_right)

		local right_dot = mvec3_dot(dodge_dir, my_right)

		if math.abs(fwd_dot) > 0.7071067690849 then
			if fwd_dot > 0 then
				dodge_side = "fwd"
			else
				dodge_side = "bwd"
			end
		elseif right_dot > 0 then
			dodge_side = "r"
		else
			dodge_side = "l"
		end
	end

	local body_part = 1
	local shoot_chance = variation_data.shoot_chance
	
	if dodge_side ~= "bwd" then
		if shoot_chance and shoot_chance > 0 and math.random() < shoot_chance then
			body_part = 2
		end
	end

	local action_data = {
		type = "dodge",
		body_part = body_part,
		variation = variation,
		side = dodge_side,
		direction = dodge_dir,
		timeout = variation_data.timeout,
		speed = data.char_tweak.dodge.speed,
		shoot_accuracy = variation_data.shoot_accuracy,
		blocks = {
			act = -1,
			tase = -1,
			dodge = -1,
			walk = -1,
			action = body_part == 1 and -1 or nil,
			aim = body_part == 1 and -1 or nil
		}
	}

	if variation ~= "side_step" then
		action_data.blocks.hurt = -1
		action_data.blocks.heavy_hurt = -1
	end

	local action = data.unit:movement():action_request(action_data)

	if action then
		local my_data = data.internal_data

		CopLogicAttack._cancel_cover_pathing(data, my_data)
		CopLogicAttack._cancel_charge(data, my_data)
		CopLogicAttack._cancel_expected_pos_path(data, my_data)
		CopLogicAttack._cancel_walking_to_cover(data, my_data, true)
	end

	return action
end
