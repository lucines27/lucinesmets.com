const CACHE_NAME = 'lucine-dashboard-v1';
const ASSETS = [
  '/perso/',
    '/perso/index.html',
      '/perso/manifest.json',
        'https://fonts.googleapis.com/css2?family=DM+Sans:wght@300;400;500;600&family=DM+Mono:wght@400;500&display=swap',
          'https://cdn.jsdelivr.net/npm/chart.js@4/dist/chart.umd.min.js'
          ];

          self.addEventListener('install', e => {
            e.waitUntil(caches.open(CACHE_NAME).then(cache => cache.addAll(ASSETS)));
            });

            self.addEventListener('activate', e => {
              e.waitUntil(caches.keys().then(keys =>
                  Promise.all(keys.filter(k => k !== CACHE_NAME).map(k => caches.delete(k)))
                    ));
                    });

                    self.addEventListener('fetch', e => {
                      e.respondWith(
                          caches.match(e.request).then(cached => cached || fetch(e.request))
                            );
                            });
