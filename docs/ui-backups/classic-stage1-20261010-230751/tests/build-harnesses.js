// Rebuild snapshots from this project's current source; no Roblox services are contacted.
const fs = require('fs');
const path = require('path');
const project = path.resolve(__dirname, '..');
const source = file => fs.readFileSync(path.join(project, file), 'utf8');
const fixture = file => fs.readFileSync(path.join(__dirname, 'fixtures', file), 'utf8');
const moduleCode = (name, file) => `local ${name}=(function()\n${name === "Catalog" ? source(file).replace(/^local Definition=.*\r?\n/, "local Definition=" + "(function()\n" + source("src/shared/Config/CosmeticConfig.luau") + "\nend)()\n") : source(file)}\nend)()\n`;
const pure = [
  ['E', 'src/shared/TetrisEngine.luau'],
  ['R', 'src/shared/Config/Rules.luau'],
  ['P', 'src/shared/Progression.luau'],
  ['C', 'src/server/GameConfig.luau'],
  ['Catalog', 'src/shared/Catalog.luau'],
];
let server = pure.map(([key, file]) => moduleCode(key, file)).join('');
server += fixture('server-mocks.luau');
for (const [key, file] of [
  ['Legacy', 'LegacyPlayerDataService'], ['Data', 'PlayerDataService'], ['Leaders', 'LeaderboardService'], ['S', 'ServerMain'],
]) {
  server += '\n' + (key === 'S' ? moduleCode(key, `src/server/${file}.luau`).replace('(function()\n', '(function()\nlocal Catalog=nil -- Do not inherit Catalog from the harness scope.\n') : moduleCode(key, `src/server/${file}.luau`));
  if (key !== 'S') server += `modules.${file}=${key}\n`;
}
server += fixture('server-checks.luau');
server += fixture('equip-checks.luau');
server += fixture('arcade-server-checks.luau');
fs.writeFileSync(path.join(__dirname, 'ServerHarness.luau'), server);

const input = moduleCode('R', 'src/shared/Config/Rules.luau') + fixture('Input-mocks.luau')
  + '\n' + moduleCode('Input', 'src/client/InputController.luau') + fixture('Input-checks.luau');
fs.writeFileSync(path.join(__dirname, 'InputHarness.luau'), input);

let ui = pure.map(([key, file]) => moduleCode(key, file)).join('');
ui += ["UIAssetConfig","UIThemeConfig","DeveloperProductConfig","BattleEffectsConfig","ShopPreviewConfig","DropEffectConfig","RankIconConfig","CurrencyIconConfig","BrickSkinConfig","GhostEffectConfig"].map(name => moduleCode(name,'src/shared/Config/'+name+'.luau')).join('');
ui += moduleCode('SoundConfig', 'src/shared/Config/SoundConfig.luau') + fixture('ui-mocks.luau');
ui += '\nlocal configuredImages=UIAssetConfig.Images\nlocal function blankImages(t) local result={} for k,v in pairs(t) do result[k]=type(v)=="table" and blankImages(v) or "" end return result end\nUIAssetConfig.Images=blankImages(configuredImages)\n';
for (const key of ['UIAssets', 'RetroTheme', 'NeonUI', 'NeonLayout', 'RetroArtwork', 'BrickStyles', 'AudioController', 'InputController', 'CosmeticRenderer', 'BrickRenderer', 'BrickPreviewRenderer', 'GameClient', 'ArcadeFeedback', 'ArcadeResults', 'PortalUI']) {
  ui += `\nmodules.${key}=(function()\n${source(`src/client/${key}.luau`)}\nend)()\n`;
}
ui += '\nlocal app=(function()\n' + source('src/client/TetrisUI.client.luau')
  + '\nreturn {gui=gui,menu=menu,portal=portal,root=root,scale=rootScale,safe=safe,layout=applyLayout,own=ownBoard,enemy=enemyBoard,arcade=arcade,client=client,menuObjects=menuObjects,nav=navButtons}\nend)()\n';
ui += fixture('ui-checks.luau');
ui += fixture('arcade-ui-checks.luau');
ui += fixture('ui-v3-checks.luau');
ui += fixture('reference-ui-checks.luau');
fs.writeFileSync(path.join(__dirname, 'UIHarness.luau'), ui);
let profiles=pure.map(([key,file])=>moduleCode(key,file)).join('')+fixture('profile-mocks.luau');
for(const key of ['ProfileStore','ProfileStoreMigration','PlayerDataService']){
  profiles+=`\nmodules.${key}=(function()\n${source(`src/server/${key}.luau`)}\nend)()\n`;
}
profiles+='local Data=modules.PlayerDataService\n'+fixture('profile-checks.luau');
profiles+=fixture('profile-network-setup.luau');
profiles+=moduleCode('S','src/server/ServerMain.luau').replace('(function()\n','(function()\nlocal Catalog=nil -- Require the real module dependency.\n');
profiles+='local function send(p,kind,data) remote.OnServerEvent:fire(p,kind,data) end\n'+fixture('equip-checks.luau');
profiles+='\nPlayers.List={}; RunService.IsStudio=function() return true end; C.ProfileStoreStudioPersistence=false; C.FreeCosmeticsInDebug=false; C.FreeShopPurchasesInDebug=false; remote.OnServerEvent=event()\n';
profiles+=moduleCode('StudioData','src/server/PlayerDataService.luau');
profiles+='modules.PlayerDataService=StudioData; Data=StudioData; assert(Data.Debug)\n';
profiles+=moduleCode('StudioS','src/server/ServerMain.luau').replace('(function()\n','(function()\nlocal Catalog=nil\n');
profiles+='S=StudioS\n'+fixture('equip-checks.luau');
profiles+='\nPlayers.List={}; C.ProfileStoreStudioPersistence=true; remote.OnServerEvent=event()\n';
profiles+=moduleCode('StudioPersistentData','src/server/PlayerDataService.luau');
profiles+='modules.PlayerDataService=StudioPersistentData; Data=StudioPersistentData; assert(not Data.Debug)\n';
profiles+=moduleCode('StudioPersistentS','src/server/ServerMain.luau').replace('(function()\n','(function()\nlocal Catalog=nil\n');
profiles+='S=StudioPersistentS\n'+fixture('equip-checks.luau');
fs.writeFileSync(path.join(__dirname,'ProfileStoreHarness.luau'),profiles);
console.log('Rebuilt Server, Input, UI and supplied-library ProfileStore harnesses from current source.');
