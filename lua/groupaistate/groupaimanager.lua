Hooks:PreHook(GroupAIManager, "set_state", "lies_groupsetup", function(self, name)
	log("LIES: Initializing tweak_data...")
	tweak_data.group_ai:_LIES_setup()
	
	if self._state then
		self._state._tweak_data = tweak_data.group_ai[name]
	end
end)