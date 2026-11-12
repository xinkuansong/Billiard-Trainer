// A fresh local MongoDB replica, real HTTP routes, signed Apple tokens and simulated provider HTTP.
const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const fs = require("node:fs/promises");
const os = require("node:os");
const path = require("node:path");
const { once } = require("node:events");
const { createRequire } = require("node:module");

const root = path.resolve(__dirname, "../..");
const backend = createRequire(path.join(root, "backend/package.json"));
const runtime = path.join(
  root,
  "output/custom-formation-sync-20261019/runtime/node_modules/mongodb-memory-server",
);
const { MongoMemoryReplSet } = require(runtime);
const mongoose = backend("mongoose");

async function run() {
  const tmp = await fs.mkdtemp(path.join(os.tmpdir(), "cuephys-link-"));
  const clientID = "com.test.cuephys";
  Object.assign(process.env, {
    AVATAR_STORAGE_DIR: path.join(tmp, "avatars"),
    DELETION_CHECKPOINT_DIR: path.join(tmp, "checkpoints"),
    APPLE_BUNDLE_ID: clientID,
    APPLE_TEAM_ID: "LOCALTEAM",
    APPLE_KEY_ID: "LOCALKEY",
    APPLE_SIGNIN_KEY_PATH: path.join(tmp, "apple-test-key"),
    APPLE_TOKEN_ENCRYPTION_KEY: crypto.randomBytes(32).toString("hex"),
    JWT_SECRET: crypto.randomUUID(),
    JWT_REFRESH_SECRET: crypto.randomUUID(),
    WECHAT_APP_ID: "fixture-mobile-app",
    WECHAT_APP_SECRET: crypto.randomUUID(),
  });
  const signing = crypto.generateKeyPairSync("ec", { namedCurve: "P-256" });
  await fs.writeFile(
    process.env.APPLE_SIGNIN_KEY_PATH,
    signing.privateKey.export({ type: "pkcs8", format: "pem" }),
    { mode: 0o600 },
  );
  const rsa = crypto.generateKeyPairSync("rsa", { modulusLength: 2048 });
  const jwt = backend("jsonwebtoken");
  const apple = backend("apple-signin-auth");
  apple._setFetch(async (url) => {
    assert.equal(url, "https://appleid.apple.com/auth/keys");
    return Response.json({ keys: [{ ...rsa.publicKey.export({ format: "jwk" }), kid: "fixture" }] });
  });
  function identityToken(subject, audience = clientID) {
    return jwt.sign({ email: "same@example.test" }, rsa.privateKey, {
      algorithm: "RS256",
      keyid: "fixture",
      issuer: "https://appleid.apple.com",
      audience,
      subject,
      expiresIn: "5m",
    });
  }
  const grants = { apple: new Map(), wechat: new Map() };
  function credentials(provider, subject) {
    const code = crypto.randomUUID();
    grants[provider].set(code, subject);
    return provider === "wechat"
      ? { code }
      : { identityToken: identityToken(subject), authorizationCode: code };
  }
  const realFetch = global.fetch;
  const revoked = [];
  let exchangeStarted, resumeExchange;
  const started = new Promise((resolve) => {
    exchangeStarted = resolve;
  });
  const resume = new Promise((resolve) => {
    resumeExchange = resolve;
  });
  global.fetch = async (input, options) => {
    const url = new URL(input);
    if (url.hostname === "127.0.0.1") return realFetch(input, options);
    assert.equal(options.redirect, "error");
    if (url.origin === "https://api.weixin.qq.com") {
      assert.equal(url.pathname, "/sns/oauth2/access_token");
      const query = url.searchParams;
      assert.equal(query.get("appid"), process.env.WECHAT_APP_ID);
      assert.equal(query.get("secret"), process.env.WECHAT_APP_SECRET);
      assert.equal(query.get("grant_type"), "authorization_code");
      const code = query.get("code"),
        subject = grants.wechat.get(code);
      if (!subject) return Response.json({ errcode: 40163 });
      grants.wechat.delete(code);
      if (subject === "delayed-exchange") {
        exchangeStarted();
        await resume;
      }
      return Response.json({ openid: subject, access_token: "wx-private-fixture" });
    }
    assert.equal(url.origin, "https://appleid.apple.com");
    const fields = options.body;
    jwt.verify(fields.get("client_secret"), signing.publicKey, {
      algorithms: ["ES256"],
      issuer: "LOCALTEAM",
      audience: "https://appleid.apple.com",
    });
    if (url.pathname === "/auth/revoke") {
      assert.equal(fields.get("token_type_hint"), "refresh_token");
      revoked.push(fields.get("token"));
      return new Response(null, { status: 200 });
    }
    assert.equal(url.pathname, "/auth/token");
    const code = fields.get("code"),
      subject = grants.apple.get(code);
    if (!subject) return Response.json({ error: "invalid_grant" }, { status: 400 });
    grants.apple.delete(code);
    return Response.json({
      id_token: identityToken(subject),
      refresh_token: "apple-private-fixture-" + subject,
    });
  };

  const User = backend("./src/models/User");
  const Training = backend("./src/models/TrainingSession");
  const { CustomFormation, FormationChange } = backend("./src/models/CustomFormation");
  let mongo, server;
  const report = {
    testedAt: new Date().toISOString(),
    scope: "isolated MongoDB + production HTTP routes + simulated Apple/WeChat responses",
  };
  try {
    mongo = await MongoMemoryReplSet.create({
      binary: {
        systemBinary: path.join(runtime, "mongodb-binaries/mongod-arm64-darwin-7.0.24"),
        version: "7.0.24",
      },
      replSet: { count: 1, ip: "127.0.0.1", storageEngine: "wiredTiger" },
      instanceOpts: [{ args: ["--wiredTigerCacheSizeGB", "0.25"] }],
    });
    await mongoose.connect(mongo.getUri("cuephys_link_test"));
    process.env.DELETION_LEDGER_URI = mongo.getUri("cuephys_link_deletions");
    await fs.mkdir(process.env.DELETION_CHECKPOINT_DIR);
    await backend("./src/services/deletionLedger").initializeLedger();
    await Promise.all([User, Training, CustomFormation, FormationChange].map((model) => model.init()));
    const indexes = await User.collection.indexes();
    for (const field of ["appleUserId", "wechatIdentity"])
      assert.ok(indexes.some((i) => i.unique && i.sparse && i.key[field] === 1));
    server = backend("./src/app").createApp().listen(0, "127.0.0.1");
    await once(server, "listening");
    async function call(method, route, body, session) {
      const headers = { "Content-Type": "application/json" };
      if (session) headers.Authorization = "Bearer " + session.accessToken;
      const response = await fetch("http://127.0.0.1:" + server.address().port + route, {
        method,
        headers,
        body: JSON.stringify(body && route.startsWith("/auth/login-") ? {age14Confirmed: true, ...body} : body),
      });
      return { status: response.status, body: await response.json() };
    }
    async function login(provider, subject, createIfMissing = false) {
      const result = await call("POST", "/auth/login-" + provider, {
        ...credentials(provider, subject),
        createIfMissing,
      });
      assert.equal(result.status, 200);
      return result.body;
    }
    function bind(session, provider, subject) {
      return call(
        "POST",
        "/auth/bind-" + provider,
        { ...credentials(provider, subject), refreshToken: session.refreshToken },
        session,
      );
    }
    async function seed(session, label) {
      assert.equal(
        (
          await call(
            "POST",
            "/training-sessions",
            { clientId: label, date: new Date(), note: label },
            session,
          )
        ).status,
        201,
      );
      const id = crypto.randomUUID(),
        ball = "_1@" + crypto.randomUUID();
      const template = {
        id,
        name: label,
        updatedAt: new Date().toISOString(),
        ballKeys: [ball],
        board: { onTable: { cueBall: { x: 0.2, y: 0.2 }, [ball]: { x: 0.4, y: 0.3 } } },
      };
      assert.equal(
        (
          await call(
            "PUT",
            "/custom-formations/" + id,
            { baseRevision: 0, schemaVersion: 1, operationId: crypto.randomUUID(), template },
            session,
          )
        ).status,
        200,
      );
    }
    async function records(session) {
      const training = await call("GET", "/training-sessions", undefined, session);
      const shapes = await call("GET", "/custom-formations", undefined, session);
      assert.equal(training.status, 200);
      assert.equal(shapes.status, 200);
      assert.equal(training.body.length, 1);
      assert.equal(shapes.body.records.length, 1);
      return { training: training.body, shapes: shapes.body };
    }
    for (const [first, second] of [
      ["apple", "wechat"],
      ["wechat", "apple"],
    ]) {
      const name = first + "-first";
      const a = await login(first, name, true);
      await seed(a, name);
      const expected = await records(a);
      const noSignup = await call("POST", "/auth/login-" + second, {
        ...credentials(second, name),
        createIfMissing: false,
      });
      assert.equal(noSignup.body.code, "IDENTITY_NOT_REGISTERED");
      const linked = await bind(a, second, name);
      assert.equal(linked.status, 200);
      assert.deepEqual(linked.body.user.linkedProviders, ["apple", "wechat"]);
      assert.equal(linked.body.user.id, a.user.id);
      assert.equal((await bind(a, second, name)).status, 200);
      assert.equal((await call("DELETE", "/auth/logout", undefined, a)).status, 200);
      assert.equal((await bind(a, second, name)).status, 401);
      const b = await login(second, name);
      assert.equal(b.user.id, a.user.id);
      assert.deepEqual(await records(b), expected);
      const edit = await call(
        "PUT",
        "/training-sessions/" + expected.training[0]._id,
        { note: "bound-" + name },
        b,
      );
      assert.equal(edit.status, 200);
      const edited = await records(b);
      assert.equal(edited.training[0].note, "bound-" + name);
      const original = await login(first, name);
      assert.equal(original.user.id, a.user.id);
      assert.deepEqual(await records(original), edited);
      report[name] = {
        unchangedAccount: true,
        unchangedTrainingAndFormations: true,
        editVisibleThroughOriginalLogin: true,
        repeatBinding: 200,
        loggedOutBinding: 401,
      };
    }
    assert.equal(await User.countDocuments(), 2);
    const a = await login("apple", "conflict-a", true),
      b = await login("wechat", "conflict-b", true);
    await seed(a, "account-A");
    await seed(b, "account-B");
    const [aData, bData] = await Promise.all([records(a), records(b)]);
    const before = await User.collection
      .find({
        _id: { $in: [new mongoose.Types.ObjectId(a.user.id), new mongoose.Types.ObjectId(b.user.id)] },
      })
      .sort({ _id: 1 })
      .toArray();
    for (const result of [await bind(a, "wechat", "conflict-b"), await bind(b, "apple", "conflict-a")]) {
      assert.equal(result.status, 409);
      assert.equal(result.body.code, "IDENTITY_CONFLICT");
    }
    assert.deepEqual(
      await User.collection
        .find({ _id: { $in: before.map((doc) => doc._id) } })
        .sort({ _id: 1 })
        .toArray(),
      before,
    );
    assert.deepEqual(await records(a), aData);
    assert.deepEqual(await records(b), bData);
    const aAgain = await login("apple", "conflict-a"),
      bAgain = await login("wechat", "conflict-b");
    assert.equal(aAgain.user.id, a.user.id);
    assert.deepEqual(await records(aAgain), aData);
    assert.equal(bAgain.user.id, b.user.id);
    assert.deepEqual(await records(bAgain), bData);
    report.twoPopulatedAccounts = { bothDirections: 409, originalUsersAndRecordsUnchanged: true };

    const contender = await login("apple", "other-apple", true);
    const outcomes = await Promise.all([
      bind(aAgain, "wechat", "unclaimed"),
      bind(contender, "wechat", "unclaimed"),
    ]);
    assert.deepEqual(outcomes.map((x) => x.status).sort(), [200, 409]);
    const winner = outcomes[0].status === 200 ? a : contender;
    assert.equal((await login("wechat", "unclaimed")).user.id, winner.user.id);
    report.racingBindings = { oneOwner: true, statuses: [200, 409] };
    const active = await login("apple", "conflict-a");
    const malformed = await call(
      "POST",
      "/auth/bind-wechat",
      { openid: "forged", refreshToken: active.refreshToken },
      active,
    );
    assert.equal(malformed.status, 400);
    const invalidApple = await call(
      "POST",
      "/auth/bind-apple",
      {
        identityToken: identityToken("test", "wrong.app"),
        authorizationCode: "x",
        refreshToken: active.refreshToken,
      },
      active,
    );
    assert.equal(invalidApple.status, 401);
    const wrongSession = await call(
      "POST",
      "/auth/bind-wechat",
      { ...credentials("wechat", "bad"), refreshToken: b.refreshToken },
      active,
    );
    assert.equal(wrongSession.status, 401);
    const used = credentials("wechat", "conflict-b");
    assert.equal((await call("POST", "/auth/login-wechat", used)).status, 200);
    assert.equal((await call("POST", "/auth/login-wechat", used)).status, 401);
    report.invalidEvidence = {
      clientOpenID: 400,
      wrongAppleAudience: 401,
      otherAccountRefresh: 401,
      replayedWeChatCode: 401,
    };
    await User.updateOne({ _id: active.user.id }, { $set: { deletionPending: true } });
    assert.equal((await bind(active, "wechat", "blocked")).status, 401);
    assert.equal((await call("POST", "/auth/login-apple", credentials("apple", "conflict-a"))).status, 401);
    report.deletionPendingBlocked = true;
    const legacy = await User.create({
      provider: "apple",
      appleUserId: "legacy-first",
      displayName: "旧用户",
    });
    const oldClient = await call("POST", "/auth/login-apple", {
      identityToken: identityToken("legacy-first"), age14Confirmed: undefined,
    });
    assert.equal(oldClient.status, 403);
    const upgraded = await login("apple", "legacy-first");
    assert.equal(upgraded.user.id, legacy.id);
    await seed(upgraded, "原账号记录");
    const oldData = await records(upgraded);
    assert.equal((await bind(upgraded, "wechat", "legacy-linked")).status, 200);
    const fromWeChat = await login("wechat", "legacy-linked");
    assert.equal(fromWeChat.user.id, legacy.id);
    assert.deepEqual(await records(fromWeChat), oldData);
    report.legacyAppleAccountPreservedAfterAgeConfirmation = true;

    const delayed = bind(fromWeChat, "wechat", "delayed-exchange");
    await started;
    assert.equal((await call("DELETE", "/auth/logout", undefined, fromWeChat)).status, 200);
    resumeExchange();
    assert.equal((await delayed).status, 401);
    assert.equal(
      await User.countDocuments({ wechatIdentity: process.env.WECHAT_APP_ID + ":delayed-exchange" }),
      0,
    );
    report.logoutDuringExchangeBlocked = true;

    const wxOwner = await login("wechat", "wechat-first");
    const removed = await call("DELETE", "/user/account", undefined, wxOwner);
    assert.equal(removed.status, 200);
    assert.equal(removed.body.appleRevocation, "revoked");
    assert.deepEqual(revoked, ["apple-private-fixture-wechat-first"]);
    for (const provider of ["apple", "wechat"]) {
      const gone = await call("POST", "/auth/login-" + provider, {
        ...credentials(provider, "wechat-first"),
        createIfMissing: false,
      });
      assert.equal(gone.body.code, "IDENTITY_NOT_REGISTERED");
    }
    assert.equal(await Training.countDocuments({ userId: wxOwner.user.id }), 0);
    assert.equal(await CustomFormation.countDocuments({ userId: wxOwner.user.id }), 0);
    report.wechatOriginDeletionRevokedLinkedAppleAndClearedBothIdentities = true;
    console.log(JSON.stringify(report, null, 2));
  } finally {
    global.fetch = realFetch;
    if (server) {
      server.closeAllConnections();
      await new Promise((resolve) => server.close(resolve));
    }
    await backend("./src/services/deletionLedger").closeLedger();
    await mongoose.disconnect();
    if (mongo) await mongo.stop();
    await fs.rm(tmp, { recursive: true, force: true });
  }
}
run().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
