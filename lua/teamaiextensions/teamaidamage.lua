function TeamAIDamage:_check_fatal()
	if self._bleed_out_health <= 0 then
		if not self._bleed_out then
			self._unit:interaction():set_tweak_data("revive")
			self._unit:interaction():set_active(true, false)
		end

		self._bleed_out = nil
		self._bleed_death_t = nil
		self._bleed_out_health = nil
		self._health_ratio = 0
		self._fatal = true

		managers.groupai:state():on_criminal_disabled(self._unit)
		--PlayerMovement.set_attention_settings(self._unit:brain(), nil, "team_AI")
	end
end