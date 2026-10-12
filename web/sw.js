/* KOKURO service worker: network-first with cache fallback.
   Keeps the app shell available offline after a first successful load,
   while still always picking up fresh builds of main.dart.js. */
const CACHE_NAME = 'kokuro-v2';

self.addEventListener('install', (event) => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) =>
        Promise.all(keys.filter((k) => k !== CACHE_NAME).map((k) => caches.delete(k))),
      )
      .then(() => self.clients.claim()),
  );
});

self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);
  if (url.origin !== location.origin) return;

  const request = event.request;
  const htmlLike =
    request.mode === 'navigate' ||
    url.pathname === '/' ||
    url.pathname.endsWith('/index.html');

  event.respondWith(
    fetch(request)
      .then((response) => {
        if (response && response.ok) {
          const clone = response.clone();
          caches.open(CACHE_NAME).then((cache) => cache.put(request, clone));
        }
        return response;
      })
      .catch(() =>
        caches.match(request).then(
          (hit) => hit || (htmlLike ? caches.match('/index.html') : Response.error()),
        ),
      ),
  );
});