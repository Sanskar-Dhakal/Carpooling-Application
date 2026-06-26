const router = require('express').Router();
const ctrl = require('./bookings.controller');
const { authenticate, requireDriver } = require('../../middleware/auth.middleware');

// Booking CRUD
router.post('/', authenticate, ctrl.createBooking);
router.get('/my', authenticate, ctrl.myBookings);
router.get('/driver', authenticate, requireDriver, ctrl.driverBookings);

// Driver accept / reject
router.put('/:id/confirm', authenticate, requireDriver, ctrl.confirmBooking);
router.put('/:id/reject', authenticate, requireDriver, ctrl.rejectBooking);
router.patch('/:id/status', authenticate, requireDriver, ctrl.updateStatus); // legacy alias

// Passenger cancel
router.put('/:id/cancel', authenticate, ctrl.cancelBooking);

// Payment actions
router.post('/:id/authorize-wallet', authenticate, ctrl.authorizeWalletPayment);
router.put('/:id/payment-sent', authenticate, ctrl.submitQrPayment);       // QR: passenger sent
router.put('/:id/cash-received', authenticate, requireDriver, ctrl.confirmCashReceived); // Cash: driver confirms
router.post('/:id/confirm-payment', authenticate, requireDriver, ctrl.confirmPayment);  // QR: driver confirms (alias)

module.exports = router;
