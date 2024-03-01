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

function AttentionTweakData:setup_hhtacs()
	self.settings.team_enemy_cbt.weight_mul = 1
	self.settings.custom_enemy_suburbia_shootout.weight_mul = 1
	self.settings.sentry_gun_enemy_cbt_hacked.weight_mul = 1

	local difficulty = Global.game_settings and Global.game_settings.difficulty or "normal"
	local difficulty_index = tweak_data:difficulty_to_index(difficulty)
	
	--player heister attention object states start here
	if difficulty_index > 6 then
		self.settings.pl_mask_off_foe_combatant.turn_around_range = 500
	end
	
	self.settings.pl_mask_on_foe_combatant_whisper_mode_stand.delay_override = {
		0.3,
		5
	}
	self.settings.pl_mask_on_foe_combatant_whisper_mode_stand.max_range = 3000
	
	self.settings.pl_mask_on_foe_non_combatant_whisper_mode_stand.delay_override = {
		0.3,
		5
	}
	self.settings.pl_mask_on_foe_non_combatant_whisper_mode_stand.max_range = 3000
	self.settings.pl_mask_on_foe_non_combatant_whisper_mode_stand.notice_delay_mul = 2
	
	self.settings.pl_mask_on_foe_combatant_whisper_mode_crouch.delay_override = {
		0.3,
		5
	}
	self.settings.pl_mask_on_foe_combatant_whisper_mode_crouch.max_range = 2000
	
	self.settings.pl_mask_on_foe_non_combatant_whisper_mode_crouch.delay_override = {
		0.3,
		5
	}
	self.settings.pl_mask_on_foe_non_combatant_whisper_mode_crouch.max_range = 2000
	self.settings.pl_mask_on_foe_non_combatant_whisper_mode_crouch.notice_delay_mul = 2
	
	--civilian attention object states start here
	self.settings.civ_enemy_corpse_sneak.max_range = 1200
	self.settings.civ_enemy_corpse_sneak.notice_delay_mul = 2
	
	self.settings.civ_civ_cbt.max_range = 1200
	self.settings.civ_civ_cbt.notice_delay_mul = 3
		
	--enemy attention object states start here
	self.settings.enemy_law_corpse_sneak = self.settings.civ_enemy_corpse_sneak
	self.settings.enemy_team_corpse_sneak = self.settings.civ_enemy_corpse_sneak
	
	self.settings.enemy_civ_cbt.max_range = 1200
	self.settings.enemy_civ_cbt.verification_interval = 0.1
	self.settings.enemy_civ_cbt.notice_delay_mul = 3
	
	self.settings.enemy_enemy_cbt.max_range = 1200
	self.settings.enemy_enemy_cbt.verification_interval = 0.1
	self.settings.enemy_enemy_cbt.notice_delay_mul = 3
	

	--prop attention object states start here
	self.settings.drill_civ_ene_ntl.max_range = 1100
	self.settings.drill_silent_civ_ene_ntl.max_range = 1000
	self.settings.prop_carry_bag.max_range = 800
	self.settings.prop_carry_bodybag.max_range = 800
	
	--mission attention object states start here
	self.settings.no_staff_ene_ntl = {
		uncover_range = 100,
		reaction = "REACT_CURIOUS",
		notice_requires_FOV = true,
		max_range = 1200,
		suspicion_range = 1000,
		verification_interval = 0.4,
		release_delay = 1,
		filter = "law_enforcer"
	}
	self.settings.timelock_ene_ntl = {
		uncover_range = 100,
		reaction = "REACT_CURIOUS",
		notice_requires_FOV = true,
		max_range = 1200,
		suspicion_range = 1000,
		verification_interval = 0.4,
		release_delay = 1,
		filter = "law_enforcer"
	}
	self.settings.open_security_gate_ene_ntl = {
		uncover_range = 100,
		reaction = "REACT_CURIOUS",
		notice_requires_FOV = true,
		max_range = 1200,
		suspicion_range = 1000,
		verification_interval = 0.4,
		release_delay = 1,
		filter = "law_enforcer"
	}
	self.settings.open_vault_ene_ntl = {
		uncover_range = 100,
		reaction = "REACT_CURIOUS",
		notice_requires_FOV = true,
		max_range = 600,
		suspicion_range = 500,
		verification_interval = 0.4,
		release_delay = 1,
		filter = "law_enforcer"
	}
	self.settings.open_elevator_ene_ntl = {
		uncover_range = 800,
		reaction = "REACT_CURIOUS",
		notice_requires_FOV = true,
		max_range = 1500,
		suspicion_range = 1200,
		verification_interval = 0.4,
		release_delay = 1,
		filter = "civilians_enemies"
	}
end