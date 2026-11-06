--!strict
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Theme = {
	Background = Color3.fromRGB(13, 13, 13),
	Row = Color3.fromRGB(17, 17, 17),
	Stroke = Color3.fromRGB(42, 42, 42),
	Text = Color3.fromRGB(232, 232, 232),
	SubText = Color3.fromRGB(140, 140, 140),
	Accent = Color3.fromRGB(46, 94, 66),
	AccentBright = Color3.fromRGB(76, 140, 102),
	Track = Color3.fromRGB(38, 38, 38),
}

local FontFamily = "rbxasset://fonts/families/GothamSSm.json"
local Fonts = {
	Bold = Font.new(FontFamily, Enum.FontWeight.Bold),
	Regular = Font.new(FontFamily, Enum.FontWeight.Medium),
}

local WIDGET_WIDTH = 96
local WIDGET_HEIGHT = 36

export type WindowConfig = {
	Name: string?,
	Title: string,
	Subtitle: string?,
	Parent: Instance?,
	Keybind: Enum.KeyCode?,
	Visible: boolean?,
	OnClose: (() -> ())?,
}

export type ToggleConfig = {
	Title: string,
	Description: string?,
	Default: boolean?,
	OnText: string?,
	OffText: string?,
	Callback: ((boolean) -> ())?,
}

export type ButtonConfig = {
	Title: string,
	Description: string?,
	ButtonText: string?,
	Callback: (() -> ())?,
}

export type SliderConfig = {
	Title: string,
	Description: string?,
	Min: number,
	Max: number,
	Default: number?,
	Step: number?,
	Suffix: string?,
	Callback: ((number) -> ())?,
}

export type LabelConfig = {
	Title: string,
	Description: string?,
}

export type Element = {
	Set: (self: Element, value: any) -> (),
	Get: (self: Element) -> any,
	SetTitle: (self: Element, text: string) -> (),
	SetDescription: (self: Element, text: string) -> (),
	Destroy: (self: Element) -> (),
}

type RowParts = {
	Row: Frame,
	Top: Frame,
	Title: TextLabel,
	Description: TextLabel,
}

type WindowData = {
	Gui: ScreenGui,
	Main: Frame,
	Content: ScrollingFrame,
	Connections: { RBXScriptConnection },
	Order: number,
	OnClose: (() -> ())?,
}

local UILibrary = {}
UILibrary.__index = UILibrary

export type Window = typeof(setmetatable({} :: WindowData, UILibrary))

