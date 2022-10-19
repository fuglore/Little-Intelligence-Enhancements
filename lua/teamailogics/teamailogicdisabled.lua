function TeamAILogicDisabled._register_revive_SO(data, my_data, rescue_type)
	local followup_objective = {
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
	}
	local objective = {
		type = "revive",
		called = true,
		destroy_clbk_key = false,
		follow_unit = data.unit,
		nav_seg = data.unit:movement():nav_tracker():nav_segment(),
		fail_clbk = callback(TeamAILogicDisabled, TeamAILogicDisabled, "on_revive_SO_failed", data),
		action = {
			align_sync = true,
			type = "act",
			body_part = 1,
			variant = rescue_type,
			blocks = {
				light_hurt = -1,
				hurt = -1,
				action = -1,
				heavy_hurt = -1,
				aim = -1,
				walk = -1
			}
		},
		action_duration = tweak_data.interaction[data.name == "surrender" and "free" or "revive"].timer,
		followup_objective = followup_objective
	}
	local so_descriptor = {
		interval = 0,
		search_dis_sq = 2250000,
		AI_group = "friendlies",
		base_chance = 1,
		chance_inc = 0,
		usage_amount = 1,
		objective = objective,
		search_pos = mvector3.copy(data.m_pos),
		admin_clbk = callback(TeamAILogicDisabled, TeamAILogicDisabled, "on_revive_SO_administered", data)
	}
	local so_id = "TeamAIrevive" .. tostring(data.key)
	my_data.SO_id = so_id

	managers.groupai:state():add_special_objective(so_id, so_descriptor)

	my_data.deathguard_SO_id = PlayerBleedOut._register_deathguard_SO(data.unit)
end