function SpoocLogicIdle._upd_enemy_detection(data)
	managers.groupai:state():on_unit_detection_updated(data.unit)

	data.t = TimerManager:game():time()
	local my_data = data.internal_data
	CopLogicBase._upd_attention_obj_detection(data, nil, nil)
	
	local delay = 0
	
	if not managers.groupai:state():whisper_mode() then
		delay = (data.unit:anim_data().hide or data.unit:anim_data().hide_loop) and 0.5 or data.important and 0.7 or 1.4
	end
	
	local new_attention, new_prio_slot, new_reaction = CopLogicIdle._get_priority_attention(data, data.detected_attention_objects)

	CopLogicBase._set_attention_obj(data, new_attention, new_reaction)
	SpoocLogicIdle._chk_exit_hiding(data)

	if new_reaction and AIAttentionObject.REACT_SUSPICIOUS < new_reaction and (not data.unit:anim_data().hide or data.unit:anim_data().hide_loop) then
		local objective = data.objective
		local wanted_state = nil
		local allow_trans, obj_failed = CopLogicBase.is_obstructed(data, objective, nil, new_attention)

		if allow_trans then
			wanted_state = CopLogicBase._get_logic_state_from_reaction(data)
		end

		if wanted_state and wanted_state ~= data.name then
			if data.unit:anim_data().hide_loop then
				new_attention.react_t = data.t - 1
				SpoocLogicIdle._exit_hiding(data)
			end

			if obj_failed then
				data.objective_failed_clbk(data.unit, data.objective)
			end

			if my_data == data.internal_data then
				CopLogicBase._exit(data.unit, wanted_state)
			end
		end
	end
	
	if my_data ~= data.internal_data then
		return delay
	end

	CopLogicBase._chk_call_the_police(data)

	if my_data ~= data.internal_data then
		return delay
	end

	if my_data ~= data.internal_data then
		return delay
	end

	return delay
end

function SpoocLogicIdle._chk_exit_hiding(data)
	if not data.unit:anim_data().hide_loop then
		return
	end
	
	local attention_objects = data.detected_attention_objects
	
	for u_key, attention_data in pairs(attention_objects) do
		if AIAttentionObject.REACT_SHOOT <= attention_data.reaction and attention_data.nav_tracker and alive(attention_data.nav_tracker) then
			if attention_data.dis < 1500 then
				if attention_data.verified or attention_data.nearly_visible then
					attention_data.react_t = data.t - 1
					SpoocLogicIdle._exit_hiding(data)
					
					break
				end
			end
			
			if attention_data.dis < 700 then
				local my_nav_seg_id = data.unit:movement():nav_tracker():nav_segment()
				local enemy_areas = managers.groupai:state():get_areas_from_nav_seg_id(attention_data.nav_tracker:nav_segment())

				for _, area in ipairs(enemy_areas) do
					if area.nav_segs[my_nav_seg_id] then
						attention_data.react_t = data.t - 1
						SpoocLogicIdle._exit_hiding(data)

						break
					end
				end
			end
		end
	end
end