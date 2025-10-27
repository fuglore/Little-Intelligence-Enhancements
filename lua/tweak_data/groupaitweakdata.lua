function GroupAITweakData:_LIES_setup()
	if self._LIES_fix then
		return
	end
	
	log("LIES: Initializing tweak_data...")
	local faction = tweak_data.levels:get_ai_group_type()
	self._not_america = faction ~= "america" and faction or false
	
	if LIES.settings.extra_chatter then
		tweak_data.character:_setup_extra_chatter_tweak()
	end

	if self.enemy_spawn_groups["tac_swat_shotgun_rush"] and not self._LIES_fix or not self.unit_categories["medic_M4"] and not self._LIES_fix then
		log("LIES: Another mod has already changed spawn groups and tactics. Ignoring tweakdata setup.")
		
		self._LIES_fix = true

		if LIES.settings.hhtacs then
			local difficulty = Global.game_settings and Global.game_settings.difficulty or "normal"
			local difficulty_index = tweak_data:difficulty_to_index(difficulty)
		
			log("LIES: Hyper Taktikz enabled while another mod is. Things may not work as intended...")
			
			if tweak_data.character then
				tweak_data.character:setup_hhtacs()
			end
			
			if tweak_data.weapon then
				tweak_data.weapon:setup_hhtacs()
			end
			
			if tweak_data.attention then
				tweak_data.attention:setup_hhtacs()
			end
			
			if tweak_data.levels then
				tweak_data.levels:setup_hhtacs()
			end
			
			self:_setup_hhtacs_task_data(difficulty_index)
		end
		
		return
	end

	self._tactics.tazer_flanking = { 
		"flank", --set to "flanking" in vanilla which is not an actual tactic
		"charge",
		"provide_coverfire_LIES",
		"smoke_grenade",
		"murder"
	}
	
	local difficulty = Global.game_settings and Global.game_settings.difficulty or "normal"
	local difficulty_index = tweak_data:difficulty_to_index(difficulty)
	
	if not LIES.settings.hhtacs and LIES.settings.fixed_spawngroups > 1 and not self._LIES_fix then
		log("LIES: Attempting to fix spawngroups...")
		
		if self.enemy_spawn_groups.tac_swat_shotgun_rush then
			log("LIES: Spawngroups already fixed by another mod.")
			self._LIES_fix = true
		else
			if difficulty_index == 8 then
				self.unit_categories.FBI_heavy_G36.unit_types.federales = {
					Idstring("units/pd2_dlc_bex/characters/ene_swat_heavy_policia_federale_fbi_g36/ene_swat_heavy_policia_federale_fbi_g36")
				}
			end

			if difficulty_index > 5 and difficulty_index < 8 then
				self.unit_categories.FBI_heavy_R870.unit_types.murkywater = {
					Idstring("units/pd2_dlc_bph/characters/ene_murkywater_heavy_shotgun/ene_murkywater_heavy_shotgun") --6$ srimp special
				}
			end
			
			if difficulty_index > 5 and difficulty_index < 8 then
				self.unit_categories.FBI_swat_R870.unit_types.america = {
					Idstring("units/payday2/characters/ene_city_swat_2/ene_city_swat_2")
				}
			end
			
			if difficulty_index <= 2 then
				self.enemy_spawn_groups.tac_swat_shotgun_rush = {
					amount = {
						3,
						3
					},
					spawn = {
						{
							amount_min = 2,
							freq = 1,
							amount_max = 2,
							rank = 2,
							unit = "CS_swat_R870",
							tactics = self._tactics.swat_shotgun_rush
						},
						{
							amount_min = 1,
							freq = 1,
							amount_max = 1,
							rank = 3,
							unit = "CS_heavy_R870",
							tactics = self._tactics.swat_shotgun_rush
						}
					}
				}
			elseif difficulty_index == 3 then
				self.enemy_spawn_groups.tac_swat_shotgun_rush = {
					amount = {
						4,
						4
					},
					spawn = {
						{
							amount_min = 2,
							freq = 1,
							amount_max = 2,
							rank = 2,
							unit = "CS_swat_R870",
							tactics = self._tactics.swat_shotgun_rush
						},
						{
							amount_min = 2,
							freq = 1,
							amount_max = 2,
							rank = 3,
							unit = "CS_heavy_R870",
							tactics = self._tactics.swat_shotgun_rush
						}
					}
				}
			elseif difficulty_index == 4 then
				self.enemy_spawn_groups.tac_swat_shotgun_rush = {
					amount = {
						4,
						4
					},
					spawn = {
						{
							amount_min = 3,
							freq = 1,
							amount_max = 3,
							rank = 2,
							unit = "FBI_swat_R870",
							tactics = self._tactics.swat_shotgun_rush
						},
						{
							amount_min = 1,
							freq = 1,
							amount_max = 1,
							rank = 3,
							unit = "FBI_heavy_R870",
							tactics = self._tactics.swat_shotgun_rush
						}
					}
				}
			elseif difficulty_index == 5 then
				self.enemy_spawn_groups.tac_swat_shotgun_rush = {
					amount = {
						4,
						5
					},
					spawn = {
						{
							amount_min = 2,
							freq = 2,
							amount_max = 2,
							rank = 2,
							unit = "FBI_swat_R870",
							tactics = self._tactics.swat_shotgun_rush
						},
						{
							amount_min = 2,
							freq = 2,
							amount_max = 2,
							rank = 3,
							unit = "FBI_heavy_R870",
							tactics = self._tactics.swat_shotgun_rush
						},
						{
							amount_min = 1,
							freq = 0.2,
							amount_max = 1,
							rank = 1,
							unit = "medic_R870",
							tactics = self._tactics.swat_shotgun_rush
						}
					}
				}
			elseif difficulty_index == 6 then
				self.enemy_spawn_groups.tac_swat_shotgun_rush = {
					amount = {
						4,
						5
					},
					spawn = {
						{
							amount_min = 3,
							freq = 3,
							amount_max = 3,
							rank = 2,
							unit = "FBI_swat_R870",
							tactics = self._tactics.swat_shotgun_rush
						},
						{
							amount_min = 1,
							freq = 1,
							amount_max = 1,
							rank = 3,
							unit = "FBI_heavy_R870",
							tactics = self._tactics.swat_shotgun_rush
						},
						{
							amount_min = 1,
							freq = 0.35,
							amount_max = 1,
							rank = 1,
							unit = "medic_R870",
							tactics = self._tactics.swat_shotgun_rush
						}
					}
				}
			elseif difficulty_index == 7 then
				self.enemy_spawn_groups.tac_swat_shotgun_rush = {
					amount = {
						4,
						5
					},
					spawn = {
						{
							amount_min = 2,
							freq = 2,
							amount_max = 2,
							rank = 2,
							unit = "FBI_swat_R870",
							tactics = self._tactics.swat_shotgun_rush
						},
						{
							amount_min = 2,
							freq = 2,
							amount_max = 2,
							rank = 3,
							unit = "FBI_heavy_R870",
							tactics = self._tactics.swat_shotgun_rush
						},
						{
							amount_min = 1,
							freq = 0.35,
							amount_max = 1,
							rank = 1,
							unit = "medic_R870",
							tactics = self._tactics.swat_shotgun_rush
						}
					}
				}
			else
				self.enemy_spawn_groups.tac_swat_shotgun_rush = {
					amount = {
						4,
						5
					},
					spawn = {
						{
							amount_min = 1,
							freq = 1,
							amount_max = 1,
							rank = 2,
							unit = "FBI_swat_R870",
							tactics = self._tactics.swat_shotgun_rush
						},
						{
							amount_min = 3,
							freq = 3,
							amount_max = 3,
							rank = 3,
							unit = "FBI_heavy_R870",
							tactics = self._tactics.swat_shotgun_rush
						},
						{
							amount_min = 1,
							freq = 0.35,
							amount_max = 1,
							rank = 1,
							unit = "medic_R870",
							tactics = self._tactics.swat_shotgun_rush
						}
					}
				}
			end
			
			if difficulty_index <= 2 then
				self.enemy_spawn_groups.tac_swat_shotgun_flank = {
					amount = {
						3,
						3
					},
					spawn = {
						{
							amount_min = 2,
							freq = 1,
							amount_max = 2,
							rank = 2,
							unit = "CS_swat_R870",
							tactics = self._tactics.swat_shotgun_flank
						},
						{
							amount_min = 1,
							freq = 1,
							amount_max = 1,
							rank = 3,
							unit = "CS_heavy_R870",
							tactics = self._tactics.swat_shotgun_flank
						}
					}
				}
			elseif difficulty_index == 3 then
				self.enemy_spawn_groups.tac_swat_shotgun_flank = {
					amount = {
						4,
						4
					},
					spawn = {
						{
							amount_min = 2,
							freq = 1,
							amount_max = 2,
							rank = 2,
							unit = "CS_swat_R870",
							tactics = self._tactics.swat_shotgun_flank
						},
						{
							amount_min = 2,
							freq = 1,
							amount_max = 2,
							rank = 3,
							unit = "CS_heavy_R870",
							tactics = self._tactics.swat_shotgun_flank
						}
					}
				}
			elseif difficulty_index == 4 then
				self.enemy_spawn_groups.tac_swat_shotgun_flank = {
					amount = {
						4,
						4
					},
					spawn = {
						{
							amount_min = 3,
							freq = 1,
							amount_max = 3,
							rank = 2,
							unit = "FBI_swat_R870",
							tactics = self._tactics.swat_shotgun_flank
						},
						{
							amount_min = 1,
							freq = 1,
							amount_max = 1,
							rank = 3,
							unit = "FBI_heavy_R870",
							tactics = self._tactics.swat_shotgun_flank
						}
					}
				}
			elseif difficulty_index == 5 then
				self.enemy_spawn_groups.tac_swat_shotgun_flank = {
					amount = {
						4,
						5
					},
					spawn = {
						{
							amount_min = 2,
							freq = 2,
							amount_max = 2,
							rank = 2,
							unit = "FBI_swat_R870",
							tactics = self._tactics.swat_shotgun_flank
						},
						{
							amount_min = 2,
							freq = 2,
							amount_max = 2,
							rank = 3,
							unit = "FBI_heavy_R870",
							tactics = self._tactics.swat_shotgun_flank
						},
						{
							amount_min = 0,
							freq = 0.2,
							amount_max = 1,
							rank = 1,
							unit = "medic_R870",
							tactics = self._tactics.swat_shotgun_flank
						}
					}
				}
			elseif difficulty_index == 6 then
				self.enemy_spawn_groups.tac_swat_shotgun_flank = {
					amount = {
						4,
						5
					},
					spawn = {
						{
							amount_min = 3,
							freq = 3,
							amount_max = 3,
							rank = 2,
							unit = "FBI_swat_R870",
							tactics = self._tactics.swat_shotgun_flank
						},
						{
							amount_min = 1,
							freq = 1,
							amount_max = 1,
							rank = 3,
							unit = "FBI_heavy_R870",
							tactics = self._tactics.swat_shotgun_flank
						},
						{
							amount_min = 0,
							freq = 0.35,
							amount_max = 1,
							rank = 1,
							unit = "medic_R870",
							tactics = self._tactics.swat_shotgun_flank
						}
					}
				}
			elseif difficulty_index == 7 then
				self.enemy_spawn_groups.tac_swat_shotgun_flank = {
					amount = {
						4,
						5
					},
					spawn = {
						{
							amount_min = 2,
							freq = 2,
							amount_max = 2,
							rank = 2,
							unit = "FBI_swat_R870",
							tactics = self._tactics.swat_shotgun_flank
						},
						{
							amount_min = 2,
							freq = 2,
							amount_max = 2,
							rank = 3,
							unit = "FBI_heavy_R870",
							tactics = self._tactics.swat_shotgun_flank
						},
						{
							amount_min = 0,
							freq = 0.35,
							amount_max = 1,
							rank = 1,
							unit = "medic_R870",
							tactics = self._tactics.swat_shotgun_flank
						}
					}
				}
			else
				self.enemy_spawn_groups.tac_swat_shotgun_flank = {
					amount = {
						4,
						5
					},
					spawn = {
						{
							amount_min = 1,
							freq = 1,
							amount_max = 1,
							rank = 2,
							unit = "FBI_swat_R870",
							tactics = self._tactics.swat_shotgun_flank
						},
						{
							amount_min = 3,
							freq = 3,
							amount_max = 3,
							rank = 3,
							unit = "FBI_heavy_R870",
							tactics = self._tactics.swat_shotgun_flank
						},
						{
							amount_min = 0,
							freq = 0.5,
							amount_max = 1,
							rank = 1,
							unit = "medic_R870",
							tactics = self._tactics.swat_shotgun_flank
						}
					}
				}
			end

			if difficulty_index <= 2 then
				self.enemy_spawn_groups.tac_swat_rifle = {
					amount = {
						3,
						3
					},
					spawn = {
						{
							amount_min = 2,
							freq = 1,
							amount_max = 2,
							rank = 2,
							unit = "CS_swat_MP5",
							tactics = self._tactics.swat_rifle
						},
						{
							amount_min = 1,
							freq = 1,
							amount_max = 1,
							rank = 3,
							unit = "CS_heavy_M4",
							tactics = self._tactics.swat_rifle
						}
					}
				}
			elseif difficulty_index == 3 then
				self.enemy_spawn_groups.tac_swat_rifle = {
					amount = {
						4,
						4
					},
					spawn = {
						{
							amount_min = 2,
							freq = 1,
							amount_max = 2,
							rank = 2,
							unit = "CS_swat_MP5",
							tactics = self._tactics.swat_rifle
						},
						{
							amount_min = 2,
							freq = 1,
							amount_max = 2,
							rank = 3,
							unit = "CS_heavy_M4",
							tactics = self._tactics.swat_rifle
						}
					}
				}
			elseif difficulty_index == 4 then
				self.enemy_spawn_groups.tac_swat_rifle = {
					amount = {
						4,
						4
					},
					spawn = {
						{
							amount_min = 3,
							freq = 1,
							amount_max = 3,
							rank = 2,
							unit = "FBI_swat_M4",
							tactics = self._tactics.swat_rifle
						},
						{
							amount_min = 1,
							freq = 1,
							amount_max = 1,
							rank = 3,
							unit = "FBI_heavy_G36",
							tactics = self._tactics.swat_rifle
						}
					}
				}
			elseif difficulty_index == 5 then
				self.enemy_spawn_groups.tac_swat_rifle = {
					amount = {
						4,
						5
					},
					spawn = {
						{
							amount_min = 2,
							freq = 2,
							amount_max = 2,
							rank = 2,
							unit = "FBI_swat_M4",
							tactics = self._tactics.swat_rifle
						},
						{
							amount_min = 2,
							freq = 2,
							amount_max = 2,
							rank = 3,
							unit = "FBI_heavy_G36",
							tactics = self._tactics.swat_rifle
						},
						{
							amount_min = 0,
							freq = 0.2,
							amount_max = 1,
							rank = 1,
							unit = "medic_M4",
							tactics = self._tactics.swat_rifle
						}
					}
				}
			elseif difficulty_index == 6 then
				self.enemy_spawn_groups.tac_swat_rifle = {
					amount = {
						4,
						5
					},
					spawn = {
						{
							amount_min = 3,
							freq = 3,
							amount_max = 3,
							rank = 2,
							unit = "FBI_swat_M4",
							tactics = self._tactics.swat_rifle
						},
						{
							amount_min = 1,
							freq = 1,
							amount_max = 1,
							rank = 3,
							unit = "FBI_heavy_G36",
							tactics = self._tactics.swat_rifle
						},
						{
							amount_min = 0,
							freq = 0.35,
							amount_max = 1,
							rank = 1,
							unit = "medic_M4",
							tactics = self._tactics.swat_rifle
						}
					}
				}
			elseif difficulty_index == 7 then
				self.enemy_spawn_groups.tac_swat_rifle = {
					amount = {
						4,
						5
					},
					spawn = {
						{
							amount_min = 2,
							freq = 2,
							amount_max = 2,
							rank = 2,
							unit = "FBI_swat_M4",
							tactics = self._tactics.swat_rifle
						},
						{
							amount_min = 2,
							freq = 2,
							amount_max = 2,
							rank = 3,
							unit = "FBI_heavy_G36",
							tactics = self._tactics.swat_rifle
						},
						{
							amount_min = 0,
							freq = 0.35,
							amount_max = 1,
							rank = 1,
							unit = "medic_M4",
							tactics = self._tactics.swat_rifle
						}
					}
				}
			else
				self.enemy_spawn_groups.tac_swat_rifle = {
					amount = {
						4,
						5
					},
					spawn = {
						{
							amount_min = 1,
							freq = 1,
							amount_max = 1,
							rank = 2,
							unit = "FBI_swat_M4",
							tactics = self._tactics.swat_rifle
						},
						{
							amount_min = 3,
							freq = 3,
							amount_max = 3,
							rank = 3,
							unit = "FBI_heavy_G36",
							tactics = self._tactics.swat_rifle
						},
						{
							amount_min = 0,
							freq = 0.5,
							amount_max = 1,
							rank = 1,
							unit = "medic_M4",
							tactics = self._tactics.swat_rifle
						}
					}
				}
			end
			
			if difficulty_index <= 2 then
				self.besiege.assault.groups = {
					tac_swat_shotgun_rush = {
						0.18,
						0.18,
						0.18
					},
					tac_swat_shotgun_flank = {
						0.18,
						0.18,
						0.18
					},
					tac_swat_rifle = {
						0.22,
						0.22,
						0.22
					},
					tac_swat_rifle_flank = {
						0.22,
						0.22,
						0.22
					},
					tac_shield_wall_ranged = {
						0.2,
						0.2,
						0.2
					},
					tac_shield_wall_charge = {
						0,
						0,
						0
					},
					tac_shield_wall = {
						0,
						0,
						0
					},
					tac_tazer_flanking = {
						0,
						0,
						0
					},
					tac_tazer_charge = {
						0,
						0,
						0
					},
					single_spoocs = {
						0,
						0,
						0
					},
					tac_bull_rush = {
						0,
						0,
						0
					}
				}
			elseif difficulty_index == 3 then
				self.besiege.assault.groups = {
					tac_swat_shotgun_rush = {
						0.13,
						0.13,
						0.13
					},
					tac_swat_shotgun_flank = {
						0.13,
						0.13,
						0.13
					},
					tac_swat_rifle = {
						0.15,
						0.15,
						0.15
					},
					tac_swat_rifle_flank = {
						0.15,
						0.15,
						0.15
					},
					tac_shield_wall_ranged = {
						0.1,
						0.1,
						0.1
					},
					tac_shield_wall_charge = {
						0.1,
						0.1,
						0.1
					},
					tac_shield_wall = {
						0.1,
						0.1,
						0.1
					},
					tac_tazer_flanking = {
						0.12,
						0.12,
						0.12
					},
					tac_tazer_charge = {
						0.12,
						0.12,
						0.12
					},
					single_spoocs = {
						0,
						0,
						0
					},
					tac_bull_rush = {
						0,
						0,
						0
					}
				}
			elseif difficulty_index == 4 then
				self.besiege.assault.groups = {
					tac_swat_shotgun_rush = {
						0.185,
						0.185,
						0.185
					},
					tac_swat_shotgun_flank = {
						0.185,
						0.185,
						0.185
					},
					tac_swat_rifle = {
						0.2,
						0.2,
						0.2
					},
					tac_swat_rifle_flank = {
						0.2,
						0.2,
						0.2
					},
					tac_shield_wall_ranged = {
						0.025,
						0.025,
						0.025
					},
					tac_shield_wall_charge = {
						0.025,
						0.025,
						0.025
					},
					tac_shield_wall = {
						0.025,
						0.025,
						0.025
					},
					tac_tazer_flanking = {
						0.04,
						0.04,
						0.04
					},
					tac_tazer_charge = {
						0.04,
						0.04,
						0.04
					},
					FBI_spoocs = {
						0.035,
						0.035,
						0.035
					},
					tac_bull_rush = {
						0.04,
						0.04,
						0.04
					}
				}
			elseif difficulty_index == 5 then
				self.besiege.assault.groups = {
					tac_swat_shotgun_rush = {
						0.185,
						0.185,
						0.185
					},
					tac_swat_shotgun_flank = {
						0.185,
						0.185,
						0.185
					},
					tac_swat_rifle = {
						0.2,
						0.2,
						0.2
					},
					tac_swat_rifle_flank = {
						0.2,
						0.2,
						0.2
					},
					tac_shield_wall_ranged = {
						0.025,
						0.025,
						0.025
					},
					tac_shield_wall_charge = {
						0.025,
						0.025,
						0.025
					},
					tac_shield_wall = {
						0.025,
						0.025,
						0.025
					},
					tac_tazer_flanking = {
						0.04,
						0.04,
						0.04
					},
					tac_tazer_charge = {
						0.04,
						0.04,
						0.04
					},
					FBI_spoocs = {
						0.035,
						0.035,
						0.035
					},
					tac_bull_rush = {
						0.04,
						0.04,
						0.04
					}
				}
			elseif difficulty_index == 6 then
				self.besiege.assault.groups = {
					tac_swat_shotgun_rush = {
						0.185,
						0.185,
						0.185
					},
					tac_swat_shotgun_flank = {
						0.185,
						0.185,
						0.185
					},
					tac_swat_rifle = {
						0.2,
						0.2,
						0.2
					},
					tac_swat_rifle_flank = {
						0.2,
						0.2,
						0.2
					},
					tac_shield_wall_ranged = {
						0.025,
						0.025,
						0.025
					},
					tac_shield_wall_charge = {
						0.025,
						0.025,
						0.025
					},
					tac_shield_wall = {
						0.025,
						0.025,
						0.025
					},
					tac_tazer_flanking = {
						0.04,
						0.04,
						0.04
					},
					tac_tazer_charge = {
						0.04,
						0.04,
						0.04
					},
					FBI_spoocs = {
						0.035,
						0.035,
						0.035
					},
					tac_bull_rush = {
						0.04,
						0.04,
						0.04
					}
				}
			elseif difficulty_index == 7 then
				self.besiege.assault.groups = {
					tac_swat_shotgun_rush = {
						0.185,
						0.185,
						0.185
					},
					tac_swat_shotgun_flank = {
						0.185,
						0.185,
						0.185
					},
					tac_swat_rifle = {
						0.2,
						0.2,
						0.2
					},
					tac_swat_rifle_flank = {
						0.2,
						0.2,
						0.2
					},
					tac_shield_wall_ranged = {
						0.025,
						0.025,
						0.025
					},
					tac_shield_wall_charge = {
						0.025,
						0.025,
						0.025
					},
					tac_shield_wall = {
						0.025,
						0.025,
						0.025
					},
					tac_tazer_flanking = {
						0.04,
						0.04,
						0.04
					},
					tac_tazer_charge = {
						0.04,
						0.04,
						0.04
					},
					FBI_spoocs = {
						0.035,
						0.035,
						0.035
					},
					tac_bull_rush = {
						0.04,
						0.04,
						0.04
					}
				}
			elseif difficulty_index == 8 then
				self.besiege.assault.groups = {
					tac_swat_shotgun_rush = {
						0.185,
						0.185,
						0.185
					},
					tac_swat_shotgun_flank = {
						0.185,
						0.185,
						0.185
					},
					tac_swat_rifle = {
						0.2,
						0.2,
						0.2
					},
					tac_swat_rifle_flank = {
						0.2,
						0.2,
						0.2
					},
					tac_shield_wall_ranged = {
						0.025,
						0.025,
						0.025
					},
					tac_shield_wall_charge = {
						0.025,
						0.025,
						0.025
					},
					tac_shield_wall = {
						0.025,
						0.025,
						0.025
					},
					tac_tazer_flanking = {
						0.04,
						0.04,
						0.04
					},
					tac_tazer_charge = {
						0.04,
						0.04,
						0.04
					},
					FBI_spoocs = {
						0.035,
						0.035,
						0.035
					},
					tac_bull_rush = {
						0.04,
						0.04,
						0.04
					}
				}
			else
				self.besiege.assault.groups = {
					tac_swat_shotgun_rush = {
						0.185,
						0.185,
						0.185
					},
					tac_swat_shotgun_flank = {
						0.185,
						0.185,
						0.185
					},
					tac_swat_rifle = {
						0.2,
						0.2,
						0.2
					},
					tac_swat_rifle_flank = {
						0.2,
						0.2,
						0.2
					},
					tac_shield_wall_ranged = {
						0.025,
						0.025,
						0.025
					},
					tac_shield_wall_charge = {
						0.025,
						0.025,
						0.025
					},
					tac_shield_wall = {
						0.025,
						0.025,
						0.025
					},
					tac_tazer_flanking = {
						0.04,
						0.04,
						0.04
					},
					tac_tazer_charge = {
						0.04,
						0.04,
						0.04
					},
					FBI_spoocs = {
						0.035,
						0.035,
						0.035
					},
					tac_bull_rush = {
						0.04,
						0.04,
						0.04
					}
				}
			end

			
			log("LIES: Spawngroups successfully fixed.")
			
			self._LIES_fix = true
		end
	end
	
	if LIES.settings.hhtacs then
		log("LIES: Initializing Hyper Taktikz. Poggers.")
		
		if tweak_data.character then
			tweak_data.character:setup_hhtacs()
		end
		
		if tweak_data.weapon then
			tweak_data.weapon:setup_hhtacs()
		end
		
		if tweak_data.attention then
			tweak_data.attention:setup_hhtacs()
		end
		
		if tweak_data.levels then
			tweak_data.levels:setup_hhtacs()
		end
		
		self:_setup_hhtacs_task_data(difficulty_index)
		
		self._tactics.reenforce = {
			"blockade",
			"smoke_grenade"
		}
		if difficulty_index == 8  then
			self._tactics.spooc = {
				"flank",
				"charge",
				"shield_cover",
				"smoke_grenade",
				"sabotage",
				"tackle"
			}
		else
			self._tactics.spooc = {
				"flank",
				"charge",
				"shield_cover",
				"smoke_grenade",
				"sabotage"
			}
		end
		self._tactics.shield_wall_ranged = {
			"shield",
			"ranged_fire",
			"provide_support",
			"smoke_grenade"
		}
		self._tactics.shield_wall = {
			"shield",
			"flank",
			"ranged_fire",
			"provide_support",
			"murder",
			"deathguard"
		}
		
		self._tactics.marshal_marksman = {
			"ranged_fire",
			"murder",
			"hrt",
			"sabotage",
			"sniper",
			"shield_cover"
		}
		self._tactics.marshal_shield = {
			"shield",
			"hrt",
			"sabotage",
			"charge",
			"murder"
		}
		
		if difficulty_index > 5 then
			self._tactics.swat_rifle_flank = { --this is the group ever
				"ranged_fire",
				"flank",
				"provide_coverfire_LIES",
				"provide_support",
				"smoke_grenade",
				"harass"
			}
		else
			self._tactics.swat_rifle_flank = { --this is the group ever
				"ranged_fire",
				"flank",
				"provide_coverfire_LIES",
				"provide_support",
				"smoke_grenade"
			}
		end
		
		self._tactics.tazer_charge = {
			"charge",
			"flash_grenade",
			"provide_coverfire_LIES",
			"murder"
		}
		
		if difficulty_index == 8  then
			self._tactics.hrt = {
				"hrt",
				"sabotage",
				"flank",
				"tackle"
			}
		else
			self._tactics.hrt = {
				"hrt",
				"sabotage",
				"flank"
			}
		end
		
		if difficulty_index == 8  then
			self._tactics.taser_sabo = {
				"flank",
				"charge",
				"sabotage",
				"tackle"
			}
		else
			self._tactics.taser_sabo = {
				"flank",
				"charge",
				"sabotage"
			}
		end
		
		--chad wuz here
	end
	
	--allow enemies assigned to group ai to...actually participate to group ai
	self.besiege.assault.groups.custom = {
		0,
		0,
		0
	}
	self.besiege.recon.groups.custom = {
		0,
		0,
		0
	}
	self.skirmish.assault.groups.custom = {
		0,
		0,
		0
	}
	self.skirmish.recon.groups.custom = {
		0,
		0,
		0
	}

	--spawngroup setups for spicy tacs
	if LIES.settings.hhtacs then
		self.enemy_spawn_groups.Phalanx = {
			amount = {
				self.phalanx.minions.amount + 1,
				self.phalanx.minions.amount + 1
			},
			spawn = {
				{
					amount_min = 1,
					freq = 1,
					amount_max = 1,
					rank = 1, --equal ranks so they wait for eachother
					unit = "Phalanx_vip",
					tactics = self._tactics.Phalanx_vip
				},
				{
					freq = 1,
					amount_min = 1,
					rank = 1,
					unit = "Phalanx_minion",
					tactics = self._tactics.Phalanx_minion
				}
			}
		}
	
		if difficulty_index == 6 then
			self.unit_categories.FBI_tank.unit_types.america = {
				Idstring("units/payday2/characters/ene_bulldozer_1/ene_bulldozer_1"),
				Idstring("units/payday2/characters/ene_bulldozer_2/ene_bulldozer_2"),
				Idstring("units/payday2/characters/ene_bulldozer_3/ene_bulldozer_3")
			}
			self.unit_categories.FBI_tank.unit_types.russia = {
				Idstring("units/pd2_dlc_mad/characters/ene_akan_fbi_tank_r870/ene_akan_fbi_tank_r870"),
				Idstring("units/pd2_dlc_mad/characters/ene_akan_fbi_tank_saiga/ene_akan_fbi_tank_saiga"),
				Idstring("units/pd2_dlc_mad/characters/ene_akan_fbi_tank_rpk_lmg/ene_akan_fbi_tank_rpk_lmg")
			}
			self.unit_categories.FBI_tank.unit_types.zombie = {
				Idstring("units/pd2_dlc_hvh/characters/ene_bulldozer_hvh_1/ene_bulldozer_hvh_1"),
				Idstring("units/pd2_dlc_hvh/characters/ene_bulldozer_hvh_2/ene_bulldozer_hvh_2"),
				Idstring("units/pd2_dlc_hvh/characters/ene_bulldozer_hvh_3/ene_bulldozer_hvh_3")
			}
			self.unit_categories.FBI_tank.unit_types.murkywater = {
				Idstring("units/pd2_dlc_bph/characters/ene_murkywater_bulldozer_4/ene_murkywater_bulldozer_4"),
				Idstring("units/pd2_dlc_bph/characters/ene_murkywater_bulldozer_2/ene_murkywater_bulldozer_2"),
				Idstring("units/pd2_dlc_bph/characters/ene_murkywater_bulldozer_3/ene_murkywater_bulldozer_3")
			}
			self.unit_categories.FBI_tank.unit_types.federales = {
				Idstring("units/pd2_dlc_bex/characters/ene_swat_dozer_policia_federale_r870/ene_swat_dozer_policia_federale_r870"),
				Idstring("units/pd2_dlc_bex/characters/ene_swat_dozer_policia_federale_saiga/ene_swat_dozer_policia_federale_saiga"),
				Idstring("units/pd2_dlc_bex/characters/ene_swat_dozer_policia_federale_m249/ene_swat_dozer_policia_federale_m249")
			}
		elseif difficulty_index == 7 then
			self.unit_categories.FBI_tank.unit_types.america = {
				Idstring("units/payday2/characters/ene_bulldozer_1/ene_bulldozer_1"),
				Idstring("units/payday2/characters/ene_bulldozer_2/ene_bulldozer_2"),
				Idstring("units/payday2/characters/ene_bulldozer_3/ene_bulldozer_3"),
				Idstring("units/pd2_dlc_drm/characters/ene_bulldozer_minigun_classic/ene_bulldozer_minigun_classic")
			}
			self.unit_categories.FBI_tank.unit_types.russia = {
				Idstring("units/pd2_dlc_mad/characters/ene_akan_fbi_tank_r870/ene_akan_fbi_tank_r870"),
				Idstring("units/pd2_dlc_mad/characters/ene_akan_fbi_tank_saiga/ene_akan_fbi_tank_saiga"),
				Idstring("units/pd2_dlc_mad/characters/ene_akan_fbi_tank_rpk_lmg/ene_akan_fbi_tank_rpk_lmg"),
				Idstring("units/pd2_dlc_drm/characters/ene_bulldozer_minigun_classic/ene_bulldozer_minigun_classic")
			}
			self.unit_categories.FBI_tank.unit_types.zombie = {
				Idstring("units/pd2_dlc_hvh/characters/ene_bulldozer_hvh_1/ene_bulldozer_hvh_1"),
				Idstring("units/pd2_dlc_hvh/characters/ene_bulldozer_hvh_2/ene_bulldozer_hvh_2"),
				Idstring("units/pd2_dlc_hvh/characters/ene_bulldozer_hvh_3/ene_bulldozer_hvh_3"),
				Idstring("units/pd2_dlc_drm/characters/ene_bulldozer_minigun_classic/ene_bulldozer_minigun_classic")
			}
			self.unit_categories.FBI_tank.unit_types.murkywater = {
				Idstring("units/pd2_dlc_bph/characters/ene_murkywater_bulldozer_1/ene_murkywater_bulldozer_1"),
				Idstring("units/pd2_dlc_bph/characters/ene_murkywater_bulldozer_2/ene_murkywater_bulldozer_2"),
				Idstring("units/pd2_dlc_bph/characters/ene_murkywater_bulldozer_3/ene_murkywater_bulldozer_3"),
				Idstring("units/pd2_dlc_bph/characters/ene_murkywater_bulldozer_4/ene_murkywater_bulldozer_4")
			}
			self.unit_categories.FBI_tank.unit_types.federales = {
				Idstring("units/pd2_dlc_bex/characters/ene_swat_dozer_policia_federale_r870/ene_swat_dozer_policia_federale_r870"),
				Idstring("units/pd2_dlc_bex/characters/ene_swat_dozer_policia_federale_saiga/ene_swat_dozer_policia_federale_saiga"),
				Idstring("units/pd2_dlc_bex/characters/ene_swat_dozer_policia_federale_m249/ene_swat_dozer_policia_federale_m249"),
				Idstring("units/pd2_dlc_bex/characters/ene_swat_dozer_policia_federale_minigun/ene_swat_dozer_policia_federale_minigun")
			}
		elseif difficulty_index == 8 then
			self.unit_categories.FBI_tank.unit_types.america = {
				Idstring("units/pd2_dlc_gitgud/characters/ene_zeal_bulldozer/ene_zeal_bulldozer"),
				Idstring("units/pd2_dlc_gitgud/characters/ene_zeal_bulldozer_2/ene_zeal_bulldozer_2"),
				Idstring("units/pd2_dlc_gitgud/characters/ene_zeal_bulldozer_3/ene_zeal_bulldozer_3"),
				Idstring("units/pd2_dlc_drm/characters/ene_bulldozer_medic/ene_bulldozer_medic"),
				Idstring("units/pd2_dlc_drm/characters/ene_bulldozer_minigun/ene_bulldozer_minigun")
			}
			self.unit_categories.FBI_tank.unit_types.russia = {
				Idstring("units/pd2_dlc_mad/characters/ene_akan_fbi_tank_r870/ene_akan_fbi_tank_r870"),
				Idstring("units/pd2_dlc_mad/characters/ene_akan_fbi_tank_saiga/ene_akan_fbi_tank_saiga"),
				Idstring("units/pd2_dlc_mad/characters/ene_akan_fbi_tank_rpk_lmg/ene_akan_fbi_tank_rpk_lmg"),
				Idstring("units/pd2_dlc_drm/characters/ene_bulldozer_medic/ene_bulldozer_medic"),
				Idstring("units/pd2_dlc_drm/characters/ene_bulldozer_minigun/ene_bulldozer_minigun")
			}
			self.unit_categories.FBI_tank.unit_types.zombie = {
				Idstring("units/pd2_dlc_hvh/characters/ene_bulldozer_hvh_1/ene_bulldozer_hvh_1"),
				Idstring("units/pd2_dlc_hvh/characters/ene_bulldozer_hvh_2/ene_bulldozer_hvh_2"),
				Idstring("units/pd2_dlc_hvh/characters/ene_bulldozer_hvh_3/ene_bulldozer_hvh_3"),
				Idstring("units/pd2_dlc_drm/characters/ene_bulldozer_medic/ene_bulldozer_medic"),
				Idstring("units/pd2_dlc_drm/characters/ene_bulldozer_minigun/ene_bulldozer_minigun")
			}
			self.unit_categories.FBI_tank.unit_types.murkywater = {
				Idstring("units/pd2_dlc_bph/characters/ene_murkywater_bulldozer_1/ene_murkywater_bulldozer_1"),
				Idstring("units/pd2_dlc_bph/characters/ene_murkywater_bulldozer_2/ene_murkywater_bulldozer_2"),
				Idstring("units/pd2_dlc_bph/characters/ene_murkywater_bulldozer_3/ene_murkywater_bulldozer_3"),
				Idstring("units/pd2_dlc_bph/characters/ene_murkywater_bulldozer_4/ene_murkywater_bulldozer_4"),
				Idstring("units/pd2_dlc_bph/characters/ene_murkywater_bulldozer_medic/ene_murkywater_bulldozer_medic")
			}
			self.unit_categories.FBI_tank.unit_types.federales = {
				Idstring("units/pd2_dlc_bex/characters/ene_swat_dozer_policia_federale_r870/ene_swat_dozer_policia_federale_r870"),
				Idstring("units/pd2_dlc_bex/characters/ene_swat_dozer_policia_federale_saiga/ene_swat_dozer_policia_federale_saiga"),
				Idstring("units/pd2_dlc_bex/characters/ene_swat_dozer_policia_federale_m249/ene_swat_dozer_policia_federale_m249"),
				Idstring("units/pd2_dlc_bex/characters/ene_swat_dozer_policia_federale_minigun/ene_swat_dozer_policia_federale_minigun"),
				Idstring("units/pd2_dlc_bex/characters/ene_swat_dozer_medic_policia_federale/ene_swat_dozer_medic_policia_federale")
			}
		end

		if difficulty_index == 8 then
			self.unit_categories.FBI_heavy_G36.unit_types.federales = {
				Idstring("units/pd2_dlc_bex/characters/ene_swat_heavy_policia_federale_fbi_g36/ene_swat_heavy_policia_federale_fbi_g36")
			}
		end

		if difficulty_index > 5 and difficulty_index < 8 then
			self.unit_categories.FBI_heavy_R870.unit_types.murkywater = {
				Idstring("units/pd2_dlc_bph/characters/ene_murkywater_heavy_shotgun/ene_murkywater_heavy_shotgun") --6$ srimp special
			}
		end
		
		if difficulty_index > 5 and difficulty_index < 8 then
			self.unit_categories.FBI_swat_R870.unit_types.america = {
				Idstring("units/payday2/characters/ene_city_swat_2/ene_city_swat_2")
			}
		end

		if difficulty_index <= 2 then
			self.enemy_spawn_groups.tac_swat_rifle_flank = {
				amount = {
					3,
					3
				},
				spawn = {
					{
						amount_min = 2,
						freq = 1,
						amount_max = 2,
						rank = 2,
						unit = "CS_swat_MP5",
						tactics = self._tactics.swat_rifle_flank
					},
					{
						amount_min = 1,
						freq = 1,
						amount_max = 1,
						rank = 3,
						unit = "CS_heavy_M4",
						tactics = self._tactics.swat_rifle_flank
					}
				}
			}
		elseif difficulty_index == 3 then
			self.enemy_spawn_groups.tac_swat_rifle_flank = {
				amount = {
					4,
					4
				},
				spawn = {
					{
						amount_min = 2,
						freq = 1,
						amount_max = 2,
						rank = 2,
						unit = "CS_swat_MP5",
						tactics = self._tactics.swat_rifle_flank
					},
					{
						amount_min = 2,
						freq = 1,
						amount_max = 2,
						rank = 3,
						unit = "CS_heavy_M4",
						tactics = self._tactics.swat_rifle_flank
					}
				}
			}
		elseif difficulty_index == 4 then
			self.enemy_spawn_groups.tac_swat_rifle_flank = {
				amount = {
					4,
					4
				},
				spawn = {
					{
						amount_min = 3,
						freq = 1,
						amount_max = 3,
						rank = 2,
						unit = "FBI_swat_M4",
						tactics = self._tactics.swat_rifle_flank
					},
					{
						amount_min = 1,
						freq = 1,
						amount_max = 1,
						rank = 3,
						unit = "FBI_heavy_G36",
						tactics = self._tactics.swat_rifle_flank
					}
				}
			}
		elseif difficulty_index == 5 then
			self.enemy_spawn_groups.tac_swat_rifle_flank = {
				amount = {
					4,
					5
				},
				spawn = {
					{
						amount_min = 2,
						freq = 2,
						amount_max = 2,
						rank = 2,
						unit = "FBI_swat_M4",
						tactics = self._tactics.swat_rifle_flank
					},
					{
						amount_min = 2,
						freq = 2,
						amount_max = 2,
						rank = 3,
						unit = "FBI_heavy_G36",
						tactics = self._tactics.swat_rifle_flank
					},
					{
						amount_min = 0,
						freq = 0.2,
						amount_max = 1,
						rank = 1,
						unit = "medic_M4",
						tactics = self._tactics.swat_rifle_flank
					}
				}
			}
		elseif difficulty_index == 6 then
			self.enemy_spawn_groups.tac_swat_rifle_flank = {
				amount = {
					4,
					5
				},
				spawn = {
					{
						amount_min = 3,
						freq = 3,
						amount_max = 3,
						rank = 2,
						unit = "FBI_swat_M4",
						tactics = self._tactics.swat_rifle_flank
					},
					{
						amount_min = 1,
						freq = 1,
						amount_max = 1,
						rank = 3,
						unit = "FBI_heavy_G36",
						tactics = self._tactics.swat_rifle_flank
					},
					{
						amount_min = 0,
						freq = 0.35,
						amount_max = 1,
						rank = 1,
						unit = "medic_M4",
						tactics = self._tactics.swat_rifle_flank
					}
				}
			}
		elseif difficulty_index == 7 then
			self.enemy_spawn_groups.tac_swat_rifle_flank = {
				amount = {
					4,
					5
				},
				spawn = {
					{
						amount_min = 2,
						freq = 2,
						amount_max = 2,
						rank = 2,
						unit = "FBI_swat_M4",
						tactics = self._tactics.swat_rifle_flank
					},
					{
						amount_min = 2,
						freq = 2,
						amount_max = 2,
						rank = 3,
						unit = "FBI_heavy_G36",
						tactics = self._tactics.swat_rifle_flank
					},
					{
						amount_min = 0,
						freq = 0.35,
						amount_max = 1,
						rank = 1,
						unit = "medic_M4",
						tactics = self._tactics.swat_rifle_flank
					}
				}
			}
		else
			self.enemy_spawn_groups.tac_swat_rifle_flank = {
				amount = {
					4,
					5
				},
				spawn = {
					{
						amount_min = 2,
						freq = 2,
						amount_max = 2,
						rank = 2,
						unit = "FBI_swat_M4",
						tactics = self._tactics.swat_rifle_flank
					},
					{
						amount_min = 2,
						freq = 2,
						amount_max = 2,
						rank = 3,
						unit = "FBI_heavy_G36",
						tactics = self._tactics.swat_rifle_flank
					},
					{
						amount_min = 0,
						freq = 0.35,
						amount_max = 1,
						rank = 1,
						unit = "medic_M4",
						tactics = self._tactics.swat_rifle_flank
					}
				}
			}
		end
		
		if difficulty_index <= 2 then
			self.enemy_spawn_groups.tac_shield_wall_ranged = {
				amount = {
					4,
					4
				},
				spawn = {
					{
						amount_min = 2,
						freq = 1,
						amount_max = 2,
						rank = 2,
						unit = "CS_swat_MP5",
						tactics = self._tactics.shield_support_ranged
					},
					{
						amount_min = 2,
						freq = 1,
						amount_max = 2,
						rank = 3,
						unit = "CS_shield",
						tactics = self._tactics.shield_wall_ranged
					}
				}
			}
		elseif difficulty_index == 3 then
			self.enemy_spawn_groups.tac_shield_wall_ranged = {
				amount = {
					4,
					4
				},
				spawn = {
					{
						amount_min = 2,
						freq = 1,
						amount_max = 2,
						rank = 2,
						unit = "CS_heavy_M4",
						tactics = self._tactics.shield_support_ranged
					},
					{
						amount_min = 2,
						freq = 1,
						amount_max = 2,
						rank = 3,
						unit = "CS_shield",
						tactics = self._tactics.shield_wall_ranged
					}
				}
			}
		elseif difficulty_index == 4 then
			self.enemy_spawn_groups.tac_shield_wall_ranged = {
				amount = {
					4,
					4
				},
				spawn = {
					{
						amount_min = 2,
						freq = 1,
						amount_max = 2,
						rank = 2,
						unit = "FBI_swat_M4",
						tactics = self._tactics.shield_support_ranged
					},
					{
						amount_min = 2,
						freq = 1,
						amount_max = 2,
						rank = 3,
						unit = "FBI_shield",
						tactics = self._tactics.shield_wall_ranged
					}
				}
			}
		elseif difficulty_index == 5 then
			self.enemy_spawn_groups.tac_shield_wall_ranged = {
				amount = {
					4,
					5
				},
				spawn = {
					{
						amount_min = 1,
						freq = 1,
						amount_max = 1,
						rank = 2,
						unit = "FBI_swat_M4",
						tactics = self._tactics.shield_support_ranged
					},
					{
						amount_min = 1,
						freq = 2,
						amount_max = 1,
						rank = 2,
						unit = "FBI_heavy_G36",
						tactics = self._tactics.shield_support_ranged
					},
					{
						amount_min = 2,
						freq = 2,
						amount_max = 2,
						rank = 3,
						unit = "FBI_shield",
						tactics = self._tactics.shield_wall_ranged
					},
					{
						amount_min = 0,
						freq = 0.2,
						amount_max = 1,
						rank = 1,
						unit = "medic_M4",
						tactics = self._tactics.shield_support_ranged
					}
				}
			}
		elseif difficulty_index == 6 then
			self.enemy_spawn_groups.tac_shield_wall_ranged = {
				amount = {
					4,
					5
				},
				spawn = {
					{
						amount_min = 1,
						freq = 1,
						amount_max = 1,
						rank = 2,
						unit = "FBI_swat_M4",
						tactics = self._tactics.shield_support_ranged
					},
					{
						amount_min = 1,
						freq = 2,
						amount_max = 1,
						rank = 2,
						unit = "FBI_heavy_G36",
						tactics = self._tactics.shield_support_ranged
					},
					{
						amount_min = 2,
						freq = 2,
						amount_max = 2,
						rank = 3,
						unit = "FBI_shield",
						tactics = self._tactics.shield_wall_ranged
					},
					{
						amount_min = 0,
						freq = 0.35,
						amount_max = 1,
						rank = 1,
						unit = "medic_M4",
						tactics = self._tactics.shield_support_ranged
					}
				}
			}
		elseif difficulty_index == 7 then
			self.enemy_spawn_groups.tac_shield_wall_ranged = {
				amount = {
					4,
					5
				},
				spawn = {
					{
						amount_min = 1,
						freq = 1,
						amount_max = 1,
						rank = 2,
						unit = "FBI_swat_M4",
						tactics = self._tactics.shield_support_ranged
					},
					{
						amount_min = 1,
						freq = 2,
						amount_max = 1,
						rank = 2,
						unit = "FBI_heavy_G36",
						tactics = self._tactics.shield_support_ranged
					},
					{
						amount_min = 2,
						freq = 2,
						amount_max = 2,
						rank = 3,
						unit = "FBI_shield",
						tactics = self._tactics.shield_wall_ranged
					},
					{
						amount_min = 0,
						freq = 0.35,
						amount_max = 1,
						rank = 1,
						unit = "medic_M4",
						tactics = self._tactics.shield_support_ranged
					}
				}
			}
		else
			self.enemy_spawn_groups.tac_shield_wall_ranged = {
				amount = {
					4,
					5
				},
				spawn = {
					{
						amount_min = 1,
						freq = 1,
						amount_max = 1,
						rank = 2,
						unit = "FBI_swat_M4",
						tactics = self._tactics.shield_support_ranged
					},
					{
						amount_min = 1,
						freq = 2,
						amount_max = 1,
						rank = 2,
						unit = "FBI_heavy_G36",
						tactics = self._tactics.shield_support_ranged
					},
					{
						amount_min = 2,
						freq = 2,
						amount_max = 2,
						rank = 3,
						unit = "FBI_shield",
						tactics = self._tactics.shield_wall_ranged
					},
					{
						amount_min = 0,
						freq = 0.5,
						amount_max = 1,
						rank = 1,
						unit = "medic_M4",
						tactics = self._tactics.shield_support_ranged
					}
				}
			}
		end

		if difficulty_index <= 2 then
			self.enemy_spawn_groups.tac_shield_wall_charge = {
				amount = {
					4,
					4
				},
				spawn = {
					{
						amount_min = 2,
						freq = 1,
						amount_max = 2,
						rank = 2,
						unit = "CS_swat_R870",
						tactics = self._tactics.shield_support_charge
					},
					{
						amount_min = 2,
						freq = 1,
						amount_max = 2,
						rank = 3,
						unit = "CS_shield",
						tactics = self._tactics.shield_wall_charge
					}
				}
			}
		elseif difficulty_index == 3 then
			self.enemy_spawn_groups.tac_shield_wall_charge = {
				amount = {
					4,
					4
				},
				spawn = {
					{
						amount_min = 2,
						freq = 1,
						amount_max = 2,
						rank = 2,
						unit = "CS_heavy_R870",
						tactics = self._tactics.shield_support_charge
					},
					{
						amount_min = 2,
						freq = 1,
						amount_max = 2,
						rank = 3,
						unit = "CS_shield",
						tactics = self._tactics.shield_wall_charge
					}
				}
			}
		elseif difficulty_index == 4 then
			self.enemy_spawn_groups.tac_shield_wall_charge = {
				amount = {
					4,
					4
				},
				spawn = {
					{
						amount_min = 2,
						freq = 1,
						amount_max = 2,
						rank = 2,
						unit = "FBI_swat_R870",
						tactics = self._tactics.shield_support_charge
					},
					{
						amount_min = 2,
						freq = 1,
						amount_max = 2,
						rank = 3,
						unit = "FBI_shield",
						tactics = self._tactics.shield_wall_charge
					}
				}
			}
		elseif difficulty_index == 5 then
			self.enemy_spawn_groups.tac_shield_wall_charge = {
				amount = {
					4,
					5
				},
				spawn = {
					{
						amount_min = 1,
						freq = 1,
						amount_max = 1,
						rank = 2,
						unit = "FBI_swat_R870",
						tactics = self._tactics.shield_support_charge
					},
					{
						amount_min = 1,
						freq = 1,
						amount_max = 1,
						rank = 2,
						unit = "FBI_heavy_R870",
						tactics = self._tactics.shield_support_charge
					},
					{
						amount_min = 2,
						freq = 2,
						amount_max = 2,
						rank = 3,
						unit = "FBI_shield",
						tactics = self._tactics.shield_wall_charge
					},
					{
						amount_min = 0,
						freq = 0.2,
						amount_max = 1,
						rank = 1,
						unit = "medic_R870",
						tactics = self._tactics.shield_support_charge
					}
				}
			}
		elseif difficulty_index == 6 then
			self.enemy_spawn_groups.tac_shield_wall_charge = {
				amount = {
					4,
					5
				},
				spawn = {
					{
						amount_min = 1,
						freq = 1,
						amount_max = 1,
						rank = 2,
						unit = "FBI_swat_R870",
						tactics = self._tactics.shield_support_charge
					},
					{
						amount_min = 1,
						freq = 1,
						amount_max = 1,
						rank = 2,
						unit = "FBI_heavy_R870",
						tactics = self._tactics.shield_support_charge
					},
					{
						amount_min = 2,
						freq = 2,
						amount_max = 2,
						rank = 3,
						unit = "FBI_shield",
						tactics = self._tactics.shield_wall_charge
					},
					{
						amount_min = 0,
						freq = 0.35,
						amount_max = 1,
						rank = 1,
						unit = "medic_R870",
						tactics = self._tactics.shield_support_charge
					}
				}
			}
		elseif difficulty_index == 7 then
			self.enemy_spawn_groups.tac_shield_wall_charge = {
				amount = {
					4,
					5
				},
				spawn = {
					{
						amount_min = 1,
						freq = 1,
						amount_max = 1,
						rank = 2,
						unit = "FBI_swat_R870",
						tactics = self._tactics.shield_support_charge
					},
					{
						amount_min = 1,
						freq = 1,
						amount_max = 1,
						rank = 2,
						unit = "FBI_heavy_R870",
						tactics = self._tactics.shield_support_charge
					},
					{
						amount_min = 2,
						freq = 2,
						amount_max = 2,
						rank = 3,
						unit = "FBI_shield",
						tactics = self._tactics.shield_wall_charge
					},
					{
						amount_min = 0,
						freq = 0.35,
						amount_max = 1,
						rank = 1,
						unit = "medic_R870",
						tactics = self._tactics.shield_support_charge
					}
				}
			}
		else
			self.enemy_spawn_groups.tac_shield_wall_charge = {
				amount = {
					4,
					5
				},
				spawn = {
					{
						amount_min = 1,
						freq = 1,
						amount_max = 1,
						rank = 2,
						unit = "FBI_swat_R870",
						tactics = self._tactics.shield_support_charge
					},
					{
						amount_min = 1,
						freq = 1,
						amount_max = 1,
						rank = 2,
						unit = "FBI_heavy_R870",
						tactics = self._tactics.shield_support_charge
					},
					{
						amount_min = 2,
						freq = 2,
						amount_max = 2,
						rank = 3,
						unit = "FBI_shield",
						tactics = self._tactics.shield_wall_charge
					},
					{
						amount_min = 0,
						freq = 0.5,
						amount_max = 1,
						rank = 1,
						unit = "medic_R870",
						tactics = self._tactics.shield_support_charge
					}
				}
			}
		end
		
		if difficulty_index <= 2 then
			self.enemy_spawn_groups.tac_tazer_flanking = {
				amount = {
					1,
					1
				},
				spawn = {
					{
						amount_min = 1,
						freq = 1,
						amount_max = 1,
						rank = 3,
						unit = "CS_tazer",
						tactics = self._tactics.tazer_flanking
					}
				}
			}
		elseif difficulty_index == 3 then
			self.enemy_spawn_groups.tac_tazer_flanking = {
				amount = {
					1,
					1
				},
				spawn = {
					{
						amount_min = 1,
						freq = 1,
						amount_max = 1,
						rank = 3,
						unit = "CS_tazer",
						tactics = self._tactics.tazer_flanking
					}
				}
			}
		elseif difficulty_index == 4 then
			self.enemy_spawn_groups.tac_tazer_flanking = {
				amount = {
					1,
					1
				},
				spawn = {
					{
						amount_min = 1,
						freq = 1,
						amount_max = 1,
						rank = 3,
						unit = "CS_tazer",
						tactics = self._tactics.tazer_flanking
					}
				}
			}
		elseif difficulty_index == 5 then
			self.enemy_spawn_groups.tac_tazer_flanking = {
				amount = {
					1,
					1
				},
				spawn = {
					{
						amount_min = 1,
						freq = 1,
						amount_max = 1,
						rank = 3,
						unit = "CS_tazer",
						tactics = self._tactics.tazer_flanking
					}
				}
			}
		elseif difficulty_index == 6 then
			self.enemy_spawn_groups.tac_tazer_flanking = {
				amount = {
					1,
					1
				},
				spawn = {
					{
						amount_min = 1,
						freq = 1,
						amount_max = 1,
						rank = 3,
						unit = "CS_tazer",
						tactics = self._tactics.tazer_flanking
					}
				}
			}
		else
			self.enemy_spawn_groups.tac_tazer_flanking = {
				amount = {
					5,
					5
				},
				spawn = {
					{
						amount_min = 1,
						freq = 1,
						amount_max = 1,
						rank = 3,
						unit = "CS_tazer",
						tactics = self._tactics.tazer_flanking
					},
					{
						amount_min = 2,
						freq = 1,
						amount_max = 2,
						rank = 1,
						unit = "FBI_swat_M4",
						tactics = self._tactics.tazer_flanking
					},
					{
						amount_min = 2,
						freq = 3,
						amount_max = 2,
						rank = 2,
						unit = "FBI_heavy_G36",
						tactics = self._tactics.tazer_flanking
					}
				}
			}
		end
	
		if difficulty_index <= 2 then
			self.enemy_spawn_groups.tac_tazer_charge = {
				amount = {
					1,
					1
				},
				spawn = {
					{
						amount_min = 1,
						freq = 1,
						amount_max = 1,
						rank = 3,
						unit = "CS_tazer",
						tactics = self._tactics.tazer_charge
					}
				}
			}
		elseif difficulty_index == 3 then
			self.enemy_spawn_groups.tac_tazer_charge = {
				amount = {
					1,
					1
				},
				spawn = {
					{
						amount_min = 1,
						freq = 1,
						amount_max = 1,
						rank = 3,
						unit = "CS_tazer",
						tactics = self._tactics.tazer_charge
					}
				}
			}
		elseif difficulty_index == 4 then
			self.enemy_spawn_groups.tac_tazer_charge = {
				amount = {
					1,
					1
				},
				spawn = {
					{
						amount_min = 1,
						freq = 1,
						amount_max = 1,
						rank = 3,
						unit = "CS_tazer",
						tactics = self._tactics.tazer_charge
					}
				}
			}
		elseif difficulty_index == 5 then
			self.enemy_spawn_groups.tac_tazer_charge = {
				amount = {
					1,
					1
				},
				spawn = {
					{
						amount_min = 1,
						freq = 1,
						amount_max = 1,
						rank = 3,
						unit = "CS_tazer",
						tactics = self._tactics.tazer_charge
					}
				}
			}
		elseif difficulty_index == 6 then
			self.enemy_spawn_groups.tac_tazer_charge = {
				amount = {
					1,
					1
				},
				spawn = {
					{
						amount_min = 1,
						freq = 1,
						amount_max = 1,
						rank = 3,
						unit = "CS_tazer",
						tactics = self._tactics.tazer_charge
					}
				}
			}
		else
			self.enemy_spawn_groups.tac_tazer_charge = {
				amount = {
					6,
					6
				},
				spawn = {
					{
						amount_min = 1,
						freq = 1,
						amount_max = 1,
						rank = 3,
						unit = "CS_tazer",
						tactics = self._tactics.tazer_charge
					},
					{
						amount_min = 2,
						freq = 1,
						amount_max = 2,
						rank = 1,
						unit = "FBI_swat_M4",
						tactics = self._tactics.tazer_charge
					},
					{
						amount_min = 2,
						freq = 3,
						amount_max = 2,
						rank = 2,
						unit = "FBI_heavy_G36",
						tactics = self._tactics.tazer_charge
					}
				}
			}
		end
		
		if difficulty_index <= 2 then
			self.enemy_spawn_groups.tac_bull_rush = {
				amount = {
					1,
					1
				},
				spawn = {
					{
						amount_min = 1,
						freq = 1,
						amount_max = 1,
						rank = 3,
						unit = "FBI_tank",
						tactics = self._tactics.tank_rush
					}
				}
			}
		elseif difficulty_index == 3 then
			self.enemy_spawn_groups.tac_bull_rush = {
				amount = {
					1,
					1
				},
				spawn = {
					{
						amount_min = 1,
						freq = 1,
						amount_max = 1,
						rank = 3,
						unit = "FBI_tank",
						tactics = self._tactics.tank_rush
					}
				}
			}
		elseif difficulty_index == 4 then
			self.enemy_spawn_groups.tac_bull_rush = {
				amount = {
					1,
					1
				},
				spawn = {
					{
						amount_min = 1,
						freq = 1,
						amount_max = 1,
						rank = 3,
						unit = "FBI_tank",
						tactics = self._tactics.tank_rush
					}
				}
			}
		elseif difficulty_index == 5 then
			self.enemy_spawn_groups.tac_bull_rush = {
				amount = {
					1,
					1
				},
				spawn = {
					{
						amount_min = 1,
						freq = 1,
						amount_max = 1,
						rank = 3,
						unit = "FBI_tank",
						tactics = self._tactics.tank_rush
					}
				}
			}
		elseif difficulty_index == 6 then
			self.enemy_spawn_groups.tac_bull_rush = {
				amount = {
					1,
					1
				},
				spawn = {
					{
						amount_min = 1,
						freq = 1,
						amount_max = 1,
						rank = 3,
						unit = "FBI_tank",
						tactics = self._tactics.tank_rush
					}
				}
			}
		else
			self.enemy_spawn_groups.tac_bull_rush = {
				amount = {
					4,
					4
				},
				spawn = {
					{
						amount_min = 1,
						freq = 1,
						amount_max = 2,
						rank = 3,
						unit = "FBI_tank",
						tactics = self._tactics.tank_rush
					},
					{
						amount_min = 1,
						freq = 1,
						amount_max = 2,
						rank = 1,
						unit = "FBI_swat_R870",
						tactics = self._tactics.tank_rush
					},
					{
						amount_min = 1,
						freq = 1,
						amount_max = 2,
						rank = 2,
						unit = "FBI_heavy_R870",
						tactics = self._tactics.tank_rush
					}
				}
			}
		end
		
		local access_type_all = {
			acrobatic = true,
			walk = true
		}
		self.unit_categories.phalanx_pusher = {
			unit_types = {
				america = {
					Idstring("units/pd2_dlc_vip/characters/ene_phalanx_1/ene_phalanx_1")
				},
				russia = {
					Idstring("units/pd2_dlc_vip/characters/ene_phalanx_1/ene_phalanx_1")
				},
				zombie = {
					Idstring("units/pd2_dlc_vip/characters/ene_phalanx_1/ene_phalanx_1")
				},
				murkywater = {
					Idstring("units/pd2_dlc_vip/characters/ene_phalanx_1/ene_phalanx_1")
				},
				federales = {
					Idstring("units/pd2_dlc_vip/characters/ene_phalanx_1/ene_phalanx_1")
				}
			},
			access = access_type_all
		}
		
		self.enemy_spawn_groups.phalanx_aggressors = {
			amount = {
				2,
				2
			},
			spawn = {
				{
					amount_min = 2,
					amount_max = 2,
					rank = 2,
					freq = 1,
					access = "swat",
					unit = "phalanx_pusher",
					tactics = self._tactics.tank_rush
				}
			},
			spawn_point_chk_ref = table.list_to_set({
				"Phalanx",
				"tac_bull_rush"
			})
		}
		
		local actually_finished_factions = {
			america = true,
			zombie = true,
			russia = true
		}
		
		self.unit_categories.FBI_office = {
			unit_types = {
				america = {
					Idstring("units/payday2/characters/ene_fbi_office_1/ene_fbi_office_1"),
					Idstring("units/payday2/characters/ene_fbi_office_2/ene_fbi_office_2"),
					Idstring("units/payday2/characters/ene_fbi_office_3/ene_fbi_office_3"),
					Idstring("units/payday2/characters/ene_fbi_office_4/ene_fbi_office_4"),
					Idstring("units/payday2/characters/ene_fbi_female_1/ene_fbi_female_1"),
					Idstring("units/payday2/characters/ene_fbi_female_2/ene_fbi_female_2"),
					Idstring("units/payday2/characters/ene_fbi_female_3/ene_fbi_female_3"),
					Idstring("units/payday2/characters/ene_fbi_female_4/ene_fbi_female_4")
				},
				russia = {
					Idstring("units/payday2/characters/ene_fbi_office_1/ene_fbi_office_1"),
					Idstring("units/payday2/characters/ene_fbi_office_2/ene_fbi_office_2"),
					Idstring("units/payday2/characters/ene_fbi_office_3/ene_fbi_office_3"),
					Idstring("units/payday2/characters/ene_fbi_office_4/ene_fbi_office_4"),
					Idstring("units/payday2/characters/ene_fbi_female_1/ene_fbi_female_1"),
					Idstring("units/payday2/characters/ene_fbi_female_2/ene_fbi_female_2"),
					Idstring("units/payday2/characters/ene_fbi_female_3/ene_fbi_female_3"),
					Idstring("units/payday2/characters/ene_fbi_female_4/ene_fbi_female_4")
				},
				zombie = {
					Idstring("units/payday2/characters/ene_fbi_office_1/ene_fbi_office_1"),
					Idstring("units/payday2/characters/ene_fbi_office_2/ene_fbi_office_2"),
					Idstring("units/payday2/characters/ene_fbi_office_3/ene_fbi_office_3"),
					Idstring("units/payday2/characters/ene_fbi_office_4/ene_fbi_office_4"),
					Idstring("units/payday2/characters/ene_fbi_female_1/ene_fbi_female_1"),
					Idstring("units/payday2/characters/ene_fbi_female_2/ene_fbi_female_2"),
					Idstring("units/payday2/characters/ene_fbi_female_3/ene_fbi_female_3"),
					Idstring("units/payday2/characters/ene_fbi_female_4/ene_fbi_female_4")
				},
				murkywater = {
					Idstring("units/payday2/characters/ene_fbi_office_1/ene_fbi_office_1"),
					Idstring("units/payday2/characters/ene_fbi_office_2/ene_fbi_office_2"),
					Idstring("units/payday2/characters/ene_fbi_office_3/ene_fbi_office_3"),
					Idstring("units/payday2/characters/ene_fbi_office_4/ene_fbi_office_4"),
					Idstring("units/payday2/characters/ene_fbi_female_1/ene_fbi_female_1"),
					Idstring("units/payday2/characters/ene_fbi_female_2/ene_fbi_female_2"),
					Idstring("units/payday2/characters/ene_fbi_female_3/ene_fbi_female_3"),
					Idstring("units/payday2/characters/ene_fbi_female_4/ene_fbi_female_4")
				},
				federales = {
					Idstring("units/payday2/characters/ene_fbi_office_1/ene_fbi_office_1"),
					Idstring("units/payday2/characters/ene_fbi_office_2/ene_fbi_office_2"),
					Idstring("units/payday2/characters/ene_fbi_office_3/ene_fbi_office_3"),
					Idstring("units/payday2/characters/ene_fbi_office_4/ene_fbi_office_4"),
					Idstring("units/payday2/characters/ene_fbi_female_1/ene_fbi_female_1"),
					Idstring("units/payday2/characters/ene_fbi_female_2/ene_fbi_female_2"),
					Idstring("units/payday2/characters/ene_fbi_female_3/ene_fbi_female_3"),
					Idstring("units/payday2/characters/ene_fbi_female_4/ene_fbi_female_4")
				}
			},
			access = access_type_all
		}
		
		self.unit_categories.MKWTR_mercs = {
			unit_types = {
				america = {
					Idstring("units/payday2/characters/ene_murkywater_1/ene_murkywater_1"),
					Idstring("units/payday2/characters/ene_murkywater_2/ene_murkywater_2")
				},
				russia = {
					Idstring("units/payday2/characters/ene_murkywater_1/ene_murkywater_1"),
					Idstring("units/payday2/characters/ene_murkywater_2/ene_murkywater_2")
				},
				zombie = {
					Idstring("units/payday2/characters/ene_murkywater_1/ene_murkywater_1"),
					Idstring("units/payday2/characters/ene_murkywater_2/ene_murkywater_2")
				},
				murkywater = {
					Idstring("units/payday2/characters/ene_murkywater_1/ene_murkywater_1"),
					Idstring("units/payday2/characters/ene_murkywater_2/ene_murkywater_2")
				},
				federales = {
					Idstring("units/payday2/characters/ene_murkywater_1/ene_murkywater_1"),
					Idstring("units/payday2/characters/ene_murkywater_2/ene_murkywater_2")
				}
			},
			access = access_type_all
		}
		
		self.unit_categories.ranc_rangers = {
			unit_types = {
				america = {
					Idstring("units/pd2_dlc_ranc/characters/ene_male_ranc_ranger_01/ene_male_ranc_ranger_01"),
					Idstring("units/pd2_dlc_ranc/characters/ene_male_ranc_ranger_02/ene_male_ranc_ranger_02")
				},
				russia = {
					Idstring("units/pd2_dlc_ranc/characters/ene_male_ranc_ranger_01/ene_male_ranc_ranger_01"),
					Idstring("units/pd2_dlc_ranc/characters/ene_male_ranc_ranger_02/ene_male_ranc_ranger_02")
				},
				zombie = {
					Idstring("units/pd2_dlc_ranc/characters/ene_male_ranc_ranger_01/ene_male_ranc_ranger_01"),
					Idstring("units/pd2_dlc_ranc/characters/ene_male_ranc_ranger_02/ene_male_ranc_ranger_02")
				},
				murkywater = {
					Idstring("units/pd2_dlc_ranc/characters/ene_male_ranc_ranger_01/ene_male_ranc_ranger_01"),
					Idstring("units/pd2_dlc_ranc/characters/ene_male_ranc_ranger_02/ene_male_ranc_ranger_02")
				},
				federales = {
					Idstring("units/pd2_dlc_ranc/characters/ene_male_ranc_ranger_01/ene_male_ranc_ranger_01"),
					Idstring("units/pd2_dlc_ranc/characters/ene_male_ranc_ranger_02/ene_male_ranc_ranger_02")
				}
			},
			access = access_type_all
		}
		
		self.unit_categories.CS_fbi_all = {
			unit_types = {
				america = {
					Idstring("units/payday2/characters/ene_fbi_1/ene_fbi_1"),
					Idstring("units/payday2/characters/ene_fbi_2/ene_fbi_2"),
					Idstring("units/payday2/characters/ene_fbi_3/ene_fbi_3")
				},
				russia = {
					Idstring("units/pd2_dlc_mad/characters/ene_akan_cs_cop_asval_smg/ene_akan_cs_cop_asval_smg"),
					Idstring("units/pd2_dlc_mad/characters/ene_akan_cs_cop_r870/ene_akan_cs_cop_r870"),
					Idstring("units/pd2_dlc_mad/characters/ene_akan_cs_cop_ak47_ass/ene_akan_cs_cop_ak47_ass")
				},
				zombie = {
					Idstring("units/pd2_dlc_hvh/characters/ene_fbi_hvh_1/ene_fbi_hvh_1"),
					Idstring("units/pd2_dlc_hvh/characters/ene_fbi_hvh_2/ene_fbi_hvh_2"),
					Idstring("units/pd2_dlc_hvh/characters/ene_fbi_hvh_3/ene_fbi_hvh_3")
				},
				murkywater = {
					Idstring("units/payday2/characters/ene_fbi_1/ene_fbi_1"),
					Idstring("units/payday2/characters/ene_fbi_2/ene_fbi_2"),
					Idstring("units/payday2/characters/ene_fbi_3/ene_fbi_3")
				},
				federales = {
					Idstring("units/payday2/characters/ene_fbi_1/ene_fbi_1"),
					Idstring("units/payday2/characters/ene_fbi_2/ene_fbi_2"),
					Idstring("units/payday2/characters/ene_fbi_3/ene_fbi_3")
				}
			},
			access = access_type_all
		}
		
		self.unit_categories.CS_cop_all = {
			unit_types = {
				america = {
					Idstring("units/payday2/characters/ene_cop_1/ene_cop_1"),
					Idstring("units/payday2/characters/ene_cop_2/ene_cop_2"),
					Idstring("units/payday2/characters/ene_cop_3/ene_cop_3"),
					Idstring("units/payday2/characters/ene_cop_4/ene_cop_4")
				},
				russia = {
					Idstring("units/pd2_dlc_mad/characters/ene_akan_cs_cop_asval_smg/ene_akan_cs_cop_asval_smg"),
					Idstring("units/pd2_dlc_mad/characters/ene_akan_cs_cop_r870/ene_akan_cs_cop_r870"),
					Idstring("units/pd2_dlc_mad/characters/ene_akan_cs_cop_akmsu_smg/ene_akan_cs_cop_akmsu_smg"),
					Idstring("units/pd2_dlc_mad/characters/ene_akan_cs_cop_ak47_ass/ene_akan_cs_cop_ak47_ass")
				},
				zombie = {
					Idstring("units/pd2_dlc_hvh/characters/ene_cop_hvh_1/ene_cop_hvh_1"),
					Idstring("units/pd2_dlc_hvh/characters/ene_cop_hvh_2/ene_cop_hvh_2"),
					Idstring("units/pd2_dlc_hvh/characters/ene_cop_hvh_3/ene_cop_hvh_3"),
					Idstring("units/pd2_dlc_hvh/characters/ene_cop_hvh_4/ene_cop_hvh_4")
				},
				murkywater = {
					Idstring("units/payday2/characters/ene_cop_1/ene_cop_1"),
					Idstring("units/payday2/characters/ene_cop_2/ene_cop_2"),
					Idstring("units/payday2/characters/ene_cop_3/ene_cop_3"),
					Idstring("units/payday2/characters/ene_cop_4/ene_cop_4")
				},
				federales = {
					Idstring("units/payday2/characters/ene_cop_1/ene_cop_1"),
					Idstring("units/payday2/characters/ene_cop_2/ene_cop_2"),
					Idstring("units/payday2/characters/ene_cop_3/ene_cop_3"),
					Idstring("units/payday2/characters/ene_cop_4/ene_cop_4")
				}
			},
			access = access_type_all
		}
		
		self.unit_categories.tank_refless = clone(self.unit_categories.FBI_tank)
		self.unit_categories.tank_refless.special_type = nil

		self.unit_categories.tank_r870 = {
			unit_types = {
				america = {
					Idstring("units/payday2/characters/ene_bulldozer_1/ene_bulldozer_1")
				},
				russia = {
					Idstring("units/pd2_dlc_mad/characters/ene_akan_fbi_tank_r870/ene_akan_fbi_tank_r870")
				},
				zombie = {
					Idstring("units/pd2_dlc_hvh/characters/ene_bulldozer_hvh_1/ene_bulldozer_hvh_1")
				},
				murkywater = {
					Idstring("units/pd2_dlc_bph/characters/ene_murkywater_bulldozer_2/ene_murkywater_bulldozer_2")
				},
				federales = {
					Idstring("units/pd2_dlc_bex/characters/ene_swat_dozer_policia_federale_r870/ene_swat_dozer_policia_federale_r870")
				}
			},
			access = access_type_all
		}
		
		if difficulty_index < 5 then
			self.unit_categories.tank_diff_specific = {
				unit_types = {
					america = {
						Idstring("units/payday2/characters/ene_bulldozer_1/ene_bulldozer_1")
					},
					russia = {
						Idstring("units/pd2_dlc_mad/characters/ene_akan_fbi_tank_r870/ene_akan_fbi_tank_r870")
					},
					zombie = {
						Idstring("units/pd2_dlc_hvh/characters/ene_bulldozer_hvh_1/ene_bulldozer_hvh_1")
					},
					murkywater = {
						Idstring("units/pd2_dlc_bph/characters/ene_murkywater_bulldozer_2/ene_murkywater_bulldozer_2")
					},
					federales = {
						Idstring("units/pd2_dlc_bex/characters/ene_swat_dozer_policia_federale_r870/ene_swat_dozer_policia_federale_r870")
					}
				},
				access = access_type_all
			}
		elseif difficulty_index < 6 then
			self.unit_categories.tank_diff_specific = {
				unit_types = {
					america = {
						Idstring("units/payday2/characters/ene_bulldozer_2/ene_bulldozer_2")
					},
					russia = {
						Idstring("units/pd2_dlc_mad/characters/ene_akan_fbi_tank_saiga/ene_akan_fbi_tank_saiga")
					},
					zombie = {
						Idstring("units/pd2_dlc_hvh/characters/ene_bulldozer_hvh_2/ene_bulldozer_hvh_2")
					},
					murkywater = {
						Idstring("units/pd2_dlc_bph/characters/ene_murkywater_bulldozer_3/ene_murkywater_bulldozer_3")
					},
					federales = {
						Idstring("units/pd2_dlc_bex/characters/ene_swat_dozer_policia_federale_saiga/ene_swat_dozer_policia_federale_saiga")
					}
				},
				access = access_type_all
			}
		elseif difficulty_index < 7 then
			self.unit_categories.tank_diff_specific = {
				unit_types = {
					america = {
						Idstring("units/payday2/characters/ene_bulldozer_3/ene_bulldozer_3")
					},
					russia = {
						Idstring("units/pd2_dlc_mad/characters/ene_akan_fbi_tank_rpk_lmg/ene_akan_fbi_tank_rpk_lmg")
					},
					zombie = {
						Idstring("units/pd2_dlc_hvh/characters/ene_bulldozer_hvh_3/ene_bulldozer_hvh_3")
					},
					murkywater = {
						Idstring("units/pd2_dlc_bph/characters/ene_murkywater_bulldozer_4/ene_murkywater_bulldozer_4")
					},
					federales = {
						Idstring("units/pd2_dlc_bex/characters/ene_swat_dozer_policia_federale_m249/ene_swat_dozer_policia_federale_m249")
					}
				},
				access = access_type_all
			}
		elseif difficulty_index < 8 then
			self.unit_categories.tank_diff_specific = {
				unit_types = {
					america = {
						Idstring("units/pd2_dlc_drm/characters/ene_bulldozer_minigun_classic/ene_bulldozer_minigun_classic")
					},
					russia = {
						Idstring("units/pd2_dlc_drm/characters/ene_bulldozer_minigun_classic/ene_bulldozer_minigun_classic")
					},
					zombie = {
						Idstring("units/pd2_dlc_drm/characters/ene_bulldozer_minigun_classic/ene_bulldozer_minigun_classic")
					},
					murkywater = {
						Idstring("units/pd2_dlc_bph/characters/ene_murkywater_bulldozer_1/ene_murkywater_bulldozer_1")
					},
					federales = {
						Idstring("units/pd2_dlc_bex/characters/ene_swat_dozer_policia_federale_minigun/ene_swat_dozer_policia_federale_minigun")
					}
				},
				access = access_type_all
			}
		else
			self.unit_categories.tank_diff_specific = {
				unit_types = {
					america = {
						Idstring("units/pd2_dlc_drm/characters/ene_bulldozer_medic/ene_bulldozer_medic")
					},
					russia = {
						Idstring("units/pd2_dlc_drm/characters/ene_bulldozer_medic/ene_bulldozer_medic")
					},
					zombie = {
						Idstring("units/pd2_dlc_drm/characters/ene_bulldozer_medic/ene_bulldozer_medic")
					},
					murkywater = {
						Idstring("units/pd2_dlc_bph/characters/ene_murkywater_bulldozer_medic/ene_murkywater_bulldozer_medic")
					},
					federales = {
						Idstring("units/pd2_dlc_bex/characters/ene_swat_dozer_medic_policia_federale/ene_swat_dozer_medic_policia_federale")
					}
				},
				access = access_type_all
			}
		end
		
		self.unit_categories.spooc_refless = clone(self.unit_categories.spooc)
		self.unit_categories.spooc_refless.special_type = nil
		
		self.unit_categories.taser_refless = clone(self.unit_categories.CS_tazer)
		self.unit_categories.taser_refless.special_type = nil
		
		self.unit_categories.medic_m4_refless = clone(self.unit_categories.medic_M4)
		self.unit_categories.medic_m4_refless.special_type = nil
		
		self.unit_categories.medic_shot_refless = clone(self.unit_categories.medic_R870)
		self.unit_categories.medic_shot_refless.special_type = nil
		
		local level_id = Global.level_data and Global.level_data.level_id ~= nil and Global.level_data.level_id or Global.game_settings and Global.game_settings.level_id ~= nil and Global.game_settings.level_id
		local lvl_tweak_data = tweak_data.levels[level_id]

		if self.enemy_spawn_groups.marshal_squad then
			if lvl_tweak_data.ai_marshal_spawns_fast then
				self.enemy_spawn_groups.marshal_squad = {
					spawn_cooldown = 60,
					max_nr_simultaneous_groups = 2,
					initial_spawn_delay = 90,
					amount = {
						2,
						3
					},
					spawn = {
						{
							respawn_cooldown = 30,
							amount_min = 1,
							amount_max = 1,
							rank = 2,
							freq = 1,
							unit = "marshal_shield",
							tactics = self._tactics.marshal_marksman
						},
						{
							respawn_cooldown = 30,
							amount_min = 1,
							rank = 1,
							freq = 1,
							unit = "marshal_marksman",
							tactics = self._tactics.marshal_marksman
						}
					},
					spawn_point_chk_ref = table.list_to_set({
						"tac_shield_wall",
						"tac_shield_wall_ranged",
						"tac_shield_wall_charge"
					})
				}
			else
				self.enemy_spawn_groups.marshal_squad = {
					spawn_cooldown = 60,
					max_nr_simultaneous_groups = 2,
					initial_spawn_delay = 90,
					amount = {
						2,
						3
					},
					spawn = {
						{
							respawn_cooldown = 30,
							amount_min = 1,
							amount_max = 1,
							rank = 2,
							freq = 1,
							unit = "marshal_shield",
							tactics = self._tactics.marshal_marksman
						},
						{
							respawn_cooldown = 30,
							amount_min = 1,
							rank = 1,
							freq = 1,
							unit = "marshal_marksman",
							tactics = self._tactics.marshal_marksman
						}
					},
					spawn_point_chk_ref = table.list_to_set({
						"tac_shield_wall",
						"tac_shield_wall_ranged",
						"tac_shield_wall_charge"
					})
				}
				
				if difficulty_index > 5 then
					self.enemy_spawn_groups.marshal_squad.spawn_cooldown = 60
					self.enemy_spawn_groups.marshal_squad.initial_spawn_delay = 150
				end
			end
		end
		
		self.skirmish.assault.groups.marshal_squad = {
			0,
			0,
			0
		}
		self.skirmish.recon.groups.marshal_squad = {
			0,
			0,
			0
		}
		
		if difficulty_index < 4 then
			self.enemy_spawn_groups.tac_reenforce = {
				amount = {
					4,
					4
				},
				spawn = {
					{
						freq = 1,
						amount_max = 2,
						rank = 2,
						unit = "CS_swat_MP5",
						tactics = self._tactics.reenforce
					}
				},
				spawn_point_chk_ref = table.list_to_set({
					"tac_swat_rifle_flank",
					"tac_swat_rifle"
				})
			}
		elseif difficulty_index < 6 then
			self.enemy_spawn_groups.tac_reenforce = {
				amount = {
					4,
					4
				},
				spawn = {
					{
						freq = 1,
						amount_max = 2,
						rank = 2,
						unit = "CS_swat_MP5",
						tactics = self._tactics.reenforce
					},
					{
						freq = 1,
						amount_max = 2,
						rank = 3,
						unit = "CS_heavy_M4_w",
						tactics = self._tactics.reenforce
					}
				},
				spawn_point_chk_ref = table.list_to_set({
					"tac_swat_rifle_flank",
					"tac_swat_rifle"
				})
			}
		else
			if difficulty_index < 8 then
				self.unit_categories.FBI_reenforce = {
					unit_types = {
						america = {
							Idstring("units/payday2/characters/ene_fbi_swat_1/ene_fbi_swat_1")
						},
						russia = {
							Idstring("units/pd2_dlc_mad/characters/ene_akan_fbi_swat_ak47_ass/ene_akan_fbi_swat_ak47_ass")
						},
						zombie = {
							Idstring("units/pd2_dlc_hvh/characters/ene_fbi_swat_hvh_1/ene_fbi_swat_hvh_1")
						},
						murkywater = {
							Idstring("units/pd2_dlc_bph/characters/ene_murkywater_light_fbi/ene_murkywater_light_fbi")
						},
						federales = {
							Idstring("units/pd2_dlc_bex/characters/ene_swat_policia_federale_fbi/ene_swat_policia_federale_fbi")
						}
					},
					access = access_type_all
				}
				self.unit_categories.FBI_reenforce_heavy = {
					unit_types = {
						america = {
							Idstring("units/payday2/characters/ene_fbi_heavy_1/ene_fbi_heavy_1")
						},
						russia = {
							Idstring("units/pd2_dlc_mad/characters/ene_akan_fbi_heavy_g36/ene_akan_fbi_heavy_g36")
						},
						zombie = {
							Idstring("units/pd2_dlc_hvh/characters/ene_fbi_heavy_hvh_1/ene_fbi_heavy_hvh_1")
						},
						murkywater = {
							Idstring("units/pd2_dlc_bph/characters/ene_murkywater_heavy/ene_murkywater_heavy")
						},
						federales = {
							Idstring("units/pd2_dlc_bex/characters/ene_swat_heavy_policia_federale_fbi_g36/ene_swat_heavy_policia_federale_fbi_g36")
						}
					},
					access = access_type_all
				}
			else
				self.unit_categories.FBI_reenforce = {
					unit_types = {
						america = {
							Idstring("units/payday2/characters/ene_city_swat_3/ene_city_swat_3")
						},
						russia = {
							Idstring("units/pd2_dlc_mad/characters/ene_akan_fbi_swat_dw_ak47_ass/ene_akan_fbi_swat_dw_ak47_ass")
						},
						zombie = {
							Idstring("units/pd2_dlc_hvh/characters/ene_fbi_swat_hvh_1/ene_fbi_swat_hvh_1")
						},
						murkywater = {
							Idstring("units/pd2_dlc_bph/characters/ene_murkywater_light_city/ene_murkywater_light_city")
						},
						federales = {
							Idstring("units/pd2_dlc_bex/characters/ene_swat_policia_federale_city/ene_swat_policia_federale_city")
						}
					},
					access = access_type_all
				}
				
				self.unit_categories.FBI_reenforce_heavy = {
					unit_types = {
						america = {
							Idstring("units/payday2/characters/ene_city_heavy_g36/ene_city_heavy_g36")
						},
						russia = {
							Idstring("units/pd2_dlc_mad/characters/ene_akan_fbi_heavy_g36/ene_akan_fbi_heavy_g36")
						},
						zombie = {
							Idstring("units/pd2_dlc_hvh/characters/ene_fbi_heavy_hvh_1/ene_fbi_heavy_hvh_1")
						},
						murkywater = {
							Idstring("units/pd2_dlc_bph/characters/ene_murkywater_heavy_g36/ene_murkywater_heavy_g36")
						},
						federales = {
							Idstring("units/pd2_dlc_bex/characters/ene_swat_heavy_policia_federale_fbi_g36/ene_swat_heavy_policia_federale_fbi_g36")
						}
					},
					access = access_type_all
				}
			end
		
			self.enemy_spawn_groups.tac_reenforce = {
				amount = {
					4,
					4
				},
				spawn = {
					{
						freq = 1,
						amount_min = 1,
						amount_max = 4,
						rank = 2,
						unit = "FBI_reenforce",
						tactics = self._tactics.reenforce
					},
					{
						freq = 1,
						amount_max = 2,
						rank = 3,
						unit = "FBI_reenforce_heavy",
						tactics = self._tactics.reenforce
					}
				},
				spawn_point_chk_ref = table.list_to_set({
					"tac_swat_rifle_flank",
					"tac_swat_rifle"
				})
			}
		end
		
		self.besiege.assault.groups.tac_reenforce = {
			0,
			0,
			0
		}
		self.besiege.recon.groups.tac_reenforce = {
			0,
			0,
			0
		}
		
		self.besiege.reenforce.interval = {
			10,
			10,
			10
		}
		self.besiege.reenforce.groups = {
			tac_reenforce = {
				1,
				1,
				1
			}
		}
		
		if level_id == "run" or level_id == "glace" then
			self.enemy_spawn_groups.tac_reenforce.initial_spawn_delay = 10
			self.enemy_spawn_groups.tac_reenforce.spawn_cooldown = 30
			self.enemy_spawn_groups.tac_reenforce.max_nr_simultaneous_groups = 4
			
			for i = 1, #self.enemy_spawn_groups.tac_reenforce.spawn do
				local spawn_info = self.enemy_spawn_groups.tac_reenforce.spawn[i]
				
				spawn_info.respawn_cooldown = 15
			end
		end
		
		if level_id == "ranc" then
			self.enemy_spawn_groups.Cowboys = {
				spawn_cooldown = 30,
				max_nr_simultaneous_groups = 2,
				initial_spawn_delay = 10,
				amount = {
					2,
					3
				},
				spawn = {
					{
						respawn_cooldown = 20,
						amount_min = 2,
						access = "swat",
						rank = 1,
						freq = 1,
						unit = "ranc_rangers",
						tactics = self._tactics.hrt
					}
				},
				spawn_point_chk_ref = table.list_to_set({
					"tac_swat_rifle_flank",
					"tac_swat_rifle"
				})
			}
			
			self.besiege.assault.groups.Cowboys = {
				0,
				0,
				0
			}
			self.besiege.recon.groups.Cowboys = {
				0,
				0,
				0
			}

			if difficulty_index > 5 then
				if self.enemy_spawn_groups.Cowboys then
					self.enemy_spawn_groups.Cowboys.initial_spawn_delay = 10
					self.enemy_spawn_groups.Cowboys.max_nr_simultaneous_groups = 3
				end
			end
		elseif level_id == "firestarter_1" or level_id == "firestarter_2" or level_id == "firestarter_3" or level_id == "hox_3" then
			self.enemy_spawn_groups.CS_cops = {
				spawn_cooldown = 30,
				max_nr_simultaneous_groups = 2,
				initial_spawn_delay = 10,
				amount = {
					2,
					4
				},
				spawn = {
					{
						respawn_cooldown = 20,
						amount_min = 2,
						rank = 1,
						freq = 1,
						access = "swat",
						unit = "CS_fbi_all",
						tactics = self._tactics.hrt
					}
				},
				spawn_point_chk_ref = table.list_to_set({
					"tac_swat_rifle_flank",
					"tac_swat_rifle"
				})
			}
			
			self.besiege.assault.groups.CS_cops = {
				0,
				0,
				0
			}
			self.besiege.recon.groups.CS_cops = {
				0,
				0,
				0
			}
				
			if difficulty_index > 5 then
				if self.enemy_spawn_groups.CS_cops then
					self.enemy_spawn_groups.CS_cops.initial_spawn_delay = 10
					self.enemy_spawn_groups.CS_cops.max_nr_simultaneous_groups = 3
				end
			
				self.enemy_spawn_groups.spoocs_145 = { --the power rangers insta-down squad
					spawn_cooldown = 240,
					max_nr_simultaneous_groups = 1,
					initial_spawn_delay = 180,
					amount = {
						2,
						2
					},
					spawn = {
						{
							respawn_cooldown = 120,
							amount_min = 2,
							rank = 1,
							freq = 1,
							unit = "spooc_refless",
							tactics = self._tactics.spooc
						}
					},
					spawn_point_chk_ref = table.list_to_set({
						"single_spooc"
					})
				}
				
				self.besiege.assault.groups.spoocs_145 = {
					0,
					0,
					0
				}
				self.besiege.recon.groups.spoocs_145 = {
					0,
					0,
					0
				}
			end
		elseif level_id == "hox_2" then
			self.enemy_spawn_groups.FBI_office_agents = {
				spawn_cooldown = 60,
				max_nr_simultaneous_groups = 3,
				initial_spawn_delay = 30,
				amount = {
					2,
					4
				},
				spawn = {
					{
						respawn_cooldown = 30,
						amount_min = 2,
						rank = 1,
						freq = 1,
						unit = "CS_fbi_all",
						tactics = self._tactics.hrt
					},
					{
						respawn_cooldown = 30,
						amount_min = 0,
						amount_max = 2,
						rank = 1,
						freq = 1,
						unit = "FBI_office",
						tactics = self._tactics.hrt
					}
				},
				spawn_point_chk_ref = table.list_to_set({
					"tac_swat_rifle_flank",
					"tac_swat_rifle"
				})
			}
			
			self.besiege.assault.groups.FBI_office_agents = {
				0,
				0,
				0
			}
			self.besiege.recon.groups.FBI_office_agents = {
				0,
				0,
				0
			}
			
			if difficulty_index > 5 then
				self.enemy_spawn_groups.FBI_office_agents.spawn_cooldown = 45
				self.enemy_spawn_groups.FBI_office_agents.initial_spawn_delay = 10
				self.enemy_spawn_groups.FBI_office_agents.spawn[1].respawn_cooldown = 15
				self.enemy_spawn_groups.FBI_office_agents.spawn[2].respawn_cooldown = 15
				
				self.enemy_spawn_groups.CS_swat_taser_tac = {
					spawn_cooldown = 60,
					max_nr_simultaneous_groups = 2,
					initial_spawn_delay = 120,
					amount = {
						2,
						4
					},
					spawn = {
						{
							respawn_cooldown = 15,
							amount_min = 1,
							rank = 1,
							freq = 1,
							unit = "CS_swat_MP5",
							tactics = self._tactics.taser_sabo
						},
						{
							respawn_cooldown = 15,
							amount_min = 1,
							rank = 1,
							freq = 1,
							unit = "CS_swat_R870",
							tactics = self._tactics.taser_sabo
						},
						{
							respawn_cooldown = 30,
							amount_min = 1,
							rank = 2,
							freq = 1,
							unit = "taser_refless",
							tactics = self._tactics.taser_sabo
						}
					},
					spawn_point_chk_ref = table.list_to_set({
						"tac_tazer_charge",
						"tac_tazer_flanking"
					})
				}
				
				self.besiege.assault.groups.CS_swat_taser_tac = {
					0,
					0,
					0
				}
				self.besiege.recon.groups.CS_swat_taser_tac = {
					0,
					0,
					0
				}
			end
		elseif level_id == "nmh" or level_id == "election_day_3" or level_id == "election_day_3_skip1" then
			self.enemy_spawn_groups.CS_cops = {
				spawn_cooldown = 30,
				max_nr_simultaneous_groups = 2,
				initial_spawn_delay = 10,
				amount = {
					2,
					4
				},
				spawn = {
					{
						respawn_cooldown = 20,
						amount_min = 2,
						rank = 1,
						freq = 1,
						access = "swat",
						unit = "CS_cop_all",
						tactics = self._tactics.hrt
					}
				},
				spawn_point_chk_ref = table.list_to_set({
					"tac_swat_rifle_flank",
					"tac_swat_rifle"
				})
			}
			
			self.besiege.assault.groups.CS_cops = {
				0,
				0,
				0
			}
			self.besiege.recon.groups.CS_cops = {
				0,
				0,
				0
			}
			
			if difficulty_index > 5 then
				self.enemy_spawn_groups.CS_cops.initial_spawn_delay = 10
				self.enemy_spawn_groups.CS_cops.max_nr_simultaneous_groups = 3
				self.enemy_spawn_groups.CS_cops.spawn = {
					{
						respawn_cooldown = 10,
						amount_min = 2,
						rank = 1,
						freq = 1,
						access = "swat",
						unit = "CS_fbi_all",
						tactics = self._tactics.hrt
					}
				}
				
				self.enemy_spawn_groups.bulls_on_parade = {
					spawn_cooldown = 240,
					max_nr_simultaneous_groups = 1,
					initial_spawn_delay = 180,
					amount = {
						4,
						4
					},
					spawn = {
						{
							respawn_cooldown = 120,
							amount_min = 4,
							amount_max = 4,
							rank = 2,
							freq = 1,
							unit = "tank_r870",
							tactics = self._tactics.tank_rush
						}
					},
					spawn_point_chk_ref = table.list_to_set({
						"tac_bull_rush"
					})
				}
				
				self.besiege.assault.groups.bulls_on_parade = {
					0,
					0,
					0
				}
				self.besiege.recon.groups.bulls_on_parade = {
					0,
					0,
					0
				}
			end
		elseif level_id == "dinner" then
			self.enemy_spawn_groups.Murkies = {
				spawn_cooldown = 60,
				max_nr_simultaneous_groups = 3,
				initial_spawn_delay = 30,
				amount = {
					2,
					4
				},
				spawn = {
					{
						respawn_cooldown = 30,
						amount_min = 2,
						amount_max = 4,
						rank = 1,
						freq = 1,
						unit = "MKWTR_mercs",
						tactics = self._tactics.swat_rifle
					}
				},
				spawn_point_chk_ref = table.list_to_set({
					"tac_swat_rifle_flank",
					"tac_swat_rifle"
				})
			}
			
			self.besiege.assault.groups.Murkies = {
				0,
				0,
				0
			}
			self.besiege.recon.groups.Murkies = {
				0,
				0,
				0
			}
			
			if difficulty_index > 5 then
				self.enemy_spawn_groups.Murkies.initial_spawn_delay = 15
				self.enemy_spawn_groups.Murkies.spawn_cooldown = 45

				self.enemy_spawn_groups.FBI_tank_and_backup = {
					spawn_cooldown = 60,
					max_nr_simultaneous_groups = 1,
					initial_spawn_delay = 120,
					amount = {
						2,
						2
					},
					spawn = {
						{
							respawn_cooldown = 60,
							amount_min = 1,
							amount_max = 1,
							rank = 2,
							freq = 1,
							unit = "tank_diff_specific",
							tactics = self._tactics.tank_rush
						},
						{
							respawn_cooldown = 15,
							rank = 1,
							freq = 0.5,
							unit = "medic_shot_refless",
							tactics = self._tactics.tank_rush
						},
						{
							respawn_cooldown = 15,
							rank = 1,
							freq = 0.5,
							unit = "medic_m4_refless",
							tactics = self._tactics.tank_rush
						}
					},
					spawn_point_chk_ref = table.list_to_set({
						"tac_bull_rush"
					})
				}
				
				self.besiege.assault.groups.FBI_tank_and_backup = {
					0,
					0,
					0
				}
				self.besiege.recon.groups.FBI_tank_and_backup = {
					0,
					0,
					0
				}
			end
		elseif level_id == "red2" or level_id == "man" then
			self.enemy_spawn_groups.FBI_infil = {
				spawn_cooldown = 30,
				max_nr_simultaneous_groups = 3,
				initial_spawn_delay = 10,
				amount = {
					2,
					3
				},
				spawn = {
					{
						respawn_cooldown = 10,
						amount_min = 2,
						rank = 1,
						freq = 1,
						unit = "CS_fbi_all",
						tactics = self._tactics.hrt
					}
				},
				spawn_point_chk_ref = table.list_to_set({
					"tac_swat_rifle_flank",
					"tac_swat_rifle"
				})
			}
			
			self.besiege.assault.groups.FBI_infil = {
				0,
				0,
				0
			}
			self.besiege.recon.groups.FBI_infil = {
				0,
				0,
				0
			}
		
			if difficulty_index > 5 then
				self.enemy_spawn_groups.FBI_infil.initial_spawn_delay = 10
				
				self.enemy_spawn_groups.spoocs_145 = { --the power rangers insta-down squad
					spawn_cooldown = 240,
					max_nr_simultaneous_groups = 1,
					initial_spawn_delay = 180,
					amount = {
						2,
						2
					},
					spawn = {
						{
							respawn_cooldown = 120,
							amount_min = 2,
							rank = 1,
							freq = 1,
							unit = "spooc_refless",
							tactics = self._tactics.spooc
						}
					},
					spawn_point_chk_ref = table.list_to_set({
						"single_spooc"
					})
				}
				
				self.besiege.assault.groups.spoocs_145 = {
					0,
					0,
					0
				}
				self.besiege.recon.groups.spoocs_145 = {
					0,
					0,
					0
				}
			end
		elseif not managers.skirmish:is_skirmish() then
			if actually_finished_factions[faction] then
				self.enemy_spawn_groups.CS_cops = {
					spawn_cooldown = 30,
					max_nr_simultaneous_groups = 2,
					initial_spawn_delay = 10,
					amount = {
						2,
						4
					},
					spawn = {
						{
							respawn_cooldown = 20,
							amount_min = 2,
							rank = 1,
							freq = 1,
							access = "swat",
							unit = "CS_cop_all",
							tactics = self._tactics.hrt
						}
					},
					spawn_point_chk_ref = table.list_to_set({
						"tac_swat_rifle_flank",
						"tac_swat_rifle"
					})
				}
				
				self.besiege.assault.groups.CS_cops = {
					0,
					0,
					0
				}
				self.besiege.recon.groups.CS_cops = {
					0,
					0,
					0
				}
			else
				self._tactics.tazer_flanking = { 
					"flank", --set to "flanking" in vanilla which is not an actual tactic
					"charge",
					"provide_coverfire_LIES",
					"smoke_grenade",
					"murder",
					"sabotage"
				}
				self._tactics.smg = {
					"flank",
					"smoke_grenade",
					"flash_grenade",
					"sabotage"
				}
			end
		
			if difficulty_index > 5 then
				if self.enemy_spawn_groups.CS_cops then
					self.enemy_spawn_groups.CS_cops.initial_spawn_delay = 10
					self.enemy_spawn_groups.CS_cops.max_nr_simultaneous_groups = 3
					self.enemy_spawn_groups.CS_cops.spawn = {
						{
							respawn_cooldown = 10,
							amount_min = 2,
							rank = 1,
							freq = 1,
							access = "swat",
							unit = "CS_fbi_all",
							tactics = self._tactics.hrt
						}
					}
				end
				
				
				local group = math.random(1, 3)
				
				if group == 1 then
					self.enemy_spawn_groups.FBI_tank_and_backup = {
						spawn_cooldown = 60,
						max_nr_simultaneous_groups = 1,
						initial_spawn_delay = 120,
						amount = {
							2,
							2
						},
						spawn = {
							{
								respawn_cooldown = 60,
								amount_min = 1,
								amount_max = 1,
								rank = 2,
								freq = 1,
								unit = "tank_diff_specific",
								tactics = self._tactics.tank_rush
							},
							{
								respawn_cooldown = 15,
								rank = 1,
								freq = 0.5,
								unit = "medic_shot_refless",
								tactics = self._tactics.tank_rush
							},
							{
								respawn_cooldown = 15,
								rank = 1,
								freq = 0.5,
								unit = "medic_m4_refless",
								tactics = self._tactics.tank_rush
							}
						},
						spawn_point_chk_ref = table.list_to_set({
							"tac_bull_rush"
						})
					}
					
					self.besiege.assault.groups.FBI_tank_and_backup = {
						0,
						0,
						0
					}
					self.besiege.recon.groups.FBI_tank_and_backup = {
						0,
						0,
						0
					}
				elseif group == 2 then
					self.enemy_spawn_groups.CS_swat_taser_tac = {
						spawn_cooldown = 60,
						max_nr_simultaneous_groups = 2,
						initial_spawn_delay = 120,
						amount = {
							2,
							4
						},
						spawn = {
							{
								respawn_cooldown = 15,
								amount_min = 1,
								rank = 1,
								freq = 1,
								unit = "CS_swat_MP5",
								tactics = self._tactics.taser_sabo
							},
							{
								respawn_cooldown = 15,
								amount_min = 1,
								rank = 1,
								freq = 1,
								unit = "CS_swat_R870",
								tactics = self._tactics.taser_sabo
							},
							{
								respawn_cooldown = 30,
								amount_min = 1,
								rank = 2,
								freq = 1,
								unit = "taser_refless",
								tactics = self._tactics.taser_sabo
							}
						},
						spawn_point_chk_ref = table.list_to_set({
							"tac_tazer_charge",
							"tac_tazer_flanking"
						})
					}
					
					self.besiege.assault.groups.CS_swat_taser_tac = {
						0,
						0,
						0
					}
					self.besiege.recon.groups.CS_swat_taser_tac = {
						0,
						0,
						0
					}
				else
					self.enemy_spawn_groups.spoocs_145 = { --the power rangers insta-down squad
						spawn_cooldown = 240,
						max_nr_simultaneous_groups = 1,
						initial_spawn_delay = 180,
						amount = {
							2,
							2
						},
						spawn = {
							{
								respawn_cooldown = 120,
								amount_min = 2,
								rank = 1,
								freq = 1,
								unit = "spooc_refless",
								tactics = self._tactics.spooc
							}
						},
						spawn_point_chk_ref = table.list_to_set({
							"single_spooc"
						})
					}
					
					self.besiege.assault.groups.spoocs_145 = {
						0,
						0,
						0
					}
					self.besiege.recon.groups.spoocs_145 = {
						0,
						0,
						0
					}
				end
			end
		end
		
		if not self._tactics.smg then
			self._tactics.smg = {
				"flank",
				"smoke_grenade",
				"flash_grenade"
			}
		end
	
		if difficulty_index <= 2 then
			self.enemy_spawn_groups.tac_swat_smg = {
				amount = {
					2,
					2
				},
				spawn = {
					{
						amount_min = 2,
						freq = 1,
						amount_max = 2,
						rank = 2,
						unit = "CS_swat_MP5",
						tactics = self._tactics.smg
					}
				},
				spawn_point_chk_ref = table.list_to_set({
					"tac_swat_rifle_flank",
					"tac_swat_rifle"
				})
			}
		elseif difficulty_index == 3 then
			self.enemy_spawn_groups.tac_swat_smg = {
				amount = {
					2,
					2
				},
				spawn = {
					{
						amount_min = 1,
						freq = 1,
						amount_max = 1,
						rank = 2,
						unit = "CS_swat_MP5",
						tactics = self._tactics.smg
					},
					{
						amount_min = 1,
						freq = 1,
						amount_max = 1,
						rank = 2,
						unit = "CS_heavy_M4",
						tactics = self._tactics.smg
					}
				},
				spawn_point_chk_ref = table.list_to_set({
					"tac_swat_rifle_flank",
					"tac_swat_rifle"
				})
			}
		elseif difficulty_index == 4 then
			self.enemy_spawn_groups.tac_swat_smg = {
				amount = {
					2,
					2
				},
				spawn = {
					{
						amount_min = 1,
						freq = 1.75,
						amount_max = 2,
						rank = 2,
						unit = "FBI_swat_M4",
						tactics = self._tactics.smg
					},
					{
						freq = 0.25,
						amount_max = 1,
						rank = 2,
						unit = "FBI_swat_R870",
						tactics = self._tactics.smg
					},
					{
						freq = 0.25,
						amount_max = 1,
						rank = 3,
						unit = "FBI_heavy_G36",
						tactics = self._tactics.smg
					}
				},
				spawn_point_chk_ref = table.list_to_set({
					"tac_swat_rifle_flank",
					"tac_swat_rifle"
				})
			}
		elseif difficulty_index == 5 then
			self.enemy_spawn_groups.tac_swat_smg = {
				amount = {
					2,
					3
				},
				spawn = {
					{
						freq = 1.25,
						amount_max = 2,
						rank = 2,
						unit = "FBI_swat_M4",
						tactics = self._tactics.smg
					},
					{
						freq = 0.75,
						amount_max = 1,
						rank = 2,
						unit = "FBI_swat_R870",
						tactics = self._tactics.smg
					},
					{
						freq = 0.75,
						amount_max = 1,
						rank = 3,
						unit = "FBI_heavy_G36",
						tactics = self._tactics.smg
					}
				},
				spawn_point_chk_ref = table.list_to_set({
					"tac_swat_rifle_flank",
					"tac_swat_rifle"
				})
			}
		elseif difficulty_index <= 7 then
			self.unit_categories.FBI_SMG = { --use city_swat_3
				unit_types = {
					america = {
						Idstring("units/payday2/characters/ene_city_swat_3/ene_city_swat_3")
					},
					russia = {
						Idstring("units/pd2_dlc_mad/characters/ene_akan_fbi_swat_dw_ak47_ass/ene_akan_fbi_swat_dw_ak47_ass")
					},
					zombie = {
						Idstring("units/pd2_dlc_hvh/characters/ene_fbi_swat_hvh_1/ene_fbi_swat_hvh_1")
					},
					murkywater = {
						Idstring("units/pd2_dlc_bph/characters/ene_murkywater_light_city/ene_murkywater_light_city")
					},
					federales = {
						Idstring("units/pd2_dlc_bex/characters/ene_swat_policia_federale_city/ene_swat_policia_federale_city")
					}
				},
				access = access_type_all
			}
			
			if difficulty_index == 7 then
				self._tactics.smg = {
					"flank",
					"charge",
					"smoke_grenade",
					"flash_grenade"
				}
			end
		
			self.enemy_spawn_groups.tac_swat_smg = {
				amount = {
					3,
					4
				},
				spawn = {
					{
						amount_min = 1,
						freq = 1,
						amount_max = 1,
						rank = 2,
						unit = "FBI_SMG",
						tactics = self._tactics.smg
					},
					{
						freq = 0.34,
						amount_max = 1,
						rank = 2,
						unit = "FBI_swat_R870",
						tactics = self._tactics.smg
					},
					{
						freq = 0.33,
						amount_max = 1,
						rank = 3,
						unit = "FBI_heavy_G36",
						tactics = self._tactics.smg
					},
					{
						freq = 0.33,
						amount_max = 1,
						rank = 3,
						unit = "FBI_heavy_R870",
						tactics = self._tactics.smg
					}
				},
				spawn_point_chk_ref = table.list_to_set({
					"tac_swat_rifle_flank",
					"tac_swat_rifle"
				})
			}
		else
			if difficulty_index == 7 then
				self._tactics.smg = {
					"flank",
					"charge",
					"smoke_grenade",
					"flash_grenade"
				}
			end
		
			self.enemy_spawn_groups.tac_swat_smg = {
				amount = {
					3,
					4
				},
				spawn = {
					{
						freq = 1,
						amount_max = 2,
						rank = 2,
						unit = "FBI_swat_M4",
						tactics = self._tactics.smg
					},
					{
						freq = 1,
						amount_max = 2,
						rank = 2,
						unit = "FBI_swat_R870",
						tactics = self._tactics.smg
					},
					{
						freq = 0.75,
						amount_max = 1,
						rank = 3,
						unit = "FBI_heavy_G36",
						tactics = self._tactics.smg
					},
					{
						freq = 0.75,
						amount_max = 1,
						rank = 3,
						unit = "FBI_heavy_R870",
						tactics = self._tactics.smg
					}
				},
				spawn_point_chk_ref = table.list_to_set({
					"tac_swat_rifle_flank",
					"tac_swat_rifle"
				})
			}
		end
		
		if difficulty_index <= 2 then
			self.besiege.assault.groups.tac_swat_smg = {
				0.2,
				0.2,
				0.2
			}
			self.besiege.assault.groups.tac_swat_rifle_flank = {
				0.6,
				0.6,
				0.6
			}
		elseif difficulty_index == 3 then
			self.besiege.assault.groups.tac_swat_smg = {
				0.125,
				0.125,
				0.125
			}
			self.besiege.assault.groups.tac_swat_rifle_flank = {
				0.375,
				0.375,
				0.375
			}
		elseif difficulty_index == 4 then
			local weight_smg = 0.77 / 3 --im not doing this fucking math die
			local weight_rifle = 0.77 - weight_smg
			self.besiege.assault.groups.tac_swat_rifle_flank = {
				weight_rifle,
				weight_rifle,
				weight_rifle
			}
			self.besiege.assault.groups.tac_swat_smg = {
				weight_smg,
				weight_smg,
				weight_smg
			}
		elseif difficulty_index == 5 then
			local weight_smg = 0.77 / 3 --im not doing this fucking math die
			local weight_rifle = 0.77 - weight_smg
			self.besiege.assault.groups.tac_swat_rifle_flank = {
				weight_rifle,
				weight_rifle,
				weight_rifle
			}
			self.besiege.assault.groups.tac_swat_smg = {
				weight_smg,
				weight_smg,
				weight_smg
			}
		elseif difficulty_index == 6 then
			self.besiege.assault.groups.tac_swat_rifle_flank = {
				0.24,
				0.24,
				0.24
			}
			self.besiege.assault.groups.tac_swat_smg = {
				0.48,
				0.48,
				0.48,
			}
		elseif difficulty_index == 7 then
			self.besiege.assault.groups.tac_swat_rifle_flank = {
				0.24,
				0.24,
				0.24
			}
			self.besiege.assault.groups.tac_swat_smg = {
				0.48,
				0.48,
				0.48,
			}
		elseif difficulty_index == 8 then
			self.besiege.assault.groups.tac_swat_rifle_flank = {
				0.24,
				0.24,
				0.24
			}
			self.besiege.assault.groups.tac_swat_smg = {
				0.48,
				0.48,
				0.48,
			}
		else
			local weight_smg = 0.52 / 3
			local weight_rifle = 0.52 - weight_smg
			self.besiege.assault.groups.tac_swat_rifle_flank = {
				weight_rifle,
				weight_rifle,
				weight_rifle
			}
			self.besiege.assault.groups.tac_swat_smg = {
				weight_smg,
				weight_smg,
				weight_smg
			}
		end

		local cartel_heists = { 
			constantine_dwtd_lvl = true,
			constantine_suburbia_lvl = true,
			constantine_train_lvl = true,
			constantine_jungle_lvl = true,
			constantine_fiesta_lvl = true,
			constantine_yacht_lvl = true,
			constantine_cart_dwn_lvl = true,
			constantine_cart_con_lvl = true
		}
		
		if faction == "bo" then
			self:_setup_hhtacs_bo_compatibility(difficulty_index) --boworks custom faction support...i should make boworks-themed marshals for fun eventually
		elseif cartel_heists[level_id] then
			self:_setup_hhtacs_cartel_compatibility(difficulty_index) --constantine heists support
		end
		
		if tweak_data.skirmish then
			tweak_data.skirmish:setup_hhtacs()
			self.besiege.assault.force = {
				8,
				8,
				8
			}
			self.skirmish.assault.force = {
				8,
				8,
				8
			}
			self.besiege.assault.force_pool = {
				72,
				72,
				72
			}
			self.skirmish.assault.force_pool = {
				72,
				72,
				72
			}
			self.besiege.assault.sustain_duration_min = {
				105,
				105,
				105
			}
			self.skirmish.assault.sustain_duration_min = {
				105,
				105,
				105
			}
			self.besiege.assault.sustain_duration_max = {
				105,
				105,
				105
			}
			self.skirmish.assault.sustain_duration_max = {
				105,
				105,
				105
			}
			
			log("Holdout tweakdata initialized.")
		end
	end

	for group_id, group_info in pairs(self.enemy_spawn_groups) do
		if not self.besiege.assault.groups[group_id] then
			self.besiege.assault.groups[group_id] = {0, 0, 0}
		end
		
		if not self.skirmish.assault.groups[group_id] then
			self.besiege.assault.groups[group_id] = {0, 0, 0}
		end
		
		if not self.besiege.recon.groups[group_id] then
			self.besiege.recon.groups[group_id] = {0, 0, 0}
		end
		
		if not self.skirmish.recon.groups[group_id] then
			self.skirmish.recon.groups[group_id] = {0, 0, 0}
		end
	end

	self.street = deep_clone(self.besiege)
	self.safehouse = deep_clone(self.besiege)
	
	self._LIES_fix = true
