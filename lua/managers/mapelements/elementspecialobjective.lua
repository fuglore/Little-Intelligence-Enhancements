local adjust_ids = {
	wwh = { --use comments to keep track of what im modifying here so i dont forget what i did or why
		[100796] = { --superduper broken anim for climbing up near the alaskan deal sheds
			new_pos = Vector3(5552.89, 2805.31, 1153),
			new_search_pos = Vector3(5992, 2749, 1568),
			new_rotation = Rotation(-137, 0, -0),
			new_action = "e_nl_up_4m"
		}
	},
	red2 = { --so many defend and hunt SOs...LET THE AI DO THEIR THING!!!
		[103369] = {
			disable = true
		},
		[103370] = {
			disable = true
		},
		[103375] = {
			disable = true
		},
		[103066] = {
			disable = true
		},
		[100335] = {
			disable = true
		},
		[103065] = {
			disable = true
		},
		[102584] = {
			disable = true
		},
		[100345] = {
			disable = true
		},
		[100697] = {
			disable = true
		},
		[103368] = {
			disable = true
		},
		[103372] = {
			disable = true
		},
		[100557] = {
			disable = true
		},
		[100653] = {
			disable = true
		},
		[100656] = {
			disable = true
		},
		[100679] = {
			disable = true
		},
		[100681] = {
			disable = true
		},
		[100846] = {
			disable = true
		},
		[100852] = {
			disable = true
		},
		[100853] = {
			disable = true
		},
		[100854] = {
			disable = true
		},
		[100890] = {
			disable = true
		},
		[106545] = {
			disable = true
		},
	},
	rvd1 = {
		[100449] = {
			action_duration = {20, 20}
		},
		[100026] = {
			trigger_on = "none"
		}
	},
	bph = {
		[102181] = { --some badly set access filters result in team ai and jokers climbing up a specific window in the washing machine room, but not being able to climb down
			override_access_filter = {
				"cop",
				"security_patrol",
				"shield",
				"tank",
				"security",
				"gangster",
				"swat",
				"fbi",
				"taser",
				"sniper",
				"murky",
				"spooc"
			}
		},
		[102373] = {
			override_access_filter = {
				"cop",
				"security_patrol",
				"shield",
				"tank",
				"security",
				"gangster",
				"swat",
				"fbi",
				"taser",
				"sniper",
				"murky",
				"spooc"
			}
		}
	},
	glace = { --civilian start up SO
		[100187] = {
			change_interrupt_dis = false
		}
	},
	born = { --biker idle SOs, NIGHTMARE NIGHTMARE NIGHTMARE
		[100085] = {
			interrupt_objective = true
		},
		[100529] = {
			interrupt_objective = true
		},
		[101422] = {
			interrupt_objective = true
		},
		[100572] = {
			interrupt_objective = true
		},
		[101418] = {
			interrupt_objective = true
		},
		[101120] = {
			interrupt_objective = true
		},
		[101423] = {
			interrupt_objective = true
		},
		[101657] = {
			interrupt_objective = true
		},
		[102431] = {
			interrupt_objective = true
		},
		[100086] = {
			interrupt_objective = true
		},
		[100076] = {
			interrupt_objective = true
		},
		[102479] = {
			interrupt_objective = true
		},
		[100403] = {
			interrupt_objective = true
		},
		[100084] = {
			interrupt_objective = true
		},
		[100083] = {
			interrupt_objective = true
		},
		[100528] = {
			interrupt_objective = true
		},
		[100534] = {
			interrupt_objective = true
		},
		[101424] = {
			interrupt_objective = true
		},
		[101655] = {
			interrupt_objective = true
		},
		[100545] = {
			interrupt_objective = true
		},
		[100547] = {
			interrupt_objective = true
		},
		[100548] = {
			interrupt_objective = true
		},
		[100549] = {
			interrupt_objective = true
		},
		[100150] = {
			interrupt_objective = true
		},
		[102439] = {
			interrupt_objective = true
		},
		[102443] = {
			interrupt_objective = true
		},
		[102449] = {
			interrupt_objective = true
		},
		[102452] = {
			interrupt_objective = true
		},
		[102454] = {
			interrupt_objective = true
		},
	}
}

local hhtacs_adjust = {
	rvd1 = {
		[100449] = {
			followup_elements = {100026}
		}
	}
}

