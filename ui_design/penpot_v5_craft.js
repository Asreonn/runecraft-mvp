// RuneCraft UI v5 — craft tab, rune structure and floating inspector pieces. Run INSIDE Penpot (execute_code) after
// penpot_stone_v4.js (needs storage.S4). Defines storage.S5 with SVG generators; boards named "rcui / <name>" are
// exported at 2x like v4. Design rules: square slots (small 45° chamfer, no circles behind runes), one clean rim per
// state, no speckles inside wells, states separated by rim colour + one accent, never by extra decoration.
const S4 = storage.S4;
const S5 = {};
S5.C = {
  out: "#100F14", well: "#17161B", wellHi: "#211F26", lip: "#5F5B68",
  rim: { normal: "#8A8692", hover: "#B9B5BD", selected: "#ECE6D6", drop: "#7FE3F0", invalid: "#F06A5A",
         output: "#F2C14E", pending: "#5CB9FF", locked: "#4A4752" },
  rune: "#7FE3F0", gold: "#F2C14E", mana: "#5CB9FF", bad: "#F06A5A", good: "#8ED45E", bone: "#ECE6D6", muted: "#8C877D",
};
S5.ch = S4.ch; S5.P = S4.P; S5.svg = S4.svg;

// Square rune slot, one state per export. 64x64 at 1x; 9-slice margins 12.
S5.slot = (state = "normal", s = 64) => {
  const P = S5.P, C = S5.C, rim = C.rim[state], c = 6, w = s, h = s;
  let b = "";
  b += `<polygon points="${P(S5.ch(1, 2, w - 2, h - 2, c))}" fill="#000000" fill-opacity="0.35"/>`;            // drop shadow
  b += `<polygon points="${P(S5.ch(1, 1, w - 2, h - 2, c))}" fill="${rim}" stroke="${C.out}" stroke-width="1.5"/>`;
  b += `<polyline points="${P([[2.5, h - c - 2], [2.5, c + 1.5], [c + 1.5, 2.5], [w - c - 2, 2.5]])}" fill="none" stroke="#FFFFFF" stroke-opacity="${state === "locked" ? 0.08 : 0.35}" stroke-width="1"/>`;
  b += `<polyline points="${P([[w - 2.5, c + 2], [w - 2.5, h - c - 1.5], [w - c - 1.5, h - 2.5], [c + 2, h - 2.5]])}" fill="none" stroke="#000000" stroke-opacity="0.3" stroke-width="1"/>`;
  const inner = S5.ch(5, 5, w - 10, h - 10, 4);
  b += `<polygon points="${P(inner)}" fill="${state === "locked" ? "#111015" : C.well}" stroke="${C.out}" stroke-width="1"/>`;
  b += `<rect x="6" y="6" width="${w - 12}" height="4" fill="#000000" fill-opacity="0.4"/>`;                    // inner top shadow
  b += `<rect x="8" y="${h - 7}" width="${w - 16}" height="1" fill="#FFFFFF" fill-opacity="0.07"/>`;
  if (state === "drop" || state === "pending" || state === "output" || state === "invalid")                   // inner accent line
    b += `<polygon points="${P(S5.ch(7, 7, w - 14, h - 14, 3))}" fill="none" stroke="${rim}" stroke-opacity="0.45" stroke-width="1.5"/>`;
  return S5.svg(w, h, b);
};
// Square soft glow drawn around a slot that can accept the current drag (replaces the round vfx_glow there). 96x96.
S5.slotGlow = (col) => {
  const P = S5.P; let b = "";
  for (let i = 0; i < 8; i++) b += `<polygon points="${P(S5.ch(4 + i * 2, 4 + i * 2, 88 - i * 4, 88 - i * 4, 10))}" fill="none" stroke="${col}" stroke-opacity="${(0.03 + i * 0.022).toFixed(3)}" stroke-width="2.5"/>`;
  return S5.svg(96, 96, b);
};
// Compact rows for the rune structure / inspector. 9-slice margins 10.
S5.row = (state = "idle", w = 160, h = 40) => {
  const P = S5.P, C = S5.C;
  const edge = { idle: "#3A3842", hover: "#6E6A78", active: C.rune, locked: "#2C2B33", off: "#3A3842", bad: "#7A3A34" }[state];
  const face = { idle: "#1E1D24", hover: "#26252D", active: "#1F2A30", locked: "#16151A", off: "#1A191F", bad: "#271A1C" }[state];
  let b = `<polygon points="${P(S5.ch(1, 1, w - 2, h - 2, 5))}" fill="${face}" fill-opacity="0.96" stroke="${state === "active" ? C.out : edge}" stroke-width="1.5"/>`;
  if (state === "active") b += `<polygon points="${P(S5.ch(1, 1, w - 2, h - 2, 5))}" fill="none" stroke="${C.rune}" stroke-opacity="0.75" stroke-width="1"/>`;
  b += `<polyline points="${P([[2, h - 6], [2, 6], [6, 2], [w - 6, 2]])}" fill="none" stroke="#FFFFFF" stroke-opacity="0.07" stroke-width="1"/>`;
  const bar = { idle: "#5F5B68", hover: "#8A8692", active: C.rune, locked: "#3A3842", off: "#4A4752", bad: C.bad }[state];
  b += `<rect x="3" y="7" width="3" height="${h - 14}" fill="${bar}"/>`;                                        // state bar (left)
  if (state === "locked") for (let x = 12; x < w - 6; x += 10) b += `<rect x="${x}" y="${h - 4}" width="5" height="1" fill="#5F5B68"/>`;
  return S5.svg(w, h, b);
};
// Donor pill under an ability: ok (contributes) / off (no contribution here) / bad (something not carried). 9-slice 8.
S5.pill = (kind = "ok", w = 96, h = 28) => {
  const P = S5.P, C = S5.C;
  const edge = { ok: C.mana, off: "#4A4752", bad: C.bad, pend: C.rune }[kind];
  const face = { ok: "#18222C", off: "#18171C", bad: "#24181A", pend: "#172529" }[kind];
  return S5.svg(w, h, `<polygon points="${P(S5.ch(1, 1, w - 2, h - 2, 4))}" fill="${face}" stroke="${edge}" stroke-opacity="${kind === "off" ? 1 : 0.8}" stroke-width="1.3"${kind === "pend" ? ' stroke-dasharray="4 3"' : ""}/>`);
};
// Small count / grade badges. 9-slice 6.
S5.badge = (kind = "dark", w = 24, h = 16) => {
  const P = S5.P, C = S5.C;
  const face = { dark: "#26252D", mana: "#2F6FA8", gold: "#8A6420", rune: "#1F5A63", bad: "#7A2E28" }[kind];
  const edge = { dark: "#5F5B68", mana: C.mana, gold: C.gold, rune: C.rune, bad: C.bad }[kind];
  return S5.svg(w, h, `<polygon points="${P(S5.ch(0.75, 0.75, w - 1.5, h - 1.5, 3))}" fill="${face}" stroke="${C.out}" stroke-width="1.5"/><polygon points="${P(S5.ch(2, 2, w - 4, h - 4, 2))}" fill="none" stroke="${edge}" stroke-opacity="0.7" stroke-width="1"/>`);
};
// Connector pieces for donor branches: a vertical spine and an elbow, stretched in Godot.
S5.link = (kind = "line", col = "#5F5B68") => {
  if (kind === "line") return S5.svg(8, 8, `<rect x="2.5" y="0" width="3" height="8" fill="${S5.C.out}"/><rect x="3.25" y="0" width="1.5" height="8" fill="${col}"/>`);
  if (kind === "dot") return S5.svg(12, 12, `<polygon points="6,1 11,6 6,11 1,6" fill="${col}" stroke="${S5.C.out}" stroke-width="1.5"/>`);
  return "";
};
// Tooltip / floating inspector frames.
S5.tip = (w = 200, h = 120) => {
  const P = S5.P, C = S5.C;
  return S5.svg(w, h, `<polygon points="${P(S5.ch(2, 3, w - 3, h - 3, 7))}" fill="#000000" fill-opacity="0.45"/>`
    + `<polygon points="${P(S5.ch(1, 1, w - 3, h - 3, 7))}" fill="#16151A" fill-opacity="0.97" stroke="${C.out}" stroke-width="1.5"/>`
    + `<polygon points="${P(S5.ch(3, 3, w - 7, h - 7, 5))}" fill="none" stroke="#5F5B68" stroke-width="1"/>`
    + `<rect x="12" y="3" width="${w - 27}" height="2" fill="${C.rune}" fill-opacity="0.85"/>`);
};
S5.floatPanel = (w = 640, h = 480) => S4.panel(w, h, "rcui-float-v5", { frame: 14, corner: 28, mossAmount: 0.5 });
S5.header = (w = 200, h = 64) => {
  const P = S5.P;
  return S5.svg(w, h, `<polygon points="${P(S5.ch(1, 1, w - 2, h - 2, 6))}" fill="#1F1E25" stroke="#3A3842" stroke-width="1.2"/>`
    + `<rect x="2" y="${h - 3}" width="${w - 4}" height="1" fill="#000000" fill-opacity="0.6"/><rect x="8" y="2" width="${w - 16}" height="1" fill="#FFFFFF" fill-opacity="0.08"/>`);
};
// Line icons (24x24, bone on transparent with a dark outline), consistent with the v4 icon weight.
S5.icon = (kind) => {
  const o = S5.C.out, f = S5.C.bone;
  const st = (d, w = 2.4) => `<path d="${d}" fill="none" stroke="${o}" stroke-width="${w + 2}" stroke-linecap="square" stroke-linejoin="miter"/><path d="${d}" fill="none" stroke="${f}" stroke-width="${w}" stroke-linecap="square" stroke-linejoin="miter"/>`;
  const body = {
    close: st("M6 6 L18 18 M18 6 L6 18"),
    chev_right: st("M9 5 L16 12 L9 19"),
    chev_down: st("M5 9 L12 16 L19 9"),
    lock: `<rect x="5" y="10" width="14" height="10" fill="${f}" stroke="${o}" stroke-width="1.6"/>` + st("M8 10 V7 L10 5 H14 L16 7 V10", 2.2) + `<rect x="11" y="13" width="2" height="4" fill="${o}"/>`,
    link: st("M4 12 H10 M14 12 H20") + `<polygon points="12,8 16,12 12,16 8,12" fill="${S5.C.rune}" stroke="${o}" stroke-width="1.5"/>`,
    expand: st("M5 9 V5 H9 M15 5 H19 V9 M19 15 V19 H15 M9 19 H5 V15"),
    warn: `<polygon points="12,3 22,20 2,20" fill="${S5.C.bad}" stroke="${o}" stroke-width="1.6"/><rect x="11" y="9" width="2" height="6" fill="${o}"/><rect x="11" y="16.5" width="2" height="2" fill="${o}"/>`,
  }[kind];
  return S5.svg(24, 24, body);
};
storage.S5 = S5;
