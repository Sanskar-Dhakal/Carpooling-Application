const pool = require('../../config/database');
const bcrypt = require('bcryptjs');
const { sendPush } = require('../notifications/notification.service');
const { creditPlatformFee, PLATFORM_FEE_RATE } = require('../payments/payments.service');
const { delPattern, getPp, setPp } = require('../../config/redis');
const { ensureWalletTransactionsSchema } = require('../../services/schema.service');
// Inline cache buster — avoids circular dep (rides ↔ bookings)
const invalidateRideSearchCache = () => delPattern('search:*');

const toInt = (value) => {
  const n = parseInt(value, 10);
  return Number.isFinite(n) ? n : null;
};

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

const nearestPolylinePoint = (polyline, point) => {
  let bestIndex = 0;
  let bestDist = Infinity;
  for (let i = 0; i < polyline.length; i++) {
    const d = haversineMeters(polyline[i], point);
    if (d < bestDist) {
      bestDist = d;
      bestIndex = i;
    }
  }
  return { index: bestIndex, distMeters: bestDist };
};

const polylineDistance = (polyline, startIndex, endIndex) => {
  let distance = 0;
  for (let i = startIndex + 1; i <= endIndex; i++) {
    distance += haversineMeters(polyline[i - 1], polyline[i]);
  }
  return Math.round(distance);
};

const bookingSelect = `
  b.*,
  r.driver_id,
  r.origin_address,
  r.destination_address,
  r.departure_time,
  r.price_per_seat,
  r.route_distance_m,
  r.route_polyline,
  r.origin_lat,
  r.origin_lng,
  r.destination_lat,
  r.destination_lng,
  driver.name AS driver_name,
  driver.phone AS driver_phone,
  driver.rating AS driver_rating,
  driver.fcm_token AS driver_fcm_token,
  driver.qr_payment_id AS driver_qr_payment_id,
  driver.qr_payment_label AS driver_qr_payment_label,
  driver.qr_payment_image_url AS driver_qr_payment_image_url,
  driver.qr_payment_images::text AS driver_qr_payment_images,
  passenger.name AS passenger_name,
  passenger.phone AS passenger_phone,
  passenger.rating AS passenger_rating,
  passenger.fcm_token AS passenger_fcm_token
`;

const rowToBooking = (row) => ({
  id: row.id,
  rideId: row.ride_id,
  passengerId: row.passenger_id,
  seatsBooked: Number(row.seats_booked),
  totalAmount: Number(row.total_amount),
  paymentMethod: row.payment_method,
  status: row.status,
  paymentStatus: row.payment_status,
  paymentScreenshotUrl: row.payment_screenshot_url,
  paymentConfirmedAt: row.payment_confirmed_at,
  createdAt: row.created_at,
  ride: {
    id: row.ride_id,
    originAddress: row.origin_address,
    destinationAddress: row.destination_address,
    departureTime: row.departure_time,
    pricePerSeat: Number(row.price_per_seat),
    distanceMeters: Number(row.route_distance_m) || 0,
    origin: { lat: Number(row.origin_lat), lng: Number(row.origin_lng) },
    destination: { lat: Number(row.destination_lat), lng: Number(row.destination_lng) },
    route: row.route_polyline ? JSON.parse(row.route_polyline) : [],
  },
  driver: {
    id: row.driver_id,
    name: row.driver_name,
    phone: row.driver_phone,
    rating: Number(row.driver_rating) || 0,
    qrPaymentId: row.driver_qr_payment_id,
    qrPaymentLabel: row.driver_qr_payment_label,
    qrPaymentImageUrl: row.driver_qr_payment_image_url,
    qrPaymentImages: row.driver_qr_payment_images ? JSON.parse(row.driver_qr_payment_images) : {},
  },
  passenger: {
    id: row.passenger_id,
    name: row.passenger_name,
    phone: row.passenger_phone,
    rating: Number(row.passenger_rating) || 0,
  },
});

