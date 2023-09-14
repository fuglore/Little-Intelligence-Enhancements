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

function SecurityCamera:_upd_detect_attention_objects(t)
	local detected_obj = self._detected_attention_objects
	local my_key = self._u_key
	local my_pos = self._pos
	local my_fwd = self._look_fwd
	local det_delay = self._detection_delay
	local hhtacs = LIES.settings.hhtacs

	for u_key, attention_info in pairs(detected_obj) do
		if t >= attention_info.next_verify_t then
			attention_info.next_verify_t = t + (attention_info.identified and attention_info.verified and attention_info.settings.verification_interval * 1.3 or attention_info.settings.verification_interval * 0.3)

			if not attention_info.identified then
				local noticable = nil
				local angle, dis_multiplier = self:_detection_angle_and_dis_chk(my_pos, my_fwd, attention_info.handler, attention_info.settings, attention_info.handler:get_detection_m_pos())

				if angle then
					local attention_pos = attention_info.handler:get_detection_m_pos()
					local vis_ray = self._unit:raycast("ray", my_pos, attention_pos, "slot_mask", self._visibility_slotmask, "ray_type", "ai_vision")

					if not vis_ray or vis_ray.unit:key() == u_key then
						noticable = true
					end
				end

				local delta_prog = nil
				local dt = t - attention_info.prev_notice_chk_t

				if noticable then
					if angle == -1 then
						if attention_info.is_husk_player then
							local peer = managers.network:session():peer_by_unit(attention_info.unit)
							local latency = peer and Network:qos(peer:rpc()).ping or nil
							
							if latency then
								local ping = latency / 1000
								
								delta_prog = dt / ping + 0.02
							end	
						else
							delta_prog = 1
						end
					else
						local min_delay = det_delay[1]
						local max_delay = det_delay[2]
						local angle_mul_mod = 0.15 * math.min(angle / self._cone_angle, 1)
						local dis_mul_mod =  0.85 * dis_multiplier
						local notice_delay_mul = attention_info.settings.notice_delay_mul or 1

						if attention_info.settings.detection and attention_info.settings.detection.delay_mul then
							if hhtacs then
								local mul = attention_info.settings.detection.delay_mul
								mul = math.lerp(mul, 1, 0.75) --detection risk affects detection rate 75% less
								
								notice_delay_mul = notice_delay_mul * mul
							else
								notice_delay_mul = notice_delay_mul * attention_info.settings.detection.delay_mul
							end
						end
						
						local notice_delay_modified = math.lerp(min_delay * notice_delay_mul, max_delay, dis_mul_mod + angle_mul_mod)
						
						if attention_info.is_husk_player then
							local peer = managers.network:session():peer_by_unit(attention_info.unit)
							local latency = peer and Network:qos(peer:rpc()).ping or nil
							
							if latency then
								local ping = latency / 1000
								
								notice_delay_modified = notice_delay_modified + ping + 0.02
							end	
						end
						
						delta_prog = notice_delay_modified > 0 and dt / notice_delay_modified or 1
					end
				else
					delta_prog = det_delay[2] > 0 and -dt / det_delay[2] or -1
				end

				attention_info.notice_progress = attention_info.notice_progress + delta_prog

				if attention_info.notice_progress >= 1 then
					attention_info.notice_progress = nil
					attention_info.prev_notice_chk_t = nil
					attention_info.identified = true
					attention_info.release_t = t + attention_info.settings.release_delay
					attention_info.identified_t = t
					noticable = true

					if AIAttentionObject.REACT_SCARED <= attention_info.settings.reaction then
						managers.groupai:state():on_criminal_suspicion_progress(attention_info.unit, self._unit, true)
					end
				elseif attention_info.notice_progress <= 0 then
					self:_destroy_detected_attention_object_data(attention_info)

					noticable = false
				else
					noticable = attention_info.notice_progress
					attention_info.prev_notice_chk_t = t

					if AIAttentionObject.REACT_SCARED <= attention_info.settings.reaction then
						managers.groupai:state():on_criminal_suspicion_progress(attention_info.unit, self._unit, noticable)
					end
				end

				if noticable ~= false and attention_info.settings.notice_clbk then
					attention_info.settings.notice_clbk(self._unit, noticable)
				end
			end

			if attention_info.identified then
				attention_info.nearly_visible = nil
				local verified, vis_ray = nil
				local attention_pos = attention_info.handler:get_detection_m_pos()
				local dis = mvector3.distance(my_pos, attention_info.m_pos)

				if dis < self._range * 1.2 then
					local detect_pos = nil

					if attention_info.is_husk_player and attention_info.unit:anim_data().crouch then
						detect_pos = self._tmp_vec1

						mvector3.set(detect_pos, attention_info.m_pos)
						mvector3.add(detect_pos, tweak_data.player.stances.default.crouched.head.translation)
					else
						detect_pos = attention_pos
					end

					local in_FOV = self:_detection_angle_chk(my_pos, my_fwd, detect_pos, 0.8)

					if in_FOV then
						vis_ray = self._unit:raycast("ray", my_pos, detect_pos, "slot_mask", self._visibility_slotmask, "ray_type", "ai_vision")

						if not vis_ray or vis_ray.unit:key() == u_key then
							verified = true
						end
					end

					attention_info.verified = verified
				end

				attention_info.dis = dis

				if verified then
					attention_info.release_t = nil
					attention_info.verified_t = t

					mvector3.set(attention_info.verified_pos, attention_pos)

					attention_info.last_verified_pos = mvector3.copy(attention_pos)
					attention_info.verified_dis = dis
				elseif attention_info.release_t and attention_info.release_t < t then
					self:_destroy_detected_attention_object_data(attention_info)
				else
					attention_info.release_t = attention_info.release_t or t + attention_info.settings.release_delay
				end
			end
		end
	end