end

function GroupAITweakData:_setup_hhtacs_task_data(difficulty_index)
	if difficulty_index <= 2 then
		self.besiege.recurring_group_SO = {
			recurring_cloaker_spawn = {
				retire_delay = 30,
				interval = {
					180,
					300
				}
			},
			recurring_spawn_1 = {
				interval = {
					30,
					60
				}
			}
		}
	elseif difficulty_index == 3 then
		self.besiege.recurring_group_SO = {
			recurring_cloaker_spawn = {
				retire_delay = 30,
				interval = {
					60,
					120
				}
			},
			recurring_spawn_1 = {
				interval = {
					30,
					60
				}
			}
		}
	elseif difficulty_index == 4 then
		self.besiege.recurring_group_SO = {
			recurring_cloaker_spawn = {
				retire_delay = 30,
				interval = {
					45,
					60
				}
			},
			recurring_spawn_1 = {
				interval = {
					30,
					60
				}
			}
		}
	elseif difficulty_index == 5 then
		self.besiege.recurring_group_SO = {
			recurring_cloaker_spawn = {
				retire_delay = 30,
				interval = {
					20,
					40
				}
			},
			recurring_spawn_1 = {
				interval = {
					30,
					45
				}
			}
		}
	else
		self.besiege.recurring_group_SO = {
			recurring_cloaker_spawn = {
				retire_delay = 60,
				interval = {
					15,
					30
				}
			},
			recurring_spawn_1 = {
				interval = {
					20,
					40
				}
			}
		}
	end
	
	if difficulty_index < 6 then
		self.smoke_grenade_lifetime = 7.5
		self.max_smoke_grenades = 1
	elseif difficulty_index < 8 then
		self.smoke_grenade_lifetime = 12
		self.max_smoke_grenades = 2
	else
		self.smoke_grenade_lifetime = 16
		self.max_smoke_grenades = 3
	end
	
	if difficulty_index < 6 then
		self.smoke_and_flash_grenade_timeout = {
			15,
			20
		}
	else
		self.smoke_and_flash_grenade_timeout = {
			10,
			17.5
		}
	end
	
	if difficulty_index > 7 then
		self.besiege.assault.force_balance_mul = {
			1.675,
			2.675,
			3.675,
			4.675
		}
	end
	
	if difficulty_index <= 6 then
		self.besiege.assault.force_pool = {
			36,
			54,
			72
		}
	else
		self.besiege.assault.force_pool = {
			72,
			108,
			144
		}
		self.besiege.assault.build_duration = 70
		self.besiege.assault.sustain_duration_min = {
			60,
			180,
			240
		}
		self.besiege.assault.sustain_duration_max = {
			80,
			240,
			300
		}
	end
	
	self.besiege.assault.force_pool_balance_mul = {
		1.5,
		1.75,
		2.25,
		2.75
	}
	self.besiege.assault.delay = { 
		60,
		45,
		30
	}
	
	self.phalanx.max_soldier_groups = 4
	self.phalanx.move_interval = 20
	
	if difficulty_index > 6 then
		self.phalanx.max_soldier_groups = 6
		self.phalanx.move_interval = 15
		self.phalanx.check_spawn_intervall = 120
		self.phalanx.respawn_delay = 1200
	end
	
	self.phalanx.vip.damage_reduction = {
		max = 0.2,
		start = 0.025,
		increase_intervall = 15,
		increase = 0.025
	}
