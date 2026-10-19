// Production account lifecycle for the explicitly authorized two-simulator probe.
const assert=require('node:assert/strict'),fs=require('node:fs'),{randomUUID}=require('node:crypto');
assert.equal(process.env.PRODUCTION_FORMATION_SMOKE,'authorized');
const req=require('node:module').createRequire('/opt/qiuji-backend/package.json');
req('dotenv').config({path:'/opt/qiuji-backend/.env'});
const mongoose=req('mongoose'),User=req('./src/models/User');
const {CustomFormation,FormationChange}=req('./src/models/CustomFormation');
const directory='/root/formation-production-sims-20261019';
const path=directory+'/fixture.json';
(async()=>{
  await mongoose.connect(req('./src/config').mongodbUri);
  try {
    if(process.argv[2]==='create') {
      assert.ok(!fs.existsSync(path),'Do not overwrite an existing probe account');
      fs.mkdirSync(directory,{recursive:true,mode:0o700});
      const probeName='formation-two-sim-probe-'+randomUUID();
      const user=await User.create({provider:'apple',displayName:probeName});
      const f={baseURL:'http://106.54.3.210:3000',userID:String(user._id),
        token:req('./src/utils/jwt').signAccessToken(String(user._id)),probeName,
        templateID:randomUUID(),ballIDs:Array.from({length:25},randomUUID),
        vertexIDs:Array.from({length:3},randomUUID),lineIDs:Array.from({length:2},randomUUID)};
      fs.writeFileSync(path,JSON.stringify(f),{mode:0o600});
      console.log('PASS isolated production account created; private fixture saved');
    } else {
      const f=JSON.parse(fs.readFileSync(path));
      assert.ok(f.probeName.startsWith('formation-two-sim-probe-'));
      const user=await User.findById(f.userID).lean();
      assert.equal(user?.displayName,f.probeName,'Only operate on this probe account');
      if(process.argv[2]==='inspect') {
        const row=await CustomFormation.findOne({userId:f.userID,clientId:f.templateID}).lean();
        const changes=await FormationChange.find({userId:f.userID}).sort({sequence:1}).lean();
        const expected=Number(process.argv[3]);
        assert.equal(row?.revision??0,expected);assert.equal(changes.length,expected);
        assert.equal(row?.deleted??false,expected===4);
        if(row&&!row.deleted){assert.equal(row.template.ballKeys.length,25);assert.equal(Object.keys(row.template.board.onTable).length,26);}
        console.log(JSON.stringify({revision:row?.revision??0,deleted:row?.deleted??false,changes:changes.length,
          records:changes.map(c=>({revision:c.record.revision,deleted:c.record.deleted,name:c.record.template?.name??null}))}));
      } else if(process.argv[2]==='cleanup') {
        const response=await fetch('http://127.0.0.1:3000/user/account',{method:'DELETE',headers:{Authorization:'Bearer '+f.token}});
        assert.equal(response.status,200);
        assert.equal(await User.countDocuments({_id:f.userID}),0);
        assert.equal(await CustomFormation.countDocuments({userId:f.userID}),0);
        assert.equal(await FormationChange.countDocuments({userId:f.userID}),0);
        fs.unlinkSync(path);console.log('PASS production probe account, templates, receipts and credential fixture removed');
      } else throw Error('Unknown action');
    }
  } finally {await mongoose.disconnect();}
})().catch(e=>{console.error('FAIL',e.name,e.codeName||'',e.message?.replace(/mongodb:\/\/\S+/g,'[redacted]'));process.exitCode=1;});
