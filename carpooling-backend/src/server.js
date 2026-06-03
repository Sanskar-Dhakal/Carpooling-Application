require('dotenv').config();
const http        = require('http');
const { Server }  = require('socket.io');
const app         = require('./app');
const setupSocket = require('./socket/socket');

const PORT   = process.env.PORT || 3000;
const server = http.createServer(app);

const io = new Server(server, {
  cors: { origin: '*', methods: ['GET','POST'] },
});
setupSocket(io);

server.listen(PORT, () => {
  console.log('\n🚗 ═══════════════════════════════════════');
  console.log(`🚗  Vroom Squad API  →  http://localhost:${PORT}`);
  console.log('🚗 ═══════════════════════════════════════');
  console.log(`📦  ENV      : ${process.env.NODE_ENV}`);
  console.log(`🗄️   DB       : ${process.env.DB_HOST}:${process.env.DB_PORT}/${process.env.DB_NAME}`);
  console.log(`⚡  Redis    : ${process.env.REDIS_HOST}:${process.env.REDIS_PORT}`);
  console.log('\n📡 Endpoints ready:');
  console.log(`   GET  /health`);
  console.log(`   POST /api/v1/auth/register`);
  console.log(`   POST /api/v1/auth/login`);
  console.log(`   POST /api/v1/auth/refresh`);
  console.log(`   GET  /api/v1/auth/me  (needs JWT)\n`);
});

process.on('SIGTERM', () => server.close(() => process.exit(0)));
