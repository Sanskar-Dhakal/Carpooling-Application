const errorHandler = (err, req, res, next) => {
  console.error('❌', err.message);
  if (err.code === '23505') return res.status(409).json({ message: 'Already exists' });
  if (err.code === '23503') return res.status(400).json({ message: 'Reference not found' });
  const body = { message: err.message || 'Server error' };
  if (err.verification_status) body.verification_status = err.verification_status;
  if (err.token) body.token = err.token;
  res.status(err.status || 500).json(body);
};

const notFound = (req, res) =>
  res.status(404).json({ message: `${req.originalUrl} not found` });

module.exports = { errorHandler, notFound };
