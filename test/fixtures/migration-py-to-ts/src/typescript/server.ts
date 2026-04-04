// MIGRATED: TypeScript implementation of the Data Processing API
// Replaces src/python/main.py
import express from 'express';
import { z } from 'zod';

const app = express();
app.use(express.json());

const DatasetCreate = z.object({
  name: z.string(),
  source_url: z.string().url(),
  format: z.enum(['csv', 'json', 'parquet']).default('csv'),
});

interface Dataset {
  id: string;
  name: string;
  source_url: string;
  format: string;
  status: 'pending' | 'processing' | 'complete' | 'failed';
}

// TODO migrate: replace with Drizzle ORM when schema.ts is ready
const datasets = new Map<string, Dataset>();

app.get('/api/health', (_req, res) => {
  res.json({ status: 'healthy', version: '2.1.0' });
});

app.get('/api/datasets', (_req, res) => {
  res.json(Array.from(datasets.values()));
});

app.post('/api/datasets', (req, res) => {
  const parsed = DatasetCreate.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ detail: parsed.error.message });
    return;
  }
  const id = crypto.randomUUID();
  const dataset: Dataset = { id, ...parsed.data, status: 'pending' };
  datasets.set(id, dataset);
  res.status(201).json(dataset);
});

export default app;
