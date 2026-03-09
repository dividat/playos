// sw.js
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', event => event.waitUntil(clients.claim()));
self.addEventListener('fetch', (event) => {
  if (event.request.url.includes('/sw/')) {

    const mockData = "Hello from Service Worker!";
    const mockResponse = new Response(mockData);
    event.respondWith(mockResponse);
  }
});
