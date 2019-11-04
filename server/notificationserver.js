/**
 * This code runs in a separate process for two reasons:
 * - it leans on the 'firebase-admin' module
 * - it reads the secret Firebase key from the 'keys'
 *   directory without having to reveal it to the client
 *
 *
 * See also:
 * https://firebase.google.com/docs/cloud-messaging
 * https://console.developers.google.com/apis/api/fcm.googleapis.com/overview?project=sprintname-voting-booth
 */

'use strict';

const firebase          = require('firebase/app');
const messaging = require('firebase/messaging'); // TODO



const firebaseConfig =
    { apiKey : "AIzaSyAm4--Q2MjVWGZYW-IC8LPZARXJq-XyHXA"
    , databaseURL : "https://sprintname-voting-booth.firebaseio.com"
    , authDomain : "sprintname-voting-booth.firebaseapp.com"
    , storageBucket :  "sprintname-voting-booth.appspot.com"
    , messagingSenderId : "90828432994"
    };

module.exports = (function () {

    // These values must stay private.
    let serviceAccountKey;

    /**
     * Constructor.
     */
    let NotificationServer = function (firebaseAdmin)
    {
        this.firebaseAdmin = firebaseAdmin;
        var registrationToken = 'BDx87RnRIMPIbumyRtZeQ3M-aAfRxIJ2n49SvKIMbK-FVLyS-mqmlK3aLSVy4U-VIm8pSe0d9xZ-tJBz3Mr9_2g';

        var message = {
            data: {
                score: '850',
                time: '2:45'
            },
            token: registrationToken
        };

        // Send a message to the device corresponding to the provided
        // registration token.
        firebase.initializeApp(firebaseConfig);
        //const messaging = firebase.messaging();
        messaging.usePublicVapidKey('BDx87RnRIMPIbumyRtZeQ3M-aAfRxIJ2n49SvKIMbK-FVLyS-mqmlK3aLSVy4U-VIm8pSe0d9xZ-tJBz3Mr9_2g');
        this.firebaseAdmin.messaging().send(message)
            .then((response) => {
                // Response is a message ID string.
                console.log('Successfully sent message:', response);
            })
            .catch((error) => {
                console.log('Error sending message:', error);
            });
    };



    return NotificationServer;
})();

