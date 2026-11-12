// Called inside verify-deletion.cjs with its isolated HTTP server and replica set.
const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const fs = require("node:fs/promises");
const path = require("node:path");

module.exports = async function verifyAppleGrant({ backend, directory, call, seed, counts, block, report }) {
  const apple = backend("apple-signin-auth");
  const jwt = backend("jsonwebtoken");
  const config = backend("./src/config");
  const User = backend("./src/models/User");
  const { resumePendingDeletions } = backend("./src/services/accountDeletion");
  const { privateKey, publicKey } = crypto.generateKeyPairSync("ec", { namedCurve: "P-256" });
  process.env.APPLE_SIGNIN_KEY_PATH = path.join(directory, "fixture-signing-key.p8");
  await fs.writeFile(process.env.APPLE_SIGNIN_KEY_PATH, privateKey.export({ type:"pkcs8", format:"pem" }), { mode:0o600 });
  process.env.APPLE_TOKEN_ENCRYPTION_KEY = crypto.randomBytes(32).toString("hex");
  process.env.APPLE_TEAM_ID = "FIXTURETEAM";
  process.env.APPLE_KEY_ID = "FIXTUREKEY";
  const rsa = crypto.generateKeyPairSync("rsa", {modulusLength:2048});
  const kid = "fixture-rsa";
  const idToken = sub => jwt.sign({}, rsa.privateKey, { algorithm:"RS256", keyid:kid, expiresIn:"5m", subject:sub,
    audience:config.appleBundleId, issuer:"https://appleid.apple.com" });
  const realFetch = global.fetch;
  const subject = "fixture-apple-user";
  const grants = new Set(), used = new Set();
  let failRevoke = false, attempts = 0;
  apple._setFetch(async url => {
    assert.equal(url, "https://appleid.apple.com/auth/keys");
    const jwk = rsa.publicKey.export({format:"jwk"});
    return Response.json({keys:[{...jwk, kid, alg:"RS256"}]});
  });
  global.fetch = async (url, opts) => {
    if (!String(url).startsWith("https://appleid.apple.com/")) {
      assert.equal(new URL(url).hostname,"127.0.0.1");
      return realFetch(url,opts);
    }
    assert.equal(opts.redirect,"error");
    const fields = opts.body;
    const secret = jwt.verify(fields.get("client_secret"), publicKey, { algorithms:["ES256"], issuer:"FIXTURETEAM", audience:"https://appleid.apple.com" });
    assert.equal(secret.sub,config.appleBundleId);
    if (url.endsWith("/token")) {
      assert.equal(fields.get("grant_type"),"authorization_code");
      const code = fields.get("code");
      if (used.has(code)) return Response.json({error:"invalid_grant"},{status:400});
      used.add(code);
      const token = crypto.randomUUID();grants.add(token);
      return Response.json({refresh_token:token,id_token:idToken(code === "wrong-user" ? "other-user" : subject)});
    }
    assert.equal(new URL(url).pathname,"/auth/revoke");
    assert.equal(fields.get("token_type_hint"),"refresh_token");
    assert(grants.has(fields.get("token")));
    attempts++;
    return new Response(null,{status:failRevoke ? 503 : 200});
  };
  const login = (code, identity=subject) => call({}, "POST","/auth/login-apple",{age14Confirmed:true,identityToken:idToken(identity),authorizationCode:code});
  const remove = account => call(account,"DELETE","/user/account");
  const empty = object => Object.values(object).every(n=>n===0);
  try {
    assert.equal((await login(undefined)).status,400);
    assert.equal((await login("wrong-user")).status,401);
    assert.equal(await User.countDocuments({appleUserId:subject}),0);
    const first=await login("first");
    assert.equal(first.status,200);
    const old={id:first.body.user.id,token:first.body.accessToken};
    assert.equal((await login("first")).status,401);
    assert.equal((await login("returning")).body.user.id,old.id);
    assert.equal((await login(undefined)).body.user.id,old.id);
    const stored=await User.findById(old.id).select("+appleGrant").lean();
    assert.equal(typeof stored.appleGrant,"string");
    for (const grant of grants) assert(!JSON.stringify(stored).includes(grant));
    assert.equal(first.body.user.appleGrant,undefined);
    await seed(old);
    const awaitMark=await block("delete");
    const closing=remove(old);
    await awaitMark();
    assert.equal((await login("frozen")).status,401);
    const closed=await closing;
    assert.equal(closed.status,200);assert.equal(closed.body.appleRevocation,"revoked");
    assert(empty(await counts(old)));
    const fresh=await login("fresh");
    assert.equal(fresh.status,200);assert.notEqual(fresh.body.user.id,old.id);
    const next={id:fresh.body.user.id,token:fresh.body.accessToken};
    assert.equal((await call(old,"GET","/training-sessions")).status,401);
    assert.deepEqual((await call(next,"GET","/training-sessions")).body,[]);
    await seed(next);failRevoke=true;
    const pending=await remove(next);
    assert.equal(pending.status,202);assert.equal(pending.body.appleRevocation,"pending");
    assert.equal((await call(next,"GET","/user/profile")).status,401);
    assert.equal((await login("pending")).status,401);
    const remaining=await counts(next);assert.equal(remaining.user,1);delete remaining.user;assert(empty(remaining));
    const attemptBefore=attempts;
    await resumePendingDeletions(directory);assert.equal(attempts,attemptBefore);
    await User.updateOne({_id:next.id},{$set:{appleRevokeLeaseUntil:new Date(0)}});
    failRevoke=false;
    await resumePendingDeletions(directory);
    assert.equal(attempts,attemptBefore+1);assert(empty(await counts(next)));
    const legacy=await User.create({provider:"apple",appleUserId:"legacy-apple"});
    const legacyResponse=await remove({id:legacy.id,token:backend("./src/utils/jwt").signAccessToken(legacy.id)});
    assert.equal(legacyResponse.status,200);assert.equal(legacyResponse.body.appleRevocation,"manual");
    report.appleFixture={repeatedLoginSameAccount:true,deniedWhileDeleting:true,newEmptyAccount:true};
    return {transport:"isolated Apple HTTP fixtures with signed RSA identity and ES256 client secret",checks:{
      newAccountRequiresCode:true,mismatchedIdentityRefused:true,replayedCodeRefused:true,encryptedAtRest:true,
      existingClientCompatible:true,normalRevocation:200,oldAccessRefused:401,pendingOnAppleFailure:202,
      frozenDuringRetry:true,payloadPurgedBeforeRetry:true,leasePreventsDuplicateRetry:true,
      recoveryWithoutUserSession:true,legacyDeletionWithManualGuidance:200,newEmptyAccount:true}};
  } finally { global.fetch=realFetch;apple._setFetch(realFetch); }
};
