"""SQLAlchemy models — will be replaced by Drizzle ORM schemas"""
# TODO migrate: convert to Drizzle ORM (see src/typescript/schema.ts)
from sqlalchemy import Column, String, DateTime, Enum as SAEnum
from sqlalchemy.ext.declarative import declarative_base
from datetime import datetime

Base = declarative_base()


class DatasetModel(Base):
    __tablename__ = "datasets"

    id = Column(String, primary_key=True)
    name = Column(String, nullable=False)
    source_url = Column(String, nullable=False)
    format = Column(SAEnum("csv", "json", "parquet", name="dataset_format"), default="csv")
    status = Column(SAEnum("pending", "processing", "complete", "failed", name="dataset_status"), default="pending")
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
