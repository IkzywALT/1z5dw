--!nonstrict
--[[
	Luau Control Panel UI Library
	-----------------------------------------------------------------
	A dark, red-accent control panel: icon sidebar + two-column content.

	Works as a ModuleScript (require) or as a hosted script (loadstring).
	The last line of this file returns the Library table.

	Hierarchy:
		Library -> Window -> Tab -> Section -> Elements
		(Toggle, Dropdown, Button, Textbox, Label, Divider)

	Notification is available through Window:Notify / Library:Notify.

	Icons: every icon comes from the Lucide source through Library.IconService.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

---------------------------------------------------------------------
-- Theme / layout constants
---------------------------------------------------------------------
local Theme = {
	Background = Color3.fromHex("#090A0D"),
	Panel = Color3.fromHex("#141519"),
	Row = Color3.fromHex("#1B1C22"),
	RowHover = Color3.fromHex("#22232B"),
	Field = Color3.fromHex("#0C0D10"),
	Accent = Color3.fromHex("#F01824"),
	AccentHover = Color3.fromHex("#FF3541"),
	AccentPressed = Color3.fromHex("#C4121C"),
	Text = Color3.fromHex("#EAEAEE"),
	TextDim = Color3.fromHex("#B4B5BE"),
	TextMuted = Color3.fromHex("#6D6E79"),
	Border = Color3.fromHex("#24252C"),
	ToggleTrack = Color3.fromHex("#0E0F12"),
	ToggleKnobOff = Color3.fromHex("#9B9CA5"),
	White = Color3.new(1, 1, 1),
	Black = Color3.new(0, 0, 0),
	Success = Color3.fromHex("#2FD47A"),
	Warning = Color3.fromHex("#F5A623"),
}

local Layout = {
	SidebarWidth = 102,
	TabSize = 64,
	TabGap = 13,
	TabTop = 94,
	TabBottom = 14,
	RowHeight = 54,
	RowGap = 8,
	DropdownClosedHeight = 82,
	OptionHeight = 28,
	MaxVisibleOptions = 5,
}

local FONT_FAMILY = "rbxasset://fonts/families/GothamSSm.json"
local Fonts = {
	Regular = Font.new(FONT_FAMILY, Enum.FontWeight.Regular),
	Medium = Font.new(FONT_FAMILY, Enum.FontWeight.Medium),
	Bold = Font.new(FONT_FAMILY, Enum.FontWeight.Bold),
}

local Library = {}
Library.__index = Library
Library.Version = "1.0.0"
Library.Theme = Theme
Library._windows = {}

---------------------------------------------------------------------
-- Maid: collects connections / instances / cleanup functions
---------------------------------------------------------------------
local Maid = {}
Maid.__index = Maid

function Maid.new()
	return setmetatable({ _tasks = {} }, Maid)
end

function Maid:Give(item)
	table.insert(self._tasks, item)
	return item
end

function Maid:Connect(signal, callback)
	return self:Give(signal:Connect(callback))
end

function Maid:Clean()
	local tasks = self._tasks
	self._tasks = {}
	for _, item in tasks do
		local kind = typeof(item)
		if kind == "RBXScriptConnection" then
			item:Disconnect()
		elseif kind == "Instance" then
			item:Destroy()
		elseif kind == "function" then
			item()
		end
	end
end

---------------------------------------------------------------------
-- Instance helpers
---------------------------------------------------------------------
local function New(className, props, children)
	local inst = Instance.new(className)

	if inst:IsA("GuiObject") then
		inst.BorderSizePixel = 0
		if not (inst:IsA("Frame") or inst:IsA("CanvasGroup") or inst:IsA("ScrollingFrame")) then
			inst.BackgroundTransparency = 1
		end
		if inst:IsA("GuiButton") then
			inst.AutoButtonColor = false
		end
		if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
			inst.FontFace = Fonts.Medium
			inst.TextColor3 = Theme.Text
			inst.TextSize = 14
			inst.Text = ""
		end
	end

	local parent
	for key, value in props or {} do
		if key == "Parent" then
			parent = value
		else
			inst[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function Corner(radius)
	return New("UICorner", { CornerRadius = UDim.new(0, radius) })
end

local function CornerFull()
	return New("UICorner", { CornerRadius = UDim.new(1, 0) })
end

local function Stroke(color, thickness, transparency)
	return New("UIStroke", {
		Color = color,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

local function Padding(left, top, right, bottom)
	return New("UIPadding", {
		PaddingLeft = UDim.new(0, left),
		PaddingTop = UDim.new(0, top),
		PaddingRight = UDim.new(0, right),
		PaddingBottom = UDim.new(0, bottom),
	})
end

local function List(padding)
	return New("UIListLayout", {
		Padding = UDim.new(0, padding),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

local function Tween(inst, props, duration, style, direction)
	local tween = TweenService:Create(
		inst,
		TweenInfo.new(duration or 0.18, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
		props
	)
	tween:Play()
	return tween
end

-- Sets properties instantly or with a tween.
local function Apply(inst, props, animate, duration, style)
	if animate then
		return Tween(inst, props, duration, style)
	end
	for key, value in props do
		inst[key] = value
	end
	return nil
end

local function IsPointerInput(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
end

-- Shrinks `scaleHost` while `inputObject` is pressed. scaleHost should be
-- centre-anchored so it shrinks towards its middle.
local function AddPress(inputObject, maid, scaleHost, depth)
	local uiScale = New("UIScale", { Parent = scaleHost })
	maid:Connect(inputObject.InputBegan, function(input)
		if IsPointerInput(input) then
			Tween(uiScale, { Scale = depth or 0.94 }, 0.08)
		end
	end)
	maid:Connect(inputObject.InputEnded, function(input)
		if IsPointerInput(input) then
			Tween(uiScale, { Scale = 1 }, 0.18, Enum.EasingStyle.Back)
		end
	end)
	return uiScale
end

-- Drags `target` (scale-based Position) while the pointer is held on `handle`.
-- If `state` is given, state.moved is true after a drag of more than 4px so
-- click handlers can ignore the release that ends a drag.
local function MakeDraggable(handle, target, root, maid, state)
	local dragging = false
	local startPointer = Vector2.zero
	local startPosition = target.Position

	maid:Connect(handle.InputBegan, function(input)
		if not IsPointerInput(input) then
			return
		end
		dragging = true
		if state then
			state.moved = false
		end
		startPointer = Vector2.new(input.Position.X, input.Position.Y)
		startPosition = target.Position

		local changed
		changed = input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
				if changed then
					changed:Disconnect()
				end
			end
		end)
	end)

	maid:Connect(UserInputService.InputChanged, function(input)
		if not dragging then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local viewport = root.AbsoluteSize
		if viewport.X <= 0 or viewport.Y <= 0 then
			return
		end
		local delta = Vector2.new(input.Position.X, input.Position.Y) - startPointer
		if state and delta.Magnitude > 4 then
			state.moved = true
		end
		target.Position = UDim2.new(
			math.clamp(startPosition.X.Scale + delta.X / viewport.X, 0.02, 0.98),
			0,
			math.clamp(startPosition.Y.Scale + delta.Y / viewport.Y, 0.02, 0.98),
			0
		)
	end)
end

local function ResolveParent(custom)
	if custom then
		return custom
	end
	local ok, hui = pcall(function()
		return gethui()
	end)
	if ok and typeof(hui) == "Instance" then
		return hui
	end
	return Players.LocalPlayer:WaitForChild("PlayerGui")
end

---------------------------------------------------------------------
-- IconService: single entry point for every icon in the UI (Lucide)
--
-- Source:  local Icons = loadstring(game:HttpGet("https://molto.pages.dev/source.lua"))()
--          Icons.GetAsset("eye") -> table (or nil when the name is unknown):
--            IconName, Url, ImageRectSize, ImageRectOffset
--          Icons are spritesheet cells, so ImageRectSize/ImageRectOffset MUST be
--          assigned together with Image, otherwise the whole sheet is drawn.
--
-- In Studio (no HttpGet) call Library:SetIconSource(require(LucideModule)) with
-- latte-soft's lucide-roblox module; GetAsset returns the same fields.
---------------------------------------------------------------------
local IconService = {}

local ICON_SOURCE_URL = "https://molto.pages.dev/source.lua"
local ICON_ALIASES = {
	world = "globe",
	combat = "swords",
	sword = "swords",
	player = "user",
	account = "user",
	vehicle = "fuel",
	gear = "settings",
	cog = "settings",
}
local ICON_SIZE = 30 -- matches the 24px sprite cells 1:1 (sharpest); override per call if needed

local iconSource = nil
local iconLoadAttempted = false
local iconCache = {} -- [name] = normalized asset | false (known miss)
local iconWarned = {}

local function WarnOnce(key, message)
	if not iconWarned[key] then
		iconWarned[key] = true
		warn("[Library] " .. message)
	end
end

local function LoadIconSource()
	if iconSource or iconLoadAttempted then
		return iconSource
	end
	iconLoadAttempted = true
	local ok, result = pcall(function()
		return loadstring(game:HttpGet(ICON_SOURCE_URL))()
	end)
	if ok and type(result) == "table" and type(result.GetAsset) == "function" then
		iconSource = result
	else
		WarnOnce(
			"source",
			"Icon library could not be loaded (" .. tostring(result) .. "). Use Library:SetIconSource(...) in Studio."
		)
	end
	return iconSource
end

-- Validates whatever GetAsset returned and converts it to what ImageLabels need.
local function NormalizeAsset(raw)
	local kind = typeof(raw)
	if kind == "string" then
		return { Image = raw, RectSize = Vector2.zero, RectOffset = Vector2.zero }
	elseif kind == "number" then
		return { Image = "rbxassetid://" .. raw, RectSize = Vector2.zero, RectOffset = Vector2.zero }
	elseif kind ~= "table" then
		return nil
	end

	local image = raw.Url or raw.Image
	if image == nil and type(raw.Id) == "number" then
		image = "rbxassetid://" .. raw.Id
	end
	if type(image) ~= "string" or image == "" then
		return nil
	end
	return {
		Image = image,
		RectSize = typeof(raw.ImageRectSize) == "Vector2" and raw.ImageRectSize or Vector2.zero,
		RectOffset = typeof(raw.ImageRectOffset) == "Vector2" and raw.ImageRectOffset or Vector2.zero,
	}
end

-- Returns a normalized asset or nil. Results (including misses) are cached.
function IconService.Get(name)
	if type(name) == "number" then
		return NormalizeAsset(name)
	end
	if type(name) ~= "string" or name == "" then
		return nil
	end
	if string.find(name, "^rbx") then
		return NormalizeAsset(name) -- caller passed a raw asset string
	end

	local key = ICON_ALIASES[string.lower(name)] or string.lower(name)
	local cached = iconCache[key]
	if cached ~= nil then
		return cached or nil
	end

	local source = LoadIconSource()
	if not source then
		return nil
	end
	local ok, raw = pcall(source.GetAsset, key)
	local asset = ok and NormalizeAsset(raw) or nil
	if not asset then
		WarnOnce(key, ("Icon '%s' was not returned by the icon library."):format(key))
	end
	iconCache[key] = asset or false
	return asset
end

-- Assigns an asset (or a name) to an ImageLabel/ImageButton. Returns true on success.
function IconService.Apply(imageObject, nameOrAsset)
	local asset = type(nameOrAsset) == "table" and nameOrAsset or IconService.Get(nameOrAsset)
	if not asset then
		imageObject.Image = ""
		imageObject.ImageRectSize = Vector2.zero
		imageObject.ImageRectOffset = Vector2.zero
		return false
	end
	imageObject.Image = asset.Image
	imageObject.ImageRectSize = asset.RectSize
	imageObject.ImageRectOffset = asset.RectOffset
	return true
end

-- Creates a centered, consistently sized icon. opts: Size, Color, Name
function IconService.Create(parent, name, opts)
	opts = opts or {}
	local size = opts.Size or ICON_SIZE
	local image = New("ImageLabel", {
		Name = opts.Name or "Icon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		ImageColor3 = opts.Color or Theme.White,
		ScaleType = Enum.ScaleType.Fit,
		Parent = parent,
	})
	if not IconService.Apply(image, name) then
		-- Neutral placeholder (no emoji): a small ring so layout stays intact.
		New("Frame", {
			Name = "Placeholder",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.5, 0.5),
			BackgroundTransparency = 1,
			Parent = image,
		}, { CornerFull(), Stroke(opts.Color or Theme.White, 2, 0.4) })
	end
	return image
end

Library.IconService = IconService

-- Set a custom icon source: a table with GetAsset(name), or nil to reload the default.
function Library:SetIconSource(source)
	if source ~= nil and not (type(source) == "table" and type(source.GetAsset) == "function") then
		error("Library:SetIconSource expects a table with a GetAsset function")
	end
	iconSource = source
	iconLoadAttempted = source ~= nil
	table.clear(iconCache)
	table.clear(iconWarned)
end

---------------------------------------------------------------------
-- Class tables
---------------------------------------------------------------------
local Window = {}
Window.__index = Window
local Tab = {}
Tab.__index = Tab
local Section = {}
Section.__index = Section

---------------------------------------------------------------------
-- Row helpers (used by every element)
---------------------------------------------------------------------
local function ElementMaid(section)
	local maid = Maid.new()
	section._window._maid:Give(function()
		maid:Clean()
	end)
	return maid
end

local function CreateRow(section, height, interactive, maid)
	section._order += 1
	local row = New(interactive and "TextButton" or "Frame", {
		Name = "Row",
		Size = UDim2.new(1, 0, 0, height),
		BackgroundColor3 = Theme.Row,
		BackgroundTransparency = 0,
		LayoutOrder = section._order,
		ClipsDescendants = not interactive,
		Parent = section._body,
	}, {
		Corner(10),
		Stroke(Theme.Border, 1, 0.5),
	})
	maid:Connect(row.MouseEnter, function()
		Tween(row, { BackgroundColor3 = Theme.RowHover }, 0.15)
	end)
	maid:Connect(row.MouseLeave, function()
		Tween(row, { BackgroundColor3 = Theme.Row }, 0.15)
	end)
	return row
end

local function RowLabel(row, text, reserveRight)
	return New("TextLabel", {
		Name = "Label",
		Position = UDim2.fromOffset(16, 0),
		Size = UDim2.new(1, -(16 + reserveRight), 1, 0),
		Text = text,
		TextSize = 14,
		TextColor3 = Theme.Text,
		FontFace = Fonts.Medium,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = row,
	})
end

local function RegisterFlag(section, config, element)
	if config.Flag then
		section._window.Flags[config.Flag] = element
	end
end

local function KeyLabel(keyCode)
	if not keyCode then
		return "None"
	end
	local name = string.gsub(string.gsub(keyCode.Name, "^Left", "L"), "^Right", "R")
	return string.sub(name, 1, 6)
end

---------------------------------------------------------------------
-- Section: Toggle
---------------------------------------------------------------------
function Section:CreateToggle(config)
	config = config or {}
	local maid = ElementMaid(self)
	local state = config.Default == true
	local callback = config.Callback or function() end
	local hasKeybind = config.Keybind ~= false
	-- Keybind: false = hide the box, true/nil = show it unbound, Enum.KeyCode = show it pre-bound.
	-- (Key is kept as an alias for a pre-bound key.)
	local boundKey = typeof(config.Keybind) == "EnumItem" and config.Keybind or config.Key
	local listening = false

	local row = CreateRow(self, Layout.RowHeight, true, maid)
	row.Name = "Toggle_" .. tostring(config.Name or "")
	RowLabel(row, config.Name or "Toggle", hasKeybind and 150 or 80)

	local trackStroke = Stroke(Theme.Border, 1, 0.3)
	local track = New("Frame", {
		Name = "Track",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.5, 0),
		Size = UDim2.fromOffset(50, 28),
		BackgroundColor3 = Theme.ToggleTrack,
		BackgroundTransparency = 0,
		Parent = row,
	}, { CornerFull(), trackStroke })

	local knob = New("Frame", {
		Name = "Knob",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 4, 0.5, 0),
		Size = UDim2.fromOffset(20, 20),
		BackgroundColor3 = Theme.ToggleKnobOff,
		BackgroundTransparency = 0,
		Parent = track,
	}, { CornerFull() })

	local toggle = { Name = config.Name, Type = "Toggle", Value = state, Instance = row }

	local function render(animate)
		Apply(track, { BackgroundColor3 = state and Theme.Accent or Theme.ToggleTrack }, animate, 0.2)
		Apply(trackStroke, { Color = state and Theme.AccentHover or Theme.Border }, animate, 0.2)
		Apply(knob, { BackgroundColor3 = state and Theme.White or Theme.ToggleKnobOff }, animate, 0.2)
		Apply(knob, { Position = UDim2.new(0, state and 26 or 4, 0.5, 0) }, animate, 0.25, Enum.EasingStyle.Back)
	end
	render(false)

	function toggle:Set(value, silent)
		value = value == true
		if value == state then
			return
		end
		state = value
		self.Value = value
		render(true)
		if not silent then
			task.spawn(callback, state)
		end
	end

	function toggle:Get()
		return state
	end

	maid:Connect(row.Activated, function()
		toggle:Set(not state)
	end)

	if hasKeybind then
		local keyButton = New("TextButton", {
			Name = "Keybind",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -(16 + 50 + 10), 0.5, 0),
			Size = UDim2.fromOffset(56, 28),
			BackgroundColor3 = Theme.Field,
			BackgroundTransparency = 0,
			Text = KeyLabel(boundKey),
			TextSize = 11,
			TextColor3 = Theme.TextMuted,
			FontFace = Fonts.Medium,
			Parent = row,
		}, { Corner(6), Stroke(Theme.Border, 1, 0.4) })

		maid:Connect(keyButton.MouseEnter, function()
			Tween(keyButton, { TextColor3 = Theme.TextDim }, 0.12)
		end)
		maid:Connect(keyButton.MouseLeave, function()
			if not listening then
				Tween(keyButton, { TextColor3 = Theme.TextMuted }, 0.12)
			end
		end)

		function toggle:SetKeybind(keyCode)
			boundKey = keyCode
			listening = false
			keyButton.Text = KeyLabel(boundKey)
			Tween(keyButton, { TextColor3 = Theme.TextMuted }, 0.12)
		end

		function toggle:GetKeybind()
			return boundKey
		end

		maid:Connect(keyButton.Activated, function()
			listening = true
			keyButton.Text = "..."
			Tween(keyButton, { TextColor3 = Theme.Accent }, 0.12)
		end)

		maid:Connect(UserInputService.InputBegan, function(input, processed)
			if listening then
				if input.UserInputType == Enum.UserInputType.Keyboard then
					if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.Backspace then
						toggle:SetKeybind(nil)
					else
						toggle:SetKeybind(input.KeyCode)
					end
				end
				return
			end
			if not processed and boundKey and input.KeyCode == boundKey then
				toggle:Set(not state)
			end
		end)
	end

	function toggle:Destroy()
		maid:Clean()
		row:Destroy()
	end

	RegisterFlag(self, config, toggle)
	return toggle
end

---------------------------------------------------------------------
-- Section: Dropdown
---------------------------------------------------------------------
function Section:CreateDropdown(config)
	config = config or {}
	local maid = ElementMaid(self)
	local callback = config.Callback or function() end
	local options = table.clone(config.Options or {})
	local selected = config.Default
	if selected == nil or not table.find(options, selected) then
		selected = options[1]
	end
	local isOpen = false
	local optionButtons = {}

	local closedHeight = Layout.DropdownClosedHeight
	local row = CreateRow(self, closedHeight, false, maid)
	row.Name = "Dropdown_" .. tostring(config.Name or "")

	New("TextLabel", {
		Name = "Label",
		Position = UDim2.fromOffset(16, 12),
		Size = UDim2.new(1, -32, 0, 16),
		Text = config.Name or "Dropdown",
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = row,
	})

	local fieldStroke = Stroke(Theme.Border, 1, 0.4)
	local field = New("TextButton", {
		Name = "Field",
		Position = UDim2.fromOffset(16, 38),
		Size = UDim2.new(1, -32, 0, 32),
		BackgroundColor3 = Theme.Field,
		BackgroundTransparency = 0,
		Parent = row,
	}, { Corner(6), fieldStroke })

	local valueLabel = New("TextLabel", {
		Name = "Value",
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -36, 1, 0),
		Text = selected ~= nil and tostring(selected) or "",
		TextSize = 13,
		TextColor3 = Theme.TextDim,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = field,
	})

	local chevronSlot = New("Frame", {
		Name = "ChevronSlot",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(20, 20),
		BackgroundTransparency = 1,
		Parent = field,
	})
	local chevron = IconService.Create(chevronSlot, "chevron-down", {
		Name = "Chevron",
		Size = 16,
		Color = Theme.TextMuted,
	})

	local menu = New("ScrollingFrame", {
		Name = "Menu",
		Position = UDim2.fromOffset(16, 76),
		Size = UDim2.new(1, -32, 0, 0),
		BackgroundColor3 = Theme.Field,
		BackgroundTransparency = 0,
		Visible = false,
		ScrollBarThickness = 2,
		ScrollBarImageColor3 = Theme.TextMuted,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = row,
	}, { Corner(6), Stroke(Theme.Border, 1, 0.4), Padding(4, 4, 4, 4), List(2) })

	local dropdown = { Name = config.Name, Type = "Dropdown", Value = selected, Instance = row }

	local function menuHeight()
		local count = math.min(#options, Layout.MaxVisibleOptions)
		if count == 0 then
			return 8
		end
		return count * Layout.OptionHeight + (count - 1) * 2 + 8
	end

	local function openHeight()
		return 76 + menuHeight() + 12
	end

	local function styleOptions(animate)
		for _, entry in optionButtons do
			local isSelected = entry.value == selected
			Apply(entry.button, {
				BackgroundColor3 = isSelected and Theme.Accent or Theme.Row,
				BackgroundTransparency = isSelected and 0.85 or 1,
				TextColor3 = isSelected and Theme.White or Theme.TextDim,
			}, animate, 0.15)
			entry.bar.Visible = isSelected
		end
	end

	local function setOpen(open)
		if open == isOpen then
			return
		end
		isOpen = open
		if open then
			menu.Size = UDim2.new(1, -32, 0, menuHeight())
			menu.Visible = true
			Tween(row, { Size = UDim2.new(1, 0, 0, openHeight()) }, 0.25, Enum.EasingStyle.Quint)
			Tween(chevron, { Rotation = 180, ImageColor3 = Theme.Accent }, 0.2)
			Tween(fieldStroke, { Color = Theme.Accent }, 0.2)
		else
			Tween(row, { Size = UDim2.new(1, 0, 0, closedHeight) }, 0.2, Enum.EasingStyle.Quint)
			Tween(chevron, { Rotation = 0, ImageColor3 = Theme.TextMuted }, 0.2)
			Tween(fieldStroke, { Color = Theme.Border }, 0.2)
			task.delay(0.22, function()
				if not isOpen and menu.Parent then
					menu.Visible = false
				end
			end)
		end
	end

	local optionMaid = Maid.new()
	maid:Give(function()
		optionMaid:Clean()
	end)

	local function buildOptions()
		optionMaid:Clean()
		for _, entry in optionButtons do
			entry.button:Destroy()
		end
		table.clear(optionButtons)

		for index, value in options do
			local button = New("TextButton", {
				Name = "Option_" .. tostring(value),
				Size = UDim2.new(1, 0, 0, Layout.OptionHeight),
				BackgroundColor3 = Theme.Row,
				BackgroundTransparency = 1,
				Text = tostring(value),
				TextSize = 13,
				TextColor3 = Theme.TextDim,
				LayoutOrder = index,
				Parent = menu,
			}, { Corner(5), Padding(12, 0, 8, 0) })
			button.TextXAlignment = Enum.TextXAlignment.Left

			local bar = New("Frame", {
				Name = "SelectedBar",
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, -8, 0.5, 0),
				Size = UDim2.fromOffset(3, 14),
				BackgroundColor3 = Theme.Accent,
				BackgroundTransparency = 0,
				Visible = false,
				Parent = button,
			}, { CornerFull() })

			optionMaid:Connect(button.MouseEnter, function()
				if value ~= selected then
					Tween(button, { BackgroundTransparency = 0 }, 0.12)
				end
			end)
			optionMaid:Connect(button.MouseLeave, function()
				if value ~= selected then
					Tween(button, { BackgroundTransparency = 1 }, 0.12)
				end
			end)
			optionMaid:Connect(button.Activated, function()
				dropdown:Set(value)
				setOpen(false)
			end)

			table.insert(optionButtons, { value = value, button = button, bar = bar })
		end
		styleOptions(false)
	end
	buildOptions()

	function dropdown:Set(value, silent)
		if not table.find(options, value) then
			warn(("[Library] Dropdown '%s' has no option '%s'"):format(tostring(config.Name), tostring(value)))
			return
		end
		local changed = value ~= selected
		selected = value
		self.Value = value
		valueLabel.Text = tostring(value)
		styleOptions(true)
		if changed and not silent then
			task.spawn(callback, value)
		end
	end

	function dropdown:Get()
		return selected
	end

	function dropdown:SetOptions(newOptions, keepSelection)
		options = table.clone(newOptions or {})
		if not (keepSelection and table.find(options, selected)) then
			selected = options[1]
			self.Value = selected
			valueLabel.Text = selected ~= nil and tostring(selected) or ""
		end
		buildOptions()
		if isOpen then
			menu.Size = UDim2.new(1, -32, 0, menuHeight())
			Tween(row, { Size = UDim2.new(1, 0, 0, openHeight()) }, 0.2, Enum.EasingStyle.Quint)
		end
	end

	function dropdown:Open()
		setOpen(true)
	end

	function dropdown:Close()
		setOpen(false)
	end

	function dropdown:Destroy()
		maid:Clean()
		row:Destroy()
	end

	maid:Connect(field.MouseEnter, function()
		if not isOpen then
			Tween(fieldStroke, { Color = Theme.TextMuted }, 0.12)
		end
	end)
	maid:Connect(field.MouseLeave, function()
		if not isOpen then
			Tween(fieldStroke, { Color = Theme.Border }, 0.12)
		end
	end)
	maid:Connect(field.Activated, function()
		setOpen(not isOpen)
	end)

	RegisterFlag(self, config, dropdown)
	return dropdown
end

---------------------------------------------------------------------
-- Section: Button
---------------------------------------------------------------------
function Section:CreateButton(config)
	config = config or {}
	local maid = ElementMaid(self)
	local callback = config.Callback or function() end

	local row = CreateRow(self, Layout.RowHeight, false, maid)
	row.Name = "Button_" .. tostring(config.Name or "")
	RowLabel(row, config.Name or "Button", 118)

	local wrapper = New("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.5, 0),
		Size = UDim2.fromOffset(92, 30),
		BackgroundTransparency = 1,
		Parent = row,
	})
	local button = New("TextButton", {
		Name = "Button",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Accent,
		BackgroundTransparency = 0,
		Text = config.ButtonText or "Run",
		TextSize = 12,
		FontFace = Fonts.Bold,
		TextColor3 = Theme.White,
		Parent = wrapper,
	}, { Corner(8) })

	maid:Connect(button.MouseEnter, function()
		Tween(button, { BackgroundColor3 = Theme.AccentHover }, 0.12)
	end)
	maid:Connect(button.MouseLeave, function()
		Tween(button, { BackgroundColor3 = Theme.Accent }, 0.12)
	end)
	AddPress(button, maid, button, 0.94)
	maid:Connect(button.Activated, function()
		task.spawn(callback)
	end)

	local element = { Name = config.Name, Type = "Button", Instance = row }
	function element:SetText(text)
		button.Text = text
	end
	function element:Destroy()
		maid:Clean()
		row:Destroy()
	end
	return element
end

---------------------------------------------------------------------
-- Section: Textbox
---------------------------------------------------------------------
function Section:CreateTextbox(config)
	config = config or {}
	local maid = ElementMaid(self)
	local callback = config.Callback or function() end

	local row = CreateRow(self, Layout.RowHeight, false, maid)
	row.Name = "Textbox_" .. tostring(config.Name or "")
	RowLabel(row, config.Name or "Textbox", 176)

	local boxStroke = Stroke(Theme.Border, 1, 0.4)
	local box = New("TextBox", {
		Name = "Input",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.5, 0),
		Size = UDim2.fromOffset(150, 30),
		BackgroundColor3 = Theme.Field,
		BackgroundTransparency = 0,
		Text = config.Default or "",
		PlaceholderText = config.Placeholder or "Type here...",
		PlaceholderColor3 = Theme.TextMuted,
		TextColor3 = Theme.Text,
		TextSize = 13,
		ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = row,
	}, { Corner(6), boxStroke, Padding(10, 0, 10, 0) })

	maid:Connect(box.Focused, function()
		Tween(boxStroke, { Color = Theme.Accent }, 0.15)
	end)
	maid:Connect(box.FocusLost, function(enterPressed)
		Tween(boxStroke, { Color = Theme.Border }, 0.15)
		task.spawn(callback, box.Text, enterPressed)
	end)

	local element = { Name = config.Name, Type = "Textbox", Instance = row }
	function element:Get()
		return box.Text
	end
	function element:Set(text)
		box.Text = tostring(text)
	end
	function element:Destroy()
		maid:Clean()
		row:Destroy()
	end
	RegisterFlag(self, config, element)
	return element
end

---------------------------------------------------------------------
-- Section: Label / Divider
---------------------------------------------------------------------
function Section:CreateLabel(text)
	local maid = ElementMaid(self)
	self._order += 1
	local label = New("TextLabel", {
		Name = "Label",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = tostring(text or ""),
		TextSize = 12,
		TextColor3 = Theme.TextMuted,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = self._order,
		Parent = self._body,
	}, { Padding(4, 2, 4, 2) })

	local element = { Type = "Label", Instance = label }
	function element:SetText(newText)
		label.Text = tostring(newText)
	end
	function element:Destroy()
		maid:Clean()
		label:Destroy()
	end
	return element
end

function Section:CreateDivider(text)
	local maid = ElementMaid(self)
	self._order += 1
	local holder
	if text and text ~= "" then
		holder = New("TextLabel", {
			Name = "Divider",
			Size = UDim2.new(1, 0, 0, 30),
			Text = string.upper(text),
			TextSize = 12,
			FontFace = Fonts.Bold,
			TextColor3 = Theme.Accent,
			LayoutOrder = self._order,
			Parent = self._body,
		})
	else
		holder = New("Frame", {
			Name = "Divider",
			Size = UDim2.new(1, 0, 0, 9),
			BackgroundTransparency = 1,
			LayoutOrder = self._order,
			Parent = self._body,
		}, {
			New("Frame", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.fromScale(0, 0.5),
				Size = UDim2.new(1, 0, 0, 1),
				BackgroundColor3 = Theme.Border,
				BackgroundTransparency = 0,
			}),
		})
	end
	local element = { Type = "Divider", Instance = holder }
	function element:Destroy()
		maid:Clean()
		holder:Destroy()
	end
	return element
