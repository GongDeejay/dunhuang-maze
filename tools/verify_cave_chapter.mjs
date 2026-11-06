// Verify role: full production cave flow through real keyboard/touch, never mutate game state.
// URL=http://127.0.0.1:8077/ NODE_PATH=... node tools/verify_cave_chapter.mjs
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {mkdir} from 'node:fs/promises';
import {resolve} from 'node:path';
const {chromium}=createRequire(import.meta.url)('playwright');
const out=resolve('artifacts/cave-network-verify');await mkdir(out,{recursive:true});
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
 async function button(key){
  await page.waitForFunction(k=>{const s=window.caveProbe,b=s?.[k];return b?.visible&&b.left>=0&&b.top>=0&&b.right<=s.width+.5&&b.bottom<=s.height+.5;},key);
  await tap((await state())[key]);
 }
 async function steps(route){for(const dir of route){const s=await state(),[i,key]=dirs[dir];if(p.mobile)await tap(s.arrows[i]);else await page.keyboard.press(key);await page.waitForFunction(m=>window.caveProbe.moves===m+1&&window.caveProbe.busy==='',s.moves);}}
 async function blocked(dir){const s=await state(),[i,key]=dirs[dir];if(p.mobile)await tap(s.arrows[i]);else await page.keyboard.press(key);await page.waitForFunction(f=>window.caveProbe.frame>f+12,s.frame);assert.equal((await state()).moves,s.moves,'blocked move never advances');}
 async function action(){const s=await state();await button('action');if(s.doorTarget>=0)await page.waitForFunction(r=>window.caveProbe.room===r,s.doorTarget);else await page.waitForFunction(h=>window.caveProbe.history===h+1&&window.caveProbe.busy==='',s.history);}
 async function reload(){const before=await state();await page.waitForTimeout(1600); // Wait for web filesystem sync before unloading.
  await page.reload({waitUntil:'domcontentloaded'});await page.waitForFunction(()=>window.caveProbe?.active&&!document.getElementById('status')&&window.caveProbe.frame>12,null,{timeout:120000});
  const after=await state();for(const key of ['room','x','y','shortcut','secret','held','reached','box','solved'])assert.deepEqual(after[key],before[key],`reload retains ${key}`);
 }
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
  await shot('03-scarf');await action();await layout();assert.equal((await state()).room,5);await shot('04-hub');
  await steps('UUUUU');assert.equal((await state()).action.disabled,true,'shortcut cannot open from hub');await shot('04-locked-shortcut');await steps('DDDDD');
  if(p.id!=='phone'){
  await steps('LLUUL');await action();assert.equal((await state()).room,1);await shot('04-pressure');
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
  await shot('05-shared-ears');await steps('LUURUU');await action();await layout();
  assert.equal((await state()).room,3);assert.equal((await state()).checkpoint,3);
  await steps('LLUURDRURRUU');assert.equal((await state()).latch,true);await shot('05b-latched');
  await undo();assert.equal((await state()).latch,false);
  await steps('UUDDDLLLURRDRUUULLUUU');assert.equal((await state()).reached,true);await shot('05c-relay-solved');
  assert.equal((await state()).undo.disabled,true,'solved room cannot be accidentally undone');
  await steps('DDLL');await shot('05d-rear-door');await action();assert.equal((await state()).room,5);assert.equal((await state()).shortcut,true);assert.ok((await state()).hintText.includes('原来绕回'));await shot('05e-loop');
  await reload();await action();assert.equal((await state()).room,3);assert.deepEqual((await state()).gates,[true,true]);assert.deepEqual((await state()).box,[5,2]);assert.equal((await state()).latch,true);
  await action();await steps('DD');await button('action');await page.waitForFunction(()=>window.caveProbe.secret&&window.caveProbe.mode==='note');await shot('05f-secret');
  await button('primary');await page.waitForFunction(()=>window.caveProbe.mode==='playing');await reload();await shot('05g-secret-kept');
  await button('note');await page.waitForFunction(()=>window.caveProbe.mode==='note');await shot('05h-map');await button('primary');await page.waitForFunction(()=>window.caveProbe.mode==='playing');
  await button('pause');await page.waitForFunction(()=>window.caveProbe.mode==='pause');await button('tertiary');await page.waitForFunction(()=>window.caveProbe.mode==='menu');await button('primary');await page.waitForFunction(()=>window.caveProbe.menu&&!window.caveProbe.active);
  await page.reload({waitUntil:'domcontentloaded'});await page.waitForFunction(()=>window.caveProbe?.active&&!document.getElementById('status'),null,{timeout:120000});assert.equal((await state()).secret,true);assert.equal((await state()).shortcut,true);
  await steps('UU');await action();await steps('RRUU');await action();assert.equal((await state()).room,2);assert.equal((await state()).solved[4],false,'left route does not require right branch');await steps('RR');
  }else{
  await steps('RRUUR');await action();assert.equal((await state()).room,4);await steps('U');await action();assert.equal((await state()).held,true);
  await steps('D');await action();assert.equal((await state()).room,5);await action();assert.equal((await state()).held,true,'unfinished cave remembers lamp on retreat');await reload();
  await steps('ULL');await action();assert.equal((await state()).lit,true);await shot('05d-light-bridge');
  await steps('RRRR');await action();await steps('LLUU');assert.equal((await state()).action.disabled,true);await steps('UUUU');await action();assert.equal((await state()).room,2);
  assert.equal((await state()).solved[1],false);assert.equal((await state()).solved[3],false);assert.equal((await state()).secret,false,'secret is never required');
  await action();assert.equal((await state()).room,4);assert.equal((await state()).lit,true);await steps('DDDDDDD');await action();assert.equal((await state()).room,5);await shot('05i-right-return');
  await action();await steps('UUUUUUU');await action();await steps('LL');
  }
  await layout();await shot('06-lamp');
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
  await button('primary');await page.waitForFunction(()=>window.caveProbe.mode==='playing');await reload();await steps('RR');assert.equal((await state()).reached,true);await shot('12-doorway');
  await button('action');await page.waitForFunction(()=>window.caveProbe.mode==='finish');await button('primary');await page.waitForFunction(()=>window.caveProbe.third&&!window.caveProbe.active&&window.caveProbe.level===2);await shot('13-third-chapter');
  assert.equal(await page.locator('#mogao-cave-viewport').count(),0,'chapter-scoped browser style removed on exit');
  assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth),false);assert.deepEqual(errors,[]);
  console.log(`${p.id}: ${p.id==='phone'?'independent right route and return':'independent left route, loop and secret'}; persistent states, undo, touch, rescue, third-chapter transition PASS`);
 }catch(e){await shot('FAILED');console.error(errors);throw e;}finally{await ctx.close();}
}}finally{await browser.close();}
