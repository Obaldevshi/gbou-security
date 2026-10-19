import pytest
from sqlalchemy import create_engine, text
from app.config.database import Base
import app.models  # register ORM tables for running this module independently
from app.core.building_scope import validate_building_database


@pytest.fixture
def isolated(tmp_path):
    engine = create_engine('sqlite:///' + (tmp_path / 'building.sqlite').as_posix())
    Base.metadata.create_all(engine)
    with engine.begin() as db:
        db.execute(text("INSERT INTO schools(id,full_name,short_name,address,is_active) VALUES(2,'Synthetic','2036','Synthetic',1)"))
        db.execute(text("INSERT INTO school_buildings(id,school_id,name,address,is_active) VALUES(1,2,'Building1','Synthetic',1)"))
        yield db
    engine.dispose()


def test_own_empty_building_is_valid_and_check_does_not_write(isolated):
    validate_building_database(isolated, 1, 2)
    assert isolated.execute(text('SELECT COUNT(*) FROM users')).scalar_one() == 0


@pytest.mark.parametrize('change', [
    "INSERT INTO school_buildings(id,school_id,name,address,is_active) VALUES(2,2,'Building2','Synthetic',0)",
    "INSERT INTO users(id,school_id,building_id,login,full_name,hashed_password,role,is_active,must_change_password) VALUES(1,2,2,'synthetic','Synthetic','not-a-password','teacher',0,0)",
    "INSERT INTO users(id,school_id,building_id,login,full_name,hashed_password,role,is_active,must_change_password) VALUES(1,2,NULL,'synthetic','Synthetic','not-a-password','guard',0,0)",
    "INSERT INTO users(id,school_id,building_id,login,full_name,hashed_password,role,is_active,must_change_password) VALUES(1,2,1,'synthetic','Synthetic','not-a-password','super_admin',0,0)",
])
def test_foreign_even_inactive_records_fail_without_deletion(isolated, change):
    isolated.execute(text(change))
    with pytest.raises(ValueError):
        validate_building_database(isolated, 1, 2)
    assert isolated.execute(text('SELECT COUNT(*) FROM school_buildings')).scalar_one() >= 1


def test_shared_central_school_admin_allowed_but_foreign_school_is_not(isolated):
    isolated.execute(text("INSERT INTO users(id,school_id,login,full_name,hashed_password,role,is_active,must_change_password) VALUES(1,2,'synthetic','Synthetic','not-a-password','school_admin',1,0)"))
    validate_building_database(isolated, 1, 2)
    with pytest.raises(ValueError):
        validate_building_database(isolated, 1, 3)
