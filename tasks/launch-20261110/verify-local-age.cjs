const assert = require("node:assert/strict");
const path = require("node:path");
const crypto = require("node:crypto");
const backend = require("node:module").createRequire(path.resolve("backend/package.json"));
const runtime = path.resolve("output/custom-formation-sync-20261019/runtime/node_modules/mongodb-memory-server");
const http = global.fetch;
process.env.JWT_SECRET = crypto.randomBytes(32).toString("hex");
process.env.JWT_REFRESH_SECRET = crypto.randomBytes(32).toString("hex");
process.env.WECHAT_APP_ID = "local-synthetic";
process.env.WECHAT_APP_SECRET = "local-synthetic";
let providerCalls = 0;
global.fetch = async url => {
  providerCalls += 1;
  assert.equal(new URL(url).origin, "https://api.weixin.qq.com");
  return Response.json({openid:"fixture_" + new URL(url).searchParams.get("code"),access_token:"fixture_only"});
};
(async () => {
  const mongo = await require(runtime).MongoMemoryReplSet.create({
    binary:{systemBinary:path.join(runtime,"mongodb-binaries/mongod-arm64-darwin-7.0.24"),version:"7.0.24"},
    replSet:{count:1, ip:"127.0.0.1",storageEngine:"wiredTiger"}
  });
  const db=backend("mongoose");
  let srv;
  try {
    await db.connect(mongo.getUri("age_fixture"));
    srv=backend("./src/app").createApp().listen(0,"127.0.0.1");
    await require("node:events").once(srv,"listening");
    const base="http://127.0.0.1:"+srv.address().port;
    const User=backend("./src/models/User"), Session=backend("./src/models/TrainingSession");
    const checkpoints=[];
    let token, uid;
    async function req(label, method, route, body, expect) {
      const r=await http(base+route,{method,headers:{"Content-Type":"application/json",...(token?{Authorization:"Bearer "+token}:{})},body:JSON.stringify(body)});
      assert.equal(r.status,expect,label); checkpoints.push({label,method,route,status:r.status}); return r.json();
    }
    const {latestEligibleBirthday} = backend("./src/services/accountAge");
    const boundary = latestEligibleBirthday();
    const child = new Date().toISOString().slice(0,10);
    const session = {clientId:crypto.randomUUID(),date:new Date().toISOString(),kind:"drill",totalDurationMinutes:1};
    for (const provider of ["wechat", "apple"]) {
      for (const flag of [undefined,false]) {
        await req("no confirmation: "+provider,"POST","/auth/login-"+provider,{age14Confirmed:flag,createIfMissing:true},403);
      }
    }
    assert.equal(providerCalls, 0);
    assert.equal(await User.countDocuments(),0);
    await req("guest cloud write","POST","/training-sessions",session,401);
    const login = {code:"simulated",age14Confirmed:true,createIfMissing:true};
    const user = await req("age confirmed","POST","/auth/login-wechat",login,200);
    uid=user.user.id; token=user.accessToken;
    await req("reject child birthday import","POST","/user/profile/import-initial",{accountID:uid,fields:{birthDate:child}},403);
    await req("reject child birthday edit","PUT","/user/profile",{birthDate:child},403);
    assert.equal((await User.findById(uid)).birthDate,undefined);
    await req("fourteenth birthday","PUT","/user/profile",{birthDate:boundary},200);
    await req("eligible cloud write","POST","/training-sessions",session,201);
    assert.equal(await Session.countDocuments({userId:uid}),1);
    const { ageDistribution } = backend("./src/scripts/ageDistribution");
    const importBand = (band) => ({accountID:uid,fields:{ageBand:band}});
    assert.equal((await ageDistribution()).answered,0);
    await req("reject child survey value","POST","/user/profile/import-initial",importBand("under14"),400);
    await req("voluntary age band","POST","/user/profile/import-initial",importBand("25-34"),200);
    await req("duplicate import preserves original answer","POST","/user/profile/import-initial",importBand("35-44"),200);
    const unansweredUser = await req("second login with survey skipped","POST","/auth/login-wechat",{...login,code:"skipped"},200);
    assert.notEqual(unansweredUser.user.id,uid);
    const survey=await ageDistribution();
    assert.equal(survey.loggedInAccounts,2);
    assert.equal(survey.answered,1);
    assert.equal(survey.responsePercent,50);
    assert.equal(survey.distribution.find(row=>row.ageBand==="25-34").percentOfRespondents,100);
    assert.equal(survey.distribution.find(row=>row.ageBand==="35-44").accounts,0);
    const emptyCohort = await ageDistribution({beginnersOnly:true});
    assert.equal(emptyCohort.loggedInAccounts,0);
    assert.equal(emptyCohort.responsePercent,null);
    await req("beginner reports experience","PUT","/user/profile",{yearsPlaying:"lessThan1"},200);
    const beginners=await ageDistribution({beginnersOnly:true});
    assert.equal(beginners.loggedInAccounts,1);
    assert.equal(beginners.answered,1);
    const jwt=backend("jsonwebtoken");
    token=jwt.sign({sub:uid},process.env.JWT_SECRET);
    await req("pre-update session","GET","/user/profile",undefined,401);
    const legacyRefresh=jwt.sign({sub:uid,type:"refresh"},process.env.JWT_REFRESH_SECRET);
    await req("pre-update refresh","POST","/auth/refresh",{refreshToken:legacyRefresh},401);
    token=user.accessToken;
    await User.updateOne({_id:uid},{$set:{birthDate:child}});
    await req("existing child account login","POST","/auth/login-wechat",login,403);
    await req("existing child account write","POST","/training-sessions",{...session,clientId:crypto.randomUUID()},401);
    await req("existing child account refresh","POST","/auth/refresh",{refreshToken:user.refreshToken},401);
    assert.equal(await Session.countDocuments({userId:uid}),1);
    console.log(JSON.stringify({checkedAt:new Date().toISOString(),scope:"Loopback Express and isolated MongoDB; synthetic identities; simulated WeChat",survey,checkpoints},null,2));
  } finally { if(srv) {srv.closeAllConnections(); await new Promise(resolve=>srv.close(resolve));} await db.disconnect(); await mongo.stop(); }
})().catch(e=>{console.error(e);process.exitCode=1});
