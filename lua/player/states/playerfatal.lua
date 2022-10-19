Hooks:PostHook(PlayerFatal, "enter", "lies_fix_revive", function(self, state_data, enter_data)
	if Network:is_server() and enter_data then
		if not self._revive_SO_data then
			self._revive_SO_data = {
				unit = self._unit
			}
			
			if self._ext_movement:nav_tracker() then
				PlayerBleedout._register_revive_SO(self._revive_SO_data, "revive")
			end
		end
	end
end)