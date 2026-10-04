// Baseball rules for Pocket Diamond. An ECMAScript module with no Qt in it, so
// Game.qml imports it and node tests it (tools/test-baseball.mjs).
//
// Everything lives in one plain state object that pitchOnce() and nextHalf()
// change in place. Randomness comes from a small seeded generator whose state
// is part of that object, so a seed replays the same game exactly.
//
// Teams are 0 (visitors, bat in the top half) and 1 (home, bat in the bottom).
// Bases are [first, second, third], true when a runner is on.

export const PITCHES = [
    // control: added to the chance the pitch finds the zone.
    // contact: added to the batter's chance of making contact.
    { id: "fast", name: "Fastball", short: "FAST", control: 0.05, contact: -0.04 },
    { id: "curve", name: "Curveball", short: "CURVE", control: -0.12, contact: -0.10 },
    { id: "change", name: "Change-up", short: "CHANGE", control: 0, contact: -0.06 }
]
// Locations as seen from the catcher with a right-handed batter: inside is on
// the left of the plate, outside on the right.
export const LOCATIONS = [
    { id: "in", name: "inside", short: "INSIDE" },
    { id: "mid", name: "middle", short: "MIDDLE" },
    { id: "out", name: "outside", short: "OUTSIDE" }
]
export const ACTIONS = ["swing", "take", "bunt"]

// Ball-in-play results by how good a pitch the batter hit: weights for
// single, double, triple, homer, groundout, flyout.
const SPRAY = {
    mid: [30, 11, 2, 9, 25, 23],
    edge: [27, 8, 1, 4, 31, 29],
    off: [12, 3, 0, 1, 46, 38]
}
const IN_PLAY = ["single", "double", "triple", "homer", "groundout", "flyout"]

// ------------------------------------------------------------ randomness

// mulberry32: tiny, fast, and good enough for dice. Returns [0, 1).
export function rand(s) {
    s.rng = (s.rng + 0x6D2B79F5) >>> 0
    let t = s.rng
    t = Math.imul(t ^ (t >>> 15), t | 1)
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61)
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296
}

function chance(s, p) {
    return rand(s) < p
}

function weighted(s, weights) {
    let total = 0
    for (const w of weights) total += Math.max(0, w)
    let r = rand(s) * total
    for (let i = 0; i < weights.length; i++) {
        r -= Math.max(0, weights[i])
        if (r < 0) return i
    }
    return weights.length - 1
}

function clamp(x, lo, hi) {
    return Math.max(lo, Math.min(hi, x))
}

export function pitchById(id) {
    return PITCHES.find(p => p.id === id) || PITCHES[0]
}

// ------------------------------------------------------------ the game

// userTeam: 0 to bat first (visitors), 1 to pitch first (home).
// innings: regulation length. A tie goes to extra innings up to maxInnings,
// after which the game is called a tie.
export function newGame(opts = {}) {
    const innings = opts.innings || 1
    return {
        seed: opts.seed >>> 0,
        rng: opts.seed >>> 0,
        userTeam: opts.userTeam === 1 ? 1 : 0,
        innings,
        maxInnings: Math.max(innings, opts.maxInnings || 9),
        inning: 1,
        half: 0,
        balls: 0,
        strikes: 0,
        outs: 0,
        bases: [false, false, false],
        score: [0, 0],
        hits: [0, 0],
        line: [[0], []],        // runs per half inning, per team
        phase: "play",          // "play", "switch" (side retired) or "final"
        last: null,             // the latest pitch event, for the screen
        summary: "",            // what ended the half or the game
        pitches: 0
    }
}

export function clone(s) {
    return JSON.parse(JSON.stringify(s))
}

export function battingTeam(s) {
    return s.half
}

export function userBatting(s) {
    return s.half === s.userTeam
}

export function runnersOn(s) {
    return s.bases.filter(b => b).length
}

// 1 when the user's team won, -1 when it lost, 0 for a tie or a game still on.
export function userResult(s) {
    if (s.phase !== "final") return 0
    const d = s.score[s.userTeam] - s.score[1 - s.userTeam]
    return d > 0 ? 1 : d < 0 ? -1 : 0
}

// ------------------------------------------------------------ the computer

