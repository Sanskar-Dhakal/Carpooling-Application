const service = require('./rides.service');

const wrap = (fn) => async (req, res, next) => {
  try {
    await fn(req, res);
  } catch (err) {
    next(err);
  }
};

const geocode = wrap(async (req, res) => {
  res.json({ results: await service.geocode(req.query.q) });
});

const createRide = wrap(async (req, res) => {
  const ride = await service.createRide(req.user.id, req.body);
  res.status(201).json({ ride });
});

const searchRides = wrap(async (req, res) => {
  res.json({ rides: await service.searchRides(req.query) });
});

const getRide = wrap(async (req, res) => {
  res.json({ ride: await service.getRide(req.params.id) });
});

const getMyRides = wrap(async (req, res) => {
  res.json({ rides: await service.getMyRides(req.user.id) });
});

const updateStatus = wrap(async (req, res) => {
  res.json({ ride: await service.updateStatus(req.user.id, req.params.id, req.body.status) });
});

module.exports = {
  geocode,
  createRide,
  searchRides,
  getRide,
  getMyRides,
  updateStatus,
};
