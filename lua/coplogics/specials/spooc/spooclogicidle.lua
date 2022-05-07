function SpoocLogicIdle._chk_exit_hiding(data)
	local attention_objects = data.detected_attention_objects

	for u_key, attention_data in pairs(attention_objects) do
		if AIAttentionObject.REACT_SHOOT <= attention_data.reaction and data.unit:anim_data().hide_loop then
			if attention_data.dis < 1500 and data.attention_obj.verified then
				SpoocLogicIdle._exit_hiding(data)
				
				break
			elseif attention_data.dis < 700 then
				local my_nav_seg_id = data.unit:movement():nav_tracker():nav_segment()
				local enemy_areas = managers.groupai:state():get_areas_from_nav_seg_id(attention_data.nav_tracker:nav_segment())
				local exited = nil
				
				for _, area in ipairs(enemy_areas) do
					if area.nav_segs[my_nav_seg_id] then
						exited = true
						SpoocLogicIdle._exit_hiding(data)

						break
					end
				end
				
				if exited then
					break
				end
			end
		end
	end
end