// The computer pitcher: around the plate when behind in the count, nibbling at
// the corners when ahead, and more curveballs with two strikes.
export function cpuPitch(s) {
    const behind = s.balls === 3 || (s.balls >= 2 && s.balls > s.strikes)
    const ahead = s.strikes > s.balls
    const midWeight = behind ? 65 : ahead ? 15 : 45
    const edge = (100 - midWeight) / 2
    const loc = LOCATIONS[weighted(s, [edge, midWeight, edge])].id
    const pitchWeights = behind ? [70, 10, 20] : s.strikes === 2 ? [35, 40, 25] : [50, 25, 25]
    const pitch = PITCHES[weighted(s, pitchWeights)].id
    // Ahead in the count, a corner pitch is meant to be chased, not hit.
    return { pitch, loc, nibble: ahead && loc !== "mid" }
}

// The computer batter sees the pitch coming: it swings more at strikes, more
// with two strikes, rarely at 3-0, and sometimes bunts a runner over.
export function cpuAction(s, inZone, pitch) {
    if (s.outs === 0 && s.strikes < 2 && (s.bases[0] || s.bases[1]) && !s.bases[2]
            && s.score[s.half] <= s.score[1 - s.half] && chance(s, 0.3))
        return "bunt"
    let p = inZone ? 0.68 : 0.24
    if (s.strikes === 2) p += inZone ? 0.25 : 0.14
    if (s.balls === 3 && s.strikes < 2) p -= inZone ? 0.25 : 0.18
    if (!inZone && pitch === "curve") p += 0.1
    return chance(s, clamp(p, 0.02, 0.97)) ? "swing" : "take"
}

// A hint for the user at the plate, from the count alone. It tells the truth
// about how cpuPitch leans.
export function batterHint(s) {
    if (s.balls === 3 && s.strikes < 2) return "Pitcher must throw a strike."
    if (s.balls >= 2 && s.balls > s.strikes) return "Pitcher is behind. Expect one over the plate."
    if (s.strikes === 2 && s.balls < 2) return "Two strikes. He'll work the corners."
    if (s.strikes > s.balls) return "Pitcher is ahead. Watch the edges."
    if (s.bases[0] && s.outs === 0 && !s.bases[2]) return "Runner on, nobody out. A bunt moves him up."
    return "Pick your pitch."
}

// The same, for the user on the mound: how the computer batter will lean.
export function pitcherHint(s) {
    if (s.balls === 3 && s.strikes < 2) return "Three balls. He's taking unless it's a strike."
    if (s.balls >= 2 && s.balls > s.strikes) return "Behind in the count. Don't groove one."
    if (s.strikes === 2) return "Two strikes. He'll chase a curve off the plate."
    if (s.outs === 0 && (s.bases[0] || s.bases[1]) && !s.bases[2]) return "Runner on, nobody out. Watch for the bunt."
    if (s.strikes > s.balls) return "You're ahead. Work the corners."
    return "Middle is easy to hit. Corners can miss."
}

// ------------------------------------------------------------ one pitch

// Where the pitch ended up, as a point in strike-zone units: the zone is
// x 0..3 (inside, middle, outside columns) by y 0..3 (top to bottom).
function locate(s, loc, pitch, nibble) {
    const p = pitchById(pitch)
    const col = loc === "in" ? 0 : loc === "mid" ? 1 : 2
    const findZone = clamp((loc === "mid" ? 0.92 : 0.5) + p.control - (nibble ? 0.25 : 0), 0.05, 0.98)
    const inZone = chance(s, findZone)
    let x, y
    if (inZone) {
        x = col + 0.2 + rand(s) * 0.6
        y = 0.25 + rand(s) * 2.5
    } else if (loc === "mid") {
        // A missed middle pitch sails high, or (a curve) bounces low.
        x = 1.1 + rand(s) * 0.8
        y = pitch === "curve" || chance(s, 0.4) ? 3.25 + rand(s) * 0.4 : -0.25 - rand(s) * 0.4
    } else {
        x = col === 0 ? -0.25 - rand(s) * 0.45 : 3.25 + rand(s) * 0.45
        y = 0.4 + rand(s) * 2.2
    }
    return { inZone, x, y }
}

