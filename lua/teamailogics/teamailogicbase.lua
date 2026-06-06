TeamAILogicBase._current_att_objs = {}

function TeamAILogicBase._get_logic_state_from_reaction(data, reaction)
	if data.last_engage_t and data.t - data.last_engage_t <= 15 then
		return "assault"
	elseif not reaction or reaction <= AIAttentionObject.REACT_SCARED then
		return "idle"
	else
		return "assault"
	end
end

function TeamAILogicBase._set_attention_obj(data, new_att_obj, new_reaction)
	local old_att_obj = data.attention_obj
	data.attention_obj = new_att_obj

	if new_att_obj then
		new_att_obj.reaction = new_reaction or new_att_obj.settings.reaction
	end

	if old_att_obj and new_att_obj and old_att_obj.u_key == new_att_obj.u_key then
		if new_att_obj.stare_expire_t and new_att_obj.stare_expire_t < data.t then
			if new_att_obj.settings.pause then
				new_att_obj.stare_expire_t = nil
				new_att_obj.pause_expire_t = data.t + math.lerp(new_att_obj.settings.pause[1], new_att_obj.settings.pause[2], math.random())

				--print("[TeamAILogicBase._chk_focus_on_attention_object] pausing for", current_attention.pause_expire_t - data.t, "sec")
			end
		elseif new_att_obj.pause_expire_t and new_att_obj.pause_expire_t < data.t then
			new_att_obj.pause_expire_t = nil
			new_att_obj.stare_expire_t = data.t + math.lerp(new_att_obj.settings.duration[1], new_att_obj.settings.duration[2], math.random())
		end
	elseif new_att_obj and new_att_obj.settings.duration then
		new_att_obj.stare_expire_t = data.t + math.lerp(new_att_obj.settings.duration[1], new_att_obj.settings.duration[2], math.random())
		new_att_obj.pause_expire_t = nil
	end
	
	if new_att_obj then
		TeamAILogicBase._current_att_objs[data.key] = new_att_obj.u_key
	else
		TeamAILogicBase._current_att_objs[data.key] = nil
	end
end