# Vroom Squad Carpooling

Full-stack carpooling project with:

- Node.js/Express backend
- PostgreSQL and Redis via Docker
- Flutter mobile app
- Ride booking, driver requests, wallet, QR, cash payments, withdrawals, and admin wallet credit

## Project Folders

```text
carpooling-backend/       Backend API
carpooling application/   Flutter app
```

## Requirements

- Node.js 18+
- npm
- Docker and Docker Compose
- Flutter SDK
- Android Studio or a connected device/emulator

## 1. Start Database Services

From the workspace root:

```bash
cd carpooling-backend
docker compose up -d
```

This starts:

- PostgreSQL on `localhost:5432`
- Redis on `localhost:6381`

The database schema is loaded from:

```text
carpooling-backend/docker/init.sql
```

Default admin account:

```text
email: admin@vroomsquad.com
password: Admin@1234
```

## 2. Start Backend API

From `carpooling-backend`:

```bash
npm install
npm run dev
```

For normal start:

```bash
npm start
```

Backend URL:

```text
http://localhost:3000
```

Health check:

```bash
curl http://localhost:3000/health
```

The backend reads configuration from:

```text
carpooling-backend/.env
```

## 3. Run Flutter App

Open a new terminal:

```bash
cd "carpooling application"
flutter pub get
flutter run -d chroome
```

For web or desktop, the default API URL works:

```text
http://localhost:3000/api/v1
```

For Android emulator, use `10.0.2.2` instead of `localhost`:

```bash
flutter run --dart-define=API_URL=http://10.0.2.2:3000/api/v1
```

For a physical phone, replace the IP with your computer LAN IP:

```bash
flutter run --dart-define=API_URL=http://YOUR_COMPUTER_IP:3000/api/v1
```

## Payment Flow

Wallet:

1. Passenger tops up wallet.
2. Passenger books ride with wallet.
3. Amount is reserved.
4. Driver completes ride.
5. Passenger opens My Bookings and enters account password to authorize payment.
6. Backend settles payment: passenger reserved amount is released/debited and driver wallet is credited.

QR:

1. Driver adds QR payment ID/photo in Driver Wallet.
2. Passenger opens QR payment from My Bookings.
3. Passenger scans/pays and uploads proof.
4. Driver confirms QR received.

Cash:

1. Passenger chooses cash.
2. Driver completes ride.
3. Driver confirms cash received.

If a ride is cancelled, reserved wallet money is released back to the passenger.

## Useful Commands

Backend syntax check:

```bash
cd carpooling-backend
node --check src/modules/bookings/bookings.service.js
node -e "require('./src/app'); console.log('app ok')"
```

Flutter analyzer:

```bash
cd "carpooling application"
flutter analyze
flutter pub get
flutter run -d chrome
```

Stop Docker services:

```bash
cd carpooling-backend
docker compose down
```

Reset database data:

```bash
cd carpooling-backend
docker compose down -v
docker compose up -d
```
