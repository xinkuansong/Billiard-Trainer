const { chromium } = require('/Users/song/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const fs = require('fs');
const path = require('path');
const assert = require('assert/strict');
(async () => {
  const browser = await chromium.launch({ headless: true, channel: 'msedge' });
  try {
    const page = await browser.newPage({ viewport: { width: 800, height: 900 } });
    const errors = [];
    page.on('pageerror', e => errors.push(e.message));
    await page.goto('file://' + path.join(__dirname, process.argv[2] || 'preview.html'));
    const f = page.frameLocator('iframe');
    await f.locator('[data-role="table"] circle').first().waitFor();
    const frame = page.frames().find(f => f.parentFrame());
    const checks = [];
    for (const state of [null, {}, {stage:2,pocket:null}, {stage:2,pocket:'2'}, {stage:2,pocket:1.5}, {stage:2,pocket:-1}, {stage:2,pocket:2}, {stage:2,pocket:6}, {stage:2,pocket:false}, {stage:2,routeID:999999,pocket:1}, {stage:2,routeID:99,pocket:1}]) {
      await frame.evaluate(s => window.dispatchEvent(new CustomEvent('openai:set_globals', {detail:{globals:{widgetState:{modelContent:s}}}})), state);
      assert.match(await f.locator('[data-role="summary"]').innerText(), /网格候选/);
      assert.ok(await f.locator('[data-role="table"] circle').count() >= 6);
      checks.push(state);
    }
    let routes = 0;
    const counts = await f.locator('[data-role="count"] option:enabled').evaluateAll(os => os.map(o => o.value));
    for (const c of counts) {
      await f.locator('[data-role="count"]').selectOption(c);
      const rs = await f.locator('[data-role="route"] option').evaluateAll(os => os.map(o => o.value));
      for (const r of rs) {
        await f.locator('[data-role="route"]').selectOption(r);
        for (const p of ['0','1','3','4','5']) {
          await f.locator('[data-role="pocket"]').selectOption(p);
          assert.match(await f.locator('[data-role="summary"]').innerText(), /网格候选/);
          routes++;
        }
      }
    }
    for (const mode of ['missing','void','promise']) {
      await frame.evaluate(mode => { window.openai = mode === 'missing' ? {} : { setWidgetState: mode === 'void' ? () => undefined : () => Promise.resolve() }; }, mode);
      for (const stage of [0,1,2]) {
        await f.locator(`[data-stage="${stage}"]`).click();
        assert.ok(await f.locator('[data-role="table"] circle').count() >= 6);
      }
    }
    await frame.evaluate(() => window.dispatchEvent(new CustomEvent('openai:set_globals', {detail:{globals:{widgetState:{modelContent:{stage:2,routeID:99,pocket:1}}}}})));
    const layouts=[];
    for (const width of [800,360,320]) {
      await page.setViewportSize({width,height:900});
      await page.waitForTimeout(100);
      const layout=await frame.evaluate(() => ({width:innerWidth,scroll:document.documentElement.scrollWidth,invalid:[...document.querySelectorAll('svg *')].some(e=>[...e.attributes].some(a=>/NaN|Infinity|undefined/.test(a.value)))}));
      assert.equal(layout.invalid,false);assert.ok(layout.scroll<=layout.width+1);
      layouts.push(layout);
      if (!process.argv[2]) await page.screenshot({path:path.join(__dirname,`after-${width}.png`),fullPage:true});
    }
    assert.deepEqual(errors,[]);
    const result={errors,restoredStates:checks,routePocketCombinations:routes,bridgeModes:3,stages:3,layouts};
    fs.writeFileSync(path.join(__dirname,process.argv[3] || 'review.json'),JSON.stringify(result,null,2));
    console.log(JSON.stringify(result));
  } finally { await browser.close(); }
})().catch(e=>{console.error(e);process.exitCode=1;});
