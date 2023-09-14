local blocked_hunts = {
	gallery = {
		[100352] = true
	},
	framing_frame_1 = {
		[100352] = true
	},
	crojob2 = {
		[106867] = true
	}
}

function ElementAiGlobalEvent:on_executed(instigator)
	if not self._values.enabled then
		return
	end

	local wave_mode = self._wave_modes[self._values.wave_mode]
	local blame = self._blames[self._values.blame]
	local AI_event = self._AI_events[self._values.AI_event]

	if wave_mode and wave_mode ~= "none" then
		if LIES.settings.hhtacs and blocked_hunts[Global.level_data.level_id] then
			local block_ids = blocked_hunts[Global.level_data.level_id]
			if wave_mode == "hunt" and block_ids[self._id] then
				managers.groupai:state():start_extend_assault()
			else
				managers.groupai:state():set_wave_mode(wave_mode)
			end
		else
			managers.groupai:state():set_wave_mode(wave_mode)
		end
	end

	if not blame or blame == "none" then
		Application:error("ElementAiGlobalEvent needs to be updated with blame parameter, and not none", blame)
	end

	if AI_event and AI_event ~= "none" then
		if AI_event == "police_called" then
			managers.groupai:state():on_police_called(managers.groupai:state().analyse_giveaway(blame, instigator, {
				"vo_cbt"
			}))
		elseif AI_event == "police_weapons_hot" then
			managers.groupai:state():on_police_weapons_hot(managers.groupai:state().analyse_giveaway(blame, instigator, {
				"vo_cbt"
			}))
		elseif AI_event == "gangsters_called" then
			managers.groupai:state():on_gangsters_called(managers.groupai:state().analyse_giveaway(blame, instigator, {
				"vo_cbt"
			}))
		elseif AI_event == "gangster_weapons_hot" then
			managers.groupai:state():on_gangster_weapons_hot(managers.groupai:state().analyse_giveaway(blame, instigator, {
				"vo_cbt"
			}))
		end
	end

	ElementAiGlobalEvent.super.on_executed(self, instigator)
end