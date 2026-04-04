// Application configuration for the TypeScript API
export const config = {
  port: Number(process.env.PORT ?? 3000),
  database: {
    host: process.env.DB_HOST ?? 'localhost',
    port: Number(process.env.DB_PORT ?? 5432),
    name: process.env.DB_NAME ?? 'data_api',
  },
  api: {
    version: '2.1.0',
    basePath: '/api',
  },
} as const;