// Moves the runners for a result and returns how many scored. The batter has
// already been counted out (or not) by the caller.
export function advance(bases, kind, outsAfter) {
    const [b1, b2, b3] = bases
    let runs = 0
    switch (kind) {
    case "walk":
        // Only forced runners move.
        if (b1 && b2 && b3) runs = 1
        bases[2] = b3 || (b1 && b2)
        bases[1] = b2 || b1
        bases[0] = true
        break
    case "single":
        runs = +b3
        bases[2] = b2; bases[1] = b1; bases[0] = true
        break
    case "double":
        runs = +b3 + +b2
        bases[2] = b1; bases[1] = true; bases[0] = false
        break
    case "triple":
        runs = +b1 + +b2 + +b3
        bases[2] = true; bases[1] = false; bases[0] = false
        break
    case "homer":
        runs = +b1 + +b2 + +b3 + 1
        bases[0] = bases[1] = bases[2] = false
        break
    case "groundout":
        // A productive out: everyone moves up a base, unless it was the third out.
        if (outsAfter >= 3) break
        runs = +b3
        bases[2] = b2; bases[1] = b1; bases[0] = false
        break
    case "flyout":
        // A runner on third tags up and scores, unless it was the third out.
        if (outsAfter >= 3 || !b3) break
        runs = 1
        bases[2] = false
        break
    }
    return runs
}

function strikeText(n) {
    return n === 1 ? "strike one" : n === 2 ? "strike two" : "strike three"
}

function ballText(n) {
    return "ball " + ["one", "two", "three", "four"][n - 1]
}

function runsText(runs) {
    return runs === 0 ? "" : runs === 1 ? " A run scores." : " " + runs + " runs score."
}

// Throws one pitch. Whichever half is the user's comes from the arguments:
// when the user is batting, pass action and leave pitch/loc null for the
// computer; when the user is pitching, pass pitch and loc and leave action null.
// Returns the event, which is also kept as s.last.
// Generate the actual visible delivery before the player chooses to swing.
export function preparePitch(s, pitch, loc) {
    let nibble = false
    if (!pitch || !loc) {
        const c = cpuPitch(s)
        pitch = c.pitch
        loc = c.loc
        nibble = c.nibble
    }
    return { pitch, loc, where: locate(s, loc, pitch, nibble) }
}

