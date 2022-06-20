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