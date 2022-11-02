Hooks:PostHook(AttentionTweakData, "init", "lies_fix_badaimobjs", function(self)
		self.settings.prop_civ_ene_ntl = {
		uncover_range = 500,
		reaction = "REACT_SCARED",
		notice_requires_FOV = true,
		verification_interval = 0.4,
		release_delay = 1,
		filter = "civilians_enemies"
	}
	self.settings.prop_ene_ntl_edaycrate = {
		uncover_range = 300,
		reaction = "REACT_SCARED",
		notice_requires_FOV = true,
		max_range = 700,
		verification_interval = 0.4,
		release_delay = 1,
		filter = "all_enemy"
	}
	self.settings.prop_ene_ntl = {
		uncover_range = 500,
		reaction = "REACT_SCARED",
		notice_requires_FOV = true,
		verification_interval = 0.4,
		release_delay = 1,
		filter = "all_enemy"
	}
	self.settings.broken_cam_ene_ntl = {
		uncover_range = 100,
		reaction = "REACT_SCARED",
		notice_requires_FOV = true,
		max_range = 1200,
		suspicion_range = 1000,
		verification_interval = 0.4,
		release_delay = 1,
		filter = "law_enforcer"
	}
	self.settings.no_staff_ene_ntl = {
		uncover_range = 100,
		reaction = "REACT_SCARED",
		notice_requires_FOV = true,
		max_range = 1200,
		suspicion_range = 1000,
		verification_interval = 0.4,
		release_delay = 1,
		filter = "law_enforcer"
	}
	self.settings.timelock_ene_ntl = {
		uncover_range = 100,
		reaction = "REACT_SCARED",
		notice_requires_FOV = true,
		max_range = 1200,
		suspicion_range = 1000,
		verification_interval = 0.4,
		release_delay = 1,
		filter = "law_enforcer"
	}
	self.settings.open_security_gate_ene_ntl = {
		uncover_range = 100,
		reaction = "REACT_SCARED",
		notice_requires_FOV = true,
		max_range = 1200,
		suspicion_range = 1000,
		verification_interval = 0.4,
		release_delay = 1,
		filter = "law_enforcer"
	}
	self.settings.open_vault_ene_ntl = {
		uncover_range = 100,
		reaction = "REACT_SCARED",
		notice_requires_FOV = true,
		max_range = 600,
		suspicion_range = 500,
		verification_interval = 0.4,
		release_delay = 1,
		filter = "law_enforcer"
	}
	self.settings.open_elevator_ene_ntl = {
		uncover_range = 800,
		reaction = "REACT_SCARED",
		notice_requires_FOV = true,
		max_range = 1500,
		suspicion_range = 1200,
		verification_interval = 0.4,
		release_delay = 1,
		filter = "civilians_enemies"
	}
end)