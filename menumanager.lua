if RequiredScript == "lib/managers/menumanager" then
	_G.LIES = {
		mod_path = ModPath,
		loc_path = ModPath .. "loc/",
		save_path = SavePath .. "LittleIntelligenceEnhancementS.txt",
		default_loc_path = ModPath .. "loc/en.txt",
		options_path = ModPath .. "menu/options.txt",
		version = "V2contact",
		settings = {
			lua_cover = false,
			enemy_aggro_level = 2,
			fixed_spawngroups = 1,
			copsretire = false,
			interruptoncontact = false
		}
	}
	LIES.update_url = "https://raw.githubusercontent.com/fuglore/Little-Intelligence-Enhancements/auto-updates/autoupdate.json"

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
		
		return managers.navigation:_find_cover_through_lua(copied_threat_pos, near_pos, furthest_pos, min_dis)
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
		
		return managers.navigation:_find_cover_through_lua(copied_threat_pos, near_pos, nil, min_threat_dis, max_near_dis)
	end
	
	function LIES:find_cover_away_from_pos(near_pos, threat_pos, nav_seg_id)
		local copied_threat_pos = threat_pos and mvec3_cpy(threat_pos) or nil
		
		return managers.navigation:_find_cover_in_seg_through_lua(copied_threat_pos, near_pos, nav_seg_id)
	end
	
	local function spawn_group_id(spawn_group)
		return spawn_group.mission_element:id()
	end
	
	function LIES:_choose_best_groups(best_groups, group, group_types, allowed_groups)
		local total_weight = 0

		local previous_chosen_types = managers.groupai:state()._previous_chosen_types
		
		for _, group_type in ipairs(group_types) do
			if tweak_data.group_ai.enemy_spawn_groups[group_type] then
				local group_tweak = tweak_data.group_ai.enemy_spawn_groups[group_type]
				local special_type, spawn_limit, current_count = nil
				local cat_weights = allowed_groups[group_type]
				
				if previous_chosen_types[group_type] then
					cat_weights = false
				end

				if cat_weights then				
					local cat_weight = cat_weights[1]
					
					table.insert(best_groups, {
						group = group,
						group_type = group_type,
						wght = cat_weight,
						cat_weight = cat_weight,
						dis_weight = cat_weight
					})

					total_weight = total_weight + cat_weight
				end
			end
		end
		
		if total_weight == 0 then
			managers.groupai:state()._previous_chosen_types = {}
		end

		return total_weight
	end
	
	function LIES:_choose_best_group(best_groups, total_weight)
		local rand_wgt = total_weight * math.random()
		local best_grp, best_grp_type = nil
		
		for i = 1, #best_groups do
			local candidate = best_groups[i]
			
			rand_wgt = rand_wgt - candidate.wght
			
			if rand_wgt <= 0 then
				self._spawn_group_timers[spawn_group_id(candidate.group)] = TimerManager:game():time() + math.random(15, 20)
				
				best_grp = candidate.group
				best_grp_type = candidate.group_type
				
				local previous_chosen_types = managers.groupai:state()._previous_chosen_types
				
				previous_chosen_types[best_grp_type] = true
				
				best_grp.delay_t = self._t + best_grp.interval

				break
			end
		end

		return best_grp, best_grp_type
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
			local on = item:value() == "on"
			LIES.settings.lua_cover = on

			LIES:Save()
		end
		
		MenuCallbackHandler.callback_lies_enemy_aggro_level = function(self, item)
			local value = item:value()
			LIES.settings.enemy_aggro_level = value

			LIES:Save()
		end
		
		MenuCallbackHandler.callback_lies_fixed_spawngroups = function(self, item)
			local value = item:value()
			LIES.settings.fixed_spawngroups = value

			LIES:Save()
		end
		
		MenuCallbackHandler.callback_lies_copsretire = function(self, item)
			local on = item:value() == "on"
			LIES.settings.copsretire = on

			LIES:Save()
		end
		
		MenuCallbackHandler.callback_lies_interruptoncontact = function(self, item)
			local on = item:value() == "on"
			LIES.settings.interruptoncontact = on

			LIES:Save()
		end
		
		--called when the menu is closed
		MenuCallbackHandler.callback_lies_close = function(self)
		end

		--load settings from user's mod settings txt
		LIES:Load()
		
		if type(LIES.settings.fixed_spawngroups) ~= "number" then
			log("oh")
			LIES.settings.fixed_spawngroups = 1
			
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
