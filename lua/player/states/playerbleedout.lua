function PlayerBleedOut._register_revive_SO(revive_SO_data, variant)
	if revive_SO_data.SO_id or not managers.navigation:is_data_ready() then
		return
	end
	
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
		follow_unit = revive_SO_data.unit,
		nav_seg = revive_SO_data.unit:movement():nav_tracker():nav_segment(),
		fail_clbk = callback(PlayerBleedOut, PlayerBleedOut, "on_rescue_SO_failed", revive_SO_data),
		complete_clbk = callback(PlayerBleedOut, PlayerBleedOut, "on_rescue_SO_completed", revive_SO_data),
		action_start_clbk = callback(PlayerBleedOut, PlayerBleedOut, "on_rescue_SO_started", revive_SO_data),
		action = {
			align_sync = true,
			type = "act",
			body_part = 1,
			variant = variant,
			blocks = {
				light_hurt = -1,
				hurt = -1,
				action = -1,
				heavy_hurt = -1,
				aim = -1,
				walk = -1
			}
		},
		action_duration = tweak_data.interaction[variant == "untie" and "free" or variant].timer,
		followup_objective = followup_objective
	}
	local so_descriptor = {
		interval = 0,
		AI_group = "friendlies",
		base_chance = 1,
		chance_inc = 0,
		usage_amount = 1,
		objective = objective,
		search_pos = revive_SO_data.unit:position(),
		admin_clbk = callback(PlayerBleedOut, PlayerBleedOut, "on_rescue_SO_administered", revive_SO_data),
		verification_clbk = callback(PlayerBleedOut, PlayerBleedOut, "rescue_SO_verification", revive_SO_data.unit)
	}
	revive_SO_data.variant = variant
	local so_id = "Playerrevive"
	revive_SO_data.SO_id = so_id

	managers.groupai:state():add_special_objective(so_id, so_descriptor)

	if not revive_SO_data.deathguard_SO_id then
		revive_SO_data.deathguard_SO_id = PlayerBleedOut._register_deathguard_SO(revive_SO_data.unit)
	end
end

function PlayerBleedOut:on_rescue_SO_administered(revive_SO_data, receiver_unit)
	if revive_SO_data.rescuer then
		debug_pause("[PlayerBleedOut:on_rescue_SO_administered] Already had a rescuer!!!!", receiver_unit, revive_SO_data.rescuer)
	end

	revive_SO_data.rescuer = receiver_unit
	revive_SO_data.SO_id = nil

	if receiver_unit:movement():carrying_bag() then
		local speed = 670
		local can_run = tweak_data.carry.types[tweak_data.carry[receiver_unit:movement():carry_id()].type].can_run
		local speed_mul = tweak_data.carry.types[tweak_data.carry[receiver_unit:movement():carry_id()].type].move_speed_modifier

		if not can_run then
			speed = 285
		end
		
		speed = speed * speed_mul
		
		if can_run then
			speed = speed * 28
		else
			speed = speed * 10
		end
		
		if mvector3.distance(revive_SO_data.unit:movement():m_pos(), receiver_unit:movement():m_pos()) > speed then
			receiver_unit:movement():throw_bag()
		end
	end
end