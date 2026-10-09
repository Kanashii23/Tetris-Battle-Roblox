
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local oldGui = playerGui:FindFirstChild("TetrisBattleUI")
if oldGui then oldGui:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "TetrisBattleUI"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.Parent = playerGui

local background = Instance.new("Frame")
background.Size = UDim2.fromScale(1, 1)
background.BackgroundColor3 = Color3.fromRGB(10, 12, 30)
background.BorderSizePixel = 0
background.Parent = gui

local gradient = Instance.new("UIGradient")
gradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(12, 17, 45)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(47, 17, 72))
})
gradient.Rotation = 45
gradient.Parent = background

local title = Instance.new("TextLabel")
title.Name = "GameTitle"
title.AnchorPoint = Vector2.new(0.5, 0.5)
title.Position = UDim2.fromScale(0.5, 0.32)
title.Size = UDim2.fromScale(0.9, 0.15)
title.BackgroundTransparency = 1
title.Text = "TETRIS BATTLE"
title.TextColor3 = Color3.fromRGB(0, 230, 255)
title.Font = Enum.Font.GothamBlack
title.TextScaled = true
title.Parent = background

local titleLimit = Instance.new("UITextSizeConstraint")
titleLimit.MaxTextSize = 72
titleLimit.Parent = title

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(0, 180, 255)
stroke.Thickness = 1.5
stroke.Parent = title

local subtitle = Instance.new("TextLabel")
subtitle.AnchorPoint = Vector2.new(0.5, 0.5)
subtitle.Position = UDim2.fromScale(0.5, 0.44)
subtitle.Size = UDim2.fromScale(0.85, 0.06)
subtitle.BackgroundTransparency = 1
subtitle.Text = "MODERN NEON ARCADE"
subtitle.TextColor3 = Color3.fromRGB(200, 185, 255)
subtitle.Font = Enum.Font.GothamMedium
subtitle.TextScaled = true
subtitle.Parent = background

local playButton = Instance.new("TextButton")
playButton.Name = "PlayButton"
playButton.AnchorPoint = Vector2.new(0.5, 0.5)
playButton.Position = UDim2.fromScale(0.5, 0.62)
playButton.Size = UDim2.fromScale(0.55, 0.11)
playButton.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
playButton.Text = "PLAY"
playButton.TextColor3 = Color3.new(1, 1, 1)
playButton.TextScaled = true
playButton.Font = Enum.Font.GothamBold
playButton.Parent = background

local sizeConstraint = Instance.new("UISizeConstraint")
sizeConstraint.MaxSize = Vector2.new(320, 65)
sizeConstraint.Parent = playButton

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 14)
corner.Parent = playButton

local buttonStroke = Instance.new("UIStroke")
buttonStroke.Color = Color3.fromRGB(100, 240, 255)
buttonStroke.Thickness = 2
buttonStroke.Parent = playButton

playButton.Activated:Connect(function()
    playButton.Text = "COMING SOON"
    TweenService:Create(
        playButton,
        TweenInfo.new(0.25),
        {BackgroundColor3 = Color3.fromRGB(135, 65, 255)}
    ):Play()
end)

print("[Tetris Battle] Neon UI loaded!")
