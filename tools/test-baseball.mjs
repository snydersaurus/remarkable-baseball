#!/usr/bin/env node
// Exercises ui/Baseball.mjs outside Qt: `node tools/test-baseball.mjs`.
// Hand-built situations for the runner rules, then thousands of whole games
// with random choices, checking every invariant after every pitch.
import assert from "node:assert"
import * as B from "../ui/Baseball.mjs"

// ------------------------------------------------------------ runner rules

function adv(bases, kind, outsAfter = 1) {
    const b = bases.slice()
    const runs = B.advance(b, kind, outsAfter)
    return [b, runs]
}
const E = [false, false, false], F = [true, false, false], S = [false, true, false],
    T = [false, false, true], FS = [true, true, false], FT = [true, false, true],
    ST = [false, true, true], L = [true, true, true]

assert.deepStrictEqual(adv(E, "walk"), [F, 0])
assert.deepStrictEqual(adv(S, "walk"), [FS, 0], "walk does not push an unforced runner")
assert.deepStrictEqual(adv(T, "walk"), [FT, 0])
assert.deepStrictEqual(adv(FT, "walk"), [L, 0])
assert.deepStrictEqual(adv(L, "walk"), [L, 1], "bases-loaded walk forces a run")
assert.deepStrictEqual(adv(L, "single"), [L, 1])
assert.deepStrictEqual(adv(FS, "double"), [ST, 1], "runner from second scores on a double")
assert.deepStrictEqual(adv(L, "double"), [ST, 2])
assert.deepStrictEqual(adv(L, "triple"), [T, 3])
assert.deepStrictEqual(adv(L, "homer"), [E, 4])
assert.deepStrictEqual(adv(E, "homer"), [E, 1])
assert.deepStrictEqual(adv(ST, "groundout", 1), [T, 1], "productive out")
assert.deepStrictEqual(adv(ST, "groundout", 3), [ST, 0], "no run scores on the third out")
assert.deepStrictEqual(adv(T, "flyout", 2), [E, 1], "sacrifice fly")
assert.deepStrictEqual(adv(T, "flyout", 3), [T, 0], "no sac fly on the third out")
assert.deepStrictEqual(adv(FS, "flyout", 1), [FS, 0], "others hold on a fly")
console.log("runner rules ok")

// ------------------------------------------------------------ seeding

function playRandom(seed, innings, chooser) {
    const s = B.newGame({ seed, userTeam: seed % 2, innings })
    const r = { rng: (seed * 7919) >>> 0 }
    const events = []
    let guard = 0
    while (s.phase !== "final") {
        assert.ok(++guard < 20000, "game never ends")
        if (s.phase === "switch") {
            B.nextHalf(s)
        } else {
            const before = B.clone(s)
            const e = B.userBatting(s)
                ? B.pitchOnce(s, null, null, chooser.action(r, s))
                : B.pitchOnce(s, chooser.pitch(r), chooser.loc(r), null)
            events.push(e)
            check(before, s, e)
        }
        assert.deepStrictEqual(B.problems(s), [], "seed " + seed)
    }
    return { s, events }
}

const randomChooser = {
    action: (r) => B.ACTIONS[Math.floor(B.rand(r) * 3)],
    pitch: (r) => B.PITCHES[Math.floor(B.rand(r) * 3)].id,
    loc: (r) => B.LOCATIONS[Math.floor(B.rand(r) * 3)].id
}

// What one pitch is allowed to do to the state.
function check(before, s, e) {
    assert.ok(e.headline && e.text, "every pitch is described")
    const runs = s.score[e.team] - before.score[e.team]
    assert.strictEqual(runs, e.runs, "score moves by the event's runs")
    assert.strictEqual(s.score[1 - e.team], before.score[1 - e.team], "the fielding side never scores")
    const outs = (s.phase === "play" ? s.outs : 3) - before.outs
    if (s.phase === "final" && s.outs < 3) {
        // A walk-off: the half ends with fewer than three outs.
        assert.ok(e.team === 1 && s.score[1] > s.score[0])
    } else {
        assert.strictEqual(outs, e.outs, "outs move by the event's outs: " + e.text)
    }
    const countReset = s.balls === 0 && s.strikes === 0
    if (e.kind === "ball" && !e.walk) assert.strictEqual(s.balls, before.balls + 1)
    if ((e.kind === "called" || e.kind === "whiff") && !e.strikeout) assert.strictEqual(s.strikes, before.strikes + 1)
    if (e.walk || e.strikeout || ["single", "double", "triple", "homer", "groundout", "flyout"].includes(e.kind))
        assert.ok(countReset, "the at-bat ends: " + e.text)
    if (e.kind === "homer") assert.deepStrictEqual(s.bases, [false, false, false])
}

{
    const a = playRandom(12345, 3, randomChooser)
    const b = playRandom(12345, 3, randomChooser)
    assert.deepStrictEqual(a.s, b.s, "the same seed replays the same game")
    const c = playRandom(54321, 3, randomChooser)
    assert.notDeepStrictEqual(a.events.map(e => e.text), c.events.map(e => e.text))
}
console.log("seeding ok")

