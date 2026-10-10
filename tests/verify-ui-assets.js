const fs=require('fs'),path=require('path'),crypto=require('crypto'),root=path.resolve(__dirname,'..');
const pack=path.join(root,'assets/ui/TetrisBattle_UI_Assets');
const manifest=JSON.parse(fs.readFileSync(path.join(pack,'manifest.json'),'utf8'));
const config=fs.readFileSync(path.join(root,'src/shared/Config/UIAssetConfig.luau'),'utf8');
const checklist=fs.readFileSync(path.join(root,'ASSET_ID_CHECKLIST.md'),'utf8');
const hash=p=>crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
for(const asset of manifest.assets){
 const file=path.resolve(pack,asset.file); if(!file.startsWith(path.resolve(pack)+path.sep))throw Error('Invalid manifest path');
 const data=fs.readFileSync(file); if(data.subarray(0,8).toString('hex')!=='89504e470d0a1a0a')throw Error('Not PNG: '+asset.file);
 if(data.readUInt32BE(16)!==asset.width||data.readUInt32BE(20)!==asset.height||hash(file)!==asset.sha256)throw Error('Image changed: '+asset.file);
 const name=asset.key.split('/')[1]; if(!config.includes(name+' = ""')&&!config.includes(name+'=""'))throw Error('Missing configurable entry: '+name);
 if(!checklist.includes(asset.file))throw Error('Missing checklist: '+asset.file);
}
if(!fs.existsSync(path.join(pack,'preview.png'))||!checklist.includes('Images.artwork.preview'))throw Error('Missing contact sheet');
console.log('PASS 58 original PNGs / manifest integrity / named config entries / checklist coverage');
