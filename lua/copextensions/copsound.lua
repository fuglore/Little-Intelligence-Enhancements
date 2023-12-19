local mex_gang = {
	[Idstring("units/payday2/characters/ene_gang_mexican_1/ene_gang_mexican_1"):key()] = true,
	[Idstring("units/payday2/characters/ene_gang_mexican_2/ene_gang_mexican_2"):key()] = true,
	[Idstring("units/payday2/characters/ene_gang_mexican_3/ene_gang_mexican_3"):key()] = true,
	[Idstring("units/payday2/characters/ene_gang_mexican_4/ene_gang_mexican_4"):key()] = true
}

local cobra_gang = {
	[Idstring("units/payday2/characters/ene_gang_black_1/ene_gang_black_1"):key()] = true,
	[Idstring("units/payday2/characters/ene_gang_black_2/ene_gang_black_2"):key()] = true,
	[Idstring("units/payday2/characters/ene_gang_black_3/ene_gang_black_3"):key()] = true,
	[Idstring("units/payday2/characters/ene_gang_black_4/ene_gang_black_4"):key()] = true
}

local biker_gang = {
	[Idstring("units/payday2/characters/ene_biker_1/ene_biker_1"):key()] = true,
	[Idstring("units/payday2/characters/ene_biker_2/ene_biker_2"):key()] = true,
	[Idstring("units/payday2/characters/ene_biker_3/ene_biker_3"):key()] = true,
	[Idstring("units/payday2/characters/ene_biker_4/ene_biker_4"):key()] = true
}

local hotline_gang = {
	[Idstring("units/payday2/characters/ene_gang_mobster_1/ene_gang_mobster_1"):key()] = true,
	[Idstring("units/payday2/characters/ene_gang_mobster_2/ene_gang_mobster_2"):key()] = true,
	[Idstring("units/payday2/characters/ene_gang_mobster_3/ene_gang_mobster_3"):key()] = true,
	[Idstring("units/payday2/characters/ene_gang_mobster_4/ene_gang_mobster_4"):key()] = true
}

Hooks:PostHook(CopSound, "init", "lies_init", function(self, unit)
	if mex_gang[self._unit:name():key()] then
		self._prefix = "lt" .. tostring(math.random(2)) .. "_"
	elseif cobra_gang[self._unit:name():key()] then
		self._prefix = "ict" .. tostring(math.random(2)) .. "_"
	elseif biker_gang[self._unit:name():key()] then
		self._prefix = "bik" .. tostring(math.random(2)) .. "_"
	elseif hotline_gang[self._unit:name():key()] then
		self._prefix = "rt" .. tostring(math.random(2)) .. "_"
	end
	
	self.speaking = self.speaking_fix
	self.say = self.say_fix
	self._play = self._play_fixed
end)

function CopSound:stop_speaking_clbk(instance, event_type, unit, sound_source, label, identifier, position)
	if not alive(unit) then
		return
	end

	unit:sound()._last_speech = nil
	unit:sound()._speak_expire_t = TimerManager:game():time()
end

function CopSound:speaking_fix(t)
	return self._last_speech
end

function CopSound:_play_fixed(sound_name, source_name, clbk)
	local source = nil

	if source_name then
		source = Idstring(source_name)
	end

	local event = nil

	if clbk then --add self._unit to make the clbk work
		event = self._unit:sound_source(source):post_event(sound_name, clbk, self._unit, "marker", "end_of_event")
	else
		event = self._unit:sound_source(source):post_event(sound_name)
	end

	return event
end

