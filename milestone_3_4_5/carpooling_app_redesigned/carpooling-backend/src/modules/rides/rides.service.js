const pool = require('../../config/database');
const {
  settleWalletBookingsForRide,
  releaseWalletReservationsForRide,
} = require('../bookings/bookings.service');
const { getJson, setJson, delPattern } = require('../../config/redis');

// ── Cache TTLs ────────────────────────────────────────────────────────────────
const GEOCODE_TTL     = 3600;  // 1 hour  — place names rarely change
const RIDE_SEARCH_TTL = 30;    // 30 s    — availability changes fast; invalidated on booking/status change

const OSRM_URL        = process.env.OSRM_URL        || 'https://router.project-osrm.org';
const NOMINATIM_URL   = process.env.NOMINATIM_URL   || 'https://nominatim.openstreetmap.org';
const NOMINATIM_EMAIL = process.env.NOMINATIM_EMAIL || 'dev@vroomsquad.local';

const toNum = (value) => {
  const n = Number(value);
  return Number.isFinite(n) ? n : null;
};

// ── Haversine: straight-line distance between two {lat,lng} points (metres) ──
const haversineMeters = (a, b) => {
  const r    = 6371000;
  const lat1 = a.lat * Math.PI / 180;
  const lat2 = b.lat * Math.PI / 180;
  const dLat = (b.lat - a.lat) * Math.PI / 180;
  const dLng = (b.lng - a.lng) * Math.PI / 180;
  const x    = Math.sin(dLat / 2) ** 2
              + Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLng / 2) ** 2;
  return 2 * r * Math.atan2(Math.sqrt(x), Math.sqrt(1 - x));
};

// ── Find the polyline point nearest to {lat,lng}. Returns {index, distMeters} ─
const nearestPolylinePoint = (polyline, point) => {
  let bestIndex = 0;
  let bestDist  = Infinity;
  for (let i = 0; i < polyline.length; i++) {
    const d = haversineMeters(polyline[i], point);
    if (d < bestDist) { bestDist = d; bestIndex = i; }
  }
  return { index: bestIndex, distMeters: bestDist };
};

const fallbackRoute = (coordinates) => {
  const points = coordinates.map(([lng, lat]) => ({ lat, lng }));
  let distance = 0;
  for (let i = 1; i < points.length; i++) {
    distance += haversineMeters(points[i - 1], points[i]);
  }
  return {
    distance: Math.round(distance),
    duration: Math.round(distance / 12),
    geometry: points,
  };
};

const polylineDistance = (polyline, startIndex, endIndex) => {
  let distance = 0;
  for (let i = startIndex + 1; i <= endIndex; i++) {
    distance += haversineMeters(polyline[i - 1], polyline[i]);
  }
  return Math.round(distance);
};

const roundMoney = (value) => Number(Number(value).toFixed(2));

const fareForDistance = (fullPrice, fullDistanceMeters, passengerDistanceMeters) => {
  const price = Number(fullPrice) || 0;
  const fullDistance = Number(fullDistanceMeters) || 0;
  const passengerDistance = Number(passengerDistanceMeters) || 0;
  if (price <= 0 || fullDistance <= 0 || passengerDistance <= 0) return 0;
  const ratio = Math.min(1, passengerDistance / fullDistance);
  return roundMoney(price * ratio);
};

