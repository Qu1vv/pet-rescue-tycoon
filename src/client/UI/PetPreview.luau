local Shared=game.ReplicatedStorage:WaitForChild("Shared")
local Geometry=require(Shared.Pets.PetGeometry)
local Preview={}
-- Renders original safe geometry in a card; locked entries use a single-color silhouette.
function Preview.Create(parent,definition,variant,locked)
 local view=Instance.new("ViewportFrame")
 view.Size=UDim2.fromOffset(100,105); view.Position=UDim2.fromOffset(4,8)
 view.BackgroundTransparency=1; view.Ambient=Color3.fromRGB(205,205,205); view.LightColor=Color3.new(1,1,1); view.Parent=parent
 local model=Instance.new("Model"); model.Parent=view
 for _,shape in Geometry.Build(definition,variant,{Stage=1}) do
  local part=Instance.new("Part"); part.Anchored=true; part.Shape=Enum.PartType.Ball
  part.Size=Vector3.new(table.unpack(shape.Size))
  part.CFrame=CFrame.new(table.unpack(shape.Position))*CFrame.Angles(math.rad(shape.Rotation[1]),math.rad(shape.Rotation[2]),math.rad(shape.Rotation[3]))
  part.Color=if locked then Color3.fromRGB(100,112,123) else Color3.fromRGB(table.unpack(shape.Color))
  part.Parent=model
 end
 local camera=Instance.new("Camera"); camera.FieldOfView=38
 camera.CFrame=CFrame.lookAt(Vector3.new(5,4,-9),Vector3.new(0,2,0)); camera.Parent=view; view.CurrentCamera=camera
 return view
end
return Preview
