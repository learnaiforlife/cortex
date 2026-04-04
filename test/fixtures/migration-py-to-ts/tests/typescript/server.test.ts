// Tests for the TypeScript API implementation
import { describe, it, expect } from 'vitest';
import request from 'supertest';
import app from '../../src/typescript/server';

describe('Data API (TypeScript)', () => {
  it('health check returns healthy status and version', async () => {
    const res = await request(app).get('/api/health');
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ status: 'healthy', version: '2.1.0' });
  });

  it('returns empty list when no datasets exist', async () => {
    const res = await request(app).get('/api/datasets');
    expect(res.status).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
  });

  it('creates a dataset with valid input', async () => {
    const res = await request(app)
      .post('/api/datasets')
      .send({ name: 'test-ds', source_url: 'https://example.com/data.csv', format: 'csv' });
    expect(res.status).toBe(201);
    expect(res.body).toMatchObject({
      name: 'test-ds',
      source_url: 'https://example.com/data.csv',
      format: 'csv',
      status: 'pending',
    });
    expect(res.body.id).toBeDefined();
  });

  it('rejects invalid dataset input', async () => {
    const res = await request(app)
      .post('/api/datasets')
      .send({ name: 'bad-ds' }); // missing source_url
    expect(res.status).toBe(400);
  });
});

describe('Config loading', () => {
  it('loads default config values', async () => {
    const { config } = await import('../../src/typescript/config');
    expect(config.port).toBe(3000);
    expect(config.api.version).toBe('2.1.0');
    expect(config.database.host).toBe('localhost');
  });
});
