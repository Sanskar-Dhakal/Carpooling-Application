importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyB5Us1g8FJ_qH7rfjVgJVAP_ddKZtIVr34',
  authDomain: 'vroom-squad.firebaseapp.com',
  projectId: 'vroom-squad',
  appId: '1:1047074779085:web:1ebef6900f0da7780a1e84',
  messagingSenderId: '1047074779085',
});

firebase.messaging();