local line_array = { c01 = "contact",
	c01x = "contact",
	rrl = "gogo",
	e01 = "ready",
	e02 = "ready",
	e03 = "ready",
	e04 = "ready",
	e05 = "ready",
	e06 = "ready",
	i01 = "contact",
	i02 = "gogo",
	i03 = "kill",
	lk3a = "cover_me",
	lk3b = "cover_me",
	mov = "gogo",
	med = "buddy_died",
	amm = "buddy_died",
	ch1 = "buddy_died",
	ch2 = "buddy_died",
	ch3 = "buddy_died",
	ch4 = "buddy_died",
	t01 = "gogo",
	pus = "gogo",
	g90 = "contact",
	civ = "hostage",
	bak = "ready",
	p01 = "hostage",
	p02 = "hostage",
	p03 = "gogo",
	m01 = "retreat",
	h01 = "rescue_civ",
	cr1 = "rescue_civ",
	rdy = "ready",
	r01 = "ready",
	clr = "clear",
	att = "gogo",
	a08 = "gogo",
	a05 = "gogo",
	prm = "ready",
	pos = "ready",
	d01 = "ready",
	d02 = "ready",
	x01a_any_3p = "pain",
	x01a_any_3p_01 = "pain",
	x01a_any_3p_02 = "pain",
	x02a_any_3p = "death",
	x02a_any_3p_01 = "death",
	x02a_any_3p_02 = "death",
	hlp = "buddy_died",
	buddy_died = "buddy_died",
	s01x = "surrender",
	use_gas = "use_gas",
	spawn = "spawn",
	tasing = "tasing",
	heal = "heal",
	tsr_x02a_any_3p = "death",
	tsr_x01a_any_3p = "pain",
	tsr_post_tasing_taunt = "tasing",
	tsr_g90 = "buddy_died",
	tsr_entrance = "gogo",
	tsr_c01 = "contact",
	bdz_c01 = "contact",
	bdz_entrance = "spawn",
	bdz_entrance_elite = "spawn",
	bdz_g90 = "gogo",
	bdz_post_kill_taunt = "gogo",
	bdz_visor_lost = "gogo",
	cloaker_taunt_after_assault = "kill",
	cloaker_taunt_during_assault = "kill",
	cpa_taunt_after_assault = "kill",
	cpa_taunt_during_assault = "kill",
	police_radio = "radio",
	clk_x02a_any_3p = "death"
}

