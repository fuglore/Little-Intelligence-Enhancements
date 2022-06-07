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
local math_abs = math.abs
local math_max = math.max
local math_clamp = math.clamp
local math_ceil = math.ceil
local math_floor = math.floor
local temp_vec1 = Vector3()
local temp_vec2 = Vector3()
local math_up = math.UP
local temp_vec1 = Vector3()
local temp_vec2 = Vector3()
NavigationManager.has_registered_cover_units_for_LIES = nil


Hooks:PostHook(NavigationManager, "update", "lies_cover", function(self, t, dt)
	if not self.has_registered_cover_units_for_LIES and LIES.settings.lua_cover then
		log("LIES: Cover through LUA enabled, registering cover points...")
		
		if not self._covers then
			self._covers = {}
			self:register_cover_units(true) --run this in order to allow LUA-based cover searches.
			self.has_registered_cover_units_for_LIES = true
		elseif #self._covers > 0 then
			log("LIES: Covers already registered, this is the work of another mod.")
			self.has_registered_cover_units_for_LIES = true
		else
			self:register_cover_units(true) --run this in order to allow LUA-based cover searches.
			self.has_registered_cover_units_for_LIES = true
		end
		
		if #self._covers > 0 then
			log("LIES: Covers registered successfully, neat.")
			
			self.find_cover_in_cone_from_threat_pos_1 = LIES.find_cover_in_cone_from_threat_pos_1
			self.find_cover_in_nav_seg_3 = LIES.find_cover_in_nav_seg_3
			self.find_cover_from_threat = LIES.find_cover_from_threat
			self.find_cover_near_pos_1 = LIES.find_cover_near_pos_1
			self.find_cover_away_from_pos = LIES.find_cover_away_from_pos
		else
			log("LIES: Covers failed to register, Vanilla cover behavior will persist.")
		end
	end
end)

function NavigationManager:register_cover_units(please)
	if not please and not self:is_data_ready() then
		return
	end

	local rooms = self._rooms
	local covers = {}
	local cover_data = managers.worlddefinition:get_cover_data()
	local t_ins = table.insert

	if cover_data then
		local function _register_cover(pos, fwd)
			local nav_tracker = self._quad_field:create_nav_tracker(pos, true)
			local cover = {
				nav_tracker:field_position(),
				fwd,
				nav_tracker
			}

			if please or self._debug then
				t_ins(covers, cover)
			end

			local location_script_data = self._quad_field:get_script_data(nav_tracker, true)

			if not location_script_data.covers then
				location_script_data.covers = {}
			end

			t_ins(location_script_data.covers, cover)
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

			if please or self._debug then
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

	self._covers = covers
end

function NavigationManager:_find_cover_in_seg_through_lua(threat_pos, near_pos, desired_segs)
	--log("aaaaa")
	local v3_dis_sq = mvec3_dis_sq
	local world_g = World
	local nav_segs = desired_segs
	local slotmask = managers.slot:get_mask("AI_visibility")
	local nav_seg = nil
	
	if min_dis then
		min_dis = min_dis * min_dis
	end
	
	if threat_pos then
		threat_pos = threat_pos + math_up * 160
	end
	
	if type(desired_segs) ~= "table" then
		nav_seg = desired_segs
		nav_segs = nil
	end
	
	local function _f_check_cover_dis(cover, near_pos) --checking the distance of the cover to the near_pos
		local dis_sq = v3_dis_sq
		local cover_dis = dis_sq(cover[1], near_pos)
		
		return cover_dis
	end
	
	local function _f_check_cover_rays(cover, threat_pos, slotmask) --this is a visibility check. first checking for crouching positions, then standing.
		local cover_pos = cover[1]
		local ray_from = temp_vec1

		mvec3_set(ray_from, math_up)
		mvec3_mul(ray_from, 82.5)
		mvec3_add(ray_from, cover_pos)

		local ray_to_pos = threat_pos

		local low_ray = world_g:raycast("ray", ray_from, ray_to_pos, "slot_mask", slotmask, "ray_type", "ai_vision", "report")
		local high_ray = nil

		if low_ray then
			mvec3_set_z(ray_from, ray_from.z + 82.5)

			high_ray = world_g:raycast("ray", ray_from, ray_to_pos, "slot_mask", slotmask, "ray_type", "ai_vision", "report")
		end

		return low_ray, high_ray
	end
	
	local best_cover, best_cover_dis, best_cover_low_ray, best_cover_high_ray

	for i = 1, #self._covers do
		local cover = self._covers[i]
		
		if not cover[self.COVER_RESERVED] then
			if nav_segs and nav_segs[cover[3]:nav_segment()] or nav_seg == cover[3]:nav_segment() then
				if near_pos then
					cover_dis = _f_check_cover_dis(cover, near_pos)
				end
				
				if not best_cover_dis or cover_dis < best_cover_dis then
					local cover_low_ray, cover_high_ray
					
					if threat_pos then
						cover_low_ray, cover_high_ray = _f_check_cover_rays(cover, threat_pos, slotmask)
					end
							
					if not best_cover_low_ray or cover_low_ray then
						if not best_cover_high_ray or cover_high_ray then
							best_cover = cover
							best_cover_dis = cover_dis
							best_cover_low_ray = cover_low_ray
							best_cover_high_ray = cover_high_ray
						end
					end
				end
			end
		end
	end
	
	return best_cover
end

