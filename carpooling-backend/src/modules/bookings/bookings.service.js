const pool = require('../../config/database');
const bcrypt = require('bcryptjs');
const { sendPush } = require('../notifications/notification.service');

const toInt = (value) => {
  const n = parseInt(value, 10);
  return Number.isFinite(n) ? n : null;
};

const bookingSelect = `
  b.*,
  r.driver_id,
  r.origin_address,
  r.destination_address,
  r.departure_time,
  r.price_per_seat,
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
    await creditDriverWallet(client, row.driver_id, row.total_amount, row.ride_id, 'Ride earning from wallet');
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
       WHERE ride_id = $1 AND passenger_id = $2`,
      [input.rideId, passengerId],
    );
    if (existing.rows.length) throw { status: 409, message: 'You already have a booking for this ride' };

    const totalAmount = Number(ride.price_per_seat) * seatsBooked;

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
    if (err.code === '23505' && err.constraint === 'uq_bookings_ride_passenger') {
      throw { status: 409, message: 'You already have a booking for this ride' };
    }
    throw err;
  } finally {
    client.release();
  }

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
  if (!['confirmed', 'rejected'].includes(status)) {
    throw { status: 400, message: 'Status must be confirmed or rejected' };
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const row = await fetchBooking(bookingId, client);
    if (row.driver_id !== driverId) throw { status: 403, message: 'Only the ride driver can update this booking' };
    if (row.status !== 'pending') throw { status: 400, message: 'Only pending bookings can be updated' };

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
    } else if (row.payment_method === 'wallet') {
      const walletRes = await client.query('SELECT * FROM wallets WHERE user_id = $1 FOR UPDATE', [row.passenger_id]);
      const wallet = walletRes.rows[0];
      await client.query(
        `UPDATE wallets
         SET balance = balance + $1, reserved = GREATEST(reserved - $1, 0), updated_at = NOW()
         WHERE id = $2`,
        [row.total_amount, wallet.id],
      );
      await client.query(
        `INSERT INTO wallet_transactions (wallet_id, type, amount, description, ride_id)
         VALUES ($1, 'release', $2, $3, $4)`,
        [wallet.id, row.total_amount, 'Ride booking rejected', row.ride_id],
      );
    }

    await client.query(
      `UPDATE bookings
       SET status = $1, payment_status = CASE
         WHEN $2 = 'confirmed' AND payment_method = 'cash' THEN 'pending'
         WHEN $2 = 'confirmed' AND payment_method = 'qr' THEN 'pending'
         WHEN $2 = 'confirmed' AND payment_method = 'wallet' THEN 'pending'
         ELSE payment_status
       END,
       updated_at = NOW()
       WHERE id = $3`,
      [status, status, bookingId],
    );

    await client.query('COMMIT');

    sendPush({
      token: row.passenger_fcm_token,
      title: status === 'confirmed' ? 'Booking confirmed' : 'Booking rejected',
      body: `${row.driver_name} ${status === 'confirmed' ? 'accepted' : 'rejected'} your ride request`,
      data: { type: 'booking_status', bookingId, status },
    });
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }

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

    await client.query(
      `UPDATE bookings
       SET payment_status = 'passenger_confirmed',
           payment_confirmed_at = NOW(),
           updated_at = NOW()
       WHERE id = $1`,
      [bookingId],
    );
    await settleWalletBookingsForRide(row.ride_id, client);
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

    await client.query(
      `UPDATE bookings
       SET status = CASE WHEN status = 'completed' THEN status ELSE 'completed' END,
           payment_status = 'settled',
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
};
