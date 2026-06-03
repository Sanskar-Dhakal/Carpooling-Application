const router = require('express').Router();
const ctrl   = require('./auth.controller');
const { authenticate } = require('../../middleware/auth.middleware');

router.post('/register', ctrl.register);
router.post('/login',    ctrl.login);
router.post('/refresh',  ctrl.refresh);
router.get ('/me',       authenticate, ctrl.getMe);

module.exports = router;