// timing is only supplied for the human's live swing. Legacy/CPU resolution
// keeps the existing probability model; a correctly timed strike is in play.
export function pitchOnce(s, pitch, loc, action, delivery = null, timing = null) {
    if (s.phase !== "play") throw new Error("pitchOnce outside of play")
    const d = delivery || preparePitch(s, pitch, loc)
    pitch = d.pitch
    loc = d.loc
    const where = d.where
    if (!action) action = cpuAction(s, where.inZone, pitch)

    const team = s.half
    const p = pitchById(pitch)
    const e = {
        team, inning: s.inning, half: s.half, pitch, loc, action,
        inZone: where.inZone, x: where.x, y: where.y,
        kind: "", headline: "", text: "", runs: 0, outs: 0,
        strikeout: false, walk: false, bunt: action === "bunt",
        // Where a ball in play went: 0 is the third-base line, 1 the first.
        spray: 0.5,
        countBefore: [s.balls, s.strikes]
    }
    const zoneWord = where.inZone ? LOCATIONS.find(l => l.id === loc).name
        : where.y > 3 ? "low" : where.y < 0 ? "high" : (loc === "in" ? "inside" : "outside") + ", off the plate"
    const lead = p.name + ", " + zoneWord + ". "
    s.pitches++

    const strike = (kind, verb) => {
        s.strikes++
        e.kind = kind
        if (s.strikes >= 3) {
            e.strikeout = true
            e.headline = "STRIKEOUT"
            e.text = lead + verb + ", strike three."
            batterOut(s, e)
        } else {
            e.headline = kind === "called" ? "STRIKE" : "SWING & MISS"
            e.text = lead + verb + ", " + strikeText(s.strikes) + "."
        }
    }
    const foul = (twoStrikeOut) => {
        e.kind = "foul"
        e.spray = chance(s, 0.5) ? -0.15 : 1.15
        if (s.strikes < 2) {
            s.strikes++
            e.headline = "FOUL"
            e.text = lead + "Fouled off, " + strikeText(s.strikes) + "."
        } else if (twoStrikeOut) {
            s.strikes = 3
            e.strikeout = true
            e.headline = "STRIKEOUT"
            e.text = lead + "Bunted foul with two strikes. That's strike three."
            batterOut(s, e)
        } else {
            e.headline = "FOUL"
            e.text = lead + "Fouled off. Still two strikes."
        }
    }

    if (action === "take") {
        if (where.inZone) {
            strike("called", "Called")
        } else {
            s.balls++
            e.kind = "ball"
            if (s.balls >= 4) {
                e.walk = true
                e.headline = "WALK"
                e.runs = advance(s.bases, "walk", s.outs)
                e.text = lead + "Ball four. Take your base." + runsText(e.runs)
                score(s, e)
                resetCount(s)
            } else {
                e.headline = "BALL"
                e.text = lead + "Taken, " + ballText(s.balls) + "."
            }
        }
    } else if (action === "bunt") {
        const contact = clamp((where.inZone ? 0.78 : 0.4) + p.contact / 2, 0.05, 0.95)
        if (!chance(s, contact)) {
            strike("whiff", "Bunt missed")
        } else if (chance(s, 0.35)) {
            foul(true)
        } else {
            e.spray = 0.25 + rand(s) * 0.5
            if (runnersOn(s) > 0 && chance(s, 0.8)) {
                e.kind = "groundout"
                e.headline = "SAC BUNT"
                s.outs++
                e.outs = 1
                e.runs = advance(s.bases, "groundout", s.outs)
                e.text = lead + (s.outs >= 3 ? "Bunted, thrown out at first."
                    : "Sacrifice bunt. The runners move up.") + runsText(e.runs)
                score(s, e)
                resetCount(s)
            } else if (chance(s, runnersOn(s) > 0 ? 1 : 0.25)) {
                e.kind = "single"
                e.headline = "BUNT SINGLE"
                e.runs = advance(s.bases, "single", s.outs)
                s.hits[team]++
                e.text = lead + "Dropped down and beaten out for a hit." + runsText(e.runs)
                score(s, e)
                resetCount(s)
            } else {
                e.kind = "groundout"
                e.headline = "OUT"
                s.outs++
                e.outs = 1
                e.runs = advance(s.bases, "groundout", s.outs)
                e.text = lead + "Bunted to the pitcher, out at first."
                score(s, e)
                resetCount(s)
            }
        }
    } else {
        // Swing.
        const quality = !where.inZone ? "off" : loc === "mid" ? "mid" : "edge"
        let contact = { mid: 0.9, edge: 0.8, off: 0.38 }[quality] + p.contact
        if (!where.inZone && pitch === "curve") contact -= 0.05
        if (s.balls > s.strikes) contact += 0.05
        if (s.strikes === 2) contact -= 0.03
        const live = timing !== null
        const connected = live ? timing === "hit" && where.inZone : chance(s, clamp(contact, 0.05, 0.95))
        if (!connected) {
            strike("whiff", "Swung on and missed")
        } else if (!live && chance(s, { mid: 0.25, edge: 0.32, off: 0.42 }[quality])) {
            foul(false)
        } else {
            const w = SPRAY[quality].slice()
            if (pitch === "change") w[4] += 8
            if (pitch === "curve") { w[4] += 6; w[3] -= 1 }
            if (pitch === "fast") { w[3] += 1; w[5] += 4 }
            const kind = IN_PLAY[weighted(s, w)]
            e.kind = kind
            e.spray = rand(s)
            if (kind === "groundout" || kind === "flyout") {
                s.outs++
                e.outs = 1
                e.runs = advance(s.bases, kind, s.outs)
                const field = kind === "groundout"
                    ? ["Grounded to short.", "Grounded to second.", "Chopper to third.", "Rolled over to first."]
                    : ["Lazy fly to left.", "Fly ball to center.", "Lifted to right.", "Popped up behind the plate."]
                const sac = kind === "flyout" && e.runs > 0
                e.headline = sac ? "SAC FLY" : kind === "groundout" ? "GROUND OUT" : "FLY OUT"
                e.text = lead + field[Math.floor(rand(s) * field.length)]
                    + (sac ? " The runner tags and scores." : "") + (!sac ? runsText(e.runs) : "")
            } else {
                s.hits[team]++
                e.runs = advance(s.bases, kind, s.outs)
                e.headline = { single: "SINGLE", double: "DOUBLE", triple: "TRIPLE", homer: "HOME RUN" }[kind]
                const call = {
                    single: ["Lined into center for a single.", "Bounced through the hole.", "Blooped into right."],
                    double: ["Ripped into the gap for two.", "Down the line, standing double."],
                    triple: ["Off the wall and he's in with a triple!"],
                    homer: ["Gone! Over the fence!", "Way back... home run!"]
                }[kind]
                e.text = lead + call[Math.floor(rand(s) * call.length)] + runsText(kind === "homer" ? 0 : e.runs)
                if (kind === "homer")
                    e.text += e.runs === 1 ? " Solo shot." : e.runs === 4 ? " Grand slam!" : " " + e.runs + " runs score."
            }
            score(s, e)
            resetCount(s)
        }
    }
    s.last = e
    endOfPlay(s, e)
    return e
}

