"""Project physically verified trajectory parameters into the enabled spin settings."""
def required_axes(n):
    return int(n['spinY']!=0) + 2*int(n['spinX']!=0)


def rewrite(layout,rows,efforts,settings,summary,changed):
    original={r['id']:r for r in layout['routes']}
    variants={}
    by_signature={}
    next_id=max(original)+1

    def variant(root_id, proof):
        nonlocal next_id
        n=proof['input']
        signature=(root_id,n['velocity'],n['spinX'],n['spinY'],*proof['dir'])
        if signature not in by_signature:
            by_signature[signature]=next_id
            variants[next_id]=dict(original[root_id],id=next_id,v=n['velocity'],sx=n['spinX'],sy=n['spinY'],dir=proof['dir'])
            next_id+=1
        return by_signature[signature]

    for q in layout['questions']:
        source=q['refs']
        keys=[f"{layout['id']}#{q['id']}/{r}" for r,pocket in source]
        proofs=[rows.pop(key) for key in keys]
        choices=[settings.get('choices',{}).get(key,[]) if p['state']=='searchReview' else [] for key,p in zip(keys,proofs)]
        default_changed=any(p['state']=='adjusted' for p in proofs)
        if not default_changed and not any(choices):
            continue
        local_changes=set()
        changed_orig=set()

        def references(mask):
            sequence=[]
            admitted=[]
            uses_extra=False
            for rank, ((root_id,pocket),key,proof,alternatives) in enumerate(zip(source,keys,proofs,choices)):
                pick=proof if proof['state']=='adjusted' else None
                if mask is not None and alternatives:
                    allowed=[p for p in alternatives if required_axes(p['input']) & ~mask == 0]
                    if allowed:
                        pick=min(allowed,key=lambda p:(p['rms'],p['effort'],required_axes(p['input'])))
                        uses_extra=True
                        summary['byMask'][str(mask)]+=1
                        changed_orig.add(key)
                param=variant(root_id,pick) if pick else root_id
                if pick:local_changes.add(f"{layout['id']}#{q['id']}/{param}")
                ref=[param,pocket]
                sequence.append(ref)
                if proof['state'] not in ('filtered','baselineFailure'):
                    effort=pick['effort'] if pick else proof.get('effort',efforts.get(key,settings.get('originalEfforts',{}).get(key)))
                    if effort is None:raise ValueError('Missing measured effort '+key)
                    admitted.append((rank,effort,ref))
            ordered=sorted(admitted,key=lambda item:item[1])
            for (slot,_,_),(_,_,ref) in zip(admitted,ordered):
                sequence[slot]=ref
            return sequence,uses_extra

        if default_changed:
            q['trajectoryRefs']=references(None)[0]
        overrides={}
        if any(choices):
            for mask in (1,2,3):
                sequence,uses_extra=references(mask)
                if uses_extra:overrides[str(mask)]=sequence
        if overrides:q['trajectoryRefsByAxes']=overrides
        summary['conditionalOriginals']+=len(changed_orig)
        summary['alwaysAdjusted']+=sum(p['state']=='adjusted' for p in proofs)
        changed.extend(sorted(local_changes))
    layout['routes']=[*original.values(),*variants.values()]
    return bool(variants)