const fetchBooking = async (id, client = pool) => {
  const { rows } = await client.query(
    `SELECT ${bookingSelect}
     FROM bookings b
     JOIN rides r ON r.id = b.ride_id
     JOIN users driver ON driver.id = r.driver_id
     JOIN users passenger ON passenger.id = b.passenger_id
     WHERE b.id = $1`,
    [id],
  );
  if (!rows.length) throw { status: 404, message: 'Booking not found' };
  return rows[0];
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

const calculatePassengerPricePerSeat = (ride, input) => {
  const origin = {
    lat: toNum(input.originLat ?? input.origin?.lat),
    lng: toNum(input.originLng ?? input.origin?.lng),
  };
  const destination = {
    lat: toNum(input.destinationLat ?? input.destination?.lat),
    lng: toNum(input.destinationLng ?? input.destination?.lng),
  };

  if (origin.lat == null || origin.lng == null
      || destination.lat == null || destination.lng == null) {
    return Number(ride.price_per_seat);
  }

  let passengerDistance = Math.round(haversineMeters(origin, destination));
  let polyline = [];
  try {
    polyline = ride.route_polyline ? JSON.parse(ride.route_polyline) : [];
  } catch (_) {
    polyline = [];
  }

  if (polyline.length >= 2) {
    const pickupMatch = nearestPolylinePoint(polyline, origin);
    const dropoffMatch = nearestPolylinePoint(polyline, destination);
    if (pickupMatch.index < dropoffMatch.index) {
      passengerDistance = Math.max(
        polylineDistance(polyline, pickupMatch.index, dropoffMatch.index),
        passengerDistance,
      );
    }
  }

  return fareForDistance(
    ride.price_per_seat,
    Number(ride.route_distance_m) || passengerDistance,
    passengerDistance,
  );
};

const creditDriverWallet = async (client, driverId, amount, rideId, description) => {
  const walletRes = await client.query('SELECT * FROM wallets WHERE user_id = $1 FOR UPDATE', [driverId]);
  const wallet = walletRes.rows[0]
    || (await client.query('INSERT INTO wallets (user_id) VALUES ($1) RETURNING *', [driverId])).rows[0];
  await client.query(
    `UPDATE wallets SET balance = balance + $1, updated_at = NOW()
     WHERE id = $2`,
    [amount, wallet.id],
  );
  await client.query(
    `INSERT INTO wallet_transactions (wallet_id, type, amount, description, ride_id)
     VALUES ($1, 'credit', $2, $3, $4)`,
    [wallet.id, amount, description, rideId],
  );
};

const splitRideEarning = async (client, driverId, grossAmount, rideId, method) => {
  const gross = roundMoney(Number(grossAmount));
  const commissionRate = 0.10;
  const commission = roundMoney(gross * commissionRate);
  const driverAmount = roundMoney(gross - commission);

  // Admin always gets 10% commission for every payment method (cash, qr, wallet)
  if (commission > 0) {
    const adminWalletRes = await client.query(
      `SELECT w.id FROM wallets w JOIN users u ON u.id = w.user_id WHERE u.role = 'admin' ORDER BY u.created_at ASC LIMIT 1 FOR UPDATE`
    );
    if (adminWalletRes.rows.length) {
      await client.query(
        `UPDATE wallets SET balance = balance + $1, updated_at = NOW() WHERE id = $2`,
        [commission, adminWalletRes.rows[0].id]
      );
      await client.query(
        `INSERT INTO wallet_transactions (wallet_id, type, amount, description, ride_id)
         VALUES ($1, 'credit', $2, $3, $4)`,
        [adminWalletRes.rows[0].id, commission, `Platform commission (10%) from ${method} payment`, rideId]
      );
    }
  }

  // For cash: driver gets money physically from the passenger — do NOT credit wallet
  // to avoid double-counting. For QR/Wallet: credit driver the remaining 90%.
  if (method !== 'cash') {
    await creditDriverWallet(
      client,
      driverId,
      driverAmount,
      rideId,
      `Ride earning (after commission) from ${method}`,
    );
  }
};

const settleWalletBookingsForRide = async (rideId, client = pool) => {
  const { rows } = await client.query(
    `SELECT b.*, r.driver_id
     FROM bookings b
     JOIN rides r ON r.id = b.ride_id
     WHERE b.ride_id = $1
       AND r.status = 'completed'
       AND b.status = 'completed'
       AND b.payment_method = 'wallet'
       AND b.payment_status = 'passenger_confirmed'
     FOR UPDATE OF b`,
    [rideId],
  );

  for (const row of rows) {
    const passengerWalletRes = await client.query('SELECT * FROM wallets WHERE user_id = $1 FOR UPDATE', [row.passenger_id]);
    const passengerWallet = passengerWalletRes.rows[0];
    if (!passengerWallet) throw { status: 400, message: 'Passenger wallet not found' };

    await client.query(
      `UPDATE wallets
       SET reserved = GREATEST(reserved - $1, 0), updated_at = NOW()
       WHERE id = $2`,
      [row.total_amount, passengerWallet.id],
    );
    await client.query(
      `INSERT INTO wallet_transactions (wallet_id, type, amount, description, ride_id)
       VALUES ($1, 'debit', $2, $3, $4)`,
      [passengerWallet.id, row.total_amount, 'Ride payment settled', row.ride_id],
    );
    await splitRideEarning(client, row.driver_id, row.total_amount, row.ride_id, 'wallet');
    await client.query(
      `UPDATE bookings
       SET status = 'completed',
           payment_status = 'settled',
           payment_confirmed_at = NOW(),
           updated_at = NOW()
       WHERE id = $1`,
      [row.id],
    );
  }
};

const releaseWalletReservationsForRide = async (rideId, client = pool, description = 'Ride cancelled') => {
  const { rows } = await client.query(
    `SELECT * FROM bookings
     WHERE ride_id = $1
       AND payment_method = 'wallet'
       AND payment_status <> 'settled'
       AND status IN ('pending','confirmed','completed')
     FOR UPDATE`,
    [rideId],
  );

  for (const row of rows) {
    const walletRes = await client.query('SELECT * FROM wallets WHERE user_id = $1 FOR UPDATE', [row.passenger_id]);
    const wallet = walletRes.rows[0];
    if (!wallet) continue;
    await client.query(
      `UPDATE wallets
       SET balance = balance + $1,
           reserved = GREATEST(reserved - $1, 0),
           updated_at = NOW()
       WHERE id = $2`,
      [row.total_amount, wallet.id],
    );
    await client.query(
      `INSERT INTO wallet_transactions (wallet_id, type, amount, description, ride_id)
       VALUES ($1, 'release', $2, $3, $4)`,
      [wallet.id, row.total_amount, description, row.ride_id],
    );
  }

  await client.query(
    `UPDATE bookings
     SET status = 'cancelled',
         payment_status = CASE WHEN payment_status = 'settled' THEN payment_status ELSE 'pending' END,
         updated_at = NOW()
     WHERE ride_id = $1
       AND status IN ('pending','confirmed','completed')
       AND payment_status <> 'settled'`,
    [rideId],
  );
};

const createBooking = async (passengerId, input) => {
  const seatsBooked = toInt(input.seatsBooked ?? input.seats);
  const paymentMethod = input.paymentMethod || 'cash';
  if (!input.rideId || !seatsBooked || seatsBooked < 1 || !['wallet', 'qr', 'cash'].includes(paymentMethod)) {
    throw { status: 400, message: 'rideId, seatsBooked, and a valid paymentMethod are required' };
  }

  const client = await pool.connect();
  let bookingRow;
  try {
    await client.query('BEGIN');

    let passenger = await getPp(passengerId);
    if (!passenger) {
      const { rows } = await client.query(
        'SELECT id,name,email,phone,role,is_verified,verification_status,is_blocked,rating,profile_photo_url,is_red_listed FROM users WHERE id = $1',
        [passengerId],
      );
      if (!rows.length) throw { status: 404, message: 'User not found' };
      passenger = rows[0];
      await setPp(passenger.id, passenger);
    }
    if (passenger.is_verified !== true) {
      throw { status: 403, message: 'Please verify your account before booking a ride' };
    }
    if (passenger.is_red_listed) {
      throw { status: 403, message: 'Your account is restricted due to repeated cancellations. Please contact support.' };
    }

    const rideRes = await client.query(
      `SELECT r.*, driver.fcm_token AS driver_fcm_token, driver.name AS driver_name
       FROM rides r JOIN users driver ON driver.id = r.driver_id
       WHERE r.id = $1
       FOR UPDATE`,
      [input.rideId],
    );
    if (!rideRes.rows.length) throw { status: 404, message: 'Ride not found' };
    const ride = rideRes.rows[0];
    if (ride.driver_id === passengerId) throw { status: 400, message: 'Drivers cannot book their own ride' };
    if (ride.status !== 'active') throw { status: 400, message: 'Ride is not active' };
    if (Number(ride.seats_available) < seatsBooked) throw { status: 400, message: 'Not enough seats available' };

    const existing = await client.query(
      `SELECT id FROM bookings
       WHERE ride_id = $1 AND passenger_id = $2 AND status IN ('pending','confirmed')`,
      [input.rideId, passengerId],
    );
    if (existing.rows.length) throw { status: 409, message: 'You already have an active booking for this ride' };

    const passengerPricePerSeat = calculatePassengerPricePerSeat(ride, input);
    const totalAmount = roundMoney(passengerPricePerSeat * seatsBooked);

    if (paymentMethod === 'wallet') {
      const walletRes = await client.query('SELECT * FROM wallets WHERE user_id = $1 FOR UPDATE', [passengerId]);
      if (!walletRes.rows.length) throw { status: 400, message: 'Wallet not found' };
      const wallet = walletRes.rows[0];
      if (Number(wallet.balance) < totalAmount) throw { status: 400, message: 'Insufficient wallet balance' };

      await client.query(
        `UPDATE wallets
         SET balance = balance - $1, reserved = reserved + $1, updated_at = NOW()
         WHERE id = $2`,
        [totalAmount, wallet.id],
      );
      await client.query(
        `INSERT INTO wallet_transactions (wallet_id, type, amount, description, ride_id)
         VALUES ($1, 'reserve', $2, $3, $4)`,
        [wallet.id, totalAmount, 'Ride booking reservation', input.rideId],
      );
    }

    const bookingRes = await client.query(
      `INSERT INTO bookings (ride_id, passenger_id, seats_booked, total_amount, payment_method, payment_status)
       VALUES ($1,$2,$3,$4,$5,$6)
       RETURNING *`,
      [input.rideId, passengerId, seatsBooked, totalAmount, paymentMethod, 'pending'],
    );
    bookingRow = bookingRes.rows[0];
    await client.query('COMMIT');

    sendPush({
      token: ride.driver_fcm_token,
      title: 'New booking request',
      body: `${seatsBooked} seat request for ${ride.origin_address} to ${ride.destination_address}`,
      data: { type: 'booking_request', bookingId: bookingRow.id, rideId: input.rideId },
    });
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }

  // Seat availability changed — bust ride-search cache
  await invalidateRideSearchCache();
  return rowToBooking(await fetchBooking(bookingRow.id));
};

const getPassengerBookings = async (passengerId) => {
  const { rows } = await pool.query(
    `SELECT ${bookingSelect}
     FROM bookings b
     JOIN rides r ON r.id = b.ride_id
     JOIN users driver ON driver.id = r.driver_id
     JOIN users passenger ON passenger.id = b.passenger_id
     WHERE b.passenger_id = $1
     ORDER BY b.created_at DESC`,
    [passengerId],
  );
  return rows.map(rowToBooking);
};

const getDriverBookings = async (driverId) => {
  const { rows } = await pool.query(
    `SELECT ${bookingSelect}
     FROM bookings b
     JOIN rides r ON r.id = b.ride_id
     JOIN users driver ON driver.id = r.driver_id
     JOIN users passenger ON passenger.id = b.passenger_id
     WHERE r.driver_id = $1
     ORDER BY b.created_at DESC`,
    [driverId],
  );
  return rows.map(rowToBooking);
};

const updateBookingStatus = async (driverId, bookingId, status) => {
  if (!['confirmed', 'rejected', 'completed', 'cancelled'].includes(status)) {
    throw { status: 400, message: 'Status must be confirmed, rejected, completed, or cancelled' };
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const row = await fetchBooking(bookingId, client);
    if (row.driver_id !== driverId) throw { status: 403, message: 'Only the ride driver can update this booking' };
    if (!['pending', 'confirmed'].includes(row.status)) throw { status: 400, message: 'Only pending or confirmed bookings can be updated' };

    const rideRes = await client.query('SELECT * FROM rides WHERE id = $1 FOR UPDATE', [row.ride_id]);
    const ride = rideRes.rows[0];
    if (status === 'confirmed') {
      if (Number(ride.seats_available) < Number(row.seats_booked)) {
        throw { status: 400, message: 'Not enough seats available' };
      }
      await client.query(
        `UPDATE rides
         SET seats_available = seats_available - $1, updated_at = NOW()
         WHERE id = $2`,
        [row.seats_booked, row.ride_id],
      );
    } else if (['rejected', 'cancelled'].includes(status)) {
      if (row.status === 'confirmed') {
        await client.query(
          `UPDATE rides SET seats_available = seats_available + $1, updated_at = NOW() WHERE id = $2`,
          [row.seats_booked, row.ride_id]
        );
      }
      if (row.payment_method === 'wallet') {
        const walletRes = await client.query('SELECT * FROM wallets WHERE user_id = $1 FOR UPDATE', [row.passenger_id]);
        const wallet = walletRes.rows[0];
        if (wallet) {
          await client.query(
            `UPDATE wallets
             SET balance = balance + $1, reserved = GREATEST(reserved - $1, 0), updated_at = NOW()
             WHERE id = $2`,
            [row.total_amount, wallet.id],
          );
          await client.query(
            `INSERT INTO wallet_transactions (wallet_id, type, amount, description, ride_id)
             VALUES ($1, 'release', $2, $3, $4)`,
            [wallet.id, row.total_amount, `Ride booking ${status}`, row.ride_id],
          );
        }
      }
    }

    let finalPaymentStatus = row.payment_status;
    if (status === 'completed' && row.payment_method === 'wallet') {
      finalPaymentStatus = 'settled';
    } else if (status === 'confirmed') {
      finalPaymentStatus = 'pending';
    }

    await client.query(
      `UPDATE bookings
       SET status = $1, payment_status = $2,
       updated_at = NOW()
       ${finalPaymentStatus === 'settled' ? ', payment_confirmed_at = NOW()' : ''}
       WHERE id = $3`,
      [status, finalPaymentStatus, bookingId],
    );

    if (status === 'completed') {
      await client.query(
        `UPDATE rides
         SET status = 'completed',
             actual_end_time = COALESCE(actual_end_time, NOW()),
             updated_at = NOW()
         WHERE id = $1
           AND status <> 'completed'`,
        [row.ride_id],
      );
      await client.query(
        `UPDATE bookings
         SET status = 'completed',
             updated_at = NOW()
         WHERE ride_id = $1
           AND status = 'confirmed'`,
        [row.ride_id],
      );
    }

    if (finalPaymentStatus === 'settled') {
      const passengerWalletRes = await client.query('SELECT * FROM wallets WHERE user_id = $1 FOR UPDATE', [row.passenger_id]);
      const passengerWallet = passengerWalletRes.rows[0];
      if (passengerWallet) {
        await client.query(
          `UPDATE wallets SET reserved = GREATEST(reserved - $1, 0), updated_at = NOW() WHERE id = $2`,
          [row.total_amount, passengerWallet.id]
        );
        await client.query(
          `INSERT INTO wallet_transactions (wallet_id, type, amount, description, ride_id) VALUES ($1, 'debit', $2, $3, $4)`,
          [passengerWallet.id, row.total_amount, 'Ride payment settled automatically', row.ride_id]
        );
        await splitRideEarning(client, row.driver_id, row.total_amount, row.ride_id, 'wallet');
      }
    }

    if (status === 'completed') {
      await settleWalletBookingsForRide(row.ride_id, client);
    }

    await client.query('COMMIT');

    sendPush({
      token: row.passenger_fcm_token,
      title: status === 'confirmed' ? 'Booking confirmed' : status === 'completed' ? 'Ride completed' : 'Booking rejected',
      body: status === 'completed' ? `${row.driver_name} has completed the ride. Payment processed.` : `${row.driver_name} ${status === 'confirmed' ? 'accepted' : 'rejected'} your ride request`,
      data: { type: 'booking_status', bookingId, status },
    });
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }

  // Seat availability may have changed — bust ride-search cache
  await invalidateRideSearchCache();
  return rowToBooking(await fetchBooking(bookingId));
};

const authorizeWalletPayment = async (passengerId, bookingId, password) => {
  if (!password) throw { status: 400, message: 'Password is required to authorize wallet payment' };

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const row = await fetchBooking(bookingId, client);
    if (row.passenger_id !== passengerId) throw { status: 403, message: 'Only the passenger can authorize this payment' };
    if (row.payment_method !== 'wallet') throw { status: 400, message: 'This booking is not a wallet payment' };
    if (row.status !== 'completed') {
      throw { status: 400, message: 'Ride must be completed before wallet payment authorization' };
    }
    if (row.payment_status === 'settled') throw { status: 400, message: 'Payment is already settled' };

    const userRes = await client.query('SELECT password_hash FROM users WHERE id = $1', [passengerId]);
    const ok = await bcrypt.compare(password, userRes.rows[0]?.password_hash || '');
    if (!ok) throw { status: 401, message: 'Incorrect password' };

    const passengerWalletRes = await client.query('SELECT * FROM wallets WHERE user_id = $1 FOR UPDATE', [passengerId]);
    const passengerWallet = passengerWalletRes.rows[0];
    if (!passengerWallet) throw { status: 400, message: 'Passenger wallet not found' };

    await client.query(
      `UPDATE wallets
       SET reserved = GREATEST(reserved - $1, 0), updated_at = NOW()
       WHERE id = $2`,
      [row.total_amount, passengerWallet.id],
    );
    await client.query(
      `INSERT INTO wallet_transactions (wallet_id, type, amount, description, ride_id)
       VALUES ($1, 'debit', $2, $3, $4)`,
      [passengerWallet.id, row.total_amount, 'Ride payment settled', row.ride_id],
    );
    await splitRideEarning(client, row.driver_id, row.total_amount, row.ride_id, 'wallet');

    await client.query(
      `UPDATE bookings
       SET payment_status = 'settled',
           payment_confirmed_at = NOW(),
           updated_at = NOW()
       WHERE id = $1`,
      [bookingId],
    );
    await client.query('COMMIT');
    return rowToBooking(await fetchBooking(bookingId));
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
};

const submitQrPayment = async (passengerId, bookingId, screenshotUrl) => {
  if (!screenshotUrl || String(screenshotUrl).trim().length < 4) {
    throw { status: 400, message: 'Payment screenshot or reference is required' };
  }
  const row = await fetchBooking(bookingId);
  if (row.passenger_id !== passengerId) throw { status: 403, message: 'Only the passenger can submit this payment' };
  if (row.payment_method !== 'qr') throw { status: 400, message: 'This booking is not a QR payment' };
  if (!['confirmed', 'completed'].includes(row.status)) {
    throw { status: 400, message: 'Booking must be confirmed first' };
  }

  await pool.query(
    `UPDATE bookings
     SET payment_screenshot_url = $1,
         payment_status = 'passenger_confirmed',
         payment_confirmed_at = NOW(),
         updated_at = NOW()
     WHERE id = $2`,
    [screenshotUrl, bookingId],
  );
  return rowToBooking(await fetchBooking(bookingId));
};

const confirmPaymentReceived = async (driverId, bookingId) => {
  await ensureWalletTransactionsSchema();
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const row = await fetchBooking(bookingId, client);
    if (row.driver_id !== driverId) throw { status: 403, message: 'Only the ride driver can confirm payment' };
    if (!['qr', 'cash'].includes(row.payment_method)) {
      throw { status: 400, message: 'Only QR and cash payments need driver confirmation' };
    }
    if (!['confirmed', 'completed'].includes(row.status)) {
      throw { status: 400, message: 'Booking must be confirmed before payment can settle' };
    }
    if (row.payment_method === 'qr' && row.payment_status !== 'passenger_confirmed') {
      throw { status: 400, message: 'Passenger must submit QR payment first' };
    }
    if (row.payment_status === 'settled') {
      throw { status: 400, message: 'Payment is already settled' };
    }

    if (row.payment_method === 'cash') {
      await client.query(
        `UPDATE bookings
         SET status = CASE WHEN status = 'completed' THEN status ELSE 'completed' END,
             payment_status = 'settled',
             payment_confirmed_at = NOW(),
             updated_at = NOW()
         WHERE id = $1`,
        [bookingId],
      );
      await client.query(
        `INSERT INTO wallet_transactions (wallet_id, type, amount, description, ride_id)
         SELECT w.id, 'cash_receipt', $1, $2, $3
         FROM wallets w
         WHERE w.user_id = $4`,
        [row.total_amount, 'Cash received from passenger (not added to wallet)', row.ride_id, row.driver_id]
      );
      // BUGFIX: cash payments never credited the admin's 10% platform commission.
      // splitRideEarning() with method 'cash' credits ONLY the admin wallet
      // (it intentionally skips crediting the driver, since the driver already
      // holds the cash physically) — this is what was missing before.
      await splitRideEarning(client, row.driver_id, row.total_amount, row.ride_id, 'cash');
    } else {
      await client.query(
        `UPDATE bookings
         SET status = CASE WHEN status = 'completed' THEN status ELSE 'completed' END,
             payment_status = 'settled',
             payment_confirmed_at = NOW(),
             updated_at = NOW()
         WHERE id = $1`,
        [bookingId],
      );
      await splitRideEarning(client, row.driver_id, row.total_amount, row.ride_id, row.payment_method);
    }
    await client.query('COMMIT');
    return rowToBooking(await fetchBooking(bookingId));
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
};


const cancelPassengerBooking = async (passengerId, bookingId) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const row = await fetchBooking(bookingId, client);
    if (row.passenger_id !== passengerId) throw { status: 403, message: 'Only the passenger can cancel this booking' };
    if (!['pending', 'confirmed'].includes(row.status)) throw { status: 400, message: 'Cannot cancel a completed or already cancelled booking' };

    if (row.status === 'confirmed') {
      await client.query(
        `UPDATE rides SET seats_available = seats_available + $1, updated_at = NOW() WHERE id = $2`,
        [row.seats_booked, row.ride_id]
      );
      if (row.payment_method === 'wallet') {
        const walletRes = await client.query('SELECT * FROM wallets WHERE user_id = $1 FOR UPDATE', [passengerId]);
        const wallet = walletRes.rows[0];
        if (wallet) {
          await client.query(
            `UPDATE wallets SET balance = balance + $1, reserved = GREATEST(reserved - $1, 0), updated_at = NOW() WHERE id = $2`,
            [row.total_amount, wallet.id]
          );
          await client.query(
            `INSERT INTO wallet_transactions (wallet_id, type, amount, description, ride_id) VALUES ($1, 'release', $2, $3, $4)`,
            [wallet.id, row.total_amount, 'Booking cancelled by passenger', row.ride_id]
          );
        }
      }
    }

    await client.query(
      `UPDATE bookings SET status = 'cancelled', updated_at = NOW() WHERE id = $1`,
      [bookingId]
    );

    // Count all confirmed cancellations by this passenger
    const countRes = await client.query(
      `SELECT COUNT(*) AS cnt FROM bookings
       WHERE passenger_id = $1 AND status = 'cancelled'`,
      [passengerId],
    );
    const cancelCount = Number(countRes.rows[0]?.cnt || 0);

    // Red-list passengers who cancel 5 or more times
    if (cancelCount >= 5) {
      await client.query(
        `UPDATE users SET is_red_listed = true, updated_at = NOW() WHERE id = $1`,
        [passengerId],
      );
      await delPp(passengerId);
      const { rows: userRows } = await client.query(
        'SELECT name, fcm_token FROM users WHERE id = $1', [passengerId],
      );
      if (userRows.length) {
        await setPp(passengerId, userRows[0]);
      }
      const userName = userRows[0]?.name || 'A user';
      if (userRows[0]?.fcm_token) {
        const { sendPush } = require('../notifications/notification.service');
        await sendPush({
          token: userRows[0].fcm_token,
          title: 'Account Restricted',
          body: 'Your account has been restricted due to repeated booking cancellations. Please contact support.',
          data: { type: 'account_red_listed' },
        });
      }
      const { rows: admins } = await client.query(
        `SELECT fcm_token FROM users WHERE role = 'admin' AND fcm_token IS NOT NULL`,
      );
      const notify = require('../notifications/notification.service');
      for (const admin of admins) {
        await notify.sendPush({
          token: admin.fcm_token,
          title: 'Red List Alert',
          body: `${userName} has been red-listed after ${cancelCount} booking cancellations.`,
          data: { type: 'red_list_alert', userId: String(passengerId) },
        });
      }
    }

    await client.query('COMMIT');
    return rowToBooking(await fetchBooking(bookingId));
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
};

module.exports = {
  createBooking,
  getPassengerBookings,
  getDriverBookings,
  updateBookingStatus,
  authorizeWalletPayment,
  submitQrPayment,
  confirmPaymentReceived,
  settleWalletBookingsForRide,
  releaseWalletReservationsForRide,
  cancelPassengerBooking,
};