function batterOut(s, e) {
    s.outs++
    e.outs = 1
    resetCount(s)
}

function resetCount(s) {
    s.balls = 0
    s.strikes = 0
}

function score(s, e) {
    s.score[s.half] += e.runs
    const line = s.line[s.half]
    line[line.length - 1] += e.runs
}

// After every pitch: a walk-off ends the game at once, three outs end the half.
function endOfPlay(s, e) {
    const lastInning = s.inning >= s.innings
    if (s.half === 1 && lastInning && s.score[1] > s.score[0]) {
        s.phase = "final"
        s.summary = e.runs > 0 ? "Walk-off! The home team wins it." : "The home team wins."
        return
    }
    if (s.outs < 3) return
    s.bases = [false, false, false]
    resetCount(s)
    const name = s.half === 0 ? "Visitors" : "Home"
    const r = s.line[s.half][s.line[s.half].length - 1]
    if (lastInning && s.half === 0 && s.score[1] > s.score[0]) {
        s.phase = "final"
        s.summary = "Three outs. The home team was already ahead, so that's the game."
    } else if (lastInning && s.half === 1 && s.score[0] > s.score[1]) {
        s.phase = "final"
        s.summary = "Three outs. The visitors hold on."
    } else if (lastInning && s.half === 1 && s.inning >= s.maxInnings) {
        s.phase = "final"
        s.summary = "Tied after " + s.inning + ". The game is called a tie."
    } else {
        s.phase = "switch"
        s.summary = "Three outs. " + name + " scored " + r + (r === 1 ? " run" : " runs") + " that half."
        if (lastInning && s.half === 1)
            s.summary += " Tied: extra innings."
    }
}

// Starts the next half inning after a "switch".
export function nextHalf(s) {
    if (s.phase !== "switch") throw new Error("nextHalf outside of a switch")
    if (s.half === 0) {
        s.half = 1
    } else {
        s.half = 0
        s.inning++
    }
    s.line[s.half].push(0)
    s.outs = 0
    resetCount(s)
    s.bases = [false, false, false]
    s.phase = "play"
    s.last = null
    s.summary = ""
}

// Checks the state is one the game can be in; returns a list of problems.
export function problems(s) {
    const out = []
    if (s.balls < 0 || s.balls > 3) out.push("balls " + s.balls)
    if (s.strikes < 0 || s.strikes > 2) out.push("strikes " + s.strikes)
    if (s.outs < 0 || s.outs > 3) out.push("outs " + s.outs)
    if (s.phase === "play" && s.outs > 2) out.push("three outs in play")
    if (s.bases.length !== 3 || s.bases.some(b => typeof b !== "boolean")) out.push("bases")
    for (const t of [0, 1]) {
        const sum = s.line[t].reduce((a, b) => a + b, 0)
        if (sum !== s.score[t]) out.push("line " + t + " sums to " + sum + " not " + s.score[t])
    }
    if (s.line[0].length !== s.inning) out.push("visitor line length")
    if (s.line[1].length !== s.inning - (s.half === 0 ? 1 : 0)) out.push("home line length")
    if (!["play", "switch", "final"].includes(s.phase)) out.push("phase " + s.phase)
    return out
}
