Hooks:PostHook(TankCopDamage, "seq_clbk_vizor_shatter", "lies_tankvisorbroken", function(self)
	if self._unit:character_damage():dead() or not LIES.settings.hhtacs then
		return
	end
	
	local logic_data = self._unit:brain()._logic_data
	
	if logic_data then
		self._unit:brain()._logic_data._visor_broken = true
		
		if self._unit:brain()._current_logic.on_visor_lost then
			self._unit:brain()._current_logic.on_visor_lost(self._unit:brain()._logic_data)
		end
	end
end)