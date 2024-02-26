core:module("CoreWorldDefinition")
core:import("CoreUnit")
core:import("CoreMath")
core:import("CoreEditorUtils")
core:import("CoreEngineAccess")
WorldDefinition = WorldDefinition or class()

local adjust_ids = {
	wwh = {
		[101234] = true, --very cheesable visblocker that just kinda gets in the way of everything
	},
	des = {
		--entryway
		[102258] = true,
		[102260] = true,
		--dear god the entry way walkway.
		[101815] = true,
		[101841] = true,
		[101863] = true,
		[101869] = true,
		[101873] = true,
		[101902] = true,
		[101904] = true,
		[101907] = true,
		[101916] = true,
		[101917] = true,
		[101922] = true,
		[101931] = true,
		[101932] = true,
		[102032] = true,
		[102053] = true,
		[101818] = true,
		[101860] = true,
		[101864] = true,
		[101872] = true,
		[101901] = true,
		[101903] = true,
		[101906] = true,
		[101901] = true,
		[102057] = true,
		[102060] = true,
		[102072] = true,
		[102073] = true,
		[101904] = true,
		
		[101603] = true,
		[101604] = true,
		[101605] = true,
		[101606] = true,
		[101607] = true,
		[101608] = true,
		[101612] = true,
		[101704] = true,
		[101709] = true,
		[101710] = true,
		[101776] = true,
		[101785] = true,
		[101643] = true,
		[101648] = true,
		[101653] = true,
		[101654] = true,
		[101655] = true,
		[101661] = true,
		[101663] = true,
		[101664] = true,
		[101668] = true,
		[101675] = true,
		[101676] = true,
		[101684] = true,
		[101685] = true,
		[101703] = true,
		[101809] = true,
		[101812] = true,
		
		--box room walkways
		[102265] = true,
		[102266] = true,
		[102274] = true,
		[102275] = true,
		[102276] = true,
		[102277] = true,
		[102293] = true,
		
		[102269] = true,
		[102270] = true,
		[102271] = true,
		[102272] = true,
		[102273] = true,
		[102282] = true,
		[102283] = true,
		[102284] = true,
		[102285] = true,
		[102286] = true,
		[102292] = true,
		
		--IT room
		[102294] = true,
		[102295] = true,
		[102297] = true,
		[102298] = true,
		
		--archives
		[101237] = true,
		[101238] = true,
		[101258] = true,
		[101259] = true,
		
		[101260] = true,
		[101261] = true,
		[102184] = true,
		[102192] = true,
		[102193] = true,

		--biolab
		[102198] = true,
		[102199] = true,
		[102240] = true,
		[102241] = true,
		
		[102245] = true,
		[102246] = true,
		[102247] = true,
		[102253] = true,
		[102255] = true,
		[102256] = true,
		
		--weapons lab
		[101672] = true,
		
		[102243] = true,
		[102244] = true,
		[102330] = true,
		--fucking weapons lab walkway
		[102242] = true,
		[102342] = true,
		[102344] = true,
		[102344] = true,
		[102345] = true,
		[102350] = true,
		[102577] = true,
		[103056] = true,
		[103102] = true,
		[103268] = true,
		[103269] = true,
		[103270] = true,
		[103271] = true,
		[103272] = true,
		[103273] = true,
		[103274] = true,
	
	}
}



Hooks:PostHook(WorldDefinition, "assign_unit_data", "lies_fix_dumb_map_stuff", function(self, unit, data)
	if Global.load_level == true and adjust_ids[Global.level_data.level_id] then
		local to_adjust = adjust_ids[Global.level_data.level_id]
		
		if to_adjust[unit:unit_data().unit_id] then
			local params = to_adjust[unit:unit_data().unit_id]
			
			--log("SCRINDONGULODED")
			
			--[[if params.set_position then
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
			end]]--
			
			unit:set_enabled(false)
			
			return
		end
	end
end)