Hooks:PostHook(ElementSpecialObjective, "_finalize_values", "lies_send_navlink_element", function(self)
	if adjust_ids[Global.level_data.level_id] then
		local to_adjust = adjust_ids[Global.level_data.level_id]
		
		if to_adjust[self._id] then
			local params = to_adjust[self._id]
			
			if params.align_full then
				self._values.align_position = true
				self._values.align_rotation = true
			end
			
			if params.trigger_on then
				self._values.trigger_on = params.trigger_on
			end
			
			if params.new_pos then
				self._values.position = params.new_pos
			end
			
			if params.disable then
				self._values.enabled = false
			end
			
			if params.new_rotation then
				self._values.rotation = mrotation.yaw(params.new_rotation)
			end
			
			if params.new_search_pos then
				self._values.search_position = params.new_search_pos
			end
			
			if params.action_duration then
				self._values.action_duration_min = params.action_duration[1]
				self._values.action_duration_max = params.action_duration[2]
			end
			
			if params.new_action then
				self._values.so_action = params.new_action
			end
			
			if params.override_access_filter then
				self._values.SO_access = managers.navigation:convert_access_filter_to_number(params.override_access_filter)
			end
			
			if params.change_interrupt_dis ~= nil then
				self._values.interrupt_dis = params.change_interrupt_dis
			end
			
			if params.interrupt_objective ~= nil then
				self._values.interrupt_objective = params.interrupt_objective
			end
			
			--log("SCRONGBONGLED")
		end
	end
	
	if LIES.settings.hhtacs and hhtacs_adjust[Global.level_data.level_id] then
		local to_adjust = hhtacs_adjust[Global.level_data.level_id]
		
		if to_adjust[self._id] then
			local params = to_adjust[self._id]

			if params.followup_elements then
				self._values.followup_elements = params.followup_elements
			end
			
			--log("SCRONGBONGLED")
		end
	end
	
	if self._values.so_action == "e_so_ntl_smoke_stand" then --this smoking action has a much too long exit animation for loud gameplay
		self._values.so_action = "e_so_ntl_look_around"
	end

	if self:_is_nav_link() then
		managers.navigation._LIES_navlink_elements[self._id] = self
	end
	
	local is_AI_SO = self._is_AI_SO or string.begins(self._values.so_action, "AI")
	
	if not is_AI_SO and self._values.path_stance ~= "hos" and self._values.path_stance ~= "cbt" and (self._values.patrol_path or self._values.position) and self._values.path_style ~= "precise" and not self._values.forced then
		self._stealth_patrol = true
	end
end)

function ElementSpecialObjective:nav_link_delay()
	local original_value = self:_get_default_value_if_nil("interval")
	
	if original_value > 3 then
		original_value = 3
	end
	
	return original_value
end

function ElementSpecialObjective:clbk_verify_administration(unit)
	if self._values.needs_pos_rsrv then
		self._tmp_pos_rsrv = self._tmp_pos_rsrv or {
			radius = 30,
			position = self._values.position
		}
		local pos_rsrv = self._tmp_pos_rsrv
		pos_rsrv.filter = unit:movement():pos_rsrv_id()

		if not managers.navigation:is_pos_free(pos_rsrv) then
			return false
		end
	end
	
	local is_AI_SO = self._is_AI_SO or string.begins(self._values.so_action, "AI")
	
	local is_scripted_AI_SO = {
		AI_escort = true,
		AI_sniper = true,
		AI_phalanx = true,
		AI_idle = true
	}
	
	if is_AI_SO and not is_scripted_AI_SO[self._values.so_action] and unit:brain() and not self._stealth_patrol then
		local group_type = unit:brain()._logic_data and unit:brain()._logic_data.group and unit:brain()._logic_data.group.type
		
		if group_type ~= "custom" or unit:brain():objective() and unit:brain():objective().type ~= "free" or unit:brain():objective() and unit:brain():objective().grp_objective then
			return false
		end
	end
	
	if self._stealth_patrol and managers.groupai:state():whisper_mode() or self._values.path_style == "destination" then
		if unit:movement()._nav_tracker and unit:brain():SO_access() then
			local to_pos = self._values.position
			
			if not to_pos then
				local path_data = managers.ai_data:patrol_path(self._values.patrol_path)
				
				local points = path_data.points
				to_pos = points[#points].position
			end
			
			if to_pos then
				local to_seg = managers.navigation:get_nav_seg_from_pos(to_pos, true)
				
				if unit:movement():nav_tracker() and unit:movement():nav_tracker():nav_segment() ~= to_seg then				
					local search_params = {
						id = "ESO_coarse_" ..  self._id .. tostring(unit:key()),
						from_tracker = unit:movement():nav_tracker(),
						to_seg = to_seg,
						to_pos = to_pos,
						access_pos = unit:brain():SO_access()
					}
					local coarse_path = managers.navigation:search_coarse(search_params)
					
					if not coarse_path then
						return false
					end
				end
			end
		end
	end

	return true
end