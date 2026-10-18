from pydantic import BaseModel, ConfigDict, PositiveInt


class NodeSchool(BaseModel):
    id: PositiveInt
    full_name: str
    short_name: str
    address: str
    is_active: bool
    model_config = ConfigDict(from_attributes=True)


class NodeBuilding(BaseModel):
    id: PositiveInt
    school_id: PositiveInt
    name: str
    address: str
    is_active: bool
    model_config = ConfigDict(from_attributes=True)


class NodeSchoolAdmin(BaseModel):
    id: PositiveInt
    school_id: PositiveInt
    login: str
    full_name: str
    phone: str | None
    hashed_password: str
    is_active: bool
    must_change_password: bool
    model_config = ConfigDict(from_attributes=True)


class NodeConfig(BaseModel):
    school: NodeSchool
    buildings: list[NodeBuilding]
    school_admins: list[NodeSchoolAdmin]


class NodeConfigEnvelope(BaseModel):
    message: str
    data: NodeConfig
