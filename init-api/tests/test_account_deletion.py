from datetime import datetime, timedelta, timezone
import pytest
from sqlalchemy import create_engine, event
from sqlalchemy.orm import sessionmaker
from fastapi import FastAPI
from fastapi.testclient import TestClient
import app.models
from app.models import Base, User, UserRole, School, SchoolBuilding, SchoolClass, Student, ExitRequest, ExitRequestStatus, ExitReasonType, TeacherClassAssignment, TrustedDeviceSession, Category, AuditLog
from app.core.exceptions import UnauthorizedError, ConflictError, UnprocessableEntityError
from app.core.security import get_password_hash, verify_password, verify_token
from app.config.settings import settings
from app.repositories.user_repository import UserRepository
from app.repositories.account_deletion_repository import AccountDeletionRepository
from app.services.account_deletion_service import AccountDeletionService
from app.services.deletion_session_service import DeletionSessionService
from app.services.auth_service import AuthService

PASSWORD='SyntheticPassword8'


def test_migration014_preserves_profiles_and_single_head(tmp_path,monkeypatch):
    import importlib.util
    from pathlib import Path
    from alembic.migration import MigrationContext
    from alembic.operations import Operations
    from alembic.script import ScriptDirectory
    from sqlalchemy import inspect,text
    scripts=Path(__file__).parents[1]/'alembic'
    assert ScriptDirectory(str(scripts)).get_heads()==['014_account_deletion']
    spec=importlib.util.spec_from_file_location('account_migration_test',scripts/'versions/014_account_deletion.py')
    migration=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(migration)
    engine=create_engine('sqlite:///'+(tmp_path/'migration.sqlite').as_posix())
    with engine.begin() as connection:
        connection.execute(text('CREATE TABLE users(id INTEGER PRIMARY KEY,login TEXT)'))
        connection.execute(text("INSERT INTO users VALUES(1,'synthetic.teacher')"))
        monkeypatch.setattr(migration,'op',Operations(MigrationContext.configure(connection)))
        migration.upgrade()
        assert 'deleted_at' in {c['name'] for c in inspect(connection).get_columns('users')}
        assert connection.execute(text('SELECT deleted_at FROM users')).scalar_one() is None
        migration.downgrade()
        assert connection.execute(text('SELECT login FROM users')).scalar_one()=='synthetic.teacher'
    engine.dispose()

@pytest.fixture
def db(tmp_path,monkeypatch):
    from app.services.login_attempt_guard import LoginAttemptGuard
    import app.services.account_deletion_service as deletion_module
    monkeypatch.setattr(deletion_module,'deletion_guard',LoginAttemptGuard())
    engine=create_engine('sqlite:///'+str(tmp_path/'accounts.sqlite'))
    @event.listens_for(engine,'connect')
    def fk(connection,_): connection.execute('PRAGMA foreign_keys=ON')
    Base.metadata.create_all(engine)
    with sessionmaker(bind=engine,expire_on_commit=False)() as db:
        db.add(School(id=1,full_name='Демо',short_name='Демо',address='Демо'))
        db.flush()
        db.add(SchoolBuilding(id=1,school_id=1,name='Демо',address='Демо'))
        db.flush()
        db.add(SchoolClass(id=1,school_id=1,building_id=1,name='5А'))
        db.add_all([User(id=1,school_id=1,building_id=1,login='synthetic.teacher',full_name='Вымышленный учитель',phone='synthetic-phone',
                         hashed_password=get_password_hash(PASSWORD),role=UserRole.TEACHER,is_active=True,must_change_password=False),
                    User(id=2,school_id=1,building_id=1,login='synthetic.guard',full_name='Вымышленная охрана',hashed_password=get_password_hash(PASSWORD),
                         role=UserRole.GUARD,is_active=True,must_change_password=False)])
        db.flush()
        db.add(Student(id=1,school_id=1,class_id=1,last_name='Пример',first_name='Ученик',is_active=True))
        db.flush()
        db.add_all([TeacherClassAssignment(teacher_id=1,class_id=1),Category(user_id=1,name='Личное'),
            TrustedDeviceSession(user_id=1,name='Тест',token_hash='a'*64,expires_at=datetime.now(timezone.utc)+timedelta(days=1)),
            AuditLog(actor_id=1,school_id=1,method='POST',path='/api/v1/teacher/requests',status_code=200,ip_address='192.0.2.1',user_agent='test'),
            ExitRequest(id=1,school_id=1,building_id=1,class_id=1,student_id=1,teacher_id=1,released_by_id=2,
                reason_type=ExitReasonType.PARENT_NOTE,status=ExitRequestStatus.RELEASED,scheduled_at=datetime.now(timezone.utc))])
        db.commit()
        yield db
    engine.dispose()

def service(db,mode='local'): return AccountDeletionService(AccountDeletionRepository(db),mode)

def test_deletion_wipes_identity_credentials_links_and_keeps_school_records(db):
    original=db.get(User,1)
    service(db).delete(original,PASSWORD,'УДАЛИТЬ')
    db.expire_all()
    user=db.get(User,1)
    assert user.deleted_at is not None and not user.is_active
    assert user.login.startswith('deleted-') and user.full_name=='Удалённый сотрудник' and user.phone is None
    assert not verify_password(PASSWORD,user.hashed_password)
    assert db.query(TrustedDeviceSession).count()==0
    assert db.query(TeacherClassAssignment).count()==0
    assert db.query(Category).count()==0
    audit=db.query(AuditLog).filter(AuditLog.path=='/api/v1/teacher/requests').one()
    assert audit.actor_id is None and audit.ip_address is None and audit.user_agent is None
    request=db.get(ExitRequest,1)
    assert request.status==ExitRequestStatus.RELEASED and request.teacher_full_name=='Удалённый сотрудник'
    assert db.query(Student).count()==1 and db.query(SchoolClass).count()==1 and db.get(User,2).login=='synthetic.guard'
    assert UserRepository(db).get_by_login('synthetic.teacher') is None
    assert UserRepository(db).get_by_id(1) is None
    user.is_active=True # Even accidental status reactivation cannot restore access.
    with pytest.raises(UnauthorizedError): AuthService.ensure_user_can_access(user)

