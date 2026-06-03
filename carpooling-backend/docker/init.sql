CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. USERS
CREATE TABLE IF NOT EXISTS users (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name              VARCHAR(100) NOT NULL,
  email             VARCHAR(255) UNIQUE NOT NULL,
  phone             VARCHAR(20),
  password_hash     TEXT,
  role              VARCHAR(20) NOT NULL DEFAULT 'passenger'
                    CHECK (role IN ('driver','passenger','both','admin')),
  is_verified       BOOLEAN DEFAULT FALSE,
  rating            DECIMAL(2,1) DEFAULT 0.0,
  profile_photo_url TEXT,
  fcm_token         TEXT,
  qr_payment_id     VARCHAR(100),
  qr_payment_label  VARCHAR(100),
  qr_payment_image_url TEXT,
  created_at        TIMESTAMP DEFAULT NOW(),
  updated_at        TIMESTAMP DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_role  ON users(role);

-- 2. RIDES
CREATE TABLE IF NOT EXISTS rides (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  driver_id           UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  origin_address      VARCHAR(255) NOT NULL,
  origin_lat          DECIMAL(9,6) NOT NULL,
  origin_lng          DECIMAL(9,6) NOT NULL,
  destination_address VARCHAR(255) NOT NULL,
  destination_lat     DECIMAL(9,6) NOT NULL,
  destination_lng     DECIMAL(9,6) NOT NULL,
  route_polyline      TEXT,
  route_distance_m    INTEGER DEFAULT 0,
  route_duration_s    INTEGER DEFAULT 0,
  departure_time      TIMESTAMP NOT NULL,
  seats_total         INTEGER NOT NULL DEFAULT 1,
  seats_available     INTEGER NOT NULL DEFAULT 1,
  price_per_seat      DECIMAL(8,2) NOT NULL,
  preferences         JSONB DEFAULT '{}',
  status              VARCHAR(20) DEFAULT 'active'
                      CHECK (status IN ('active','in_progress','completed','cancelled')),
  actual_start_time   TIMESTAMP,
  actual_end_time     TIMESTAMP,
  created_at          TIMESTAMP DEFAULT NOW(),
  updated_at          TIMESTAMP DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_rides_driver_id ON rides(driver_id);
CREATE INDEX IF NOT EXISTS idx_rides_status    ON rides(status);

-- 3. BOOKINGS
CREATE TABLE IF NOT EXISTS bookings (
  id                     UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  ride_id                UUID NOT NULL REFERENCES rides(id) ON DELETE CASCADE,
  passenger_id           UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  seats_booked           INTEGER NOT NULL DEFAULT 1,
  total_amount           DECIMAL(8,2) NOT NULL,
  payment_method         VARCHAR(10) DEFAULT 'cash'
                         CHECK (payment_method IN ('wallet','qr','cash')),
  status                 VARCHAR(20) DEFAULT 'pending'
                         CHECK (status IN ('pending','confirmed','rejected','cancelled','completed')),
  payment_status         VARCHAR(30) DEFAULT 'pending'
                         CHECK (payment_status IN (
                           'pending','passenger_confirmed',
                           'driver_confirmed','settled','disputed'
                         )),
  payment_screenshot_url TEXT,
  payment_confirmed_at   TIMESTAMP,
  created_at             TIMESTAMP DEFAULT NOW(),
  updated_at             TIMESTAMP DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_bookings_ride_id      ON bookings(ride_id);
CREATE INDEX IF NOT EXISTS idx_bookings_passenger_id ON bookings(passenger_id);

-- 4. WALLETS
CREATE TABLE IF NOT EXISTS wallets (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id    UUID UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  balance    DECIMAL(10,2) DEFAULT 0.00,
  reserved   DECIMAL(10,2) DEFAULT 0.00,
  currency   VARCHAR(10) DEFAULT 'USD',
  updated_at TIMESTAMP DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_wallets_user_id ON wallets(user_id);

-- 5. WALLET TRANSACTIONS
CREATE TABLE IF NOT EXISTS wallet_transactions (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  wallet_id   UUID NOT NULL REFERENCES wallets(id) ON DELETE CASCADE,
  type        VARCHAR(30) NOT NULL
              CHECK (type IN (
                'credit','debit','reserve','release',
                'withdrawal_request','withdrawal_paid'
              )),
  amount      DECIMAL(10,2) NOT NULL,
  description TEXT,
  ride_id     UUID REFERENCES rides(id),
  created_at  TIMESTAMP DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_wallet_tx_wallet_id ON wallet_transactions(wallet_id);

-- 6. REVIEWS
CREATE TABLE IF NOT EXISTS reviews (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  booking_id  UUID UNIQUE NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
  reviewer_id UUID NOT NULL REFERENCES users(id),
  reviewed_id UUID NOT NULL REFERENCES users(id),
  rating      INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment     TEXT,
  created_at  TIMESTAMP DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_reviews_reviewed_id ON reviews(reviewed_id);

-- 7. MESSAGES
CREATE TABLE IF NOT EXISTS messages (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
  sender_id  UUID NOT NULL REFERENCES users(id),
  content    TEXT NOT NULL,
  is_read    BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_messages_booking_id ON messages(booking_id);

-- SEED ADMIN
-- email: admin@vroomsquad.com  |  password: Admin@1234
INSERT INTO users (name, email, password_hash, role, is_verified)
VALUES (
  'Super Admin',
  'admin@vroomsquad.com',
  '$2a$12$8.h2lncM/0iieCtFFAFmseQxMDlMqmM4mmCLyHgaWL3OdRJJim/OW',
  'admin',
  true
) ON CONFLICT (email) DO NOTHING;

INSERT INTO wallets (user_id)
SELECT id FROM users WHERE email = 'admin@vroomsquad.com'
ON CONFLICT (user_id) DO NOTHING;