function NavigationManager:_find_cover_through_lua(threat_pos, near_pos, far_pos, min_dis, search_from_pos, max_dis)
	local v3_dis_sq = mvec3_dis_sq
	local world_g = World
	local slotmask = managers.slot:get_mask("AI_visibility")
	
	min_dis = min_dis and min_dis * min_dis
	max_dis = max_dis and max_dis or v3_dis_sq(near_pos, far_pos)
	
	if threat_pos then
		threat_pos = threat_pos + math_up * 160
	end
	
	local pos_tracker = nil
	
	if search_from_pos then
		pos_tracker = self:create_nav_tracker(search_from_pos)
	else
		pos_tracker = self:create_nav_tracker(near_pos)
	end

	local function _f_check_max_dis(cover, near_pos, max_dis) --checking if the cover is further than our max search distance.
		local dis_sq = v3_dis_sq
		local cover_dis = dis_sq(cover[1], near_pos)
		
		if cover_dis > max_dis then
			return
		else
			return true
		end
	end
	
	local function _f_check_min_dis(cover, threat_pos, min_dis) --minimum distance from threat.
		if not threat_pos then
			return
		end
	
		local dis_sq = v3_dis_sq
		local cover_dis = dis_sq(cover[1], threat_pos)
		
		if cover_dis < min_dis then
			return
		else
			return cover_dis
		end
	end
	
	local function _f_check_cover_rays(cover, threat_pos, slotmask) --this is a visibility check. first checking for crouching positions, then standing.
		local cover_pos = cover[1]
		local ray_from = temp_vec1

		mvec3_set(ray_from, math_up)
		mvec3_mul(ray_from, 82.5)
		mvec3_add(ray_from, cover_pos)

		local ray_to_pos = threat_pos

		local low_ray = world_g:raycast("ray", ray_from, ray_to_pos, "slot_mask", slotmask, "ray_type", "ai_vision", "report")
		local high_ray = nil

		if low_ray then
			mvec3_set_z(ray_from, ray_from.z + 82.5)

			high_ray = world_g:raycast("ray", ray_from, ray_to_pos, "slot_mask", slotmask, "ray_type", "ai_vision", "report")
		end

		return low_ray, high_ray
	end
	
	local best_cover, best_cover_optimal_dis, best_cover_min_dis, best_cover_low_ray, best_cover_high_ray
	
	for i = 1, #self._covers do
		local cover = self._covers[i]
		
		--is this cover already reserved by someone else?
		if not cover[self.COVER_RESERVED] then
			--the priority is as follows:
			--the cover is further than the minimum distance of the threat.
			--the cover is optimally distanced, and close to our optimal position.
			--the cover would cover up our head if we crouched.
			--the cover would cover up our head if we stood up.
			
			--the only actual REQUIREMENTS for the cover is for it to be within the maximum search distance and to be something we can path to, everything else is fluff.
			
			if _f_check_max_dis(cover, near_pos, max_dis) then
				--can we path to this cover?
				local coarse_params = {
					access_pos = "swat",
					from_tracker = pos_tracker,
					to_tracker = cover[3],
					id = "cover" .. tostring(i)
				}
				local path = self:search_coarse(coarse_params)
				
				if path then
					local cover_min_dis, cover_low_ray, cover_high_ray
					
					cover_min_dis = min_dis and _f_check_min_dis(cover, threat_pos, min_dis)
					
					if not best_cover_min_dis or cover_min_dis and cover_min_dis > best_cover_min_dis then
						cover_low_ray, cover_high_ray = _f_check_cover_rays(cover, threat_pos, slotmask)
						
						if not best_cover_low_ray or cover_low_ray then
							if not best_cover_high_ray or cover_high_ray then
								best_cover = cover
								best_cover_min_dis = cover_min_dis
								best_cover_low_ray = cover_low_ray
								best_cover_high_ray = cover_high_ray
								
								if best_cover_min_dis and best_cover_low_ray then
									self:destroy_nav_tracker(pos_tracker)
									return best_cover
								end
							end
						end
					end
				end
			end
		end
	end
	
	self:destroy_nav_tracker(pos_tracker)
	
	return best_cover
end

function NavigationManager:_find_cover_through_lua_quick(near_pos, max_dis, access_pos) --meant for quick searches, find cover nearest to a pos
	local v3_dis_sq = mvec3_dis_sq
	local world_g = World

	max_dis = max_dis and max_dis * max_dis or 490000
	
	local function _f_check_dis(cover, near_pos, max_dis) --checking if the cover is further than our max search distance.
		local dis_sq = v3_dis_sq
		local cover_dis = dis_sq(cover[1], near_pos)
		
		if math.abs(cover[1].z - near_pos.z) > 250 then
			return
		end
		
		if cover_dis > max_dis then
			return
		else
			return true
		end
	end

	local best_cover
	local pos_tracker = self:create_nav_tracker(near_pos)

	for i = 1, #self._covers do
		local cover = self._covers[i]

		if not cover[self.COVER_RESERVED] then
			if _f_check_dis(cover, near_pos, max_dis) then
				local coarse_params = {
					access_pos = access_pos or "swat",
					from_tracker = pos_tracker,
					to_tracker = cover[3],
					id = "cover" .. tostring(i)
				}
				local path = self:search_coarse(coarse_params)
				
				if path then
					best_cover = cover
				end
				
				break
			end
		end
	end
	
	self:destroy_nav_tracker(pos_tracker)
	
	return best_cover
end