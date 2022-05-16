Hooks:PostHook(CopMovement, "_upd_actions", "lies_actions", function(self, t)
	if not self._need_upd then
		local ext_anim = self._ext_anim
		
		self._need_upd = ext_anim.fumble and true or false
	end
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