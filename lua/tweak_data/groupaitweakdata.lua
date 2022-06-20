function GroupAITweakData:_LIES_setup()
	if self._LIES_fix then
		return
	end

	if self.enemy_spawn_groups["tac_swat_shotgun_rush"] and not self._LIES_fix then
		log("LIES: Another mod has already changed spawn groups and tactics. Ignoring tweakdata setup.")
		
		self._LIES_fix = true
		
		return
	end

	self._tactics.tazer_flanking = { 
		"flank", --set to "flanking" in vanilla which is not an actual tactic
		"charge",
		"provide_coverfire",
		"smoke_grenade",
		"murder"
	}
	
	local difficulty = Global.game_settings and Global.game_settings.difficulty or "normal"
	local difficulty_index = tweak_data:difficulty_to_index(difficulty)
	
	if LIES.settings.hhtacs then
		log("LIES: Initializing Hyper Taktikz. Poggers.")
		
		if tweak_data.character then
			tweak_data.character:setup_hhtacs()
		end
		
		if tweak_data.weapon then
			tweak_data.weapon:_setup_hhtacs()
		end
	
		self._tactics.spooc = {
			"flank",
			"charge",
			"shield_cover",
			"smoke_grenade"
		}
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
		
		if LIES.settings.fixed_spawngroups < 3 then
			if difficulty_index > 5 then
				self._tactics.swat_rifle_flank = { --this is the group ever
					"ranged_fire",
					"provide_coverfire",
					"provide_support",
					"flash_grenade",
					"harass"
				}
			else
				self._tactics.swat_rifle_flank = { --this is the group ever
					"ranged_fire",
					"provide_coverfire",
					"provide_support",
					"flash_grenade"
				}
			end
		else
			if difficulty_index > 5 then
				self._tactics.swat_rifle = {
					"ranged_fire",
					"provide_coverfire",
					"provide_support",
					"smoke_grenade",
					"harass"
				}
				self._tactics.swat_shotgun_rush = {
					"charge",
					"provide_coverfire",
					"provide_support",
					"deathguard",
					"flash_grenade",
					"harass"
				}
				self._tactics.shield_support_charge = {
					"shield_cover",
					"charge",
					"harass",
					"provide_coverfire",
					"flash_grenade"
				}
			else
				self._tactics.swat_rifle = {
					"ranged_fire",
					"provide_coverfire",
					"provide_support",
					"smoke_grenade"
				}
				self._tactics.swat_shotgun_rush = {
					"charge",
					"provide_coverfire",
					"provide_support",
					"deathguard",
					"flash_grenade"
				}
			end
			
			self._tactics.swat_rifle_flank = {
				"ranged_fire",
				"flank",
				"provide_coverfire",
				"provide_support",
				"smoke_grenade"
			}
			self._tactics.tazer_charge = {
				"charge",
				"flash_grenade",
				"provide_coverfire",
				"murder"
			}
		end
		
		--chad wuz here
	end
	
	if LIES.settings.hhtacs then
		if difficulty_index < 5 then
			self.unit_categories.FBI_tank.unit_types = {
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
					Idstring("units/pd2_dlc_bex/characters/ene_swat_dozer_policia_federale_saiga/ene_swat_dozer_policia_federale_saiga")
				}
			}
		elseif difficulty_index == 5 then
			self.unit_categories.FBI_tank.unit_types = {
				america = {
					Idstring("units/payday2/characters/ene_bulldozer_1/ene_bulldozer_1"),
					Idstring("units/payday2/characters/ene_bulldozer_2/ene_bulldozer_2")
				},
				russia = {
					Idstring("units/pd2_dlc_mad/characters/ene_akan_fbi_tank_saiga/ene_akan_fbi_tank_saiga"),
					Idstring("units/pd2_dlc_mad/characters/ene_akan_fbi_tank_r870/ene_akan_fbi_tank_r870")
				},
				zombie = {
					Idstring("units/pd2_dlc_hvh/characters/ene_bulldozer_hvh_1/ene_bulldozer_hvh_1"),
					Idstring("units/pd2_dlc_hvh/characters/ene_bulldozer_hvh_2/ene_bulldozer_hvh_2")
				},
				murkywater = {
					Idstring("units/pd2_dlc_bph/characters/ene_murkywater_bulldozer_2/ene_murkywater_bulldozer_2"),
					Idstring("units/pd2_dlc_bph/characters/ene_murkywater_bulldozer_3/ene_murkywater_bulldozer_3")
				},
				federales = {
					Idstring("units/pd2_dlc_bex/characters/ene_swat_dozer_policia_federale_saiga/ene_swat_dozer_policia_federale_saiga"),
					Idstring("units/pd2_dlc_bex/characters/ene_swat_dozer_policia_federale_r870/ene_swat_dozer_policia_federale_r870")
				}
			}
		elseif difficulty_index == 6 then
			self.unit_categories.FBI_tank.unit_types = {
				america = {
					Idstring("units/payday2/characters/ene_bulldozer_1/ene_bulldozer_1"),
					Idstring("units/payday2/characters/ene_bulldozer_2/ene_bulldozer_2"),
					Idstring("units/payday2/characters/ene_bulldozer_3/ene_bulldozer_3")
				},
				russia = {
					Idstring("units/pd2_dlc_mad/characters/ene_akan_fbi_tank_r870/ene_akan_fbi_tank_r870"),
					Idstring("units/pd2_dlc_mad/characters/ene_akan_fbi_tank_saiga/ene_akan_fbi_tank_saiga"),
					Idstring("units/pd2_dlc_mad/characters/ene_akan_fbi_tank_rpk_lmg/ene_akan_fbi_tank_rpk_lmg")
				},
				zombie = {
					Idstring("units/pd2_dlc_hvh/characters/ene_bulldozer_hvh_1/ene_bulldozer_hvh_1"),
					Idstring("units/pd2_dlc_hvh/characters/ene_bulldozer_hvh_2/ene_bulldozer_hvh_2"),
					Idstring("units/pd2_dlc_hvh/characters/ene_bulldozer_hvh_3/ene_bulldozer_hvh_3")
				},
				murkywater = {
					Idstring("units/pd2_dlc_bph/characters/ene_murkywater_bulldozer_1/ene_murkywater_bulldozer_1"),
					Idstring("units/pd2_dlc_bph/characters/ene_murkywater_bulldozer_2/ene_murkywater_bulldozer_2"),
					Idstring("units/pd2_dlc_bph/characters/ene_murkywater_bulldozer_3/ene_murkywater_bulldozer_3")
				},
				federales = {
					Idstring("units/pd2_dlc_bex/characters/ene_swat_dozer_policia_federale_r870/ene_swat_dozer_policia_federale_r870"),
					Idstring("units/pd2_dlc_bex/characters/ene_swat_dozer_policia_federale_saiga/ene_swat_dozer_policia_federale_saiga"),
					Idstring("units/pd2_dlc_bex/characters/ene_swat_dozer_policia_federale_m249/ene_swat_dozer_policia_federale_m249")
				}
			}
		elseif difficulty_index == 7 then
			self.unit_categories.FBI_tank.unit_types = {
				america = {
					Idstring("units/payday2/characters/ene_bulldozer_1/ene_bulldozer_1"),
					Idstring("units/payday2/characters/ene_bulldozer_2/ene_bulldozer_2"),
					Idstring("units/payday2/characters/ene_bulldozer_3/ene_bulldozer_3"),
					Idstring("units/pd2_dlc_drm/characters/ene_bulldozer_minigun_classic/ene_bulldozer_minigun_classic")
				},
				russia = {
					Idstring("units/pd2_dlc_mad/characters/ene_akan_fbi_tank_r870/ene_akan_fbi_tank_r870"),
					Idstring("units/pd2_dlc_mad/characters/ene_akan_fbi_tank_saiga/ene_akan_fbi_tank_saiga"),
					Idstring("units/pd2_dlc_mad/characters/ene_akan_fbi_tank_rpk_lmg/ene_akan_fbi_tank_rpk_lmg"),
					Idstring("units/pd2_dlc_drm/characters/ene_bulldozer_minigun_classic/ene_bulldozer_minigun_classic")
				},
				zombie = {
					Idstring("units/pd2_dlc_hvh/characters/ene_bulldozer_hvh_1/ene_bulldozer_hvh_1"),
					Idstring("units/pd2_dlc_hvh/characters/ene_bulldozer_hvh_2/ene_bulldozer_hvh_2"),
					Idstring("units/pd2_dlc_hvh/characters/ene_bulldozer_hvh_3/ene_bulldozer_hvh_3"),
					Idstring("units/pd2_dlc_drm/characters/ene_bulldozer_minigun_classic/ene_bulldozer_minigun_classic")
				},
				murkywater = {
					Idstring("units/pd2_dlc_bph/characters/ene_murkywater_bulldozer_1/ene_murkywater_bulldozer_1"),
					Idstring("units/pd2_dlc_bph/characters/ene_murkywater_bulldozer_2/ene_murkywater_bulldozer_2"),
					Idstring("units/pd2_dlc_bph/characters/ene_murkywater_bulldozer_3/ene_murkywater_bulldozer_3"),
					Idstring("units/pd2_dlc_bph/characters/ene_murkywater_bulldozer_4/ene_murkywater_bulldozer_4")
				},
				federales = {
					Idstring("units/pd2_dlc_bex/characters/ene_swat_dozer_policia_federale_r870/ene_swat_dozer_policia_federale_r870"),
					Idstring("units/pd2_dlc_bex/characters/ene_swat_dozer_policia_federale_saiga/ene_swat_dozer_policia_federale_saiga"),
					Idstring("units/pd2_dlc_bex/characters/ene_swat_dozer_policia_federale_m249/ene_swat_dozer_policia_federale_m249"),
					Idstring("units/pd2_dlc_bex/characters/ene_swat_dozer_policia_federale_minigun/ene_swat_dozer_policia_federale_minigun")
				}
			}
		else
			self.unit_categories.FBI_tank.unit_types = {
				america = {
					Idstring("units/pd2_dlc_gitgud/characters/ene_zeal_bulldozer/ene_zeal_bulldozer"),
					Idstring("units/pd2_dlc_gitgud/characters/ene_zeal_bulldozer_2/ene_zeal_bulldozer_2"),
					Idstring("units/pd2_dlc_gitgud/characters/ene_zeal_bulldozer_3/ene_zeal_bulldozer_3"),
					Idstring("units/pd2_dlc_drm/characters/ene_bulldozer_medic/ene_bulldozer_medic"),
					Idstring("units/pd2_dlc_drm/characters/ene_bulldozer_minigun/ene_bulldozer_minigun")
				},
				russia = {
					Idstring("units/pd2_dlc_mad/characters/ene_akan_fbi_tank_r870/ene_akan_fbi_tank_r870"),
					Idstring("units/pd2_dlc_mad/characters/ene_akan_fbi_tank_saiga/ene_akan_fbi_tank_saiga"),
					Idstring("units/pd2_dlc_mad/characters/ene_akan_fbi_tank_rpk_lmg/ene_akan_fbi_tank_rpk_lmg"),
					Idstring("units/pd2_dlc_drm/characters/ene_bulldozer_medic/ene_bulldozer_medic"),
					Idstring("units/pd2_dlc_drm/characters/ene_bulldozer_minigun/ene_bulldozer_minigun")
				},
				zombie = {
					Idstring("units/pd2_dlc_hvh/characters/ene_bulldozer_hvh_1/ene_bulldozer_hvh_1"),
					Idstring("units/pd2_dlc_hvh/characters/ene_bulldozer_hvh_2/ene_bulldozer_hvh_2"),
					Idstring("units/pd2_dlc_hvh/characters/ene_bulldozer_hvh_3/ene_bulldozer_hvh_3"),
					Idstring("units/pd2_dlc_drm/characters/ene_bulldozer_medic/ene_bulldozer_medic"),
					Idstring("units/pd2_dlc_drm/characters/ene_bulldozer_minigun/ene_bulldozer_minigun")
				},
				murkywater = {
					Idstring("units/pd2_dlc_bph/characters/ene_murkywater_bulldozer_1/ene_murkywater_bulldozer_1"),
					Idstring("units/pd2_dlc_bph/characters/ene_murkywater_bulldozer_2/ene_murkywater_bulldozer_2"),
					Idstring("units/pd2_dlc_bph/characters/ene_murkywater_bulldozer_3/ene_murkywater_bulldozer_3"),
					Idstring("units/pd2_dlc_bph/characters/ene_murkywater_bulldozer_4/ene_murkywater_bulldozer_4"),
					Idstring("units/pd2_dlc_bph/characters/ene_murkywater_bulldozer_medic/ene_murkywater_bulldozer_medic")
				},
				federales = {
					Idstring("units/pd2_dlc_bex/characters/ene_swat_dozer_policia_federale_r870/ene_swat_dozer_policia_federale_r870"),
					Idstring("units/pd2_dlc_bex/characters/ene_swat_dozer_policia_federale_saiga/ene_swat_dozer_policia_federale_saiga"),
					Idstring("units/pd2_dlc_bex/characters/ene_swat_dozer_policia_federale_m249/ene_swat_dozer_policia_federale_m249"),
					Idstring("units/pd2_dlc_bex/characters/ene_swat_dozer_policia_federale_minigun/ene_swat_dozer_policia_federale_minigun"),
					Idstring("units/pd2_dlc_bex/characters/ene_swat_dozer_medic_policia_federale/ene_swat_dozer_medic_policia_federale")
				}
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
						rank = 2,
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
						rank = 2,
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
						rank = 2,
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
						amount_min = 1,
						freq = 1,
						amount_max = 1,
						rank = 2,
						unit = "FBI_swat_M4",
						tactics = self._tactics.swat_rifle_flank
					},
					{
						amount_min = 3,
						freq = 3,
						amount_max = 3,
						rank = 3,
						unit = "FBI_heavy_G36",
						tactics = self._tactics.swat_rifle_flank
					},
					{
						amount_min = 0,
						freq = 0.35,
						amount_max = 1,
						rank = 2,
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
						amount_min = 2,
						freq = 2,
						amount_max = 2,
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
						rank = 2,
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
						amount_min = 2,
						freq = 2,
						amount_max = 2,
						rank = 2,
						unit = "FBI_swat_M4",
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
						rank = 2,
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
						amount_min = 2,
						freq = 2,
						amount_max = 2,
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
						rank = 2,
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
						amount_min = 2,
						freq = 2,
						amount_max = 2,
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
						rank = 2,
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
						amount_min = 2,
						freq = 2,
						amount_max = 2,
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
						rank = 2,
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
						amount_min = 2,
						freq = 2,
						amount_max = 2,
						rank = 2,
						unit = "FBI_swat_R870",
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
						rank = 2,
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
						amount_min = 2,
						freq = 2,
						amount_max = 2,
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
						rank = 2,
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
						amount_min = 2,
						freq = 2,
						amount_max = 2,
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
						rank = 2,
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
					6,
					6
				},
				spawn = {
					{
						amount_min = 2,
						freq = 1,
						amount_max = 2,
						rank = 3,
						unit = "CS_tazer",
						tactics = self._tactics.tazer_flanking
					},
					{
						amount_min = 1,
						freq = 1,
						amount_max = 1,
						rank = 2,
						unit = "FBI_swat_M4",
						tactics = self._tactics.swat_rifle_flank
					},
					{
						amount_min = 3,
						freq = 3,
						amount_max = 3,
						rank = 3,
						unit = "FBI_heavy_G36",
						tactics = self._tactics.swat_rifle_flank
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
						amount_min = 2,
						freq = 1,
						amount_max = 2,
						rank = 3,
						unit = "CS_tazer",
						tactics = self._tactics.tazer_charge
					},
					{
						amount_min = 1,
						freq = 1,
						amount_max = 1,
						rank = 2,
						unit = "FBI_swat_M4",
						tactics = self._tactics.swat_rifle_flank
					},
					{
						amount_min = 3,
						freq = 3,
						amount_max = 3,
						rank = 3,
						unit = "FBI_heavy_G36",
						tactics = self._tactics.swat_rifle_flank
					}
				}
			}
		end
	end
	
	if LIES.settings.fixed_spawngroups > 2 and not self._LIES_fix then
		log("LIES: Attempting to fix spawngroups...")
		
		if self.enemy_spawn_groups.tac_swat_shotgun_rush then
			log("LIES: Spawngroups already fixed by another mod.")
			self._LIES_fix = true
		else
			if difficulty_index < 6 then
				self.unit_categories.FBI_swat_R870.unit_types = {
					america = {
						Idstring("units/payday2/characters/ene_fbi_swat_2/ene_fbi_swat_2")
					},
					russia = {
						Idstring("units/pd2_dlc_mad/characters/ene_akan_fbi_swat_r870/ene_akan_fbi_swat_r870")
					},
					zombie = {
						Idstring("units/pd2_dlc_hvh/characters/ene_fbi_swat_hvh_2/ene_fbi_swat_hvh_2")
					},
					murkywater = {
						Idstring("units/pd2_dlc_bph/characters/ene_murkywater_light_r870/ene_murkywater_light_r870")
					},
					federales = {
						Idstring("units/pd2_dlc_bex/characters/ene_swat_policia_federale_r870/ene_swat_policia_federale_r870")
					}
				}
			elseif difficulty_index < 8 then
				self.unit_categories.FBI_swat_R870.unit_types = {
					america = {
						Idstring("units/payday2/characters/ene_city_swat_2/ene_city_swat_2")
					},
					russia = {
						Idstring("units/pd2_dlc_mad/characters/ene_akan_fbi_swat_dw_r870/ene_akan_fbi_swat_dw_r870")
					},
					zombie = {
						Idstring("units/pd2_dlc_hvh/characters/ene_fbi_swat_hvh_2/ene_fbi_swat_hvh_2")
					},
					murkywater = {
						Idstring("units/pd2_dlc_bph/characters/ene_murkywater_light_city_r870/ene_murkywater_light_city_r870")
					},
					federales = {
						Idstring("units/pd2_dlc_bex/characters/ene_swat_policia_federale_city_r870/ene_swat_policia_federale_city_r870")
					}
				}
			else
				self.unit_categories.FBI_swat_R870.unit_types = {
					america = {
						Idstring("units/pd2_dlc_gitgud/characters/ene_zeal_swat/ene_zeal_swat")
					},
					russia = {
						Idstring("units/pd2_dlc_mad/characters/ene_akan_fbi_swat_dw_r870/ene_akan_fbi_swat_dw_r870")
					},
					zombie = {
						Idstring("units/pd2_dlc_hvh/characters/ene_fbi_swat_hvh_2/ene_fbi_swat_hvh_2")
					},
					murkywater = {
						Idstring("units/pd2_dlc_bph/characters/ene_murkywater_light/ene_murkywater_light")
					},
					federales = {
						Idstring("units/pd2_dlc_bex/characters/ene_swat_policia_federale/ene_swat_policia_federale")
					}
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
							rank = 2,
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
							rank = 2,
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
							rank = 2,
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
							rank = 2,
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
							rank = 2,
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
							rank = 2,
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
							rank = 2,
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
							rank = 2,
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
							rank = 2,
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
							rank = 2,
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
							rank = 2,
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
							rank = 2,
							unit = "medic_M4",
							tactics = self._tactics.swat_rifle
						}
					}
				}
			end
			
			log("LIES: Spawngroups successfully fixed.")
			
			self._LIES_fix = true
		end
	end
end

Hooks:PostHook(GroupAITweakData, "_init_chatter_data", "lies_chatter", function(self)
	self.enemy_chatter.go_go = {
		radius = 1000,
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
	self.enemy_chatter.flank = {
		radius = 700,
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
end)