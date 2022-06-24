local mvec3_n_equal = mvector3.not_equal
local mvec3_set = mvector3.set
local mvec3_set_st = mvector3.set_static
local mvec3_set_z = mvector3.set_z
local mvec3_step = mvector3.step
local mvec3_sub = mvector3.subtract
local mvec3_norm = mvector3.normalize
local mvec3_dir = mvector3.direction
local mvec3_add = mvector3.add
local mvec3_mul = mvector3.multiply
local mvec3_div = mvector3.divide
local mvec3_lerp = mvector3.lerp
local mvec3_cpy = mvector3.copy
local mvec3_set_l = mvector3.set_length
local mvec3_dot = mvector3.dot
local mvec3_cross = mvector3.cross
local mvec3_dis = mvector3.distance
local mvec3_dis_sq = mvector3.distance_sq
local mvec3_rot = mvector3.rotate_with
local mvec3_length = mvector3.length
local math_abs = math.abs
local math_max = math.max
local math_clamp = math.clamp
local math_ceil = math.ceil
local math_floor = math.floor
local temp_vec1 = Vector3()
local temp_vec2 = Vector3()
local math_up = math.UP
NavigationManager.has_registered_cover_units_for_LIES = nil


Hooks:PostHook(NavigationManager, "update", "lies_cover", function(self, t, dt)
	if LIES.settings.lua_cover > 1 and not self.has_registered_cover_units_for_LIES then
		log("LIES: Cover through LUA enabled, registering cover points...")
		
		if not self._covers then
			self._covers = {}
			self:_LIES_register_cover()
			self.has_registered_cover_units_for_LIES = true
		elseif #self._covers > 0 then
			log("LIES: Covers already registered, this is the work of another mod...")
			self._covers = {}
			self:_LIES_register_cover()
			self.has_registered_cover_units_for_LIES = true
		else
			self:_LIES_register_cover()
			self.has_registered_cover_units_for_LIES = true
		end
		
		if #self._covers > 0 then
			log("LIES: Covers registered successfully.")
			log("LIES: " .. tostring(#self._covers) .. " covers registered.")
			self._funcs_replaced = true
			self.find_cover_in_cone_from_threat_pos_1 = self.find_cover_in_cone_from_threat_pos_1_LUA
			self.find_cover_from_threat = self.find_cover_from_threat_LUA
			self.find_cover_in_nav_seg_3 = self.find_cover_in_nav_seg_3_LUA
		else
			log("LIES: Covers failed to register, Vanilla cover behavior will persist.")
		end
	end
end)

function NavigationManager:_change_funcs()
	if LIES.settings.lua_cover < 2 and self._funcs_replaced then
		self._funcs_replaced = nil
		self.find_cover_in_cone_from_threat_pos_1 = NavigationManager.find_cover_in_cone_from_threat_pos_1
		self.find_cover_from_threat = NavigationManager.find_cover_from_threat
		self.find_cover_in_nav_seg_3 = NavigationManager.find_cover_in_nav_seg_3
	elseif LIES.settings.lua_cover > 1 then
		self._funcs_replaced = true
		self.find_cover_in_cone_from_threat_pos_1 = self.find_cover_in_cone_from_threat_pos_1_LUA
		self.find_cover_from_threat = self.find_cover_from_threat_LUA
		self.find_cover_in_nav_seg_3 = self.find_cover_in_nav_seg_3_LUA
	end
end

function NavigationManager:_LIES_register_cover()
	for key, res in pairs(self._nav_segments) do
		if res.pos then
			local tracker = self._quad_field:create_nav_tracker(res.pos)
			
			local location_script_data = self._quad_field:get_script_data(tracker)
			
			if location_script_data and location_script_data.covers then
				local covers = location_script_data.covers
				
				for i = 1, #covers do
					local cover = covers[i]
					
					self._covers[#self._covers + 1] = cover
				end
			end
			
			self:destroy_nav_tracker(tracker)
		end
	end
	
	self.has_registered_cover_units_for_LIES = true
end

function NavigationManager:find_cover_in_cone_from_threat_pos_1_LUA(threat_pos, furthest_pos, near_pos, search_from_pos, angle, min_dis, nav_seg, optimal_threat_dis, rsrv_filter)
	local v3_dis_sq = mvec3_dis_sq
	local world_g = World
	min_dis = min_dis and min_dis * min_dis or 0
	local nav_segs
	
	if type(nav_seg) == "table" then
		nav_segs = nav_seg
	elseif nav_seg then
		nav_segs = {nav_seg}
	end
	
	local best_cover, best_dist, best_l_ray, best_h_ray
	
	local function _f_check_cover_rays(cover, threat_pos) --this is a visibility check. first checking for crouching positions, then standing.
		local cover_pos = cover[1]
		local ray_from = temp_vec1

		mvec3_set(ray_from, math_up)
		mvec3_mul(ray_from, 82.5)
		mvec3_add(ray_from, cover_pos)
		
		local ray_to_pos = temp_vec2
		
		mvec3_set(ray_to_pos, math_up)
		mvec3_mul(ray_to_pos, 82.5)
		mvec3_add(ray_to_pos, threat_pos)

		local low_ray = world_g:raycast("ray", ray_from, ray_to_pos, "slot_mask", managers.slot:get_mask("AI_visibility"), "ray_type", "ai_vision", "report")
		local high_ray = nil

		if low_ray then
			mvec3_set_z(ray_from, ray_from.z + 82.5)
			mvec3_set_z(ray_to_pos, ray_to_pos.z + 82.5)

			high_ray = world_g:raycast("ray", ray_from, ray_to_pos, "slot_mask", managers.slot:get_mask("AI_visibility"), "ray_type", "ai_vision", "report")
		end

		return low_ray, high_ray
	end
	
	for i = 1, #self._covers do
		local cover = self._covers[i]
		
		if not cover[self.COVER_RESERVED] and self._quad_field:is_nav_segment_enabled(cover[3]:nav_segment()) then
			if not nav_segs or nav_segs[cover[3]:nav_segment()] then
				local cover_dis = mvec3_dis_sq(near_pos, cover[1])
				local threat_dir = threat_pos - cover[1]
				local threat_dist = mvec3_length(threat_dir)
				threat_dist = threat_dist * threat_dist
				
				local threat_dir_norm = threat_dir:normalized()
				
				if min_dis < threat_dist then
					if optimal_threat_dis then
						cover_dis = cover_dis - optimal_threat_dis
					end
					
					if not best_dist or cover_dis < best_dist then
						if math.cos(cone_angle) > mvec3_dot(threat_dir_norm, furthest_pos) then
							if self._quad_field:is_position_unreserved({radius = 40, position = cover[1], filter = rsrv_filter}) then
								local low_ray, high_ray
								
								if LIES.settings.lua_cover > 2 then
									low_ray, high_ray = _f_check_cover_rays(cover, threat_pos)
								end
								
								if not best_l_ray or low_ray then
									if not best_h_ray or high_ray then
										best_l_ray = low_ray
										best_h_ray = high_ray
										best_cover = cover
										best_dist = cover_dis
								
										if LIES.settings.lua_cover < 3 and cover_dis <= 10000 or cover_dis <= 10000 and best_l_ray then
											break
										end
									end
								end
							end
						end
					end
				end
			end
		end
	end
	
	if best_cover then
		return best_cover
	end
end

function NavigationManager:find_cover_from_threat_LUA(nav_seg_id, optimal_threat_dis, near_pos, threat_pos)
	local v3_dis_sq = mvec3_dis_sq
	local world_g = World
	min_dis = min_dis and min_dis * min_dis or 0
	local nav_segs
	
	if type(nav_seg_id) == "table" then
		nav_segs = nav_seg_id
	elseif nav_seg_id then
		nav_segs = {nav_seg_id}
	end
	
	local best_cover, best_dist, best_l_ray, best_h_ray
	
	local function _f_check_cover_rays(cover, threat_pos) --this is a visibility check. first checking for crouching positions, then standing.
		local cover_pos = cover[1]
		local ray_from = temp_vec1

		mvec3_set(ray_from, math_up)
		mvec3_mul(ray_from, 82.5)
		mvec3_add(ray_from, cover_pos)
		
		local ray_to_pos = temp_vec2
		
		mvec3_set(ray_to_pos, math_up)
		mvec3_mul(ray_to_pos, 82.5)
		mvec3_add(ray_to_pos, threat_pos)

		local low_ray = world_g:raycast("ray", ray_from, ray_to_pos, "slot_mask", managers.slot:get_mask("AI_visibility"), "ray_type", "ai_vision", "report")
		local high_ray = nil

		if low_ray then
			mvec3_set_z(ray_from, ray_from.z + 82.5)
			mvec3_set_z(ray_to_pos, ray_to_pos.z + 82.5)

			high_ray = world_g:raycast("ray", ray_from, ray_to_pos, "slot_mask", managers.slot:get_mask("AI_visibility"), "ray_type", "ai_vision", "report")
		end

		return low_ray, high_ray
	end
	
	for i = 1, #self._covers do
		local cover = self._covers[i]
		
		if not cover[self.COVER_RESERVED] and self._quad_field:is_nav_segment_enabled(cover[3]:nav_segment()) then
			if not nav_segs or nav_segs[cover[3]:nav_segment()] then
				local cover_dis = v3_dis_sq(near_pos, cover[1])
				local threat_dist
				
				if threat_pos then
					threat_dist = v3_dis_sq(cover[1], threat_pos)
				end
				
				if not threat_dist or min_dis < threat_dist then
					if threat_dist and optimal_threat_dis then
						cover_dis = cover_dis - optimal_threat_dis
					end
					
					if not best_dist or cover_dis < best_dist then
						if self._quad_field:is_position_unreserved({radius = 40, position = cover[1], filter = rsrv_filter}) then
							local low_ray, high_ray
								
							if threat_pos and LIES.settings.lua_cover > 2 then
								low_ray, high_ray = _f_check_cover_rays(cover, threat_pos)
							end
							
							if not best_l_ray or low_ray then
								if not best_h_ray or high_ray then
									best_l_ray = low_ray
									best_h_ray = high_ray
									best_cover = cover
									best_dist = cover_dis
							
									if LIES.settings.lua_cover < 3 and cover_dis <= 10000 or cover_dis <= 10000 and best_l_ray then
										break
									end
								end
							end
						end
					end
				end
			end
		end
	end
	
	if best_cover then
		return best_cover
	end
end

function NavigationManager:find_cover_in_nav_seg_3_LUA(nav_seg_id, max_near_dis, near_pos, threat_pos)
	local v3_dis_sq = mvec3_dis_sq
	local world_g = World
	min_dis = min_dis and min_dis * min_dis or 0

	max_near_dis = max_near_dis and max_near_dis * max_near_dis
	local nav_segs
	
	if type(nav_seg_id) == "table" then
		nav_segs = nav_seg_id
	elseif nav_seg_id then
		nav_segs = {nav_seg_id}
	end
	
	local best_cover, best_dist, best_l_ray, best_h_ray
	
	local function _f_check_cover_rays(cover, threat_pos) --this is a visibility check. first checking for crouching positions, then standing.
		local cover_pos = cover[1]
		local ray_from = temp_vec1

		mvec3_set(ray_from, math_up)
		mvec3_mul(ray_from, 82.5)
		mvec3_add(ray_from, cover_pos)
		
		local ray_to_pos = temp_vec2
		
		mvec3_set(ray_to_pos, math_up)
		mvec3_mul(ray_to_pos, 82.5)
		mvec3_add(ray_to_pos, threat_pos)

		local low_ray = world_g:raycast("ray", ray_from, ray_to_pos, "slot_mask", managers.slot:get_mask("AI_visibility"), "ray_type", "ai_vision", "report")
		local high_ray = nil

		if low_ray then
			mvec3_set_z(ray_from, ray_from.z + 82.5)
			mvec3_set_z(ray_to_pos, ray_to_pos.z + 82.5)

			high_ray = world_g:raycast("ray", ray_from, ray_to_pos, "slot_mask", managers.slot:get_mask("AI_visibility"), "ray_type", "ai_vision", "report")
		end

		return low_ray, high_ray
	end
	
	for i = 1, #self._covers do
		local cover = self._covers[i]
		
		if not cover[self.COVER_RESERVED] and self._quad_field:is_nav_segment_enabled(cover[3]:nav_segment()) then
			if not nav_segs or nav_segs[cover[3]:nav_segment()] then
				local cover_dis = mvec3_dis_sq(near_pos, cover[1])
				local threat_dist
				
				if threat_pos then
					threat_dist = v3_dis_sq(cover[1], threat_pos)
				end
				
				if not threat_dist or min_dis < threat_dist then
					if not max_near_dis or cover_dis < max_near_dis then
						if not best_dist or cover_dis < best_dist then
							if self._quad_field:is_position_unreserved({radius = 40, position = cover[1], filter = rsrv_filter}) then
								local low_ray, high_ray
								
								if threat_pos and LIES.settings.lua_cover > 2 then
									low_ray, high_ray = _f_check_cover_rays(cover, threat_pos)
								end
								
								if not best_l_ray or low_ray then
									if not best_h_ray or high_ray then
										best_l_ray = low_ray
										best_h_ray = high_ray
										best_cover = cover
										best_dist = cover_dis
								
										if LIES.settings.lua_cover < 3 and cover_dis <= 10000 or cover_dis <= 10000 and best_l_ray then
											break
										end
									end
								end
							end
						end
					end
				end
			end
		end
	end
	
	if best_cover then
		return best_cover
	end
end