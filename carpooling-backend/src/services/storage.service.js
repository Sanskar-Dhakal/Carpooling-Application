const { minioClient } = require('../config/minio');
const { v4: uuidv4 } = require('uuid');
const path = require('path');

/**
 * Upload a file buffer to MinIO.
 * @param {string} bucket  - e.g. 'profile-photos'
 * @param {Buffer} buffer  - file bytes
 * @param {string} originalName - original filename (used for extension)
 * @param {string} mimeType
 * @returns {Promise<string>} the stored object key
 */
const uploadFile = async (bucket, buffer, originalName, mimeType) => {
  const ext = path.extname(originalName || '').toLowerCase() || '.bin';
  const key = `${uuidv4()}${ext}`;
  await minioClient.putObject(bucket, key, buffer, buffer.length, {
    'Content-Type': mimeType || 'application/octet-stream',
  });
  return key;
};

/**
 * Get a pre-signed GET URL (expires in 1 hour).
 */
const getPresignedUrl = async (bucket, key) => {
  if (!key) return null;
  const url = await minioClient.presignedGetObject(bucket, key, 3600);
  const publicUrl = process.env.MINIO_PUBLIC_URL || 'http://localhost:9000';
  try {
    const internal = new URL(url);
    const external = new URL(publicUrl);
    internal.protocol = external.protocol;
    internal.host = external.host;
    return internal.toString();
  } catch (_) {
    return url;
  }
};

/**
 * Delete an object.
 */
const deleteFile = async (bucket, key) => {
  if (!key) return;
  await minioClient.removeObject(bucket, key);
};

module.exports = { uploadFile, getPresignedUrl, deleteFile };
