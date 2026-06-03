const pool = require('../../config/database');
const { settleWalletBookingsForRide } = require('../bookings/bookings.service');

const OSRM_URL = process.env.OSRM_URL || 'https://router.project-osrm.org';
const NOMINATIM_URL = process.env.NOMINATIM_URL || 'https://nominatim.openstreetmap.org';
const NOMINATIM_EMAIL = process.env.NOMINATIM_EMAIL || 'dev@vroomsquad.local';

const toNum = (value) => {
  const n = Number(value);
  return Number.isFinite(n) ? n : null;
};

const haversineMeters = (a, b) => {
  const r = 6371000;
  const lat1 = a.lat * Math.PI / 180;
  const lat2 = b.lat * Math.PI / 180;
  const dLat = (b.lat - a.lat) * Math.PI / 180;
  const dLng = (b.lng - a.lng) * Math.PI / 180;
  const x = Math.sin(dLat / 2) ** 2
    + Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLng / 2) ** 2;
  return 2 * r * Math.atan2(Math.sqrt(x), Math.sqrt(1 - x));
};

const fallbackRoute = (coordinates) => {
  const points = coordinates.map(([lng, lat]) => ({ lat, lng }));
  let distance = 0;
  for (let i = 1; i < points.length; i += 1) {
    distance += haversineMeters(points[i - 1], points[i]);
  }
  return {
    distance: Math.round(distance),
    duration: Math.round(distance / 12),
    geometry: points,
  };
};

const getOsrmRoute = async (coordinates) => {
  const coordPath = coordinates.map(([lng, lat]) => `${lng},${lat}`).join(';');
  const url = `${OSRM_URL}/route/v1/driving/${coordPath}?overview=full&geometries=geojson`;

  try {
    const res = await fetch(url);
    if (!res.ok) return fallbackRoute(coordinates);
    const data = await res.json();
    const route = data.routes?.[0];
    if (!route) return fallbackRoute(coordinates);

    return {
      distance: Math.round(route.distance || 0),
      duration: Math.round(route.duration || 0),
      geometry: route.geometry.coordinates.map(([lng, lat]) => ({ lat, lng })),
    };
  } catch (_) {
    return fallbackRoute(coordinates);
  }
};

const geocode = async (query) => {
  if (!query || query.trim().length < 2) {
    throw { status: 400, message: 'Search query must be at least 2 characters' };
  }

  const params = new URLSearchParams({
    q: query,
    format: 'json',
    addressdetails: '1',
    limit: '8',
    email: NOMINATIM_EMAIL,
  });

  const res = await fetch(`${NOMINATIM_URL}/search?${params}`, {
    headers: { 'User-Agent': 'VroomSquad/1.0' },
  });
  if (!res.ok) throw { status: 502, message: 'Geocoding service unavailable' };

  const data = await res.json();
  return data.map((item) => ({
    label: item.display_name,
    lat: Number(item.lat),
    lng: Number(item.lon),
  }));
};

const rowToRide = (row) => ({
  id: row.id,
  driverId: row.driver_id,
  driver: row.driver_name ? {
    id: row.driver_id,
    name: row.driver_name,
    phone: row.driver_phone,
    rating: Number(row.driver_rating) || 0,
    profilePhotoUrl: row.driver_profile_photo_url || null,
  } : null,
  originAddress: row.origin_address,
  origin: { lat: Number(row.origin_lat), lng: Number(row.origin_lng) },
  destinationAddress: row.destination_address,
  destination: { lat: Number(row.destination_lat), lng: Number(row.destination_lng) },
  route: row.route_polyline ? JSON.parse(row.route_polyline) : [],
  distanceMeters: Number(row.route_distance_m) || 0,
  durationSeconds: Number(row.route_duration_s) || 0,
  departureTime: row.departure_time,
  seatsTotal: Number(row.seats_total),
  seatsAvailable: Number(row.seats_available),
  pricePerSeat: Number(row.price_per_seat),
  preferences: row.preferences || {},
  status: row.status,
  match: row.detour_score === undefined ? null : {
    detourScore: Number(row.detour_score),
    detourMeters: Number(row.detour_meters),
  },
  createdAt: row.created_at,
});

const ensureRideColumns = async () => {
  await pool.query(`
    ALTER TABLE rides
      ADD COLUMN IF NOT EXISTS route_distance_m INTEGER DEFAULT 0,
      ADD COLUMN IF NOT EXISTS route_duration_s INTEGER DEFAULT 0
  `);
};

