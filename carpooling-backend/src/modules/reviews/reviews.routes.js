const router = require('express').Router();
const pool = require('../../config/database');
const { authenticate } = require('../../middleware/auth.middleware');
const { sendPush } = require('../notifications/notification.service');

// POST /api/v1/bookings/:id/review — submit review after trip
router.post('/bookings/:id/review', authenticate, async (req, res, next) => {
  try {
    const { rating, comment } = req.body;
    if (!rating || rating < 1 || rating > 5) {
      return res.status(400).json({ message: 'Rating must be 1-5' });
    }

    // Get booking + figure out who is being reviewed
    const { rows: bRows } = await pool.query(
      `SELECT b.*, r.driver_id, b.passenger_id,
              d.fcm_token AS driver_fcm, d.name AS driver_name,
              p.name AS passenger_name
       FROM bookings b
       JOIN rides r ON r.id = b.ride_id
       JOIN users d ON d.id = r.driver_id
       JOIN users p ON p.id = b.passenger_id
       WHERE b.id = $1`,
      [req.params.id],
    );
    if (!bRows.length) return res.status(404).json({ message: 'Booking not found' });
    const bk = bRows[0];

    if (bk.status !== 'completed') {
      return res.status(400).json({ message: 'Can only review completed trips' });
    }

    const isDriver = req.user.id === bk.driver_id;
    const reviewerId = req.user.id;
    const reviewedId = isDriver ? bk.passenger_id : bk.driver_id;

    const { rows } = await pool.query(
      `INSERT INTO reviews (booking_id, reviewer_id, reviewed_id, rating, comment)
       VALUES ($1, $2, $3, $4, $5)
       ON CONFLICT (booking_id, reviewer_id) DO NOTHING
       RETURNING *`,
      [req.params.id, reviewerId, reviewedId, rating, comment || null],
    );

    if (!rows.length) {
      return res.status(409).json({ message: 'You have already reviewed this trip' });
    }

    // Recalculate average rating for reviewed user
    await pool.query(
      `UPDATE users SET rating = (
         SELECT ROUND(AVG(rating)::numeric, 1) FROM reviews WHERE reviewed_id = $1
       ) WHERE id = $1`,
      [reviewedId],
    );

    // Notify the reviewed user
    const recipientFcm = isDriver ? null : bk.driver_fcm;
    const reviewerName = isDriver ? bk.driver_name : bk.passenger_name;
    if (recipientFcm) {
      await sendPush({
        token: recipientFcm,
        title: 'New Review',
        body: `${reviewerName} gave you ${rating} star${rating > 1 ? 's' : ''}`,
        data: { type: 'new_review', bookingId: req.params.id },
      });
    }

    res.status(201).json({ review: rows[0] });
  } catch (e) { next(e); }
});

// GET /api/v1/users/:id/reviews — public reviews for a user
router.get('/users/:id/reviews', authenticate, async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      `SELECT r.*, u.name AS reviewer_name
       FROM reviews r
       JOIN users u ON u.id = r.reviewer_id
       WHERE r.reviewed_id = $1
       ORDER BY r.created_at DESC
       LIMIT 50`,
      [req.params.id],
    );
    res.json({ reviews: rows });
  } catch (e) { next(e); }
});

module.exports = router;
