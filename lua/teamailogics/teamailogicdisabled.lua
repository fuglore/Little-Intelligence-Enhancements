function TeamAILogicDisabled._consider_surrender(data, my_data)
	my_data.stay_cool_chk_t = TimerManager:game():time()
	local my_health_ratio = data.unit:character_damage():health_ratio()

	if my_health_ratio < 0.1 then
		my_data.stay_cool = true
		
		return
	end

	local my_health = my_health_ratio * data.unit:character_damage()._HEALTH_BLEEDOUT_INIT
	local total_scare = 0

	for e_key, e_data in pairs(data.detected_attention_objects) do
		if e_data.verified_t and data.t - e_data.verified_t < 2 and e_data.unit:in_slot(data.enemy_slotmask) then
			local scare = tweak_data.character[e_data.unit:base()._tweak_table].HEALTH_INIT / my_health
			scare = scare * (1 - math.clamp(e_data.verified_dis - 300, 0, 2500) / 2500)
			total_scare = total_scare + scare
		end
	end

	for c_key, c_data in pairs(managers.groupai:state():all_player_criminals()) do
		if not c_data.status then
			local support = tweak_data.player.damage.HEALTH_INIT / my_health
			local dis = mvector3.distance(c_data.m_pos, data.m_pos)
			support = 3 * support * (1 - math.clamp(dis - 300, 0, 2500) / 2500)
			total_scare = total_scare - support
		end
	end

	if total_scare > 1 then
		my_data.stay_cool = true

		if my_data.firing then
			data.unit:movement():set_allow_fire(false)

			my_data.firing = nil
		end
	else
		my_data.stay_cool = false
	end
end

function TeamAILogicDisabled._upd_aim(data, my_data)
	local shoot, aim = nil
	local focus_enemy = data.attention_obj

	if my_data.stay_cool then
		-- Nothing
	elseif focus_enemy and AIAttentionObject.REACT_COMBAT <= focus_enemy.reaction then
		if focus_enemy.verified then
			if focus_enemy.verified_dis < 2000 or my_data.alert_t and data.t - my_data.alert_t < 7 then
				shoot = true
			end
		elseif focus_enemy.verified_t and data.t - focus_enemy.verified_t < 10 then
			aim = true

			if my_data.shooting and data.t - focus_enemy.verified_t < 3 then
				shoot = true
			end
		elseif focus_enemy.verified_dis < 600 and my_data.walking_to_cover_shoot_pos then
			aim = true
		end
	end

	if aim or shoot then
		if focus_enemy.verified then
			if my_data.attention_unit ~= focus_enemy.u_key then
				CopLogicBase._set_attention(data, focus_enemy)

				my_data.attention_unit = focus_enemy.u_key
			end
		elseif my_data.attention_unit ~= focus_enemy.verified_pos then
			CopLogicBase._set_attention_on_pos(data, mvector3.copy(focus_enemy.verified_pos))

			my_data.attention_unit = mvector3.copy(focus_enemy.verified_pos)
		end
	else
		if data.unit:movement():chk_action_forbidden("action") or not data.unit:anim_data().reload and CopLogicAttack._check_needs_reload(data, my_data) then
			if my_data.shooting then
				local new_action = {
					body_part = 3,
					type = "idle"
				}

				data.unit:brain():action_request(new_action)
			end
		end

		if my_data.attention_unit then
			CopLogicBase._reset_attention(data)

			my_data.attention_unit = nil
		end
	end

	if shoot then
		if not my_data.firing then
			data.unit:movement():set_allow_fire(true)

			my_data.firing = true
		end
	elseif my_data.firing then
		data.unit:movement():set_allow_fire(false)

		my_data.firing = nil
	end
end

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