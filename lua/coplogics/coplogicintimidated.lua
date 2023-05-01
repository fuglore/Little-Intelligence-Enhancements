function CopLogicIntimidated._unregister_rescue_SO(data, my_data)
	if my_data.rescuer then
		if alive(my_data.rescuer) then
			local rescuer = my_data.rescuer
			my_data.rescuer = nil

			managers.groupai:state():on_objective_failed(rescuer, rescuer:brain():objective())
		else
			CopLogicIntimidated.on_rescue_SO_failed(nil, data)
		end
	elseif my_data.rescue_SO_id then
		managers.groupai:state():remove_special_objective(my_data.rescue_SO_id)

		my_data.rescue_SO_id = nil
	elseif my_data.delayed_rescue_SO_id then
		CopLogicBase.chk_cancel_delayed_clbk(my_data, my_data.delayed_rescue_SO_id)
	end
end