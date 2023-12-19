Hooks:PostHook(CharacterTweakData, "init", "lies_fix_nosup", function(self, tweak_data)
	self:fix_escort()
	
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
	
	self.medic.spawn_sound_event = nil
	
	self.medic.chatter.entrance = "entrance"
	
	self.taser.chatter.entrance = "entrance"
	
	self.tank.chatter.entrance = "entrance"
	self.tank_hw.chatter.entrance = "entrance"
	self.tank_mini.chatter.entrance = "entrance"
	self.tank_medic.chatter.entrance = "entrance"
end)

function CharacterTweakData:fix_escort()
	if self.old_hoxton_mission then
		self.old_hoxton_mission.no_suppressed_reaction = true
		self.old_hoxton_mission.buddy = true
	end
	
	if self.spa_vip then
		self.spa_vip.no_suppressed_reaction = true
		self.spa_vip.buddy = true
	end
end

function CharacterTweakData:_setup_extra_chatter_tweak()
	self.tank_mini.chatter.entrance = "entrance_elite"
	self.tank_medic.chatter.entrance = "entrance_elite"
	
	self.sniper.spawn_sound_event = "mga_deploy_snipers"
	
	self.marshal_marksman.die_sound_event = "mga_death_scream"
	
	self.marshal_shield.chatter = {
		clear = true,
		ready = true,
		contact = true,
		suppress = true,
		smoke = true,
		retreat = true,
		go_go = true,
		aggressive = true,
		follow_me = true
	}
	self.marshal_shield.speech_prefix_p1 = "l5d"
	self.marshal_shield.speech_prefix_p2 = nil
	self.marshal_shield.speech_prefix_count = nil
	self.marshal_shield.die_sound_event = "mga_death_scream"
	
	self.marshal_shield_break.chatter = {
		clear = true,
		ready = true,
		contact = true,
		suppress = true,
		smoke = true,
		retreat = true,
		go_go = true,
		aggressive = true,
		follow_me = true
	}
	
	self.marshal_shield_break.speech_prefix_p1 = "l5d"
	self.marshal_shield_break.speech_prefix_p2 = nil
	self.marshal_shield_break.speech_prefix_count = nil
	self.marshal_shield_break.die_sound_event = "mga_death_scream"
	local ganger = {
		contact = true,
		aggressive = true	
	}
	
	self.gangster.chatter = ganger
	self.mobster.chatter = ganger
	self.biker.chatter = ganger
	self.biker_escape.chatter = ganger
end

local fry_vars = {
	"cop",
	"gensec",
	"cop_scared",
	"cop_female",
	"security",
	"security_mex",
	"security_mex_no_pager",
	"fbi",
	"fbi_female"
}
local swat_vars = {
	"swat",
	"heavy_swat",
	"fbi_swat",
	"fbi_heavy_swat",
	"city_swat"
}


function CharacterTweakData:setup_hhtacs()
	self.tank_mini.throwable = "frag"
	self.drug_lord_boss.throwable = "launcher_frag"
	
	local difficulty = Global.game_settings and Global.game_settings.difficulty or "normal"
	local difficulty_index = tweak_data:difficulty_to_index(difficulty)
	
	for i = 1, #fry_vars do
		local tweak = fry_vars[i]
		
		if self[tweak] then
			self[tweak].safe_weapon = "c45"
		end
	end
	
	local safe_for_swat = difficulty_index > 7 and "deagle" or "c45"
	
	for i = 1, #swat_vars do
		local tweak = swat_vars[i]
		
		if self[tweak] then
			self[tweak].safe_weapon = safe_for_swat
		end
	end
	
	self.medic.safe_weapon = "raging_bull"
	self.spooc.safe_weapon = "beretta92"
	
	if difficulty_index > 5 then
		self.civilian.faster_reactions = true
		self.civilian.submission_max = {30, 60}
		self.civilian.submission_intimidate = 15
		--self.civilian.scare_intimidate = 0
		self.civilian_female.faster_reactions = true
		self.civilian_female.submission_max = {30, 60}
		self.civilian_female.submission_intimidate = 15
		--self.civilian_female.scare_intimidate = -2
		self.civilian_mariachi.faster_reactions = true
		self.civilian_mariachi.submission_max = {30, 60}
		self.civilian_mariachi.submission_intimidate = 15
		--self.civilian_mariachi.scare_intimidate = -2
		self.civilian_no_penalty.faster_reactions = true
		self.civilian_no_penalty.submission_max = {30, 60}
		self.civilian_no_penalty.submission_intimidate = 15
		--self.civilian_no_penalty.scare_intimidate = -2
		self.bank_manager.faster_reactions = true
		self.bank_manager.submission_max = {30, 60}
		self.bank_manager.submission_intimidate = 15
		--self.bank_manager.scare_intimidate = -2
		
		self.tank.enrages = true

		local heavy_adv = {
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
					chance = 1,
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
					chance = 0.75,
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
		
		self.zeal_heavy_swat.dodge = heavy_adv
		self.fbi_heavy_swat.dodge = heavy_adv
		
		local light_adv = {
			speed = 1.6,
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
							shoot_accuracy = 0.8,
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
		
		self.zeal_swat.dodge = light_adv
		self.fbi_swat.dodge = light_adv
		self.city_swat.dodge = light_adv
		self.taser.dodge = light_adv
		self.medic.dodge = light_adv
		
		local ninja_adv = {
			speed = 2,
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
							shoot_accuracy = 1,
							timeout = {
								0,
								0
							}
						},
						roll = {
							chance = 1,
							timeout = {
								0.2,
								0.2
							}
						},
						wheel = {
							chance = 2,
							timeout = {
								0.5,
								0.5
							}
						}
					}
				},
				preemptive = {
					chance = 1,
					check_timeout = {
						0,
						0
					},
					variations = {
						side_step = {
							chance = 3,
							shoot_chance = 1,
							shoot_accuracy = 1,
							timeout = {
								0,
								0
							}
						},
						roll = {
							chance = 1,
							timeout = {
								0.2,
								0.2
							}
						},
						wheel = {
							chance = 2,
							timeout = {
								0.2,
								0.2
							}
						}
					}
				},
				scared = {
					chance = 1,
					check_timeout = {
						0,
						0
					},
					variations = {
						side_step = {
							chance = 5,
							shoot_chance = 1,
							shoot_accuracy = 1,
							timeout = {
								0,
								0
							}
						},
						roll = {
							chance = 3,
							timeout = {
								0.2,
								0.2
							}
						},
						wheel = {
							chance = 3,
							timeout = {
								0.2,
								0.2
							}
						}
					}
				}
			}
		}
		
		self.spooc.dodge = ninja_adv
		self.shadow_spooc.dodge = ninja_adv
	end
end