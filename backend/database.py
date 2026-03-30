import os
from datetime import datetime, date

from peewee import (
    SqliteDatabase,
    Model,
    CharField,
    DateTimeField,
    DateField,
    FloatField,
)

DB_PATH = os.environ.get("DB_PATH", "./data/memoridef.db")
os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)

db = SqliteDatabase(DB_PATH)


class BaseModel(Model):
    class Meta:
        database = db


class Image(BaseModel):
    author = CharField()
    upload_date = DateTimeField(default=datetime.now)
    date = DateField(null=True)
    path = CharField()
    location_x = FloatField(null=True)
    location_y = FloatField(null=True)


db.connect()
db.create_tables([Image])