end

-- Short aliases: Section:Toggle(name, default, callback), Section:Dropdown(name, options, callback)
function Section:Toggle(name, default, callback)
	return self:CreateToggle({ Name = name, Default = default, Callback = callback })
end

function Section:Dropdown(name, options, callback)
	return self:CreateDropdown({ Name = name, Options = options, Callback = callback })
end

function Section:Button(name, callback)
	return self:CreateButton({ Name = name, Callback = callback })
end

function Section:Textbox(name, callback)
	return self:CreateTextbox({ Name = name, Callback = callback })
end

---------------------------------------------------------------------
-- Tab
---------------------------------------------------------------------
function Tab:CreateSection(config, side)
	if type(config) == "string" then
		config = { Name = config, Side = side }
	end
	config = config or {}
	local name = config.Name or "Section"
	local isRight = string.lower(tostring(config.Side or "Left")) == "right"

	local column, order
	if isRight then
		self._rightOrder += 1
		column, order = self._right, self._rightOrder
	else
		self._leftOrder += 1
		column, order = self._left, self._leftOrder
	end

	local card = New("Frame", {
		Name = "Section_" .. name,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Panel,
		BackgroundTransparency = 0,
		LayoutOrder = order,
		Parent = column,
	}, {
		Corner(16),
		Stroke(Theme.Border, 1, 0.45),
		Padding(18, 14, 18, 18),
		List(0),
	})

	New("TextLabel", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 44),
		Text = string.upper(name),
		TextSize = 14,
		FontFace = Fonts.Bold,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 0,
		Parent = card,
	}, { Padding(3, 0, 0, 0) })

	local body = New("Frame", {
		Name = "Body",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Parent = card,
	}, { List(Layout.RowGap) })

	local section = setmetatable({
		Name = name,
		Tab = self,
		Instance = card,
		_window = self.Window,
		_body = body,
		_order = 0,
	}, Section)
	return section
