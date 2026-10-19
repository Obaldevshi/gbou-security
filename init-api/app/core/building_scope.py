"""Read-only database boundary check. Never repair by hiding/deleting records."""
from sqlalchemy import text


def validate_building_database(connection, building_id, school_id=None):
    buildings = connection.execute(text('SELECT id,school_id FROM school_buildings ORDER BY id')).all()
    if len(buildings) != 1 or buildings[0][0] != building_id:
        raise ValueError('Database must contain exactly its own building; explicit migration required')
    owner = buildings[0][1]
    if school_id is not None and owner != school_id:
        raise ValueError('Database school scope mismatch')
    if connection.execute(text('SELECT id FROM schools ORDER BY id')).all() != [(owner,)]:
        raise ValueError('Database must contain exactly its own school')
    params = {'school': owner, 'building': building_id}
    checks = [
        "SELECT 1 FROM users WHERE school_id IS NULL OR school_id<>:school OR role='super_admin' OR (building_id IS NOT NULL AND building_id<>:building) OR (building_id IS NULL AND role<>'school_admin') LIMIT 1",
        'SELECT 1 FROM school_classes WHERE school_id<>:school OR building_id<>:building LIMIT 1',
        'SELECT 1 FROM students s LEFT JOIN school_classes c ON c.id=s.class_id WHERE s.school_id<>:school OR c.id IS NULL OR c.school_id<>:school OR c.building_id<>:building LIMIT 1',
        'SELECT 1 FROM exit_requests WHERE school_id<>:school OR building_id<>:building LIMIT 1',
        'SELECT 1 FROM audit_logs WHERE school_id IS NOT NULL AND school_id<>:school LIMIT 1',
    ]
    if any(connection.execute(text(query), params).first() is not None for query in checks):
        raise ValueError('Database contains out-of-building records; not modified')
    if connection.dialect.name == 'sqlite' and connection.exec_driver_sql('PRAGMA foreign_key_check').first():
        raise ValueError('Database contains broken foreign-key references; not modified')
