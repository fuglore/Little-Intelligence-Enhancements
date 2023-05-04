local orig_func = CopDamage.damage_explosion

function CopDamage:damage_explosion(attack_data)
	if self._dead or self._invulnerable then
		return
	end
	
	if attack_data and attack_data.attacker_unit and alive(attack_data.attacker_unit) then
		local attacker = attack_data.attacker_unit
		local base_ext = attacker:base()

		if base_ext and base_ext.thrower_unit then
			attacker = base_ext:thrower_unit()
			attacker = alive(attacker) and attacker or nil
		end
		
		if attacker and attacker:movement() and attacker:movement().team then
			if self:is_friendly_fire(attacker) then
				return
			end
		end
	end
	
	orig_func(self, attack_data)
end

Hooks:PostHook(CopDamage, "_on_damage_received", "lies_pain_lines", function(self, damage_info)
	if damage_info.variant == "stun" then
		local t = TimerManager:game():time()
		
		if not self._last_said_ecm_t or t - self._last_said_ecm_t > 10 then
			if self._unit:sound():say("ch3", true) then
				self._last_said_ecm_t = t
			end
		end
	end
end)