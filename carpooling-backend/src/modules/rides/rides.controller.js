const service = require('./rides.service');

const wrap = (fn) => async (req, res, next) => {
  try { await fn(req, res); } catch (err) { next(err); }
};

// Pass optional ?country=NP to restrict geocode results to that country
const geocode = wrap(async (req, res) => {
  res.json({ results: await service.geocode(req.query.q, req.query.country) });
});

const createRide = wrap(async (req, res) => {
  res.status(201).json({ ride: await service.createRide(req.user.id, req.body) });
});

// Pass optional ?corridorMeters=800 to tune corridor width
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

module.exports = { geocode, createRide, searchRides, getRide, getMyRides, updateStatus };
