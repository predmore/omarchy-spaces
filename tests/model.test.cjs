const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const model = {};
vm.createContext(model);
vm.runInContext(fs.readFileSync(path.join(__dirname, '../Model.js'), 'utf8').replace('.pragma library', ''), model);
const plain = value => JSON.parse(JSON.stringify(value));

test('configuration has bounded typed defaults and survives malformed files', () => {
  assert.deepEqual(plain(model.settings('')), {workspaceCount:10, workspaceBase:null, swipeDistance:260, captureLimit:16, previewInterval:100, backgroundInterval:1100, gesturesEnabled:true});
  for (const input of ['null', '[]', '{', '"value"']) assert.equal(model.settings(input).workspaceCount, 10);
  const config = model.settings(JSON.stringify({workspaceCount:500, swipeDistance:-1, captureLimit:Infinity, previewInterval:'fast', gesturesEnabled:false, workspaceBase:40}));
  assert.equal(config.workspaceCount, 20); assert.equal(config.swipeDistance,80);
  assert.equal(config.captureLimit,16); assert.equal(config.previewInterval,100); assert.equal(config.workspaceBase,40); assert.equal(config.gesturesEnabled,false);
});

test('workspace discovery follows monitor state and retains empty slots', () => {
  assert.equal(model.baseForMonitor('2\tDISPLAY-B\tDISPLAY-B\n','DISPLAY-B',21),20);
  assert.equal(model.baseForMonitor('','DISPLAY-B',25),20);
  const windows = [{workspace:{id:22,name:'22'}}, {workspace:{id:28,name:'mail'}}];
  const spaces = model.spaces(windows,20,5);
  assert.equal(spaces.length,6); assert.equal(spaces[0].windows.length,0);
  assert.equal(spaces[1].windows.length,1); assert.equal(spaces[5].label,'mail');
});

test('geometry uses logical positions on scaled and offset monitors', () => {
  const result=model.geometry({lastIpcObject:{at:[1600,50],size:[800,500]}},{x:1600,y:0,width:2560,height:1600,scale:1.6});
  assert.equal(result.x,0); assert.equal(result.width,.5); assert.equal(result.height,.5);
});

test('notch detection is optional and specific to the active physical panel', () => {
  const raw=JSON.stringify({panels:[{connector:'INTERNAL',width:2560,height:1664,top:56}]});
  const mode={name:'INTERNAL-1',width:2560,height:1664,scale:1.6,transform:0};
  assert.equal(model.safeTopInset(raw,mode,0),35);
  assert.equal(model.safeTopInset(raw,{...mode,scale:2},0),28);
  assert.equal(model.safeTopInset(raw,{...mode,name:'EXTERNAL-1'},0),0);
  assert.equal(model.safeTopInset(raw,{...mode,transform:1},0),0);
  assert.equal(model.safeTopInset('',mode,0),0);
  assert.equal(model.safeTopInset(raw,{...mode,width:1920,height:1080},0),0);
});

test('swipes settle, cancel and stay at the workspace edges', () => {
  assert.equal(model.swipeTarget(0,.5,-1,-130,false,10),1);
  assert.equal(model.swipeTarget(1,1.4,-1,-104,true,10),1);
  assert.equal(model.swipeTarget(0,0,1,400,false,10),0);
  assert.equal(model.swipeTarget(9,9,-1,-400,false,10),9);
});

test('addresses are validated and markup-shaped titles stay literal', () => {
  assert.equal(model.address('abc'), '0xabc'); assert.equal(model.address('0xabc;command'), '');
  assert.equal(model.text('<img src="https://example.invalid/remote">'), '<img src="https://example.invalid/remote">');
});

test('app cues are deduplicated by desktop application identifier', () => {
  const apps=model.apps([{wayland:{appId:'org.example.Mail'}},{wayland:{appId:'org.example.Mail'}},{lastIpcObject:{class:'terminal'}}]);
  assert.equal(apps.length,2); assert.equal(apps[0].name,'Mail');
});
