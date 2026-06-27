const router = require('express').Router();
const ctrl = require('./payments.controller');
const { authenticate, requireAdmin, requireDriver } = require('../../middleware/auth.middleware');
const upload = require('../../middleware/upload.middleware');

router.get('/wallet', authenticate, ctrl.wallet);
router.post('/wallet/top-up', authenticate, ctrl.topUp);
router.post('/wallet/withdrawals', authenticate, ctrl.withdrawal);
router.put('/qr', authenticate, requireDriver, ctrl.updateQr);
router.post('/qr/image', authenticate, requireDriver, upload.single('qrImage'), ctrl.uploadQrImage);

router.post('/admin/credit-wallet', authenticate, requireAdmin, ctrl.adminCredit);
router.get('/admin/withdrawals', authenticate, requireAdmin, ctrl.withdrawals);
router.put('/admin/withdrawals/:id/complete', authenticate, requireAdmin, ctrl.completeWithdrawal);
router.put('/admin/withdrawals/:id/reject', authenticate, requireAdmin, ctrl.rejectWithdrawal);

module.exports = router;
