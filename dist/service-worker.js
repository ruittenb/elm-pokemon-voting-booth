
/**
 * Serviceworker for Pokémon Sprint Name Voting Booth
 */

const version = 'v15.7.0';
const siteUrl = 'https://voting-booth.dokube.profortool.com/';
const cacheName = 'sprintname-voting-booth-' + version;
const imageDir = '/pokeart/'
const placeHolder = 'silhouette.png';
const filesToCache = [
    '/',
    '/index.html',
    '/index.html?utm_source=pwa',
    '/bundle.js',
    '/service-worker.js',
    '/lightbox.min.js',
    '/lightbox.min.css',
    '/normalize.min.css',
    '/voting-booth.min.css',
    '/font-awesome.min.css',
    '/fonts/fontawesome-webfont.woff',
    '/icons/bell.png',
    '/icons/bell-bw.png',
    '/icons/cross.png',
    '/icons/find-bw.png',
    '/icons/lock-bw.png',
    '/icons/lock-open-bw.png',
    '/icons/maintenance.png',
    '/images/lb-close.png',
    '/images/lb-loading.gif',
    '/images/lb-next.png',
    '/images/lb-prev.png',
    '/images/loading-busy.gif',
    '/images/loading-circle.svg',
    '/images/loading-error.png',
    '/images/loading-shade.png',
    '/images/ribbon.png',
    '/favicons/apple-touch-icon.png',
    '/favicons/favicon.ico',
    '/favicons/favicon-16x16.png',
    '/favicons/favicon-32x32.png',
    '/favicons/favicon-57x57.png',
    '/favicons/favicon-58x58.png',
    '/favicons/favicon-72x72.png',
    '/favicons/favicon-114x114.png',
    '/favicons/favicon-128x128.png',
    '/favicons/favicon-144x144.png',
    '/favicons/favicon-152x152.png',
    '/favicons/favicon-192x192.png',
    '/favicons/favicon-256x256.png',
    '/favicons/favicon-512x512.png',
    imageDir + placeHolder
];

/**
 * Cache important files when installing
 */
self.addEventListener('install', function (event) {
    console.log('[ServiceWorker] Installing');
    self.skipWaiting();
    event.waitUntil(
        caches.open(cacheName).then(function (cache) {
            console.log('[ServiceWorker] Caching app shell');
            return cache.addAll(filesToCache);
        })
    );
});

/**
 * Remove old caches when activating
 */
self.addEventListener('activate', function (event) {
    console.log('[ServiceWorker] Activating');
    event.waitUntil(
        caches.keys().then(function (keyList) {
            return Promise.all(keyList.map(function (key) {
                if (key !== cacheName) {
                    console.log('[ServiceWorker] Removing old cache', key);
                    return caches.delete(key);
                }
            }));
        })
    );
    return self.clients.claim();
});

/**
 * Listen to arriving push notifications
 */
self.addEventListener('push', function(event) {
    console.log('[ServiceWorker] Push notification received');
    const title = 'Push Codelab';
    const options = {
        body: event.data.text(),
        //badge: 'images/badge.png',
        icon: 'favicons/favicon-144x144.png'
    };
    event.waitUntil(
        self.registration.showNotification(title, options)
    );
});

/**
 * Open the main site when the notification is clicked
 */
self.addEventListener('notificationclick', function(event) {
    console.log('[ServiceWorker] Notification click received');
    event.notification.close();
    event.waitUntil(
        clients.openWindow(siteUrl)
    );
});

/**
 * Stale-while-revalidate:
 * If found in cache, then send the version from cache.
 * Meanwhile, fetch the new version over the network and cache it.
 *
 * @see https://jakearchibald.com/2014/offline-cookbook/#stale-while-revalidate
 */
self.addEventListener('fetch', function (event) {
    if (event.request.method !== 'GET') {
        // We don't handle the request, but don't block it either
        return;
    }
    var requestFile = event.request.url.replace(/^https?:\/\/[^\/]+/, '').replace(/#.*/, '');
    if (filesToCache.indexOf(requestFile) !== -1) {
        // This file should be in the cache
        return cacheThenNetwork(event);
    }
    else if (requestFile.indexOf(imageDir) === 0) {
        // This is an image for which a placeholder should be shown
        return networkThenFallback(event);
    }
    // In all other cases: just don't block the default
});

/**
 * All important framework files are served from the cache first,
 * while the cache is refreshed.
 */
function cacheThenNetwork(event) {
    event.respondWith(
        caches.open(cacheName).then(function (cache) {
            return cache.match(event.request).then(function (cacheResponse) {
                var fetchPromise = fetch(event.request).then(function (networkResponse) {
                    cache.put(event.request, networkResponse.clone());
                    return networkResponse;
                }).catch(function () {
                    //console.log('[ServiceWorker] could not fetch:', event.request.url);
                });
                return cacheResponse || fetchPromise;
            });
        })
    );
}

/**
 * All artwork images are served from the network only, but if
 * unreachable, serve a placeholder image from the cache.
 */
function networkThenFallback(event) {
    event.respondWith(
        fetch(event.request)
        .then(function (response) {
            return response;
        }, unableToFetch)
        .catch(unableToFetch)
    );
}

/**
 * Serve a placeholder image from the cache.
 */
function unableToFetch() {
    return caches.open(cacheName).then(function (cache) {
        return cache.match(imageDir + placeHolder).then(function (response) {
            return response;
        });
    });
}
