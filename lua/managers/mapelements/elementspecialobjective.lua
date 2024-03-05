local adjust_ids = {
	wwh = { --use comments to keep track of what im modifying here so i dont forget what i did or why
		[100796] = { --superduper broken anim for climbing up near the alaskan deal sheds
			new_pos = Vector3(5552.89, 2805.31, 1153),
			new_search_pos = Vector3(5992, 2749, 1568),
			new_rotation = Rotation(-137, 0, -0),
			new_action = "e_nl_up_4m"
		}
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
	
	if not is_AI_SO and not self._stealth_patrol and self._values.trigger_on == nil and not self._values.allow_followup_self then
		self._values.trigger_on = "none"
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
	
	if self._stealth_patrol and managers.groupai:state():whisper_mode() or not self._values.patrol_path and self._values.path_style == "destination" then
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

function ElementSpecialObjective:choose_followup_SO(unit, skip_element_ids)
	if not self._values.followup_elements then
		return
	end

	if skip_element_ids == nil then
		if self._values.allow_followup_self and self:enabled() and (not LIES.settings.hhtacs or not self._stealth_patrol) then
			skip_element_ids = {}
		else
			skip_element_ids = {
				[self._id] = true
			}
		end
	end

	if self._values.SO_access and unit and not managers.navigation:check_access(self._values.SO_access, unit:brain():SO_access(), 0) then
		return
	end

	local total_weight = 0
	local pool = {}

	for _, followup_element_id in ipairs(self._values.followup_elements) do
		local weight = nil
		local followup_element = managers.mission:get_element_by_id(followup_element_id)

		if followup_element:enabled() then
			followup_element, weight = followup_element:get_as_followup(unit, skip_element_ids)

			if followup_element and followup_element:enabled() and weight > 0 then
				table.insert(pool, {
					element = followup_element,
					weight = weight
				})

				total_weight = total_weight + weight
			end
		end
	end

	if not next(pool) or total_weight <= 0 then
		if self._stealth_patrol and managers.groupai:state():whisper_mode() then --we have followup elements...but none of them are accessible...aaaaa repeat!!!
			local weight
			local followup_element = managers.mission:get_element_by_id(self._id)
			followup_element, weight = followup_element:get_as_followup(unit, {})
			
			return followup_element
		end

		return
	end

	local lucky_w = math.random() * total_weight
	local accumulated_w = 0

	for i, followup_data in ipairs(pool) do
		accumulated_w = accumulated_w + followup_data.weight

		if lucky_w <= accumulated_w then
			return pool[i].element
		end
	end
end