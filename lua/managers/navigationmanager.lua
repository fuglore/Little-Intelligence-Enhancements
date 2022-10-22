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

function NavigationManager:find_segment_doors_with_nav_links(from_seg_id, approve_clbk)
	local all_doors = self._room_doors
	local all_nav_segs = self._nav_segments
	local from_seg = all_nav_segs[from_seg_id]
	local found_doors = {}

	for neighbour_seg_id, door_list in pairs(from_seg.neighbours) do
		for _, i_door in ipairs(door_list) do
			if type(i_door) == "number" then
				table.insert(found_doors, all_doors[i_door])
			elseif alive(i_door) then
				local end_pos = i_door:script_data().element:nav_link_end_pos()
				local fake_door = {center=end_pos}
				table.insert(found_doors, fake_door)
			end
		end
	end

	return found_doors
end

function NavigationManager:draw_coarse_path(path, alt_color)
	if not path then
		return
	end
	
	local all_nav_segs = self._nav_segments
	
	local line1 = Draw:brush(Color.red:with_alpha(0.5), 5)
	local line2 = Draw:brush(Color.blue:with_alpha(0.5), 5)
	
	if alt_color then
		for path_i = 1, #path do
			local seg_pos = all_nav_segs[path[path_i][1]].pos
			line2:cylinder(seg_pos, seg_pos + math_up * 185, 20)
		end
	else
		for path_i = 1, #path do
			local seg_pos = all_nav_segs[path[path_i][1]].pos
			line1:cylinder(seg_pos, seg_pos + math_up * 185, 20)
		end
	end
end

function NavigationManager:generate_cover_fwd(tracker)
	local all_nav_segs = self._nav_segments
	local m_seg_id = tracker:nav_segment()
	
	if all_nav_segs[m_seg_id] then
		local new_fwd = temp_vec1
		local v3_dis_sq = mvec3_dis_sq
		local doors = self:find_segment_doors_with_nav_links(m_seg_id)
		local best_door = all_nav_segs[m_seg_id].pos
		local field_pos = tracker:field_position()
		local best_door_dis = nil
		local best_door_has_ray = nil
		
		for i = 1, #doors do
			local door = doors[i]			
			
			if math_abs(field_pos.z - door.center.z) < 180 then
				local door_on_z = door.center:with_z(field_pos.z)
				local dis = v3_dis_sq(field_pos, door_on_z)
				local ray = self:raycast({trace = false, pos_from = field_pos, pos_to = door_on_z})
				
				if (not best_door_dis or dis < best_door_dis) and (not best_door_has_ray or ray) then
					best_door = door_on_z
					best_door_dis = dis
					best_door_has_clean_ray = not ray
				end
			end
		end
		
		mvec3_dir(new_fwd, field_pos, best_door)
		
		local ray_params = {
			trace = false,
			pos_from = field_pos
		}
		
		local fwd_test = temp_vec2
		local rot_with = mvector3.rotate_with
		local nr_rotations = 7
		local angle = 360 / nr_rotations
		
		
		for i = 1, nr_rotations do
			mvec3_set(fwd_test, new_fwd)
			mvec3_mul(fwd_test, 100)
			mvec3_add(fwd_test, field_pos)
			ray_params.pos_to = fwd_test
			
			if self:raycast(ray_params) then
				break
			else
				rot_with(new_fwd, Rotation(angle))
			end
		end
		
		return mvec3_cpy(new_fwd)
	end
end

function NavigationManager:_draw_covers()
	local reserved = self.COVER_RESERVED
	local cone_height = Vector3(0, 0, 80)
	local arrow_height = Vector3(0, 0, 1)

	for i_cover, cover in ipairs(self._covers) do
		local draw_pos = cover[1]
		local tracker = cover[3]

		if tracker:lost() then
			Application:draw_cone(draw_pos, draw_pos + cone_height, 30, 1, 0, 0)

			local placed_pos = tracker:position()

			Application:draw_sphere(placed_pos, 20, 1, 0, 0)
			Application:draw_line(placed_pos, draw_pos, 1, 0, 0)
		else
			Application:draw_cone(draw_pos, draw_pos + cone_height, 30, 0, 1, 0)
		end

		local fwd_pos = temp_vec1
		mvec3_set(fwd_pos, cover[2])
		mvec3_mul(fwd_pos, 100)
		mvec3_add(fwd_pos, draw_pos)

		Application:draw_line(draw_pos, fwd_pos, 1, 0, 0)

		if cover[reserved] then
			Application:draw_sphere(draw_pos, 18, 0, 0, 1)
		end
	end
end

