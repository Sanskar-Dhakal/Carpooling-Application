const service = require('./vehicles.service');
const storageService = require('../../services/storage.service');

const wrap = (fn) => async (req, res, next) => {
  try { await fn(req, res); } catch (err) { next(err); }
};

const list = wrap(async (req, res) => {
  res.json({ vehicles: await service.getDriverVehicles(req.user.id) });
});

const add = wrap(async (req, res) => {
  let photoUrl = null;
  if (req.file) {
    const key = await storageService.uploadFile(
      'profile-photos', req.file.buffer, req.file.originalname, req.file.mimetype
    );
    photoUrl = await storageService.getPresignedUrl('profile-photos', key);
  }
  const vehicle = await service.addVehicle(req.user.id, { ...req.body, photoUrl });
  res.status(201).json({ vehicle });
});

const update = wrap(async (req, res) => {
  let photoUrl = req.body.photoUrl || null;
  if (req.file) {
    const key = await storageService.uploadFile(
      'profile-photos', req.file.buffer, req.file.originalname, req.file.mimetype
    );
    photoUrl = await storageService.getPresignedUrl('profile-photos', key);
  }
  const vehicle = await service.updateVehicle(req.user.id, req.params.id, { ...req.body, photoUrl });
  res.json({ vehicle });
});

const remove = wrap(async (req, res) => {
  res.json(await service.deleteVehicle(req.user.id, req.params.id));
});

module.exports = { list, add, update, remove };
