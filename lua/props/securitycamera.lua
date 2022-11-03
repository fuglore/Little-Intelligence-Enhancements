function SecurityCamera:set_detection_enabled(state, settings, mission_element)
	if self._destroyed then
		return
	end

	self:set_update_enabled(state)

	self._mission_script_element = mission_element or self._mission_script_element

	if state then
		self._u_key = self._unit:key()
		self._last_detect_t = self._last_detect_t or TimerManager:game():time()
		self._detection_interval = 0
		self._SO_access_str = "security"
		self._SO_access = managers.navigation:convert_access_filter_to_number({
			self._SO_access_str
		})
		self._visibility_slotmask = managers.slot:get_mask("AI_visibility")

		if settings then
			self._set_settings = true
			self._cone_angle = settings.fov
			self._detection_delay = settings.detection_delay
			self._range = settings.detection_range
			self._suspicion_range = settings.suspicion_range
			self._team = managers.groupai:state():team_data(settings.team_id or tweak_data.levels:get_default_team_ID("combatant"))
		end

		self._detected_attention_objects = self._detected_attention_objects or {}
		self._look_obj = self._unit:get_object(Idstring("CameraLens"))
		self._yaw_obj = self._unit:get_object(Idstring("CameraYaw"))
		self._pitch_obj = self._unit:get_object(Idstring("CameraPitch"))
		self._pos = self._yaw_obj:position()
		self._look_fwd = nil
		self._tmp_vec1 = self._tmp_vec1 or Vector3()
		self._suspicion_lvl_sync = 0
	else
		self._last_detect_t = nil

		self:_destroy_all_detected_attention_object_data()

		self._brush = nil
		self._visibility_slotmask = nil
		self._detection_delay = nil
		self._detected_attention_objects = nil
		self._suspicion_lvl_sync = nil
		self._team = nil

		if not self._destroying then
			self:_stop_all_sounds()
			self:_deactivate_tape_loop()
		end
	end

	if settings then
		self:apply_rotations(settings.yaw, settings.pitch)
	end

	managers.groupai:state():register_security_camera(self._unit, state)
end

function SecurityCamera:_upd_suspicion(t)
	local function _exit_func(attention_data)
		attention_data.unit:movement():on_uncovered(self._unit)
		self:_sound_the_alarm(attention_data.unit)
	end

	local max_suspicion = 0

	for u_key, attention_data in pairs(self._detected_attention_objects) do
		if attention_data.identified and attention_data.reaction == AIAttentionObject.REACT_SUSPICIOUS then
			if not attention_data.verified then
				if attention_data.uncover_progress then
					local dt = t - attention_data.last_suspicion_t
					attention_data.uncover_progress = attention_data.uncover_progress - dt

					if attention_data.uncover_progress <= 0 then
						attention_data.uncover_progress = nil
						attention_data.last_suspicion_t = nil

						attention_data.unit:movement():on_suspicion(self._unit, false)
						managers.groupai:state():on_criminal_suspicion_progress(attention_data.unit, self._unit, false)
					else
						max_suspicion = math.max(max_suspicion, attention_data.uncover_progress)

						attention_data.unit:movement():on_suspicion(self._unit, attention_data.uncover_progress)

						attention_data.last_suspicion_t = t
					end
				end
			else
				local dis = attention_data.dis
				local susp_settings = attention_data.unit:base():suspicion_settings()
				local suspicion_range = self._suspicion_range
				local uncover_range = 0
				local max_range = self._range

				if attention_data.settings.uncover_range and dis < math.min(max_range, uncover_range) * susp_settings.range_mul then
					attention_data.unit:movement():on_suspicion(self._unit, true)	
					managers.groupai:state():on_criminal_suspicion_progress(attention_data.unit, self._unit, true)
					managers.groupai:state():criminal_spotted(attention_data.unit, true)

					max_suspicion = 1

					_exit_func(attention_data)
				elseif suspicion_range and dis < math.min(max_range, suspicion_range) * susp_settings.range_mul then
					if attention_data.last_suspicion_t then
						local dt = t - attention_data.last_suspicion_t
						local range_max = (suspicion_range - uncover_range) * susp_settings.range_mul
						local range_min = uncover_range
						local mul = 1 - (dis - range_min) / range_max
						local progress = dt * 0.5 * mul * susp_settings.buildup_mul
						attention_data.uncover_progress = (attention_data.uncover_progress or 0) + progress
						max_suspicion = math.max(max_suspicion, attention_data.uncover_progress)

						if attention_data.uncover_progress < 1 then
							attention_data.unit:movement():on_suspicion(self._unit, attention_data.uncover_progress)

							attention_data.last_suspicion_t = t
						else
							attention_data.unit:movement():on_suspicion(self._unit, true)
							managers.groupai:state():on_criminal_suspicion_progress(attention_data.unit, self._unit, true)
							managers.groupai:state():criminal_spotted(attention_data.unit, true)
							_exit_func(attention_data)
						end
					else
						attention_data.uncover_progress = 0

						managers.groupai:state():on_criminal_suspicion_progress(attention_data.unit, self._unit, 0)

						attention_data.last_suspicion_t = t
					end
				elseif attention_data.uncover_progress and attention_data.last_suspicion_t then
					local dt = t - attention_data.last_suspicion_t
					attention_data.uncover_progress = attention_data.uncover_progress - dt

					if attention_data.uncover_progress <= 0 then
						attention_data.uncover_progress = nil
						attention_data.last_suspicion_t = nil

						attention_data.unit:movement():on_suspicion(self._unit, false)
						managers.groupai:state():on_criminal_suspicion_progress(attention_data.unit, self._unit, false)
					else
						attention_data.last_suspicion_t = t
						max_suspicion = math.max(max_suspicion, attention_data.uncover_progress)

						attention_data.unit:movement():on_suspicion(self._unit, attention_data.uncover_progress)
					end
				end
			end
		end
	end

	self._suspicion = max_suspicion > 0 and max_suspicion
