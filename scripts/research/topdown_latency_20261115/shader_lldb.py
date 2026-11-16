"""External debugger capture of actual Metal requests; never a latency benchmark."""
import hashlib
import json
from pathlib import Path
import time
import traceback
import struct
import lldb

state = {}

def emit(kind, **fields):
    with (state['out'] / 'requests.jsonl').open('a') as stream:
        stream.write(json.dumps({'event': kind, 'wall': time.time(), **fields}) + '\n')

def marker():
    root = Path(state['markers'])
    for path in root.glob('*/render-state.bin'):
        raw = path.read_bytes()
        if len(raw) != 56:
            continue
        seq, activation, phase, wall, uptime, pid, seq2 = struct.unpack('<QQQddQQ', raw)
        if seq == seq2 and pid == state['pid'] and wall >= state['started']:
            return {'session':path.parent.name,'activation':activation,'phase':phase,'wall':wall}
    return None

def expression(frame, code):
    options = lldb.SBExpressionOptions()
    options.SetLanguage(lldb.eLanguageTypeObjC_plus_plus)
    options.SetIgnoreBreakpoints(True)
    options.SetTimeoutInMicroSeconds(2_000_000)
    value = frame.EvaluateExpression(code, options)
    if value.GetError().Fail():
        raise RuntimeError(str(value.GetError()) + ': ' + code[:180])
    return value.GetValueAsUnsigned()

def string(frame, object_expression):
    address = expression(frame, '(const char *)[(' + object_expression + ') UTF8String]')
    if not address:
        return None
    error = lldb.SBError()
    value = frame.GetThread().GetProcess().ReadCStringFromMemory(address, 2_000_000, error)
    if error.Fail():
        raise RuntimeError(str(error))
    return value

def trace(frame):
    return [f.GetFunctionName() or str(f.GetPCAddress()) for f in frame.GetThread()][:24]

def library(frame, bp_loc, internal_dict):
    try:
        entry = time.time()
        current_marker = marker()
        thread = frame.GetThread().GetThreadID()
        source_pointer = frame.FindRegister('x2').GetValueAsUnsigned()
        options_pointer = frame.FindRegister('x3').GetValueAsUnsigned()
        source = string(frame, '(id)0x%x' % source_pointer)
        if not source:
            raise RuntimeError('Empty source at Metal library entry')
        digest = hashlib.sha256(source.encode()).hexdigest()
        (state['out'] / (digest + '.metal')).write_text(source)
        options_description = string(frame, '[(id)0x%x description]' % options_pointer) if options_pointer else None
        macros = string(frame, '[[(id)0x%x preprocessorMacros] description]' % options_pointer) if options_pointer else None
        state['libraries'] += 1
        state['last_source'][thread] = digest
        emit('library', thread=thread, sourceSHA256=digest, sourceBytes=len(source.encode()),
             options=options_description, macros=macros, stack=trace(frame), entryWall=entry, marker=current_marker)
        if state['libraries'] >= state['max_libraries']:
            state['limit'] = True
            return True
    except Exception:
        emit('capture_error', detail=traceback.format_exc())
        state['failed'] = True
        return True
    return False

def pipeline(frame, bp_loc, internal_dict):
    try:
        ptr = frame.FindRegister('x2').GetValueAsUnsigned()
        desc = string(frame, '[(id)0x%x description]' % ptr)
        emit('pipeline', thread=frame.GetThread().GetThreadID(), descriptor=desc, stack=trace(frame))
    except Exception:
        emit('capture_error', detail=traceback.format_exc())
        state['failed'] = True
        return True
    return False

def compiler(frame, bp_loc, internal_dict):
    tid=frame.GetThread().GetThreadID()
    emit('compiler_request', thread=tid, lastSourceOnThread=state['last_source'].get(tid),
         marker=marker(),stack=trace(frame))
    return False