end

function Tab:_SetSelected(selected, instant)
	local page = self._page
	if selected then
		Apply(self._icon, { ImageColor3 = Theme.White }, not instant, 0.2)
		Apply(self._button, { BackgroundTransparency = 1 }, false)
		page.Visible = true
		if instant then
			page.Position = UDim2.fromOffset(0, 0)
		else
			page.Position = UDim2.fromOffset(0, 12)
			Tween(page, { Position = UDim2.fromOffset(0, 0) }, 0.28, Enum.EasingStyle.Quint)
			self.Window:_FadePage()
		end
	else
		Apply(self._icon, { ImageColor3 = Theme.TextDim }, true, 0.2)
		page.Visible = false
	end
end

---------------------------------------------------------------------
-- Window
---------------------------------------------------------------------
function Window:CreateTab(config)
	if type(config) == "string" then
		config = { Name = config }
	end
	config = config or {}

	local tab = setmetatable({
		Name = config.Name or "Tab",
		Icon = config.Icon,
		Window = self,
		_leftOrder = 0,
		_rightOrder = 0,
	}, Tab)

	-- Sidebar slot -----------------------------------------------------
	local size, gap = Layout.TabSize, Layout.TabGap
	local slot
	if config.Bottom == true then
		self._bottomCount += 1
		local k = self._bottomCount
		slot = UDim2.new(0.5, -size / 2, 1, -(Layout.TabBottom + k * size + (k - 1) * gap))
	else
		self._topCount += 1
		slot = UDim2.new(0.5, -size / 2, 0, Layout.TabTop + (self._topCount - 1) * (size + gap))
	end
	tab._slot = slot

	local maid = self._maid
	local button = New("TextButton", {
		Name = "Tab_" .. tab.Name,
		Position = slot,
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = Theme.Row,
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = self._sidebar,
	}, { Corner(16) })
	tab._button = button

	local icon = IconService.Create(button, config.Icon or tab.Name, { Name = "Icon", Color = Theme.TextDim })
	tab._icon = icon
	AddPress(button, maid, icon, 0.86)

	maid:Connect(button.MouseEnter, function()
		if self.ActiveTab ~= tab then
			Tween(button, { BackgroundTransparency = 0 }, 0.15)
		end
	end)
	maid:Connect(button.MouseLeave, function()
		Tween(button, { BackgroundTransparency = 1 }, 0.15)
	end)
	maid:Connect(button.Activated, function()
		self:SelectTab(tab)
	end)

	-- Page with two scrolling columns ---------------------------------
	local page = New("Frame", {
		Name = "Page_" .. tab.Name,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = self._content,
	}, { Padding(16, 16, 16, 16) })
	tab._page = page

	local function makeColumn(name, position)
		return New("ScrollingFrame", {
			Name = name,
			Position = position,
			Size = UDim2.new(0.5, -8, 1, 0),
			BackgroundTransparency = 1,
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = Theme.TextMuted,
			ScrollBarImageTransparency = 0.4,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			Parent = page,
		}, { List(12), Padding(0, 0, 6, 0) })
	end
	tab._left = makeColumn("Left", UDim2.fromOffset(0, 0))
	tab._right = makeColumn("Right", UDim2.new(0.5, 8, 0, 0))

	table.insert(self.Tabs, tab)
	if not self.ActiveTab then
		self:SelectTab(tab)
	end
	return tab