function NavigationManager:register_cover_units()
	if not self:is_data_ready() then
		return
	end

	local rooms = self._rooms
	local covers = {}
	local cover_data = managers.worlddefinition:get_cover_data()
	local t_ins = table.insert

	if cover_data then
		local v3_dis_sq = mvec3_dis_sq
		local function _register_cover(pos, fwd)
			local nav_tracker = self._quad_field:create_nav_tracker(pos, true)
			
			if not nav_tracker:lost() or v3_dis_sq(nav_tracker:field_position(), pos) < 3600 then
				local cover = {
					nav_tracker:field_position(),
					fwd,
					nav_tracker
				}
				
				cover[2] = self:generate_cover_fwd(nav_tracker)

				local location_script_data = self._quad_field:get_script_data(nav_tracker, true)

				if not location_script_data.covers then
					location_script_data.covers = {}
				end

				t_ins(location_script_data.covers, cover)
				t_ins(covers, cover)
			end
		end

		local tmp_rot = Rotation(0, 0, 0)

		if cover_data.rotations then
			local rotations = cover_data.rotations

			for i, yaw in ipairs(cover_data.rotations) do
				mrotation.set_yaw_pitch_roll(tmp_rot, yaw, 0, 0)
				mrotation.y(tmp_rot, temp_vec1)
				_register_cover(cover_data.positions[i], mvector3.copy(temp_vec1))
			end
		else
			for _, cover_desc in ipairs(cover_data) do
				mrotation.set_yaw_pitch_roll(tmp_rot, cover_desc[2], 0, 0)
				mrotation.y(tmp_rot, temp_vec1)
				_register_cover(cover_desc[1], mvector3.copy(temp_vec1))
			end
		end
	else
		local all_cover_units = World:find_units_quick("all", managers.slot:get_mask("cover"))

		for i, unit in ipairs(all_cover_units) do
			local pos = unit:position()
			local fwd = unit:rotation():y()
			local nav_tracker = self._quad_field:create_nav_tracker(pos, true)
			local cover = {
				nav_tracker:field_position(),
				fwd,
				nav_tracker,
				true
			}

			if self._debug then
				t_ins(covers, cover)
			end

			local location_script_data = self._quad_field:get_script_data(nav_tracker)

			if not location_script_data.covers then
				location_script_data.covers = {}
			end

			t_ins(location_script_data.covers, cover)
			self:_safe_remove_unit(unit)
		end
	end
	
	for key, res in pairs(self._nav_segments) do
		if res.pos and res.neighbours and next(res.neighbours) then	
			local tracker = self._quad_field:create_nav_tracker(res.pos, true)

			local location_script_data = self._quad_field:get_script_data(tracker, true)

			if not location_script_data.covers or not next(location_script_data.covers) then
				if not location_script_data.covers then
					location_script_data.covers = {}
				end

				local cover = {
					tracker:field_position(),
					nil,
					tracker
				}
				
				cover[2] = self:generate_cover_fwd(tracker)
				
				t_ins(location_script_data.covers, cover)
				t_ins(covers, cover)
			else
				self:destroy_nav_tracker(tracker)
			end
		end
	end

	self._covers = covers
	
	if not self.has_registered_cover_units_for_LIES then
		if #self._covers > 0 then
			self.has_registered_cover_units_for_LIES = true
			log("LIES: " .. tostring(#self._covers) .. " cover points.")
		else
			self.has_registered_cover_units_for_LIES = true
			log("LIES: Map has no cover points. ...How!?")
		end
	end
	
	self:_change_funcs()
end

--Hooks:PostHook(NavigationManager, "update", "lies_cover", function(self, t, dt)
--	self:_draw_covers()
--	self:_draw_coarse_graph()
--end)

function NavigationManager:_change_funcs()
	if LIES.settings.lua_cover < 2 and self._funcs_replaced then
		log("LIES: Cover through LUA disabled.")
		self._funcs_replaced = nil
		self.find_cover_in_cone_from_threat_pos_1 = NavigationManager.find_cover_in_cone_from_threat_pos_1
		self.find_cover_from_threat = NavigationManager.find_cover_from_threat
		self.find_cover_in_nav_seg_3 = NavigationManager.find_cover_in_nav_seg_3
	elseif LIES.settings.lua_cover > 1 then
		log("LIES: Cover through LUA enabled. Mode: " .. tostring(LIES.settings.lua_cover - 1))
		self._funcs_replaced = true
		self.find_cover_in_cone_from_threat_pos_1 = self.find_cover_in_cone_from_threat_pos_1_LUA
		self.find_cover_from_threat = self.find_cover_from_threat_LUA
		self.find_cover_in_nav_seg_3 = self.find_cover_in_nav_seg_3_LUA
	end
end

function NavigationManager:_LIES_register_cover()	
	for key, res in pairs(self._nav_segments) do
		if res.pos then
			local tracker = self._quad_field:create_nav_tracker(res.pos, true)
			
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
		mvec3_mul(ray_from, 90)
		mvec3_add(ray_from, cover_pos)
		
		local ray_to_pos = temp_vec2
		
		mvec3_set(ray_to_pos, math_up)
		mvec3_mul(ray_to_pos, 90)
		mvec3_add(ray_to_pos, threat_pos)

		local low_ray = world_g:raycast("ray", ray_from, ray_to_pos, "slot_mask", managers.slot:get_mask("AI_visibility"), "ray_type", "ai_vision", "report")
		local high_ray = nil

		if low_ray then
			mvec3_set_z(ray_from, ray_from.z + 90)
			mvec3_set_z(ray_to_pos, ray_to_pos.z + 90)

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
		mvec3_mul(ray_from, 90)
		mvec3_add(ray_from, cover_pos)
		
		local ray_to_pos = temp_vec2
		
		mvec3_set(ray_to_pos, math_up)
		mvec3_mul(ray_to_pos, 90)
		mvec3_add(ray_to_pos, threat_pos)

		local low_ray = world_g:raycast("ray", ray_from, ray_to_pos, "slot_mask", managers.slot:get_mask("AI_visibility"), "ray_type", "ai_vision", "report")
		local high_ray = nil

		if low_ray then
			mvec3_set_z(ray_from, ray_from.z + 90)
			mvec3_set_z(ray_to_pos, ray_to_pos.z + 90)

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
		mvec3_mul(ray_from, 90)
		mvec3_add(ray_from, cover_pos)
		
		local ray_to_pos = temp_vec2
		
		mvec3_set(ray_to_pos, math_up)
		mvec3_mul(ray_to_pos, 90)
		mvec3_add(ray_to_pos, threat_pos)

		local low_ray = world_g:raycast("ray", ray_from, ray_to_pos, "slot_mask", managers.slot:get_mask("AI_visibility"), "ray_type", "ai_vision", "report")
		local high_ray = nil

		if low_ray then
			mvec3_set_z(ray_from, ray_from.z + 90)
			mvec3_set_z(ray_to_pos, ray_to_pos.z + 90)

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

function NavigationManager:clamp_position_to_field(position)
	if not position then
		return
	end
	
	local position_tracker = self._quad_field:create_nav_tracker(position)
	
	local new_pos = position_tracker:field_position()
	
	self._quad_field:destroy_nav_tracker(position_tracker)

	return new_pos
end

function NavigationManager:pad_out_position(position, nr_rays, dis)
	nr_rays = math.max(2, nr_rays or 4)
	dis = dis or 46.5
	local angle = 360
	local rot_step = angle / nr_rays
	local rot_offset = 1 * angle * 0.5
	local ray_rot = Rotation(-angle * 0.5 + rot_offset - rot_step)
	local vec_to = Vector3(dis, 0, 0)

	mvec3_rot(vec_to, ray_rot)

	local pos_to = Vector3()

	mrotation.set_yaw_pitch_roll(ray_rot, rot_step, 0, 0)

	local ray_params = {
		trace = true,
		pos_from = position,
		pos_to = pos_to
	}
	local i_ray = 1
	local tmp_vec = temp_vec1
	local altered_pos = mvec3_cpy(position)
	--local line = Draw:brush(Color.red:with_alpha(0.5), 2)
	--local line2 = Draw:brush(Color.green:with_alpha(0.5), 2)
	
	for i = 1, nr_rays do
		mvec3_rot(vec_to, ray_rot)
		mvec3_set(pos_to, vec_to)
		mvec3_add(pos_to, position)
		local hit = self:raycast(ray_params)
		
		if hit then
			if line then
				line:cylinder(position, pos_to, 1)
			end
			
			mvec3_dir(tmp_vec, pos_to, position)
			mvec3_mul(tmp_vec, dis)
			mvec3_add(altered_pos, tmp_vec)
		elseif line2 then
			line2:cylinder(position, ray_params.trace[1]:with_z(position.z), 1)
		end
	end
	
	local altered_pos = altered_pos:with_z(position.z)
	local position_tracker = self._quad_field:create_nav_tracker(altered_pos, true)
	altered_pos = position_tracker:field_position()

	self._quad_field:destroy_nav_tracker(position_tracker)
	
	if line and line2 then
		line2:sphere(position, 10)
		line:sphere(altered_pos, 10)
	end
	
	return altered_pos
end