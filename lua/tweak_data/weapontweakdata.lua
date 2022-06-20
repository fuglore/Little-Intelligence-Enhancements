function WeaponTweakData:_setup_hhtacs()
	local difficulty = Global.game_settings and Global.game_settings.difficulty or "normal"
	local difficulty_index = tweak_data:difficulty_to_index(difficulty)
	
	if difficulty_index > 5 then
		self.saiga_npc.CLIP_AMMO_MAX = 14
		self.m4_npc.CLIP_AMMO_MAX = 45
		self.m4_yellow_npc.CLIP_AMMO_MAX = 45
		self.ak47_ass_npc.CLIP_AMMO_MAX = 45
		self.g36_npc.CLIP_AMMO_MAX = 45
		self.r870_npc.CLIP_AMMO_MAX = 8
		self.benelli_npc.CLIP_AMMO_MAX = 8
	end
end