end

Hooks:PostHook(GroupAITweakData, "_init_chatter_data", "lies_chatter", function(self)
	self.enemy_chatter.retreat = {
		radius = 1500,
		max_nr = 2,
		queue = "m01",
		group_min = 2,
		duration = {
			4,
			8
		},
		interval = {
			0.75,
			1.2
		}
	}
	self.enemy_chatter.aggressive = {
		radius = 800,
		max_nr = 4,
		queue = "g90",
		group_min = 0,
		duration = {
			4,
			8
		},
		interval = {
			1.5,
			3
		}
	}
	self.enemy_chatter.teammatedown = {
		radius = 800,
		max_nr = 4,
		queue = "lk3a",
		group_min = 0,
		duration = {
			4,
			8
		},
		interval = {
			1.5,
			3
		}
	}
	self.enemy_chatter.hostageblock = {
		radius = 1500,
		max_nr = 1,
		queue = "bak",
		group_min = 2,
		duration = {
			8,
			16
		},
		interval = {
			0.75,
			1.2
		}
	}
	self.enemy_chatter.wantcover = {
		radius = 800,
		max_nr = 4,
		queue = "hlp",
		group_min = 2,
		duration = {
			4,
			8
		},
		interval = {
			1.5,
			3
		}
	}
	self.enemy_chatter.go_go = {
		radius = 2000,
		max_nr = 1,
		queue = "mov",
		group_min = 2,
		duration = {
			8,
			16
		},
		interval = {
			0.75,
			1.2
		}
	}
	self.enemy_chatter.criminalhasgun = {
		radius = 3000,
		max_nr = 1,
		queue = "a01",
		group_min = 2,
		duration = {
			8,
			16
		},
		interval = {
			0.75,
			1.2
		}
	}
	self.enemy_chatter.contact = {
		radius = 1500,
		max_nr = 1,
		queue = "c01",
		group_min = 2,
		duration = {
			16,
			16
		},
		interval = {
			0.75,
			1.2
		}
	}
	self.enemy_chatter.open_fire = {
		radius = 1000,
		max_nr = 1,
		queue = "att",
		group_min = 2,
		duration = {
			8,
			16
		},
		interval = {
			0.75,
			1.2
		}
	}
	self.enemy_chatter.ready = {
		radius = 1000,
		max_nr = 1,
		queue = "rdy",
		group_min = 2,
		duration = {
			8,
			16
		},
		interval = {
			0.75,
			1.2
		}
	}
	self.enemy_chatter.controlidle = {
		radius = 1000,
		max_nr = 1,
		queue = "g90",
		group_min = 2,
		duration = {
			8,
			16
		},
		interval = {
			0.75,
			1.5
		}
	}
	self.enemy_chatter.clear = {
		radius = 1000,
		max_nr = 1,
		queue = "clr",
		group_min = 2,
		duration = {
			8,
			16
		},
		interval = {
			0.75,
			1.5
		}
	}
	self.enemy_chatter.in_pos = {
		radius = 700,
		max_nr = 1,
		queue = "pos",
		group_min = 2,
		duration = {
			8,
			16
		},
		interval = {
			0.75,
			1.2
		}
	}
	self.enemy_chatter.push = {
		radius = 700,
		max_nr = 1,
		queue = "pus",
		group_min = 0,
		duration = {
			8,
			16
		},
		interval = {
			0.75,
			1.2
		}
	}
	self.enemy_chatter.block_escort = {
		radius = 700,
		max_nr = 1,
		queue = "i02",
		group_min = 0,
		duration = {
			8,
			16
		},
		interval = {
			0.75,
			1.2
		}
	}
	self.enemy_chatter.flank = {
		radius = 2000,
		max_nr = 1,
		queue = "t01",
		group_min = 0,
		duration = {
			8,
			16
		},
		interval = {
			0.75,
			1.2
		}
	}
	self.enemy_chatter.sentry = {
		radius = 700,
		max_nr = 1,
		queue = "ch2",
		group_min = 2,
		duration = {
			8,
			16
		},
		interval = {
			0.75,
			1.2
		}
	}
	self.enemy_chatter.follow_me = {
		radius = 700,
		max_nr = 1,
		queue = "prm",
		group_min = 2,
		duration = {
			8,
			16
		},
		interval = {
			0.75,
			1.2
		}
	}
	self.enemy_chatter.calloutreload = {
		radius = 700,
		max_nr = 1,
		queue = "rrl",
		group_min = 0,
		duration = {
			8,
			16
		},
		interval = {
			0.75,
			1.2
		}
	}
	self.enemy_chatter.getcivs = {
		radius = 700,
		max_nr = 1,
		queue = "civ",
		group_min = 2,
		duration = {
			8,
			16
		},
		interval = {
			0.75,
			1.2
		}
	}
	self.enemy_chatter.gatherloot = {
		radius = 700,
		max_nr = 1,
		queue = "l01",
		group_min = 2,
		duration = {
			8,
			16
		},
		interval = {
			0.75,
			1.2
		}
	}
	self.enemy_chatter.movedin_civs = {
		radius = 700,
		max_nr = 1,
		queue = "cr1",
		group_min = 2,
		duration = {
			8,
			16
		},
		interval = {
			0.75,
			1.2
		}
	}
	
	self.enemy_chatter.drillsabotage = {
		radius = 700,
		max_nr = 1,
		queue = "e01",
		group_min = 0,
		duration = {
			0,
			0
		},
		interval = {
			0.75,
			1.2
		}
	}
	self.enemy_chatter.gearsabotage = {
		radius = 700,
		max_nr = 1,
		queue = "e02",
		group_min = 0,
		duration = {
			0,
			0
		},
		interval = {
			0.75,
			1.2
		}
	}
	self.enemy_chatter.powersabotage = {
		radius = 700,
		max_nr = 1,
		queue = "e03",
		group_min = 0,
		duration = {
			0,
			0
		},
		interval = {
			0.75,
			1.2
		}
	}
	self.enemy_chatter.gensabotage = {
		radius = 700,
		max_nr = 1,
		queue = "e04",
		group_min = 0,
		duration = {
			0,
			0
		},
		interval = {
			0.75,
			1.2
		}
	}
end)

