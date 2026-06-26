const svc = require('./auth.service');

const isValidNepalMobile = (phone) => /^(97|98)\d{8}$/.test(String(phone || ''));

const register = async (req, res, next) => {
  try {
    const { name, email, phone, password, role } = req.body;
    if (!name || !email || !password)
      return res.status(400).json({ message: 'name, email and password are required' });
    if (!isValidNepalMobile(phone))
      return res.status(400).json({ message: 'A valid Nepal mobile number is required' });
    if (!['driver', 'passenger', 'both'].includes(role))
      return res.status(400).json({ message: 'role must be driver, passenger or both' });
    if (!req.file)
      return res.status(400).json({ message: 'A verification document is required' });
    const data = await svc.register({ name, email, phone, password, role, document: req.file });
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

// Resend verification email (Flutter calls this if user didn't get it)
const sendVerification = async (req, res, next) => {
  try {
    const { userId, email } = req.body;
    if (!userId || !email)
      return res.status(400).json({ message: 'userId and email are required' });
    await svc.sendVerificationEmail(userId, email);
    res.json({ message: 'Verification email sent.' });
  } catch (e) { next(e); }
};

// Called when user clicks the link in their email (opens in browser)
const verifyEmail = async (req, res, next) => {
  try {
    await svc.verifyEmailToken(req.query.token);
    res.send(`
      <html>
        <body style="font-family:sans-serif;text-align:center;padding:60px;background:#f8f8f6">
          <div style="max-width:400px;margin:0 auto;background:#fff;padding:40px;border-radius:16px;box-shadow:0 2px 16px rgba(0,0,0,0.08)">
            <div style="font-size:48px">✅</div>
            <h2 style="color:#1A3C5E;margin:16px 0 8px">Email Verified!</h2>
            <p style="color:#666">Your email has been verified successfully.<br>You can now close this tab and log in to the app.</p>
          </div>
        </body>
      </html>
    `);
  } catch (e) { next(e); }
};

// Flutter polls this to check if user has clicked the link yet
const checkVerified = async (req, res, next) => {
  try {
    const verified = await svc.checkVerified(req.user.id);
    res.json({ is_verified: verified });
  } catch (e) { next(e); }
};

module.exports = { register, login, refresh, getMe, sendVerification, verifyEmail, checkVerified };