end

function SecurityCamera:_upd_suspicion(t)
	local function _exit_func(attention_data)
		attention_data.unit:movement():on_uncovered(self._unit)
		self:_sound_the_alarm(attention_data.unit)
	end

	local max_suspicion = 0
	local hhtacs = LIES.settings.hhtacs

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
				local susp_mul = susp_settings.range_mul
				
				if hhtacs then
					susp_mul = math.lerp(susp_mul, 1, 0.75)
				end
				
				local uncover_range = 0
				local max_range = self._range

				if attention_data.settings.uncover_range and dis < math.min(max_range, uncover_range) * susp_mul then
					attention_data.unit:movement():on_suspicion(self._unit, true)	
					managers.groupai:state():on_criminal_suspicion_progress(attention_data.unit, self._unit, true)
					managers.groupai:state():criminal_spotted(attention_data.unit, true)

					max_suspicion = 1

					_exit_func(attention_data)
				elseif suspicion_range and dis < math.min(max_range, suspicion_range) * susp_mul then
					if attention_data.last_suspicion_t then
						local dt = t - attention_data.last_suspicion_t
						local range_max = (suspicion_range - uncover_range) * susp_mul
						local range_min = uncover_range
						local mul = 1 - (dis - range_min) / range_max
						
						local settings_mul
			
						if hhtacs then
							settings_mul = math.lerp(susp_settings.buildup_mul, 1, 0.5) / attention_data.settings.suspicion_duration
						else
							settings_mul = susp_settings.buildup_mul
						end
						
						local total_mul = mul * settings_mul

						if attention_data.is_husk_player then
							local peer = managers.network:session():peer_by_unit(attention_data.unit)
							local latency = peer and Network:qos(peer:rpc()).ping or nil
							
							if latency then
								local ping = latency / 1000
								local ping_add = 1 + ping + 0.02
								
								total_mul = total_mul / ping_add
							end	
						end
						
						local progress = dt * 0.5 * total_mul
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

function SecurityCamera:_detection_angle_and_dis_chk(my_pos, my_fwd, handler, settings, attention_pos)
	local dis = mvector3.direction(self._tmp_vec1, my_pos, attention_pos)
	local dis_multiplier, angle_multiplier = nil
	local max_dis = math.min(self._range, settings.max_range or self._range)

	if settings.detection and settings.detection.range_mul then
		local mul = settings.detection.range_mul
		
		if LIES.settings.hhtacs then
			mul = math.lerp(mul, 1, 0.75)
		end
		
		max_dis = max_dis * mul
	end

	dis_multiplier = dis / max_dis

	if dis_multiplier < 1 then
		if settings.notice_requires_FOV then
			local angle = mvector3.angle(my_fwd, self._tmp_vec1)
			local angle_max = self._cone_angle * 0.5
			angle_multiplier = angle / angle_max

			if angle_multiplier < 1 then
				return angle, dis_multiplier
			end
		else
			return 0, dis_multiplier
		end
	end
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