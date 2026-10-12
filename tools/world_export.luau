-- Build-time Roblox geometry adapter. Executes the actual world builders; never used by gameplay.
local V={}; V.__index=function(v,k)
 if k=="Magnitude" then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z) end
 if k=="Unit" then return v/v.Magnitude end
 return V[k]
end
local function vec(x,y,z) return setmetatable({X=x or 0,Y=y or 0,Z=z or 0,Kind="Vector3"},V) end
V.__add=function(a,b) return vec(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
V.__sub=function(a,b) return vec(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
V.__unm=function(a) return a*-1 end
V.__mul=function(a,b) if type(a)=="number" then a,b=b,a end; return vec(a.X*b,a.Y*b,a.Z*b) end
V.__div=function(a,b) return a*(1/b) end
local function cross(a,b) return vec(a.Y*b.Z-a.Z*b.Y,a.Z*b.X-a.X*b.Z,a.X*b.Y-a.Y*b.X) end
local CF={}; CF.__index=CF
local identity={1,0,0,0,1,0,0,0,1}
local function cf(p,r) return setmetatable({Position=p or vec(),R=r or identity,Kind="CFrame"},CF) end
local function rotate(r,p) return vec(r[1]*p.X+r[2]*p.Y+r[3]*p.Z,r[4]*p.X+r[5]*p.Y+r[6]*p.Z,r[7]*p.X+r[8]*p.Y+r[9]*p.Z) end
CF.__mul=function(a,b)
 local r={}
 for row=0,2 do for col=0,2 do
  local n=0; for k=0,2 do n+=a.R[row*3+k+1]*b.R[k*3+col+1] end
  r[row*3+col+1]=n
 end end
 return cf(a.Position+rotate(a.R,b.Position),r)
end
CF.__add=function(a,b) return cf(a.Position+b,a.R) end
local CFrame={}
function CFrame.new(x,y,z) return cf(if type(x)=="table" then x else vec(x,y,z)) end
function CFrame.Angles(x,y,z)
 local sx,cx,sy,cy,sz,cz=math.sin(x),math.cos(x),math.sin(y),math.cos(y),math.sin(z),math.cos(z)
 return cf(nil,{1,0,0,0,cx,-sx,0,sx,cx})*cf(nil,{cy,0,sy,0,1,0,-sy,0,cy})*cf(nil,{cz,-sz,0,sz,cz,0,0,0,1})
end
function CFrame.lookAt(a,b)
 local back=(a-b).Unit; local right=cross(vec(0,1,0),back).Unit; local up=cross(back,right)
 return cf(a,{right.X,up.X,back.X,right.Y,up.Y,back.Y,right.Z,up.Z,back.Z})
end
local nextId=0
local Methods={}
function Methods:SetAttribute(k,v) self.Attributes[k]=v end
function Methods:GetAttribute(k) return self.Attributes[k] end
function Methods:GetChildren() return self.Children end
function Methods:FindFirstChild(name) for _,v in self.Children do if v.Name==name then return v end end end
function Methods:GetDescendants()
 local result={}; for _,child in self.Children do table.insert(result,child); for _,desc in child:GetDescendants() do table.insert(result,desc) end end; return result
end
function Methods:IsA(class) return self.ClassName==class end
function Methods:Destroy() end
local function instance(class)
 nextId+=1
 return setmetatable({ClassName=class,Name=class,Children={},Attributes={},Kind="Instance",Id=nextId},{__index=Methods,
  __newindex=function(o,k,v) rawset(o,k,v); if k=="Parent" and v then table.insert(v.Children,o) end end})
end
local function enumCategory(category)
 return setmetatable({},{__index=function(_,key) return {Kind="Enum",Category=category,Name=key} end})
end
local enums=setmetatable({},{__index=function(_,key) return enumCategory(key) end})
local function udim2(xs,xo,ys,yo) return {Kind="UDim2",XS=xs,XO=xo,YS=ys,YO=yo} end
local root={World={},Common={}}
root.World.Parent,root.Common.Parent=root,root
root.World.PlotBuilder,root.World.BiomeBuilder="PlotBuilder","BiomeBuilder"
root.World.LegacyWorldCleanup="LegacyWorldCleanup"
root.Common.BuildUtil="BuildUtil"
local shared={Config={GameConfig="Config",Biomes="Biomes",ShelterUpgrades="Upgrades"},Pets={PetHousing="PetHousing"}}
local world=instance("Workspace")
local cache={}
local function requireModule(name)
 if cache[name] then return cache[name] end
 local env=setmetatable({script={Parent=if name=="BuildUtil" then root.Common else root.World},
  game={GetService=function() return {Shared=shared} end},workspace=world,
  Instance={new=instance},Enum=enums,CFrame=CFrame,Vector3={new=vec,one=vec(1,1,1),zero=vec()},
  Color3={fromRGB=function(r,g,b) return {Kind="Color3",R=r/255,G=g/255,B=b/255} end},
  UDim2={new=udim2,fromOffset=function(x,y) return udim2(0,x,0,y) end,fromScale=function(x,y) return udim2(x,0,y,0) end},
 },{__index=getfenv()})
 env.require=requireModule
 local chunk=assert(loadstring(sources[name],name)); setfenv(chunk,env); cache[name]=chunk(); return cache[name]
end
local built=requireModule("WorldBuilder").Build()
built.Model.Name="ShelterPreview"
-- Serialize geometry and labels, excluding runtime-only records and references to parents.
local function quote(s) return '"'..string.gsub(string.gsub(string.gsub(string.gsub(s,'\\','\\\\'),'"','\\"'),'\n','\\n'),'\r','\\r')..'"' end
local function json(value)
 if type(value)=="string" then return quote(value) end
 if type(value)=="number" or type(value)=="boolean" then return tostring(value) end
 if type(value)~="table" then return "null" end
 local parts={}
 if #value>0 then for _,v in value do table.insert(parts,json(v)) end; return "["..table.concat(parts,",").."]" end
 for key,v in value do if key~="Parent" then
  if type(v)=="table" and v.Kind=="Instance" and key~="Children" then v={Kind="Ref",Id=v.Id} end
  table.insert(parts,quote(tostring(key))..":"..json(v))
 end end
 return "{"..table.concat(parts,",").."}"
end
print(json(built.Model))

