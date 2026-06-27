const pool = require('../../config/database');

const rowToVehicle = (row) => ({
  id: row.id,
  driverId: row.driver_id,
  vehicleNumber: row.vehicle_number,
  type: row.type,
  capacity: Number(row.capacity),
  name: row.name,
  photoUrl: row.photo_url || null,
  createdAt: row.created_at,
});

const getDriverVehicles = async (driverId) => {
  const { rows } = await pool.query(
    'SELECT * FROM vehicles WHERE driver_id = $1 ORDER BY created_at DESC',
    [driverId]
  );
  return rows.map(rowToVehicle);
};

const addVehicle = async (driverId, { vehicleNumber, type, capacity, name, photoUrl }) => {
  if (!vehicleNumber || !type || !capacity) {
    throw { status: 400, message: 'vehicleNumber, type, and capacity are required' };
  }
  if (!type || typeof type !== 'string' || type.trim().length === 0) {
    throw { status: 400, message: 'type is required and must be a non-empty string' };
  }
  if (type.trim().length > 100) {
    throw { status: 400, message: 'type must be 100 characters or less' };
  }
  const cap = parseInt(capacity, 10);
  if (!Number.isFinite(cap) || cap < 1 || cap > 20) {
    throw { status: 400, message: 'capacity must be between 1 and 20' };
  }

  const { rows } = await pool.query(
    `INSERT INTO vehicles (driver_id, vehicle_number, type, capacity, name, photo_url)
     VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
    [driverId, vehicleNumber.toUpperCase(), type.trim(), cap, name ? name.trim() : null, photoUrl || null]
  );
  return rowToVehicle(rows[0]);
};

const updateVehicle = async (driverId, vehicleId, updates) => {
  const { rows: existing } = await pool.query(
    'SELECT * FROM vehicles WHERE id = $1 AND driver_id = $2',
    [vehicleId, driverId]
  );
  if (!existing.length) throw { status: 404, message: 'Vehicle not found' };

  const { vehicleNumber, type, capacity, name, photoUrl } = updates;
  const { rows } = await pool.query(
    `UPDATE vehicles
     SET vehicle_number = COALESCE($1, vehicle_number),
         type           = COALESCE($2, type),
         capacity       = COALESCE($3, capacity),
         name           = COALESCE($4, name),
         photo_url      = COALESCE($5, photo_url),
         updated_at     = NOW()
     WHERE id = $6 AND driver_id = $7
     RETURNING *`,
    [
      vehicleNumber ? vehicleNumber.toUpperCase() : null,
      type || null,
      capacity ? parseInt(capacity, 10) : null,
      name || null,
      photoUrl || null,
      vehicleId,
      driverId,
    ]
  );
  return rowToVehicle(rows[0]);
};

const deleteVehicle = async (driverId, vehicleId) => {
  const { rowCount } = await pool.query(
    'DELETE FROM vehicles WHERE id = $1 AND driver_id = $2',
    [vehicleId, driverId]
  );
  if (!rowCount) throw { status: 404, message: 'Vehicle not found' };
  return { message: 'Vehicle deleted' };
};

module.exports = { getDriverVehicles, addVehicle, updateVehicle, deleteVehicle };
