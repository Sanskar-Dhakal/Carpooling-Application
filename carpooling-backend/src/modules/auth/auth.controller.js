const svc = require('./auth.service');

const register = async (req, res, next) => {
  try {
    const { name, email, phone, password, role } = req.body;
    if (!name || !email || !password)
      return res.status(400).json({ message: 'name, email and password are required' });
    if (!['driver','passenger','both'].includes(role))
      return res.status(400).json({ message: 'role must be driver, passenger or both' });
    const data = await svc.register({ name, email, phone, password, role });
    res.status(201).json(data);
  } catch (e) { next(e); }
};

const login = async (req, res, next) => {
  try {
    const { email, password } = req.body;
    if (!email || !password)
      return res.status(400).json({ message: 'email and password are required' });
    const data = await svc.login({ email, password });
    res.status(200).json(data);
  } catch (e) { next(e); }
};

const refresh = async (req, res, next) => {
  try {
    const { refreshToken } = req.body;
    if (!refreshToken)
      return res.status(400).json({ message: 'refreshToken required' });
    const data = await svc.refresh(refreshToken);
    res.status(200).json(data);
  } catch (e) { next(e); }
};

const getMe = async (req, res, next) => {
  try {
    const user = await svc.getMe(req.user.id);
    res.json({ user });
  } catch (e) { next(e); }
};

module.exports = { register, login, refresh, getMe };
