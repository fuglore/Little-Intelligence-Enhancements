local tmp_vec1 = Vector3()

function CivilianLogicSurrender.queued_update(rubbish, data)
	local my_data = data.internal_data

	CivilianLogicSurrender._update_enemy_detection(data, my_data)

	if my_data.submission_meter <= 0 and not data.is_tied and (not data.unit:anim_data().react_enter or not not data.unit:anim_data().idle) then
		if data.unit:anim_data().drop then
			local new_action = {
				variant = "stand",
				body_part = 1,
				type = "act"
			}

			data.unit:brain():action_request(new_action)
		end

		my_data.surrender_clbk_registered = false

		data.unit:brain():set_objective({
			is_default = true,
			type = "free"
		})

		return
	else --pretty sure this function can cause a crash in vanilla due to a civ getting registered into the _upd_hostage_task even though they've left the logic for travel
		if CopLogicIdle._chk_relocate(data) then
			return
		end
	
		CivilianLogicFlee._chk_add_delayed_rescue_SO(data, my_data)
		managers.groupai:state():add_to_surrendered(data.unit, callback(CivilianLogicSurrender, CivilianLogicSurrender, "queued_update", data))
	end	
end

function CivilianLogicSurrender._update_enemy_detection(data, my_data)
	managers.groupai:state():on_unit_detection_updated(data.unit)

	local t = TimerManager:game():time()
	local delta_t = t - my_data.last_upd_t
	local my_pos = data.unit:movement():m_head_pos()
	local enemies = managers.groupai:state():all_criminals()
	local visible, closest_dis, closest_enemy = nil
	my_data.inside_intimidate_aura = nil
	local my_tracker = data.unit:movement():nav_tracker()
	local chk_vis_func = my_tracker.check_visibility
	local mvec3_dir = mvector3.direction
	local mvec3_dis_sq = mvector3.distance_sq
	local mvec3_cpy = mvector3.copy
	
	if not my_data.criminal_pos_list then
		my_data.criminal_pos_list = {}
	end
	
	for e_key, u_data in pairs(enemies) do
		if not u_data.is_deployable then
			local enemy_unit = u_data.unit
			local enemy_pos = u_data.m_det_pos
			
			if not my_data.criminal_pos_list[e_key] then
				my_data.criminal_pos_list[e_key] = {
					seen = false,
					verified_pos = nil
				}
			end
			
			local crim_pos_entry = my_data.criminal_pos_list[e_key]
			
			if not crim_pos_entry.seen or crim_pos_entry.verified_pos and mvec3_dis_sq(crim_pos_entry.verified_pos, enemy_pos) > 10000 then
				local vis_ray = World:raycast("ray", my_pos, enemy_pos, "slot_mask", data.visibility_slotmask, "ray_type", "ai_vision", "report")
				
				crim_pos_entry.seen = not vis_ray
				crim_pos_entry.verified_pos = mvec3_cpy(enemy_pos)
			end
			
			if crim_pos_entry.seen then
				local my_vec = tmp_vec1
				local dis = mvector3.direction(my_vec, enemy_pos, my_pos)
				local inside_aura = nil

				if u_data.unit:base().is_local_player then
					if managers.player:has_category_upgrade("player", "intimidate_aura") and dis < managers.player:upgrade_value("player", "intimidate_aura", 0) then
						inside_aura = true
					end
				elseif u_data.unit:base().is_husk_player and u_data.unit:base():upgrade_value("player", "intimidate_aura") and dis < u_data.unit:base():upgrade_value("player", "intimidate_aura") then
					inside_aura = true
				end

				if (inside_aura or dis < 700) and (not closest_dis or dis < closest_dis) then
					closest_dis = dis
					closest_enemy = enemy_unit
				end

				if inside_aura then
					my_data.inside_intimidate_aura = true
				elseif dis < 700 then
					local look_vec
				
					if enemy_unit:base().is_local_player then
						look_vec = enemy_unit:movement():m_head_rot():y()
					else
						if enemy_unit:inventory() and enemy_unit:inventory():equipped_unit() then
							if enemy_unit:movement()._stance.values[3] >= 0.6 then
								local weapon_fire_obj = enemy_unit:inventory():equipped_unit():get_object(Idstring("fire"))

								if alive(weapon_fire_obj) then
									look_vec = weapon_fire_obj:rotation():y()
								end
							end
						end

						if not look_vec then
							look_vec = enemy_unit:movement():m_head_rot():z()
						end
					end
					
					if look_vec then
						mvector3.normalize(look_vec)
					end

					local focus = my_vec:dot(look_vec)
					
					if focus > 0.65 then
						visible = true
					end
				end
			end
		end
	end

	local attention = data.unit:movement():attention()
	local attention_unit = attention and attention.unit or nil

	if not attention_unit then
		if closest_enemy and closest_dis < 700 and data.unit:anim_data().ik_type then
			CopLogicBase._set_attention_on_unit(data, closest_enemy)
		end
	elseif mvector3.distance(my_pos, attention_unit:movement():m_head_pos()) > 900 or not data.unit:anim_data().ik_type then
		CopLogicBase._reset_attention(data)
	end

	if managers.navigation:get_nav_seg_metadata(my_tracker:nav_segment()).force_civ_submission then
		my_data.submission_meter = my_data.submission_max
	elseif my_data.inside_intimidate_aura then
		my_data.submission_meter = my_data.submission_max
	elseif visible then
		my_data.submission_meter = math.min(my_data.submission_max, my_data.submission_meter + delta_t)
	elseif not data.unit:anim_data().drop and data.char_tweak.faster_reactions then
		my_data.submission_meter = 0
	else
		my_data.submission_meter = math.max(0, my_data.submission_meter - delta_t)
	end

	if managers.groupai:state():rescue_state() and not visible then
		if not my_data.rescue_active then
			CivilianLogicFlee._add_delayed_rescue_SO(data, my_data)
		end
	elseif my_data.rescue_active then
		CivilianLogicFlee._unregister_rescue_SO(data, my_data)
	end

	my_data.scare_meter = math.max(0, my_data.scare_meter - delta_t)
	my_data.last_upd_t = t
end