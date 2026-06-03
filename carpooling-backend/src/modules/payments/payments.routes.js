const router = require('express').Router();
const ctrl = require('./payments.controller');
const { authenticate, requireAdmin, requireDriver } = require('../../middleware/auth.middleware');

router.get('/wallet', authenticate, ctrl.wallet);
router.post('/wallet/top-up', authenticate, ctrl.topUp);
router.post('/wallet/withdrawals', authenticate, requireDriver, ctrl.withdrawal);
router.put('/qr', authenticate, requireDriver, ctrl.updateQr);

router.post('/admin/credit-wallet', authenticate, requireAdmin, ctrl.adminCredit);
router.get('/admin/withdrawals', authenticate, requireAdmin, ctrl.withdrawals);

module.exports = router;