@pytest.mark.parametrize('password,confirmation,error',[("bad","УДАЛИТЬ",UnauthorizedError),(PASSWORD,'no',UnprocessableEntityError)])
def test_wrong_proof_does_not_delete(db,password,confirmation,error):
    with pytest.raises(error): service(db).delete(db.get(User,1),password,confirmation)
    assert db.get(User,1).deleted_at is None and db.query(TeacherClassAssignment).count()==1

def admin(db,id=3):
    item=User(id=id,school_id=1,login=f'admin{id}',full_name='Демо администратор',role=UserRole.SCHOOL_ADMIN,
              is_active=True,must_change_password=False,hashed_password=get_password_hash(PASSWORD))
    db.add(item);db.commit();return item

def test_last_admin_requires_replacement_not_a_support_only_dead_end(db):
    item=admin(db)
    assert not service(db,'cloud').info(item)['can_delete']
    with pytest.raises(ConflictError) as exc:service(db,'cloud').delete(item,PASSWORD,'УДАЛИТЬ')
    assert exc.value.code=='last_administrator'
    admin(db,4)
    service(db,'cloud').delete(item,PASSWORD,'УДАЛИТЬ')
    assert db.get(User,3).deleted_at is not None and db.get(User,4).is_active

def test_local_admin_cannot_delete_only_the_mirror(db):
    item=admin(db)
    assert service(db).info(item)['authority']=='central'
    with pytest.raises(ConflictError) as exc:service(db).delete(item,PASSWORD,'УДАЛИТЬ')
    assert exc.value.code=='central_account_required' and item.deleted_at is None

def test_commit_failure_rolls_back_all_erasure(db,monkeypatch):
    repo=AccountDeletionRepository(db)
    monkeypatch.setattr(repo,'commit',lambda:(_ for _ in ()).throw(RuntimeError('synthetic rollback')))
    with pytest.raises(RuntimeError):AccountDeletionService(repo,'local').delete(db.get(User,1),PASSWORD,'УДАЛИТЬ')
    assert db.get(User,1).login=='synthetic.teacher'
    assert db.query(TeacherClassAssignment).count()==1 and db.query(TrustedDeviceSession).count()==1

def test_narrow_session_cannot_be_used_as_normal_bearer_and_revokes(db,monkeypatch):
    monkeypatch.setattr(settings,'deployment_mode','cloud')
    item=admin(db);admin(db,4)
    auth=DeletionSessionService(UserRepository(db))
    result=auth.login(item.login,PASSWORD)
    token=result['access_token']
    assert result['expires_in']==120 and verify_token(token) is None
    assert auth.authenticate(token).id==item.id
    service(db,'cloud').delete(item,PASSWORD,'УДАЛИТЬ')
    with pytest.raises(UnauthorizedError):auth.authenticate(token)

def test_narrow_session_rejects_school_role(db,monkeypatch):
    monkeypatch.setattr(settings,'deployment_mode','cloud')
    with pytest.raises(UnauthorizedError):DeletionSessionService(UserRepository(db)).login('synthetic.teacher',PASSWORD)


def test_narrow_session_cannot_be_accepted_by_local_node(db,monkeypatch):
    from app.core.exceptions import ForbiddenError
    monkeypatch.setattr(settings,'deployment_mode','cloud')
    item=admin(db)
    auth=DeletionSessionService(UserRepository(db))
    token=auth.login(item.login,PASSWORD)['access_token']
    monkeypatch.setattr(settings,'deployment_mode','local')
    with pytest.raises(ForbiddenError):auth.authenticate(token)

def test_route_rejects_targeting_someone_else(db):
    from app.api.v1.user import router
    from app.core.dependencies import get_current_user,get_account_deletion_service
    app=FastAPI();app.include_router(router,prefix='/api/v1/users')
    app.dependency_overrides[get_current_user]=lambda:db.get(User,1)
    app.dependency_overrides[get_account_deletion_service]=lambda:service(db)
    response=TestClient(app).post('/api/v1/users/delete-account',json={
        'current_password':PASSWORD,'confirmation':'УДАЛИТЬ','user_id':2})
    assert response.status_code==422 and db.get(User,2).deleted_at is None


def test_open_event_stream_stops_after_account_deletion(db,monkeypatch):
    import asyncio
    import app.api.v1.user as routes
    from sqlalchemy.orm import sessionmaker
    monkeypatch.setattr(settings,'deployment_mode','local')
    monkeypatch.setattr(routes,'SessionLocal',sessionmaker(bind=db.get_bind()))
    user=db.get(User,1)
    async def run():
        stream=routes.request_events(user).body_iterator
        assert 'event: requests' in await anext(stream)
        user.deleted_at=datetime.now(timezone.utc);user.is_active=False;db.commit()
        with pytest.raises(StopAsyncIteration):await anext(stream)
    asyncio.run(run())
