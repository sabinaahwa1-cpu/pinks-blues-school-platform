// Network-only service worker: do not cache student, staff or finance records.
self.addEventListener('install', event => { self.skipWaiting(); });
self.addEventListener('activate', event => { event.waitUntil(self.clients.claim()); });
self.addEventListener('fetch', event => { /* Network request proceeds without caching. */ });
