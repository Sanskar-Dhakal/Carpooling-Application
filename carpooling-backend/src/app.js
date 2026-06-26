const express = require('express');
const cors = require('cors');
const { errorHandler } = require('./middleware/error.middleware');

const authRoutes     = require('./modules/auth/auth.routes');
const userRoutes     = require('./modules/users/users.routes');
const rideRoutes     = require('./modules/rides/rides.routes');
const bookingRoutes  = require('./modules/bookings/bookings.routes');
const paymentRoutes  = require('./modules/payments/payments.routes');
const vehicleRoutes  = require('./modules/vehicles/vehicles.routes');
const messageRoutes  = require('./modules/messages/messages.routes');   // M7
const reviewRoutes   = require('./modules/reviews/reviews.routes');     // M8
const adminRoutes    = require('./modules/admin/admin.routes');         // M8

const app = express();

app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

app.use('/api/v1/auth',     authRoutes);
app.use('/api/v1/users',    userRoutes);
app.use('/api/v1/rides',    rideRoutes);
app.use('/api/v1/bookings', bookingRoutes);
app.use('/api/v1/payments', paymentRoutes);
app.use('/api/v1/vehicles', vehicleRoutes);
app.use('/api/v1/messages', messageRoutes);   // M7
app.use('/api/v1',          reviewRoutes);    // M8 — /bookings/:id/review + /users/:id/reviews
app.use('/api/v1/admin',    adminRoutes);     // M8

app.use(errorHandler);

module.exports = app;
