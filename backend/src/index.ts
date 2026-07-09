import Fastify from 'fastify';
import cors from '@fastify/cors';
import multipart from '@fastify/multipart';
import { config } from './config.js';
import { registerHealthRoute } from './routes/health.js';
import { registerDiagnoseRoute } from './routes/diagnose.js';
import { registerDebugRoute } from './routes/debug.js';
import { registerSearchRoute } from './routes/search.js';
import { registerDecideRoute } from './routes/decide.js';
import { registerPlanWeekRoute } from './routes/plan-week.js';
import { registerTranscribeRoute } from './routes/transcribe.js';
import { registerParseUrlRoute } from './routes/parse-url.js';
import { registerTrendingRoute } from './routes/trending.js';
import { startTrendingScheduler } from './services/trending-scheduler.js';

async function main(): Promise<void> {
  const app = Fastify({
    bodyLimit: 15 * 1024 * 1024, // 15 MB — base64 product photos in /api/decide JSON bodies
    logger: {
      level: 'info',
      transport:
        process.env.NODE_ENV !== 'production'
          ? {
              target: 'pino-pretty',
              options: {
                translateTime: 'HH:MM:ss',
                ignore: 'pid,hostname',
              },
            }
          : undefined,
    },
  });

  await app.register(cors, {
    origin: true, // accept any origin for mobile clients
    methods: ['GET', 'POST', 'OPTIONS'],
  });

  await app.register(multipart, {
    limits: {
      fileSize: 25 * 1024 * 1024, // 25 MB — Whisper max
    },
  });

  // Request logging — logs every incoming request with a short summary
  app.addHook('onRequest', async (req) => {
    req.log.info(
      { method: req.method, url: req.url, ua: req.headers['user-agent'] },
      '→ incoming',
    );
  });

  // Response logging — logs status and timing
  app.addHook('onResponse', async (req, reply) => {
    req.log.info(
      {
        method: req.method,
        url: req.url,
        status: reply.statusCode,
        durationMs: Math.round(reply.elapsedTime),
      },
      '← response',
    );
  });

  // Global error handler — ensures we always return a readable JSON body
  app.setErrorHandler((err, req, reply) => {
    req.log.error({ err }, 'unhandled error');
    reply.status(500).send({
      error: 'Internal server error',
      message: err instanceof Error ? err.message : String(err),
    });
  });

  await registerHealthRoute(app);
  await registerDiagnoseRoute(app);
  await registerDebugRoute(app);
  await registerSearchRoute(app);
  await registerDecideRoute(app); // Gobly buying/decision engine — /api/decide
  await registerPlanWeekRoute(app);
  await registerTranscribeRoute(app);
  await registerParseUrlRoute(app);
  await registerTrendingRoute(app);

  app.get('/', async () => ({
    name: 'Gobly API',
    version: '0.2.0',
    endpoints: [
      'GET /health',
      'GET /api/diagnose',
      'POST /api/decide', // buying/decision engine
      'POST /api/search',
      'POST /api/plan-week',
    ],
  }));

  try {
    await app.listen({ port: config.port, host: '0.0.0.0' });
    app.log.info(`Recimo backend listening on :${config.port}`);
    // Kick off the weekly trending-recipe scheduler (runs Sundays 03:00 UTC).
    startTrendingScheduler(app.log);
  } catch (err) {
    app.log.error({ err }, 'Failed to start server');
    process.exit(1);
  }
}

main().catch((err) => {
  console.error('Fatal startup error:', err);
  process.exit(1);
});
