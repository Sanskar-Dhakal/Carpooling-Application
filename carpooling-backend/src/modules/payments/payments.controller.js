const service = require('./payments.service');
const storageService = require('../../services/storage.service');

const wrap = (fn) => async (req, res, next) => {
  try {
    await fn(req, res);
  } catch (err) {
    next(err);
  }
};

const wallet = wrap(async (req, res) => {
  res.json({
    wallet: await service.getWallet(req.user.id),
    transactions: await service.getTransactions(req.user.id),
  });
});

const topUp = wrap(async (req, res) => {
  res.json({ wallet: await service.topUpWallet(req.user.id, req.body.amount) });
});

const withdrawal = wrap(async (req, res) => {
  res.status(201).json({ wallet: await service.requestWithdrawal(req.user.id, req.body.amount) });
});

const adminCredit = wrap(async (req, res) => {
  res.json({ wallet: await service.adminCreditWallet(req.body) });
});

const updateQr = wrap(async (req, res) => {
  res.json({ qr: await service.updateDriverQr(req.user.id, req.body) });
});

const uploadQrImage = wrap(async (req, res) => {
  if (!req.file) return res.status(400).json({ message: 'No file uploaded' });
  const key = await storageService.uploadFile('qr-payments', req.file.buffer, req.file.originalname, req.file.mimetype);
  const url = await storageService.getPresignedUrl('qr-payments', key);
  res.json({ url });
});

const withdrawals = wrap(async (req, res) => {
  res.json({ withdrawals: await service.listWithdrawalRequests() });
});

const completeWithdrawal = wrap(async (req, res) => {
  res.json(await service.completeWithdrawalRequest(req.params.id));
});

const rejectWithdrawal = wrap(async (req, res) => {
  res.json(await service.rejectWithdrawalRequest(req.params.id, req.body?.reason));
});

module.exports = {
  wallet,
  topUp,
  withdrawal,
  adminCredit,
  updateQr,
  uploadQrImage,
  withdrawals,
  completeWithdrawal,
  rejectWithdrawal,
};
