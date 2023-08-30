function CopLogicIntimidated._unregister_rescue_SO(data, my_data)
	if my_data.rescuer then
		if alive(my_data.rescuer) then
			local rescuer = my_data.rescuer

			managers.groupai:state():on_objective_failed(rescuer, rescuer:brain():objective())
		end
		
		my_data.rescuer = nil
	elseif my_data.rescue_SO_id then
		managers.groupai:state():remove_special_objective(my_data.rescue_SO_id)

		my_data.rescue_SO_id = nil
	elseif my_data.delayed_rescue_SO_id then
		CopLogicBase.chk_cancel_delayed_clbk(my_data, my_data.delayed_rescue_SO_id)
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