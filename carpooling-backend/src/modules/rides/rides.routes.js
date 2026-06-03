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
