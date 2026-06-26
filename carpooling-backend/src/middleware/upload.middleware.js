const multer = require('multer');
const path = require('path');

// Store in memory so we can pass Buffer to MinIO
const storage = multer.memoryStorage();

const upload = multer({
  storage,
  limits: { fileSize: 5 * 1024 * 1024 }, // 5 MB
  fileFilter: (_req, file, cb) => {
    const ext = path.extname(file.originalname || '').toLowerCase();
    const looksLikeImage = ['.jpg', '.jpeg', '.png', '.webp', '.gif'].includes(ext);
    if (file.mimetype.startsWith('image/') || looksLikeImage) {
      cb(null, true);
    } else {
      cb(new Error('Only image files are allowed'));
    }
  },
});

module.exports = upload;
