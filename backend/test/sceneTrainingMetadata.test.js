const test = require('node:test');
const assert = require('node:assert/strict');
const AngleTest = require('../src/models/AngleTest');

test('scene training metadata survives strict schema serialization; legacy remains unknown', () => {
  const base = {clientId:'test',userId:'507f1f77bcf86cd799439011',date:new Date(),actualAngle:0,userAngle:0,pocketType:'corner',quizType:'aimPoint2D'};
  const metadata = JSON.stringify({rulesVersion:2,scoringVersion:'transverse-v2',firstAttempt:true,assistance:['angleHint'],score:{status:'backwards'}});
  const result = new AngleTest({...base,trainingMetadataJSON:metadata});
  assert.equal(result.validateSync(), undefined);
  assert.equal(result.toObject().trainingMetadataJSON,metadata);
  assert.equal(new AngleTest(base).toObject().trainingMetadataJSON,undefined);
});
