const { chromium } = require('/Users/song/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const fs=require('fs');
const path=require('path');
const out=__dirname;
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:'/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge'});
 const page=await browser.newPage({viewport:{width:820,height:1600},deviceScaleFactor:1});
 const errors=[];page.on('pageerror',e=>errors.push(String(e)));
 await page.goto('file://'+path.join(out,'preview.html'));
 const frame=page.frameLocator('iframe');
 await frame.locator('[data-role="score"]').waitFor();
 const states=[];
 for(let s=0;s<3;s++){
  await frame.locator('[data-role="scenario"]').selectOption(String(s));
  for(let c=0;c<8;c++){
   await frame.locator('[data-role="case"]').selectOption(String(c));
   states.push({scenario:s,case:c,score:await frame.locator('[data-role="score"]').innerText(),status:await frame.locator('[data-role="status"]').innerText(),lines:await frame.locator('[data-role="table"] polyline').count()});
  }
 }
 await frame.locator('[data-role="scenario"]').selectOption('0');
 await frame.locator('[data-role="case"]').selectOption('7');
 await frame.locator('#separation-score-lab').screenshot({path:path.join(out,'counterexample-wide.png')});
 await frame.locator('[data-role="scenario"]').selectOption('1');
 await frame.locator('[data-role="case"]').selectOption('1');
 await frame.locator('#separation-score-lab').screenshot({path:path.join(out,'default-wide.png')});
 await page.setViewportSize({width:360,height:1800});
 await frame.locator('#separation-score-lab').screenshot({path:path.join(out,'default-narrow.png')});
 const narrow=await frame.locator('#separation-score-lab').evaluate(e=>({width:e.clientWidth,scroll:e.scrollWidth,invalid:[...e.querySelectorAll('svg *')].filter(n=>[...n.attributes].some(a=>/NaN|undefined/.test(a.value))).length}));
 await frame.locator('[data-role="zoom-toggle"]').uncheck();
 const zoomHidden=await frame.locator('[data-role="zoom-wrap"]').isHidden();
 await frame.locator('[data-role="rows"] button').nth(3).click();
 const tableSelection=await frame.locator('[data-role="case"]').inputValue();
 await page.emulateMedia({colorScheme:'dark'});
 await page.setViewportSize({width:820,height:1600});
 await frame.locator('[data-role="zoom-toggle"]').check();
 await frame.locator('#separation-score-lab').screenshot({path:path.join(out,'dark.png')});
 const result={states,errors,narrow,zoomHidden,tableSelection};
 fs.writeFileSync(path.join(out,'browser-review.json'),JSON.stringify(result,null,2));
 if(errors.length||narrow.invalid||narrow.scroll>narrow.width+1||!zoomHidden||tableSelection!=='3')throw Error(JSON.stringify(result));
 console.log(JSON.stringify({states:states.length,errors,narrow,zoomHidden,tableSelection}));
 await browser.close();
})().catch(e=>{console.error(e);process.exit(1)});
