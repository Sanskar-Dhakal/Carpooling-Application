const router = require('express').Router();
const ctrl   = require('./auth.controller');
const { authenticate } = require('../../middleware/auth.middleware');
const upload = require('../../middleware/upload.middleware');

router.post('/register',          upload.single('document'), ctrl.register);
router.post('/login',             ctrl.login);
router.post('/refresh',           ctrl.refresh);
router.get ('/me',                authenticate, ctrl.getMe);

// Email verification
router.post('/send-verification', ctrl.sendVerification);         // resend link
router.get ('/verify-email',      ctrl.verifyEmail);              // link click (browser)
router.get ('/check-verified',    authenticate, ctrl.checkVerified); // Flutter polls this

module.exports = router;
