function CivilianLogicSurrender.queued_update(rubbish, data)
	local my_data = data.internal_data

	CivilianLogicSurrender._update_enemy_detection(data, my_data)

	if my_data.submission_meter == 0 and not data.is_tied and (not data.unit:anim_data().react_enter or not not data.unit:anim_data().idle) then
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