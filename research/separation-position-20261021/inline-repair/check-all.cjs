const {chromium}=require('/Users/song/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const fs=require('fs'),assert=require('assert/strict');
(async()=>{
 const browser=await chromium.launch({headless:true,channel:'msedge'});
 try {
  const results=[];
  for(const name of ['all-preview','all-max45-preview']){
   const page=await browser.newPage({viewport:{width:800,height:900}}),errors=[];
   page.on('pageerror',e=>errors.push(e.message));
   await page.goto('file://'+__dirname+'/'+name+'.html');
   const f=page.frameLocator('iframe');
   await f.locator('[data-role="next-route"]').waitFor();
   const frame=page.frames().find(x=>x.parentFrame());
   const checks=await frame.evaluate(()=>{
    const get=role=>document.querySelector(`[data-role="${role}"]`);
    const count=get('count'),route=get('route'),pocket=get('pocket'),next=get('next-route'),checks=[];
    const change=(el,value)=>{el.value=value;el.dispatchEvent(new Event('change'));};
    let saved=null;window.openai={setWidgetState:s=>{saved=s;return Promise.resolve();}};
    for(const option of [...count.options].filter(o=>!o.disabled)){
     change(count,option.value);
     const expected=Number(option.textContent.match(/· (\d+) 条/)[1]),total=route.options.length;
     if(total!==expected)throw Error('Class count differs from available routes');
     change(route,route.options[0].value);
     const ids=[];
     for(let i=0;i<total;i++){
      if(route.selectedIndex!==i)throw Error('Next skipped or repeated a route');
      ids.push(saved.modelContent.routeID);
      if(!get('route-position').textContent.endsWith(`${i+1} / ${total}`))throw Error('Counter mismatch');
      for(const p of [...pocket.options]){
       change(pocket,p.value);
       if(!get('summary').textContent.includes('网格候选'))throw Error('Missing second-ball region');
       if([...get('table').querySelectorAll('*')].some(e=>[...e.attributes].some(a=>/NaN|undefined|Infinity/.test(a.value))))throw Error('Invalid SVG');
      }
      next.click();
      if(count.value!==option.value)throw Error('Next changed class');
     }
     if(new Set(ids).size!==total||route.selectedIndex!==0)throw Error('Incomplete class cycle');
     if(next.disabled!==(total===1))throw Error('Disabled state mismatch');
     checks.push({class:option.value,total,uniqueIDs:ids.length,wrap:true});
    }
    change(count,'1');change(route,route.options[0].value);change(pocket,'1');
    document.querySelector('[data-stage="1"]').click();
    return checks;
   });
   await f.locator('[data-role="next-route"]').click();
   assert.match(await f.locator('[data-role="route-position"]').innerText(),/2 \/ (51|74)$/);
   await page.screenshot({path:__dirname+'/'+name+'-wide.png',fullPage:true});
   await page.setViewportSize({width:320,height:850});
   await page.waitForTimeout(100);
   const layout=await frame.evaluate(()=>({width:innerWidth,scroll:document.documentElement.scrollWidth}));
   assert.ok(layout.scroll<=layout.width+1);
   await page.screenshot({path:__dirname+'/'+name+'-narrow.png',fullPage:true});
   assert.deepEqual(errors,[]);
   results.push({name,checks,errors,layout});
   await page.close();
  }
  fs.writeFileSync(__dirname+'/all-review.json',JSON.stringify(results,null,2));console.log(JSON.stringify(results));
 } finally {await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
