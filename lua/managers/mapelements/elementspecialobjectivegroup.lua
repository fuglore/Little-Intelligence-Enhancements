function ElementSpecialObjectiveGroup:choose_followup_SO(unit, skip_element_ids)
	if skip_element_ids and skip_element_ids[self._id] then
		--log("uh...")
		return
	end
	
	--uuugh...i feel bad doing this.
	skip_element_ids = skip_element_ids or {}

	skip_element_ids[self._id] = true
	local res_element = ElementSpecialObjective.choose_followup_SO(self, unit, skip_element_ids)

	if not res_element then
		--log("depression")
		self:event("admin_fail", unit)
	else
		--log("joy! from: " .. self._editor_name)
	end

	return res_element
end