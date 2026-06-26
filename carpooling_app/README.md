# Vroom Squad Flutter App

Flutter client for the Vroom Squad carpooling system.

## Run

Install packages:

```bash
flutter pub get
flutter run -d chrome
```

Run on web/desktop:

```bash
flutter run
```

Run on Android emulator:

```bash
flutter run --dart-define=API_URL=http://10.0.2.2:3000/api/v1
```

Run on a physical phone:

```bash
flutter run --dart-define=API_URL=http://YOUR_COMPUTER_IP:3000/api/v1
```

## Backend Required

Start the backend first:

```bash
cd ../carpooling-backend
docker compose up -d
npm install
npm run dev
```

Default backend API:

```text
http://localhost:3000/api/v1
```

## Check Code

```bash
flutter analyze
```

## Main Screens

- Passenger home
- Driver home
- Admin home
- Search rides
- Post ride
- My bookings
- Driver booking requests
- Wallet and transaction history
- QR payment
- Admin wallet credit and withdrawal requests
