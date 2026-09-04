local DiscordLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/bloodball/-back-ups-for-libs/main/discord"))()

local Ui = {
	DefaultEditorContent = "--Welcome to Sigma Spy",

    SeasonLabels = { 
        January = "⛄%s⛄", 
        February = "🌨️%s🏂", 
        March = "🌹%s🌺", 
        April = "🐣%s✝️", 
        May = "🐝%s🌞", 
        June = "🪴%s🥕", 
        July = "🌊%s🏖️", 
        August = "☀️%s🌞", 
        September = "🍁%s🍁", 
        October = "🎃%s🎃", 
        November = "🍂%s🍂", 
        December = "🎄%s🎁"
    },
    
	OptionTypes = {
		boolean = "Checkbox",
	},

    Window = nil,
    RandomSeed = Random.new(tick()),
	Logs = setmetatable({}, {__mode = "k"}),
	LogQueue = setmetatable({}, {__mode = "v"}),
} 

type table = {
	[any]: any
}

type Log = {
	Remote: Instance,
	Method: string,
	Args: table,
	IsReceive: boolean?,
	MetaMethod: string?,
	OrignalFunc: ((...any) -> ...any)?,
	CallingScript: Instance?,
	CallingFunction: ((...any) -> ...any)?,
	ClassData: table?,
	ReturnValues: table?,
	RemoteData: table?,
	Id: string,
	Selectable: table,
	HeaderData: table
}

--// Compatibility
local SetClipboard = setclipboard or toclipboard or set_clipboard

--// Libraries
local IDEModule = loadstring(game:HttpGet('https://raw.githubusercontent.com/depthso/Dear-ReGui/refs/heads/main/lib/ide.lua'))()

--// Services
local InsertService: InsertService

--// Modules
local Flags
local Generation
local Process
local Hook 
local Config

local ActiveData = nil
local RemotesCount = 0

local TextFont = Font.fromEnum(Enum.Font.Code)
local FontSuccess = false

local function DeepCloneTable(Table)
	local New = {}
	for Key, Value in next, Table do
		New[Key] = typeof(Value) == "table" and DeepCloneTable(Value) or Value
	end
	return New
end

function Ui:SetClipboard(Content: string)
	SetClipboard(Content)
end

function Ui:TurnSeasonal(Text: string): string
    local SeasonLabels = self.SeasonLabels
    local Month = os.date("%B")
    local Base = SeasonLabels[Month]

    return Base:format(Text)
end

function Ui:SetFont(FontJsonFile: string, FontContent: string)
	if not FontJsonFile then return end

	FontSuccess = FontContent ~= ""
	if not FontSuccess then return end

	local AssetId = getcustomasset(FontJsonFile, false)
	local NewFont = Font.new(AssetId)
	TextFont = NewFont
end

function Ui:FontWasSuccessful()
	if FontSuccess then return end
	self:ShowModal({
		"Unfortunately your executor was unable to download the font",
		"\nUsing default font"
	})
end

function Ui:Init(Data)
    local Modules = Data.Modules
	local Services = Data.Services

	InsertService = Services.InsertService

	Flags = Modules.Flags
	Generation = Modules.Generation
	Process = Modules.Process
	Hook = Modules.Hook
	Config = Modules.Config
end

function Ui:CreateWindow()
    self:CreateDiscordWindow()
	self:FontWasSuccessful()

	Flags:SetFlagCallback("UiVisible", function(self, Visible)
		-- DiscordLib doesn't have built-in visibility toggle
		-- We'll handle this differently
	end)

	return self.Window
end

function Ui:CreateDiscordWindow()
    local Window = DiscordLib:Window("Sigma Spy")
    self.Window = Window
    
    -- Create main server
    local mainServer = Window:Server("Sigma Spy", "")
    
    -- Remote logs channel
    local remoteChannel = mainServer:Channel("Remote Logs")
    
    -- Options channel
    local optionsChannel = mainServer:Channel("Options")
    
    -- Editor channel
    local editorChannel = mainServer:Channel("Editor")
    
    -- Store channels for later use
    self.RemoteChannel = remoteChannel
    self.OptionsChannel = optionsChannel
    self.EditorChannel = editorChannel
    
    self:AuraCounterService()
    
    return Window