end

function Window:SelectTab(tab)
	if type(tab) == "string" then
		for _, candidate in self.Tabs do
			if candidate.Name == tab then
				tab = candidate
				break
			end
		end
	end
	if type(tab) ~= "table" or self.ActiveTab == tab then
		return
	end

	local previous = self.ActiveTab
	self.ActiveTab = tab
	if previous then
		previous:_SetSelected(false)
	end
	tab:_SetSelected(true, previous == nil)

	local indicator = self._indicator
	if previous == nil then
		indicator.Position = tab._slot
		indicator.Visible = true
	else
		Tween(indicator, { Position = tab._slot }, 0.3, Enum.EasingStyle.Quint)
	end
end

-- Swaps the watermark between "eye" (UI visible) and "eye-off" (UI hidden)
-- with a short fade; the ScreenGui itself is never touched.
function Window:_UpdateWatermark(visible, instant)
	local icon = self._watermarkIcon
	if not icon then
		return
	end
	self._watermarkToken += 1
	local token = self._watermarkToken
	local targetColor = visible and Theme.White or Theme.TextMuted
	local iconName = visible and "eye" or "eye-off"

	if instant then
		IconService.Apply(icon, iconName)
		icon.ImageColor3 = targetColor
		return
	end

	Tween(icon, { ImageTransparency = 1 }, 0.1)
	task.delay(0.1, function()
		if self._destroyed or token ~= self._watermarkToken then
			return
		end
		IconService.Apply(icon, iconName)
		icon.ImageColor3 = targetColor
		Tween(icon, { ImageTransparency = 0 }, 0.14)
	end)
