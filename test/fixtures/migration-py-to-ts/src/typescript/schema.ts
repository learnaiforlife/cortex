// MIGRATED: Drizzle ORM schema replacing SQLAlchemy models
// Replaces src/python/models.py
import { pgTable, varchar, timestamp, pgEnum } from 'drizzle-orm/pg-core';

export const datasetFormatEnum = pgEnum('dataset_format', ['csv', 'json', 'parquet']);
export const datasetStatusEnum = pgEnum('dataset_status', ['pending', 'processing', 'complete', 'failed']);

export const datasets = pgTable('datasets', {
  id: varchar('id', { length: 36 }).primaryKey(),
  name: varchar('name', { length: 255 }).notNull(),
  sourceUrl: varchar('source_url', { length: 1024 }).notNull(),
  format: datasetFormatEnum('format').default('csv'),
  status: datasetStatusEnum('status').default('pending'),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow(),
});
