Hooks:PostHook(CopMovement, "_upd_actions", "lies_actions", function(self, t)
	if not self._need_upd then
		local ext_anim = self._ext_anim
		
		self._need_upd = ext_anim.fumble and true or false
	end
end)