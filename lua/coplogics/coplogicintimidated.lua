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

function CopLogicIntimidated._unregister_rescue_SO(data, my_data)
	if my_data.rescuer then
		local rescuer = my_data.rescuer
		my_data.rescuer = nil
		
		if alive(rescuer) then
			managers.groupai:state():on_objective_failed(rescuer, rescuer:brain():objective())
		end
	elseif my_data.rescue_SO_id then
		managers.groupai:state():remove_special_objective(my_data.rescue_SO_id)

		my_data.rescue_SO_id = nil
	elseif my_data.delayed_rescue_SO_id then
		CopLogicBase.chk_cancel_delayed_clbk(my_data, my_data.delayed_rescue_SO_id)
	end
end

function CopLogicIntimidated._update_enemy_detection(data, my_data)
	local robbers = managers.groupai:state():all_criminals()
	local my_tracker = data.unit:movement():nav_tracker()
	--local chk_vis_func = my_tracker.check_visibility
	local fight = not my_data.tied

	if not my_data.surrender_break_t or data.t < my_data.surrender_break_t then
		for u_key, u_data in pairs(robbers) do
			if not u_data.is_deployable then
				local crim_unit = u_data.unit
				local crim_pos = u_data.m_pos
				local dis = mvector3.distance(data.m_pos, crim_pos)

				if dis < tweak_data.player.long_dis_interaction.intimidate_range_enemies * tweak_data.upgrades.values.player.intimidate_range_mul[1] * 1.05 then
					local max_dot = 0.7
					
					if dis < 700 then
						max_dot = math.lerp(0.3, 0.7, (dis - 50) / 650)
					end

					local enemy_look_dir = tmp_vec1
					local weapon_rot = nil

					if crim_unit:base().is_husk_player then
						mvec3_set(enemy_look_dir, crim_unit:movement():detect_look_dir())
					else
						if crim_unit:base().is_local_player then
							m_rot_y(crim_unit:movement():m_head_rot(), enemy_look_dir)
						else
							if crim_unit:inventory() and crim_unit:inventory():equipped_unit() then
								if crim_unit:movement()._stance.values[3] >= 0.6 then
									local weapon_fire_obj = crim_unit:inventory():equipped_unit():get_object(Idstring("fire"))

									if alive(weapon_fire_obj) then
										weapon_rot = weapon_fire_obj:rotation()
									end
								end
							end

							if weapon_rot then
								m_rot_y(weapon_rot, enemy_look_dir)
							else
								m_rot_z(crim_unit:movement():m_head_rot(), enemy_look_dir)
							end
						end

						mvec3_norm(enemy_look_dir)
					end

					local enemy_vec = tmp_vec2

					mvec3_dir(enemy_vec, crim_unit:movement():m_head_pos(), data.unit:movement():m_com())

					if mvec3_dot(enemy_vec, enemy_look_dir) > 0.7 then
						local vis_ray = World:raycast("ray", data.unit:movement():m_head_pos(), crim_unit:movement():m_head_pos(), "slot_mask", data.visibility_slotmask, "ray_type", "ai_vision", "report")

						if not vis_ray then
							fight = nil

							break
						end
					end
				end
			end
		end
	end

	if fight then
		my_data.surrender_clbk_registered = nil
		managers.groupai:state():remove_from_surrendered(data.unit)

		data.brain:set_objective(nil)
		CopLogicBase._exit(data.unit, "idle")
	end
end


function CopLogicIntimidated.on_rescue_SO_completed(ignore_this, data, good_pig)
	if not data.unit:inventory():equipped_unit() then
		if data.unit:inventory():num_selections() <= 0 then
			local weap_name = data.unit:base():default_weapon_name()

			if weap_name then
				data.unit:inventory():add_unit_by_name(weap_name, true, true)
			end
		else
			data.unit:inventory():equip_selection(1, true)
		end
	end

	if data.unit:anim_data().hands_tied then
		local new_action = {
			variant = "stand",
			body_part = 1,
			type = "act"
		}

		data.unit:brain():action_request(new_action)
	end

	CopLogicBase._exit(data.unit, "idle")
