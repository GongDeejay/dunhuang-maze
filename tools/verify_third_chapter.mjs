// Verify role: real browser keyboard/multitouch through the 3D chapter and ending.
// Use a test-only export with tests/third_chapter_probe.tscn; never publish the probe.
// Usage: URL=http://127.0.0.1:8063/ NODE_PATH=... node tools/verify_third_chapter.mjs
import assert from 'node:assert/strict';
import { mkdir } from 'node:fs/promises';
import { resolve } from 'node:path';
import { createRequire } from 'node:module';
const { chromium } = createRequire(import.meta.url)('playwright');
const out = resolve('artifacts/third-chapter-verify');
await mkdir(out, { recursive: true });
const browser = await chromium.launch({headless:true, executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'});
const profiles = [
  {id:'desktop-safe', width:1440, height:900, mobile:false, full:true, relic:true},
  {id:'phone-short', width:390, height:844, mobile:true, full:true},
  {id:'small-large-text', width:360, height:640, mobile:true, font:20},
  {id:'landscape', width:844, height:390, mobile:true},
];
function route(floor, start, goal, rescued) {
  const allowed=new Set(floor.map(c=>c.join(','))), seen=new Set([start.join(',')]), queue=[[...start,[]]];
  for(let i=0;i<queue.length;i++){
    const [x,z,steps]=queue[i]; if(x===goal[0]&&z===goal[1])return steps;
    for(const [dx,dz] of [[0,-1],[1,0],[0,1],[-1,0]]){
      const next=[x+dx,z+dz],key=next.join(',');
      if(!allowed.has(key)||seen.has(key)||(!rescued&&key==='13,6'))continue;
      seen.add(key);queue.push([...next,[...steps,next]]);
    }
  }
  throw new Error('No walkable route');
}
try{
 for(const profile of profiles){
  const ctx=await browser.newContext({viewport:{width:profile.width,height:profile.height},isMobile:profile.mobile,hasTouch:profile.mobile,deviceScaleFactor:profile.mobile?3:1});
  const page=await ctx.newPage(),errors=[];
  page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
  if(profile.font)await page.addInitScript(font=>document.addEventListener('DOMContentLoaded',()=>document.documentElement.style.fontSize=`${font}px`),profile.font);
  const state=()=>page.evaluate(()=>window.thirdChapterProbe);
  const point=async p=>{const s=await state(),c=await page.locator('#canvas').boundingBox();return{x:c.x+p.x*c.width/s.width,y:c.y+p.y*c.height/s.height};};
  const tap=async name=>{const p=await point((await state())[name]);if(profile.mobile)await page.touchscreen.tap(p.x,p.y);else await page.mouse.click(p.x,p.y);};
  const screenshot=async name=>page.screenshot({path:resolve(out,`${profile.id}-${name}.png`)});
  try{
   await page.goto(process.env.URL||'http://127.0.0.1:8063/',{waitUntil:'domcontentloaded'});
   if(await page.locator('#intro-skip').isVisible())await page.locator('#intro-skip').click();
   await page.waitForFunction(()=>window.thirdChapterProbe&&!document.getElementById('status'),null,{timeout:120000});
   let s=await state();assert.equal(s.mode,'welcome');
   assert.ok(s.primary.left>=0&&s.primary.bottom<=s.height,'continue visible at native text scale');
   await screenshot('welcome');
   await tap('primary');await page.waitForFunction(()=>window.thirdChapterProbe.mode==='playing');
   const cdp=await ctx.newCDPSession(page);
   const touches=async(type,points)=>cdp.send('Input.dispatchTouchEvent',{type,touchPoints:points});
   if(profile.mobile){
    s=await state();const m=await point({x:s.stick.x,y:s.stick.y-35}),l=await point({x:s.width*.72,y:s.height*.43}),l2=await point({x:s.width*.72+20,y:s.height*.43});
    await touches('touchStart',[{...m,id:0},{...l,id:1}]);
    await touches('touchMove',[{...m,id:0},{...l2,id:1}]);
    await page.waitForFunction(()=>window.thirdChapterProbe.moveTouch>=0&&window.thirdChapterProbe.lookTouch>=0);
    await touches('touchEnd',[{...m,id:0}]);
    await page.waitForFunction(()=>window.thirdChapterProbe.lookTouch===-1&&window.thirdChapterProbe.moveTouch>=0);
    await touches('touchEnd',[]);
    await touches('touchStart',[{...l2,id:1}]);await touches('touchMove',[{...l,id:1}]);await touches('touchEnd',[]);
    await page.waitForFunction(()=>window.thirdChapterProbe.moveTouch===-1&&window.thirdChapterProbe.lookTouch===-1);
    assert.ok(Math.abs((await state()).yaw)<0.005,'look drag reverses without synthetic mouse duplication');
   }
   // Pause must freeze simulation and clear any previously held movement.
   await tap('pause');await page.waitForFunction(()=>window.thirdChapterProbe.mode==='paused');
   const paused=await state();await page.keyboard.down('w');
   await page.waitForTimeout(1700); // Deliberately exceeds the scorpion windup interval.
   await page.keyboard.up('w');s=await state();assert.equal(s.elapsed,paused.elapsed);assert.equal(s.z,paused.z);
   await screenshot('pause');await tap('primary');
   await page.waitForFunction(()=>window.thirdChapterProbe.mode==='playing');
   async function hold(dx,dz){
    if(profile.mobile){const q=await state(),p=await point({x:q.stick.x+dx*48,y:q.stick.y+dz*48});await touches('touchStart',[{...p,id:0}]);}
    else await page.keyboard.down(dx>0?'d':dx<0?'a':dz>0?'s':'w');
   }
   async function release(dx,dz){if(profile.mobile)await touches('touchEnd',[]);else await page.keyboard.up(dx>0?'d':dx<0?'a':dz>0?'s':'w');}
   async function axis(key,goal){
    const q=await state(),distance=goal-q[key];if(Math.abs(distance)<0.2)return;
    const sign=Math.sign(distance),dx=key==='x'?sign:0,dz=key==='z'?sign:0;
    await hold(dx,dz);
    try{await page.waitForFunction(({key,goal,sign})=>{const p=window.thirdChapterProbe;return(p[key]-goal)*sign>=-0.15||p.mode!=='playing';},{key,goal,sign},{timeout:8000});}
    finally{await release(dx,dz);}
    assert.equal((await state()).mode,'playing','route remains survivable');
   }
   async function go(goal){
    const q=await state(),steps=route(q.floor,[Math.round(q.x/4),Math.round(q.z/4)],goal,q.rescued);
    for(const [x,z]of steps){await axis('x',x*4);await axis('z',z*4);}
   }
   // Continuous forward movement is real, and a boundary stops the player.
   await go([3,11]);await screenshot('valley');
   if(profile.full){
    await go([3,8]);await tap('interact');await screenshot('fork');
    if(profile.relic){
     await go([2,5]);await go([5,5]);await axis('z',21);await axis('x',24);
     await page.waitForFunction(()=>window.thirdChapterProbe.target==='relic');await tap('interact');
     await page.waitForFunction(()=>window.thirdChapterProbe.relic);await screenshot('relic');
     await go([2,3]);await go([9,3]);
    }else{
     await go([8,8]);await go([9,8]);await axis('z',27);
     await page.waitForFunction(()=>window.thirdChapterProbe.target==='enemy');
     await screenshot('encounter');await tap('interact');
     await page.waitForTimeout(550); // Attack cooldown, not an asset readiness wait.
     await tap('interact');await page.waitForFunction(()=>window.thirdChapterProbe.enemyHp<=0);
     await go([9,3]);
    }
    await go([13,3]);await axis('z',11);
    await page.waitForFunction(()=>window.thirdChapterProbe.target==='child');await screenshot('child');
    await tap('interact');await page.waitForFunction(()=>window.thirdChapterProbe.rescued);
    await screenshot('rescue');await tap('primary');
    await page.waitForFunction(()=>window.thirdChapterProbe.mode==='playing');
    await go([13,11]);
    // Arrival triggers the ending before the exact camp centre.
    await axis('x',56);await hold(0,1);
    await page.waitForFunction(()=>window.thirdChapterProbe.mode==='ending1',{},{timeout:8000});await release(0,1);
    assert.equal((await state()).save,-1,'completed checkpoint cleared');await screenshot('reunion');
    if(profile.mobile)await tap('primary');
    else await page.waitForFunction(()=>window.thirdChapterProbe.mode==='complete',{},{timeout:22000});
    await page.waitForFunction(()=>window.thirdChapterProbe.mode==='complete');
    assert.equal((await state()).photo,true);await screenshot('photo');
    await tap('secondary');await page.waitForFunction(()=>window.thirdChapterProbe.mode==='replay_confirm');
    await tap('secondary');await page.waitForFunction(()=>window.thirdChapterProbe.mode==='complete');
    await tap('primary');await page.waitForFunction(()=>window.thirdChapterProbe.menu&&!window.thirdChapterProbe.active);
   }
   assert.deepEqual(errors,[],`${profile.id}: browser errors`);
   console.log(`${profile.id}: ${profile.full?'route, rescue, ending, save, menu':'layout and native input'} passed`);
  }catch(error){await screenshot('FAILED');console.error(errors);throw error;}
  finally{await ctx.close();}
 }
}finally{await browser.close();}
