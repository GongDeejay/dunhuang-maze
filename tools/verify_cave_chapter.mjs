// Verify role: full production cave flow through real keyboard/touch, never mutate game state.
// URL=http://127.0.0.1:8077/ NODE_PATH=... node tools/verify_cave_chapter.mjs
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {mkdir} from 'node:fs/promises';
import {resolve} from 'node:path';
const {chromium}=createRequire(import.meta.url)('playwright');
const out=resolve('artifacts/cave-verify');await mkdir(out,{recursive:true});
const browser=await chromium.launch({headless:true,executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'});
const profiles=[{id:'desktop',width:1440,height:900},{id:'phone',width:390,height:844,mobile:true},{id:'small-large-text',width:360,height:640,mobile:true,font:20},{id:'landscape',width:844,height:390,mobile:true}];
const dirs={U:[0,'ArrowUp'],L:[1,'ArrowLeft'],D:[2,'ArrowDown'],R:[3,'ArrowRight']};
try{for(const p of profiles.filter(p=>!process.env.PROFILE||p.id===process.env.PROFILE)){
 const ctx=await browser.newContext({viewport:{width:p.width,height:p.height},isMobile:!!p.mobile,hasTouch:!!p.mobile,deviceScaleFactor:p.mobile?3:1});
 const page=await ctx.newPage(),errors=[];page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
 if(p.font)await page.addInitScript(f=>document.addEventListener('DOMContentLoaded',()=>document.documentElement.style.fontSize=f+'px'),p.font);
 const state=()=>page.evaluate(()=>window.caveProbe);
 const shot=name=>page.screenshot({path:resolve(out,`${p.id}-${name}.png`)});
 async function tap(b){const s=await state(),r=await page.locator('#canvas').boundingBox(),x=r.x+b.x*r.width/s.width,y=r.y+b.y*r.height/s.height;if(p.mobile)await page.touchscreen.tap(x,y);else await page.mouse.click(x,y);}
 async function button(key){await tap((await state())[key]);}
 async function steps(route){for(const dir of route){const s=await state(),[i,key]=dirs[dir];if(p.mobile)await tap(s.arrows[i]);else await page.keyboard.press(key);await page.waitForFunction(m=>window.caveProbe.moves===m+1&&window.caveProbe.busy==='',s.moves);}}
 async function blocked(dir){const s=await state(),[i,key]=dirs[dir];if(p.mobile)await tap(s.arrows[i]);else await page.keyboard.press(key);await page.waitForFunction(f=>window.caveProbe.frame>f+12,s.frame);assert.equal((await state()).moves,s.moves,'blocked move never advances');}
 async function action(){const s=await state();await button('action');if(s.reached)await page.waitForFunction(r=>window.caveProbe.room===r+1,s.room);else await page.waitForFunction(h=>window.caveProbe.history===h+1&&window.caveProbe.busy==='',s.history);}
 async function undo(){const s=await state();await button('undo');await page.waitForFunction(h=>window.caveProbe.history===h-1,s.history);}
 async function layout(){const s=await state(),controls=[...s.arrows,s.action,s.undo,s.note,s.pause];for(const b of controls){assert.ok(b.left>=0&&b.right<=s.width+.5&&b.top>=0&&b.bottom<=s.height+.5,'controls fit');assert.ok(b.right-b.left>=47.99&&b.bottom-b.top>=47.99,'48px hit target');}for(let i=0;i<controls.length;i++)for(let j=i+1;j<controls.length;j++){const a=controls[i],b=controls[j];assert.ok(!(a.left<b.right&&a.right>b.left&&a.top<b.bottom&&a.bottom>b.top),'controls do not overlap');}assert.ok(s.hint.bottom<=s.height+.5,'hint stays inside viewport');assert.ok(s.objective.bottom<=s.height-176,'objective not in controls');}
 try{
  await page.goto(process.env.URL||'http://127.0.0.1:8077/',{waitUntil:'domcontentloaded'});
  if(await page.locator('#intro-skip').isVisible())await page.locator('#intro-skip').click();
  await page.waitForFunction(()=>window.caveProbe?.active&&!document.getElementById('status')&&window.caveProbe.frame>12,null,{timeout:120000});
  await layout();await shot('01-cave-entry');
  assert.equal(await page.locator('#mogao-cave-viewport').count(),1,'viewport fix belongs to the real cave controller');
  await steps('U');await blocked('U');await button('action');
  await page.waitForFunction(()=>window.caveProbe.busy==='turn'&&window.caveProbe.progress>.08);
  await button('pause');await page.waitForFunction(()=>window.caveProbe.mode==='pause');
  const paused=await state();await page.waitForTimeout(850); // Longer than the complete bridge animation.
  assert.equal((await state()).progress,paused.progress);
  await shot('02-pause');await button('primary');await page.waitForFunction(()=>window.caveProbe.mode==='playing'&&window.caveProbe.busy==='');
  await undo();assert.equal((await state()).turns,0);await action();
  await steps('U');assert.equal((await state()).action.disabled,true,'no turn from bridge');
  if(!p.mobile){const s=await state();await page.keyboard.down('ArrowUp');await page.waitForTimeout(600);await page.keyboard.up('ArrowUp');assert.equal((await state()).moves,s.moves+1,'held key moves one tile');}else await steps('U');
  await steps('UUU');assert.equal((await state()).scarf,true);assert.equal((await state()).rescued,false);
  await shot('03-scarf');await action();await layout();await shot('04-pressure');
  // Player weight works, but stops holding the door after leaving.
  await steps('LLUUU');assert.deepEqual((await state()).gates,[true,false]);await shot('04-left-plate');
  await steps('D');assert.deepEqual((await state()).gates,[false,false]);
  await steps('DRRRRUU');assert.deepEqual((await state()).gates,[false,true]);await shot('04-right-plate');
  await steps('LL');assert.deepEqual((await state()).gates,[true,true]);assert.equal((await state()).shared,true);await blocked('U');
  // Reset only this cave, with explicit confirmation and no lost first-room clue.
  await button('pause');await page.waitForFunction(()=>window.caveProbe.mode==='pause');await button('secondary');await page.waitForFunction(()=>window.caveProbe.mode==='reset');await button('primary');await page.waitForFunction(()=>window.caveProbe.mode==='playing'&&window.caveProbe.y===6&&window.caveProbe.x===3);
  assert.equal((await state()).room,1);assert.equal((await state()).scarf,true);
  await steps('LLUUR');assert.deepEqual((await state()).box,[3,4]);await undo();assert.deepEqual((await state()).box,[2,4]);
  await steps('RDRU');assert.deepEqual((await state()).box,[3,3]);assert.deepEqual((await state()).gates,[true,true]);
  await page.waitForFunction(()=>window.caveProbe.gateVisual.every(v=>v===1));
  await shot('05-shared-ears');await steps('LUURUU');await action();await layout();await shot('06-lamp');
  await action();assert.equal((await state()).held,true);
  await steps('LLU');await action();assert.equal((await state()).deer,true);assert.equal((await state()).lit,false);await shot('07-mural');
  await action();assert.equal((await state()).held,true);await steps('RRRR');await action();
  assert.equal((await state()).bankLit,true);assert.equal((await state()).lit,false,'river rescue must happen before path reveal');
  await page.waitForFunction(()=>window.caveProbe.deerTime>1.7&&window.caveProbe.deerTime<3.2);
  await button('pause');await page.waitForFunction(()=>window.caveProbe.mode==='pause');
  const riverPause=await state();await page.waitForTimeout(1000); // Verify the scene animation pauses, not only input.
  assert.equal((await state()).deerTime,riverPause.deerTime);
  await button('primary');await page.waitForFunction(()=>window.caveProbe.mode==='playing');await shot('08-carrying-person');
  await undo();assert.equal((await state()).held,true);assert.equal((await state()).lit,false);assert.equal((await state()).deerTime,-1);
  await action();await steps('U'); // Movement remains available during the nonmodal story.
  await blocked('U'); // Unfinished light trail is not walkable yet.
  await page.waitForFunction(()=>window.caveProbe.lit&&window.caveProbe.deerTime>=4.4);await shot('08-lit-route');
  await button('note');await page.waitForFunction(()=>window.caveProbe.mode==='note');const note=await state();await blocked('U');assert.equal((await state()).x,note.x);await shot('09-note');await button('primary');await page.waitForFunction(()=>window.caveProbe.mode==='playing');
  await steps('U');assert.equal((await state()).action.disabled,true,'cannot remove route light from dark corridor');
  if(p.id==='landscape'){
   await page.setViewportSize({width:390,height:844});const before=await state();
   await page.waitForFunction(f=>window.caveProbe.width===390&&innerWidth===390&&window.caveProbe.frame>f+12,before.frame);
   assert.ok(Math.abs((await page.locator('#canvas').boundingBox()).width-390)<1);await layout();await shot('10-rotated');
  }
  await steps('LULUUU');await page.waitForFunction(()=>window.caveProbe.mode==='rescue');assert.equal((await state()).rescued,true);assert.equal((await state()).reached,false);await shot('11-reunion');
  await button('primary');await page.waitForFunction(()=>window.caveProbe.mode==='playing');await steps('RR');assert.equal((await state()).reached,true);await shot('12-doorway');
  await button('action');await page.waitForFunction(()=>window.caveProbe.mode==='finish');await button('primary');await page.waitForFunction(()=>window.caveProbe.third&&!window.caveProbe.active&&window.caveProbe.level===2);await shot('13-third-chapter');
  assert.equal(await page.locator('#mogao-cave-viewport').count(),0,'chapter-scoped browser style removed on exit');
  assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth),false);assert.deepEqual(errors,[]);
  console.log(`${p.id}: bridge, crate pressure, undo, local reset, lamp/mural, lit path, rescue, third-chapter transition PASS`);
 }catch(e){await shot('FAILED');console.error(errors);throw e;}finally{await ctx.close();}
}}finally{await browser.close();}