end

function CopLogicIntimidated._start_action_hands_up(data)
	local my_data = data.internal_data
	local anim_name = "hands_up"
	
	if my_data.tied or managers.groupai:state():whisper_mode() then
		anim_name = "tied_all_in_one"
	end

	local action_data = {
		clamp_to_graph = true,
		type = "act",
		body_part = 1,
		variant = anim_name,
		blocks = {
			light_hurt = -1,
			hurt = -1,
			heavy_hurt = -1,
			walk = -1
		}
	}
	my_data.act_action = data.unit:brain():action_request(action_data)

	if my_data.act_action and data.unit:anim_data().hands_tied then
		CopLogicIntimidated._do_tied(data, my_data.aggressor_unit)
	end
end

function CopLogicIntimidated.on_intimidated(data, amount, aggressor_unit)
	local my_data = data.internal_data

	if not my_data.tied then
		my_data.surrender_break_t = data.char_tweak.surrender_break_time and data.t + math.random(data.char_tweak.surrender_break_time[1], data.char_tweak.surrender_break_time[2], math.random())
		local anim_data = data.unit:anim_data()
		local anim, blocks = nil

		if anim_data.hands_up then
			anim = "hands_back"
			blocks = {
				heavy_hurt = -1,
				hurt = -1,
				action = -1,
				light_hurt = -1,
				walk = -1
			}
		elseif anim_data.hands_back then
			anim = "tied"
			blocks = {
				heavy_hurt = -1,
				hurt_sick = -1,
				action = -1,
				light_hurt = -1,
				hurt = -1,
				walk = -1
			}
		else
			if managers.groupai:state():whisper_mode() or my_data.tied then
				anim = "tied_all_in_one"
			else
				anim = "hands_up"
			end

			blocks = {
				heavy_hurt = -1,
				hurt = -1,
				action = -1,
				light_hurt = -1,
				walk = -1
			}
		end

		local action_data = {
			clamp_to_graph = true,
			type = "act",
			body_part = 1,
			variant = anim,
			blocks = blocks
		}
		local act_action = data.unit:brain():action_request(action_data)

		if data.unit:anim_data().hands_tied then
			CopLogicIntimidated._do_tied(data, aggressor_unit)
		end
	elseif not data.unit:anim_data().hands_tied then
		local action_data = {
			clamp_to_graph = true,
			type = "act",
			body_part = 1,
			variant = "tied_all_in_one",
			blocks = {
				heavy_hurt = -1,
				hurt = -1,
				action = -1,
				light_hurt = -1,
				walk = -1
			}
		}
		data.unit:brain():action_request(action_data)
	end
end

function CopLogicIntimidated.exit(data, new_logic_name, enter_params)
	CopLogicBase.exit(data, new_logic_name, enter_params)

	local my_data = data.internal_data

	CopLogicIntimidated._unregister_rescue_SO(data, my_data)
	CopLogicIntimidated._unregister_harassment_SO(data, my_data)

	if new_logic_name ~= "inactive" then
		data.unit:base():set_slot(data.unit, 12)
	end

	if my_data.nearest_cover then
		managers.navigation:release_cover(my_data.nearest_cover[1])
	end

	if new_logic_name ~= "inactive" then
		data.unit:brain():set_update_enabled_state(true)
		data.unit:interaction():set_active(false, true, false)
	end

	if my_data.tied then
		managers.groupai:state():on_enemy_untied(data.unit:key())
	end

	managers.groupai:state():unregister_rescueable_hostage(data.key)

	if my_data.surrender_clbk_registered then
		managers.groupai:state():remove_from_surrendered(data.unit)
	end

	if my_data.is_hostage then
		managers.groupai:state():on_hostage_state(false, data.key, true)
	end

	managers.network:session():send_to_peers_synched("sync_unit_surrendered", data.unit, false)
	
	data.unit:brain():cancel_all_pathing_searches()
	CopLogicBase.cancel_queued_tasks(my_data)
	CopLogicBase.cancel_delayed_clbks(my_data)
end