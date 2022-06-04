function SpoocLogicIdle._exit_hiding(data)
	data.unit:brain():set_objective({ --this used to call data.unit:set_objective in vanilla...
		type = "act",
		action = {
			variant = "idle",
			body_part = 1,
			type = "act",
			blocks = {
				heavy_hurt = -1,
				idle = -1,
				action = -1,
				turn = -1,
				light_hurt = -1,
				walk = -1,
				fire_hurt = -1,
				hurt = -1,
				expl_hurt = -1
			}
		}
	})
end