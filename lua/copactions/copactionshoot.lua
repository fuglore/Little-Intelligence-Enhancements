function CopActionShoot:on_exit()
	if Network:is_server() then
		self._ext_movement:set_stance("hos")
	end

	if self._modifier_on then
		self[self._ik_preset.stop](self)
	end

	if self._autofiring then
		self._weapon_base:stop_autofire()
		self._ext_movement:play_redirect("up_idle")
	end
	
	if self._ext_anim.reload and self._looped_expire_t then
		self._looped_expire_t = nil

		self._ext_movement:play_redirect("reload_looped_exit")
	end

	if Network:is_server() then
		self._common_data.unit:network():send("action_aim_state", false)
	end

	if self._shooting_player and alive(self._attention.unit) then
		self._attention.unit:movement():on_targetted_for_attack(false, self._common_data.unit)
	end

	if self._glint_effect then
		self._glint_effect:kill_effect()
	end

	if self._ext_base and self._ext_base.prevent_main_bones_disabling then
		self._ext_base:prevent_main_bones_disabling(false)
	end
end
