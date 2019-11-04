'use strict';

/** **********************************************************************
 * includes
 */

require('./version.js');

// Javascript "bridges" to Auth0, Firebase and the Elm app
const Authentication      = require('./Authentication.js');
const Database            = require('./Database.js');
const VotingApp           = require('./VotingApp.js');
const NotificationHandler = require('./NotificationHandler.js');

let notificationHandler;

/** **********************************************************************
 * Register serviceworker if supported
 */

if ('serviceWorker' in navigator) {
    navigator.serviceWorker
        .register('/service-worker.js')
        .then(function(registration) {
            console.log('Service Worker Registered with scope', registration.scope);
            notificationHandler = new NotificationHandler(registration);
        })
        .catch(function (err) {
            console.log('ServiceWorker registration failed:', err);
        });
}

/** **********************************************************************
 * main
 */

const auth = new Authentication();
const credentials = auth.retrieveCredentials();

const votingApp = new VotingApp();
votingApp.run(credentials);
auth.register(votingApp.elmClient);

const database = new Database(votingApp.elmClient);

window.votingApp = votingApp;

/** **********************************************************************
 * fix styling issues with :hover on mobile devices
 *
 * @see https://www.prowebdesign.ro/how-to-deal-with-hover-on-touch-screen-devices/
 */

if ('ontouchstart' in document.documentElement) {
    document.body.classList.remove('no-touch');
}

