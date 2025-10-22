local adjust_ids = {
	--halloweiners
	nail = {
		[101612] = 0.1,
		[101887] = 0.25,
		[100465] = 0.499,
		[100550] = 0.499,
	},
	help = {
		[100026] = 0.1,
		[100059] = 0.25,
		[100060] = 0.499,
	},
	hvh = {
		[100125] = 0.01,
		[100122] = 0.01,
		[100124] = 0.01,
	},
	
	--normal heists
	mad = {
		[101980] = 0.01,
		[101982] = 0.25,
		[101983] = 0.499
	},
	glace = {
		[100530] = 0.375,
		[100531] = 0.499,
		[100532] = 0.6
	},
	run = {
		[103749] = 0.375,
		[103750] = 0.499,
		[103751] = 0.6
	},
	chew = {
		[100136] = 0.375,
		[100909] = 0.6
	},
	rvd2 = {
		[100116] = 0.375,
		[100124] = 0.499,
		[100125] = 0.75
	},
	hox_1 = {
		[100122] = 0.01
	},
	sah = {
		[100122] = 0.25,
		[100124] = 0.375,
		[102685] = 0.499,
		[100125] = 0.5,
	},
	crojob2 = {
		[101739] = 0.1,
		[101049] = 0.25,
		[101050] = 0.5,	
	},
	crojob3 = {
		[100557] = 0.1,
		[101220] = 0.25,
		[101221] = 0.375,	
	},
	crojob3_night = {
		[100557] = 0.1,
		[101220] = 0.25,
		[101221] = 0.375,	
	},
	peta = {
		[100122] = 0.1,
		[100124] = 0.25,
		[100125] = 0.5,
	},
	peta2	 = {
		[100122] = 0.1,
		[100124] = 0.25,
		[100125] = 0.5,
	},
	
	--transports and other heists sharing element numbers in really obvious ways.
	pines = {
		[100122] = 0.01,
		[100124] = 0.25,
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
	arm_und = {
		[100122] = 0.25,
		[100124] = 0.375,
		[100125] = 0.499
	},
	arm_fac = {
		[100122] = 0.25,
		[100124] = 0.375,
		[100125] = 0.499
	},
	arm_hcm = {
		[100122] = 0.25,
		[100124] = 0.375,
		[100125] = 0.499
	},
	arm_par = {
		[100122] = 0.25,
		[100124] = 0.375,
		[100125] = 0.499
	},
	arm_cro = {
		[100122] = 0.25,
		[100124] = 0.375,
		[100125] = 0.499
	},
	arm_for = {
		[100122] = 0.25,
		[100124] = 0.375,
		[100125] = 0.499
	},
}
local remove_on_exec = {
	pent = {
		[101606] = true --yufu wang wont turn off assaults
	}
}

Hooks:PostHook(ElementDifficulty, "init", "lies_alter_diff_values", function(self)
	if not LIES.settings.hhtacs then
		return
	end

	if adjust_ids[Global.level_data.level_id] then
		local to_adjust = adjust_ids[Global.level_data.level_id]
		
		if to_adjust[self._id] then
			self._values.difficulty = to_adjust[self._id]
			if Global.game_settings.difficulty == "sm_wish" then
				self._values.difficulty = self._values.difficulty + 0.1
			end
		end
	end
	
	if remove_on_exec[Global.level_data.level_id] then
		local to_adjust = remove_on_exec[Global.level_data.level_id]
		
		if remove_on_exec[self._id] then --empty out the on executed table
			self._values.on_executed = {}
		end
	end
end)