local function create(className: string, props: { [string]: any }, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in props do
		(instance :: any)[key] = value
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

local function addStroke(parent: Instance, color: Color3?): UIStroke
	return create("UIStroke", {
		Color = color or Theme.Stroke,
		Thickness = 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
end

local function addPadding(parent: Instance, top: number, right: number, bottom: number, left: number)
	create("UIPadding", {
		PaddingTop = UDim.new(0, top),
		PaddingRight = UDim.new(0, right),
		PaddingBottom = UDim.new(0, bottom),
		PaddingLeft = UDim.new(0, left),
	}, parent)
end

local function addList(parent: Instance, padding: number)
	create("UIListLayout", {
		Padding = UDim.new(0, padding),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, parent)
end

local function tween(instance: Instance, goal: { [string]: any }, duration: number?)
	TweenService:Create(
		instance,
		TweenInfo.new(duration or 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		goal
	):Play()
end

local function createRow(window: Window, title: string, description: string?): RowParts
	window.Order += 1

	local row = create("Frame", {
		Name = title,
		BackgroundColor3 = Theme.Row,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = window.Order,
	}, window.Content)
	addStroke(row)
	addPadding(row, 12, 14, 12, 14)
	addList(row, 10)

	local top = create("Frame", {
		Name = "Top",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 1,
	}, row)

	local textFrame = create("Frame", {
		Name = "Text",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -(WIDGET_WIDTH + 16), 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, top)
	create("UISizeConstraint", { MinSize = Vector2.new(0, WIDGET_HEIGHT) }, textFrame)
	create("UIListLayout", {
		Padding = UDim.new(0, 3),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}, textFrame)

	local titleLabel = create("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		FontFace = Fonts.Bold,
		TextSize = 17,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Text = title,
		LayoutOrder = 1,
	}, textFrame)

	local descriptionText = description or ""
	local descriptionLabel = create("TextLabel", {
		Name = "Description",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		FontFace = Fonts.Regular,
		TextSize = 14,
		TextColor3 = Theme.SubText,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Text = descriptionText,
		Visible = descriptionText ~= "",
		LayoutOrder = 2,
	}, textFrame)

	return {
		Row = row,
		Top = top,
		Title = titleLabel,
		Description = descriptionLabel,
	}
end

local function makeElement(parts: RowParts, set: (any) -> (), get: () -> any): Element
	return {
		Set = function(_, value: any)
			set(value)
		end,
		Get = function(_)
			return get()
		end,
		SetTitle = function(_, text: string)
			parts.Title.Text = text
		end,
		SetDescription = function(_, text: string)
			parts.Description.Text = text
			parts.Description.Visible = text ~= ""
		end,
		Destroy = function(_)
			parts.Row:Destroy()
		end,
	}
end

local function createWidgetButton(parent: Instance, text: string): TextButton
	return create("TextButton", {
		Name = "Widget",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(WIDGET_WIDTH, WIDGET_HEIGHT),
		BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		FontFace = Fonts.Bold,
		TextSize = 16,
		TextColor3 = Theme.Text,
		Text = text,
	}, parent)
end

local function snap(value: number, min: number, max: number, step: number): number
	local snapped = min + math.floor((value - min) / step + 0.5) * step
	snapped = math.floor(snapped * 1e6 + 0.5) / 1e6
	return math.clamp(snapped, min, max)
end

local function formatValue(value: number, step: number, suffix: string): string
	if step % 1 == 0 then
		return tostring(math.floor(value + 0.5)) .. suffix
	end
	return string.format("%.2f", value) .. suffix
end

function UILibrary.new(config: WindowConfig): Window
	local parent = config.Parent or (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")

	local gui = create("ScreenGui", {
		Name = config.Name or "UILibrary",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 100,
	}, parent)

	local main = create("Frame", {
		Name = "Main",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.92, 0.86),
		BackgroundColor3 = Theme.Background,
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		Visible = config.Visible ~= false,
	}, gui)
	create("UISizeConstraint", { MaxSize = Vector2.new(620, 520) }, main)
	addStroke(main)

	create("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 12),
		Size = UDim2.new(1, -80, 0, 28),
		FontFace = Fonts.Bold,
		TextSize = 24,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = config.Title,
	}, main)

	create("TextLabel", {
		Name = "Subtitle",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 42),
		Size = UDim2.new(1, -80, 0, 18),
		FontFace = Fonts.Regular,
		TextSize = 14,
		TextColor3 = Theme.SubText,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = config.Subtitle or "",
		Visible = (config.Subtitle or "") ~= "",
	}, main)

	local close = create("TextButton", {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 12),
		Size = UDim2.fromOffset(40, 40),
		BackgroundColor3 = Theme.Row,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		FontFace = Fonts.Bold,
		TextSize = 18,
		TextColor3 = Theme.Text,
		Text = "X",
	}, main)
	addStroke(close)

	local content = create("ScrollingFrame", {
		Name = "Content",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 76),
		Size = UDim2.new(1, 0, 1, -76),
		CanvasSize = UDim2.fromOffset(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Color3.fromRGB(90, 90, 90),
	}, main)
	addPadding(content, 4, 16, 16, 16)
	addList(content, 8)

	local self = setmetatable({
		Gui = gui,
		Main = main,
		Content = content,
		Connections = {},
		Order = 0,
		OnClose = config.OnClose,
	}, UILibrary)

	close.Activated:Connect(function()
		self:Close()
	end)

	local keybind = config.Keybind
	if keybind then
		table.insert(
			self.Connections,
			UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
				if not processed and input.KeyCode == keybind then
					self:Toggle()
				end
			end)
		)
	end

	return self
end

function UILibrary.Open(self: Window)
	self.Main.Visible = true
end

function UILibrary.Close(self: Window)
	if not self.Main.Visible then
		return
	end
	self.Main.Visible = false
	if self.OnClose then
		task.spawn(self.OnClose)
	end
end

function UILibrary.Toggle(self: Window)
	if self.Main.Visible then
		self:Close()
	else
		self:Open()
	end
end

function UILibrary.IsOpen(self: Window): boolean
	return self.Main.Visible
end

function UILibrary.Destroy(self: Window)
	for _, connection in self.Connections do
		connection:Disconnect()
	end
	table.clear(self.Connections)
	self.Gui:Destroy()
end

function UILibrary.AddSection(self: Window, text: string): TextLabel
	self.Order += 1
	return create("TextLabel", {
		Name = text,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 24),
		FontFace = Fonts.Bold,
		TextSize = 13,
		TextColor3 = Theme.SubText,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Bottom,
		Text = string.upper(text),
		LayoutOrder = self.Order,
	}, self.Content)
end

function UILibrary.AddLabel(self: Window, config: LabelConfig): Element
	local parts = createRow(self, config.Title, config.Description)
	local text = config.Description or ""
	return makeElement(parts, function(value: any)
		text = tostring(value)
		parts.Description.Text = text
		parts.Description.Visible = text ~= ""
	end, function()
		return text
	end)
end

