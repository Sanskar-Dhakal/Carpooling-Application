require('dotenv').config();
const express    = require('express');
const cors       = require('cors');
const helmet     = require('helmet');
const morgan     = require('morgan');
const rateLimit  = require('express-rate-limit');
const { errorHandler, notFound } = require('./middleware/error.middleware');

const app = express();

app.use(helmet());
app.use(cors({ origin: '*', credentials: true }));
app.use(rateLimit({ windowMs: 60_000, max: 200 }));
app.use(express.json());
app.use(morgan('dev'));

// ── Health ────────────────────────────────────────────────
app.get('/health', (_, res) =>
  res.json({ status: 'ok', service: 'Vroom Squad API v1.0' })
);

// ── Routes ────────────────────────────────────────────────
app.use('/api/v1/auth',  require('./modules/auth/auth.routes'));
app.use('/api/v1/users', require('./modules/users/users.routes'));
app.use('/api/v1/rides', require('./modules/rides/rides.routes'));
app.use('/api/v1/bookings', require('./modules/bookings/bookings.routes'));
app.use('/api/v1/payments', require('./modules/payments/payments.routes'));

// ── Errors ────────────────────────────────────────────────
app.use(notFound);
app.use(errorHandler);

module.exports = app;
