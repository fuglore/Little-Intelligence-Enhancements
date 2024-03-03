Hooks:PostHook(Drill, "on_sabotage_SO_completed", "lies_drilljammedvoiceline", function(self, saboteur)
	if saboteur then
		if self.is_drill then
			saboteur:sound():say("e05", true)
		else
			saboteur:sound():say("e06", true)
		end
	end
end)

Hooks:PostHook(Drill, "clbk_sabotage_SO_verification", "lies_tacs_drill", function(self, candidate_unit)
	if not LIES.settings.hhtacs then
		return
	end
	
	if candidate_unit:movement():cool() then
		return
	end

	local pos = candidate_unit:movement():nav_tracker():field_position()

	if math.abs(self._nav_tracker:field_position().z - pos.z) < 250 then
		return true
	end
end)

--not sure if i have to overwrite the entire function or not, if someone can tell me a better way to do this, id love to know
function Drill:_register_sabotage_SO()
	if self._sabotage_SO_id or not managers.navigation:is_data_ready() or not self._unit:timer_gui() or not self._unit:timer_gui()._can_jam or not self._sabotage_align_obj_name then
		return
	end

	local field_pos = self._nav_tracker:field_position()
	local field_z = self._nav_tracker:field_z() - 25
	local height = self._pos.z - field_z
	local act_anim = "sabotage_device_" .. (height > 100 and "high" or height > 60 and "mid" or "low")
	local align_obj = self._unit:get_object(Idstring(self._sabotage_align_obj_name))
	local objective_rot = align_obj:rotation()
	local objective_pos = align_obj:position()
	self._SO_area = managers.groupai:state():get_area_from_nav_seg_id(self._nav_tracker:nav_segment())
	--remove an useless followup objective
	local objective = {
		type = "act",
		interrupt_health = 1,
		stance = "hos",
		haste = "run",
		scan = true,
		interrupt_dis = 800,
		nav_seg = self._nav_tracker:nav_segment(),
		area = self._SO_area,
		pos = objective_pos,
		rot = objective_rot,
		sabo_voiceline = self.is_drill and "drillsabotage" or "gearsabotage",
		fail_clbk = callback(self, self, "on_sabotage_SO_failed"),
		complete_clbk = callback(self, self, "on_sabotage_SO_completed"),
		action_start_clbk = callback(self, self, "on_sabotage_SO_started"),
		action = {
			align_sync = true,
			type = "act",
			body_part = 1,
			variant = act_anim,
			blocks = {
				light_hurt = -1,
				action = -1,
				aim = -1
			}
		}
	}
	local so_descriptor = {
		interval = 0,
		search_dis_sq = 1000000,
		AI_group = "enemies",
		base_chance = 1,
		chance_inc = 0,
		usage_amount = 1,
		objective = objective,
		search_pos = field_pos,
		verification_clbk = callback(self, self, "clbk_sabotage_SO_verification"),
		access = managers.navigation:convert_access_filter_to_number({
			"gangster",
			"security",
			"security_patrol",
			"cop",
			"fbi",
			"swat",
			"murky",
			"sniper",
			"spooc",
			"tank",
			"taser"
		}),
		admin_clbk = callback(self, self, "on_sabotage_SO_administered")
	}
	self._sabotage_SO_id = "drill_sabotage" .. tostring(self._unit:key())

	managers.groupai:state():add_special_objective(self._sabotage_SO_id, so_descriptor)
	managers.groupai:state():register_active_drill(self._unit:key(), self._SO_area)
end

Hooks:PostHook(Drill, "_unregister_sabotage_SO", "lies_unregisterdrill", function(self)
	managers.groupai:state():unregister_active_drill(self._unit:key())
end)