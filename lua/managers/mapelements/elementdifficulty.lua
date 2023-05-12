local adjust_ids = {
	mad = {
		[101980] = 0.25,
		[101982] = 0.375,
		[101983] = 0.5
	},
	
	--transports and other heists sharing element numbers in really obvious ways.
	pines = {
		[100122] = 0.25,
		[100124] = 0.375,
		[100125] = 0.499
	},
	des = {
		[100122] = 0.25,
		[100124] = 0.375,
		[100125] = 0.5
	},
	bph = {
		[100116] = 0.25,
		[100122] = 0.5,
		[100124] = 0.25,
		[100125] = 0.5
	},
	arm_hcm = {
		[100122] = 0.25,
		[100124] = 0.375,
		[100125] = 0.5
	},
	arm_par = {
		[100122] = 0.25,
		[100124] = 0.375,
		[100125] = 0.5
	},
	arm_cro = {
		[100122] = 0.35,
		[100124] = 0.5,
		[100125] = 0.65
	},
}

Hooks:PostHook(ElementDifficulty, "init", "lies_alter_diff_values", function(self)
	if not LIES.settings.hhtacs then
		return
	end

	if adjust_ids[Global.level_data.level_id] then
		local to_adjust = adjust_ids[Global.level_data.level_id]
		
		if to_adjust[self._id] then
			self._values.difficulty = to_adjust[self._id]
		end
	end
end)