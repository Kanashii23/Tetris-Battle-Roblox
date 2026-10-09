-- One palette/type/spacing source for the complete arcade interface.
local Theme={RGB={
	background={12,7,20},panel={27,15,42},raised={40,22,58},board={10,7,17},empty={24,16,35},
	text={255,244,228},muted={176,158,191},line={75,43,92},pink={255,61,143},purple={219,49,139},
	cyan={83,213,226},orange={255,152,81},yellow={255,218,137},green={127,222,173},
	I={85,215,230},O={255,212,112},T={185,118,242},S={128,221,171},Z={248,97,143},J={111,146,238},L={255,164,98},G={104,87,124},
},Fonts={Display=Enum.Font.Arcade,Body=Enum.Font.BuilderSans,Strong=Enum.Font.BuilderSansBold,Mono=Enum.Font.Code},
Type={Hero=54,Heading=22,Body=16,Label=13,Number=28},Space={Small=8,Medium=16,Large=24,XL=32},Border=1,Radius=2,Touch=44,
Motion={Hover=0.12,Page=0.18,Preview=0.7}}
Theme.Colors={}; for name,rgb in pairs(Theme.RGB) do Theme.Colors[name]=Color3.fromRGB(table.unpack(rgb)) end
return Theme
