local nav_fixes_on_executed = {
	wwh = { --alaskan deal traincar doors fix
		[100944] = function (self)
			local nav_obstacle_info = {
				{
					pos = Vector3(4978, -1786, 1374.61)
				},
				{
					pos = Vector3(3372, -1786, 1374.61)
				}
			}
			
			local rotation = Rotation(-90, 0, -0)
			local nav_obstacle_unit = Idstring("units/dev_tools/level_tools/dev_door_blocker/dev_door_blocker_1x4x3")
			local obstacle_obj_name = Idstring("rp_dev_door_blocker_1x4x3")
			local disable_obstacles = managers.mission:get_element_by_id(100945)
			
			for i = 1, #nav_obstacle_info do
				local obstacle_info = nav_obstacle_info[i]
				local obstacle_unit = World:spawn_unit(nav_obstacle_unit, obstacle_info.pos, rotation)
				
				managers.navigation:add_obstacle(obstacle_unit, obstacle_obj_name)
				
				if not disable_obstacles._obstacle_units or #disable_obstacles._obstacle_units == 0 then
					disable_obstacles._obstacle_units = {}
				end
				
				table.insert(disable_obstacles._obstacle_units, {
					unit = obstacle_unit,
					obj_name = obstacle_obj_name
				})
				
				obstacle_unit:set_visible(false)
			end
		end,
		[100945] = function(self)
			if self._obstacle_units then
				for _, data in ipairs(self._obstacle_units) do
					managers.navigation:remove_obstacle(data.unit, data.obj_name)
				end
			end
		end
	},
	pal = { --counterfeit wilson's house table and swat van fixes
		[100292] = function (self)
			local nav_obstacle_info = {
				{
					pos = Vector3(-2085, -280, 26.7)
				},
				{
					pos = Vector3(-2085, -351, 26.7)
				},
				{
					pos = Vector3(-2223, -291, 26.7)
				},
				{
					pos = Vector3(-2223, -360, 26.7)
				},
			}
			
			local nav_obstacle_unit = Idstring("units/dev_tools/level_tools/dev_door_blocker/dev_door_blocker_1x1x3")
			local rotation = Rotation(0, 0, -0)
			local disable_obstacles = managers.mission:get_element_by_id(101797)
			local obstacle_obj_name = Idstring("rp_dev_door_blocker_1x1x3")
			
			for i = 1, #nav_obstacle_info do
				local obstacle_info = nav_obstacle_info[i]
				local obstacle_unit = World:spawn_unit(nav_obstacle_unit, obstacle_info.pos, rotation)
				
				managers.navigation:add_obstacle(obstacle_unit, obstacle_obj_name)
				
				table.insert(disable_obstacles._obstacle_units, {
					unit = obstacle_unit,
					obj_name = obstacle_obj_name
				})
				
				obstacle_unit:set_visible(false)
			end
		end,
		[101797] = function (self)
			local nav_obstacle_info = {
				{
					pos = Vector3(-2085, -280, 26.7)
				},
				{
					pos = Vector3(-2085, -351, 26.7)
				},
				{
					pos = Vector3(-2223, -291, 26.7)
				}
			}
			
			local rotation = Rotation(20, 0, -0)
			local nav_obstacle_unit = Idstring("units/dev_tools/level_tools/dev_door_blocker/dev_door_blocker_1x1x3")
			
			for i = 1, #nav_obstacle_info do
				local obstacle_info = nav_obstacle_info[i]
				local obstacle_unit = World:spawn_unit(nav_obstacle_unit, obstacle_info.pos, rotation)
				
				managers.navigation:add_obstacle(obstacle_unit, Idstring("rp_dev_door_blocker_1x1x3"))
				
				obstacle_unit:set_visible(false)
			end
		end
	},
}

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
	},
	wwh = {
		[100683] = function ()
			local valid_diffs = {
				overkill_290 = true,
				sm_wish = true
			}
			
			--log(tostring(Global.game_settings.difficulty))
		
			if not valid_diffs[Global.game_settings.difficulty] then
				return
			end
		
			local t = managers.groupai:state()._t
			
			local func = function()
				local van = managers.worlddefinition:get_unit(100677)
				
				if van and alive(van) and van:damage() then
					if van:damage():has_sequence("turret_spawn") then
						van:damage():run_sequence_simple("turret_spawn")
						van:damage():run_sequence_simple("turret_activate")
					end
				end
			end
			
			managers.enemy:add_delayed_clbk("wwh_van_turret", func, t + 10)
		end
	},
}

Hooks:PostHook(MissionScriptElement, "on_executed", "lies_nav_and_modify", function(self)
	if not self._values.enabled then
		return
	end

	if nav_fixes_on_executed[Global.level_data.level_id] then
		local stuff = nav_fixes_on_executed[Global.level_data.level_id]
		local func = stuff[self._id]
		
		if func then
			func(self)
		end
	end

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

