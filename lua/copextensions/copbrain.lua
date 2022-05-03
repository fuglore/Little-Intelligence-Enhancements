Hooks:PostHook(CopBrain, "init", "lies_init", function(self, unit)
	CopBrain._logic_variants.tank.attack = BossLogicAttack
	CopBrain._logic_variants.tank_medic.attack = BossLogicAttack
	CopBrain._logic_variants.tank_mini.attack = BossLogicAttack
	CopBrain._logic_variants.mobster_boss = CopBrain._logic_variants.tank
end)

function CopBrain:search_for_coarse_immediate(search_id, to_seg, verify_clbk, access_neg)
	local params = {
		from_tracker = self._unit:movement():nav_tracker(),
		to_seg = to_seg,
		access = {
			"walk"
		},
		id = search_id,
		verify_clbk = verify_clbk,
		access_pos = self._logic_data.char_tweak.access,
		access_neg = access_neg
	}

	return managers.navigation:search_coarse(params)
end

function CopBrain:search_for_path(search_id, to_pos, prio, access_neg, nav_segs)
	if not prio then
		prio = CopLogicTravel.get_pathing_prio(self._logic_data)
	end

	local params = {
		tracker_from = self._unit:movement():nav_tracker(),
		pos_to = to_pos,
		result_clbk = callback(self, self, "clbk_pathing_results", search_id),
		id = search_id,
		prio = prio,
		access_pos = self._SO_access,
		access_neg = access_neg,
		nav_segs = nav_segs
	}
	
	if not Iter and LIES:_path_is_straight_line(self._unit:movement():nav_tracker():field_position(), to_pos, self._logic_data) then
		local path = {
			mvector3.copy(self._unit:movement():nav_tracker():field_position()),
			mvector3.copy(to_pos)
		}
	
		self:clbk_pathing_results(search_id, path)
	else
		self._logic_data.active_searches[search_id] = true

		managers.navigation:search_pos_to_pos(params)
	end

	return true
end

function CopBrain:search_for_path_from_pos(search_id, from_pos, to_pos, prio, access_neg, nav_segs)
	if not prio then
		prio = CopLogicTravel.get_pathing_prio(self._logic_data)
	end

	local params = {
		pos_from = from_pos,
		pos_to = to_pos,
		result_clbk = callback(self, self, "clbk_pathing_results", search_id),
		id = search_id,
		prio = prio,
		access_pos = self._SO_access,
		access_neg = access_neg,
		nav_segs = nav_segs
	}
	
	if not Iter and LIES:_path_is_straight_line(from_pos, to_pos, self._logic_data) then
		local path = {
			mvector3.copy(from_pos),
			mvector3.copy(to_pos)
		}
	
		self:clbk_pathing_results(search_id, path)
	else
		self._logic_data.active_searches[search_id] = true

		managers.navigation:search_pos_to_pos(params)
	end

	return true
end

function CopBrain:search_for_path_to_cover(search_id, cover, offset_pos, access_neg)
	if not prio then
		prio = CopLogicTravel.get_pathing_prio(self._logic_data)
		--log("Waaaah")
	end

	local params = {
		tracker_from = self._unit:movement():nav_tracker(),
		tracker_to = cover[3],
		prio = prio,
		result_clbk = callback(self, self, "clbk_pathing_results", search_id),
		id = search_id,
		access_pos = self._SO_access,
		access_neg = access_neg
	}
	
	if not Iter and LIES:_path_is_straight_line(params.tracker_from:field_position(), params.tracker_to:field_position(), self._logic_data) then
		local path = {
			mvector3.copy(params.tracker_from:field_position()),
			mvector3.copy(params.tracker_to:field_position())
		}
	
		self:clbk_pathing_results(search_id, path)
	else
		self._logic_data.active_searches[search_id] = true
		managers.navigation:search_pos_to_pos(params)
	end

	return true
end


if not Iter then

local orig_clbk_pathing_results = CopBrain.clbk_pathing_results 

function CopBrain:clbk_pathing_results(search_id, path)
	if path and #path > 2 then
		--local line = Draw:brush(Color.yellow:with_alpha(0.25), 3)
		
		if line then
			for i = 1, #path do
				if path[i + 1] then
					if path[i].z and path[i + 1].z then
						line:cylinder(path[i], path[i + 1], 5)
					end
				end
			end
		end

		path = LIES:_optimize_path(path, self._logic_data)
	end
	
	orig_clbk_pathing_results(self, search_id, path)
end

end

Hooks:PostHook(CopBrain, "_add_pathing_result", "lies_pathing", function(self, search_id, path)
	if path and path ~= "failed" then
		--local line2 = Draw:brush(Color.green:with_alpha(0.5), 3)
		
		if line2 and #path > 2 then
			for i = 1, #path do
				if path[i + 1] then
					if path[i].z and path[i + 1].z then
						line2:cylinder(path[i], path[i + 1], 5)
					elseif path[i].z then
						line2:sphere(path[i], 20)
					elseif path[i + 1].z then
						line2:sphere(path[i + 1], 20)
					elseif path[i - 1] and path[i - 1].z then
						line2:sphere(path[i - 1], 20)
					end
				end
			end
		end
	
		self._logic_data.t = self._timer:time()
		self._logic_data.dt = self._timer:delta_time()

		--enemies in logictravel and logicattack will perform their appropriate actions as soon as possible once pathing has finished
		
		if self._current_logic._pathing_complete_clbk then
			self._current_logic._pathing_complete_clbk(self._logic_data)
		end
	end
end)