# HARDPLAY - Mac download site

The hosted website serves a Mac download page only. Browser playback, PWA installation, legacy app scripts and cloud proxy routes return HTTP 410. /app/ redirects to the download page.

mac/ contains the landing page, local Grid font, logo and retiring service worker. It removes only former hardplay-shell- caches, unregisters itself and navigates online clients to the download page. Audio libraries and user files are not deleted. Already offline copies cannot receive retirement until they reconnect.

Legacy player source remains under public/ for history and tests, but is not included in the hosted artifact.

Build and verify: node scripts/build.mjs; node --test tests/*.test.mjs; node scripts/validate-artifact.mjs. Output: dist/server/index.js. Hosting identity remains local.
