const assert = require("node:assert/strict");
const fs = require("node:fs/promises");
const path = require("node:path");
const test = require("node:test");
const { createApp } = require("../src/app");
const {
  renderLegalDocument,
  validateLegalConfiguration,
} = require("../src/services/legalDocuments");

const validLegal = {
  legalDocumentsPublished: true,
  legalOperatorName: "测试运营主体 & Co.",
  legalContactEmail: "privacy@example.test",
  legalEffectiveDate: "2026-09-03",
  legalInfrastructureProvider: "测试云服务商",
  legalDataRegion: "中国大陆测试区域",
  legalBackupRetentionDays: "30",
};

const publicDir = path.join(__dirname, "..", "public");

test("legal documents remain unavailable until publishing is explicitly enabled", () => {
  assert.match(validateLegalConfiguration({ published: false }), /尚未启用/);
});

test("publishing fails closed when a production fact is missing", () => {
  assert.match(
    validateLegalConfiguration({ published: true, operatorName: "测试" }),
    /缺少生产配置/
  );
});

test("configured privacy and terms pages are bilingual and contain no template tokens", async () => {
  const legal = {
    published: validLegal.legalDocumentsPublished,
    operatorName: validLegal.legalOperatorName,
    contactEmail: validLegal.legalContactEmail,
    effectiveDate: validLegal.legalEffectiveDate,
    infrastructureProvider: validLegal.legalInfrastructureProvider,
    dataRegion: validLegal.legalDataRegion,
    backupRetentionDays: validLegal.legalBackupRetentionDays,
  };
  for (const kind of ["privacy", "terms"]) {
    const body = await renderLegalDocument(kind, publicDir, legal);
    assert.match(body, /测试运营主体 &amp; Co\./);
    assert.match(body, /中文/);
    assert.match(body, /English/);
    assert.doesNotMatch(body, /\{\{[A-Z_]+\}\}/);
  }
  assert.match(await fs.readFile(path.join(publicDir, "legal.css"), "utf8"), /color-scheme/);
  assert.equal(typeof createApp(validLegal), "function");
});
