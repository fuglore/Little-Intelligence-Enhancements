if not Iter then

function CivilianLogicEscort.enter(data, new_logic_name, enter_params)
	CopLogicBase.enter(data, new_logic_name, enter_params)
	data.unit:brain():cancel_all_pathing_searches()

	local old_internal_data = data.internal_data
	local my_data = {
		unit = data.unit
	}

	data.unit:brain():set_update_enabled_state(true)

	if data.char_tweak.escort_idle_talk then
		my_data._say_random_t = Application:time() + 45
	end

	CivilianLogicEscort._get_objective_path_data(data, my_data)
	
	managers.groupai:state():_register_escort(data.unit)

	data.internal_data = my_data

	data.unit:contour():add("highlight")
	data.unit:movement():set_cool(false, "escort")
	data.unit:movement():set_stance(data.is_tied and "cbt" or "hos")

	my_data.advance_path_search_id = "CivilianLogicEscort_detailed" .. tostring(data.key)
	my_data.coarse_path_search_id = "CivilianLogicEscort_coarse" .. tostring(data.key)

	if data.unit:anim_data().tied then
		local action_data = {
			clamp_to_graph = true,
			variant = "panic",
			body_part = 1,
			type = "act"
		}

		data.unit:brain():action_request(action_data)
	end

	if not data.been_outlined and data.char_tweak.outline_on_discover then
		my_data.outline_detection_task_key = "CivilianLogicIdle._upd_outline_detection" .. tostring(data.key)

		CopLogicBase.queue_task(my_data, my_data.outline_detection_task_key, CivilianLogicIdle._upd_outline_detection, data, data.t)
	end

	local attention_settings = {
		"civ_enemy_cbt",
		"civ_civ_cbt"
	}

	data.unit:brain():set_attention_settings(attention_settings)
end

function CivilianLogicEscort.exit(data, new_logic_name, enter_params)
	CopLogicBase.exit(data, new_logic_name, enter_params)
	managers.groupai:state():_unregister_escort(data.key)

	local my_data = data.internal_data

	data.unit:brain():cancel_all_pathing_searches()
	CopLogicBase.cancel_queued_tasks(my_data)
	data.unit:contour():remove("highlight")

	if new_logic_name ~= "inactive" then
		data.unit:brain():set_update_enabled_state(true)
	end
end


end