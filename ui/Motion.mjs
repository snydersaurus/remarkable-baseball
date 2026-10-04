// Presentation only. The rules resolve on a copy; Game commits it after these
// discrete frames. No elapsed-time catch-up: slow displays see every pose.
export function makesContact(e) {
    return !!e && !["ball", "called", "whiff"].includes(e.kind)
}

export function runnerMoves(before, after, e) {
    const moves = []
    const hit = { single: 1, double: 2, triple: 3, homer: 4 }[e.kind] || 0
    const productive = before.outs + e.outs < 3
    for (let i = 0; i < 3; i++) {
        if (!before.bases[i]) continue
        const from = i + 1
        let advance = hit
        if (e.walk) advance = before.bases.slice(0, i).every(Boolean) ? 1 : 0
        if (e.kind === "groundout" && productive) advance = 1
        if (e.kind === "flyout" && productive && i === 2) advance = 1
        moves.push({ from, to: Math.min(4, from + advance) })
    }
    if (hit || e.walk) moves.push({ from: 0, to: hit || 1 })
    // Show a groundout batter running down the line, then disappear at result.
    if (e.kind === "groundout") moves.push({ from: 0, to: 1 })
    return moves
}

export function swingTiming(frame) {
    return frame && frame.ball && frame.ball.space === "pitch" && frame.ball.t >= 0.6 ? "hit" : "miss"
}
export function deliveryFrames(before, smooth = false) {
    const runners = before.bases.map((occupied, i) => ({ from: i + 1, to: i + 1, t: 0, occupied })).filter(r => r.occupied)
    const frame = (label, pitcher, ball, beat = 1) => ({label, pitcher, batter:"stance", ball, runners, beat, stride:0})
    return [frame("PITCHER SET", "set", null, 1.4), frame("WINDUP", "windup", null),
        frame("RELEASE", "release", {space:"pitch",t:0}),
        ...(smooth ? [0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1] : [0.2,0.4,0.6,0.8,1]).map(t => frame("PITCH IN", "follow", {space:"pitch",t}, smooth ? 0.5 : 1)),
        // Hold the arrival frame for one extra beat: input can trail the e-ink refresh.
        frame("AT THE PLATE", "follow", {space:"pitch",t:1}, smooth ? 1.5 : 1)]
}
export function resultFrames(before, after, smooth = false) {
    const e = after.last
    const still = before.bases.map((occupied, i) => ({ from: i + 1, to: i + 1, t: 0, occupied })).filter(r => r.occupied)
    const frames = []
    const add = (label, pitcher, batter, ball, runners = still, beat = 1) =>
        frames.push({ label, pitcher, batter, ball, runners, beat, stride: Math.floor(frames.length / (smooth ? 2 : 1)) % 2 })
    const pose = e.action === "swing" ? "swing" : e.action === "bunt" ? "bunt" : "stance"
    add(makesContact(e) ? "CONTACT" : e.kind === "whiff" ? "SWING & MISS" : "IN THE MITT", "follow", pose,
        {space: makesContact(e) ? "hit" : "catch", t:0}, still, 1.2)
    if (makesContact(e)) {
        for (const t of (smooth ? [0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1] : [0.2,0.4,0.6,0.8,1]))
            add(e.kind === "foul" ? "FOUL BALL" : "BALL IN PLAY", "set", e.action === "bunt" ? "bunt" : "follow", { space: "hit", t }, still, smooth ? 0.5 : 1)
    } else {
        add(e.kind === "whiff" ? "SWING & MISS" : "IN THE MITT", "set", e.action === "swing" ? "follow" : pose, { space: "catch", t: 1 }, still, 1.4)
    }
    const moves = runnerMoves(before, after, e)
    const distance = Math.max(0, ...moves.map(r => r.to - r.from))
    const stepsPerBase = smooth ? 6 : 3
    for (let step = 1; step <= distance * stepsPerBase; step++) {
        const runners = moves.map(r => ({ from: r.from, to: r.to, t: r.to === r.from ? 0 : Math.min(1, step / (stepsPerBase * (r.to - r.from))) }))
        add("RUNNERS ADVANCE", "set", "empty", null, runners, smooth ? 0.5 : 1)
    }
    return frames
}
