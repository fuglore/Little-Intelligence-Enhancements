Hooks:PostHook(CharacterTweakData, "init", "lies_fix_nosup", function(self, tweak_data)
	self:fix_no_supress()
	
	self.security.chatter.contact = nil
	self.security.chatter.criminalhasgun = true
	self.security_undominatable.chatter.contact = nil
	self.security_undominatable.chatter.criminalhasgun = true
	self.security_mex.chatter.contact = nil
	self.security_mex.chatter.criminalhasgun = true
	self.security_mex_no_pager.chatter.contact = nil
	self.security_mex_no_pager.chatter.criminalhasgun = true
	self.gensec.chatter.contact = nil
	self.gensec.chatter.criminalhasgun = true
end)

function CharacterTweakData:fix_no_supress()
	if self.medic then
		self.medic.no_suppressed_reaction = true
	end
	
	if self.inside_man then
		self.inside_man.no_suppressed_reaction = true
	end
	
	if self.old_hoxton_mission then
		self.old_hoxton_mission.no_suppressed_reaction = true
		self.old_hoxton_mission.buddy = true
	end
	
	if self.spa_vip then
		self.spa_vip.no_suppressed_reaction = true
		self.spa_vip.buddy = true
	end
end

function CharacterTweakData:setup_hhtacs()
	self.tank_mini.throwable = "frag"
	self.drug_lord_boss.throwable = "launcher_frag"
	
	local difficulty = Global.game_settings and Global.game_settings.difficulty or "normal"
	local difficulty_index = tweak_data:difficulty_to_index(difficulty)
	
	if difficulty_index > 5 then
		self.tank.enrages = true

		local heavy_adv = {
			speed = 1,
			occasions = {
				hit = {
					chance = 0.75,
					check_timeout = {
						0,
						0
					},
					variations = {
						side_step = {
							chance = 2,
							shoot_chance = 0.8,
							shoot_accuracy = 0.5,
							timeout = {
								2,
								4
							}
						},
						roll = {
							chance = 1,
							timeout = {
								2,
								4
							}
						}
					}
				},
				preemptive = {
					chance = 0.7,
					check_timeout = {
						0,
						0
					},
					variations = {
						side_step = {
							chance = 1,
							shoot_chance = 1,
							shoot_accuracy = 0.7,
							timeout = {
								1,
								2
							}
						}
					}
				},
				scared = {
					chance = 0.8,
					check_timeout = {
						0,
						0
					},
					variations = {
						side_step = {
							chance = 3,
							shoot_chance = 0.5,
							shoot_accuracy = 0.4,
							timeout = {
								1,
								2
							}
						},
						roll = {
							chance = 1,
							timeout = {
								8,
								10
							}
						},
						dive = {
							chance = 2,
							timeout = {
								8,
								10
							}
						}
					}
				}
			}
		}
		
		self.heavy_swat.dodge = heavy_adv
		self.fbi_heavy_swat.dodge = heavy_adv
		
		local light_adv = {
			speed = 1.3,
			occasions = {
				hit = {
					chance = 1,
					check_timeout = {
						0,
						0
					},
					variations = {
						side_step = {
							chance = 3,
							shoot_chance = 1,
							shoot_accuracy = 0.5,
							timeout = {
								0.2,
								1
							}
						},
						roll = {
							chance = 2,
							timeout = {
								0.2,
								1
							}
						}
					}
				},
				preemptive = {
					chance = 0.7,
					check_timeout = {
						0,
						0
					},
					variations = {
						side_step = {
							chance = 3,
							shoot_chance = 1,
							shoot_accuracy = 0.7,
							timeout = {
								0.2,
								1
							}
						},
						roll = {
							chance = 1,
							timeout = {
								0.2,
								1
							}
						}
					}
				},
				scared = {
					chance = 0.75,
					check_timeout = {
						0,
						0
					},
					variations = {
						side_step = {
							chance = 5,
							shoot_chance = 1,
							shoot_accuracy = 0.8,
							timeout = {
								0.2,
								1
							}
						},
						roll = {
							chance = 3,
							timeout = {
								0.2,
								1
							}
						}
					}
				}
			}
		}
		
		self.swat.dodge = light_adv
		self.fbi_swat.dodge = light_adv
		self.city_swat.dodge = light_adv
		self.taser.dodge = light_adv
		self.medic.dodge = light_adv
	end
end