local blockade_ids = {
	run = {
		[103773] = true,
		[103738] = false,
		[100201] = true,
		[100289] = false
	},
	glace = {
		[103544] = false,
		[100533] = true
	},
	hox_1 = {
		[100504] = false
	},
}

Hooks:PostHook(MissionScriptElement, "on_executed", "lies_blockade", function(self)
	if not LIES.settings.hhtacs then
		return
	end

	if blockade_ids[Global.level_data.level_id] then
		local on_off = blockade_ids[Global.level_data.level_id]
		
		if on_off[self._id] ~= nil then
			--log("AAAAAAAAAAAA")
			managers.groupai:state()._blockade = on_off[self._id]
		end
	end
end)