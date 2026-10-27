import test from 'node:test';
import assert from 'node:assert/strict';
import {presets,normalizeTheme,loadTheme,defaultPreset} from '../public/appearance.mjs';
test('appearance restores safe bounds from invalid saved preferences',()=>{
 const t=normalizeTheme({preset:'missing',accent:'url(javascript:bad)',buttonSize:999,textScale:-2,opacity:'NaN',radius:-1});
 assert.equal(t.preset,'Modular Grid');assert.equal(t.accent,'#b7c848');assert.equal(t.buttonSize,90);assert.equal(t.textScale,.9);assert.equal(t.opacity,1);assert.equal(t.radius,0);
});
test('all stage and tape presets can round trip without changing colors or ranges',()=>{
 assert.deepEqual(Object.keys(presets),['Stage','Flightcase','Cables','Cinema','Theatre','Minimal','Tape Blue','Tape White','Tape Black','Modular Grid']);
 for(const t of Object.values(presets))assert.deepEqual(normalizeTheme(JSON.parse(JSON.stringify(t))),t);
 assert.equal(presets.Minimal.texture,false);
});

test('Modular Grid is applied once, old appearance backed up and later choices retained',()=>{
 const values=new Map([['hardplay-appearance-v1',JSON.stringify(presets['Tape Blue'])]]);
 const storage={getItem:k=>values.get(k)||null,setItem:(k,v)=>values.set(k,v)};
 assert.equal(defaultPreset,'Modular Grid');
 assert.deepEqual(loadTheme(storage),presets['Modular Grid']);
 assert.equal(JSON.parse(values.get('hardplay-appearance-before-modular-grid-v1')).preset,'Tape Blue');
 storage.setItem('hardplay-appearance-v1',JSON.stringify(presets.Cinema));
 assert.deepEqual(loadTheme(storage),presets.Cinema);
 assert.deepEqual(loadTheme({getItem(){throw new Error('storage unavailable')}}),presets['Modular Grid']);
});
