local blockade_ids = {
	run = {
		[103773] = true,
		[103738] = false,
		[100201] = true,
		[100289] = false
	},
	street_new = { --whurr's heat street edit
        [100570] = true,
        [101293] = false,
        [102736] = true,
        [102852] = false,
        [103198] = true,
        [100271] = false
    },
	glace = {
		[103544] = false,
		[100533] = true
	},
	hox_1 = {
		[100504] = false
	},
}
local entirely_unique_stuff = {
	rvd1 = {
		[101653] = function ()
			local blonde_spawn = managers.mission:get_element_by_id(100544)
			
			if blonde_spawn and blonde_spawn.units and blonde_spawn:units() then
				local blondes = blonde_spawn:units()
			
				local pos = Vector3(-124, -5297, 0)
				local seg = managers.navigation:get_nav_seg_from_pos(pos)
				local area = managers.groupai:state():get_area_from_nav_seg_id(seg)
			
				local objective = {
					type = "act",
					stance = "hos",
					haste = "run",
					pos = pos,
					nav_seg = seg,
					forced = true,
					area = area,
					rot = Rotation(-90, 0, -0),
					action = {
						align_sync = true,
						type = "act",
						body_part = 1,
						variant = "e_so_sneak_wait_crh_var2",
						blocks = {
							light_hurt = -1,
							hurt = -1,
							action = -1,
							heavy_hurt = -1,
							act = -1,
							crouch = -1,
							walk = -1
						}
					}
				}
				
				for i = 1, #blondes do
					local unit = blondes[i]
					
					if alive(unit) then
						managers.groupai:state():set_char_team(unit, "neutral1")
						
						unit:brain():set_objective(objective)
					end
				end
			end
		end
	}
}

Hooks:PostHook(MissionScriptElement, "on_executed", "lies_blockade", function(self)
	if not LIES.settings.hhtacs and not Network:is_server() then
		return
	end

	if blockade_ids[Global.level_data.level_id] then
		local on_off = blockade_ids[Global.level_data.level_id]
		
		if on_off[self._id] ~= nil then
			--log("AAAAAAAAAAAA")
			managers.groupai:state()._blockade = on_off[self._id]
		end
	end
	
	if entirely_unique_stuff[Global.level_data.level_id] then
		local stuff = entirely_unique_stuff[Global.level_data.level_id]
		local func = stuff[self._id]
		
		if func then
			func(self)
		end
	end
end)