end

function Ui:ShowModal(Lines: table)
	local Message = table.concat(Lines, "\n")
	DiscordLib:Notification("Sigma Spy", Message, "Okay!")
end

function Ui:ShowUnsupported(FuncName: string)
	Ui:ShowModal({
		"Unfortunately Sigma Spy is not supported on your executor",
		`\n\nMissing function: {FuncName}`
	})
end

function Ui:CreateOptionsForDict(Parent, Dict: table, Callback)
	for Key, Value in next, Dict do
		Parent:Toggle(
			Key,
			Value,
			function(bool)
				Dict[Key] = bool
				if Callback then Callback() end
			end
		)
	end
end

function Ui:CreateElements(Parent, Options)
	local OptionTypes = self.OptionTypes
	
	for Name, Data in next, Options do
		local Value = Data.Value
		local Type = typeof(Value)

		local Class = OptionTypes[Type]
		if not Class then continue end

		if Class == "Checkbox" then
			Parent:Toggle(
				Name,
				Value,
				function(bool)
					Data.Callback(nil, bool)
				end
			)
		end
	end
end

function Ui:DisplayAura()
    local Rand = self.RandomSeed
    local AURA = Rand:NextInteger(1, 9999999)
    local Title = `Sigma Spy - Depso | AURA: {AURA}`
    local Seasonal = self:TurnSeasonal(Title)
    
    -- Update window title if possible
    if self.Window and self.Window.SetTitle then
        self.Window:SetTitle(Seasonal)
    end
end

function Ui:AuraCounterService()
    task.spawn(function()
        while true do
            self:DisplayAura()
            task.wait(5)
        end
    end)
end

function Ui:CreateWindowContent(Window)
    -- Remote logs
    self.RemotesList = {}
    
    -- Create editor tab content
    self:MakeEditorTab(Window)
    
    -- Create options tab
    self:MakeOptionsTab(Window)
end

function Ui:MakeOptionsTab(Window)
    local optionsChannel = self.OptionsChannel
    
    optionsChannel:Seperator()
    optionsChannel:Label("=== Logs ===")
    
    optionsChannel:Button(
        "Clear logs",
        function()
            self:ClearLogs()
        end
    )
    
    optionsChannel:Button(
        "Clear blocks",
        function()
            Process:UpdateAllRemoteData("Blocked", false)
        end
    )
    
    optionsChannel:Button(
        "Clear excludes",
        function()
            Process:UpdateAllRemoteData("Excluded", false)
        end
    )
    
    optionsChannel:Seperator()
    optionsChannel:Label("=== Settings ===")
    
    local flags = Flags:GetFlags()
    self:CreateElements(optionsChannel, flags)
    
    optionsChannel:Seperator()
    optionsChannel:Label("=== Information ===")
    optionsChannel:Label("Sigma spy - Created by depso!")
    optionsChannel:Label("Thank you to syn for your suggestions and testing")
    optionsChannel:Label("Boiiiiii what did you say about Sigma Spy 💀💀 (+9999999 AURA)")
end

function Ui:MakeEditorTab(Window)
    local editorChannel = self.EditorChannel
    local Default = self.DefaultEditorContent
    
    -- Editor buttons
    editorChannel:Button(
        "Copy",
        function()
            SetClipboard(Default)
        end
    )
    
    editorChannel:Button(
        "Repeat call",
        function()
            if ActiveData and ActiveData.RepeatCall then
                ActiveData:RepeatCall()
            end
        end
    )
    
    editorChannel:Button(
        "Get return",
        function()
            if ActiveData and ActiveData.GetReturn then
                ActiveData:GetReturn()
            end
        end
    )
    
    editorChannel:Button(
        "Generate info",
        function()
            if ActiveData and ActiveData.GenerateInfo then
                ActiveData:GenerateInfo()
            end
        end
    )
    
    editorChannel:Button(
        "Decompile script",
        function()
            if ActiveData and ActiveData.Decompile then
                ActiveData:Decompile()
            end
        end
    )