end

local tmp_rot1 = Rotation()

function SecurityCamera:_detect_criminals_loud(t, criminals)
	if not criminals or self._invalid_camera then
		return
	end
	
	if not self._set_settings then
		self._look_obj = self._unit:get_object(Idstring("CameraLens"))
		self._yaw_obj = self._unit:get_object(Idstring("CameraYaw"))
		
		if not self._yaw_obj then
			self._invalid_camera = true
			
			return
		end
		
		self._pitch_obj = self._unit:get_object(Idstring("CameraPitch"))
		self._pos = self._yaw_obj:position()
		
		local settings = {
		  fov = 60,		  
		  suspicion_range = 1500
		}
		
		self._cone_angle = settings.fov
		self._suspicion_range = settings.suspicion_range
		
		self._set_settings = true
	end
	
	local mvec3_dis_sq = mvector3.distance_sq
	local my_range = self._suspicion_range * self._suspicion_range
	local my_cone = self._cone_angle
	local my_pos = self._pos
	local my_fwd = self._look_fwd
	
	if not my_fwd then
		self._look_obj:m_rotation(tmp_rot1)

		self._look_fwd = Vector3()

		mrotation.y(tmp_rot1, self._look_fwd)
		
		my_fwd = self._look_fwd
	end
	
	if not self._tmp_vec1 then
		self._tmp_vec1 = Vector3()
	end
	
	for c_key, c_data in pairs(criminals) do
		if alive(c_data.unit) and t - c_data.det_t > 1 then
			local c_unit = c_data.unit
			local detection_pos = c_unit:movement():m_head_pos()
			
			if mvec3_dis_sq(my_pos, detection_pos) < my_range then
				mvector3.direction(self._tmp_vec1, my_pos, detection_pos)
				local angle = mvector3.angle(my_fwd, self._tmp_vec1)
				local angle_max = my_cone * 0.5
				angle_multiplier = angle / angle_max

				if angle_multiplier < 1 then
					local vis_ray = self._unit:raycast("ray", my_pos, detection_pos, "slot_mask", self._visibility_slotmask, "ray_type", "ai_vision")

					if not vis_ray or vis_ray.unit:key() == u_key then
						local in_cone = true

						if self._cone_angle ~= nil then
							local dir = (detection_pos - my_pos):normalized()
							in_cone = my_fwd:angle(dir) <= self._cone_angle * 0.5
						end
						
						if in_cone then
							managers.groupai:state():criminal_spotted(c_unit, true)
						end
					end
				end
			end
		end
	end
end