/**
 * Server that:
 * - listens for HTTP POST requests
 * - takes a JWT token
 * - validates it
 * - verifies that it contains a valid email address
 * - returns a valid Firebase token
 *
 * This code runs in a separate process for two reasons:
 * - it leans on the 'firebase-admin' and 'jsonwebtoken' modules
 * - it reads the secret Auth0 and Firebase keys from the 'keys'
 *   directory without having to reveal them to the client
 *
 * Usage:
 * - POST a string of the form:
 *   {
 *     "jwtToken": <string>
 *   }
 *
 * Result:
 * - A JSON response of the form:
 *   {
 *     "success"      : <boolean>,
 *     "firebaseToken": <string>,         // if success == true
 *     "status"       : <int statuscode>, // if success == false
 *     "message"      : <string>,         // if success == false
 *   }
 *
 * Possible status codes:
 *   success == false:
 *     400 : Referer not allowed (CORS)
 *     400 : Missing or empty property "jwtToken"
 *     400 : JWT token malformed
 *     400 : JWT token invalid
 *     403 : JWT token expired
 *     500 : Unable to obtain Firebase token
 *   success == true:
 *     200 : OK, returns Firebase token
 *
 * See also:
 * - http://blog.pixelastic.com/2017/10/28/authenticating-to-firebase-from-a-server/
 * - http://blog.pixelastic.com/2017/11/01/firebase-authentication-with-auth0/
 * - https://github.com/auth0/node-jsonwebtoken
 */

'use strict';

const FirebaseTokenServer = (function () {

    const PORT = 4202;
    const AUTHORIZED_USERS = /^[^@]+@proforto\.nl$/;
    const DATABASE_URL = 'https://sprintname-voting-booth.firebaseio.com';
    const DEBUG_EXPIRED_TOKEN = false;
    const VALID_REFERERS = [
        'http://localhost:4201',
        'http://votingbooth.ddns.net:4201',
        'https://voting-booth.kube.profortool.com'
    ];

    const fs         = require('fs');
    const express    = require('express');
    const bodyParser = require('body-parser');
    const jwt        = require('jsonwebtoken');

    /**
     * Constructor.
     */
    let FirebaseTokenServer = function ()
    {
        this.publicKey = fs.readFileSync('./keys/public-auth0.key');
        this.serviceAccountKey = require('./keys/serviceAccountKey.json');
        this.firebaseAdmin = require('firebase-admin');
        this.firebaseAdmin.initializeApp({
            credential: this.firebaseAdmin.credential.cert(this.serviceAccountKey),
            databaseURL: DATABASE_URL
        });
        this.server = express();
        this.startServer();
    };

    /**
     * Start the express server. Install processRequest() as handler.
     */
    FirebaseTokenServer.prototype.startServer = function ()
    {
        // Parses the body test as JSON and exposes the resulting object on request.body
        //        this.server.use(bodyParser.json());
        this.server.use(bodyParser.urlencoded({ extended: false }));
        this.server.use(function (err, request, response, callback) {
            response.status(err.status).json({ ...err, success : false });
            callback();
        });
        this.server.post('/', this.processRequest.bind(this));
        this.server.options('/', this.processOptionsRequest.bind(this));
        this.server.listen(PORT, function (err) {
            if (err) {
                return console.log('Unable to listen on port', PORT, ': ', err);
            }
            console.log('Server is listening on port', PORT);
        });
    };

    /**
     * Reply to an OPTIONS request. This is required for Cross-Origin AJAX requests.
     * @see https://techblog.constantcontact.com/software-development/using-cors-for-cross-domain-ajax-requests/
     *
     * TODO This function does not seem to get called?
     */
    FirebaseTokenServer.prototype.processOptionsRequest = function (request, response)
    {
        let origin = req.get('origin');
        console.log(`Received OPTIONS request from ${origin}`);
        /**
         * validate the origin
         */
        if (!this.validateOrigin(origin, response)) {
            response.send(400);
        } else {
            response.send(200);
        }
    };

    /**
     * Process a request. Takes a JWT web token as JSON as input and returns
     * a firebase token.
     */
    FirebaseTokenServer.prototype.processRequest = function (request, response)
    {
        let referer = request.headers.referer;
        let status, userData, firebaseToken;
        console.log(`Received POST request from ${referer}`);
        /**
         * Validate the referer
         */
        if (!this.validateOrigin(referer, response)) {
            status = 400;
            return response.status(status).json({
                success: false,
                status,
                message: 'Referer not allowed'
            });
        }

        /**
         * For debugging: in case a token has expired
         */
        if (DEBUG_EXPIRED_TOKEN) {
            status = 403;
            return response.status(status).json({
                success: false,
                status,
                message: 'JWT token has expired'
            });
        }
        /**
         * Try to retrieve JWT token
         */
        let jwtToken = request.body.jwtToken;
        if (!jwtToken) {
            status = 400;
            return response.status(status).json({
                success: false,
                status,
                message: 'Missing or empty property "jwtToken"'
            });
        };
        /**
         * Try to validate JWT token
         */
        try {
            userData = this.validateJwtToken(jwtToken);
        }
        catch (e) {
            status = e.status || 400;
            return response.status(status).json({
                success: false,
                status,
                message: e.message
            });
        }
        /**
         * Try to issue firebase token
         */
        this.issueFirebaseToken(userData)
            .then(function (firebaseToken) {
                return response.status(200).json({
                    success : true,
                    firebaseToken
                });
            })
            .catch(function (e) {
                status = e.status || 500;
                return response.status(status).json({
                    success: false,
                    status,
                    //message: JSON.stringify(e)
                    message: e.message
                });
            });
    };

    /**
     * Validate the referer/origin and fix the headers to allow CORS
     *
     * We could have chosen for https://www.npmjs.com/package/cors
     */
    FirebaseTokenServer.prototype.validateOrigin = function (referer, response)
    {
        let origin = referer.replace(/\/(index\.html)?$/, '');
        let valid = VALID_REFERERS.includes(origin);
        if (valid) {
            response.header('Access-Control-Allow-Origin', origin);
            response.header('Access-Control-Allow-Methods', 'POST,OPTIONS');
            response.header('Access-Control-Allow-Headers', 'Content-Type, Authorization, Content-Length, X-Requested-With');
        }
        return valid;
    };

    /**
     * Validate the JWT token.
     * Also validate that this is an authorized account.
     * Throw an error if invalid or unauthorized.
     *
     * See also https://github.com/auth0/node-jsonwebtoken
     *
     * @return userData from JWT token if successful.
     */
    FirebaseTokenServer.prototype.validateJwtToken = function (jwtToken)
    {
        let userData;
        try {
            userData = jwt.verify(jwtToken, this.publicKey);
            if (!userData) {
                throw new Error('Not allowed: JWT token could not be validated');
            }
            if (!userData.email_verified) {
                throw new Error('Not allowed: this email address has not been verified');
            }
            if (!userData.email.match(AUTHORIZED_USERS)) {
                throw new Error('Not allowed: this email address is not authorized');
            }
        }
        catch (e) {
            let message = e.message.replace(/^jwt /, 'JWT ');
            let status = e.name === 'TokenExpiredError' ? 403 : 400;
            throw({ status, message });
        }
        return userData;
    };

    /**
     * use the service account key to authenticate with the firebase server
     */
    FirebaseTokenServer.prototype.issueFirebaseToken = function (userData)
    {
        return this.firebaseAdmin.auth().createCustomToken(userData.email);
    };

    return FirebaseTokenServer;
})();

const server = new FirebaseTokenServer();