end

-- Fades the whole window using a background-coloured cover instead of a
-- CanvasGroup. CanvasGroups render to an offscreen texture, which looks
-- blurry on high-DPI phones (especially under UIScale).
function Window:_Fade(show, duration)
	local cover = self._cover
	self._fadeToken += 1
	local token = self._fadeToken
	cover.Visible = true
	Tween(cover, { BackgroundTransparency = show and 1 or 0 }, duration)
	if show then
		task.delay(duration, function()
			if token == self._fadeToken and cover.Parent then
				cover.Visible = false
			end
		end)
	end
end

-- Quick fade-in of the page area after a tab switch.
function Window:_FadePage()
	local cover = self._pageCover
	self._pageToken += 1
	local token = self._pageToken
	cover.BackgroundTransparency = 0.5
	cover.Visible = true
	Tween(cover, { BackgroundTransparency = 1 }, 0.25)
	task.delay(0.26, function()
		if token == self._pageToken and cover.Parent then
			cover.Visible = false
		end
	end)
end

function Window:SetKeybind(keyCode)
	self._toggleKey = keyCode or nil
end

function Window:SetVisible(visible)
	if self._destroyed or visible == self.Visible then
		return
	end
	self.Visible = visible
	self:_UpdateWatermark(visible, false)

	local holder = self._holder
	local home = UDim2.fromScale(holder.Position.X.Scale, holder.Position.Y.Scale)
	if visible then
		holder.Visible = true
		holder.Position = home + UDim2.fromOffset(0, 10)
		Tween(holder, { Position = home }, 0.3, Enum.EasingStyle.Quint)
		self:_Fade(true, 0.25)
		Tween(self._shadow, { BackgroundTransparency = 0.72 }, 0.25)
	else
		self:_Fade(false, 0.2)
		Tween(self._shadow, { BackgroundTransparency = 1 }, 0.2)
		task.delay(0.22, function()
			if not self.Visible and not self._destroyed then
				holder.Visible = false
			end
		end)
	end
