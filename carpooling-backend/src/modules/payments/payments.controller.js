const service = require('./payments.service');

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

const withdrawals = wrap(async (req, res) => {
  res.json({ withdrawals: await service.listWithdrawalRequests() });
});

module.exports = {
  wallet,
  topUp,
  withdrawal,
  adminCredit,
  updateQr,
  withdrawals,
};
