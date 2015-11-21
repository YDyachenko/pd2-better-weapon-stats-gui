toggle_greater_precision = true
local swap_positions = nil

local _blackmarketgui_function_ptr1 = BlackMarketGui.mouse_moved
local _blackmarketgui_function_ptr2 = BlackMarketGui._get_base_stats
local _blackmarketgui_function_ptr3 = BlackMarketGui._get_skill_stats
local _blackmarketgui_function_ptr4 = BlackMarketGui._get_mods_stats
local _blackmarketgui_function_ptr5 = BlackMarketGui.show_stats
local _blackmarketgui_function_ptr6 = BlackMarketGui._get_stats
local _blackmarketgui_function_ptr7 = BlackMarketGui._get_weapon_mod_stats
local _blackmarketgui_function_ptr8 = BlackMarketGui._pre_reload
local _blackmarketgui_function_ptr9 = BlackMarketGui.update_info_text


function BlackMarketGui:mouse_moved(o, x, y, ...)
	if toggle_greater_precision and self._enabled and not self._renaming_item then
		self:_check_popup(x, y)
	end
	return _blackmarketgui_function_ptr1(self, o, x, y, ...)
end





function BlackMarketGui:_get_stats(name, category, slot)
	if not toggle_greater_precision then
		return _blackmarketgui_function_ptr6(self, name, category, slot)
	end

	local equipped_mods
	local silencer = false
	local single_mod = false
	local auto_mod = false
	local blueprint = managers.blackmarket:get_weapon_blueprint(category, slot)
	if blueprint then
		equipped_mods = deep_clone(blueprint)
		local factory_id = managers.weapon_factory:get_factory_id_by_weapon_id(name)
		local default_blueprint = managers.weapon_factory:get_default_blueprint_by_factory_id(factory_id)
		if equipped_mods then
			silencer = managers.weapon_factory:has_perk("silencer", factory_id, equipped_mods)
			single_mod = managers.weapon_factory:has_perk("fire_mode_single", factory_id, equipped_mods)
			auto_mod = managers.weapon_factory:has_perk("fire_mode_auto", factory_id, equipped_mods)
		end
	end
	local base_stats = self:_get_base_stats(name)
	local mods_stats = self:_get_mods_stats(name, base_stats, equipped_mods)
	local skill_stats = self:_get_skill_stats(name, category, slot, base_stats, mods_stats, silencer, single_mod, auto_mod)
	local clip_ammo, max_ammo, ammo_data = self:get_weapon_ammo_info(name, tweak_data.weapon[name].stats.extra_ammo, base_stats.totalammo.index + mods_stats.totalammo.index)
	base_stats.totalammo.value = ammo_data.base
	mods_stats.totalammo.value = ammo_data.mod
	skill_stats.totalammo.value = ammo_data.skill
	skill_stats.totalammo.skill_in_effect = ammo_data.skill_in_effect
	local my_clip = base_stats.magazine.value + mods_stats.magazine.value + skill_stats.magazine.value
	if max_ammo < my_clip then mods_stats.magazine.value = mods_stats.magazine.value + (max_ammo - my_clip) end
	return base_stats, mods_stats, skill_stats
end


function BlackMarketGui:_pre_reload(...)
	self:_delete_popups()
	return _blackmarketgui_function_ptr8(self, ...)
end



function BlackMarketGui:update_info_text(...)
	if toggle_greater_precision then self:_check_update_info(self._slot_data, self._tabs[self._selected]._data) end
	return _blackmarketgui_function_ptr9(self, ...)
end



function BlackMarketGui:_delete_popups()
	if self._equipped_stat_popup then
		self._equipped_stat_popup:delete()
		self._equipped_stat_popup = nil
	end
	if self._selected_stat_popup then
		self._selected_stat_popup:delete()
		self._selected_stat_popup = nil
	end
end



function BlackMarketGui:_check_update_info(slot_data, tab_data)
	if self._popup_stat then
		self:_create_stat_popup()
	end
end



function BlackMarketGui:_check_popup(x, y)
	local panels = {
		self._rweapon_stats_panel,
		self._mweapon_stats_panel,
		self._armor_stats_panel,
		self._info_texts[4],
	}

	for _, p in ipairs(panels) do
		if p:visible() and p:inside(x, y) then
			if(p.children and p:children()) then
				for i, stat_row in ipairs(p:children()) do
					if stat_row:visible() and stat_row:inside(x, y) then
						if self._popup_stat ~= i then
							self._popup_stat = i
							self:_create_stat_popup()
						end
						return
					end
				end
			elseif tweak_data.projectiles[self._slot_data.name] then
				self._popup_stat = "grenade"
				self:_create_stat_popup()
				return
			elseif tweak_data.blackmarket.deployables[self._slot_data.name] then
				self._popup_stat = "deployables"
				self:_create_stat_popup()
				return
			end
		end
	end

	self._popup_stat = nil
	self:_delete_popups()
end



function BlackMarketGui:_create_stat_popup()
	self._equipped_stat_popup = self._equipped_stat_popup or InventoryStatsPopup:new(self._panel, self._popup_stat, true)
	self._equipped_stat_popup:update(self._popup_stat, self:_get_popup_data(true))
	self._equipped_stat_popup:set_position(self._stats_panel:x() - 10 - self._equipped_stat_popup:w(), self._panel:h()/2 - self._equipped_stat_popup:h()/2)

	if not self._slot_data.equipped then
		self._selected_stat_popup = self._selected_stat_popup or InventoryStatsPopup:new(self._panel, false)
		self._selected_stat_popup:update(self._popup_stat, self:_get_popup_data(false))
		if not swap_positions then
			self._selected_stat_popup:set_position(self._stats_panel:x() - 10 - self._selected_stat_popup:w(), self._panel:h()/2 - self._selected_stat_popup:h()/2)
			self._equipped_stat_popup:set_position(self._selected_stat_popup._panel:x() - self._equipped_stat_popup:w(), self._selected_stat_popup._panel:y())
		else
			self._selected_stat_popup:set_position(self._equipped_stat_popup._panel:x() - self._selected_stat_popup:w(), self._equipped_stat_popup._panel:y())
		end
	elseif self._selected_stat_popup then
		self._selected_stat_popup:delete()
		self._selected_stat_popup = nil
	end
end



