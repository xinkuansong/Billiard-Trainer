const {chromium}=require('/Users/song/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const fs=require('fs'),path=require('path');
(async()=>{
 const browser=await chromium.launch({headless:true,channel:'msedge'}),page=await browser.newPage({viewport:{width:800,height:1000}}),errors=[];
 page.on('pageerror',e=>errors.push(String(e)));await page.goto('file://'+__dirname+'/preview.html');
 const f=page.frameLocator('iframe');await f.locator('.speed-choice').first().waitFor();
 async function fit(){const frame=page.frames().find(x=>x.parentFrame());const h=await frame.evaluate(()=>document.documentElement.scrollHeight);await page.locator('iframe').evaluate((e,h)=>e.style.height=h+32+'px',h);await page.waitForTimeout(100)}
 async function snap(name){await fit();await page.screenshot({path:path.join(__dirname,name+'.png'),fullPage:true})}
 await snap('preview-all');
 for(let i=0;i<13;i++){await f.locator(`[data-index="${i}"]`).click();const selected=await f.locator('#center-speed-13').getAttribute('data-selected');if(selected!==String(i))throw Error('selection '+i);if(!(await f.locator('[data-detail]').innerText()).includes('第'+(i+1)+'档'))throw Error('detail '+i)}
 await snap('preview-fast');await f.locator('input[data-zoom]').check();await snap('preview-zoom');
 await f.locator('[data-all]').click();await snap('preview-zoom-all');await f.locator('input[data-zoom]').uncheck();
 const widths=[];
 for(const width of [360,320]){await page.setViewportSize({width,height:1000});await page.waitForTimeout(100);await snap('preview-'+width);const frame=page.frames().find(x=>x.parentFrame());const result=await frame.evaluate(()=>({width:innerWidth,scroll:document.documentElement.scrollWidth,svgWidth:document.querySelector('.table-view').getBoundingClientRect().width,invalid:[...document.querySelectorAll('svg *')].some(e=>[...e.attributes].some(a=>/NaN|Infinity|undefined/.test(a.value)))}));if(result.invalid||result.scroll>result.width+1)throw Error(JSON.stringify(result));widths.push(result)}
 await page.emulateMedia({colorScheme:'dark'});await snap('preview-dark');
 if(errors.length)throw Error(JSON.stringify(errors));fs.writeFileSync(path.join(__dirname,'visual-review.json'),JSON.stringify({errors,widths,selections:13,zoom:true,all:true},null,2));await browser.close();
})();
