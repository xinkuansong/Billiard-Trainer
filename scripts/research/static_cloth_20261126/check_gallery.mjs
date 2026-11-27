import fs from 'node:fs/promises';
import path from 'node:path';
import {spawn} from 'node:child_process';
import {once} from 'node:events';
const work=process.env.QIUJI_TEST_WORK,evidence=process.env.QIUJI_TEST_EVIDENCE;
if(!work||!evidence)throw Error('Managed run required');
const profile=path.join(work,'isolated-chrome');await fs.mkdir(profile);
const child=spawn('/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',['--headless=new','--no-first-run','--no-default-browser-check','--remote-debugging-port=0','--user-data-dir='+profile,'about:blank'],{stdio:['ignore','ignore','pipe']});
let log='';child.stderr.on('data',x=>log+=x.toString());let ws,id=0;const pending=new Map();
const pause=ms=>new Promise(r=>setTimeout(r,ms));
try {
 let port;
 for(let i=0;i<100;i++){try{port=(await fs.readFile(path.join(profile,'DevToolsActivePort'),'utf8')).split('\n')[0];break}catch{await pause(100)}}
 if(!port)throw Error('Isolated Chrome did not open debugging endpoint');
 const targets=await (await fetch('http://127.0.0.1:'+port+'/json/list')).json();const page=targets.find(t=>t.type==='page');
 ws=new WebSocket(page.webSocketDebuggerUrl);await new Promise((r,j)=>{ws.addEventListener('open',r,{once:true});ws.addEventListener('error',j,{once:true})});
 ws.addEventListener('message',event=>{const v=JSON.parse(event.data);if(pending.has(v.id)){const {r,j}=pending.get(v.id);pending.delete(v.id);v.error?j(Error(JSON.stringify(v.error))):r(v.result)}});
 const send=(method,params={})=>new Promise((r,j)=>{const key=++id;pending.set(key,{r,j});ws.send(JSON.stringify({id:key,method,params}))});
 const evaluate=async expression=>{const v=await send('Runtime.evaluate',{expression,returnByValue:true,awaitPromise:true});if(v.exceptionDetails)throw Error(JSON.stringify(v.exceptionDetails));return v.result.value};
 await send('Page.enable');await send('Emulation.setDeviceMetricsOverride',{width:1440,height:1000,deviceScaleFactor:1,mobile:false});
 await send('Page.navigate',{url:process.argv[2]});
 for(let i=0;i<100;i++){if(await evaluate("document.querySelector('#a')?.complete && document.querySelector('#a').naturalWidth===1400 && document.querySelector('#b')?.naturalWidth===1400"))break;await pause(100);if(i===99)throw Error('Initial images did not load')}
 const frames=[];
 for(const [group,index] of [['每日机位',0],['环绕／球在台面',10],['环绕／球在台面',28],['环绕／抬高球',46],['袋口 1',5]]) {
  await evaluate(`(async()=>{stop();select.value=${JSON.stringify(group)};slider.value=0;await show();slider.value=${index};await show();})()`);
  const state=await evaluate("({status:status.textContent,frame:Number(slider.value),group:select.value,a:document.querySelector('#a').naturalWidth,b:document.querySelector('#b').naturalWidth})");
  if(state.frame!==index||state.a!==1400||state.b!==1400)throw Error('Frame mismatch '+JSON.stringify(state));
  const shot=await send('Page.captureScreenshot',{format:'png'});const name='viewer-'+frames.length+'.png';await fs.writeFile(path.join(evidence,name),Buffer.from(shot.data,'base64'));frames.push({...state,screenshot:name});
 }
 await evaluate("select.value='环绕／球在台面';slider.value=0;show()");await evaluate("document.querySelector('#play').click()");await pause(1200);const playFrame=await evaluate('Number(slider.value)');await evaluate('stop()');if(playFrame<2)throw Error('Playback did not advance');
 await fs.writeFile(path.join(evidence,'gallery-browser-check.json'),JSON.stringify({frames,playFrame,scope:'Isolated headless Chrome; actual PNGs loaded and paired frame controls/playback exercised. No existing user browser profile accessed.'},null,2)+'\n');
 console.log(JSON.stringify({captured:frames.length,playFrame}));
 await send('Browser.close');
} finally {
 if(ws)ws.close();if(child.exitCode===null){child.kill('SIGTERM');await Promise.race([once(child,'exit'),pause(5000)])}
 await fs.writeFile(path.join(evidence,'chrome.log'),log);
}
