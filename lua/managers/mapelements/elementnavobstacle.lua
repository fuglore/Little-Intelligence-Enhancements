function ElementNavObstacle:on_script_activated()
	if not self._values.obstacle_list then
		self._values.obstacle_list = {
			{
				unit_id = self._values.obstacle_unit_id,
				obj_name = self._values.obstacle_obj_name
			}
		}
	end

	for _, data in ipairs(self._values.obstacle_list) do
		if Global.running_simulation then
			table.insert(self._obstacle_units, {
				unit = managers.editor:unit_with_id(data.unit_id),
				obj_name = data.obj_name
			})
		else
			local unit = managers.worlddefinition:get_unit_on_load(data.unit_id, callback(self, self, "_load_unit", data.obj_name))

			if unit then
				local key = tostring(unit:key())
	
				local osbtacle_data = {
					unit = unit,
					obj_name = data.obj_name
				}
				
				unit:unit_data():add_destroy_listener(key .. "on_nav_obstacle_destroyed", callback(self, self, "on_nav_obstacle_destroyed", osbtacle_data))
				
				table.insert(self._obstacle_units, osbtacle_data)
			end
		end
	end

	self._has_fetched_units = true

	self._mission_script:add_save_state_cb(self._id)
end

function ElementNavObstacle:_load_unit(obj_name, unit)
	local key = tostring(unit:key())
	
	local osbtacle_data = {
		unit = unit,
		obj_name = obj_name
	}
	
	unit:unit_data():add_destroy_listener(key .. "on_nav_obstacle_destroyed", callback(self, self, "on_nav_obstacle_destroyed", osbtacle_data))
	
	table.insert(self._obstacle_units, osbtacle_data)
end

function ElementNavObstacle:on_nav_obstacle_destroyed(data)
	managers.navigation:remove_obstacle(data.unit, data.obj_name)
end