end

function Ui:SetFocusedRemote(Data)
    self.ActiveData = Data
    ActiveData = Data
    
    -- Show remote info in a notification
    local Remote = Data.Remote
    local Method = Data.Method
    local Id = Data.Id
    
    DiscordLib:Notification("Remote Selected", 
        string.format("Remote: %s\nMethod: %s\nID: %s", tostring(Remote), Method, Id),
        "OK"
    )
    
    -- Update editor content if possible
    local remoteChannel = self.RemoteChannel
    if remoteChannel then
        remoteChannel:Seperator()
        remoteChannel:Label(string.format("=== Remote: %s ===", tostring(Remote)))
        remoteChannel:Label(string.format("Method: %s", Method))
        remoteChannel:Label(string.format("ID: %s", Id))
        
        if Data.Args then
            remoteChannel:Label(string.format("Args: %s", tostring(Data.Args)))
        end
    end
end

function Ui:GetRemoteHeader(Data: Log)
	local Logs = self.Logs
	local Id = Data.Id
	local Remote = Data.Remote

	local Existing = Logs[Id]
	if Existing then return Existing end

	local HeaderData = {	
		LogCount = 0,
		Remote = Remote
	}

	RemotesCount += 1

	function HeaderData:LogAdded()
		self.LogCount += 1
		return self
	end

	function HeaderData:Remove()
		Logs[Id] = nil
		table.clear(HeaderData)
	end

	Logs[Id] = HeaderData
	return HeaderData
end

function Ui:ClearLogs()
	local Logs = self.Logs
	RemotesCount = 0
	table.clear(Logs)
	
	if self.RemoteChannel then
		self.RemoteChannel:Label("=== Logs Cleared ===")
	end
end

function Ui:QueueLog(Data)
	local LogQueue = self.LogQueue
    table.insert(LogQueue, Data)
end

function Ui:ProcessLogQueue()
	local Queue = self.LogQueue
    if #Queue <= 0 then return end

    for Index, Data in next, Queue do
        self:CreateLog(Data)
        table.remove(Queue, Index)
    end
end

function Ui:BeginLogService()
	coroutine.wrap(function()
		while true do
			Ui:ProcessLogQueue()
			task.wait()
		end
	end)()
end

function Ui:CreateLog(Data: Log)
    local Remote = Data.Remote
	local Method = Data.Method
    local Args = Data.Args
    local IsReceive = Data.IsReceive
	local Id = Data.Id
	
	local IsNilParent = Hook:Index(Remote, "Parent") == nil
	local RemoteData = Process:GetRemoteData(Id)

	local Paused = Flags:GetFlagValue("Paused")
	if Paused then return end

	local CheckCaller = Flags:GetFlagValue("CheckCaller")
	if CheckCaller and not checkcaller() then return end

	local IgnoreNil = Flags:GetFlagValue("IgnoreNil")
	if IgnoreNil and IsNilParent then return end

	local LogRecives = Flags:GetFlagValue("LogRecives")
	if not LogRecives and IsReceive then return end

    if RemoteData.Excluded then return end

	local ClonedArgs = DeepCloneTable({unpack(Args)})
	Data.Args = ClonedArgs

	local Color = Config.MethodColors[Method:lower()]
	local Text = string.format("%s | %s", tostring(Remote), Method)

    local HeaderData = self:GetRemoteHeader(Data):LogAdded()
    
    -- Display log in the remote channel
    if self.RemoteChannel then
        local logText = string.format("%s | Method: %s | Args: %s", 
            tostring(Remote), 
            Method, 
            tostring(ClonedArgs)
        )
        self.RemoteChannel:Label(logText)
    end

	Data.HeaderData = HeaderData
end

return Ui