function BlackMarketGui:_get_popup_data(equipped)
	local category = self._slot_data.category
	local data

	if tweak_data.weapon[self._slot_data.name] and self._slot_data.name ~= "sentry_gun" then
		local slot = equipped and managers.blackmarket:equipped_weapon_slot(category) or self._slot_data.slot
		local weapon = equipped and managers.blackmarket:equipped_item(category) or managers.blackmarket:get_crafted_category_slot(category, slot)
		local name = equipped and weapon.weapon_id or weapon and weapon.weapon_id or self._slot_data.name
		local factory_id = managers.weapon_factory:get_factory_id_by_weapon_id(name)
		local blueprint = managers.blackmarket:get_weapon_blueprint(category, slot)
		local ammo_data = factory_id and blueprint and managers.weapon_factory:get_ammo_data_from_weapon(factory_id, blueprint) or {}
		ammo_data.fire_dot_data = tweak_data.weapon[name].fire_dot_data
		local custom_stats = factory_id and blueprint and managers.weapon_factory:get_custom_stats_from_weapon(factory_id, blueprint)
		if custom_stats then
			for part_id, stats in pairs(custom_stats) do
				if tweak_data.weapon.factory.parts[part_id].type ~= "ammo" then
					if stats.ammo_pickup_min_mul then
						ammo_data.ammo_pickup_min_mul = ammo_data.ammo_pickup_min_mul and ammo_data.ammo_pickup_min_mul * stats.ammo_pickup_min_mul or stats.ammo_pickup_min_mul
					end
					if stats.ammo_pickup_max_mul then
						ammo_data.ammo_pickup_max_mul = ammo_data.ammo_pickup_max_mul and ammo_data.ammo_pickup_max_mul * stats.ammo_pickup_max_mul or stats.ammo_pickup_max_mul
					end
				end
				if stats.fire_dot_data then
					ammo_data.fire_dot_data = stats.fire_dot_data
				end
			end
		end
		local base_stats, mods_stats, skill_stats = managers.menu_component._blackmarket_gui:_get_stats(name, category, slot)
		data = {
			base_stats = base_stats,
			mods_stats = mods_stats,
			skill_stats = skill_stats,
			inventory_category = category,
			inventory_slot = slot,
			stat_table = self._stats_shown,
			name = name,
			localized_name = managers.localization:text(tweak_data.weapon[name].name_id),
			category = tweak_data.weapon[name].category,
			tweak = tweak_data.weapon[name],
			weapon = weapon,
			factory_id = factory_id,
			blueprint = blueprint,
			ammo_data = ammo_data,
			silencer = factory_id and blueprint and managers.weapon_factory:has_perk("silencer", factory_id, blueprint),
			--weapon_modified = factory_id and blueprint and managers.blackmarket:is_weapon_modified(factory_id, blueprint),
		}
	elseif tweak_data.blackmarket.armors[self._slot_data.name] then
		local name = equipped and managers.blackmarket:equipped_item(category) or self._slot_data.name
		data = {
			inventory_category = category,
			stat_table = self._armor_stats_shown,
			name = name,
			localized_name = managers.localization:text(tweak_data.blackmarket.armors[name].name_id),
		}
	elseif tweak_data.blackmarket.melee_weapons[self._slot_data.name] then
		local name = equipped and managers.blackmarket:equipped_item(category) or self._slot_data.name
		data = {
			inventory_category = category,
			stat_table = self._mweapon_stats_shown,
			name = name,
			localized_name = managers.localization:text(tweak_data.blackmarket.melee_weapons[name].name_id),
		}
	elseif tweak_data.blackmarket.projectiles[self._slot_data.name] then
		local name, count = equipped and managers.blackmarket:equipped_item(category) or self._slot_data.name
		data = {
			inventory_category = category,
			stats = tweak_data.projectiles[name],
			name = name,
			localized_name = managers.localization:text(tweak_data.blackmarket.projectiles[name].name_id),
		}
		data.stats.count = count
	elseif tweak_data.blackmarket.deployables[self._slot_data.name] then
		local name = equipped and Global.player_manager.kit.equipment_slots[1] or self._slot_data.name
		data = {
			inventory_category = category,
			stats = tweak_data.equipments[name],
			name = name,
			localized_name = managers.localization:text(tweak_data.blackmarket.deployables[name].name_id),
		}
	else
		local raw_name
		local factory_id = managers.weapon_factory:get_factory_id_by_weapon_id(managers.blackmarket:equipped_item(category).weapon_id)
		local selected_mod = tweak_data.weapon.factory.parts[self._slot_data.name]
		local equipped_mod
		local blueprint = managers.blackmarket:get_weapon_blueprint(self._slot_data.category, self._slot_data.slot)
		if blueprint then
			for _, mod in ipairs(blueprint) do
				if tweak_data.weapon.factory.parts[mod].type == selected_mod.type then
					equipped_mod = tweak_data.weapon.factory.parts[mod]
					raw_name = mod
					break
				end
			end
		end
		local name = equipped and equipped_mod or selected_mod
		if not name then
			return nil
		end
		if not raw_name then raw_name = self._slot_data.name end
		local localized_name
		if equipped then
			if equipped_mod then
				for _, mod in ipairs(tweak_data.weapon.factory[factory_id].default_blueprint) do
					if equipped_mod == tweak_data.weapon.factory.parts[mod] then
						localized_name = "Default Part"
						break
					end
				end
			else
				localized_name = "No Part"
			end
		end
		data = {
			inventory_category = "mods",
			stat_table = self._stats_shown,
			name = name,
			localized_name = localized_name or managers.localization:text(name.name_id),
			stats = equipped and not equipped_mod and {} or name.stats,
			type = name.type
		}
		if tweak_data.weapon.factory[factory_id].override and tweak_data.weapon.factory[factory_id].override[raw_name] then
			if tweak_data.weapon.factory[factory_id].override[raw_name].stats then
				data.stats = tweak_data.weapon.factory[factory_id].override[raw_name].stats
			end
		end
	end

	return data
end



InventoryStatsPopup = InventoryStatsPopup or class()

InventoryStatsPopup.FONT_SCALE = 0.85
InventoryStatsPopup.VERTICAL_MARGIN = 10
InventoryStatsPopup.HORIZONTAL_MARGIN = 10
InventoryStatsPopup.ROW_MARGIN = 0

function InventoryStatsPopup:init(parent, equipped)
	self._panel = parent:panel({ name = "stats_popup", visible = true, layer = 10, })
	self._bg = self._panel:rect({ name = "bg", w = 10000, h = 10000, blend_mode = "normal", color = Color.black, layer = 10, })
	self._left_border = self._panel:rect({ name = "left_border", h = 10000, w = 3, blend_mode = "normal", color = Color.white, layer = 10, })
	self._right_border = self._panel:rect({ name = "right_border", h = 10000, w = 3, blend_mode = "normal", color = Color.white, layer = 10, })
	self._top_border = self._panel:rect({ name = "top_border", h = 3, w = 10000, blend_mode = "normal", color = Color.white, layer = 10, })
	self._bottom_border = self._panel:rect({ name = "bottom_border", h = 3, w = 10000, blend_mode = "normal", color = Color.white, layer = 10, })
	self._header = self._panel:text({ name = "header", align = "center", vertical = "center", color = Color.white, layer = 10,
		y = InventoryStatsPopup.VERTICAL_MARGIN,
		font = tweak_data.menu.pd2_small_font,
		font_size = tweak_data.menu.pd2_small_font_size * 1.25 * InventoryStatsPopup.FONT_SCALE,
		h = tweak_data.menu.pd2_small_font_size * 1.5 * InventoryStatsPopup.FONT_SCALE,
	})

	self._equipped = equipped
	self._rows = {}
end

function InventoryStatsPopup:delete()
	self:_clear()
	for _, child in ipairs(self._panel:children()) do
		self._panel:remove(child)
	end
	self._panel:parent():remove(self._panel)
end

function InventoryStatsPopup:_clear()
	for _, row in ipairs(self._rows) do
		row:delete()
	end

	self._rows = {}
	self._stat = nil
	self._data = nil
	self._panel:set_visible(false)
end

function InventoryStatsPopup:update(stat_index, data)
	self:_clear()
	if data then
		self._stat = stat_index
		self._data = data
		if data.inventory_category == "grenades" then
			self:_grenades()
			return self:_finalize()
		end
		if data.inventory_category == "deployables" then
			self:_deployables()
			return self:_finalize()
		end
		local cbk_name = string.format("_%s_%s", data.inventory_category, data.stat_table[stat_index].name)
		if self[cbk_name] then
			self[cbk_name](self)
			return self:_finalize()
		end
	end
end

function InventoryStatsPopup:h()
	return self._panel:h()
end

function InventoryStatsPopup:w()
	return self._panel:w()
end

function InventoryStatsPopup:set_position(x, y)
	self._panel:set_position(x, y)
end

function InventoryStatsPopup:_finalize()
	if #self._rows <= 0 then
		self._panel:set_visible(false)
		return false
	end

	self._header:set_text(self._data.localized_name .. (self._equipped and " (E)" or " (S)"))
	local _, _, header_width, _ = self._header:text_rect()
	local max_left_width = 0
	local max_right_width = 0
	local offset = self._header:bottom() + InventoryStatsPopup.VERTICAL_MARGIN

	for _, row in ipairs(self._rows) do
		max_left_width = math.max(max_left_width, row:left_w())
		max_right_width = math.max(max_right_width, row:right_w())
	end
	local max_width = math.max(max_left_width + max_right_width + 12 * InventoryStatsPopup.FONT_SCALE, header_width)
	for _, row in ipairs(self._rows) do
		row:set_top(offset)
		row:set_w(max_width)
		offset = offset + row:h()
	end

	offset = offset + InventoryStatsPopup.VERTICAL_MARGIN
	self._panel:set_visible(true)
	self._panel:set_size(max_width + InventoryStatsPopup.HORIZONTAL_MARGIN * 2, offset)
	self._header:set_w(self._panel:w())
	self._right_border:set_right(max_width + InventoryStatsPopup.HORIZONTAL_MARGIN * 2)
	self._bottom_border:set_bottom(offset)
	return true
end

function InventoryStatsPopup:_add_row(args)
	local new_row = InventoryStatsPopupRow:new(self._panel, args and (args.height or args.h), args and (args.scale or args.s))
	table.insert(self._rows, new_row)
	return new_row