function UILibrary.AddToggle(self: Window, config: ToggleConfig): Element
	local parts = createRow(self, config.Title, config.Description)
	local onText = config.OnText or "ON"
	local offText = config.OffText or "OFF"
	local value = config.Default == true
	local button = createWidgetButton(parts.Top, onText)

	local function render(animate: boolean)
		button.Text = if value then onText else offText
		local goal = {
			BackgroundTransparency = if value then 0 else 1,
			TextColor3 = if value then Theme.Text else Theme.SubText,
		}
		if animate then
			tween(button, goal)
		else
			button.BackgroundTransparency = goal.BackgroundTransparency
			button.TextColor3 = goal.TextColor3
		end
	end

	local function setValue(newValue: boolean, silent: boolean?)
		if value == newValue then
			return
		end
		value = newValue
		render(true)
		if config.Callback and not silent then
			task.spawn(config.Callback, value)
		end
	end

	button.Activated:Connect(function()
		setValue(not value)
	end)

	render(false)
	if config.Callback then
		task.defer(config.Callback, value)
	end

	return makeElement(parts, function(newValue: any)
		setValue(newValue == true)
	end, function()
		return value
	end)
end

function UILibrary.AddButton(self: Window, config: ButtonConfig): Element
	local parts = createRow(self, config.Title, config.Description)
	local button = createWidgetButton(parts.Top, config.ButtonText or "RUN")

	button.Activated:Connect(function()
		tween(button, { BackgroundColor3 = Theme.AccentBright }, 0.08)
		task.delay(0.1, function()
			if button.Parent then
				tween(button, { BackgroundColor3 = Theme.Accent }, 0.15)
			end
		end)
		if config.Callback then
			task.spawn(config.Callback)
		end
	end)

	return makeElement(parts, function(text: any)
		button.Text = tostring(text)
	end, function()
		return button.Text
	end)
end

function UILibrary.AddSlider(self: Window, config: SliderConfig): Element
	local parts = createRow(self, config.Title, config.Description)
	local min = config.Min
	local max = config.Max
	local step = config.Step or 1
	local suffix = config.Suffix or ""
	local value = snap(config.Default or min, min, max, step)

	local valueLabel = create("TextLabel", {
		Name = "Value",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(WIDGET_WIDTH, WIDGET_HEIGHT),
		BackgroundTransparency = 1,
		FontFace = Fonts.Bold,
		TextSize = 16,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "",
	}, parts.Top)

	local hit = create("Frame", {
		Name = "Slider",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 20),
		LayoutOrder = 2,
		Active = true,
	}, parts.Row)

	local bar = create("Frame", {
		Name = "Bar",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(1, 0, 0, 6),
		BackgroundColor3 = Theme.Track,
		BorderSizePixel = 0,
	}, hit)

	local fill = create("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Theme.AccentBright,
		BorderSizePixel = 0,
	}, bar)

	local function render()
		local alpha = if max > min then (value - min) / (max - min) else 0
		fill.Size = UDim2.fromScale(alpha, 1)
		valueLabel.Text = formatValue(value, step, suffix)
	end

	local function setValue(newValue: number, silent: boolean?)
		local snapped = snap(newValue, min, max, step)
		if snapped == value then
			return
		end
		value = snapped
		render()
		if config.Callback and not silent then
			task.spawn(config.Callback, value)
		end
	end

	local function updateFromX(x: number)
		local width = hit.AbsoluteSize.X
		if width <= 0 then
			return
		end
		local alpha = math.clamp((x - hit.AbsolutePosition.X) / width, 0, 1)
		setValue(min + (max - min) * alpha)
	end

	local dragging = false
	local connections: { RBXScriptConnection } = {}

	table.insert(
		connections,
		hit.InputBegan:Connect(function(input: InputObject)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				dragging = true
				self.Content.ScrollingEnabled = false
				updateFromX(input.Position.X)
			end
		end)
	)

	table.insert(
		connections,
		UserInputService.InputChanged:Connect(function(input: InputObject)
			if
				dragging
				and (
					input.UserInputType == Enum.UserInputType.MouseMovement
					or input.UserInputType == Enum.UserInputType.Touch
				)
			then
				updateFromX(input.Position.X)
			end
		end)
	)

	table.insert(
		connections,
		UserInputService.InputEnded:Connect(function(input: InputObject)
			if
				dragging
				and (
					input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.Touch
				)
			then
				dragging = false
				self.Content.ScrollingEnabled = true
			end
		end)
	)

	render()
	if config.Callback then
		task.defer(config.Callback, value)
	end

	local element = makeElement(parts, function(newValue: any)
		if type(newValue) == "number" then
			setValue(newValue)
		end
	end, function()
		return value
	end)

	element.Destroy = function(_)
		for _, connection in connections do
			connection:Disconnect()
		end
		if dragging then
			self.Content.ScrollingEnabled = true
		end
		parts.Row:Destroy()
	end

	return element
end

return UILibrary
