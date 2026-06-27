const router = require('express').Router();
const ctrl = require('./rides.controller');
const { authenticate, requireDriver } = require('../../middleware/auth.middleware');

router.get('/geocode', authenticate, ctrl.geocode);
router.get('/search', authenticate, ctrl.searchRides);
router.get('/my', authenticate, requireDriver, ctrl.getMyRides);
router.post('/', authenticate, requireDriver, ctrl.createRide);
router.get('/:id', authenticate, ctrl.getRide);
router.patch('/:id/status', authenticate, requireDriver, ctrl.updateStatus);

module.exports = router;

// M7: GPS history for completed trip replay
const pool = require('../../config/database');
router.get('/:id/gps-history', authenticate, async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      `SELECT g.lat, g.lng, g.recorded_at
       FROM gps_locations g
       JOIN bookings b ON b.id = g.booking_id
       WHERE b.ride_id = $1
       ORDER BY g.recorded_at ASC`,
      [req.params.id],
    );
    res.json({ history: rows });
  } catch (e) { next(e); }
});
