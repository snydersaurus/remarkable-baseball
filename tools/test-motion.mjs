import assert from 'node:assert/strict'
import * as B from '../ui/Baseball.mjs'
import * as M from '../ui/Motion.mjs'
let hits=0,balls=0
for(let seed=1;seed<=500;seed++) {
    const before=B.newGame({seed,userTeam:0,innings:1})
    before.bases=[true,true,true]
    const pending=JSON.parse(JSON.stringify(before))
    const delivery=B.preparePitch(pending,null,null)
    const copy=JSON.stringify(pending)
    // A prepared pitch must not reroll its location during resolution.
    const taken=JSON.parse(copy)
    const take=B.pitchOnce(taken,null,null,'take',delivery)
    assert.equal(take.kind,delivery.where.inZone?'called':'ball')
    assert.equal(take.x,delivery.where.x)
    assert.equal(take.y,delivery.where.y)
    if(!delivery.where.inZone)balls++
    for(const timing of ['hit','miss']) {
        const after=JSON.parse(copy)
        const e=B.pitchOnce(after,null,null,'swing',delivery,timing)
        if(timing==='miss'||!delivery.where.inZone)assert.equal(e.kind,'whiff')
        else {assert.ok(['single','double','triple','homer','groundout','flyout'].includes(e.kind));hits++}
        assert.deepEqual(B.problems(after),[])
        const frames=M.resultFrames(before,after)
        assert.ok(frames.length>0&&frames.length<40)
        for(const f of frames)for(const r of f.runners) {
            assert.ok(r.from>=0&&r.to<=4&&r.t>=0&&r.t<=1)
        }
        assert.equal(before.pitches,0)
    }
}
assert.ok(hits>0&&balls>0)
for(const f of M.deliveryFrames(B.newGame({seed:1,userTeam:0,innings:1})))
    assert.equal(M.swingTiming(f),f.ball&&f.ball.t>=0.6?'hit':'miss')
assert.equal(M.swingTiming(null),'miss')
// Forced walks, stationary runners, tag-up, third-out suppression and homers.
const state={bases:[true,false,true],outs:0}
assert.deepEqual(M.runnerMoves(state,{}, {kind:'ball',walk:true,outs:0}),[
    {from:1,to:2},{from:3,to:3},{from:0,to:1}])
assert.deepEqual(M.runnerMoves({...state,outs:2},{}, {kind:'flyout',outs:1}),[
    {from:1,to:1},{from:3,to:3}])
assert.deepEqual(M.runnerMoves(state,{}, {kind:'homer',outs:0}),[
    {from:1,to:4},{from:3,to:4},{from:0,to:4}])
console.log('500 prepared pitches: timing, called pitches, contact, immutable visible state and runner plans passed')