def library_hash(frame, bp_loc, internal_dict):
    # Candidate argument storage is validated against actual cache bytes offline;
    # do not assume C++ hidden-argument placement merely from the symbol name.
    process=frame.GetThread().GetProcess()
    memory={}
    for name in ['x0','x1','x2','x3','x4']:
        address=frame.FindRegister(name).GetValueAsUnsigned()
        error=lldb.SBError()
        data=process.ReadMemory(address,32,error) if address else b''
        memory[name]={'address':hex(address),'bytes':data.hex() if error.Success() else None,'error':str(error)}
    tid=frame.GetThread().GetThreadID()
    emit('library_hash_candidates',thread=tid,lastSourceOnThread=state['last_source'].get(tid),
         registers=memory,marker=marker(),stack=trace(frame))
    return False

def light_copy_return(frame, bp_loc, internal_dict):
    key=(frame.GetThread().GetThreadID(),bp_loc.GetBreakpoint().GetID())
    previous=state['pending_copies'].pop(key,None)
    frame.GetThread().GetProcess().GetTarget().BreakpointDelete(bp_loc.GetBreakpoint().GetID())
    address=frame.FindRegister('x0').GetValueAsUnsigned()
    try:
        ref=expression(frame,'(void *)[(id)0x%x lightRef]'%address)
        state['copied_refs'][ref]=previous
        emit('light_copy_return',source=previous,copyAddress=hex(address),lightRef=hex(ref))
    except Exception:
        emit('capture_error',detail=traceback.format_exc());state['failed']=True;return True
    return False

def memory(frame, address, count):
    error=lldb.SBError()
    result=frame.GetThread().GetProcess().ReadMemory(address,count,error)
    if error.Fail() or len(result)!=count:raise RuntimeError(str(error))
    return result

def global_lights(frame, bp_loc, internal_dict):
    # Layout is derived from this exact simulator framework's disassembly and
    # guarded by its Mach-O UUID below; not a portable SceneKit API assumption.
    try:
        system=frame.FindRegister('x0').GetValueAsUnsigned()
        raw=memory(frame,system,0x240)
        count=struct.unpack_from('<I',raw,0x238)[0]
        if count>8:raise RuntimeError('Unexpected global light count')
        rows=[]
        for i in range(count):
            ident=struct.unpack_from('<I',raw,0x1f8+i*4)[0]
            kind,index=ident>>28,(ident&0x0fffffff)-1
            if kind>7 or index<0 or index>255:raise RuntimeError('Unexpected light index')
            nodes=struct.unpack_from('<Q',raw,0x88+kind*8)[0]
            refs=struct.unpack_from('<Q',raw,0xc8+kind*8)[0]
            node=struct.unpack('<Q',memory(frame,nodes+index*8,8))[0]
            ref=struct.unpack('<Q',memory(frame,refs+index*8,8))[0]
            rows.append({'id':ident,'node':hex(node),'lightRef':hex(ref),
                         'lightTypeRaw':struct.unpack('<I',memory(frame,ref+0x50,4))[0],
                         'programHash':struct.unpack_from('<I',raw,0x218+i*4)[0]})
        key=(system,tuple((r['node'],r['lightRef'],r['programHash']) for r in rows))
        if key not in state['seen_globals']:
            state['seen_globals'].add(key)
            visits=[v for v in state['visits'] if v['system']==system][-5:]
            replay=None
            if count==4 and system in state['overlay_systems'] and len(visits)==5:
                # Separate temporary CF dictionaries: never mutate the renderer's
                # dictionary. Test the same raw node keys in opposite insertion order.
                n=len(visits)
                code=['({ void **buf=(void **)malloc(%d);'% (n*16)]
                for order,items in enumerate([visits,list(reversed(visits))]):
                    code.append('void *d%d=((void *(*)(void*,long,void*,void*))CFDictionaryCreateMutable)(0,0,0,0);'%order)
                    for v in items:
                        code.append('((void (*)(void*,const void*,const void*))CFDictionarySetValue)(d%d,(void*)0x%x,(void*)0x%x);'%(order,v['node'],v['index']))
                    code.append('((void (*)(const void*,const void**,const void**))CFDictionaryGetKeysAndValues)(d%d,(const void**)(buf+%d),0);'%(order,order*n))
                    code.append('((void (*)(const void*))CFRelease)(d%d);'%order)
                code.append('buf; })')
                pointer=expression(frame,''.join(code))
                try:
                    values=struct.unpack('<'+'Q'*(n*2),memory(frame,pointer,n*16))
                    replay={'input':[hex(v['node']) for v in visits],
                            'forward':[hex(v) for v in values[:n]],'reverse':[hex(v) for v in values[n:]]}
                finally:expression(frame,'(unsigned long long)(((void (*)(void*))free)((void*)0x%x),0)'%pointer)
            emit('global_light_list',system=hex(system),scene=hex(struct.unpack_from('<Q',raw,0x10)[0]),
                 dictionary=hex(struct.unpack_from('<Q',raw,0x20)[0]),rows=rows,
                 dictionaryReplay=replay,marker=marker(),thread=frame.GetThread().GetThreadID(),stack=trace(frame))
    except Exception:
        emit('capture_error',detail=traceback.format_exc());state['failed']=True;return True
    return False

