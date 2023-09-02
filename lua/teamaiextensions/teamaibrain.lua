Hooks:PostHook(TeamAIBrain, "on_cool_state_changed", "lies_swap", function(self, state)
	if Network:is_server() then
		self._unit:inventory():equip_selection(2, true)
	end
end)