const router = require('express').Router();
const ctrl = require('./vehicles.controller');
const { authenticate, requireDriver } = require('../../middleware/auth.middleware');
const upload = require('../../middleware/upload.middleware');

router.get('/mine', authenticate, requireDriver, ctrl.list);
router.post('/', authenticate, requireDriver, upload.single('photo'), ctrl.add);
router.put('/:id', authenticate, requireDriver, upload.single('photo'), ctrl.update);
router.delete('/:id', authenticate, requireDriver, ctrl.remove);

module.exports = router;
