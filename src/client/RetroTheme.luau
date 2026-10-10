-- One palette/type/spacing source for the complete arcade interface.
local Settings=require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("UIThemeConfig"))
local Theme={RGB={
	background={12,7,20},panel={27,15,42},raised={40,22,58},board={10,7,17},empty={24,16,35},
	text={255,244,228},muted={176,158,191},line={75,43,92},pink={255,44,160},purple={210,45,170},
	cyan={50,220,255},orange={255,152,81},yellow={255,214,68},green={127,222,173},
	I={85,215,230},O={255,212,112},T={185,118,242},S={128,221,171},Z={248,97,143},J={111,146,238},L={255,164,98},G={104,87,124},
},Fonts={Display=Enum.Font.Arcade,Body=Enum.Font.Gotham,Strong=Enum.Font.GothamBold,Mono=Enum.Font.Arcade},
Type={Hero=54,Heading=22,Body=16,Label=13,Number=28},Space={Small=8,Medium=16,Large=24,XL=32},Border=Settings.Border,Radius=Settings.Radius,Touch=44,
Motion={Hover=0.12,Page=0.18,Preview=0.7}}
Theme.Colors={}; for name,rgb in pairs(Theme.RGB) do Theme.Colors[name]=Color3.fromRGB(table.unpack(rgb)) end
local ok,face=pcall(function() return Font.new(Settings.FontAsset,Enum.FontWeight.Regular,Enum.FontStyle.Normal) end)
Theme.Face=ok and face or Font.fromEnum(Enum.Font.Arcade)
Theme.BodyFace=Font.fromEnum(Enum.Font.Gotham)
Theme.StrongFace=Font.fromEnum(Enum.Font.GothamBold)
Theme.FontFamily=ok and Settings.FontAsset or "Roblox Arcade fallback"
return Theme
