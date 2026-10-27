// Retire only the former player shell. Audio libraries and user files remain untouched.
self.addEventListener('install',event=>event.waitUntil(self.skipWaiting()));
self.addEventListener('activate',event=>event.waitUntil((async()=>{
  for(const key of await caches.keys())if(key.startsWith('hardplay-shell-'))await caches.delete(key);
  await self.clients.claim();
  // Unregister before navigation so activation cannot wait on its own fetch handler.
  await self.registration.unregister();
  for(const client of await self.clients.matchAll({type:'window'})){
    const url=new URL(client.url);if(url.pathname.startsWith('/app'))url.pathname='/';
    client.navigate(url.href);
  }
})()));
self.addEventListener('fetch',event=>{
  if(event.request.mode==='navigate')event.respondWith(fetch(new Request(event.request,{cache:'no-store'})).catch(()=>new Response('HARDPLAY is now available only for Mac. Download: https://github.com/RavitzLab/HARDPLAY/releases/tag/v0.45.0-beta.5',{headers:{'content-type':'text/plain; charset=utf-8'}})));
});
