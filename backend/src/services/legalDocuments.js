const fs = require("fs/promises");
const path = require("path");

const REQUIRED_FIELDS = [
  "operatorName",
  "contactEmail",
  "effectiveDate",
  "infrastructureProvider",
  "dataRegion",
  "backupRetentionDays",
];

function escapeHTML(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

function validateLegalConfiguration(legal) {
  if (!legal.published) return "法律文件尚未启用";
  const missing = REQUIRED_FIELDS.filter((field) => !String(legal[field] ?? "").trim());
  if (missing.length > 0) return `法律文件缺少生产配置：${missing.join(", ")}`;
  if (!/^\S+@\S+\.\S+$/.test(legal.contactEmail)) return "法律联系邮箱格式无效";
  if (!/^\d{4}-\d{2}-\d{2}$/.test(legal.effectiveDate)) return "生效日期必须为 YYYY-MM-DD";
  if (!/^\d+$/.test(String(legal.backupRetentionDays)) || Number(legal.backupRetentionDays) < 0) {
    return "备份保留天数必须为非负整数";
  }
  return null;
}

async function renderLegalDocument(kind, publicDir, legal) {
  const error = validateLegalConfiguration(legal);
  if (error) {
    const unavailable = new Error(error);
    unavailable.status = 503;
    throw unavailable;
  }

  const template = await fs.readFile(path.join(publicDir, kind, "index.html"), "utf8");
  const values = {
    OPERATOR_NAME: legal.operatorName,
    CONTACT_EMAIL: legal.contactEmail,
    EFFECTIVE_DATE: legal.effectiveDate,
    INFRASTRUCTURE_PROVIDER: legal.infrastructureProvider,
    DATA_REGION: legal.dataRegion,
    BACKUP_RETENTION_DAYS: legal.backupRetentionDays,
  };
  return Object.entries(values).reduce(
    (html, [key, value]) => html.replaceAll(`{{${key}}}`, escapeHTML(value)),
    template
  );
}

function createLegalDocumentHandler(kind, publicDir, legal) {
  return async (_req, res, next) => {
    try {
      const html = await renderLegalDocument(kind, publicDir, legal);
      res.set("Cache-Control", "public, max-age=300");
      res.type("html").send(html);
    } catch (error) {
      next(error);
    }
  };
}

module.exports = {
  createLegalDocumentHandler,
  renderLegalDocument,
  validateLegalConfiguration,
};
