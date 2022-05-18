function SpoocLogicIdle._chk_exit_hiding(data)
	local can_exit_hiding = data.unit:anim_data().hide_loop or data.unit:anim_data().act_idle --because of overkill being silly, i need to check for act_idle here

	if not can_exit_hiding then
		return
	end

	local attention_objects = data.detected_attention_objects

	for u_key, attention_data in pairs(attention_objects) do
		if AIAttentionObject.REACT_SHOOT <= attention_data.reaction then
		
			if attention_data.dis < 1500 and attention_data.verified then
				SpoocLogicIdle._exit_hiding(data)
				
				break
			elseif attention_data.dis < 700 then
				local my_nav_seg_id = data.unit:movement():nav_tracker():nav_segment()
				local enemy_areas = managers.groupai:state():get_areas_from_nav_seg_id(attention_data.nav_tracker:nav_segment())
				local exited = nil
				
				for _, area in ipairs(enemy_areas) do
					if area.nav_segs[my_nav_seg_id] then
						exited = true

						SpoocLogicIdle._exit_hiding(data)

						break
					end
				end
				
				if exited then
					break
				end
			end
		end
	end
end

function SpoocLogicIdle.damage_clbk(data, damage_info)
	local res = SpoocLogicIdle.super.damage_clbk(data, damage_info)
	local can_exit_hiding = data.unit:anim_data().hide_loop or data.unit:anim_data().hide or data.unit:anim_data().act_idle
	
	if can_exit_hiding then
		SpoocLogicIdle._exit_hiding(data)
	end

	return res
end

function SpoocLogicIdle.exit(data, new_logic_name, enter_params)
	if new_logic_name ~= "inactive" then
		local can_exit_hiding = data.unit:anim_data().hide_loop or data.unit:anim_data().hide or data.unit:anim_data().act_idle
		
		if can_exit_hiding then
			data.unit:brain():action_request({
				variant = "idle",
				body_part = 1,
				type = "act",
				blocks = {
					light_hurt = -1,
					hurt = -1,
					action = -1,
					expl_hurt = -1,
					heavy_hurt = -1,
					idle = -1,
					fire_hurt = -1,
					walk = -1
				}
			})
		end
	end

	CopLogicBase.exit(data, new_logic_name, enter_params)

	local my_data = data.internal_data

	data.unit:brain():cancel_all_pathing_searches()
	CopLogicBase.cancel_queued_tasks(my_data)
	CopLogicBase.cancel_delayed_clbks(my_data)

	if my_data.best_cover then
		managers.navigation:release_cover(my_data.best_cover[1])
	end

	if my_data.nearest_cover then
		managers.navigation:release_cover(my_data.nearest_cover[1])
	end

	data.brain:rem_pos_rsrv("path")
end

function SpoocLogicIdle._exit_hiding(data)
	data.unit:brain():set_objective({ --this used to call data.unit:set_objective in vanilla...
		type = "act",
		action = {
			variant = "idle",
			body_part = 1,
			type = "act",
			blocks = {
				heavy_hurt = -1,
				idle = -1,
				action = -1,
				turn = -1,
				light_hurt = -1,
				walk = -1,
				fire_hurt = -1,
				hurt = -1,
				expl_hurt = -1
			}
		}
	})
end