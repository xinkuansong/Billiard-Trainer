// Explicit production deployment probe. Only creates/mutates its own synthetic users.
// Run on the backend host with PRODUCTION_FORMATION_SMOKE=authorized; never logs tokens.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const {randomUUID} = require('node:crypto');
assert.equal(process.env.PRODUCTION_FORMATION_SMOKE, 'authorized');
const app = '/opt/qiuji-backend';
const req = require('node:module').createRequire(app + '/package.json');
req('dotenv').config({path:app+'/.env'});
const mongoose=req('mongoose'), config=req('./src/config');
const User=req('./src/models/User');
const {CustomFormation,FormationChange}=req('./src/models/CustomFormation');
const {signAccessToken,signRefreshToken}=req('./src/utils/jwt');
const base='http://106.54.3.210:3000';
const created=[];
let checks=0;
const pass=name=>{checks++;console.log('PASS '+name);};
async function request(path,method='GET',body,token) {
  const response=await fetch(base+path,{method,headers:{'Content-Type':'application/json',...(token?{Authorization:'Bearer '+token}:{})},body:body===undefined?undefined:JSON.stringify(body),signal:AbortSignal.timeout(15000)});
  return {status:response.status,data:await response.json()};
}
async function account() {
  const user=await User.create({provider:'apple',displayName:'formation-deploy-probe-'+randomUUID()});
  created.push(user._id);return {id:String(user._id),token:signAccessToken(String(user._id))};
}
function template(count=25) {
  const id=randomUUID(),ballKeys=Array.from({length:count},()=>`_1@${randomUUID()}`);
  const vertices=[{id:randomUUID(),x:-.5,z:0},{id:randomUUID(),x:0,z:0},{id:randomUUID(),x:.5,z:.2}];
  return {id,name:'生产同步验收',updatedAt:new Date().toISOString(),ballKeys,
    board:{onTable:Object.fromEntries([['cueBall',{x:.2,y:.4}],...ballKeys.map((key,i)=>[key,{x:.3+i*.01,y:.25}])])},
    drawing:{vertices,lines:[{id:randomUUID(),start:vertices[0].id,end:vertices[1].id,balls:ballKeys.slice(0,12)},{id:randomUUID(),start:vertices[1].id,end:vertices[2].id,balls:ballKeys.slice(12)}]}};
}
const mutation=(template,baseRevision=0)=>({operationId:randomUUID(),baseRevision,schemaVersion:1,template});
(async()=>{
  await mongoose.connect(config.mongodbUri);
  try {
    const a=await account(),b=await account();
    assert.equal((await request('/health')).data.status,'ok');pass('public endpoint health');
    for(const method of ['GET','PUT','DELETE']) {
      const path=method==='GET'?'/custom-formations':'/custom-formations/'+randomUUID();
      assert.equal((await request(path,method,method==='GET'?undefined:{})).status,401);
    } pass('GET PUT DELETE require authentication');
    const refresh=signRefreshToken(a.id);await User.updateOne({_id:a.id},{$set:{refreshToken:refresh}});
    const renewed=await request('/auth/refresh','POST',{refreshToken:refresh});assert.equal(renewed.status,200);
    assert.ok(renewed.data.accessToken);a.token=renewed.data.accessToken;pass('existing refresh-token flow');
    const t=template(),path='/custom-formations/'+t.id,first=mutation(t);
    const create=await request(path,'PUT',first,a.token);assert.equal(create.status,200);assert.equal(create.data.conflict,false);assert.equal(create.data.record.revision,1);pass('25 repeated targets plus cue, connected lines saved');
    // A fresh request is device B's empty cursor / cold restore of device A's data.
    const cold=await request('/custom-formations?after=0','GET',undefined,a.token);
    assert.deepEqual(cold.data.records[0].template,t);pass('second client cold restore preserves instance IDs, ball order and shared vertices');
    assert.equal((await request('/custom-formations','GET',undefined,b.token)).data.records.length,0);
    assert.equal((await request(path,'PUT',mutation({...t,name:'cross-account'},1),b.token)).data.conflict,true);
    assert.equal((await request(path,'DELETE',mutation(null,1),b.token)).data.conflict,true);pass('account isolation on list update and delete');
    const tooMany=template(26);assert.equal((await request('/custom-formations/'+tooMany.id,'PUT',mutation(tooMany),a.token)).status,422);pass('26 target balls rejected');
    const both=await Promise.all(['device A','device B'].map(name=>request(path,'PUT',mutation({...t,name},1),a.token)));
    both.forEach(r=>assert.equal(r.status,200));assert.equal(both.filter(r=>r.data.conflict).length,1);
    const winner=both.find(r=>!r.data.conflict).data.record;assert.equal(winner.revision,2);pass('concurrent edits return exactly one winner and one conflict');
    const copy={...t,id:randomUUID(),name:'离线修改 冲突副本'};
    assert.equal((await request('/custom-formations/'+copy.id,'PUT',mutation(copy),a.token)).status,200);pass('client can preserve conflicting edit under a new template ID');
    const replay=await request(path,'PUT',first,a.token);assert.deepEqual(replay.data,create.data);pass('lost-response retry replays immutable original receipt');
    assert.equal((await request(path,'PUT',{...first,template:{...t,name:'different'}},a.token)).status,409);pass('operation ID reuse with different payload rejected');
    const del=await request(path,'DELETE',mutation(null,2),a.token);assert.equal(del.data.record.deleted,true);
    const increment=await request('/custom-formations?after='+cold.data.next,'GET',undefined,a.token);
    assert.ok(increment.data.records.some(r=>r.clientId===t.id&&r.deleted));
    const revive=await request(path,'PUT',mutation(t,3),a.token);assert.equal(revive.data.conflict,true);assert.equal(revive.data.record.deleted,true);pass('incremental deletion and stale-device resurrection prevention');
    for(let i=0;i<101;i++){const item=template(1);const r=await request('/custom-formations/'+item.id,'PUT',mutation(item),a.token);assert.equal(r.status,200);}
    const page1=(await request('/custom-formations','GET',undefined,a.token)).data;assert.equal(page1.records.length,100);assert.equal(page1.hasMore,true);
    const later=template(1);await request('/custom-formations/'+later.id,'PUT',mutation(later),a.token);
    const page2=(await request(`/custom-formations?after=${page1.next}&through=${page1.through}`,'GET',undefined,a.token)).data;
    assert.equal(page2.hasMore,false);assert.equal(page2.next,page1.through);assert.ok(!page2.records.some(r=>r.clientId===later.id));
    assert.equal((await request('/custom-formations?after='+page2.next,'GET',undefined,a.token)).data.records[0].clientId,later.id);pass('100-record pagination keeps frozen boundary during concurrent new writes');
    const invalid=await request('/custom-formations?after=-1','GET',undefined,a.token);assert.equal(invalid.status,400);pass('invalid cursors rejected');
    const rollback=await account(), service=req('./src/services/customFormation');
    const broken=template(1),originalCreate=FormationChange.create;
    FormationChange.create=async()=>{throw Error('probe planned rollback')};
    try{await assert.rejects(service.mutate(rollback.id,service.validateMutation(broken.id,mutation(broken),false)),/probe planned rollback/);}finally{FormationChange.create=originalCreate;}
    assert.equal(await CustomFormation.countDocuments({userId:rollback.id}),0);
    assert.equal((await User.findById(rollback.id)).formationSequence,0);pass('actual sync transaction failure leaves no template or counter change');
    const race=await account();
    const results=await Promise.all([...Array.from({length:6},()=>{const v=template(1);return request('/custom-formations/'+v.id,'PUT',mutation(v),race.token)}),request('/user/account','DELETE',undefined,race.token)]);
    results.slice(0,-1).forEach(r=>assert.ok([200,401].includes(r.status)));assert.equal(results.at(-1).status,200);
    assert.equal(await User.countDocuments({_id:race.id}),0);assert.equal(await CustomFormation.countDocuments({userId:race.id}),0);assert.equal(await FormationChange.countDocuments({userId:race.id}),0);pass('account deletion racing with writes leaves no orphan data');
    const profile=await request('/user/profile','PUT',{gender:'female',birthDate:'1990-01-02'},a.token);assert.equal(profile.status,200);
    const partial=await request('/user/profile','PUT',{displayName:'probe partial'},a.token);assert.equal(partial.data.gender,'female');assert.equal(partial.data.birthDate,'1990-01-02');pass('existing profile partial-update contract retained');
    for(const endpoint of ['/training-sessions','/angle-tests']) assert.equal((await request(endpoint,'GET',undefined,a.token)).status,200);
    assert.equal((await request('/drills')).status,200);pass('existing training angle and drill endpoints');
    assert.equal((await request('/user/account','DELETE',undefined,a.token)).status,200);
    assert.equal(await CustomFormation.countDocuments({userId:a.id}),0);assert.equal(await FormationChange.countDocuments({userId:a.id}),0);
    assert.equal((await request(path,'PUT',mutation(t,3),a.token)).status,401);pass('account deletion purges templates receipts and rejects old access token');
    console.log(`PASS ${checks} production checks`);
  } finally {
    for(const id of created) {
      // Only IDs returned by this run's User.create can enter this cleanup path.
      await CustomFormation.deleteMany({userId:id});await FormationChange.deleteMany({userId:id});await User.deleteOne({_id:id});
    }
    assert.equal(await User.countDocuments({_id:{$in:created}}),0);
    assert.equal(await CustomFormation.countDocuments({userId:{$in:created}}),0);
    assert.equal(await FormationChange.countDocuments({userId:{$in:created}}),0);
    console.log('PASS all synthetic accounts and associated records removed');
    await mongoose.disconnect();
  }
})().catch(e=>{console.error('FAIL',e.name,e.codeName||'',e.message?.replace(/mongodb:\/\/\S+/g,'[redacted]'));process.exitCode=1;});