const createRide = async (driverId, input) => {
  await ensureRideColumns();
  const originLat = toNum(input.originLat ?? input.origin?.lat);
  const originLng = toNum(input.originLng ?? input.origin?.lng);
  const destinationLat = toNum(input.destinationLat ?? input.destination?.lat);
  const destinationLng = toNum(input.destinationLng ?? input.destination?.lng);
  const seatsTotal = parseInt(input.seatsTotal ?? input.seats, 10);
  const pricePerSeat = toNum(input.pricePerSeat ?? input.price);

  if (!input.originAddress || !input.destinationAddress || originLat == null || originLng == null
    || destinationLat == null || destinationLng == null || !input.departureTime
    || !seatsTotal || pricePerSeat == null) {
    throw { status: 400, message: 'Origin, destination, departure time, seats, and price are required' };
  }

  const route = await getOsrmRoute([[originLng, originLat], [destinationLng, destinationLat]]);
  const { rows } = await pool.query(
    `INSERT INTO rides (
      driver_id, origin_address, origin_lat, origin_lng,
      destination_address, destination_lat, destination_lng,
      route_polyline, route_distance_m, route_duration_s,
      departure_time, seats_total, seats_available, price_per_seat, preferences
    )
    VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$12,$13,$14)
    RETURNING *`,
    [
      driverId,
      input.originAddress,
      originLat,
      originLng,
      input.destinationAddress,
      destinationLat,
      destinationLng,
      JSON.stringify(route.geometry),
      route.distance,
      route.duration,
      input.departureTime,
      seatsTotal,
      pricePerSeat,
      JSON.stringify(input.preferences || {}),
    ],
  );
  return rowToRide(rows[0]);
};

const rideSelect = `
  r.*,
  u.name AS driver_name,
  u.phone AS driver_phone,
  u.rating AS driver_rating,
  u.profile_photo_url AS driver_profile_photo_url
`;

const getRide = async (id) => {
  await ensureRideColumns();
  const { rows } = await pool.query(
    `SELECT ${rideSelect}
     FROM rides r JOIN users u ON u.id = r.driver_id
     WHERE r.id = $1`,
    [id],
  );
  if (!rows.length) throw { status: 404, message: 'Ride not found' };
  return rowToRide(rows[0]);
};

const getMyRides = async (driverId) => {
  await ensureRideColumns();
  const { rows } = await pool.query(
    `SELECT ${rideSelect}
     FROM rides r JOIN users u ON u.id = r.driver_id
     WHERE r.driver_id = $1
     ORDER BY r.departure_time DESC`,
    [driverId],
  );
  return rows.map(rowToRide);
};

const updateStatus = async (driverId, rideId, status) => {
  if (!['active', 'completed', 'cancelled'].includes(status)) {
    throw { status: 400, message: 'Invalid ride status' };
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const { rows } = await client.query(
      `UPDATE rides SET status = $1, updated_at = NOW()
       WHERE id = $2 AND driver_id = $3
       RETURNING *`,
      [status, rideId, driverId],
    );
    if (!rows.length) throw { status: 404, message: 'Ride not found' };
    if (status === 'completed') {
      await settleWalletBookingsForRide(rideId, client);
      await client.query(
        `UPDATE bookings
         SET status = 'completed', updated_at = NOW()
         WHERE ride_id = $1 AND status = 'confirmed'`,
        [rideId],
      );
    }
    await client.query('COMMIT');
    return rowToRide(rows[0]);
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
};

const searchRides = async (input) => {
  await ensureRideColumns();
  const origin = { lat: toNum(input.originLat), lng: toNum(input.originLng) };
  const destination = { lat: toNum(input.destinationLat), lng: toNum(input.destinationLng) };
  if (origin.lat == null || origin.lng == null || destination.lat == null || destination.lng == null) {
    throw { status: 400, message: 'originLat, originLng, destinationLat, and destinationLng are required' };
  }

  const maxDetour = toNum(input.maxDetour) ?? 0.5;
  const { rows } = await pool.query(
    `SELECT ${rideSelect}
     FROM rides r JOIN users u ON u.id = r.driver_id
     WHERE r.status = 'active'
       AND r.seats_available > 0
       AND r.departure_time >= NOW() - INTERVAL '2 hours'
     ORDER BY r.departure_time ASC
     LIMIT 30`,
  );

  const scored = [];
  for (const row of rows) {
    const rideOrigin = { lat: Number(row.origin_lat), lng: Number(row.origin_lng) };
    const rideDestination = { lat: Number(row.destination_lat), lng: Number(row.destination_lng) };
    const direct = Number(row.route_distance_m) || haversineMeters(rideOrigin, rideDestination);
    const detourRoute = await getOsrmRoute([
      [rideOrigin.lng, rideOrigin.lat],
      [origin.lng, origin.lat],
      [destination.lng, destination.lat],
      [rideDestination.lng, rideDestination.lat],
    ]);
    const detourMeters = Math.max(0, detourRoute.distance - direct);
    const detourScore = direct > 0 ? detourMeters / direct : 99;
    if (detourScore <= maxDetour) {
      scored.push(rowToRide({ ...row, detour_score: detourScore, detour_meters: detourMeters }));
    }
  }

  return scored.sort((a, b) => a.match.detourScore - b.match.detourScore);
};

module.exports = {
  geocode,
  createRide,
  getRide,
  getMyRides,
  searchRides,
  updateStatus,
};