def append_global(frame, bp_loc, internal_dict):
    if not state['light_copy_count']:return False
    state['visits'].append({'node':frame.FindRegister('x0').GetValueAsUnsigned(),
                            'index':frame.FindRegister('x1').GetValueAsUnsigned(),
                            'system':frame.FindRegister('x2').GetValueAsUnsigned()})
    emit('dictionary_light_visit',node=hex(frame.FindRegister('x0').GetValueAsUnsigned()),
         encodedIndex=frame.FindRegister('x1').GetValueAsUnsigned(),
         system=hex(frame.FindRegister('x2').GetValueAsUnsigned()),
         thread=frame.GetThread().GetThreadID(),stack=trace(frame))
    return False

def light_add(frame, bp_loc, internal_dict):
    stack=trace(frame)
    if not any('makeTemporaryTopDownRenderScene' in name for name in stack):return False
    try:
        system=frame.FindRegister('x0').GetValueAsUnsigned()
        node=frame.FindRegister('x1').GetValueAsUnsigned()
        ref=expression(frame,'((void *(*)(void*))C3DNodeGetLight)((void*)0x%x)'%node)
        raw_type=struct.unpack('<I',memory(frame,ref+0x50,4))[0]
        state['overlay_systems'].add(system)
        emit('light_add',system=hex(system),node=hex(node),lightRef=hex(ref),lightTypeRaw=raw_type,stack=stack)
    except Exception:
        emit('capture_error',detail=traceback.format_exc());state['failed']=True;return True
    return False

def light_copy(frame, bp_loc, internal_dict):
    try:
        thread=frame.GetThread()
        address=frame.FindRegister('x0').GetValueAsUnsigned()
        if not any('makeTemporaryTopDownRenderScene' in name for name in trace(frame)):
            return False
        source={'address':hex(address),'type':string(frame,'[(id)0x%x type]'%address)}
        state['light_copy_count']+=1
        emit('light_copy',source=source,thread=thread.GetThreadID(),marker=marker(),stack=trace(frame))
        # Return-address callbacks plus expression evaluation were observed to
        # misassociate a late return with the next copy. Internal node identity
        # is now captured at actual C3DLightingSystemAdd instead.
    except Exception:
        emit('capture_error',detail=traceback.format_exc());state['failed']=True;return True
    return False

