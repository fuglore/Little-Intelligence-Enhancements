GroupAIStateBase._nr_important_cops = 12 --gets divided in groupaistatebesiege if theres more than 1 player

local mvec3_dis_sq = mvector3.distance_sq

function GroupAIStateBase:set_importance_weight(u_key, wgt_report)
	if #wgt_report == 0 then
		return
	end

	local t_rem = table.remove
	local t_ins = table.insert
	local max_nr_imp = self._nr_important_cops
	local imp_adj = 0
	local criminals = self._player_criminals
	local cops = self._police
	
	if wgt_report[2] then
		if self._police[u_key] then
			local u_data = self._police[u_key]
			local crim_data = criminals[wgt_report[1]]
			
			local dis = mvec3_dis_sq(u_data.m_pos, crim_data.m_pos)
			
			wgt_report[2] = dis * wgt_report[2]
		end
	end

	for i_dis_rep = #wgt_report - 1, 1, -2 do
		local c_key = wgt_report[i_dis_rep]
		local c_dis = wgt_report[i_dis_rep + 1]
		local c_record = criminals[c_key]
		local imp_enemies = c_record.important_enemies
		local imp_dis = c_record.important_dis
		local was_imp = nil

		for i_imp = #imp_enemies, 1, -1 do
			if imp_enemies[i_imp] == u_key then
				table.remove(imp_enemies, i_imp)
				table.remove(imp_dis, i_imp)

				was_imp = true

				break
			end
		end

		local i_imp = #imp_dis

		while i_imp > 0 do
			if imp_dis[i_imp] <= c_dis then
				break
			end

			i_imp = i_imp - 1
		end

		if i_imp < max_nr_imp then
			i_imp = i_imp + 1

			while max_nr_imp <= #imp_enemies do
				local dump_e_key = imp_enemies[#imp_enemies]

				self:_adjust_cop_importance(dump_e_key, -1)
				t_rem(imp_enemies)
				t_rem(imp_dis)
			end

			t_ins(imp_enemies, i_imp, u_key)
			t_ins(imp_dis, i_imp, c_dis)

			if not was_imp then
				imp_adj = imp_adj + 1
			end
		elseif was_imp then
			imp_adj = imp_adj - 1
		end
	end

	if imp_adj ~= 0 then
		self:_adjust_cop_importance(u_key, imp_adj)
	end
end

function GroupAIStateBase:on_objective_failed(unit, objective)
	if not unit:brain() then
		debug_pause_unit(unit, "[GroupAIStateBase:on_objective_failed] error in extension order", unit)

		local fail_clbk = objective.fail_clbk
		objective.fail_clbk = nil

		unit:brain():set_objective(nil)

		if fail_clbk then
			fail_clbk(unit)
		end

		return
	end

	local new_objective = nil

	if unit:brain():objective() == objective then
		local u_key = unit:key()
		local u_data = self._police[u_key]

		if u_data and unit:brain():is_active() and not unit:character_damage():dead() then
			new_objective = {
				is_default = true,
				scan = true,
				type = "free",
				attitude = objective.attitude,
				grp_objective = objective.grp_objective
			}

			if u_data.assigned_area then
				local seg = unit:movement():nav_tracker():nav_segment()

				self:set_enemy_assigned(self:get_area_from_nav_seg_id(seg), u_key)
			end
		end
	end

	local fail_clbk = objective.fail_clbk
	objective.fail_clbk = nil

	if new_objective then
		unit:brain():set_objective(new_objective)
	end

	if fail_clbk then
		fail_clbk(unit)
	end
end

function GroupAIStateBase:chk_say_teamAI_combat_chatter(unit)
	if not self:is_detection_persistent() then
		return
	end

	local drama_amount = self._drama_data.amount
	local frequency_lerp = drama_amount
	local delay_tweak = tweak_data.sound.criminal_sound.combat_callout_delay
	local delay = math.lerp(delay_tweak[1], delay_tweak[2], frequency_lerp)
	local delay_t = self._teamAI_last_combat_chatter_t + delay

	if self._t < delay_t then
		return
	end

	local frequency_lerp_clamp = math.clamp(frequency_lerp^2, 0, 1)
	local chance_tweak = tweak_data.sound.criminal_sound.combat_callout_chance
	local chance = math.lerp(chance_tweak[1], chance_tweak[2], frequency_lerp_clamp)

	if chance < math.random() then
		return
	end
	
	self._teamAI_last_combat_chatter_t = self._t
	unit:sound():say("g90", true, true)
end