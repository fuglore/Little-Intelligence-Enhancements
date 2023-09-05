Hooks:PostHook(MenuNodeGui, "_setup_item_rows", "LIES_update", function(self, node, ...)   
	local current_ver = LIES.version
	local new_ver_string = LIES.received_version
	
	if not Global.has_shown_lies_update_warning and new_ver_string and current_ver ~= new_ver_string then
		title = "LIES has a new update."
		desc = "Visit the ModWorkshop page to acquire it."
		QuickMenu:new(title, desc, {}, true)
		
		Global.has_shown_lies_update_warning  = true
	end
	
end)
