Hooks:PostHook(PlayerDriving, "update", "lies_fix_vehicle", function(self, t, dt)
	if self._vehicle == nil then
		return
	elseif not self._vehicle:is_active() then
		return
	end

	if self._controller == nil then
		return
	end

	self:_upd_nav_data()
end)