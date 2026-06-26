const service = require('./bookings.service');

const wrap = (fn) => async (req, res, next) => {
  try { await fn(req, res); } catch (err) { next(err); }
};

const createBooking = wrap(async (req, res) => {
  res.status(201).json({ booking: await service.createBooking(req.user.id, req.body) });
});

const myBookings = wrap(async (req, res) => {
  res.json({ bookings: await service.getPassengerBookings(req.user.id) });
});

const driverBookings = wrap(async (req, res) => {
  res.json({ bookings: await service.getDriverBookings(req.user.id) });
});

const updateStatus = wrap(async (req, res) => {
  const { status } = req.body;
  res.json({ booking: await service.updateBookingStatus(req.user.id, req.params.id, status) });
});

const confirmBooking = wrap(async (req, res) => {
  res.json({ booking: await service.updateBookingStatus(req.user.id, req.params.id, 'confirmed') });
});

const rejectBooking = wrap(async (req, res) => {
  res.json({ booking: await service.updateBookingStatus(req.user.id, req.params.id, 'rejected') });
});

const cancelBooking = wrap(async (req, res) => {
  // Passengers cancel their own booking
  const booking = await service.cancelPassengerBooking(req.user.id, req.params.id);
  res.json({ booking });
});

const authorizeWalletPayment = wrap(async (req, res) => {
  res.json({ booking: await service.authorizeWalletPayment(req.user.id, req.params.id, req.body.password) });
});

const submitQrPayment = wrap(async (req, res) => {
  const url = req.body.screenshotUrl || req.body.paymentScreenshotUrl || 'qr_confirmed';
  res.json({ booking: await service.submitQrPayment(req.user.id, req.params.id, url) });
});

const confirmCashReceived = wrap(async (req, res) => {
  res.json({ booking: await service.confirmPaymentReceived(req.user.id, req.params.id) });
});

const confirmPayment = wrap(async (req, res) => {
  res.json({ booking: await service.confirmPaymentReceived(req.user.id, req.params.id) });
});

module.exports = {
  createBooking, myBookings, driverBookings, updateStatus,
  confirmBooking, rejectBooking, cancelBooking,
  authorizeWalletPayment, submitQrPayment, confirmCashReceived, confirmPayment,
};
