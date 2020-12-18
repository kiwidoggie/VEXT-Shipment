class "ShipmentShared"

function ShipmentShared:__init()
    -- Register the partition event handler
    self.m_PartitionLoadedEvent = Events:Subscribe("Partition:Loaded", self, self.OnPartitionLoaded)

    self.m_EngineUpdateEvent = Events:Subscribe("Engine:Update", self, self.OnUpdate)

    -- After the partition we need to look for
    -- VolumeVectorShapeData 2952DE34-7CD7-48F3-BB0B-7C3CA2B18108
    self.m_NosehairTDM_VVSD_Guid = Guid("2952DE34-7CD7-48F3-BB0B-7C3CA2B18108", "D")

    print("ShipmentShared initialization.")

    self.m_MaxTick = 1.0
    self.m_Tick = 0.0

    self.m_Bounds = {
        Vec3(421.278, 213.689, -1373.87927),
        Vec3(460.535675 , 213.689, -1373.87927),
        Vec3(460.535675 , 213.689, -1334.788), -- 421.359192 213.681564 -1334.33215
        Vec3(421.278, 213.689, -1334.788) -- 421.359192 213.681564 -1334.33215
    }
        
end

function ShipmentShared:OnUpdate(p_DeltaTime, p_SimulationDeltaTime)
    self.m_Tick = self.m_Tick + p_DeltaTime

    if self.m_Tick >= self.m_MaxTick then
        self.m_Tick = 0.0

        --NetEvents:Broadcast("Shipment:Points", self.m_Point1, self.m_Point2, self.m_Point3, self.m_Point4)
    end
end

function ShipmentShared:ModifyVolumeVectorShapeObjects(p_ObjectInstance)
    local s_VolumeVectorShapeData = VolumeVectorShapeData(p_ObjectInstance)
    s_VolumeVectorShapeData:MakeWritable()
    print("found volumevectorshapedata for TDM.")

    -- Clear and make our own
    s_VolumeVectorShapeData.points:clear()
    s_VolumeVectorShapeData.normals:clear()

    for _, l_Point in pairs(self.m_Bounds) do
        print("x: " .. l_Point.x .. " y: " .. l_Point.y .. " z: " .. l_Point.z)
        s_VolumeVectorShapeData.points:add(l_Point)
        s_VolumeVectorShapeData.normals:add(Vec3(0, 1, 0))
    end

    print("modified points")
end

function ShipmentShared:Modulo(a, b)
    return a - math.floor(a/b)*b
end

function ShipmentShared:ModifyAlternateSpawnEntity(p_ObjectInstance)
    -- Check if our point index is beyond the number of spawn points we have
    if self.m_PointIndex >= #self.m_SpawnPoints then
        print("spawn index wrapped around =[, add more spawnpoints")
        self.m_PointIndex = 1
    end

    -- Cast to our alternative spawn entity data
    local s_AlternateSpawnEntityData = AlternateSpawnEntityData(p_ObjectInstance)
    s_AlternateSpawnEntityData:MakeWritable() -- make it writable

    local s_TeamId = TeamId.TeamNeutral

    if self:Modulo(self.m_PointIndex, 2) == 0 then
        s_TeamId = TeamId.Team1
    else
        s_TeamId = TeamId.Team2
    end

    -- Change all spawnpoints to be team neutral
    s_AlternateSpawnEntityData.team = s_TeamId

    -- Get our selected transform
    local s_Transform = self.m_SpawnPoints[self.m_PointIndex]

    -- Assign the new transform
    s_AlternateSpawnEntityData.transform = s_Transform

    -- Increment our point index
    self.m_PointIndex = self.m_PointIndex + 1
end

function ShipmentShared:OnPartitionLoaded(p_Partition)
    -- Validate our partition
    if p_Partition == nil then
        return
    end

    -- Iterate through all instances
    local s_Instances = p_Partition.instances
    for l_Index, l_Instance in ipairs(s_Instances) do
        if not l_Instance:Is("WorldPartData") then
            goto _volumevectorshapedata_cont_
        end

        -- Cast the world part data
        local s_WorldPartData = WorldPartData(l_Instance)

        if not string.match(s_WorldPartData.name, "TDM_Logic") then
            print("skipping: " .. s_WorldPartData.name)
            goto _volumevectorshapedata_cont_
        end
        
        -- Get the objects
        local s_WorldPartDataObjects = s_WorldPartData.objects

        -- Iterate through each of the WorldPartData objects
        for _, l_ObjectInstance in pairs(s_WorldPartDataObjects) do
            if l_ObjectInstance:Is("VolumeVectorShapeData") then
                self:ModifyVolumeVectorShapeObjects(l_ObjectInstance)
            end

            if l_ObjectInstance:Is("AlternateSpawnEntityData") then
                --self:ModifyAlternateSpawnEntity(l_ObjectInstance)
            end

            ::_worldobject_cont_::
        end
        
        -- Hack because lua doesn't support continue
        ::_volumevectorshapedata_cont_::
    end
end

g_ShipmentShared = ShipmentShared()