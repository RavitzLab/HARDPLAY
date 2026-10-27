import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const projectRoot = resolve(fileURLToPath(new URL("..", import.meta.url)));
const workerPath = resolve(projectRoot, "dist/server/index.js");
const manifestPath = resolve(projectRoot, "dist/.openai/hosting.json");

const [source, manifest] = await Promise.all([
  readFile(workerPath, "utf8"),
  readFile(manifestPath, "utf8"),
]);
JSON.parse(manifest);

// A data URL forces ESM parsing even though the generated output has no package.json.
const moduleUrl = `data:text/javascript;base64,${Buffer.from(source).toString("base64")}`;
const workerModule = await import(moduleUrl);
assert.equal(
  typeof workerModule.default?.fetch,
  "function",
  `${pathToFileURL(workerPath)} must export default.fetch`,
);

console.log("Artifact is valid ESM and exports default.fetch");

const request=path=>workerModule.default.fetch(new Request('https://hardplay.test'+path));
for(const path of ['/', '/site.css', '/logo.png', '/grid.ttf', '/OFL.txt', '/sw.js','/app/sw.js']) assert.equal((await request(path)).status,200,path);
for(const path of ['/app','/app/','/app/index.html']) assert.equal((await request(path)).status,302,path);
for(const path of ['/app.mjs','/appearance.mjs','/manifest.webmanifest','/api/cloud','/app/app.mjs','/app/api/cloud']) assert.equal((await request(path)).status,410,path);
const html=await (await request('/')).text();
assert.ok(html.includes('v0.45.0-beta.5/HARDPLAY-0.45.0-macOS-arm64.dmg'));
assert.ok(!html.includes('<audio')&&!html.includes('app.mjs'));
const sw=await (await request('/sw.js')).text();assert.ok(sw.includes('unregister()')&&sw.includes('hardplay-shell-')&&!sw.includes('indexedDB'));
console.log('Mac download page and assets passed; legacy app/cloud routes retired; shell-only service worker retirement passed');

for (const [path,lang,dir,heading] of [['/','en',null,'Your set.'],['/ru/','ru','ltr','Ваш сет.'],['/he/','he','rtl','הסט שלכם.']]) {
  const response=await request(path); assert.equal(response.status,200,path);
  const page=await response.text();
  assert.ok(page.includes(`lang="${lang}"`),path+' language');
  if(dir)assert.ok(page.includes(`dir="${dir}"`),path+' direction');
  assert.ok(page.includes(heading),path+' translated hero');
  assert.equal((page.match(/class="product-shot/g)||[]).length,9,path+' screenshot count');
  assert.equal((page.match(/aria-current="page"/g)||[]).length,1,path+' current language');
  assert.ok(page.includes('id="protection"'),path+' lock documentation');
  assert.ok(!page.includes('<script'),path+' no client runtime');
  for (const match of page.matchAll(/(?:src|href)="(\/screen-[^"]+\.jpg)"/g)) {
    const image=await request(match[1]); assert.equal(image.status,200,match[1]);
    assert.equal(image.headers.get('content-type'),'image/jpeg');
    const data=new Uint8Array(await image.arrayBuffer()); assert.deepEqual([...data.slice(0,2)],[255,216]);
  }
}
for(const path of ['/ru','/he','/en','/en/'])assert.equal((await request(path)).status,200,path);
console.log('EN/RU/HE static pages, RTL, current-language links, 9 real JPEG screenshots and lock guide passed');
