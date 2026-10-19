const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');
const fs = require('node:fs');
const f = JSON.parse(fs.readFileSync(process.env.FORMATION_TEST_FIXTURE));
assert.equal(new URL(f.baseURL).hostname, '127.0.0.1');
assert.ok(f.mongoURI.startsWith('mongodb://127.0.0.1:'));
async function request(path, method = 'GET', body, token = f.token) {
  const r = await fetch(f.baseURL + path, { method, headers: { Authorization: `Bearer ${token}`, 'Content-Type':'application/json' }, body: body && JSON.stringify(body) });
  const data = await r.json(); return { status:r.status, data };
}
function template(id = randomUUID()) { const key = `_1@${randomUUID()}`; return {id,name:'集成测试',updatedAt:new Date().toISOString(),ballKeys:[key],board:{onTable:{cueBall:{x:.2,y:.3},[key]:{x:.5,y:.25}}}}; }
function mutation(t, revision=0) {return {operationId:randomUUID(),baseRevision:revision,schemaVersion:1,template:t};}
(async()=>{
  const mongoose=require('mongoose');await mongoose.connect(f.mongoURI);
  const User=require('../../src/models/User');
  const {signAccessToken}=require('../../src/utils/jwt');
  const a=await User.create({provider:'apple'}), b=await User.create({provider:'apple'});
  f.userID=String(a._id);f.token=signAccessToken(f.userID);f.otherUserID=String(b._id);f.otherToken=signAccessToken(f.otherUserID);
  const t=template(), first=mutation(t), path='/custom-formations/'+t.id;
  let r=await request(path,'PUT',first); assert.equal(r.status,200,JSON.stringify(r.data)); assert.equal(r.data.record.revision,1);
  const own=await request('/custom-formations'); assert.equal(own.data.records.length,1);
  assert.equal((await request('/custom-formations','GET',null,f.otherToken)).data.records.length,0);
  const updates=await Promise.all(['A','B'].map(name=>request(path,'PUT',mutation({...t,name},1))));
  assert.equal(updates.filter(r=>!r.data.conflict).length,1); assert.equal(updates.filter(r=>r.data.conflict).length,1);
  r=await request(path,'PUT',first); assert.equal(r.data.record.revision,1); assert.equal(r.data.conflict,false);
  assert.equal((await request(path,'PUT',{...first,template:{...t,name:'different'}})).status,409);
  r=await request(path,'DELETE',mutation(null,2)); assert.equal(r.data.record.deleted,true);
  r=await request(path,'PUT',mutation(t,3)); assert.equal(r.data.conflict,true); assert.equal(r.data.record.deleted,true);
  for(let i=0;i<102;i++){const v=template(); const result=await request('/custom-formations/'+v.id,'PUT',mutation(v));assert.equal(result.status,200);}
  const page1=(await request('/custom-formations')).data; assert.equal(page1.records.length,100); assert.equal(page1.hasMore,true);
  const later=template();await request('/custom-formations/'+later.id,'PUT',mutation(later));
  const page2=(await request(`/custom-formations?after=${page1.next}&through=${page1.through}`)).data;
  assert.equal(page2.hasMore,false); assert.equal(page2.next,page1.through); assert.equal(page2.records.some(r=>r.clientId===later.id),false);
  assert.equal((await request(`/custom-formations?after=${page2.next}`)).data.records[0].clientId,later.id);
  // A separate disposable account verifies deletion and rejects subsequent writes.
  const v=template();await request('/custom-formations/'+v.id,'PUT',mutation(v),f.otherToken);
  const deleted=await request('/user/account','DELETE',undefined,f.otherToken);assert.equal(deleted.status,200,JSON.stringify(deleted.data));
  assert.equal((await request('/custom-formations/'+v.id,'PUT',mutation(v,1),f.otherToken)).status,401);
  const {CustomFormation,FormationChange}=require('../../src/models/CustomFormation');
  assert.equal(await CustomFormation.countDocuments({userId:f.otherUserID}),0);assert.equal(await FormationChange.countDocuments({userId:f.otherUserID}),0);
  const race=await User.create({provider:'apple'}), raceID=String(race._id), raceToken=signAccessToken(raceID);
  await Promise.all([
    ...Array.from({length:8},()=>{const t=template();return request('/custom-formations/'+t.id,'PUT',mutation(t),raceToken)}),
    request('/user/account','DELETE',undefined,raceToken)
  ]);
  assert.equal(await CustomFormation.countDocuments({userId:raceID}),0);
  assert.equal(await FormationChange.countDocuments({userId:raceID}),0);
  assert.equal(await User.countDocuments({_id:raceID}),0);
  const rollback=await User.create({provider:'apple'});
  const service=require('../../src/services/customFormation');
  const broken=template(), createChange=FormationChange.create;
  FormationChange.create=async()=>{throw new Error('injected receipt write failure')};
  try {await assert.rejects(service.mutate(String(rollback._id),service.validateMutation(broken.id,mutation(broken),false)),/injected receipt/);}
  finally {FormationChange.create=createChange;}
  assert.equal(await CustomFormation.countDocuments({userId:rollback._id}),0);
  assert.equal((await User.findById(rollback._id)).formationSequence,0);
  await User.deleteOne({_id:rollback._id});
  // Dispose only these integration accounts; simulator fixture accounts remain independent.
  await CustomFormation.deleteMany({userId:f.userID});await FormationChange.deleteMany({userId:f.userID});
  await User.deleteOne({_id:f.userID});
  await mongoose.disconnect();console.log('PASS real REST: ownership, concurrent revision, immutable receipt, deletion, stable pagination, account cleanup');
})().catch(e=>{console.error(e);process.exit(1)});
