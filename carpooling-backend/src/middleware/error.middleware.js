const errorHandler = (err, req, res, next) => {
  console.error('❌', err.message);
  if (err.code === '23505') return res.status(409).json({ message: 'Already exists' });
  if (err.code === '23503') return res.status(400).json({ message: 'Reference not found' });
  res.status(err.status || 500).json({ message: err.message || 'Server error' });
};

const notFound = (req, res) =>
  res.status(404).json({ message: `${req.originalUrl} not found` });

module.exports = { errorHandler, notFound };