end
InventoryStatsPopup.row = InventoryStatsPopup._add_row

function InventoryStatsPopup:_delete_row(row)
	for i, r in ipairs(self._rows) do
		if r == row then
			table.remove(i)
			break
		end
	end
	row:delete()
end

function InventoryStatsPopup:_text_color(value, threshold, compare)
	if compare == ">" then
		return value > threshold and Color.green or value < threshold and Color.red or Color.white
	else
		return value < threshold and Color.green or value > threshold and Color.red or Color.white
	end
end



InventoryStatsPopupRow = InventoryStatsPopupRow or class()

InventoryStatsPopupRow.COMPONENT_SPACING = 4

function InventoryStatsPopupRow:init(parent, height, scale)
	self._scale = scale or 1
	self._text_components = 0
	self._total_left_width = 0
	self._total_right_width = 0
	self._left_aligned = {}
	self._right_aligned = {}

	self._panel = parent:panel({
		name = "row",
		h = ((height or tweak_data.menu.pd2_small_font_size) + InventoryStatsPopup.ROW_MARGIN) * InventoryStatsPopup.FONT_SCALE * self._scale,
		layer = 11,
	})
end

function InventoryStatsPopupRow:delete()
	for _, child in ipairs(self._panel:children()) do
		self._panel:remove(child)
	end
	self._panel:parent():remove(self._panel)
end

function InventoryStatsPopupRow:add_left_text(text, args)
	local args = args or {}
	args.align = "left"
	return self:add_text(text, args)
end
InventoryStatsPopupRow.l_text = InventoryStatsPopupRow.add_left_text

function InventoryStatsPopupRow:add_right_text(text, args)
	local args = args or {}
	args.align = "right"
	return self:add_text(text, args)
end
InventoryStatsPopupRow.r_text = InventoryStatsPopupRow.add_right_text

function InventoryStatsPopupRow:add_text(text, args)
	local function format_numbers(text)
		for num, _ in text:gmatch("([0-9]+%.[0-9]+)") do
			text = text:gsub(num, string.format("%f", num):gsub('%.?0+$', ""))
		end
		return text
	end

	local args = args or {}
	local text = string.format(text, unpack(args.data or {}))
	local align = args.align == "right" and "right" or "left"

	text = args.no_trim and text or format_numbers(text)
	local tmp = self._panel:text({
		name = "text_" .. tostring(self._text_components),
		text = text:gsub("\t", "   "),
		align = align,
		vertical = "center",
		color = args.color or Color.white,
		font = tweak_data.menu.pd2_small_font,
		font_size = (args.font_size or (args.font_scale or 1) * (self._panel:h() - InventoryStatsPopup.ROW_MARGIN * InventoryStatsPopup.FONT_SCALE)) * self._scale,
		h = self._panel:h(),
		layer = 12,
	})
	local _, _, w, _ = tmp:text_rect()

	self._text_components = self._text_components + 1
	tmp:set_w(w)
	tmp:set_center(self._panel:center())
	if align == "left" then
		self._total_left_width = self._total_left_width + w
		table.insert(self._left_aligned, tmp)
	else
		self._total_right_width = self._total_right_width + w
		table.insert(self._right_aligned, 1, tmp)
	end
	return self
end

function InventoryStatsPopupRow:add_border(args)
	local args = args or {}
	local tmp = self._panel:rect({
		blend_mode = "normal",
		color = args.color or Color.white,
		h = args.h or 1,
		w = 10000,
		layer = 12,
	})
	tmp:set_center(self._panel:center())
	return self
end

function InventoryStatsPopupRow:set_w(width)
	self._panel:set_w(width + InventoryStatsPopup.HORIZONTAL_MARGIN * 2)

	if #self._left_aligned > 0 then
		self._left_aligned[1]:set_left(InventoryStatsPopup.HORIZONTAL_MARGIN)
		for i = 2, #self._left_aligned, 1 do
			self._left_aligned[i]:set_left(self._left_aligned[i-1]:right() + InventoryStatsPopupRow.COMPONENT_SPACING)
		end
	end

	if #self._right_aligned > 0 then
		self._right_aligned[1]:set_right(self._panel:w() - InventoryStatsPopup.HORIZONTAL_MARGIN)
		for i = 2, #self._right_aligned, 1 do
			self._right_aligned[i]:set_right(self._right_aligned[i-1]:left() - InventoryStatsPopupRow.COMPONENT_SPACING)
		end
	end
end

function InventoryStatsPopupRow:set_top(pos)
	self._panel:set_top(pos)
end

function InventoryStatsPopupRow:w()
	return self:left_w() + self:right_w()
end

function InventoryStatsPopupRow:h()
	return self._panel:h()
end

