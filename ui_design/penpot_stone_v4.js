// RuneCraft HUD v4 — carved rock UI language, run INSIDE Penpot (execute_code). Penpot is the design source;
// game textures are Penpot exports (see pull_penpot_exports.py). Defines storage.S4 = { panel, button, socket,
// tab, well, chip, coin, place, frameBoard }.
const S4 = {};
S4.ROCK = ["#CAC6CC", "#B9B5BD", "#A9A5AF", "#96929E", "#8A8692"];
S4.LIP = "#5F5B68"; S4.DEEP = "#46434F"; S4.OUT = "#100F14";
S4.IN = ["#2B2A31", "#1C1B21"];
S4.MOSS = ["#8ACF55", "#5EA83C", "#3C9A3A", "#2F7D35"];
S4.RUNE = "#7FE3F0"; S4.RUNE_HI = "#D8FBFF"; S4.GOLD = "#F2C14E";
S4.mul = (a) => () => { a |= 0; a = a + 0x6D2B79F5 | 0; let t = Math.imul(a ^ a >>> 15, 1 | a); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; };
S4.fnv = (s) => { let v = 2166136261; for (let i = 0; i < s.length; i++) v = Math.imul(v ^ s.charCodeAt(i), 16777619) >>> 0; return v >>> 0; };
S4.P = (p) => p.map(q => q[0].toFixed(1) + "," + q[1].toFixed(1)).join(" ");
S4.ch = (x, y, w, h, c) => [[x + c, y], [x + w - c, y], [x + w, y + c], [x + w, y + h - c], [x + w - c, y + h], [x + c, y + h], [x, y + h - c], [x, y + c]];
S4.shade = (hx, f) => "#" + [1, 3, 5].map(i => Math.max(0, Math.min(255, Math.floor(parseInt(hx.slice(i, i + 2), 16) * f))).toString(16).padStart(2, "0")).join("").toUpperCase();
S4.gid = 0;
S4.svg = (w, h, body) => `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">${body}</svg>`;
S4.block = (x, y, w, h, r, tone, lip = 3, chip = true, side = "top") => {
  const P = S4.P, O = S4.OUT, id = "bk" + (++S4.gid), vert = side === "left" || side === "right";
  const c = [0, 1, 2, 3].map(() => chip && r() < 0.7 ? 2 + r() * 4 : 1.2);
  const face = [[x + c[0], y], [x + w - c[1], y], [x + w, y + c[1]], [x + w, y + h - c[2]], [x + w - c[2], y + h], [x + c[3], y + h], [x, y + h - c[3]], [x, y + c[0]]];
  let o = `<defs><linearGradient id="${id}" x1="0" y1="0" x2="${vert ? 1 : 0}" y2="${vert ? 0 : 1}"><stop offset="0" stop-color="${S4.shade(tone, 1.10)}"/><stop offset="1" stop-color="${S4.shade(tone, 0.86)}"/></linearGradient></defs><polygon points="${P(face)}" fill="url(#${id})"/>`;
  if (lip > 0) o += vert ? `<polygon points="${P([[x + w - lip, y + c[1]], [x + w, y + c[1]], [x + w, y + h - c[2]], [x + w - lip, y + h - c[2]]])}" fill="${S4.LIP}"/>`
                         : `<polygon points="${P([[x + c[3], y + h - lip], [x + w - c[2], y + h - lip], [x + w - c[2], y + h], [x + c[3], y + h]])}" fill="${S4.LIP}"/>`;
  if (r() < 0.75) {
    const k = 0.22 + r() * 0.3;
    const poly = !vert ? [[x + w * (1 - k), y], [x + w - c[1], y], [x + w, y + c[1]], [x + w, y + h - lip], [x + w * (1 - k) - h * 0.4, y + h - lip]]
                       : [[x, y + h * (1 - k)], [x + w - lip, y + h * (1 - k) - w * 0.4], [x + w - lip, y + h - c[2]], [x + c[3], y + h], [x, y + h - c[3]]];
    o += `<polygon points="${P(poly)}" fill="#000000" fill-opacity="${(0.07 + r() * 0.07).toFixed(2)}"/>`;
  }
  for (let i = 0; i < Math.floor((vert ? h : w) / 22); i++) if (r() < 0.5) {
    if (!vert) { const nx = x + 4 + r() * (w - 8); o += `<polygon points="${P([[nx, y], [nx + 3, y], [nx + 1.5, y + 2]])}" fill="${O}" fill-opacity="0.8"/>`; }
    else { const ny = y + 4 + r() * (h - 8); o += `<polygon points="${P([[x, ny], [x, ny + 3], [x + 2, ny + 1.5]])}" fill="${O}" fill-opacity="0.8"/>`; }
  }
  o += `<polyline points="${P([[x + 0.6, y + h - c[3] - 1], [x + 0.6, y + c[0]], [x + c[0], y + 0.6], [x + w - c[1], y + 0.6]])}" fill="none" stroke="#FFFFFF" stroke-opacity="0.42" stroke-width="1.2"/>`;
  for (let i = 0; i < Math.floor(w * h / 150); i++) {
    const px = x + 3 + r() * Math.max(1, w - 6), py = y + 2 + r() * Math.max(1, h - lip - 4), sz = 1 + r() * 1.5;
    o += `<rect x="${px.toFixed(1)}" y="${py.toFixed(1)}" width="${sz.toFixed(1)}" height="${sz.toFixed(1)}" fill="#000000" fill-opacity="${(0.12 + r() * 0.12).toFixed(2)}"/>`;
    if (r() < 0.4) o += `<rect x="${px.toFixed(1)}" y="${(py + sz).toFixed(1)}" width="${sz.toFixed(1)}" height="0.8" fill="#FFFFFF" fill-opacity="0.15"/>`;
  }
  if (w * h > 500 && r() < 0.35) {
    let cx = x + w * (0.2 + r() * 0.6), cy = y + 1; const pts = [[cx, cy]];
    for (let i = 0; i < 3; i++) { cx += (r() - 0.5) * 6; cy += 2 + r() * (h * 0.25); pts.push([cx, Math.min(cy, y + h - lip - 1)]); }
    o += `<polyline points="${P(pts)}" fill="none" stroke="${O}" stroke-opacity="0.55" stroke-width="1"/>`;
  }
  return o + `<polygon points="${P(face)}" fill="none" stroke="${O}" stroke-width="1.6" stroke-linejoin="round"/>`;
};
S4.moss = (x, y, w, r, amount = 1) => {
  let o = ""; const M = S4.MOSS;
  for (let i = 0; i < Math.max(1, Math.floor(w / 30 * amount)); i++) {
    const mx = x + r() * (w - 28), mw = 10 + r() * 18;
    o += `<rect x="${mx.toFixed(0)}" y="${y - 2}" width="${mw.toFixed(0)}" height="7" fill="${M[2]}"/><rect x="${(mx + 2).toFixed(0)}" y="${y - 5}" width="${(mw - 4).toFixed(0)}" height="5" fill="${M[1]}"/><rect x="${(mx + 4).toFixed(0)}" y="${y - 6}" width="${Math.max(3, mw - 10).toFixed(0)}" height="2" fill="${M[0]}"/>`;
    for (let k = 0; k < Math.floor(r() * 3); k++) o += `<rect x="${(mx + 2 + r() * (mw - 4)).toFixed(0)}" y="${y + 5}" width="2" height="${(2 + r() * 7).toFixed(0)}" fill="${M[3]}"/>`;
    o += `<rect x="${mx.toFixed(0)}" y="${y - 2}" width="${mw.toFixed(0)}" height="7" fill="none" stroke="${S4.OUT}" stroke-opacity="0.35" stroke-width="0.8"/>`;
  }
  return o;
};
S4.runeStone = (cx, cy, s, r, glow = S4.RUNE) => {
  const P = S4.P, g = s * 0.17;
  return S4.block(cx - s / 2, cy - s / 2, s, s, r, S4.ROCK[1], 4)
    + `<circle cx="${cx}" cy="${cy - 1}" r="${(s * 0.3).toFixed(1)}" fill="#1C1B21" stroke="${S4.OUT}" stroke-width="1.2"/>`
    + `<circle cx="${cx}" cy="${cy - 1}" r="${(g * 2.4).toFixed(1)}" fill="${glow}" fill-opacity="0.22"/>`
    + `<polygon points="${P([[cx, cy - 1 - g * 1.4], [cx + g, cy - 1], [cx, cy - 1 + g * 1.4], [cx - g, cy - 1]])}" fill="${glow}" stroke="${S4.OUT}" stroke-width="1"/>`
    + `<polygon points="${P([[cx, cy - 1 - g * 1.4], [cx + g * 0.5, cy - 1 - g * 0.3], [cx - g * 0.5, cy - 1 - g * 0.3]])}" fill="${S4.RUNE_HI}" fill-opacity="0.9"/>`;
};
S4.run = (x0, y0, len, thick, r, horiz, side) => {
  let o = "", pos = 0;
  while (pos < len - 0.5) {
    const seg = Math.min(26 + r() * 30, len - pos), tone = S4.ROCK[Math.floor(r() * 4)];
    o += horiz ? S4.block(x0 + pos, y0, seg, thick, r, tone, 3, true, side) : S4.block(x0, y0 + pos, thick, seg, r, tone, 3, true, side);
    pos += seg;
  }
  return o;
};
S4.panel = (w, h, name, o = {}) => {
  const F = o.frame || 18, C = o.corner || 34, r = S4.mul(S4.fnv(name)), P = S4.P, id = "in" + S4.fnv(name);
  let b = `<defs><linearGradient id="${id}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${S4.IN[0]}"/><stop offset="1" stop-color="${S4.IN[1]}"/></linearGradient></defs>`;
  b += `<polygon points="${P(S4.ch(2, 6, w - 4, h - 6, C * 0.6))}" fill="#000000" fill-opacity="0.35"/>`;
  b += `<polygon points="${P(S4.ch(F * 0.5, F * 0.5, w - F, h - F, C * 0.5))}" fill="url(#${id})"/>`;
  for (let i = 0; i < Math.floor(w * h / 120); i++) b += `<rect x="${(F + r() * (w - 2 * F)).toFixed(0)}" y="${(F + r() * (h - 2 * F)).toFixed(0)}" width="1" height="1" fill="${r() < 0.4 ? "#FFFFFF" : "#000000"}" fill-opacity="0.07"/>`;
  b += `<rect x="${F}" y="${F}" width="${w - 2 * F}" height="7" fill="#000000" fill-opacity="0.35"/><rect x="${F}" y="${F}" width="5" height="${h - 2 * F}" fill="#000000" fill-opacity="0.22"/>`;
  b += S4.run(C - 4, 0, w - 2 * C + 8, F, r, true, "top") + S4.run(C - 4, h - F, w - 2 * C + 8, F, r, true, "bottom");
  b += S4.run(0, C - 4, h - 2 * C + 8, F, r, false, "left") + S4.run(w - F, C - 4, h - 2 * C + 8, F, r, false, "right");
  if (o.moss !== false) b += S4.moss(C, 1, w - 2 * C, r, o.mossAmount || 1);
  for (const [cx, cy] of [[C / 2, C / 2], [w - C / 2, C / 2], [w - C / 2, h - C / 2], [C / 2, h - C / 2]])
    b += o.runes === false ? S4.block(cx - C / 2, cy - C / 2, C, C, r, S4.ROCK[0], 4) : S4.runeStone(cx, cy, C, r);
  return S4.svg(w, h, b);
};
S4.button = (w, h, name, state = "normal", accent = null) => {
  const r = S4.mul(S4.fnv(name)), P = S4.P, lip = { normal: 5, hover: 6, pressed: 2, disabled: 3 }[state];
  const face = { normal: S4.ROCK[2], hover: S4.ROCK[1], pressed: S4.ROCK[3], disabled: "#77737E" }[state];
  const top = state === "pressed" ? 4 : 1, fh = h - top - 1 - lip;
  let b = "";
  if (state === "hover") b += `<polygon points="${P(S4.ch(0, 0, w, h, 9))}" fill="${accent || S4.RUNE}" fill-opacity="0.22"/>`;
  b += `<polygon points="${P(S4.ch(2, top + 3, w - 4, h - top - 3, 7))}" fill="#000000" fill-opacity="0.35"/>`;
  b += `<polygon points="${P(S4.ch(1, top, w - 2, h - top - 1, 7))}" fill="${S4.LIP}" stroke="${S4.OUT}" stroke-width="1.5"/>`;
  b += S4.block(1, top, w - 2, fh, r, face, 0, true);
  if (accent && state !== "disabled") {
    const y = top + fh - 5, op = state === "hover" ? 1 : 0.8;
    b += `<rect x="10" y="${y - 1}" width="${w - 20}" height="3" fill="#000000" fill-opacity="0.5"/><rect x="11" y="${y - 0.5}" width="${w - 22}" height="2" fill="${accent}" fill-opacity="${op}"/><rect x="11" y="${y - 3}" width="${w - 22}" height="6" fill="${accent}" fill-opacity="${(0.12 * op).toFixed(2)}"/>`;
  }
  if (state === "disabled") b += `<polygon points="${P(S4.ch(1, top, w - 2, h - top - 1, 7))}" fill="#000000" fill-opacity="0.25"/>`;
  return S4.svg(w, h, b);
};
S4.socket = (s, name, state = "normal", h = null) => {
  h = h || s; const w = s, r = S4.mul(S4.fnv(name)), P = S4.P;
  const rim = { normal: S4.ROCK[3], hover: S4.ROCK[1], selected: "#ECE6D6", drop: S4.RUNE, output: S4.GOLD }[state];
  const c = Math.min(9, h * 0.3);
  let b = "";
  if (state === "drop" || state === "output") b += `<polygon points="${P(S4.ch(0, 0, w, h, c + 2))}" fill="${rim}" fill-opacity="0.28"/>`;
  b += `<polygon points="${P(S4.ch(2, 2, w - 4, h - 4, c))}" fill="${rim}" stroke="${S4.OUT}" stroke-width="1.5"/>`;
  b += `<polyline points="${P([[3, h - c - 3], [3, c + 2], [c + 2, 3], [w - c - 2, 3]])}" fill="none" stroke="#FFFFFF" stroke-opacity="0.4" stroke-width="1"/>`;
  b += `<polygon points="${P(S4.ch(6, 6, w - 12, h - 12, Math.max(2, c - 3)))}" fill="#16151A" stroke="${S4.OUT}" stroke-width="1"/>`;
  b += `<rect x="7" y="7" width="${w - 14}" height="${Math.min(5, (h - 14) * 0.4)}" fill="#000000" fill-opacity="0.45"/><rect x="7" y="${h - 9}" width="${w - 14}" height="1" fill="#FFFFFF" fill-opacity="0.06"/>`;
  for (let i = 0; i < Math.floor(w / 16); i++) b += `<rect x="${(4 + r() * (w - 8)).toFixed(0)}" y="${(3 + r() * 2).toFixed(0)}" width="1.5" height="1.5" fill="#000000" fill-opacity="0.25"/>`;
  return S4.svg(w, h, b);
};
S4.tab = (w, h, name, state = "idle") => {
  const r = S4.mul(S4.fnv(name)), tone = { idle: S4.ROCK[3], hover: S4.ROCK[2], active: S4.ROCK[1] }[state], lift = { idle: 6, hover: 3, active: 0 }[state];
  let b = S4.block(0, lift, w, h - lift + 4, r, tone, 0);
  if (state === "active") b += S4.moss(10, lift + 1, w - 20, r, 0.8) + `<rect x="12" y="${h - 5}" width="${w - 24}" height="2" fill="${S4.RUNE}"/><rect x="12" y="${h - 9}" width="${w - 24}" height="4" fill="${S4.RUNE}" fill-opacity="0.2"/>`;
  else b += `<rect x="1" y="${lift}" width="${w - 2}" height="${h - lift + 4}" fill="#000000" fill-opacity="0.22"/>`;
  return S4.svg(w, h, b);
};
S4.well = (w, h, name) => S4.socket(w, name, "normal", h);
S4.coin = (s, name, state = "normal") => S4.button(s, s, name, state === "active" ? "pressed" : state, state === "active" ? S4.GOLD : (state === "hover" ? S4.RUNE : null));
S4.chip = (w, h, name, edge = null) => {
  const P = S4.P;
  return S4.svg(w, h, `<polygon points="${P(S4.ch(1, 1, w - 2, h - 2, 7))}" fill="#1A191F" fill-opacity="0.92" stroke="${edge || S4.OUT}" stroke-width="1.5"/><polyline points="${P([[2, h - 8], [2, 8], [8, 2], [w - 8, 2]])}" fill="none" stroke="#FFFFFF" stroke-opacity="0.08" stroke-width="1"/>`);
};
// An exact-size, clipped, unfilled board holding one art group: export target with exact pixel bounds.
S4.frameBoard = (svgStr, name, w, h) => {
  const b = penpot.createBoard(); b.name = name; b.resize(w, h); b.fills = []; b.clipContent = true;
  const g = penpot.createShapeFromSvg(svgStr); g.name = "art"; b.appendChild(g); g.x = b.x; g.y = b.y;
  return b;
};
storage.S4 = S4;