end

function Window:Toggle()
	self:SetVisible(not self.Visible)
end

local NotifyColors = {
	Info = Theme.Accent,
	Success = Theme.Success,
	Warning = Theme.Warning,
	Error = Theme.Accent,
}

function Window:Notify(config)
	if self._destroyed then
		return
	end
	if type(config) == "string" then
		config = { Content = config }
	end
	config = config or {}
	local duration = config.Duration or 4
	local color = NotifyColors[config.Type or "Info"] or Theme.Accent

	self._notifyOrder += 1
	local wrapper = New("Frame", {
		Name = "Notification",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = self._notifyOrder,
		Parent = self._notifyHolder,
	})

	local content = New("Frame", {
		Name = "Content",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, { Padding(18, 12, 14, 14), List(3) })

	New("TextLabel", {
		Name = "Title",
		Size = UDim2.new(1, 0, 0, 16),
		Text = config.Title or self.Title,
		TextSize = 13,
		FontFace = Fonts.Bold,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		LayoutOrder = 1,
		Parent = content,
	})
	New("TextLabel", {
		Name = "Body",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = tostring(config.Content or ""),
		TextSize = 12,
		TextColor3 = Theme.TextDim,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		LayoutOrder = 2,
		Parent = content,
	})

	local progress = New("Frame", {
		Name = "Progress",
		Position = UDim2.new(0, 0, 1, -2),
		Size = UDim2.new(1, 0, 0, 2),
		BackgroundColor3 = color,
		BackgroundTransparency = 0,
	})

	local toast = New("Frame", {
		Name = "Toast",
		Position = UDim2.fromOffset(330, 0),
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Panel,
		BackgroundTransparency = 0,
		ClipsDescendants = true,
		Parent = wrapper,
	}, {
		Corner(12),
		Stroke(Theme.Border, 1, 0.1),
		content,
		New("Frame", {
			Name = "Accent",
			Size = UDim2.new(0, 3, 1, 0),
			BackgroundColor3 = color,
			BackgroundTransparency = 0,
		}),
		progress,
	})

	Tween(toast, { Position = UDim2.fromOffset(0, 0) }, 0.35, Enum.EasingStyle.Quint)
	Tween(progress, { Size = UDim2.new(0, 0, 0, 2) }, duration, Enum.EasingStyle.Linear)

	task.delay(duration, function()
		if self._destroyed or not toast.Parent then
			return
		end
		Tween(toast, { Position = UDim2.fromOffset(330, 0) }, 0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		task.delay(0.32, function()
			if wrapper.Parent then
				wrapper:Destroy()
			end
		end)
	end)
end

function Window:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	self._maid:Clean()

	local index = table.find(Library._windows, self)
	if index then
		table.remove(Library._windows, index)
	end

	if self.OnClose then
		task.spawn(self.OnClose)
	end

	local gui = self.Gui
	self:_Fade(false, 0.2)
	Tween(self._shadow, { BackgroundTransparency = 1 }, 0.2)
	task.delay(0.25, function()
		gui:Destroy()
	end)
end

---------------------------------------------------------------------
-- Library
---------------------------------------------------------------------
function Library:CreateWindow(config)
	config = config or {}
	local self = setmetatable({}, Window)
	local maid = Maid.new()

	self._maid = maid
	self._topCount = 0
	self._bottomCount = 0
	self._notifyOrder = 0
	self._destroyed = false
	self._watermarkToken = 0
	self._fadeToken = 0
	self._pageToken = 0
	self.Title = config.Title or "Control Panel"
	self.Subtitle = config.Subtitle or ""
	self.OnClose = config.OnClose
	self.Flags = {}
	self.Tabs = {}
	self.ActiveTab = nil
	self.Visible = true

	local size = config.Size or UDim2.fromOffset(950, 620)
	local width = size.X.Offset > 0 and size.X.Offset or 950
	local height = size.Y.Offset > 0 and size.Y.Offset or 620

	-- ScreenGui -------------------------------------------------------
	local parent = ResolveParent(config.Parent)
	local guiName = config.Name or "LuauControlPanel"
	local existing = parent:FindFirstChild(guiName)
	if existing then
		existing:Destroy()
	end

	local gui = New("ScreenGui", {
		Name = guiName,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ScreenInsets = Enum.ScreenInsets.None,
		DisplayOrder = config.DisplayOrder or 100,
		Parent = parent,
	})
	self.Gui = gui

	local root = New("Frame", {
		Name = "Root",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = gui,
	})

	local holder = New("Frame", {
		Name = "Holder",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 14),
		Size = UDim2.fromOffset(width, height),
		BackgroundTransparency = 1,
		Parent = root,
	})
	self._holder = holder

	local uiScale = New("UIScale", { Parent = holder })
	local function updateScale()
		local viewport = root.AbsoluteSize
		if viewport.X <= 0 or viewport.Y <= 0 then
			return
		end
		uiScale.Scale = math.max(0.25, math.min(1, (viewport.X - 24) / width, (viewport.Y - 24) / height))
	end
	updateScale()
	maid:Connect(root:GetPropertyChangedSignal("AbsoluteSize"), updateScale)

	local shadow = New("Frame", {
		Name = "Shadow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 8),
		Size = UDim2.new(1, 24, 1, 24),
		BackgroundColor3 = Theme.Black,
		BackgroundTransparency = 1,
		ZIndex = 0,
		Parent = holder,
	}, { Corner(30) })
	self._shadow = shadow

	local main = New("Frame", {
		Name = "Main",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Background,
		BackgroundTransparency = 0,
		Parent = holder,
	}, { Corner(22), Stroke(Theme.Border, 1, 0.15) })
	self._main = main

	-- Fade cover (opaque until the intro fade starts)
	self._cover = New("Frame", {
		Name = "FadeCover",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Background,
		BackgroundTransparency = 0,
		ZIndex = 30,
		Parent = main,
	}, { Corner(22) })

	-- Sidebar ----------------------------------------------------------
	local sidebar = New("Frame", {
		Name = "Sidebar",
		Size = UDim2.new(0, Layout.SidebarWidth, 1, 0),
		BackgroundTransparency = 1,
		Parent = main,
	})
	self._sidebar = sidebar

	local logoText = config.Logo or string.upper(string.sub(self.Title, 1, 3))
	New("TextLabel", {
		Name = "Logo",
		Position = UDim2.fromOffset(0, 36),
		Size = UDim2.new(1, 0, 0, 22),
		Text = logoText,
		TextSize = 16,
		FontFace = Fonts.Bold,
		TextColor3 = Theme.Accent,
		Parent = sidebar,
	})

	New("Frame", {
		Name = "Divider",
		Position = UDim2.new(1, -1, 0, 16),
		Size = UDim2.new(0, 1, 1, -32),
		BackgroundColor3 = Theme.Border,
		BackgroundTransparency = 0.2,
		Parent = sidebar,
	})

	self._indicator = New("Frame", {
		Name = "Indicator",
		Size = UDim2.fromOffset(Layout.TabSize, Layout.TabSize),
		BackgroundColor3 = Theme.Accent,
		BackgroundTransparency = 0,
		Visible = false,
		ZIndex = 1,
		Parent = sidebar,
	}, { Corner(16), Stroke(Theme.AccentHover, 1, 0.55) })

	-- Content area -----------------------------------------------------
	self._content = New("Frame", {
		Name = "Content",
		Position = UDim2.fromOffset(Layout.SidebarWidth, 0),
		Size = UDim2.new(1, -Layout.SidebarWidth, 1, 0),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = main,
	})
	self._pageCover = New("Frame", {
		Name = "PageCover",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Background,
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 10,
		Parent = self._content,
	})

	-- Drag handle (top strip) + sidebar dragging ----------------------
	local dragStrip = New("Frame", {
		Name = "DragStrip",
		Size = UDim2.new(1, 0, 0, 14),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = main,
	})
	MakeDraggable(dragStrip, holder, root, maid)
	MakeDraggable(sidebar, holder, root, maid)

	-- Watermark toggle (always visible, draggable, independent of the window) --
	local logoLabelText = logoText
	local watermarkStroke = Stroke(Theme.Border, 1, 0.1)
	local watermark = New("TextButton", {
		Name = "Watermark",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.035),
		Size = UDim2.fromOffset(0, 34),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Theme.Panel,
		BackgroundTransparency = 1,
		ZIndex = 50,
		Parent = root,
	}, {
		CornerFull(),
		watermarkStroke,
		Padding(12, 0, 14, 0),
		New("UIListLayout", {
			Padding = UDim.new(0, 8),
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	})
	watermarkStroke.Transparency = 1

	local iconSlot = New("Frame", {
		Name = "IconSlot",
		Size = UDim2.fromOffset(18, 18),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		ZIndex = 50,
		Parent = watermark,
	})
	self._watermarkIcon = IconService.Create(iconSlot, "eye", { Name = "Eye", Size = 18, Color = Theme.White })
	self._watermarkIcon.ZIndex = 50

	New("TextLabel", {
		Name = "Text",
		Size = UDim2.fromOffset(0, 34),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = logoLabelText,
		TextSize = 12,
		FontFace = Fonts.Bold,
		TextColor3 = Theme.Accent,
		LayoutOrder = 2,
		ZIndex = 50,
		Parent = watermark,
	})
	self._watermark = watermark

	-- fade in with the window
	Tween(watermark, { BackgroundTransparency = 0.05 }, 0.3)
	Tween(watermarkStroke, { Transparency = 0.1 }, 0.3)

	maid:Connect(watermark.MouseEnter, function()
		Tween(watermark, { BackgroundColor3 = Theme.RowHover }, 0.15)
		Tween(watermarkStroke, { Color = Theme.Accent }, 0.15)
	end)
	maid:Connect(watermark.MouseLeave, function()
		Tween(watermark, { BackgroundColor3 = Theme.Panel }, 0.15)
		Tween(watermarkStroke, { Color = Theme.Border }, 0.15)
	end)
	AddPress(watermark, maid, watermark, 0.95)

	local dragState = { moved = false }
	MakeDraggable(watermark, watermark, root, maid, dragState)
	maid:Connect(watermark.Activated, function()
		if dragState.moved then
			return -- this release ended a drag, not a click
		end
		self:Toggle()
	end)

	-- Notifications ----------------------------------------------------
	self._notifyHolder = New("Frame", {
		Name = "Notifications",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.new(0, 300, 1, -32),
		BackgroundTransparency = 1,
		Parent = root,
	}, {
		New("UIListLayout", {
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
		}),
	})

	-- Toggle keybind (config.Keybind; false disables; ToggleKey kept as an alias) --
	local keybind = config.Keybind
	if keybind == nil then
		keybind = config.ToggleKey
	end
	if keybind == nil then
		keybind = Enum.KeyCode.RightShift
	end
	self._toggleKey = keybind ~= false and keybind or nil
	maid:Connect(UserInputService.InputBegan, function(input, processed)
		if not processed and self._toggleKey and input.KeyCode == self._toggleKey then
			self:Toggle()
		end
	end)

	-- Fade-in ----------------------------------------------------------
	self:_Fade(true, 0.3)
	Tween(shadow, { BackgroundTransparency = 0.72 }, 0.3)
	Tween(holder, { Position = UDim2.fromScale(0.5, 0.5) }, 0.4, Enum.EasingStyle.Quint)

	table.insert(Library._windows, self)
	return self
end

function Library:Notify(config)
	local window = Library._windows[#Library._windows]
	if window then
		window:Notify(config)
	end
end

function Library:Destroy()
	for _, window in table.clone(Library._windows) do
		window:Destroy()
	end
end

return Library
