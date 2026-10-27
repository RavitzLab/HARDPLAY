// Remove only obsolete service-worker control; never touch audio storage or playlists.
(async()=>{
  if(!('serviceWorker' in navigator))return;
  const controlled=!!navigator.serviceWorker.controller;
  const registrations=await navigator.serviceWorker.getRegistrations();
  await Promise.all(registrations.filter(r=>r.scope.startsWith(location.origin+'/')).map(r=>r.unregister()));
  if(controlled&&!sessionStorage.getItem('hardplay-shell-retired-v2')){
    sessionStorage.setItem('hardplay-shell-retired-v2','1');
    location.reload();
  }
})().catch(()=>{});
