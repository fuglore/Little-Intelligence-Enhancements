function CopBrain:clbk_pathing_results(search_id, path) 
	--fixes an issue in which enemies will delay nav links if pathing to them for no reason
	--they already set a delay by using it, so theres no reason to delay it BEFORE they even get to use it
	self:_add_pathing_result(search_id, path)
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
	self._logic_data.active_searches[search_id] = true
	
	if CopLogicTravel._check_path_is_straight_line(self._unit:movement():nav_tracker():field_position(), to_pos, self._logic_data) then
		local path = {
			mvector3.copy(self._unit:movement():nav_tracker():field_position()),
			to_pos
		}
		
		self:clbk_pathing_results(search_id, path) 
	else
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
	self._logic_data.active_searches[search_id] = true

	if CopLogicTravel._check_path_is_straight_line(from_pos, to_pos, self._logic_data) then
		local path = {
			mvector3.copy(from_pos),
			to_pos
		}
		
		self:clbk_pathing_results(search_id, path) 
	else
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
	self._logic_data.active_searches[search_id] = true

	if CopLogicTravel._check_path_is_straight_line(self._unit:movement():nav_tracker():field_position(), cover[3]:field_position(), self._logic_data) then
		local path = {
			mvector3.copy(self._unit:movement():nav_tracker():field_position()),
			mvector3.copy(cover[3]:field_position())
		}
		
		self:clbk_pathing_results(search_id, path) 
	else
		managers.navigation:search_pos_to_pos(params)
	end

	return true
end

Hooks:PostHook(CopBrain, "_add_pathing_result", "lies_pathing", function(self, search_id, path)
	self._logic_data.t = self._timer:time()
	self._logic_data.dt = self._timer:delta_time()
	
	--enemies in logictravel and logicattack will perform their appropriate actions as soon as possible once pathing has finished

	if self._current_logic._pathing_complete_clbk then
		self._current_logic._pathing_complete_clbk(self._logic_data)
	end
end)