const service = require('./bookings.service');

const wrap = (fn) => async (req, res, next) => {
  try {
    await fn(req, res);
  } catch (err) {
    next(err);
  }
};

const createBooking = wrap(async (req, res) => {
  const booking = await service.createBooking(req.user.id, req.body);
  res.status(201).json({ booking });
});

const myBookings = wrap(async (req, res) => {
  res.json({ bookings: await service.getPassengerBookings(req.user.id) });
});

const driverBookings = wrap(async (req, res) => {
  res.json({ bookings: await service.getDriverBookings(req.user.id) });
});

const updateStatus = wrap(async (req, res) => {
  res.json({ booking: await service.updateBookingStatus(req.user.id, req.params.id, req.body.status) });
});

const submitQrPayment = wrap(async (req, res) => {
  res.json({ booking: await service.submitQrPayment(req.user.id, req.params.id, req.body.screenshotUrl) });
});

const authorizeWalletPayment = wrap(async (req, res) => {
  res.json({ booking: await service.authorizeWalletPayment(req.user.id, req.params.id, req.body.password) });
});

const confirmPayment = wrap(async (req, res) => {
  res.json({ booking: await service.confirmPaymentReceived(req.user.id, req.params.id) });
});

module.exports = {
  createBooking,
  myBookings,
  driverBookings,
  updateStatus,
  submitQrPayment,
  authorizeWalletPayment,
  confirmPayment,
};