function GroupAITweakData:_setup_hhtacs_bo_compatibility(difficulty_index)
	if difficulty_index == 6 then
		self.unit_categories.FBI_swat_M4.unit_types.bo = {
			Idstring("units/pd2_mod_bofa/characters/bofa_units/ene_bofa_g36/ene_bofa_g36")
		}
	end
	
	if self.unit_categories.FBI_reenforce then
		if difficulty_index < 8 then
			self.unit_categories.FBI_reenforce.unit_types.bo = {
				Idstring("units/pd2_mod_bofa/characters/ovk_units/ene_ovk_m4/ene_ovk_m4")
			}
			self.unit_categories.FBI_reenforce_heavy.unit_types.bo = {
				Idstring("units/pd2_mod_bofa/characters/ovk_units/ene_ovk_heavy_m4/ene_ovk_heavy_m4")
			}
		else
			self.unit_categories.FBI_reenforce.unit_types.bo = {
				Idstring("units/pd2_mod_bofa/characters/bofa_units/ene_bofa_g36/ene_bofa_g36")
			}
			self.unit_categories.FBI_reenforce_heavy.unit_types.bo = {
				Idstring("units/pd2_mod_bofa/characters/bofa_units/ene_bofa_heavy_g36/ene_bofa_heavy_g36")
			}
		end
	end
	
	if self.unit_categories.FBI_SMG then
		self.unit_categories.FBI_SMG.unit_types.bo = {
			Idstring("units/pd2_mod_bofa/characters/bofa_units/ene_bofa_ump/ene_bofa_ump")
		}
	end
	
	if difficulty_index == 6 then
		self.unit_categories.FBI_tank.unit_types.bo = self.unit_categories.FBI_tank.unit_types.america
	end
	
	for name, u_category in pairs(self.unit_categories) do
		if not u_category.unit_types.bo then
			u_category.unit_types.bo = deep_clone(u_category.unit_types.america)
		end
	end
