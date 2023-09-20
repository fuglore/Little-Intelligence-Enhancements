Hooks:PostHook(CopMovement, "_upd_actions", "lies_actions", function(self, t)
	if not self._need_upd then
		local ext_anim = self._ext_anim
		
		self._need_upd = ext_anim.fumble and true
		
		if not self._need_upd then
			if managers.groupai:state():whisper_mode() and self._ext_base:lod_stage() then
				self._need_upd = true
			end
		end
		
		if self._need_upd then
			self:upd_m_head_pos()
		end
	end
	
	self._unit:brain():upd_falloff_sim()
end)

local action_req_orig = CopMovement.action_request

function CopMovement:action_request(action_desc)
	if action_desc and action_desc.variant == "suppressed_reaction" then
		if self._ext_anim.crouch or self._action_common_data.char_tweak and self._action_common_data.char_tweak.no_suppressed_reaction then
			return
		end
	end
	
	return action_req_orig(self, action_desc)
end

function CopMovement:force_upd_z_ray()
	self:upd_ground_ray()

	if self._gnd_ray then
		self:set_position(self._gnd_ray.position)
	end
end