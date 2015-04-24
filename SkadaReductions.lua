local addonName = ...

local Skada = Skada
local floor = math.floor
local band = bit.band

local reductions = {
	[31821] = {
		effect = 0.8,
		duration = 6
	}
}

local reductions_count = 0
local reductions_active = {}

local sources = {}
local function log_reduction(set, dmg)
	local time = dmg.time
	
	local total_effect = 1;
	local sources_count = 0
	wipe(sources)
	
	for id, reduction in pairs(reductions_active) do
		if reduction.activation + reduction.duration < dmg.time then
			reductions_active[id] = nil
			reductions_count = reductions_count - 1
		elseif UnitAura(dmg.playername, reduction.auraname) and (not reduction.school or band(reduction.school, dmg.school) ~= 0) then
			total_effect = total_effect * reduction.effect
			sources[id] = reduction
			sources_count = sources_count + 1
		end
	end
	
	if sources_count == 0 then return end
	local amount = floor((dmg.amount / total_effect - dmg.amount) / sources_count)
	
	for id, reduction in pairs(sources) do
		local player = Skada:get_player(set, reduction.sourceid, reduction.sourcename)
		if not player then return end
		
		-- Add to player total.
		player.healing = player.healing + amount
		player.shielding = player.shielding + amount
		
		-- Also add to set total damage.
		set.healing = set.healing + amount
		set.shielding = set.shielding + amount
		
		-- Also add to set total damage.
		set.healing = set.healing + amount
		set.shielding = set.shielding + amount
		
		-- Add to recipient healing.
		do
			local healed = player.healed[dmg.playerid]

			-- Create recipient if it does not exist.
			if not healed then
				local _, className = UnitClass(dmg.playername)
				local playerRole = UnitGroupRolesAssigned(dmg.playername)
				healed = {name = dmg.playername, class = className, role = playerRole, amount = 0, shielding = 0}
				player.healed[dmg.playerid] = healed
			end

			healed.amount = healed.amount + amount
			healed.shielding = healed.shielding + amount
		end
		
		-- Add to spell healing
		do
			local spell = player.healingspells[reduction.name]

			-- Create spell if it does not exist.
			if not spell then
				spell = {id = id, name = reduction.name, hits = 0, healing = 0, overhealing = 0, absorbed = 0, shielding = 0, critical = 0, multistrike = 0, min = nil, max = 0}
				player.healingspells[reduction.name] = spell
			end

			spell.healing = spell.healing + amount
			spell.shielding = spell.shielding + amount
			spell.hits = (spell.hits or 0) + 1

			if not spell.min or amount < spell.min then
				spell.min = amount
			end
			if not spell.max or amount > spell.max then
				spell.max = amount
			end
		end
	end
end

local dmg = {}

local function SpellDamage(_, _, _, _, _, dstGUID, dstName, _, ...)
	if reductions_count < 1 then return end
	local _, _, _, samount, _, sschool = ...

	dmg.playerid = dstGUID
	dmg.playername = dstName
	dmg.amount = samount
	dmg.school = sschool
	dmg.time = GetTime()

	log_reduction(Skada.current, dmg)
	log_reduction(Skada.total, dmg)
end

local function SwingDamage(_, _, _, _, _, dstGUID, dstName, _, ...)
	if reductions_count < 1 then return end
	local samount, _, sschool = ...

	dmg.playerid = dstGUID
	dmg.playername = dstName
	dmg.amount = samount
	dmg.school = sschool
	dmg.time = GetTime()

	log_reduction(Skada.current, dmg)
	log_reduction(Skada.total, dmg)
end

Skada:RegisterForCL(SpellDamage, "SPELL_DAMAGE", {dst_is_interesting_nopets = true})
Skada:RegisterForCL(SpellDamage, "SPELL_PERIODIC_DAMAGE", {dst_is_interesting_nopets = true})
Skada:RegisterForCL(SpellDamage, "SPELL_BUILDING_DAMAGE", {dst_is_interesting_nopets = true})
Skada:RegisterForCL(SpellDamage, "RANGE_DAMAGE", {dst_is_interesting_nopets = true})
Skada:RegisterForCL(SwingDamage, "SWING_DAMAGE", {dst_is_interesting_nopets = true})

local function SpellCast(_, _, srcGUID, srcName, _, _, _, _, ...)
	local spellId, spellName = ...
	local reduction = reductions[spellId]
	
	if reduction then
		if not reduction.name then
			reduction.name = spellName
			reduction.auraname = GetSpellInfo(reduction.aura or spellId)
		end
		
		reduction.sourceid = srcGUID
		reduction.sourcename = srcName
		reduction.activation = GetTime()
		
		reductions_active[spellId] = reduction
		reductions_count = reductions_count + 1
	end
end

Skada:RegisterForCL(SpellCast, "SPELL_CAST_SUCCESS", {src_is_interesting = true})
