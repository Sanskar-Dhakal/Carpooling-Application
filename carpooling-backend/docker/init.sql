-- ============================================================
-- VroomSquad - Docker database initialization
-- Engine : PostgreSQL 14+
-- Safe   : idempotent for Docker init and local re-runs
-- ============================================================

BEGIN;

-- ============================================================
-- EXTENSIONS
-- ============================================================
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================
-- HELPER: auto-set updated_at on every UPDATE
-- ============================================================
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- TABLE: users
-- ============================================================
CREATE TABLE IF NOT EXISTS users (
  id                   UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  name                 VARCHAR(100)  NOT NULL,
  email                VARCHAR(255)  NOT NULL UNIQUE,
  phone                VARCHAR(20),
  password_hash        TEXT,
  role                 VARCHAR(20)   NOT NULL DEFAULT 'passenger'
                         CHECK (role IN ('driver','passenger','both','admin')),
  is_verified          BOOLEAN       NOT NULL DEFAULT FALSE,
  rating               DECIMAL(2,1)  NOT NULL DEFAULT 0.0
                         CHECK (rating >= 0.0 AND rating <= 5.0),
  profile_photo_url    TEXT,
  fcm_token            TEXT,
  qr_payment_id        VARCHAR(100),
  qr_payment_label     VARCHAR(100),
  qr_payment_image_url TEXT,
  created_at           TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at           TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_email ON users (email);
CREATE INDEX IF NOT EXISTS idx_users_role ON users (role);

DROP TRIGGER IF EXISTS trg_users_updated ON users;
CREATE TRIGGER trg_users_updated
  BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

COMMENT ON TABLE users IS 'App users: drivers, passengers, and admins.';
COMMENT ON COLUMN users.role IS 'driver | passenger | both | admin';
COMMENT ON COLUMN users.rating IS 'Aggregate star rating 0.0-5.0.';
COMMENT ON COLUMN users.qr_payment_id IS 'eSewa, Khalti, FonePay, or other QR merchant/payment ID.';

-- ============================================================
-- TABLE: vehicles
-- ============================================================
CREATE TABLE IF NOT EXISTS vehicles (
  id             UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id      UUID         NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  vehicle_number VARCHAR(20)  NOT NULL UNIQUE,
  type           VARCHAR(50)  NOT NULL,
  capacity       INTEGER      NOT NULL CHECK (capacity > 0),
  created_at     TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_vehicles_driver_id ON vehicles (driver_id);

DROP TRIGGER IF EXISTS trg_vehicles_updated ON vehicles;
CREATE TRIGGER trg_vehicles_updated
  BEFORE UPDATE ON vehicles
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

COMMENT ON TABLE vehicles IS 'Vehicles registered by drivers.';

-- ============================================================
-- TABLE: rides
-- ============================================================
CREATE TABLE IF NOT EXISTS rides (
  id                    UUID           PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id             UUID           NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  origin_address        VARCHAR(255)   NOT NULL,
  origin_lat            DECIMAL(9,6)   NOT NULL,
  origin_lng            DECIMAL(9,6)   NOT NULL,
  destination_address   VARCHAR(255)   NOT NULL,
  destination_lat       DECIMAL(9,6)   NOT NULL,
  destination_lng       DECIMAL(9,6)   NOT NULL,
  route_polyline        TEXT,
  route_distance_m      INTEGER        NOT NULL DEFAULT 0 CHECK (route_distance_m >= 0),
  route_duration_s      INTEGER        NOT NULL DEFAULT 0 CHECK (route_duration_s >= 0),
  departure_time        TIMESTAMPTZ    NOT NULL,
  seats_total           INTEGER        NOT NULL CHECK (seats_total > 0),
  seats_available       INTEGER        NOT NULL CHECK (seats_available >= 0),
  price_per_seat        DECIMAL(8,2)   NOT NULL CHECK (price_per_seat >= 0),
  preferences           JSONB          NOT NULL DEFAULT '{}',
  status                VARCHAR(20)    NOT NULL DEFAULT 'active'
                          CHECK (status IN ('active','in_progress','completed','cancelled')),
  actual_start_time     TIMESTAMPTZ,
  actual_end_time       TIMESTAMPTZ,
  created_at            TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
  CONSTRAINT chk_rides_seats CHECK (seats_available <= seats_total)
);

CREATE INDEX IF NOT EXISTS idx_rides_driver_id ON rides (driver_id);
CREATE INDEX IF NOT EXISTS idx_rides_status ON rides (status);
CREATE INDEX IF NOT EXISTS idx_rides_departure ON rides (departure_time);

DROP TRIGGER IF EXISTS trg_rides_updated ON rides;
CREATE TRIGGER trg_rides_updated
  BEFORE UPDATE ON rides
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

COMMENT ON TABLE rides IS 'Ride offers created by drivers.';
COMMENT ON COLUMN rides.route_polyline IS 'JSON-encoded route points used by the app.';
COMMENT ON COLUMN rides.preferences IS 'JSON bag: music, pets, smoking, and similar ride preferences.';

-- ============================================================
-- TABLE: bookings
-- ============================================================
CREATE TABLE IF NOT EXISTS bookings (
  id                     UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_id                UUID          NOT NULL REFERENCES rides (id) ON DELETE CASCADE,
  passenger_id           UUID          NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  seats_booked           INTEGER       NOT NULL CHECK (seats_booked > 0),
  total_amount           DECIMAL(8,2)  NOT NULL CHECK (total_amount >= 0),
  payment_method         VARCHAR(10)   NOT NULL DEFAULT 'cash'
                           CHECK (payment_method IN ('wallet','qr','cash')),
  status                 VARCHAR(20)   NOT NULL DEFAULT 'pending'
                           CHECK (status IN ('pending','confirmed','rejected','cancelled','completed')),
  payment_status         VARCHAR(30)   NOT NULL DEFAULT 'pending'
                           CHECK (payment_status IN (
                             'pending','passenger_confirmed',
                             'driver_confirmed','settled','disputed'
                           )),
  payment_screenshot_url TEXT,
  payment_confirmed_at   TIMESTAMPTZ,
  created_at             TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at             TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_bookings_ride_passenger UNIQUE (ride_id, passenger_id)
);

CREATE INDEX IF NOT EXISTS idx_bookings_ride_id ON bookings (ride_id);
CREATE INDEX IF NOT EXISTS idx_bookings_passenger_id ON bookings (passenger_id);

DROP TRIGGER IF EXISTS trg_bookings_updated ON bookings;
CREATE TRIGGER trg_bookings_updated
  BEFORE UPDATE ON bookings
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

COMMENT ON TABLE bookings IS 'Passenger booking for a ride.';
COMMENT ON COLUMN bookings.payment_screenshot_url IS 'QR payment proof uploaded by passenger.';

-- ============================================================
-- TABLE: wallets
-- ============================================================
CREATE TABLE IF NOT EXISTS wallets (
  id         UUID           PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID           NOT NULL UNIQUE REFERENCES users (id) ON DELETE CASCADE,
  balance    DECIMAL(10,2)  NOT NULL DEFAULT 0.00 CHECK (balance >= 0),
  reserved   DECIMAL(10,2)  NOT NULL DEFAULT 0.00 CHECK (reserved >= 0),
  currency   CHAR(3)        NOT NULL DEFAULT 'NPR',
  updated_at TIMESTAMPTZ    NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_wallets_user_id ON wallets (user_id);

DROP TRIGGER IF EXISTS trg_wallets_updated ON wallets;
CREATE TRIGGER trg_wallets_updated
  BEFORE UPDATE ON wallets
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

COMMENT ON TABLE wallets IS 'In-app wallet; one per user.';
COMMENT ON COLUMN wallets.reserved IS 'Amount locked for in-progress rides.';
COMMENT ON COLUMN wallets.currency IS 'ISO 4217 code. Default NPR.';

-- ============================================================
-- TABLE: wallet_transactions
-- ============================================================
CREATE TABLE IF NOT EXISTS wallet_transactions (
  id          UUID           PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id   UUID           NOT NULL REFERENCES wallets (id) ON DELETE CASCADE,
  type        VARCHAR(30)    NOT NULL
                CHECK (type IN (
                  'credit','debit','reserve','release',
                  'withdrawal_request','withdrawal_paid'
                )),
  amount      DECIMAL(10,2)  NOT NULL CHECK (amount >= 0),
  description TEXT,
  ride_id     UUID           REFERENCES rides (id) ON DELETE SET NULL,
  created_at  TIMESTAMPTZ    NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_wallet_tx_wallet_id ON wallet_transactions (wallet_id);
CREATE INDEX IF NOT EXISTS idx_wallet_tx_ride_id ON wallet_transactions (ride_id);

COMMENT ON TABLE wallet_transactions IS 'Immutable ledger of every wallet movement.';

-- ============================================================
-- TABLE: payments
-- ============================================================
CREATE TABLE IF NOT EXISTS payments (
  id         UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id UUID          NOT NULL REFERENCES bookings (id) ON DELETE CASCADE,
  amount     DECIMAL(8,2)  NOT NULL CHECK (amount >= 0),
  method     VARCHAR(10)   NOT NULL CHECK (method IN ('wallet','qr','cash')),
  status     VARCHAR(20)   NOT NULL DEFAULT 'pending'
                         CHECK (status IN ('pending','completed','refunded','disputed')),
  created_at TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_payments_booking UNIQUE (booking_id)
);

CREATE INDEX IF NOT EXISTS idx_payments_booking_id ON payments (booking_id);

COMMENT ON TABLE payments IS 'Payment record for a booking.';

-- ============================================================
-- TABLE: reviews
-- ============================================================
CREATE TABLE IF NOT EXISTS reviews (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id  UUID        NOT NULL REFERENCES bookings (id) ON DELETE CASCADE,
  reviewer_id UUID        NOT NULL REFERENCES users (id),
  reviewed_id UUID        NOT NULL REFERENCES users (id),
  rating      INTEGER     NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment     TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_reviews_booking_reviewer UNIQUE (booking_id, reviewer_id)
);

CREATE INDEX IF NOT EXISTS idx_reviews_reviewed_id ON reviews (reviewed_id);
CREATE INDEX IF NOT EXISTS idx_reviews_reviewer_id ON reviews (reviewer_id);

COMMENT ON TABLE reviews IS 'Bidirectional post-ride reviews.';

-- ============================================================
-- TABLE: messages
-- ============================================================
CREATE TABLE IF NOT EXISTS messages (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id UUID        NOT NULL REFERENCES bookings (id) ON DELETE CASCADE,
  sender_id  UUID        NOT NULL REFERENCES users (id),
  content    TEXT        NOT NULL,
  is_read    BOOLEAN     NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_messages_booking_id ON messages (booking_id);
CREATE INDEX IF NOT EXISTS idx_messages_sender_id ON messages (sender_id);

COMMENT ON TABLE messages IS 'In-app chat scoped to a booking.';

-- ============================================================
-- TABLE: gps_locations
-- ============================================================
CREATE TABLE IF NOT EXISTS gps_locations (
  id          UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id  UUID          NOT NULL REFERENCES bookings (id) ON DELETE CASCADE,
  lat         DECIMAL(9,6)  NOT NULL,
  lng         DECIMAL(9,6)  NOT NULL,
  location    VARCHAR(255),
  recorded_at TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_gps_booking_id ON gps_locations (booking_id);
CREATE INDEX IF NOT EXISTS idx_gps_recorded_at ON gps_locations (recorded_at);

COMMENT ON TABLE gps_locations IS 'GPS breadcrumbs recorded during a live ride.';

-- ============================================================
-- SEED: admin user + wallet
-- email: admin@vroomsquad.com
-- password: Admin@1234
-- ============================================================
INSERT INTO users (
  name, email, password_hash, role, is_verified
) VALUES (
  'Super Admin',
  'admin@vroomsquad.com',
  '$2a$12$8.h2lncM/0iieCtFFAFmseQxMDlMqmM4mmCLyHgaWL3OdRJJim/OW',
  'admin',
  TRUE
)
ON CONFLICT (email) DO NOTHING;

INSERT INTO wallets (user_id, currency)
SELECT id, 'NPR'
FROM users
WHERE email = 'admin@vroomsquad.com'
ON CONFLICT (user_id) DO NOTHING;

COMMIT;
