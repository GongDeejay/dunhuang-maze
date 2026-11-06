// Verify role: real keyboard and touch through the isolated turning-bridge preview.
// Usage: URL=http://127.0.0.1:8076/ NODE_PATH=... node tools/verify_bridge_slice.mjs
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {mkdir} from 'node:fs/promises';
import {resolve} from 'node:path';
const {chromium}=createRequire(import.meta.url)('playwright');
const out=resolve('artifacts/bridge-verify');await mkdir(out,{recursive:true});
const browser=await chromium.launch({headless:true,executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'});
const profiles=[{id:'desktop',width:1440,height:900},{id:'phone',width:390,height:844,mobile:true},{id:'small-large-text',width:360,height:640,mobile:true,font:20},{id:'landscape',width:844,height:390,mobile:true}];
try{for(const p of profiles.filter(p=>!process.env.PROFILE||p.id===process.env.PROFILE)){
 const context=await browser.newContext({viewport:{width:p.width,height:p.height},isMobile:!!p.mobile,hasTouch:!!p.mobile,deviceScaleFactor:p.mobile?3:1});
 const page=await context.newPage(),errors=[];
 page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
 if(p.font)await page.addInitScript(font=>document.addEventListener('DOMContentLoaded',()=>document.documentElement.style.fontSize=font+'px'),p.font);
 const state=()=>page.evaluate(()=>window.bridgeProbe);
 const shot=name=>page.screenshot({path:resolve(out,`${p.id}-${name}.png`)});
 async function tap(rect){const s=await state(),c=await page.locator('#canvas').boundingBox(),x=c.x+rect.x*c.width/s.width,y=c.y+rect.y*c.height/s.height;if(p.mobile)await page.touchscreen.tap(x,y);else await page.mouse.click(x,y);}
 async function ready(after=-1){await page.waitForFunction(after=>window.bridgeProbe?.busy===''&&window.bridgeProbe.frame>after+2,after);}
 async function step(index,key,blocked=false){const before=await state();if(p.mobile)await tap(before.arrows[index]);else await page.keyboard.press(key);if(blocked)await page.waitForFunction(f=>window.bridgeProbe.frame>f+12,before.frame);else await page.waitForFunction(m=>window.bridgeProbe.moves===m+1&&window.bridgeProbe.busy==='',before.moves);}
 async function turn(){const before=await state();if(p.mobile)await tap(before.cranks[0]);else await page.keyboard.press('Space');await page.waitForFunction(t=>window.bridgeProbe.turns===t+1&&window.bridgeProbe.busy==='',before.turns);}
 try{
  await page.goto(process.env.URL||'http://127.0.0.1:8076/',{waitUntil:'domcontentloaded'});
  if(await page.locator('#intro-skip').isVisible())await page.locator('#intro-skip').click();
  await page.waitForFunction(()=>window.bridgeProbe&&!document.getElementById('status'),null,{timeout:120000});
  await page.waitForFunction(()=>window.bridgeProbe.frame>10&&window.bridgeProbe.hint.bottom<=window.bridgeProbe.height);
  let s=await state();assert.deepEqual([s.x,s.y,s.connected,s.won],[2,6,false,false]);
  assert.ok(Math.abs((await page.locator('#canvas').boundingBox()).width-p.width)<1,'canvas matches browser width');
  for(const b of [...s.arrows,s.turn,s.restart,s.pause,...s.cranks]){
   assert.ok(b.left>=0&&b.right<=s.width+.5&&b.top>=0&&b.bottom<=s.height+.5,`${p.id}: button in viewport`);
   assert.ok(b.right-b.left>=47.99&&b.bottom-b.top>=47.99,'48 logical pixels, allowing floating-point bounds rounding');
  }
  const controls=[...s.arrows,s.turn,s.restart,s.pause];
  const overlaps=(a,b)=>a.left<b.right&&a.right>b.left&&a.top<b.bottom&&a.bottom>b.top;
  for(let i=0;i<controls.length;i++)for(let j=i+1;j<controls.length;j++)assert.ok(!overlaps(controls[i],controls[j]),'controls never overlap');
  assert.ok(s.goal.x>0&&s.goal.x<s.width&&s.goal.y>90&&s.goal.y<s.hint.top,'scarf visible before solving');
  await shot('start');
  await step(0,'ArrowUp');assert.equal((await state()).y,5,'one tap moves one tile');
  await step(0,'ArrowUp',true);assert.equal((await state()).y,5,'cannot cross disconnected deck');
  await shot('bank');
  // Pause in mid-rotation, then assert it does not advance behind the pause UI.
  if(p.mobile)await tap((await state()).cranks[0]);else await page.keyboard.press('Space');
  await page.waitForFunction(()=>window.bridgeProbe.busy==='turn'&&window.bridgeProbe.progress>.08);
  await tap((await state()).pause);await page.waitForFunction(()=>window.bridgeProbe.paused);
  const paused=await state();await page.waitForTimeout(950); // Exceeds the complete 0.8 s rotation.
  assert.equal((await state()).progress,paused.progress);await shot('paused-turn');
  await tap((await state()).pause);await ready();
  s=await state();assert.equal(s.connected,true);assert.equal(s.turns,1,'one gesture turns only once');assert.equal(s.moves,1,'turning does not move player');assert.equal(s.won,false);
  await shot('connected');
  await turn();assert.equal((await state()).connected,false,'player can reverse safely');
  await turn();assert.equal((await state()).connected,true);
  await step(0,'ArrowUp');assert.equal((await state()).y,4);assert.equal((await state()).turn.disabled,true,'cannot rotate while standing on bridge');
  // A held key must not generate another tile step from native repeat.
  if(!p.mobile){await page.keyboard.down('ArrowUp');await page.waitForTimeout(650);await page.keyboard.up('ArrowUp');await ready();assert.equal((await state()).y,3,'held key is single-step');}
  else await step(0,'ArrowUp');
  await shot('crossing');
  if(p.id==='landscape'){
   await page.setViewportSize({width:390,height:844});
   const beforeRotation=await state();
   await page.waitForFunction(frame=>window.bridgeProbe.width===390&&innerWidth===390&&window.bridgeProbe.frame>frame+10,beforeRotation.frame);
   assert.ok(Math.abs((await page.locator('#canvas').boundingBox()).width-390)<1,'rotated canvas matches viewport');
   assert.equal((await state()).y,3);await shot('rotated');
  }
  for(let i=0;i<3;i++){await step(0,'ArrowUp');assert.equal((await state()).y,2-i,'each final step registered');}
  await page.waitForFunction(()=>window.bridgeProbe.won);
  assert.equal((await state()).moves,6);await shot('scarf');
  await tap((await state()).restart);await page.waitForFunction(()=>window.bridgeProbe.y===6&&!window.bridgeProbe.won);
  assert.equal((await state()).connected,false);
  assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth),false);
  assert.deepEqual(errors,[]);console.log(`${p.id}: gap, rotate, pause, undo, single step, crossing, scarf, restart passed`);
 }catch(e){await shot('FAILED');console.error(errors);throw e;}finally{await context.close();}
}}finally{await browser.close();}
