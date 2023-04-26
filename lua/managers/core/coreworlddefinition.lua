core:module("CoreWorldDefinition")
core:import("CoreUnit")
core:import("CoreMath")
core:import("CoreEditorUtils")
core:import("CoreEngineAccess")
WorldDefinition = WorldDefinition or class()

local adjust_ids = {
	wwh = {
		[101234] = { --very cheesable visblocker that just kinda gets in the way of everything
			disable = true
		}
	}
}

Hooks:PostHook(WorldDefinition, "assign_unit_data", "lies_fix_dumb_map_stuff", function(self, unit, data)
	if Global.load_level == true and adjust_ids[Global.level_data.level_id] then
		local to_adjust = adjust_ids[Global.level_data.level_id]
		
		if to_adjust[unit:unit_data().unit_id] then
			local params = to_adjust[unit:unit_data().unit_id]
			
			--log("SCRINDONGULODED")
			
			if params.set_position then
				local coords = params.set_position 
				local x = coords.x
				local y = coords.y
				local z = coords.z
				local current_unit_pos
				
				if not x or not y or not z then
					current_unit_pos = unit:position()
					
					x = x or current_unit_pos.x
					y = y or current_unit_pos.y
					z = z or current_unit_pos.z
				end
				
				local new_pos = Vector3(x, y, z)
				
				unit:set_position(new_pos)
				
				return
			end
			
			if params.disable then
				unit:set_enabled(false)
				return
			end
		end
	end
end)