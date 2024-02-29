function CharacterAttentionObject:_chk_update_registered_state()
	return
end

function CharacterAttentionObject:_register()
	if self._registered then
		--debug_pause_unit(self._unit, "[CharacterAttentionObject:_register] Already registered? ", self._parent_unit, self._unit)

		return
	end

	local tracker = not self._is_extension and self._unit:movement() and self._unit:movement():nav_tracker()

	managers.groupai:state():register_AI_attention_object(self._parent_unit or self._unit, self, tracker)

	self._registered = true
	self._register_key = (self._parent_unit or self._unit):key()

	self:set_update_enabled(true)
end

function CharacterAttentionObject:on_enemy_weapons_hot()
	return
end