// ------------------------------------------------------------ game flow

{
    // The home side leads after the top of the last inning: no bottom half.
    const s = B.newGame({ seed: 1, innings: 1 })
    s.score = [0, 2]; s.line = [[0], [2]]; s.half = 0; s.inning = 2; s.innings = 2
    s.line = [[0, 0], [2]]
    s.outs = 2; s.strikes = 2
    for (let i = 0; i < 200 && s.phase === "play"; i++) {
        B.pitchOnce(s, "fast", "mid", "take")
        if (s.phase === "play") { s.strikes = 2; s.balls = 0 }
    }
    assert.strictEqual(s.phase, "final", "three outs with home ahead ends it")
    assert.match(s.summary, /already ahead/)
}
{
    // Walk-off: bases loaded in the bottom of the last, tied, ball four.
    const s = B.newGame({ seed: 2, innings: 1 })
    s.half = 1; s.line = [[3], [3]]; s.score = [3, 3]; s.bases = [true, true, true]; s.balls = 3
    for (let i = 0; i < 200 && s.phase === "play"; i++) {
        B.pitchOnce(s, "curve", "out", "take")
        if (s.phase === "play") { s.balls = 3; s.strikes = 0; s.bases = [true, true, true]; s.outs = 0 }
    }
    assert.strictEqual(s.phase, "final")
    assert.deepStrictEqual(s.score, [3, 4])
    assert.match(s.summary, /Walk-off/)
    assert.strictEqual(B.userResult(s), 0 === s.userTeam ? -1 : 1)
}
{
    // A tie after the bottom of the last goes to extras, then to a called tie.
    const s = B.newGame({ seed: 3, innings: 1, maxInnings: 2 })
    const strikeOutSide = () => {
        while (s.phase === "play") { s.strikes = 2; B.pitchOnce(s, "fast", "mid", "take") }
    }
    // Two strikes and a taken middle fastball: a called strike three almost
    // every time, and the loop covers the rest.
    strikeOutSide(); assert.strictEqual(s.phase, "switch"); B.nextHalf(s)
    strikeOutSide()
    assert.strictEqual(s.phase, "switch", "tie after one goes to extras")
    assert.match(s.summary, /extra innings/)
    B.nextHalf(s)
    assert.strictEqual(s.inning, 2)
    strikeOutSide(); B.nextHalf(s); strikeOutSide()
    assert.strictEqual(s.phase, "final")
    assert.match(s.summary, /tie/)
    assert.deepStrictEqual(B.problems(s), [])
}
{
    // Two-strike foul bunt is strike three; two-strike foul swing is not.
    let sawBuntK = false, sawFoulStay = false
    for (let seed = 0; seed < 4000 && !(sawBuntK && sawFoulStay); seed++) {
        const s = B.newGame({ seed, userTeam: 0 })
        s.strikes = 2
        const action = seed % 2 ? "bunt" : "swing"
        const e = B.pitchOnce(s, "fast", "mid", action)
        if (e.kind === "foul" && action === "bunt") { assert.ok(e.strikeout); assert.strictEqual(s.outs, 1); sawBuntK = true }
        if (e.kind === "foul" && action === "swing") { assert.ok(!e.strikeout); assert.strictEqual(s.strikes, 2); sawFoulStay = true }
    }
    assert.ok(sawBuntK && sawFoulStay)
}
console.log("game flow ok")

// ------------------------------------------------------------ many games

const smartChooser = {
    // A rough human: takes on 3-0, protects with two strikes, otherwise swings.
    action: (r, s) => s.balls === 3 && s.strikes < 2 ? "take"
        : B.rand(r) < 0.1 ? "bunt" : B.rand(r) < 0.7 ? "swing" : "take",
    pitch: randomChooser.pitch,
    loc: randomChooser.loc
}
const tally = {}
let halves = 0, runs = 0, games = 0, pitches = 0, ties = 0, extra = 0
for (let seed = 1; seed <= 4000; seed++) {
    const { s, events } = playRandom(seed, 1 + (seed % 3 === 0 ? 2 : 0), seed % 2 ? smartChooser : randomChooser)
    games++
    halves += s.line[0].length + s.line[1].length
    runs += s.score[0] + s.score[1]
    pitches += events.length
    if (s.score[0] === s.score[1]) ties++
    if (s.inning > s.innings) extra++
    for (const e of events) {
        const k = e.strikeout ? "strikeout" : e.walk ? "walk" : e.headline
        tally[k] = (tally[k] || 0) + 1
    }
}
console.log(`${games} games ok: ${(runs / halves).toFixed(2)} runs per half, `
    + `${(pitches / games).toFixed(0)} pitches per game, ${ties} ties, ${extra} went to extras`)
console.log(Object.entries(tally).sort((a, b) => b[1] - a[1]).map(([k, v]) => `${k} ${v}`).join(", "))
