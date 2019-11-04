'use strict';

/** **********************************************************************
 * NotificationHandler
 *
 * Based on: https://developers.google.com/web/fundamentals/codelabs/push-notifications
 */

module.exports = function ()
{
    /** **********************************************************************
     * Static data
     */
    const applicationServerPublicKey = 'BAISMlq1qjqNKn7L8NZQxo4uFmClIt1V5B6NKuP4OJgvAa3M-CtleIm6pnadD_F_FdywQNXBUu2LT0DkH7lK3AQ';

    /** **********************************************************************
     * Constructor
     */
    let NotificationHandler = function (serviceWorkerRegistration)
    {
        this.swRegistration = serviceWorkerRegistration;
        this.isSubscribed = false;
        let me = this;
        setTimeout(function () { // TODO
            me.pushButton = document.querySelector('.notifications-button');
            if ('PushManager' in window) {
                console.log('Service Worker and Push is supported');
                me.initializeUI();
            } else {
                console.warn('Push messaging is not supported');
                me.pushButton.disabled = true;
            }
        }, 3000);
    };

    NotificationHandler.prototype.urlB64ToUint8Array = function (base64String)
    {
        const padding = '='.repeat((4 - base64String.length % 4) % 4);
        const base64 = (base64String + padding)
            .replace(/\-/g, '+')
            .replace(/_/g, '/');

        const rawData = window.atob(base64);
        const outputArray = new Uint8Array(rawData.length);

        for (let i = 0; i < rawData.length; ++i) {
            outputArray[i] = rawData.charCodeAt(i);
        }
        return outputArray;
    };

    NotificationHandler.prototype.initializeUI = function ()
    {
        // TODO move to Elm
        let me = this;
        this.pushButton.addEventListener('click', function () {
            me.pushButton.disabled = true;
            if (me.isSubscribed) {
                me.unsubscribeUser();
            } else {
                me.subscribeUser();
            }
        });

        // Set the initial subscription value
        me.swRegistration.pushManager.getSubscription()
            .then(function (subscription) {
                me.isSubscribed = !(subscription === null);

                if (me.isSubscribed) {
                    console.log('User IS subscribed.');
                } else {
                    console.log('User is NOT subscribed.');
                }
                me.updateBtn();
            });
    };

    NotificationHandler.prototype.updateBtn = function ()
    {
        if (Notification.permission === 'denied') {
            this.pushButton.disabled = true; // disable the button??
            this.updateSubscriptionOnServer(null);
            return;
        }
        if (this.isSubscribed) {
            this.pushButton.classList.add('subscribed');
        } else {
            this.pushButton.classList.remove('subscribed');
        }

        this.pushButton.disabled = false;
    };

    NotificationHandler.prototype.subscribeUser = function ()
    {
        const applicationServerKey = this.urlB64ToUint8Array(applicationServerPublicKey);
        let me = this;
        this.swRegistration.pushManager.subscribe({
            userVisibleOnly: true,
            applicationServerKey: applicationServerKey
        })
            .then(function (subscription) {
                console.log('User is subscribed.');
                me.updateSubscriptionOnServer(subscription);
                me.isSubscribed = true;
                me.updateBtn();
            })
            .catch(function(err) {
                console.log('Failed to subscribe the user: ', err);
                me.updateBtn();
            });
    };

    NotificationHandler.prototype.unsubscribeUser = function ()
    {
        let me = this;
        this.swRegistration.pushManager.getSubscription()
            .then(function (subscription) {
                if (subscription) {
                    return subscription.unsubscribe();
                }
            })
            .catch(function(error) {
                console.log('Error unsubscribing', error);
            })
            .then(function () {
                me.updateSubscriptionOnServer(null);
                console.log('User is unsubscribed.');
                me.isSubscribed = false;
                me.updateBtn();
            });
    };

    NotificationHandler.prototype.updateSubscriptionOnServer = function (subscription)
    {
        // TODO: Send subscription to application server
        if (subscription) {
            console.log('subscription-json:', JSON.stringify(subscription));
        }
    };

    return NotificationHandler;

}();

/* vim: set ts=4 sw=4 et list: */
