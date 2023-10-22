function TeamAIInventory:equip_selection(selection_index, instant)
	if selection_index == 1 and not self._unit:movement():cool() and self._available_selections[2] then --telling them to equip their npc-weapon secondary during loud, no.
		selection_index = 2
	end

	local res = TeamAIInventory.super.equip_selection(self, selection_index, instant)
	
	self:_ensure_weapon_visibility()
	
	return res
end