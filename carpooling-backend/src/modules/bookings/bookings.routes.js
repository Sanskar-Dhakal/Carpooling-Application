const router = require('express').Router();
const ctrl = require('./bookings.controller');
const { authenticate, requireDriver } = require('../../middleware/auth.middleware');

router.post('/', authenticate, ctrl.createBooking);
router.get('/my', authenticate, ctrl.myBookings);
router.get('/driver', authenticate, requireDriver, ctrl.driverBookings);
router.patch('/:id/status', authenticate, requireDriver, ctrl.updateStatus);
router.post('/:id/authorize-wallet', authenticate, ctrl.authorizeWalletPayment);
router.post('/:id/qr-payment', authenticate, ctrl.submitQrPayment);
router.post('/:id/confirm-payment', authenticate, requireDriver, ctrl.confirmPayment);

module.exports = router;