def capture(debugger, config_path):
    config = json.loads(Path(config_path).read_text())
    state.update(out=Path(config['output']), libraries=0, max_libraries=config['maxLibraries'],
                 failed=False, limit=False, pid=config['pid'], started=time.time(),
                 markers=config['markers'],last_source={},light_sources={},pending_copies={},
                 copied_refs={},seen_globals=set(),visits=[],light_copy_count=0,overlay_systems=set())
    state['out'].mkdir(exist_ok=True)
    debugger.SetAsync(True)
    target = debugger.CreateTarget(config['executable'])
    error = lldb.SBError()
    process = target.AttachToProcessWithID(debugger.GetListener(), config['pid'], error)
    if error.Fail():
        emit('attach_error', detail=str(error))
        return
    # XCTest terminates its App normally; do not turn SIGTERM into an indefinite debug stop.
    process.GetUnixSignals().SetShouldStop(15, False)
    process.GetUnixSignals().SetShouldNotify(15, False)
    breakpoints = []
    try:
        module=next(m for m in target.modules if m.GetFileSpec().GetFilename()=='SceneKit')
        uuid=module.GetUUIDString()
        emit('scenekit_identity',uuid=uuid,path=str(module.GetFileSpec()))
        if uuid!='745BE90A-D181-3FAE-AA9C-63ACA13CF1AD':raise RuntimeError('Unverified SceneKit layout')
        specs = [('library', '-[_MTLDevice newLibraryWithSource:options:compilerTask:error:]'),
                 ('pipeline', '-[SCNMTLResourceManager(Compilation) _createPipelineStateWithDescriptor:desc:pipeline:]')]
        for callback, name in specs:
            bp = target.BreakpointCreateByName(name)
            bp.SetScriptCallbackFunction(__name__ + '.' + callback)
            breakpoints.append(bp)
            emit('breakpoint', name=name, locations=bp.GetNumLocations())
        bp = target.BreakpointCreateByRegex('MTLCompilerScheduler::buildRequest')
        bp.SetScriptCallbackFunction(__name__ + '.compiler')
        breakpoints.append(bp)
        emit('breakpoint', name='MTLCompilerScheduler::buildRequest', locations=bp.GetNumLocations())
        bp = target.BreakpointCreateByRegex('MTLLibraryBuilder::newLibraryWithRequestDataAndHash')
        bp.SetScriptCallbackFunction(__name__ + '.library_hash')
        breakpoints.append(bp)
        emit('breakpoint',name='MTLLibraryBuilder::newLibraryWithRequestDataAndHash',locations=bp.GetNumLocations())
        bp=target.BreakpointCreateByName('-[SCNLight copyWithZone:]')
        bp.SetScriptCallbackFunction(__name__+'.light_copy');breakpoints.append(bp)
        emit('breakpoint',name='-[SCNLight copyWithZone:]',locations=bp.GetNumLocations())
        for name,callback in [('C3DLightingSystemGetGlobalLightHashCodeForCaching','global_lights'),
                              ('__appendGlobalLight','append_global'),('C3DLightingSystemAdd','light_add')]:
            bp=target.BreakpointCreateByName(name)
            bp.SetScriptCallbackFunction(__name__+'.'+callback);breakpoints.append(bp)
            emit('breakpoint',name=name,locations=bp.GetNumLocations())
            if bp.GetNumLocations()!=1:raise RuntimeError('Missing unique light breakpoint: '+name)
        emit('attached', pid=config['pid'])
        process.Continue()
        deadline = time.time() + config['timeoutSeconds']
        while time.time() < deadline and not state['failed'] and not state['limit']:
            if process.GetState() in (lldb.eStateExited, lldb.eStateDetached, lldb.eStateCrashed):
                break
            time.sleep(.1)
        emit('finished', processState=process.GetState(), libraryCount=state['libraries'],
             failed=state['failed'], limit=state['limit'])
    finally:
        if process.GetState() not in (lldb.eStateExited, lldb.eStateDetached):
            process.Stop()
            for bp in breakpoints:
                target.BreakpointDelete(bp.GetID())
            error = process.Detach()
            emit('detached', error=str(error))
