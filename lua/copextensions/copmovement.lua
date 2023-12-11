Hooks:PostHook(CopMovement, "_upd_actions", "lies_actions", function(self, t)	
	if not Network:is_server() then
		return
	end
	
	if LIES.settings.hhtacs then
		self._unit:brain():upd_falloff_sim()
	end
end)

function CopMovement:force_upd_z_ray()
	self:upd_ground_ray()

	if self._gnd_ray then
		self:set_position(self._gnd_ray.position)
	end
end