end

function GroupAITweakData:_setup_hhtacs_cartel_compatibility(difficulty_index)
	--re-set all cartel enemies since i override some of them when im fixing vanilla groups

	self.unit_categories.CS_cop_C45_R870.unit_types.federales = {
		Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier/ene_cartel_soldier"),
		Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_2/ene_cartel_soldier_2"),
		Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_3/ene_cartel_soldier_3"),		
		Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_4/ene_cartel_soldier_4"),
		Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_shotgun_1/ene_cartel_soldier_shotgun_1"),
		Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_shotgun_2/ene_cartel_soldier_shotgun_2"),
		Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_shotgun_3/ene_cartel_soldier_shotgun_3"),		
		Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_shotgun_4/ene_cartel_soldier_shotgun_4")	
	}
	
	self.unit_categories.CS_cop_stealth_MP5.unit_types.federales = {
		Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier/ene_cartel_soldier"),
		Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_2/ene_cartel_soldier_2"),
		Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_3/ene_cartel_soldier_3"),		
		Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_4/ene_cartel_soldier_4"),
		Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_shotgun_1/ene_cartel_soldier_shotgun_1"),
		Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_shotgun_2/ene_cartel_soldier_shotgun_2"),
		Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_shotgun_3/ene_cartel_soldier_shotgun_3"),		
		Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_shotgun_4/ene_cartel_soldier_shotgun_4")	
	}
	
	self.unit_categories.CS_swat_MP5.unit_types.federales =	{
		Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier/ene_cartel_soldier"),
		Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_2/ene_cartel_soldier_2"),
		Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_3/ene_cartel_soldier_3"),		
		Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_4/ene_cartel_soldier_4"),
		Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_shotgun_1/ene_cartel_soldier_shotgun_1"),
		Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_shotgun_2/ene_cartel_soldier_shotgun_2"),
		Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_shotgun_3/ene_cartel_soldier_shotgun_3"),		
		Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_shotgun_4/ene_cartel_soldier_shotgun_4")
	}
	self.unit_categories.CS_swat_R870.unit_types.federales =	{
		Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier/ene_cartel_soldier"),
		Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_2/ene_cartel_soldier_2"),
		Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_3/ene_cartel_soldier_3"),		
		Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_4/ene_cartel_soldier_4"),
		Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_shotgun_1/ene_cartel_soldier_shotgun_1"),
		Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_shotgun_2/ene_cartel_soldier_shotgun_2"),
		Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_shotgun_3/ene_cartel_soldier_shotgun_3"),		
		Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_shotgun_4/ene_cartel_soldier_shotgun_4")
	}
	
	self.unit_categories.CS_heavy_M4.unit_types.federales =	{
		Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_heavy/ene_cartel_soldier_heavy"),
		Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_heavy_shotgun/ene_cartel_soldier_heavy_shotgun")
	}
	self.unit_categories.CS_heavy_R870.unit_types.federales =	{
		Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_heavy/ene_cartel_soldier_heavy"),
		Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_heavy_shotgun/ene_cartel_soldier_heavy_shotgun")
	}
	
	self.unit_categories.CS_shield.unit_types.federales = {Idstring("units/pd2_mod_ttr/characters/ene_cartel_shield/ene_cartel_shield")}
	
	self.unit_categories.FBI_suit_C45_M4.unit_types.federales = {
		Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier/ene_cartel_soldier"),
		Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_2/ene_cartel_soldier_2"),
		Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_3/ene_cartel_soldier_3"),		
		Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_4/ene_cartel_soldier_4"),
		Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_shotgun_1/ene_cartel_soldier_shotgun_1"),
		Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_shotgun_2/ene_cartel_soldier_shotgun_2"),
		Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_shotgun_3/ene_cartel_soldier_shotgun_3"),		
		Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_shotgun_4/ene_cartel_soldier_shotgun_4")
	}
	self.unit_categories.FBI_suit_M4_MP5.unit_types.federales = {
		Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier/ene_cartel_soldier"),
		Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_2/ene_cartel_soldier_2"),
		Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_3/ene_cartel_soldier_3"),		
		Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_4/ene_cartel_soldier_4"),
		Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_shotgun_1/ene_cartel_soldier_shotgun_1"),
		Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_shotgun_2/ene_cartel_soldier_shotgun_2"),
		Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_shotgun_3/ene_cartel_soldier_shotgun_3"),		
		Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_shotgun_4/ene_cartel_soldier_shotgun_4")
	}
	self.unit_categories.FBI_suit_stealth_MP5.unit_types.federales = {
		Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier/ene_cartel_soldier"),
		Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_2/ene_cartel_soldier_2"),
		Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_3/ene_cartel_soldier_3"),		
		Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_4/ene_cartel_soldier_4"),
		Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_shotgun_1/ene_cartel_soldier_shotgun_1"),
		Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_shotgun_2/ene_cartel_soldier_shotgun_2"),
		Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_shotgun_3/ene_cartel_soldier_shotgun_3"),		
		Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_shotgun_4/ene_cartel_soldier_shotgun_4")
	}
	
	self.unit_categories.marshal_marksman.unit_types.federales = {Idstring("units/pd2_mod_ttr/characters/ene_cartel_tazer/ene_cartel_tazer")}	
	self.unit_categories.marshal_shield.unit_types.federales = {Idstring("units/pd2_mod_ttr/characters/ene_cartel_tazer/ene_cartel_tazer")}	

	self.unit_categories.spooc.unit_types.federales = {Idstring("units/pd2_mod_ttr/characters/ene_cartel_scout/ene_cartel_scout")}
	self.unit_categories.CS_tazer.unit_types.federales = {Idstring("units/pd2_mod_ttr/characters/ene_cartel_tazer_normal/ene_cartel_tazer_normal")}	

	self.unit_categories.medic_M4.unit_types.federales = {
		Idstring("units/pd2_mod_ttr/characters/ene_cartel_grenadier/ene_cartel_grenadier"),
		Idstring("units/pd2_mod_ttr/characters/ene_cartel_grenadier_2/ene_cartel_grenadier_2")		
	}	
	self.unit_categories.medic_R870.unit_types.federales = {
		Idstring("units/pd2_mod_ttr/characters/ene_cartel_grenadier/ene_cartel_grenadier"),
		Idstring("units/pd2_mod_ttr/characters/ene_cartel_grenadier_2/ene_cartel_grenadier_2")		
	}	

	self.unit_categories.FBI_tank.unit_types.federales = {
		Idstring("units/pd2_mod_ttr/characters/ene_cartel_bulldozer/ene_cartel_bulldozer"),
		Idstring("units/pd2_mod_ttr/characters/ene_cartel_bulldozer_2/ene_cartel_bulldozer_2"),
		Idstring("units/pd2_mod_ttr/characters/ene_cartel_bulldozer_3/ene_cartel_bulldozer_3")		
	}

	if difficulty_index < 6 then
		-- FBI
		self.unit_categories.FBI_swat_M4.unit_types.federales = {
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_fbi_1/ene_cartel_soldier_fbi_1"),
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_fbi_2/ene_cartel_soldier_fbi_2"),
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_fbi_3/ene_cartel_soldier_fbi_3"),
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_fbi_4/ene_cartel_soldier_fbi_4"),
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_fbi_shotgun_1/ene_cartel_soldier_fbi_shotgun_1"),
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_fbi_shotgun_2/ene_cartel_soldier_fbi_shotgun_2"),
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_fbi_shotgun_3/ene_cartel_soldier_fbi_shotgun_3"),		
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_fbi_shotgun_4/ene_cartel_soldier_fbi_shotgun_4")
		}

		self.unit_categories.FBI_swat_R870.unit_types.federales = {
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_fbi_1/ene_cartel_soldier_fbi_1"),
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_fbi_2/ene_cartel_soldier_fbi_2"),
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_fbi_3/ene_cartel_soldier_fbi_3"),		
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_fbi_4/ene_cartel_soldier_fbi_4"),
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_fbi_shotgun_1/ene_cartel_soldier_fbi_shotgun_1"),
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_fbi_shotgun_2/ene_cartel_soldier_fbi_shotgun_2"),
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_fbi_shotgun_3/ene_cartel_soldier_fbi_shotgun_3"),		
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_fbi_shotgun_4/ene_cartel_soldier_fbi_shotgun_4")
		}

		self.unit_categories.FBI_heavy_G36.unit_types.federales =	{
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_heavy_fbi/ene_cartel_soldier_heavy_fbi"),
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_heavy_fbi_shotgun/ene_cartel_soldier_heavy_fbi_shotgun")
		}
		self.unit_categories.FBI_heavy_R870.unit_types.federales =	{
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_heavy_fbi/ene_cartel_soldier_heavy_fbi"),
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_heavy_fbi_shotgun/ene_cartel_soldier_heavy_fbi_shotgun")
		}

		self.unit_categories.marshal_marksman.unit_types.federales = {Idstring("units/pd2_mod_ttr/characters/ene_cartel_tazer/ene_cartel_tazer")}	
		self.unit_categories.marshal_shield.unit_types.federales = {Idstring("units/pd2_mod_ttr/characters/ene_cartel_tazer/ene_cartel_tazer")}	

		self.unit_categories.spooc.unit_types.federales = {Idstring("units/pd2_mod_ttr/characters/ene_cartel_scout/ene_cartel_scout")}
		self.unit_categories.CS_tazer.unit_types.federales = {Idstring("units/pd2_mod_ttr/characters/ene_cartel_tazer_normal/ene_cartel_tazer_normal")}	

		self.unit_categories.medic_M4.unit_types.federales = {
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_grenadier/ene_cartel_grenadier"),
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_grenadier_2/ene_cartel_grenadier_2")		
		}	
		self.unit_categories.medic_R870.unit_types.federales = {
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_grenadier/ene_cartel_grenadier"),
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_grenadier_2/ene_cartel_grenadier_2")		
		}	
		self.unit_categories.FBI_tank.unit_types.federales = {
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_bulldozer/ene_cartel_bulldozer"),
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_bulldozer_2/ene_cartel_bulldozer_2"),
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_bulldozer_3/ene_cartel_bulldozer_3")		
		}

		self.unit_categories.FBI_shield.unit_types.federales = {Idstring("units/pd2_mod_ttr/characters/ene_cartel_shield/ene_cartel_shield")}
		
	elseif difficulty_index < 8 then
		-- City
		self.unit_categories.FBI_swat_M4.unit_types.federales =	{
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_city_1/ene_cartel_soldier_city_1"),
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_city_2/ene_cartel_soldier_city_2"),
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_city_3/ene_cartel_soldier_city_3"),		
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_city_4/ene_cartel_soldier_city_4"),
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_city_shotgun_1/ene_cartel_soldier_city_shotgun_1"),
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_city_shotgun_2/ene_cartel_soldier_city_shotgun_2"),
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_city_shotgun_3/ene_cartel_soldier_city_shotgun_3"),		
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_city_shotgun_4/ene_cartel_soldier_city_shotgun_4")	
		}
		
		self.unit_categories.FBI_swat_R870.unit_types.federales =	{
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_city_1/ene_cartel_soldier_city_1"),
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_city_2/ene_cartel_soldier_city_2"),
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_city_3/ene_cartel_soldier_city_3"),		
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_city_4/ene_cartel_soldier_city_4"),
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_city_shotgun_1/ene_cartel_soldier_city_shotgun_1"),
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_city_shotgun_2/ene_cartel_soldier_city_shotgun_2"),
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_city_shotgun_3/ene_cartel_soldier_city_shotgun_3"),		
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_city_shotgun_4/ene_cartel_soldier_city_shotgun_4")	
		}
		
		self.unit_categories.FBI_heavy_G36.unit_types.federales =	{
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_heavy_city/ene_cartel_soldier_heavy_city"),
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_heavy_fbi_shotgun/ene_cartel_soldier_heavy_fbi_shotgun")
		}
		self.unit_categories.FBI_heavy_R870.unit_types.federales =	{
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_heavy_city/ene_cartel_soldier_heavy_city"),
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_heavy_fbi_shotgun/ene_cartel_soldier_heavy_fbi_shotgun")
		}
		
		self.unit_categories.marshal_marksman.unit_types.federales = {Idstring("units/pd2_mod_ttr/characters/ene_cartel_tazer/ene_cartel_tazer")}	
		self.unit_categories.marshal_shield.unit_types.federales = {Idstring("units/pd2_mod_ttr/characters/ene_cartel_tazer/ene_cartel_tazer")}	
		
		self.unit_categories.spooc.unit_types.federales = {Idstring("units/pd2_mod_ttr/characters/ene_cartel_scout/ene_cartel_scout")}
		self.unit_categories.CS_tazer.unit_types.federales = {Idstring("units/pd2_mod_ttr/characters/ene_cartel_tazer_normal/ene_cartel_tazer_normal")}	

		self.unit_categories.medic_M4.unit_types.federales = {
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_grenadier/ene_cartel_grenadier"),
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_grenadier_2/ene_cartel_grenadier_2")		
		}	
		self.unit_categories.medic_R870.unit_types.federales = {
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_grenadier/ene_cartel_grenadier"),
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_grenadier_2/ene_cartel_grenadier_2")		
		}	

		self.unit_categories.FBI_tank.unit_types.federales = {
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_bulldozer/ene_cartel_bulldozer"),
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_bulldozer_2/ene_cartel_bulldozer_2"),
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_bulldozer_3/ene_cartel_bulldozer_3")		
		}

		self.unit_categories.FBI_shield.unit_types.federales = {Idstring("units/pd2_mod_ttr/characters/ene_cartel_shield/ene_cartel_shield")}		
	else
		-- ZEALs
		self.unit_categories.FBI_swat_M4.unit_types.federales =	{
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier/ene_cartel_soldier"),
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_2/ene_cartel_soldier_2"),
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_3/ene_cartel_soldier_3"),		
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_4/ene_cartel_soldier_4"),
		}
		self.unit_categories.FBI_swat_R870.unit_types.federales =	{
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier/ene_cartel_soldier"),
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_2/ene_cartel_soldier_2"),
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_3/ene_cartel_soldier_3"),		
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_4/ene_cartel_soldier_4"),
		}
			
		self.unit_categories.FBI_heavy_G36.unit_types.federales =	{Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_heavy/ene_cartel_soldier_heavy")}
		self.unit_categories.FBI_heavy_R870.unit_types.federales =	{Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_heavy/ene_cartel_soldier_heavy")}

		self.unit_categories.marshal_marksman.unit_types.federales = {Idstring("units/pd2_mod_ttr/characters/ene_cartel_tazer/ene_cartel_tazer")}	
		self.unit_categories.marshal_shield.unit_types.federales = {Idstring("units/pd2_mod_ttr/characters/ene_cartel_tazer/ene_cartel_tazer")}	

		self.unit_categories.spooc.unit_types.federales = {Idstring("units/pd2_mod_ttr/characters/ene_cartel_scout/ene_cartel_scout")}
		self.unit_categories.CS_tazer.unit_types.federales = {Idstring("units/pd2_mod_ttr/characters/ene_cartel_tazer_normal/ene_cartel_tazer_normal")}	

		self.unit_categories.medic_M4.unit_types.federales = {Idstring("units/pd2_mod_ttr/characters/ene_cartel_grenadier/ene_cartel_grenadier")}	
		self.unit_categories.medic_R870.unit_types.federales = {Idstring("units/pd2_mod_ttr/characters/ene_cartel_grenadier_2/ene_cartel_grenadier_2")}	

		self.unit_categories.FBI_tank.unit_types.federales = {
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_bulldozer/ene_cartel_bulldozer"),
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_bulldozer_2/ene_cartel_bulldozer_2"),
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_bulldozer_3/ene_cartel_bulldozer_3")		
		}

		self.unit_categories.marshal_marksman.unit_types.federales = {Idstring("units/pd2_mod_ttr/characters/ene_cartel_tazer/ene_cartel_tazer")}	
		self.unit_categories.marshal_shield.unit_types.federales = {Idstring("units/pd2_mod_ttr/characters/ene_cartel_tazer/ene_cartel_tazer")}	
		
		self.unit_categories.spooc.unit_types.federales = {Idstring("units/pd2_mod_ttr/characters/ene_cartel_scout/ene_cartel_scout")}
		self.unit_categories.CS_tazer.unit_types.federales = {Idstring("units/pd2_mod_ttr/characters/ene_cartel_tazer_normal/ene_cartel_tazer_normal")}	

		self.unit_categories.medic_M4.unit_types.federales = {
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_grenadier/ene_cartel_grenadier"),
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_grenadier_2/ene_cartel_grenadier_2")		
		}	
		self.unit_categories.medic_R870.unit_types.federales = {
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_grenadier/ene_cartel_grenadier"),
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_grenadier_2/ene_cartel_grenadier_2")		
		}	
		self.unit_categories.FBI_tank.unit_types.federales = {
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_bulldozer/ene_cartel_bulldozer"),
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_bulldozer_2/ene_cartel_bulldozer_2"),
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_bulldozer_3/ene_cartel_bulldozer_3")		
		}

		self.unit_categories.FBI_shield.unit_types.federales = {Idstring("units/pd2_mod_ttr/characters/ene_cartel_shield/ene_cartel_shield")}
	end
	
	if self.unit_categories.FBI_SMG then
		self.unit_categories.FBI_SMG.unit_types.federales = {
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier/ene_cartel_soldier"),
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_2/ene_cartel_soldier_2"),
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_3/ene_cartel_soldier_3"),		
			Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_4/ene_cartel_soldier_4")
		}
	end
	
	if self.unit_categories.FBI_reenforce then
		if difficulty_index < 8 then
			self.unit_categories.FBI_reenforce.unit_types.federales = {
				Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_fbi_1/ene_cartel_soldier_fbi_1"),
				Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_fbi_2/ene_cartel_soldier_fbi_2"),
				Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_fbi_3/ene_cartel_soldier_fbi_3"),		
				Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_fbi_4/ene_cartel_soldier_fbi_4")
			}
			self.unit_categories.FBI_reenforce_heavy.unit_types.federales = {
				Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_heavy_fbi/ene_cartel_soldier_heavy_fbi"),
			}
		else
			self.unit_categories.FBI_reenforce.unit_types.federales = {
				Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_city_1/ene_cartel_soldier_city_1"),
				Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_city_2/ene_cartel_soldier_city_2"),
				Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_city_3/ene_cartel_soldier_city_3"),		
				Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_city_4/ene_cartel_soldier_city_4")
			}
			self.unit_categories.FBI_reenforce_heavy.unit_types.federales = {
				Idstring("units/pd2_mod_ttr/characters/ene_cartel_soldier_heavy_city/ene_cartel_soldier_heavy_city")
			}
		end
	end
	
	self.enemy_spawn_groups.CS_cops = nil
end