function InventoryStatsPopupRow:left_w()
	return self._total_left_width + (#self._left_aligned - 1) * InventoryStatsPopupRow.COMPONENT_SPACING
end

function InventoryStatsPopupRow:right_w()
	return self._total_right_width + (#self._right_aligned - 1) * InventoryStatsPopupRow.COMPONENT_SPACING
end



function InventoryStatsPopup:_primaries_magazine()
	local reload_mul = managers.blackmarket:_convert_add_to_mul(1 + (1 - managers.player:upgrade_value(self._data.category, "reload_speed_multiplier", 1)) + (1 - managers.player:upgrade_value("weapon", "passive_reload_speed_multiplier", 1)) + (1 - managers.player:upgrade_value(self._data.name, "reload_speed_multiplier", 1)))
	if self._data.category == "bow" then reload_mul = reload_mul * 3 end
	local mag = self._data.base_stats.magazine.value + self._data.mods_stats.magazine.value + self._data.skill_stats.magazine.value
	local timers = self._data.tweak.timers
	local reload_not_empty = timers and timers.reload_not_empty
	local reload_empty = timers and timers.reload_empty
	local rof = 60 / (self._data.base_stats.fire_rate.value + self._data.mods_stats.fire_rate.value + self._data.skill_stats.fire_rate.value)

	if reload_not_empty and reload_empty then
		if reload_not_empty ~= reload_empty then
			self:row():l_text("Reload Time:")
			self:row({ s = 0.9 }):l_text("\tTactical:"):r_text("%.2fs", {data = {reload_not_empty / reload_mul}})
			self:row({ s = 0.9 }):l_text("\tEmpty:"):r_text("%.2fs", {data = {reload_empty / reload_mul}})
		else
			self:row():l_text("Reload Time:"):r_text("%.2fs", {data = {reload_not_empty / reload_mul}})
		end
	else
		self:row():l_text("Reload Time:")
		if timers.shotgun_reload_enter then
			self:row({ s = 0.9 }):l_text("\tFirst Shell:"):r_text("%.2fs", {data = {(timers.shotgun_reload_enter + timers.shotgun_reload_shell - timers.shotgun_reload_first_shell_offset) / reload_mul}})
			self:row({ s = 0.9 }):l_text("\tEach Additional Shell:"):r_text("%.2fs", {data = {timers.shotgun_reload_shell / reload_mul}})
			self:row({ s = 0.9 }):l_text("\tFull:"):r_text("%.2fs", {data = {(timers.shotgun_reload_enter + timers.shotgun_reload_shell * mag - timers.shotgun_reload_first_shell_offset) / reload_mul}})
			if timers.shotgun_reload_exit_empty == timers.shotgun_reload_exit_not_empty then
				self:row({ s = 0.9 }):l_text("\tEnd delay (Cancelable):"):r_text("%.2fs", {data = {timers.shotgun_reload_exit_empty / reload_mul}})
			else
				self:row({ s = 0.9 }):l_text("\tEnd delay (Cancelable):")
				self:row({ s = 0.81 }):l_text("\t\tPartial Reload:"):r_text("%.2fs", {data = {timers.shotgun_reload_exit_not_empty / reload_mul}})
				self:row({ s = 0.81 }):l_text("\t\tFull Reload:"):r_text("%.2fs", {data = {timers.shotgun_reload_exit_empty / reload_mul}})
			end
		else
			self:row({ s = 0.9 }):l_text("\tFirst Shell:"):r_text("%.2fs", {data = {(17 / 30 - 0.03) / reload_mul}})
			self:row({ s = 0.9 }):l_text("\tEach Additional Shell:"):r_text("%.2fs", {data = {17 / 30 / reload_mul}})
			self:row({ s = 0.9 }):l_text("\tFull:"):r_text("%.2fs", {data = {(mag * 17 / 30 - 0.03) / reload_mul}})
			self:row({ s = 0.9 }):l_text("\tEnd delay (Cancelable):")
			self:row({ s = 0.81 }):l_text("\t\tPartial Reload:"):r_text("%.2fs", {data = {0.3 / reload_mul}})
			self:row({ s = 0.81 }):l_text("\t\tFull Reload:"):r_text("%.2fs", {data = {0.7 / reload_mul}})
		end
	end

	if self._data.tweak.category == "saw" then
		return
	end

	self:row({ h = 15 })
	self:row():l_text("Time To Empty:"):r_text("%.2fs", {data = {mag * rof - rof}})
end



function InventoryStatsPopup:_primaries_totalammo()
	local pickup = self._data.tweak.AMMO_PICKUP
	local ammo_data = self._data.ammo_data
	local skill_pickup = 1 + managers.player:upgrade_value("player", "pick_up_ammo_multiplier", 1) + managers.player:upgrade_value("player", "pick_up_ammo_multiplier_2", 1) - 2
	local ammo_pickup_min_mul = ammo_data and ammo_data.ammo_pickup_min_mul or skill_pickup
	local ammo_pickup_max_mul = ammo_data and ammo_data.ammo_pickup_max_mul or skill_pickup

	self:row():l_text("Index Values:")
	self:row({ s = 0.9 }):l_text("\tBase:"):r_text("%d", {data = {self._data.base_stats.totalammo.index}})
	self:row({ s = 0.9 }):l_text("\tMod:"):r_text("%d", {data = {self._data.mods_stats.totalammo.index}})
	local bounded_total = math.clamp(self._data.base_stats.totalammo.index + self._data.mods_stats.totalammo.index, 1, #tweak_data.weapon.stats.total_ammo_mod)
	self:row({ s = 0.9 }):l_text("\tTotal:"):r_text("%d", {data = {bounded_total}})
	self:row({ h = 15 })

	self:row():l_text("Ammo Pickup Range:")
	self:row({ s = 0.9 }):l_text("\tBase:"):r_text("%.2f - %.2f", {data = {pickup[1], pickup[2]}})
	self:row({ s = 0.9 }):l_text("\tTotal:"):r_text("%.2f - %.2f", {data = {pickup[1] * ammo_pickup_min_mul, pickup[2] * ammo_pickup_max_mul}})

	if self._data.tweak.category == "saw" then
		return
	end

	local damage = self._data.base_stats.damage.value + self._data.mods_stats.damage.value + self._data.skill_stats.damage.value
	local totalammo = self._data.base_stats.totalammo.value + self._data.mods_stats.totalammo.value + self._data.skill_stats.totalammo.value
	local mag = self._data.base_stats.magazine.value + self._data.mods_stats.magazine.value + self._data.skill_stats.magazine.value

	self:row({ h = 15 })
	self:row():l_text("Damage Potential:")
	self:row({ s = 0.9 }):l_text("\tPer Pickup (avg):"):r_text("%.1f", {data = {(damage * pickup[1] * ammo_pickup_min_mul + damage * pickup[2] * ammo_pickup_max_mul) / 2}})
	self:row({ s = 0.9 }):l_text("\tPer Magazine:"):r_text("%.1f", {data = {damage * mag}})
	self:row({ s = 0.9 }):l_text("\tTotal:"):r_text("%.1f", {data = {damage * totalammo}})
end



function InventoryStatsPopup:_primaries_fire_rate()
	if self._data.tweak.category == "saw" then
		return
	end

	local akimbo_mul = self._data.category == "akimbo" and 2 or 1
	local charge_time = self._data.tweak.charge_data and self._data.tweak.charge_data.max_t
	local rof = 60 / (self._data.base_stats.fire_rate.value + self._data.mods_stats.fire_rate.value + self._data.skill_stats.fire_rate.value + (charge_time or 0)) / akimbo_mul
	local dmg = self._data.base_stats.damage.value + self._data.mods_stats.damage.value + self._data.skill_stats.damage.value
	local mag = self._data.base_stats.magazine.value + self._data.mods_stats.magazine.value + self._data.skill_stats.magazine.value
	local timers = self._data.tweak.timers
	local reload_mul = managers.blackmarket:_convert_add_to_mul(1 + (1 - managers.player:upgrade_value(self._data.category, "reload_speed_multiplier", 1)) + (1 - managers.player:upgrade_value("weapon", "passive_reload_speed_multiplier", 1)) + (1 - managers.player:upgrade_value(self._data.name, "reload_speed_multiplier", 1)))
	if self._data.category == "bow" then reload_mul = reload_mul * 3 end
	local reload_not_empty = timers and timers.reload_not_empty
	local reload_empty = timers and timers.reload_empty

	if charge_time then
		self:row():l_text("Charge Time:"):r_text("%.1fs", {data = {charge_time}})
		if self._data.category == "bow" then
			self:row():l_text("Charge Threshold:"):r_text("%.1fs", {data = {0.2}})
		end
		self:row({ h = 15 })
	end
	self:row():l_text("DPS:"):r_text("%.1f", {data = {dmg / rof}})
	if reload_not_empty then
		local dps_string = charge_time and "DPS (factoring reloads and charging):" or "DPS (factoring reloads):"
		if reload_not_empty < reload_empty then
			self:row():l_text(dps_string):r_text("%.1f", {data = {(dmg / rof) * ((mag - akimbo_mul) * rof) / ((mag - akimbo_mul) * rof + reload_not_empty / reload_mul)}})
		else
			self:row():l_text(dps_string):r_text("%.1f", {data = {(dmg / rof * (mag * rof)) / (mag * rof + reload_empty / reload_mul)}})
		end
	end

end



function InventoryStatsPopup:_primaries_damage()
	if self._data.tweak.category == "saw" then
		return
	end

	local global_difficulty_multiplier = nil
	if Global.game_settings.difficulty == "overkill_290" then global_difficulty_multiplier = true end

	local damage_base = self._data.base_stats.damage.value / tweak_data.gui.stats_present_multiplier
	local damage_mod = self._data.mods_stats.damage.value / tweak_data.gui.stats_present_multiplier
	local damage_skill = self._data.skill_stats.damage.value / tweak_data.gui.stats_present_multiplier
	local damage_total = damage_base + damage_mod + damage_skill
	local ammo_data = self._data.ammo_data
	local pierces_shields = self._data.tweak.can_shoot_through_shield or (ammo_data and ammo_data.can_shoot_through_shield)
	local explosive = ammo_data and (ammo_data.bullet_class == "InstantExplosiveBulletBase" or ammo_data.launcher_grenade == "west_arrow_exp") or self._data.category == "grenade_launcher"
	local incendiary = ammo_data and (ammo_data.bullet_class == "FlameBulletBase" or ammo_data.launcher_grenade == "launcher_incendiary") or self._data.category == "flamethrower"
	local poisonous = ammo_data and ammo_data.dot_data and ammo_data.dot_data.type == "poison"
	local no_hs = explosive or incendiary

	self:row():l_text("Index Values:")
	self:row({ s = 0.9 }):l_text("\tBase:"):r_text("%d", {data = {self._data.base_stats.damage.index}})
	self:row({ s = 0.9 }):l_text("\tMod:"):r_text("%d", {data = {self._data.mods_stats.damage.index}})
	local bounded_total = math.clamp(self._data.base_stats.damage.index + self._data.mods_stats.damage.index, 1, #tweak_data.weapon.stats.damage)
	self:row({ s = 0.9 }):l_text("\tTotal:"):r_text("%d", {data = {bounded_total}})
	self:row({ h = 15 })

	if explosive or incendiary then
		if self._data.name == "gre_m79" or self._data.name == "m32" then
			if incendiary then
				self:row():l_text("Napalm:")
				self:row({ s = 0.9 }):l_text("\tRadius:"):r_text("%.2fm", {data = {tweak_data.projectiles.launcher_incendiary.range * 3 / 100}})
				self:row({ s = 0.9 }):l_text("\tDuration:"):r_text("%.1fs", {data = {tweak_data.projectiles.launcher_incendiary.burn_duration}})
				self:row({ s = 0.9 }):l_text("\tDPS:"):r_text("%.0f", {data = {tweak_data.projectiles.launcher_incendiary.damage / tweak_data.projectiles.launcher_incendiary.burn_tick_period * tweak_data.gui.stats_present_multiplier}})
				self:row({ h = 15 })
			else
				self:row():l_text("Blast Radius:"):r_text("%.2fm", {data = {tweak_data.projectiles.launcher_frag.range / 100}})
			end
		end
		if self._data.name == "rpg7" then self:row():l_text("Blast Radius:"):r_text("%.2fm", {data = {tweak_data.projectiles.launcher_rocket.range / 100}}) end
		if self._data.name == "plainsrider" then self:row():l_text("Blast Radius:"):r_text("%dm", {data = {2}}) end
		if incendiary then
			self:row():l_text("Fire DOT:")
			if ammo_data.fire_dot_data then
				local fire = ammo_data.fire_dot_data
				self:row({ s = 0.9 }):l_text("\tApplication Chance:"):r_text("%.0f%%", {data = {fire.dot_trigger_chance}})
				self:row({ s = 0.9 }):l_text("\tDuration:"):r_text("%.1fs", {data = {fire.dot_length - .1}})
				self:row({ s = 0.9 }):l_text("\tDPS:"):r_text("%.2f", {data = {fire.dot_damage / fire.dot_tick_period * tweak_data.gui.stats_present_multiplier}})
			elseif ammo_data.launcher_grenade == "launcher_incendiary" then
				local fire = tweak_data.projectiles.launcher_incendiary.fire_dot_data
				self:row({ s = 0.9 }):l_text("\tDuration:"):r_text("%.1fs", {data = {fire.dot_length - .1}})
				self:row({ s = 0.9 }):l_text("\tDPS:"):r_text("%.2f", {data = {fire.dot_damage / fire.dot_tick_period * tweak_data.gui.stats_present_multiplier}})
			end
		end
		self:row({ h = 15 })
	end

	if poisonous then
		local poison = tweak_data.dot_types.poison
		self:row():l_text("Poison DOT:")
		self:row({ s = 0.9 }):l_text("\tCripple Chance:"):r_text("%.0f%%", {data = {poison.hurt_animation_chance * 100}})
		self:row({ s = 0.9 }):l_text("\tDuration:"):r_text("%.1fs", {data = {poison.dot_length - .5}})
		self:row({ s = 0.9 }):l_text("\tDPS:"):r_text("%.2f", {data = {poison.dot_damage * 2 * tweak_data.gui.stats_present_multiplier}})
		self:row({ h = 15 })
	end

	local difficulties = {
		{ id = "ok", name = "OK" },
		{ id = "dw", name = "DW", hp = 1.7, hs = 0.75 },
	}
	local enemies = {
		{ id = "fbi_swat", name = "FBI Swat (Green)", difficulty_override = { dw = { hp = tweak_data.character.fbi_swat.HEALTH_INIT, hs = tweak_data.character.fbi_swat.headshot_dmg_mul }}},
		{ id = "fbi_heavy_swat", name = "FBI Heavy Swat (Tan)"},
		{ id = "city_swat", name = "Murky / GenSec Elite (Gray)", difficulty_override = { dw = { hp = 24, hs = tweak_data.character.fbi_swat.HEALTH_INIT / 8 }}},
		{ id = "taser", name = "Taser", is_special = true },
		{ id = "shield", name = pierces_shields and "Shield (Piercing)" or "Shield", is_special = true , damage_mul = pierces_shields and .25 or 1 },
		{ id = "spooc", name = "Cloaker", is_special = true  },
	}
	if no_hs then
		table.insert(enemies, { id = "tank", name = "Bulldozer", is_special = true  })
	end

	local hs_mult = no_hs and 1 or managers.player:upgrade_value("weapon", "passive_headshot_damage_multiplier", 1)
	local special_mult = no_hs and 1 or managers.player:upgrade_value("weapon", "special_damage_taken_multiplier", 1)

	self:row():l_text(no_hs and "Shots to kill:" or "Headshots to kill:"):r_text("(OK / DW)")
	for _, data in ipairs(enemies) do
		local row = self:row({ s = 0.9 }):l_text("\t\t" .. data.name .. ":")
		for i, diff in ipairs(difficulties) do
			local hp = data.difficulty_override and data.difficulty_override[diff.id] and data.difficulty_override[diff.id].hp or (tweak_data.character[data.id].HEALTH_INIT * (diff.hp or 1))
			local hs = incendiary and 1
				or explosive and (tweak_data.character[data.id].damage.explosion_damage_mul or 1)
				or data.difficulty_override and data.difficulty_override[diff.id] and data.difficulty_override[diff.id].hs
				or (tweak_data.character[data.id].headshot_dmg_mul * (diff.hs or 1))
			local raw_damage = damage_total * (data.is_special and special_mult or 1) * (data.damage_mul or 1) * hs * hs_mult * (global_difficulty_multiplier and 1.7/.75 or 1)
			local adjusted_damage = math.ceil(math.max(raw_damage / (hp/512), 1)) * (hp/512)
			row:r_text("%2d (%.2f)", { no_trim = true, data = { math.ceil(hp / adjusted_damage), hp / adjusted_damage }})
			if i ~= #difficulties then
				row:r_text("/")
			end
		end
	end

	--Dozer special case
	if not no_hs then
		for i, diff in ipairs(difficulties) do
			local hp = tweak_data.character.tank.HEALTH_INIT * (diff.hp or 1) * (global_difficulty_multiplier and 1/1.7 or 1)
			local hs = tweak_data.character.tank.headshot_dmg_mul * (diff.hs or 1) * (global_difficulty_multiplier and 1/.75 or 1)
			local adjusted_body_damage = math.ceil(math.max(damage_total * special_mult / (hp/512), 1)) * (hp/512)
			local adjusted_hs_damage = math.ceil(math.max(damage_total * special_mult * hs * hs_mult / (hp/512), 1)) * (hp/512)
			local adjusted_armor_damage = math.ceil(damage_total * special_mult * 16.384) / 16.384
			local total_bullets = 0

			local is_dead
			local str = "%2d ("
			local str_data = {}
			for i, armor_hp in ipairs({ 15, 16 }) do
				if not is_dead then
					local tmp_hp = armor_hp

					while hp > 0 and tmp_hp > 0 do
						hp = hp - adjusted_body_damage
						tmp_hp = tmp_hp - adjusted_armor_damage
						total_bullets = total_bullets + 1
					end

					is_dead = hp <= 0
					str = str .. "%.2f" .. (is_dead and "" or " + ")
					table.insert(str_data, armor_hp / adjusted_armor_damage)
				end
			end

			if not is_dead then
				local bullets = hp / adjusted_hs_damage
				total_bullets = total_bullets + math.ceil(bullets)
				str = str .. "%.2f"
				table.insert(str_data, bullets)
			end
			table.insert(str_data, 1, total_bullets)

			self:row({ s = 0.9 }):l_text("\t\tBulldozer (" .. diff.name .. "):"):r_text(str .. ")", { no_trim = true, data = str_data })
		end
	end

	if self._data.category ~= "shotgun" then
		return
	end

	local near = self._data.tweak.damage_near / 100
	local far = self._data.tweak.damage_far / 100
	local near_mul = ammo_data and ammo_data.damage_near_mul or 1
	local far_mul = ammo_data and ammo_data.damage_far_mul or 1

	self:row():l_text("Shotgun Stats:")
	self:row({ s = 0.9 }):l_text("\tPellets:"):r_text("%d", {data = {ammo_data and ammo_data.rays or self._data.tweak.rays}})
	if explosive then
		self:row({ s = 0.9 }):l_text("\tBlast Radius:"):r_text("%dm", {data = {2}})
	end
	self:row({ s = 0.9 }):l_text("\tBase Falloff Range:"):r_text("%.1fm to %.1fm", {data = {near, near + far}})
	if near_mul ~= 1 or far_mul ~= 1 then
		self:row({ s = 0.9 }):l_text("\tTotal Falloff Range:"):r_text("%.1fm to %.1fm", {data = {near * near_mul, near * near_mul + far * far_mul}})
	end
end



function InventoryStatsPopup:_primaries_spread()
	if self._data.tweak.category == "saw" then
		return
	end

	local base_and_mod = tweak_data.weapon.stats.spread[math.clamp(self._data.base_stats.spread.index + self._data.mods_stats.spread.index, 1, #tweak_data.weapon.stats.spread)]
	local skill_value = self._data.skill_stats.spread.value - 1
	local global_spread_mul = self._data.tweak.stats_modifiers and self._data.tweak.stats_modifiers.spread or 1
	local spread = self._data.tweak.spread

	local function DR(stance)
		local stance_and_skill = stance - skill_value
		if stance_and_skill >= 1 then
			return stance_and_skill * global_spread_mul * base_and_mod
		end
		return (1 / (2 - stance_and_skill) * global_spread_mul * base_and_mod)
	end

	self:row():l_text("Index Values:")
	self:row({ s = 0.9 }):l_text("\tBase:"):r_text("%d", {data = {self._data.base_stats.spread.index}})
	self:row({ s = 0.9 }):l_text("\tMod:"):r_text("%d", {data = {self._data.mods_stats.spread.index}})
	local bounded_total = math.clamp(self._data.base_stats.spread.index + self._data.mods_stats.spread.index, 1, #tweak_data.weapon.stats.spread)
	self:row({ s = 0.9 }):l_text("\tTotal:"):r_text("%d", {data = {bounded_total}})
	self:row({ h = 15 })

	self:row():l_text("Base & Mod Multiplier:"):r_text("%.2f", {data = {base_and_mod}})
	if skill_value ~= 0 then self:row():l_text("Skill Additive Modifier:"):r_text("%.2f", {data = {skill_value * -1}}) end
	if global_spread_mul ~= 1 then self:row():l_text("Innate Spread Multiplier:"):r_text("%.2f", {data = {global_spread_mul}}) end
	self:row({ h = 15 })
	self:row():l_text("Stance Spread Multipliers (Total Spread):")
	self:row({ s = 0.9 }):l_text("\tADS:"):r_text("%.2f (%.2f)", {data = {spread.steelsight, DR(spread.steelsight)}})
	self:row({ s = 0.9 }):l_text("\tADS-Moving:"):r_text("%.2f (%.2f)", {data = {spread.moving_steelsight, DR(spread.moving_steelsight)}})
	self:row({ s = 0.9 }):l_text("\tStanding:"):r_text("%.2f (%.2f)", {data = {spread.standing, DR(spread.standing)}})
	self:row({ s = 0.9 }):l_text("\tStanding-Moving:"):r_text("%.2f (%.2f)", {data = {spread.moving_standing, DR(spread.moving_standing)}})
	self:row({ s = 0.9 }):l_text("\tCrouching:"):r_text("%.2f (%.2f)", {data = {spread.crouching, DR(spread.crouching)}})
	self:row({ s = 0.9 }):l_text("\tCrouching-Moving:"):r_text("%.2f (%.2f)", {data = {spread.moving_crouching, DR(spread.moving_crouching)}})
end



function InventoryStatsPopup:_primaries_recoil()
	local base_and_mod = tweak_data.weapon.stats.recoil[math.clamp(self._data.base_stats.recoil.index + self._data.mods_stats.recoil.index, 1, #tweak_data.weapon.stats.recoil)]
	local skill = managers.blackmarket:recoil_multiplier(self._data.name, self._data.category, self._data.silencer, self._data.blueprint)
	local kick = self._data.tweak.kick
	local recoil_mul = base_and_mod * skill

	self:row():l_text("Index Values:")
	self:row({ s = 0.9 }):l_text("\tBase:"):r_text("%d", {data = {self._data.base_stats.recoil.index}})
	self:row({ s = 0.9 }):l_text("\tMod:"):r_text("%d", {data = {self._data.mods_stats.recoil.index}})
	local bounded_total = math.clamp(self._data.base_stats.recoil.index + self._data.mods_stats.recoil.index, 1, #tweak_data.weapon.stats.recoil)
	self:row({ s = 0.9 }):l_text("\tTotal:"):r_text("%d", {data = {bounded_total}})
	self:row({ h = 15 })

	self:row():l_text("Base & Mod Multiplier:"):r_text("%.2f", {data = {base_and_mod}})
	self:row():l_text("Skill Multiplier:"):r_text("%.2f", {data = {skill}})
	self:row({ h = 15 })
	self:row():l_text("Base Kick Range:")
	self:row({ s = 0.9 }):l_text("\tVertical:"):r_text("%.2f to %.2f", {data = {kick.standing[1], kick.standing[2]}})
	self:row({ s = 0.9 }):l_text("\tHorizontal:"):r_text("%.2f to %.2f", {data = {kick.standing[3], kick.standing[4]}})
	self:row({ h = 15 })
	self:row():l_text("Total Kick Range:")
	self:row({ s = 0.9 }):l_text("\tVertical:"):r_text("%.2f to %.2f", {data = {kick.standing[1] * recoil_mul, kick.standing[2] * recoil_mul}})
	self:row({ s = 0.9 }):l_text("\tHorizontal:"):r_text("%.2f to %.2f", {data = {kick.standing[3] * recoil_mul, kick.standing[4] * recoil_mul}})
end



function InventoryStatsPopup:_primaries_concealment()
	local base_alert_index = self._data.tweak.stats and self._data.tweak.stats.alert_size
	local mod_alert_index = self._data.factory_id and self._data.blueprint and managers.weapon_factory:get_stats(self._data.factory_id, self._data.blueprint)["alert_size"] or 0
	local total_alert = base_alert_index and mod_alert_index and tweak_data.weapon.stats.alert_size[math.clamp(base_alert_index + mod_alert_index, 1, #tweak_data.weapon.stats.alert_size)]
	local sawing_alert = total_alert and self._data.tweak.hit_alert_size_increase and tweak_data.weapon.stats.alert_size[math.clamp(base_alert_index + mod_alert_index - self._data.tweak.hit_alert_size_increase, 1, #tweak_data.weapon.stats.alert_size)]

	if self._data.ammo_data and self._data.ammo_data.bullet_class == "InstantExplosiveBulletBase" or self._data.category == "grenade_launcher" then
		self:row():l_text("Alert Radius (Explosion):"):r_text("100m")
	elseif total_alert then
		if sawing_alert then
			self:row():l_text("Alert Radius:")
			self:row({ s = 0.9 }):l_text("\tRegular:"):r_text("%.1fm", {data = {total_alert / 100}})
			self:row({ s = 0.9 }):l_text("\tSawing:"):r_text("%.1fm", {data = {sawing_alert / 100}})
		else
			self:row():l_text("Alert Radius:"):r_text("%.1fm", {data = {total_alert / 100}})
		end
	end

	if managers.blackmarket:equipped_weapon_slot(self._data.inventory_category) ~= self._data.inventory_slot then
		return
	end

	local conceal_crit_bonus = managers.player:critical_hit_chance() * 100
	local detection_time_multiplier = managers.blackmarket:get_suspicion_of_local_player()
	local detection_distance_multiplier = 1 / math.sqrt(detection_time_multiplier)

	self:row({ h = 15 })
	self:row():l_text("Critical Hit Chance:"):r_text("%.0f%%", {data = {conceal_crit_bonus}})
	self:row({ h = 15 })
	self:row():l_text("Concealment Detection Stats:")
	self:row({ s = 0.9 }):l_text("\tTime Multiplier:"):r_text("%.2f", {data = {detection_time_multiplier}})
	self:row({ s = 0.9 }):l_text("\tDistance Multiplier:"):r_text("%.2f", {data = {detection_distance_multiplier}})

end



function InventoryStatsPopup:_primaries_suppression()
	if self._data.category == "grenade_launcher" or self._data.category == "saw" or self._data.category == "bow" then
		return
	end

	local panic_chance = self._data.tweak.panic_suppression_chance and self._data.tweak.panic_suppression_chance * 100
	local base_and_mod = (self._data.base_stats.suppression.value + self._data.mods_stats.suppression.value + 2) / 10
	local skill = managers.blackmarket:threat_multiplier(self._data.name, self._data.category, false)
	local global_suppression_mul = self._data.tweak.stats_modifiers and self._data.tweak.stats_modifiers.suppression or 1

	self:row():l_text("Index Values:")
	self:row({ s = 0.9 }):l_text("\tBase:"):r_text("%d", {data = {self._data.base_stats.suppression.index}})
	self:row({ s = 0.9 }):l_text("\tMod:"):r_text("%d", {data = {self._data.mods_stats.suppression.index}})
	local bounded_total = math.clamp(self._data.base_stats.suppression.index + self._data.mods_stats.suppression.index, 1, #tweak_data.weapon.stats.suppression)
	self:row({ s = 0.9 }):l_text("\tTotal:"):r_text("%d", {data = {bounded_total}})
	self:row({ h = 15 })

	if panic_chance then self:row():l_text("Panic Chance (requires Disturbing the Peace):"):r_text("%.0f%%", {data = {panic_chance}}) end
	self:row():l_text("Base + Mod Suppression:"):r_text("%.2f", {data = {base_and_mod}})
	self:row():l_text("Skill Multiplier:"):r_text("%.2f", {data = {skill}})
	if global_suppression_mul ~= 1 then self:row():l_text("Innate Suppression Multiplier:"):r_text("%.2f", {data = {global_suppression_mul}}) end
	self:row({ h = 15 })
	self:row():l_text("Total Maximum Suppression:"):r_text("%.2f", {data = {base_and_mod * skill * global_suppression_mul}})
end



InventoryStatsPopup._secondaries_magazine = InventoryStatsPopup._primaries_magazine
InventoryStatsPopup._secondaries_totalammo = InventoryStatsPopup._primaries_totalammo
InventoryStatsPopup._secondaries_damage = InventoryStatsPopup._primaries_damage
InventoryStatsPopup._secondaries_fire_rate = InventoryStatsPopup._primaries_fire_rate
InventoryStatsPopup._secondaries_spread = InventoryStatsPopup._primaries_spread
InventoryStatsPopup._secondaries_recoil = InventoryStatsPopup._primaries_recoil
InventoryStatsPopup._secondaries_concealment = InventoryStatsPopup._primaries_concealment
InventoryStatsPopup._secondaries_suppression = InventoryStatsPopup._primaries_suppression



function InventoryStatsPopup:_melee_weapons_damage()
	local melee = managers.blackmarket:get_melee_weapon_data(self._data.name)
	local base_stats, mods_stats, skill_stats = managers.menu_component._blackmarket_gui:_get_melee_weapon_stats(self._data.name)
	local uncharged_damage = base_stats.damage.min_value + mods_stats.damage.min_value + skill_stats.damage.min_value
	local charged_damage = base_stats.damage.max_value + mods_stats.damage.max_value + skill_stats.damage.max_value
	local uncharged_kd = base_stats.damage_effect.min_value + mods_stats.damage_effect.min_value + skill_stats.damage_effect.min_value
	local charged_kd = base_stats.damage_effect.max_value + mods_stats.damage_effect.max_value + skill_stats.damage_effect.max_value
	local charge_time = base_stats.charge_time.value + mods_stats.charge_time.value + skill_stats.charge_time.value

	self:row():l_text("Attack Delay:"):r_text("%.2fs", {data = {melee.instant and 0 or melee.melee_damage_delay}})
	self:row():l_text("Cooldown:"):r_text("%.2fs", {data = {melee.repeat_expire_t}})
	if not melee.instant then self:row():l_text("Unequip Delay:"):r_text("%.2fs", {data = {melee.expire_t}}) end
	self:row({ h = 15 })
	if melee.instant then
		self:row():l_text("DPS:"):r_text("%.2f", {data = {uncharged_damage / melee.repeat_expire_t}})
		self:row():l_text("KdPS:"):r_text("%.2f", {data = {uncharged_kd / melee.repeat_expire_t}})
	else
		self:row():l_text("Uncharged DPS:"):r_text("%.2f", {data = {uncharged_damage / melee.repeat_expire_t}})
		self:row():l_text("Charged DPS:"):r_text("%.2f", {data = {charged_damage / (melee.repeat_expire_t + charge_time)}})
		self:row({ h = 15 })
		self:row():l_text("Uncharged KdPS:"):r_text("%.2f", {data = {uncharged_kd / melee.repeat_expire_t}})
		self:row():l_text("Charged KdPS:"):r_text("%.2f", {data = {charged_kd / (melee.repeat_expire_t + charge_time)}})
	end
end

InventoryStatsPopup._melee_weapons_damage_effect = InventoryStatsPopup._melee_weapons_damage
InventoryStatsPopup._melee_weapons_charge_time = InventoryStatsPopup._melee_weapons_damage
InventoryStatsPopup._melee_weapons_range = InventoryStatsPopup._melee_weapons_damage
InventoryStatsPopup._melee_weapons_concealment = InventoryStatsPopup._melee_weapons_damage



function InventoryStatsPopup:_armors_armor()
	local armor_tweak = tweak_data.blackmarket.armors[self._data.name]
	local player_tweak = tweak_data.player
	local health = player_tweak.damage.HEALTH_INIT * tweak_data.gui.stats_present_multiplier
	local health_mul = managers.player:health_skill_multiplier()
	local regen_time = player_tweak.damage.REGENERATE_TIME * managers.player:body_armor_regen_multiplier(false)
	local speed = player_tweak.movement_state.standard.movement.speed
	local armor_mul = managers.player:mod_movement_penalty(managers.player:body_armor_value("movement", armor_tweak.upgrade_level, 1))
	local walking_mul = armor_mul + managers.player:upgrade_value("player", "walk_speed_multiplier", 1) + managers.player:upgrade_value("player", "movement_speed_multiplier", 1) - 2
	local running_mul = armor_mul + managers.player:upgrade_value("player", "run_speed_multiplier", 1) + managers.player:upgrade_value("player", "movement_speed_multiplier", 1) - 2
	local steelsight_mul = armor_mul + managers.player:upgrade_value("player", "steelsight_speed_multiplier", 1) + managers.player:upgrade_value("player", "movement_speed_multiplier", 1) - 2
	local crouch_mul = armor_mul + managers.player:upgrade_value("player", "crouch_speed_multiplier", 1) + managers.player:upgrade_value("player", "movement_speed_multiplier", 1) - 2

	self:row():l_text("Regeneration Delay: "):r_text("%.1fs", {data = {regen_time}})
	self:row({ h = 15 })
	-- self:row():l_text("Player Health:")
	-- self:row({ s = 0.9 }):l_text("\tBase:"):r_text("%.1f", {data = {health}})
	-- self:row({ s = 0.9 }):l_text("\tTotal:"):r_text("%.1f", {data = {health * health_mul}})
	-- self:row({ h = 15 })
	self:row():l_text("Movement Speed:")
	self:row({ s = 0.9 }):l_text("\tWalking:"):r_text("%.3f m/s", {data = {speed.STANDARD_MAX * walking_mul / 100}})
	self:row({ s = 0.9 }):l_text("\tSprinting:"):r_text("%.3f m/s", {data = {speed.RUNNING_MAX * running_mul / 100}})
	self:row({ s = 0.9 }):l_text("\tCrouching:"):r_text("%.3f m/s", {data = {speed.CROUCHING_MAX * crouch_mul / 100}})
	self:row({ s = 0.9 }):l_text("\tAiming:"):r_text("%.3f m/s", {data = {managers.player:has_category_upgrade("player", "steelsight_normal_movement_speed") and (speed.STANDARD_MAX * walking_mul / 100) or (speed.STEELSIGHT_MAX * steelsight_mul / 100)}})
end

InventoryStatsPopup._armors_health = InventoryStatsPopup._armors_armor
InventoryStatsPopup._armors_concealment = InventoryStatsPopup._armors_armor
InventoryStatsPopup._armors_movement = InventoryStatsPopup._armors_armor
InventoryStatsPopup._armors_dodge = InventoryStatsPopup._armors_armor
InventoryStatsPopup._armors_damage_shake = InventoryStatsPopup._armors_armor
InventoryStatsPopup._armors_stamina = InventoryStatsPopup._armors_armor



function InventoryStatsPopup:_mods_magazine()
	local index_stats = {}
	for _, stat in pairs(self._data.stat_table) do
		index_stats[stat.name] = self._data.stats and self._data.stats[stat.name] or 0
	end

	self:row():l_text("Index Values:")
	if self._data.type == "sight" then self:row({ s = 0.9 }):l_text("\tZOOM"):r_text("%d", {data = {self._data.stats.zoom or 0}}) end
	for _, stat in pairs(self._data.stat_table) do
		if stat.name == "fire_rate" or stat.name == "magazine" then
			self:row({ s = 0.9 }):l_text("\t" .. utf8.to_upper(managers.localization:text("bm_menu_" .. stat.name))):r_text("N/A")
		else
			self:row({ s = 0.9 }):l_text("\t" .. utf8.to_upper(managers.localization:text("bm_menu_" .. stat.name))):r_text("%d", {data = {index_stats[stat.name]}})
		end
	end
end

InventoryStatsPopup._mods_totalammo = InventoryStatsPopup._mods_magazine
InventoryStatsPopup._mods_damage = InventoryStatsPopup._mods_magazine
InventoryStatsPopup._mods_fire_rate = InventoryStatsPopup._mods_magazine
InventoryStatsPopup._mods_spread = InventoryStatsPopup._mods_magazine
InventoryStatsPopup._mods_recoil = InventoryStatsPopup._mods_magazine
InventoryStatsPopup._mods_concealment = InventoryStatsPopup._mods_magazine
InventoryStatsPopup._mods_suppression = InventoryStatsPopup._mods_magazine

function InventoryStatsPopup:_grenades()
	local stats = self._data.stats
	if stats.damage then self:row():l_text("Damage:"):r_text("%.2f", {data = {stats.damage * tweak_data.gui.stats_present_multiplier}}) end
	if stats.player_damage then self:row():l_text("Player Damage:"):r_text("%.2f", {data = {stats.player_damage * tweak_data.gui.stats_present_multiplier}}) end
	if stats.range then self:row():l_text("Radius:"):r_text("%.2fm", {data = {(stats.fire_dot_data and 3 or 1) * (stats.range / 100)}}) end
	if stats.burn_duration and stats.burn_tick_period then
		self:row():l_text("Napalm:")
		self:row({ s = 0.9 }):l_text("\tDuration:"):r_text("%.1fs", {data = {stats.burn_duration}})
		self:row({ s = 0.9 }):l_text("\tDPS:"):r_text("%.0f", {data = {stats.damage / stats.burn_tick_period * tweak_data.gui.stats_present_multiplier}})
		self:row({ h = 15 })
	end
	if stats.fire_dot_data then
		local fire = stats.fire_dot_data
		self:row():l_text("Fire DOT:")
		--self:row({ s = 0.9 }):l_text("\tApplication Chance:"):r_text("%.0f%%", {data = {fire.dot_trigger_chance}})
		self:row({ s = 0.9 }):l_text("\tDuration:"):r_text("%.1fs", {data = {fire.dot_length - .1}})
		self:row({ s = 0.9 }):l_text("\tDPS:"):r_text("%.2f", {data = {fire.dot_damage / fire.dot_tick_period * tweak_data.gui.stats_present_multiplier}})
	end
	if stats.dot_data then
		if stats.dot_data.type == "poison" then
			local dot = tweak_data:get_dot_type_data(stats.dot_data.type)
			self:row():l_text("Poison DOT:")
			self:row({ s = 0.9 }):l_text("\tDuration:"):r_text("%.1fs", {data = {dot.dot_length - .5}})
			self:row({ s = 0.9 }):l_text("\tDPS:"):r_text("%.2f", {data = {dot.dot_damage * 2 * tweak_data.gui.stats_present_multiplier}})
		end
	end
end

function InventoryStatsPopup:_deployables()
	local name = self._data.name
	local stats = self._data.stats
	self:row():l_text("Quantity:"):r_text("%d", {data = {stats.quantity + managers.player:equiptment_upgrade_value(name, "quantity")}})
	self:row():l_text("Deploy Time:"):r_text("%.2fs", {data = {stats.deploy_time * (stats.upgrade_deploy_time_multiplier and managers.player:upgrade_value(stats.upgrade_deploy_time_multiplier.category, stats.upgrade_deploy_time_multiplier.upgrade, 1) or 1)}})
	if tweak_data.interaction[name] and tweak_data.interaction[name].timer and name ~= "ecm_jammer" then
		self:row():l_text("Interact Time:"):r_text("%.2fs", {data = {tweak_data.interaction[name].timer * (tweak_data.interaction[name].upgrade_timer_multiplier and managers.player:upgrade_value(tweak_data.interaction[name].upgrade_timer_multiplier.category, tweak_data.interaction[name].upgrade_timer_multiplier.upgrade, 1) or 1)}})
	end
	if name == "trip_mine" then
		self:row():l_text("Interact Time:"):r_text("%.2fs", {data = {tweak_data.interaction.shaped_sharge.timer}}) --lol shaped_sharge
	elseif name == "ammo_bag" then
		self:row():l_text("Capacity:"):r_text("%d%%", {data = {(tweak_data.upgrades.ammo_bag_base + managers.player:upgrade_value("ammo_bag", "ammo_increase", 0)) * 100}})
	elseif name == "doctor_bag" then
		self:row():l_text("Charges:"):r_text("%d", {data = {tweak_data.upgrades.doctor_bag_base + managers.player:upgrade_value("doctor_bag", "amount_increase", 0)}})
	elseif name == "sentry_gun" then
		self:row():l_text("Ammo:"):r_text("%d", {data = {tweak_data.upgrades.sentry_gun_base_ammo * managers.player:upgrade_value("sentry_gun", "extra_ammo_multiplier", 1)}})
		self:row():l_text("Rate of Fire:"):r_text("%.1f", {data = {60 / tweak_data.weapon.sentry_gun.auto.fire_rate}})
		self:row():l_text("Damage:"):r_text("%.2f", {data = {tweak_data.weapon.sentry_gun.DAMAGE * managers.player:upgrade_value("sentry_gun", "damage_multiplier", 1) * tweak_data.gui.stats_present_multiplier}})
		self:row():l_text("Spread:"):r_text("%.2f", {data = {tweak_data.weapon.sentry_gun.SPREAD * managers.player:upgrade_value("sentry_gun", "spread_multiplier", 1)}})
		self:row():l_text("Turn Rate Multiplier:"):r_text("%.1f", {data = {managers.player:upgrade_value("sentry_gun", "rot_speed_multiplier", 1)}})
		self:row():l_text("Has Shield:"):r_text("%s", {data = {managers.player:has_category_upgrade("sentry_gun", "shield") and "Yes" or "No"}})
	elseif name == "ecm_jammer" then
		self:row():l_text("Duration:"):r_text("%.2fs", {data = {tweak_data.upgrades.ecm_jammer_base_battery_life * managers.player:upgrade_value("ecm_jammer", "duration_multiplier", 1) * managers.player:upgrade_value("ecm_jammer", "duration_multiplier_2", 1)}})
		self:row():l_text("Interact Time:")
		self:row({ s = 0.9 }):l_text("\tATMs:"):r_text("%.2fs", {data = {tweak_data.interaction.requires_ecm_jammer_atm.timer}})
		self:row({ s = 0.9 }):l_text("\tDoors:"):r_text(managers.player:has_category_upgrade("ecm_jammer", "can_open_sec_doors") and "%.2fs" or "N/A", {data = {tweak_data.interaction.requires_ecm_jammer_double.timer}})
		self:row({ s = 0.9 }):l_text("\tFeedback:"):r_text(managers.player:has_category_upgrade("ecm_jammer", "can_activate_feedback") and "%.2fs" or "N/A", {data = {tweak_data.interaction.ecm_jammer.timer * managers.player:upgrade_value("ecm_jammer", "interaction_speed_multiplier", 1)}})
		self:row({ h = 15 })
		local feedback_mul = managers.player:upgrade_value("ecm_jammer", "feedback_duration_boost", 1) * managers.player:upgrade_value("ecm_jammer", "feedback_duration_boost_2", 1)
		self:row():l_text("Feedback:")
		self:row({ s = 0.9 }):l_text("\tDuration:"):r_text("%.2fs to %.2fs", {data = {tweak_data.upgrades.ecm_feedback_min_duration * feedback_mul, tweak_data.upgrades.ecm_feedback_max_duration * feedback_mul}})
		self:row({ s = 0.9 }):l_text("\tRadius:"):r_text("%.2fm", {data = {tweak_data.upgrades.ecm_jammer_base_range / 100}})
	elseif name == "armor_kit" then

	elseif name == "first_aid_kit" then
		--self:row():l_text("Has Damage Reduction:"):r_text("%s", {data = {managers.player:has_category_upgrade("temporary", "first_aid_damage_reduction") and "Yes" or "No"}})
	elseif name == "bodybags_bag" then
		self:row():l_text("Charges:"):r_text("%d", {data = {tweak_data.upgrades.bodybag_crate_base}})
	else
		io.write("\nInvalid equipment\n")
	end
end