function CopSound:_play_vc_framework_voice(sound_name, important)
	if self._unit:base():char_tweak()["custom_voicework"] then
		local line_to_check = line_array[sound_name]
		
		if line_to_check then
			local voicelines = _G.voiceline_framework.BufferedSounds[self._unit:base():char_tweak().custom_voicework]
			if voicelines and voicelines[line_to_check] then
				local line_to_use = voicelines[line_to_check][math.random(#voicelines[line_to_check])]
				self._unit:base():play_voiceline(line_to_use, important)
				
				return true
			end
		end
	end
end

local important_sounds = {
	a08 = true,
	x02a_any_3p = true,
	x01a_any_3p = true,
	burnhurt = true,
	burndeath = true,
	cloaker_taunt_during_assault = true,
	cloaker_taunt_after_assault = true,
	rcloaker_taunt_during_assault = true,
	rcloaker_taunt_after_assault = true,
	mcloaker_taunt_during_assault = true,
	mcloaker_taunt_after_assault = true
}

function CopSound:say_fix(sound_name, sync, skip_prefix, important, callback)
	if not sound_name or type(sound_name) ~= "string" then --shouldn't normally happen.
		return
	end

	if important_sounds[sound_name] then
		important = true
	end
	
	if _G.voiceline_framework then
		if self:_play_vc_framework_voice(sound_name, important) then
			return
		end
	end

	if self._last_speech then
		if important then
			self._last_speech:stop()
			self:stop()
		else
			return
		end
	end

	local full_sound = nil

	if not skip_prefix then
		if self._prefix == "ict1_" or self._prefix == "bik1_" or self._prefix == "bik2_" then
			if sound_name == "burnhurt" then
				full_sound = "l5n_burnhurt"
			elseif sound_name == "burndeath" then
				full_sound = "l5n_burndeath"
			end
		end
	
		if self._prefix == "l5d_" then
			if sound_name == "c01" then
				sound_name = "i01"
			elseif sound_name == "att" then
				sound_name = "g90"
			elseif sound_name == "rrl" then
				sound_name = "pus"
			elseif sound_name == "t01" then
				sound_name = "prm"
			elseif sound_name == "h01" then
				sound_name = "h10"
			end
		end

		local fixed_sound = nil
		
		if self._prefix == "l1n_" or self._prefix == "l2n_" or self._prefix == "l3n_" then
			if sound_name == "x02a_any_3p" then
				sound_name = "x01a_any_3p"
				fixed_sound = true
			elseif sound_name == "x01a_any_3p" then
				sound_name = "x02a_any_3p"
			end
		end
		
		if self._prefix == "l2n_" then --these are flipped for l2n for some reason, because of bnk typos probably
			if sound_name == "lk3a" then
				sound_name = "lk3b"
			elseif sound_name == "lk3b" then
				sound_name = "lk3a"
			end
		end
		
		if self._prefix == "l4n_" then
			if sound_name == "x02a_any_3p" then
				sound_name = "x01a_any_3p"
				fixed_sound = true
			elseif sound_name == "x01a_any_3p" then
				full_sound = "l1n_x02a_any_3p"
			end
		end
		
		if self._prefix == "l1d_" or self._prefix == "l2d_" or self._prefix == "l3d_" or self._prefix == "l4d_" or self._prefix == "l5d_" then
			if sound_name == "a05" or sound_name == "a06" then
				sound_name = "clr"
			end
		end
		
		if self._prefix == "l2d_" then
			if sound_name == "x02a_any_3p" then
				full_sound = "l1d_x02a_any_3p"
			end
		end

		if self._prefix == "l3d_" then
			if sound_name == "burnhurt" then
				full_sound = "l1d_burnhurt"
			elseif sound_name == "burndeath" then
				full_sound = "l1d_burndeath"
			end
		end

		if self._prefix == "z1n_" or self._prefix == "z2n_" or self._prefix == "z3n_" or self._prefix == "z4n_" then
			if sound_name == "x02a_any_3p" then
				full_sound = "shd_x02a_any_3p_01"
			elseif sound_name == "x01a_any_3p" then
				full_sound = "bdz_x01a_any_3p"
			elseif sound_name ~= "x01a_any_3p" and sound_name ~= "x02a_any_3p" and sound_name ~= "burndeath" and sound_name ~= "burnhurt" then
				local sounds = {
					"g90",
					"mov",
					"rdy",
					"c01",
					"d01"
					
				}
				sound_name = sounds[math.random(#sounds)]
			end
		end
			
		if self._prefix == "fl1n_" then
			if sound_name == "x02a_any_3p" then
				full_sound = "fl1n_x01a_any_3p_01"
			end
		end

		if self._prefix == "r1n_" or self._prefix == "r2n_" or self._prefix == "r3n_" or self._prefix == "r4n_" then
			if sound_name == "x02a_any_3p" then
				full_sound = "l2n_x01a_any_3p"
			elseif sound_name == "x01a_any_3p" then
				full_sound = "l2n_x02a_any_3p"
			end
		end
	end

	if not full_sound then
		if skip_prefix then
			full_sound = sound_name
		else
			full_sound = self._prefix .. sound_name
		end
	end

	local event_id = nil

	if type(full_sound) == "number" then
		event_id = full_sound
		full_sound = nil
	end

	if sync then
		event_id = event_id or SoundDevice:string_to_id(full_sound)

		self._unit:network():send("say", event_id)
	end
	
	
	--clbk specifically when speaking is used to prevent lines from overlapping
	local clbk = self.stop_speaking_clbk

	self._last_speech = self:_play(full_sound or event_id, nil, clbk)

	if not self._last_speech then
		return
	end

	self._speak_expire_t = TimerManager:game():time() + 2
	
	return true
end