# Vroom Squad Operating Guide

This guide explains how to start and use the carpooling project from a fresh terminal.

## Project Folders

Run backend commands from:

```bash
cd "/home/sanskar/Carpooling A/carpooling-backend"
```

Run Flutter commands from:

```bash
cd "/home/sanskar/Carpooling A/carpooling application"
```

## 1. Start Database Services

From the backend folder:

```bash
docker compose up -d
```

This starts:

- PostgreSQL on port `5432`
- Redis on port `6381`

Check containers:

```bash
docker compose ps
```

## 2. Start Backend API

From the backend folder:

```bash
npm install
npm run dev
```

Backend health check:

```bash
curl http://localhost:3000/health
```

Expected backend API base URL:

```text
http://localhost:3000/api/v1
```

## 3. Start Flutter App

From the Flutter folder:

```bash
flutter pub get
flutter run
```

For Chrome/web:

```bash
flutter run -d chrome
```

For Android emulator, use:

```bash
flutter run --dart-define=API_URL=http://10.0.2.2:3000/api/v1
```

For Linux desktop or Chrome on the same machine, the default API URL works:

```text
http://localhost:3000/api/v1
```

## 4. Login And Register

Admin seed account:

```text
Email: admin@vroomsquad.com
Password: Admin@1234
```

For testing, create at least two users:

- One driver account
- One passenger account

Use the app register screen and choose the correct role.

## 5. Driver Ride Flow

1. Login as driver.
2. Open `Post a Ride`.
3. Search and select origin.
4. Search and select destination.
5. Set seats, price, preferences, and departure time.
6. Tap `Post Ride`.
7. Open `My Rides` to manage posted rides.

Routes use:

- Nominatim for address search
- OSRM for route calculation
- OpenStreetMap tiles for maps

Internet is needed unless local OSRM/Nominatim services are configured.

## 6. Passenger Search And Booking Flow

1. Login as passenger.
2. Open `Find a Ride`.
3. Search and select pickup.
4. Search and select drop-off.
5. Tap `Search Rides`.
6. Open a ride detail page.
7. Select seats.
8. Select payment method:
   - `Cash`
   - `Wallet`
   - `QR`
9. Tap `Request Booking`.
10. Open `My Bookings` to see booking status.

Wallet note:

New wallets start with `0` balance. Wallet bookings require enough wallet balance, so use `cash` or `qr` unless you manually credit the wallet in the database.

## 7. Driver Booking Accept/Reject Flow

1. Login as driver.
2. Open `Requests`.
3. Review pending passenger booking requests.
4. Tap `Accept` or `Reject`.

When accepted:

- Booking status becomes `confirmed`
- Ride seats available are reduced

When rejected:

- Booking status becomes `rejected`
- Wallet reservation is released if payment method was `wallet`

## 8. Firebase Notifications

Backend FCM support is installed.

To enable real push notifications, set this in backend `.env`:

```env
FIREBASE_SERVICE_ACCOUNT_JSON={"type":"service_account","project_id":"..."}
```

The backend also needs users to have `fcm_token` saved. The endpoint already exists:

```text
PUT /api/v1/users/fcm-token
```

If Firebase credentials or FCM tokens are missing, the backend logs notification fallback messages and keeps the booking flow working.

## 9. Useful Checks

Backend syntax/load check:

```bash
cd "/home/sanskar/Carpooling A/carpooling-backend"
node -e "require('./src/app'); console.log('app loaded')"
```

Flutter checks:

```bash
cd "/home/sanskar/Carpooling A/carpooling application"
flutter analyze
flutter test
```

## 10. Common Problems

Backend cannot connect to database:

```bash
docker compose up -d
```

Then restart backend:

```bash
npm run dev
```

Android emulator cannot reach backend:

Use:

```bash
flutter run --dart-define=API_URL=http://10.0.2.2:3000/api/v1
```

Linux/Chrome cannot reach backend:

Check backend is running:

```bash
curl http://localhost:3000/health
```

Address search or route calculation fails:

- Check internet connection.
- Public Nominatim/OSRM services may rate-limit sometimes.

Snap Flutter sandbox error:

If Flutter says `snap-confine has elevated permissions`, run the command from a normal terminal outside restricted tooling.

