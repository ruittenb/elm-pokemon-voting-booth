
'use strict';

process.title = 'voting-booth-server';

const firebaseAdmin     = require('firebase-admin');
const serviceAccountKey = require('./server/keys/serviceAccountKey.json');
const databaseUrl       = 'https://sprintname-voting-booth.firebaseio.com';
const messagingSenderId = '90828432994';

firebaseAdmin.initializeApp({
    credential: firebaseAdmin.credential.cert(serviceAccountKey),
    messagingSenderId: '90828432994',
    databaseURL: databaseUrl
});

const FirebaseTokenServer = require('./server/tokenserver.js');
const NotificationServer  = require('./server/notificationserver.js');

const PORT        = 4201;
const ADDR        = '0.0.0.0';
const HOST        = (ADDR === '0.0.0.0' ? 'localhost' : ADDR);
const PROTO       = 'http:';
const express     = require('express');
const webserver   = express();
const tokenserver = new FirebaseTokenServer(webserver, firebaseAdmin);
const notifier    = new NotificationServer(firebaseAdmin);

webserver.use(express.static('dist'));

webserver.listen(PORT, ADDR, function () {
    console.log(
        `Server is listening on ${PROTO}//${HOST}:${PORT}`,
        (ADDR === '0.0.0.0' ? '(all interfaces)' : ''));
}).on('error', function (err) {
    console.log(`Unable to listen on ${ADDR}:${PORT} : ${err.code}`);
});

