if RequiredScript == "lib/managers/menumanager" then
	_G.LIES = {
		mod_path = ModPath,
		loc_path = ModPath .. "loc/",
		save_path = SavePath .. "LittleIntelligenceEnhancementS.txt",
		default_loc_path = ModPath .. "loc/en.txt",
		options_path = ModPath .. "menu/options.txt",
		version = "V8.56",
		settings = {
			lua_cover = false,
			jokerhurts = false,
			extra_chatter = true,
			enemy_aggro_level = 2,
			enemy_reaction_level = 1,
			enemy_travel_level = 1,
			fixed_spawngroups = 1,
			copsretire = false,
			nav_link_interval = 1,
			coplimit = 1,
			interruptoncontact = true,
			teamaihelpers = true,
			spawngroupdelays = 1,
			hhtacs = false,
			highperformance = false
		}
	}
	LIES.update_url = "https://raw.githubusercontent.com/fuglore/Little-Intelligence-Enhancements/auto-updates/autoupdate.json"

	TheFixesPreventer = TheFixesPreventer or {}
	TheFixesPreventer.fix_hostages_not_moving = true
	TheFixesPreventer.crash_no_unit_type_aistatebesiege = true
	TheFixesPreventer.crash_criminal_obj_complete_aistatebase = true
	TheFixesPreventer.crash_upd_aim_coplogicattack = true
	TheFixesPreventer.crash_aim_allow_fire_coplogicattack = true
	TheFixesPreventer.civvie_goes_to_player = true

	function LIES:tprint(tbl, indent, depth)
		depth = depth or 2
		indent = indent or 0
		local toprint = string.rep(" ", indent) .. "{\r\n"
		indent = indent + 2
		
		if type(tbl) ~= "table" then
			toprint = "type is not table, type is " .. type(tbl) .. " with value of " .. tostring(tbl)
			
			return toprint
		else
			for k, v in pairs(tbl) do
				toprint = toprint .. string.rep(" ", indent)

				if type(k) == "number" then
					toprint = toprint .. "[" .. k .. "] = "
				elseif type(k) == "string" then
					toprint = toprint .. k .. "= "
				end

				if type(v) == "number" then
					toprint = toprint .. v .. ",\r\n"
				elseif type(v) == "string" then
					toprint = toprint .. "\"" .. v .. "\",\r\n"
				elseif type(v) == "table" then
					if depth > 0 then
						toprint = toprint .. LIES:tprint(v, indent, depth - 1) .. ",\r\n"
					end
				else
					toprint = toprint .. "\"" .. tostring(v) .. "\",\r\n"
				end
			end
		end

		toprint = toprint .. string.rep(" ", indent - 2) .. "}"

		return toprint
	end

	function LIES:UseLuaCover()
		return self.settings.lua_cover
	end

	function LIES:Load()
		local file = io.open(LIES.save_path, "r")

		if file then
			for k, v in pairs(json.decode(file:read("*all"))) do
				LIES.settings[k] = v
			end
		else
			LIES:Save()
		end
	end

	function LIES:Save()
		local file = io.open(LIES.save_path,"w+")

		if file then
			file:write(json.encode(LIES.settings))
			file:close()
		end
	end
	
	local mvec3_cpy = mvector3.copy
	
	function LIES:find_cover_in_cone_from_threat_pos_1(threat_pos, furthest_pos, near_pos, search_from_pos, angle, min_dis, nav_seg, optimal_threat_dis, rsrv_filter)
		local copied_threat_pos = threat_pos and mvec3_cpy(threat_pos) or nil
		
		return managers.navigation:_find_cover_through_lua(copied_threat_pos, near_pos, furthest_pos, min_dis, search_from_pos)
	end

	function LIES:find_cover_in_nav_seg_3(nav_seg_id, max_near_dis, near_pos, threat_pos)
		local copied_threat_pos = threat_pos and mvec3_cpy(threat_pos) or nil

		return managers.navigation:_find_cover_in_seg_through_lua(copied_threat_pos, near_pos, nav_seg_id)
	end

	function LIES:find_cover_from_threat(nav_seg_id, optimal_threat_dis, near_pos, threat_pos)
		local copied_threat_pos = threat_pos and mvec3_cpy(threat_pos) or nil

		return managers.navigation:_find_cover_in_seg_through_lua(threat_pos, near_pos, nav_seg_id)
	end
	
	function LIES:find_cover_near_pos_1(near_pos, threat_pos, max_near_dis, min_threat_dis, allow_fwd)
		local copied_threat_pos = threat_pos and mvec3_cpy(threat_pos) or nil
		
		return managers.navigation:_find_cover_through_lua(copied_threat_pos, near_pos, nil, min_threat_dis, nil, max_near_dis)
	end
	
	function LIES:find_cover_away_from_pos(near_pos, threat_pos, nav_seg_id)
		local copied_threat_pos = threat_pos and mvec3_cpy(threat_pos) or nil
		
		return managers.navigation:_find_cover_in_seg_through_lua(copied_threat_pos, near_pos, nav_seg_id)
	end

	function LIES:_path_is_straight_line(pos_from, pos_to, u_data)
		if not pos_from.z then
			if alive(pos_from) then
				pos_from = CopActionWalk._nav_point_pos(pos_from:script_data())
			else
				return
			end
		end
		
		if not pos_to.z then
			if alive(pos_to) then
				pos_to = CopActionWalk._nav_point_pos(pos_to:script_data())
			else
				return
			end
		end

		if math.abs(pos_from.z - pos_to.z) > 60 then 
			return
		end
		
		local ray = CopActionWalk._chk_shortcut_pos_to_pos(pos_from, pos_to)

		return not ray 
	end
	
	function LIES:_optimize_path(path, u_data)		
		if #path <= 2 then
			return path
		end

		local opt_path = {}
		local nav_path = {}
		
		for i = 1, #path do
			local nav_point = path[i]

			if nav_point.x then
				nav_path[#nav_path + 1] = nav_point
			elseif alive(nav_point) then
				nav_path[#nav_path + 1] = {
					element = nav_point:script_data().element,
					c_class = nav_point
				}
			else
				return path
			end
		end
		
		nav_path = CopActionWalk._calculate_simplified_path(path[1], nav_path, 1, true, true)
		
		for i = 1, #nav_path do
			local nav_point = nav_path[i]
			
			if nav_point.c_class then
				opt_path[#opt_path + 1] = nav_point.c_class
			else
				opt_path[#opt_path + 1] = nav_point
			end
		end

		return opt_path
	end

	function LIES:check_for_updates()
		dohttpreq(self.update_url, function(json_data, http_id)
			self:set_update_data(json_data)
		end)
	end
	
	function LIES:set_update_data(json_data)
		if json_data:is_nil_or_empty() then
			return
		end
		
		local received_data = json.decode(json_data)
		
		for _, data in pairs(received_data) do
			if data.version then
				LIES.received_version = data.version
				log("LIES: Received update data.")
				break
			end
		end
	end
	
	Hooks:Add("LocalizationManagerPostInit", "LocalizationManagerPostInit_LIES", function( loc )
		loc:load_localization_file( LIES.default_loc_path)
	end)
	
	--add the menu callbacks for when menu options are changed
	Hooks:Add( "MenuManagerInitialize", "MenuManagerInitialize_LIES", function(menu_manager)		
		MenuCallbackHandler.callback_lies_lua_cover = function(self, item)
			local value = item:value()
			LIES.settings.lua_cover = value
			
			if managers.navigation then
				managers.navigation:_change_funcs()
			end
			
			LIES:Save()
		end
		
		MenuCallbackHandler.callback_lies_extra_chatter = function(self, item)
			local on = item:value() == "on"
			LIES.settings.extra_chatter = on

			LIES:Save()
		end
		
		MenuCallbackHandler.callback_lies_jokerhurts = function(self, item)
			local on = item:value() == "on"
			LIES.settings.jokerhurts = on

			LIES:Save()
		end
		
		MenuCallbackHandler.callback_lies_enemy_aggro_level = function(self, item)
			local value = item:value()
			LIES.settings.enemy_aggro_level = value

			LIES:Save()
		end
		
		MenuCallbackHandler.callback_lies_enemy_travel_level = function(self, item)
			local value = item:value()
			LIES.settings.enemy_travel_level = value

			LIES:Save()
		end
		
		MenuCallbackHandler.callback_lies_enemy_reaction_level = function(self, item)
			local value = item:value()
			LIES.settings.enemy_reaction_level = value

			LIES:Save()
		end
		
		MenuCallbackHandler.callback_lies_fixed_spawngroups = function(self, item)
			local value = item:value()
			LIES.settings.fixed_spawngroups = value
			
			LIES.smg_groups = nil

			LIES:Save()
		end

		MenuCallbackHandler.callback_lies_copsretire = function(self, item)
			local on = item:value() == "on"
			LIES.settings.copsretire = on

			LIES:Save()
		end
		
		MenuCallbackHandler.callback_lies_teamaihelpers = function(self, item)
			local on = item:value() == "on"
			LIES.settings.teamaihelpers = on

			LIES:Save()
		end
		
		MenuCallbackHandler.callback_lies_nav_link_interval = function(self, item)
			local value = item:value()
			LIES.settings.nav_link_interval = value

			LIES:Save()
		end
		
		MenuCallbackHandler.callback_lies_coplimit = function(self, item)
			local value = item:value()
			LIES.settings.coplimit = value

			LIES:Save()
		end
		
		MenuCallbackHandler.callback_lies_interruptoncontact = function(self, item)
			local on = item:value() == "on"
			LIES.settings.interruptoncontact = on

			LIES:Save()
		end
		
		MenuCallbackHandler.callback_lies_spawngroupdelays = function(self, item)
			local value = item:value()
			LIES.settings.spawngroupdelays = value

			LIES:Save()
		end
		
		MenuCallbackHandler.callback_lies_hhtacs = function(self, item)
			local on = item:value() == "on"
			LIES.settings.hhtacs = on

			LIES:Save()
		end
		
		MenuCallbackHandler.callback_lies_highperformance = function(self, item)
			local on = item:value() == "on"
			LIES.settings.highperformance = on
			log("high performance mode: "..tostring(LIES.settings.highperformance))

			LIES:Save()
		end
		
		--called when the menu is closed
		MenuCallbackHandler.callback_lies_close = function(self)
		end

		--load settings from user's mod settings txt
		LIES:Load()
		
		if type(LIES.settings.spawngroupdelays) ~= "number" then
			log("LIES: Thanks for downloading the newest version. <3")
			LIES.settings.spawngroupdelays = LIES.settings.spawngroupdelays == true and 2 or 1
			
			LIES:Save()
		end
		
		if type(LIES.settings.fixed_spawngroups) ~= "number" then
			log("LIES: Thanks for downloading the newest version. <3")
			LIES.settings.fixed_spawngroups = 1
			
			LIES:Save()
		elseif LIES.settings.fixed_spawngroups > 2 then
			log("LIES: Thanks for downloading the newest version. <3")
			LIES.settings.fixed_spawngroups = 1
			
			LIES:Save()
		end
		
		if type(LIES.settings.lua_cover) ~= "number" then
			log("LIES: Thanks for downloading the newest version. <3")
			LIES.settings.lua_cover = LIES.settings.lua_cover == true and 2 or 1
			
			LIES:Save()
		elseif LIES.settings.lua_cover > 2 then
			log("LIES: Thanks for downloading the newest version. <3")
			LIES.settings.lua_cover = 2
			
			LIES:Save()
		end

		--create menus
		MenuHelper:LoadFromJsonFile(LIES.options_path, LIES, LIES.settings)
		
		if not Global.checked_for_updates_lies then
			log("LIES: Checking for update data.")
			LIES:check_for_updates()
			Global.checked_for_updates_lies = true
		end
	end)
end
