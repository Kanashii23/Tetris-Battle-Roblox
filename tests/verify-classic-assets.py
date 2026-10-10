# Standard-library validation; no uploads, services, or additional dependencies.
from pathlib import Path
import hashlib, json, struct, zlib
root=Path(__file__).resolve().parents[1]
assets=root/"assets/cosmetics"
manifest=json.loads((assets/"NormalizedManifest.json").read_text(encoding="utf-8"))
def transparent_rgba(data):
 width,height=struct.unpack(">II",data[16:24]); assert data[24:26]==bytes([8,6])
 payload=b""; offset=8
 while offset<len(data):
  size=struct.unpack(">I",data[offset:offset+4])[0]; kind=data[offset+4:offset+8]
  if kind==b"IDAT": payload+=data[offset+8:offset+8+size]
  offset+=size+12
 raw=zlib.decompress(payload); previous=bytearray(width*4); cursor=0; transparent=False
 for _ in range(height):
  mode=raw[cursor]; cursor+=1; row=bytearray(raw[cursor:cursor+width*4]); cursor+=width*4
  for i in range(len(row)):
   left=row[i-4] if i>=4 else 0; above=previous[i]; upper=previous[i-4] if i>=4 else 0
   if mode==1: prediction=left
   elif mode==2: prediction=above
   elif mode==3: prediction=(left+above)//2
   elif mode==4:
    q=left+above-upper; distances=[abs(q-left),abs(q-above),abs(q-upper)]; prediction=[left,above,upper][distances.index(min(distances))]
   else: assert mode==0; prediction=0
   row[i]=(row[i]+prediction)%256
  transparent=transparent or 0 in row[3::4]; previous=row
 return transparent
assert len(manifest["assets"])==35
fields=set(); files=set()
for entry in manifest["assets"]:
 file=assets/"DefaultClassic_ExactTemplate_7Colors"/entry["file"]
 data=file.read_bytes(); assert data[:8]==b"\x89PNG\r\n\x1a\n"
 assert list(struct.unpack(">II",data[16:24]))==entry["dimensions"]
 assert hashlib.sha256(data).hexdigest()==entry["sha256"] and transparent_rgba(data)
 assert entry["robloxAssetId"]=="" and entry["configField"] not in fields
 fields.add(entry["configField"]); files.add(entry["file"])
assert len(files)==35
print("PASS normalized 35-file mapping, dimensions, checksums and transparent RGBA; upload IDs intentionally blank")
