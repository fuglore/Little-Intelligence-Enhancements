function WeaponTweakData:setup_hhtacs()
	local difficulty = Global.game_settings and Global.game_settings.difficulty or "normal"
	local difficulty_index = tweak_data:difficulty_to_index(difficulty)
	
	if difficulty_index > 5 then
		if difficulty_index > 7 then
			self.dmr_npc.CLIP_AMMO_MAX = 12
			self.heavy_snp_npc.CLIP_AMMO_MAX = 12
		else
			self.dmr_npc.CLIP_AMMO_MAX = 9
			self.heavy_snp_npc.CLIP_AMMO_MAX = 9
		end

		self.saiga_npc.CLIP_AMMO_MAX = 14
		self.contraband_npc.CLIP_AMMO_MAX = 45
		self.m4_npc.CLIP_AMMO_MAX = 45
		self.m4_yellow_npc.CLIP_AMMO_MAX = 45
		self.ak47_ass_npc.CLIP_AMMO_MAX = 45
		self.g36_npc.CLIP_AMMO_MAX = 45
		self.r870_npc.CLIP_AMMO_MAX = 8
		self.benelli_npc.CLIP_AMMO_MAX = 8
	end
end