const getOsrmRoute = async (coordinates) => {
  const coordPath = coordinates.map(([lng, lat]) => `${lng},${lat}`).join(';');
  const url = `${OSRM_URL}/route/v1/driving/${coordPath}?overview=full&geometries=geojson`;
  try {
    const res = await fetch(url);
    if (!res.ok) return fallbackRoute(coordinates);
    const data  = await res.json();
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

// ── Geocode — restricted to a country when countryCode is provided ────────────
// countryCode is ISO alpha-2 e.g. "NP". This is what makes map search show only
// Nepal locations when the user selected Nepal's country code during registration.
const geocode = async (query, countryCode) => {
  if (!query || query.trim().length < 2) {
    throw { status: 400, message: 'Search query must be at least 2 characters' };
  }

  // Cache key: country + normalised query
  const cacheKey = `geocode:${(countryCode || 'all').toLowerCase()}:${query.trim().toLowerCase()}`;
  const cached   = await getJson(cacheKey);
  if (cached) return cached;

  const params = new URLSearchParams({
    q:              query,
    format:         'json',
    addressdetails: '1',
    limit:          '8',
    email:          NOMINATIM_EMAIL,
  });
  if (countryCode) {
    params.set('countrycodes', countryCode.toLowerCase());
  }
  const res = await fetch(`${NOMINATIM_URL}/search?${params}`, {
    headers: { 'User-Agent': 'VroomSquad/1.0' },
  });
  if (!res.ok) throw { status: 502, message: 'Geocoding service unavailable' };
  const data = await res.json();
  const results = data.map((item) => ({
    label: item.display_name,
    lat:   Number(item.lat),
    lng:   Number(item.lon),
  }));

  await setJson(cacheKey, results, GEOCODE_TTL);
  return results;
};

const rowToRide = (row) => ({
  id:                 row.id,
  driverId:           row.driver_id,
  driver: row.driver_name ? {
    id:              row.driver_id,
    name:            row.driver_name,
    phone:           row.driver_phone,
    rating:          Number(row.driver_rating) || 0,
    profilePhotoUrl: row.driver_profile_photo_url || null,
  } : null,
  originAddress:      row.origin_address,
  origin:             { lat: Number(row.origin_lat),      lng: Number(row.origin_lng) },
  destinationAddress: row.destination_address,
  destination:        { lat: Number(row.destination_lat), lng: Number(row.destination_lng) },
  route:              row.route_polyline ? JSON.parse(row.route_polyline) : [],
  distanceMeters:     Number(row.route_distance_m) || 0,
  durationSeconds:    Number(row.route_duration_s) || 0,
  departureTime:      row.departure_time,
  seatsTotal:         Number(row.seats_total),
  seatsAvailable:     Number(row.seats_available),
  pricePerSeat:       Number(row.price_per_seat),
  passengerDistanceMeters: row.passenger_distance_m === undefined
    ? null
    : Number(row.passenger_distance_m) || 0,
  passengerPricePerSeat: row.passenger_price_per_seat === undefined
    ? null
    : Number(row.passenger_price_per_seat) || 0,
  preferences:        row.preferences || {},
  status:             row.status,
  vehicleType:        row.vehicle_type || null,
  match: row.detour_score === undefined ? null : {
    detourScore:  Number(row.detour_score),
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

const rideSelect = `
  r.*,
  u.name              AS driver_name,
  u.phone             AS driver_phone,
  u.rating            AS driver_rating,
  u.profile_photo_url AS driver_profile_photo_url,
  v.type              AS vehicle_type
`;

const createRide = async (driverId, input) => {
  await ensureRideColumns();
  const originLat      = toNum(input.originLat      ?? input.origin?.lat);
  const originLng      = toNum(input.originLng      ?? input.origin?.lng);
  const destinationLat = toNum(input.destinationLat ?? input.destination?.lat);
  const destinationLng = toNum(input.destinationLng ?? input.destination?.lng);
  const seatsTotal     = parseInt(input.seatsTotal  ?? input.seats, 10);
  const pricePerSeat   = toNum(input.pricePerSeat   ?? input.price);

  const vehicleId     = input.vehicleId || null;

  if (!input.originAddress || !input.destinationAddress
      || originLat == null || originLng == null
      || destinationLat == null || destinationLng == null
      || !input.departureTime || !seatsTotal || pricePerSeat == null) {
    throw { status: 400, message: 'Origin, destination, departure time, seats, and price are required' };
  }

  if (vehicleId) {
    const { rows: vehicleRows } = await pool.query(
      'SELECT driver_id FROM vehicles WHERE id = $1',
      [vehicleId],
    );
    if (!vehicleRows.length) {
      throw { status: 404, message: 'Vehicle not found' };
    }
    if (vehicleRows[0].driver_id !== driverId) {
      throw { status: 403, message: 'Vehicle does not belong to this driver' };
    }
  }

  const route = await getOsrmRoute([
    [originLng, originLat],
    [destinationLng, destinationLat],
  ]);

  const { rows } = await pool.query(
    `INSERT INTO rides (
      driver_id, vehicle_id, origin_address, origin_lat, origin_lng,
      destination_address, destination_lat, destination_lng,
      route_polyline, route_distance_m, route_duration_s,
      departure_time, seats_total, seats_available, price_per_seat, preferences
    )
    VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16)
    RETURNING *`,
    [
      driverId,
      vehicleId,
      input.originAddress, originLat, originLng,
      input.destinationAddress, destinationLat, destinationLng,
      JSON.stringify(route.geometry),
      route.distance, route.duration,
      input.departureTime, seatsTotal,
      seatsTotal,
      pricePerSeat,
      JSON.stringify(input.preferences || {}),
    ],
  );
  return rowToRide(rows[0]);
};

const getRide = async (id) => {
  await ensureRideColumns();
  const { rows } = await pool.query(
    `SELECT ${rideSelect} FROM rides r
     JOIN users u ON u.id = r.driver_id
     LEFT JOIN vehicles v ON v.id = r.vehicle_id
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
     FROM rides r
     JOIN users u ON u.id = r.driver_id
     LEFT JOIN vehicles v ON v.id = r.vehicle_id
     WHERE r.driver_id = $1
     ORDER BY r.departure_time DESC`,
    [driverId],
  );
  return rows.map(rowToRide);
};

const updateStatus = async (driverId, rideId, status) => {
  if (!['active', 'in_progress', 'completed', 'cancelled'].includes(status)) {
    throw { status: 400, message: 'Invalid ride status' };
  }
  const { sendPush } = require('../notifications/notification.service');
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const { rows } = await client.query(
      `UPDATE rides SET status = $1,
        actual_start_time = CASE WHEN $1 = 'in_progress' THEN NOW() ELSE actual_start_time END,
        actual_end_time   = CASE WHEN $1 = 'completed'   THEN NOW() ELSE actual_end_time   END,
        updated_at = NOW()
       WHERE id = $2 AND driver_id = $3 RETURNING *`,
      [status, rideId, driverId],
    );
    if (!rows.length) throw { status: 404, message: 'Ride not found' };

    // Get all confirmed passengers for FCM
    const { rows: passengers } = await client.query(
      `SELECT b.id AS booking_id, u.fcm_token, u.name
       FROM bookings b JOIN users u ON u.id = b.passenger_id
       WHERE b.ride_id = $1 AND b.status = 'confirmed'`,
      [rideId],
    );

    if (status === 'in_progress') {
      // M9: trip started → batch FCM to all confirmed passengers
      for (const p of passengers) {
        await sendPush({
          token: p.fcm_token,
          title: 'Trip Started!',
          body: 'Your driver has started the trip. Track them live.',
          data: { type: 'trip_started', rideId },
        });
      }
    } else if (status === 'completed') {
      await client.query(
        `UPDATE bookings SET status = 'completed', updated_at = NOW()
         WHERE ride_id = $1 AND status = 'confirmed'`,
        [rideId],
      );
      await settleWalletBookingsForRide(rideId, client);
      // M9: trip completed → payment + review FCM to passengers
      for (const p of passengers) {
        await sendPush({
          token: p.fcm_token,
          title: 'Trip Completed!',
          body: 'Please rate your driver and complete payment.',
          data: { type: 'trip_completed', rideId, bookingId: p.booking_id },
        });
      }
    } else if (status === 'cancelled') {
      await releaseWalletReservationsForRide(rideId, client, 'Ride cancelled by driver');
      // M9: ride cancelled → FCM to all booked passengers
      for (const p of passengers) {
        await sendPush({
          token: p.fcm_token,
          title: 'Ride Cancelled',
          body: 'The driver has cancelled this ride. We apologise for the inconvenience.',
          data: { type: 'ride_cancelled', rideId },
        });
      }
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

// ── Route-corridor search algorithm ──────────────────────────────────────────
//
// HOW IT WORKS
// ─────────────
// Old approach: fired one OSRM call per ride to test a 4-point detour.
// Problems:
//   • Slow — 30 rides = 30 extra HTTP calls.
//   • Wrong — Driver KTM→Lalitpur matched KTM→Bhaktapur because the detour
//     check only asked "can the driver swing by?" not "is Bhaktapur actually
//     on the way to Lalitpur?"
//
// New approach: uses the route_polyline stored when the ride was created.
//
//   1. Find polyline point nearest to passenger's PICKUP.
//   2. Find polyline point nearest to passenger's DROPOFF.
//   3. Both must be within corridorMeters (default 800 m) of the route.
//   4. Pickup index must come BEFORE dropoff index → blocks wrong-direction.
//   5. Sort by combined corridor distance (closest match first).
//   6. Falls back to old OSRM detour if no polyline stored.
//
// Real-world example (Kathmandu):
//   Driver: KTM → Lalitpur.  Passenger: KTM → Bhaktapur.
//   Bhaktapur is EAST of KTM; Lalitpur is SOUTH. Bhaktapur is not on the
//   KTM→Lalitpur polyline → dropoff distance >> 800 m → ride hidden. ✓
//
//   Driver: KTM → Lalitpur passing through Patan.
//   Passenger: KTM → Patan. Both points within 800 m of polyline
//   AND pickup index < dropoff index → ride shown. ✓

const searchRides = async (input) => {
  await ensureRideColumns();

  const origin      = { lat: toNum(input.originLat),      lng: toNum(input.originLng) };
  const destination = { lat: toNum(input.destinationLat), lng: toNum(input.destinationLng) };

  if (origin.lat == null || origin.lng == null
      || destination.lat == null || destination.lng == null) {
    throw {
      status: 400,
      message: 'originLat, originLng, destinationLat, and destinationLng are required',
    };
  }

  const corridorMeters = toNum(input.corridorMeters) ?? 800;
  const maxDetour      = toNum(input.maxDetour)      ?? 0.5;

  // Round coords to 4 dp (~11 m) so nearby searches share the same cache entry
  const cacheKey = [
    'search',
    origin.lat.toFixed(4),
    origin.lng.toFixed(4),
    destination.lat.toFixed(4),
    destination.lng.toFixed(4),
    corridorMeters,
  ].join(':');

  const cached = await getJson(cacheKey);
  if (cached) return cached;

  const { rows } = await pool.query(
    `SELECT ${rideSelect}
     FROM rides r
     JOIN users u ON u.id = r.driver_id
     LEFT JOIN vehicles v ON v.id = r.vehicle_id
     WHERE r.status = 'active'
       AND r.seats_available > 0
       AND r.departure_time >= NOW() - INTERVAL '2 hours'
     ORDER BY r.departure_time ASC
     LIMIT 50`,
  );

  const results = [];

  for (const row of rows) {
    let polyline = [];
    try { polyline = row.route_polyline ? JSON.parse(row.route_polyline) : []; }
    catch (_) { polyline = []; }

    if (polyline.length >= 2) {
      const pickupMatch  = nearestPolylinePoint(polyline, origin);
      const dropoffMatch = nearestPolylinePoint(polyline, destination);

      if (pickupMatch.distMeters  > corridorMeters) continue;
      if (dropoffMatch.distMeters > corridorMeters) continue;
      if (pickupMatch.index >= dropoffMatch.index)  continue;

      const combinedDist = pickupMatch.distMeters + dropoffMatch.distMeters;
      const passengerDistance = Math.max(
        polylineDistance(polyline, pickupMatch.index, dropoffMatch.index),
        Math.round(haversineMeters(origin, destination)),
      );
      results.push(rowToRide({
        ...row,
        detour_score:             combinedDist / 1000,
        detour_meters:            Math.round(combinedDist),
        passenger_distance_m:     passengerDistance,
        passenger_price_per_seat: fareForDistance(
          row.price_per_seat,
          row.route_distance_m,
          passengerDistance,
        ),
      }));
    } else {
      const rideOrigin      = { lat: Number(row.origin_lat),      lng: Number(row.origin_lng) };
      const rideDestination = { lat: Number(row.destination_lat), lng: Number(row.destination_lng) };
      const direct          = Number(row.route_distance_m)
                              || haversineMeters(rideOrigin, rideDestination);

      const detourRoute = await getOsrmRoute([
        [rideOrigin.lng,      rideOrigin.lat],
        [origin.lng,          origin.lat],
        [destination.lng,     destination.lat],
        [rideDestination.lng, rideDestination.lat],
      ]);
      const detourMeters = Math.max(0, detourRoute.distance - direct);
      const detourScore  = direct > 0 ? detourMeters / direct : 99;
      if (detourScore > maxDetour) continue;
      const passengerRoute = await getOsrmRoute([
        [origin.lng, origin.lat],
        [destination.lng, destination.lat],
      ]);
      results.push(rowToRide({
        ...row,
        detour_score:             detourScore,
        detour_meters:            detourMeters,
        passenger_distance_m:     passengerRoute.distance,
        passenger_price_per_seat: fareForDistance(
          row.price_per_seat,
          direct,
          passengerRoute.distance,
        ),
      }));
    }
  }

  const sorted = results.sort((a, b) => a.match.detourScore - b.match.detourScore);
  await setJson(cacheKey, sorted, RIDE_SEARCH_TTL);
  return sorted;
};

// Bust all ride-search cache keys — call after any seat-availability change.
// NOTE: bookings.service.js imports this directly (no circular dep since
//       rides.service does NOT import from bookings.service for this helper).
const invalidateRideSearchCache = () => delPattern('search:*');

module.exports = { geocode, createRide, getRide, getMyRides, searchRides, updateStatus, invalidateRideSearchCache };