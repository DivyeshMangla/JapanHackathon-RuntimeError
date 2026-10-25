import { spawn } from 'node:child_process';
import { deflateSync, inflateSync } from 'node:zlib';

// Analysis copies contain the same pixels and marks. The uploaded original is
// retained separately and is always the primary evidence for the clinician.
function decodePng(photo) {
  const width = photo.readUInt32BE(16), height = photo.readUInt32BE(20);
  const channels = { 0: 1, 2: 3, 4: 2, 6: 4 }[photo[25]];
  if (photo[24] !== 8 || !channels || photo[28] !== 0) return null;
  const chunks = [];
  for (let offset = 8; offset + 12 <= photo.length;) {
    const length = photo.readUInt32BE(offset);
    if (photo.toString('ascii', offset + 4, offset + 8) === 'IDAT') chunks.push(photo.subarray(offset + 8, offset + 8 + length));
    offset += length + 12;
  }
  const stride = width * channels, expected = (stride + 1) * height;
  const filtered = inflateSync(Buffer.concat(chunks), { maxOutputLength: expected });
  if (filtered.length !== expected) throw new Error('Invalid pixel data');
  const pixels = Buffer.alloc(width * height);
  let prior = Buffer.alloc(stride);
  for (let y = 0; y < height; y++) {
    const filter = filtered[y * (stride + 1)], row = Buffer.allocUnsafe(stride);
    if (filter > 4) throw new Error('Invalid PNG filter');
    for (let x = 0; x < stride; x++) {
      const left = x >= channels ? row[x - channels] : 0, up = prior[x], diagonal = x >= channels ? prior[x - channels] : 0;
      const p = left + up - diagonal, a = Math.abs(p - left), b = Math.abs(p - up), c = Math.abs(p - diagonal);
      const predictor = filter === 0 ? 0 : filter === 1 ? left : filter === 2 ? up : filter === 3 ? Math.floor((left + up) / 2) : a <= b && a <= c ? left : b <= c ? up : diagonal;
      row[x] = (filtered[y * (stride + 1) + 1 + x] + predictor) & 255;
    }
    for (let x = 0; x < width; x++) {
      const offset = x * channels;
      const luminance = channels < 3 ? row[offset] : 0.2126 * row[offset] + 0.7152 * row[offset + 1] + 0.0722 * row[offset + 2];
      const alpha = channels === 2 ? row[offset + 1] : channels === 4 ? row[offset + 3] : 255;
      pixels[y * width + x] = Math.round(luminance * alpha / 255 + 255 - alpha);
    }
    prior = row;
  }
  return { width, height, pixels };
}

function pixelSummary({ pixels }) {
  let low = 255, high = 0, total = 0;
  for (const value of pixels) { low = Math.min(low, value); high = Math.max(high, value); total += value; }
  return { low, high, meanLuminance: Math.round(total / pixels.length), pixelRange: high - low };
}

// Local contrast separates pencil from uneven paper lighting. These are only
// geometric candidates: ruled paper, borders and other objects need vision review.
function inkMask({ width, height, pixels }) {
  const scale = Math.max(1, Math.ceil(Math.max(width, height) / 1000));
  const w = Math.ceil(width / scale), h = Math.ceil(height / scale);
  const gray = new Uint8Array(w * h).fill(255);
  for (let y = 0; y < height; y++) for (let x = 0; x < width; x++) {
    const i = Math.floor(y / scale) * w + Math.floor(x / scale);
    gray[i] = Math.min(gray[i], pixels[y * width + x]);
  }
  const stride = w + 1, integral = new Float64Array(stride * (h + 1));
  for (let y = 0; y < h; y++) {
    let sum = 0;
    for (let x = 0; x < w; x++) {
      sum += gray[y * w + x];
      integral[(y + 1) * stride + x + 1] = integral[y * stride + x + 1] + sum;
    }
  }
  const mask = new Uint8Array(w * h), depth = new Uint8Array(w * h), radius = Math.max(8, Math.round(Math.min(w, h) / 20));
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const left = Math.max(0, x - radius), right = Math.min(w, x + radius + 1);
    const top = Math.max(0, y - radius), bottom = Math.min(h, y + radius + 1);
    const mean = (integral[bottom * stride + right] - integral[top * stride + right]
      - integral[bottom * stride + left] + integral[top * stride + left]) / ((right - left) * (bottom - top));
    depth[y * w + x] = Math.max(0, Math.min(255, Math.round(mean - gray[y * w + x])));
    mask[y * w + x] = depth[y * w + x] >= 8 ? 1 : 0;
  }
  return { w, h, mask, depth };
}

export function detectMotorLines(decoded) {
  const { w, h, mask } = inkMask(decoded);
  const queue = new Int32Array(w * h), candidates = [];
  for (let i = 0; i < mask.length; i++) {
    if (!mask[i]) continue;
    let head = 0, tail = 1, minX = w, maxX = 0, minY = h, maxY = 0;
    let sx = 0, sy = 0, sxx = 0, sxy = 0, syy = 0;
    queue[0] = i; mask[i] = 0;
    while (head < tail) {
      const p = queue[head++], x = p % w, y = Math.floor(p / w);
      minX = Math.min(minX, x); maxX = Math.max(maxX, x);
      minY = Math.min(minY, y); maxY = Math.max(maxY, y);
      sx += x; sy += y; sxx += x * x; sxy += x * y; syy += y * y;
      for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) {
        const nx = x + dx, ny = y + dy, next = ny * w + nx;
        if (nx >= 0 && nx < w && ny >= 0 && ny < h && mask[next]) {
          mask[next] = 0; queue[tail++] = next;
        }
      }
    }
    const span = maxX - minX, vx = sxx / tail - (sx / tail) ** 2;
    if (span < w * 0.12 || vx <= 0 || minX === 0 || minY === 0 || maxX === w - 1 || maxY === h - 1) continue;
    const covariance = sxy / tail - sx * sy / tail ** 2;
    const slope = covariance / vx;
    const deviation = Math.sqrt(Math.max(0, syy / tail - (sy / tail) ** 2 - covariance * slope));
    if (Math.abs(slope) > 0.6 || deviation > Math.max(3, span * 0.035) || tail < span * 0.6) continue;
    candidates.push({
      bounds: [minX / w, minY / h, (maxX + 1) / w, (maxY + 1) / h].map(v => Number(v.toFixed(3))),
      angleDegrees: Math.round(Math.atan(slope) * 180 / Math.PI),
    });
  }
  candidates.sort((a, b) => a.bounds[1] - b.bounds[1]);
  return { method: 'local_contrast_components_v1', candidates: candidates.slice(0, 50), truncated: candidates.length > 50 };
}

// Vision models anchor on the expected number of forms, so the count of
// separate pen marks is measured from pixels instead. Gaps of about 1.5% of
// the page are closed so a stroke lifted mid-letter stays one mark, and
// specks and marks cut off by the photo edge are ignored. Paper grain and
// shadows are far fainter than the drawn strokes, so a mark only counts when
// it is at least a third as dark as the darkest one. A null count means no
// clear ink was found and the vision model's count is used instead.
export function countMotorMarks(decoded) {
  const { w, h, mask, depth } = inkMask(decoded);
  const gap = Math.max(2, Math.round(Math.max(w, h) * 0.015));
  const closed = new Uint8Array(w * h);
  const rows = new Uint8Array(w * h);
  for (let y = 0; y < h; y++) {
    let last = -Infinity;
    for (let x = 0; x < w; x++) if (mask[y * w + x]) last = x; else if (x - last <= gap) rows[y * w + x] = 1;
    let next = Infinity;
    for (let x = w - 1; x >= 0; x--) if (mask[y * w + x]) next = x; else if (next - x > gap) rows[y * w + x] = 0;
    for (let x = 0; x < w; x++) if (mask[y * w + x]) rows[y * w + x] = 1;
  }
  for (let x = 0; x < w; x++) {
    let last = -Infinity;
    for (let y = 0; y < h; y++) if (rows[y * w + x]) last = y; else if (y - last <= gap) closed[y * w + x] = 1;
    let next = Infinity;
    for (let y = h - 1; y >= 0; y--) if (rows[y * w + x]) next = y; else if (next - y > gap) closed[y * w + x] = 0;
    for (let y = 0; y < h; y++) if (rows[y * w + x]) closed[y * w + x] = 1;
  }
  const minExtent = Math.max(w, h) * 0.04, queue = new Int32Array(w * h), marks = [];
  for (let i = 0; i < closed.length; i++) {
    if (!closed[i]) continue;
    let head = 0, tail = 1, minX = w, maxX = 0, minY = h, maxY = 0, ink = 0, inked = 0;
    queue[0] = i; closed[i] = 0;
    while (head < tail) {
      const p = queue[head++], x = p % w, y = Math.floor(p / w);
      if (mask[p]) { ink += depth[p]; inked++; }
      minX = Math.min(minX, x); maxX = Math.max(maxX, x);
      minY = Math.min(minY, y); maxY = Math.max(maxY, y);
      for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) {
        const nx = x + dx, ny = y + dy, next = ny * w + nx;
        if (nx >= 0 && nx < w && ny >= 0 && ny < h && closed[next]) { closed[next] = 0; queue[tail++] = next; }
      }
    }
    const touchesEdge = minX === 0 || minY === 0 || maxX === w - 1 || maxY === h - 1;
    if (touchesEdge || Math.max(maxX - minX, maxY - minY) + 1 < minExtent) continue;
    marks.push({ strength: ink / inked, bounds: [minX / w, minY / h, (maxX + 1) / w, (maxY + 1) / h].map(v => Number(v.toFixed(3))) });
  }
  const darkest = Math.max(0, ...marks.map(mark => mark.strength));
  const drawn = marks.filter(mark => mark.strength >= Math.max(20, darkest * 0.35))
    .map(({ strength, bounds }) => ({ strength: Math.round(strength), bounds }));
  return { method: 'separate_ink_marks_v2', count: drawn.length ? drawn.length : null, marks: drawn.slice(0, 50) };
}

function pngChunk(type, bytes) {
  const name = Buffer.from(type), size = Buffer.alloc(4), checksum = Buffer.alloc(4);
  size.writeUInt32BE(bytes.length);
  let crc = 0xffffffff;
  for (const value of Buffer.concat([name, bytes])) {
    crc ^= value;
    for (let bit = 0; bit < 8; bit++) crc = (crc >>> 1) ^ (crc & 1 ? 0xedb88320 : 0);
  }
  checksum.writeUInt32BE((crc ^ 0xffffffff) >>> 0);
  return Buffer.concat([size, name, bytes, checksum]);
}

function grayscalePng({ width, height, pixels }, low, high) {
  const header = Buffer.alloc(13), rows = Buffer.alloc((width + 1) * height);
  header.writeUInt32BE(width); header.writeUInt32BE(height, 4); header[8] = 8;
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      // Only global tonal values change; the pixel geometry stays unchanged.
      const normalized = (pixels[y * width + x] - low) / (high - low);
      rows[y * (width + 1) + x + 1] = Math.round(255 * Math.pow(normalized, 0.85));
    }
  }
  return Buffer.concat([Buffer.from([137,80,78,71,13,10,26,10]), pngChunk('IHDR', header), pngChunk('IDAT', deflateSync(rows)), pngChunk('IEND', Buffer.alloc(0))]);
}

export function inspectMotorPng(photo) {
  const width = photo.readUInt32BE(16), height = photo.readUInt32BE(20);
  const base = { status: 'unchecked', width, height, reasons: [], pixelRange: null };
  if (Math.min(width, height) < 160) return { ...base, status: 'retake', reasons: ['Photo is smaller than 160 pixels on one side.'] };
  try {
    const decoded = decodePng(photo);
    if (!decoded) return base;
    const summary = pixelSummary(decoded);
    return { ...base, ...summary, status: summary.pixelRange < 4 ? 'retake' : 'checked', reasons: summary.pixelRange < 4 ? ['Photo has almost no visible contrast. Check that the drawing is visible.'] : [] };
  } catch {
    return { ...base, status: 'retake', reasons: ['Photo pixel data could not be decoded.'] };
  }
}

async function decodeJpeg(photo, binary) {
  return new Promise((resolve, reject) => {
    const process = spawn(binary, ['-nostdin', '-v', 'error', '-threads', '1', '-i', 'pipe:0', '-frames:v', '1', '-vf', 'scale=1280:1280:force_original_aspect_ratio=decrease', '-f', 'image2pipe', '-vcodec', 'png', 'pipe:1'], { stdio: ['pipe', 'pipe', 'ignore'] });
    const chunks = [];
    let bytes = 0;
    const timer = setTimeout(() => { process.kill('SIGKILL'); reject(new Error('Image decoding timed out')); }, 10000);
    process.once('error', reject);
    process.stdout.on('data', chunk => {
      bytes += chunk.length;
      if (bytes > 12 * 1024 * 1024) { process.kill('SIGKILL'); reject(new Error('Decoded image exceeds limit')); }
      else chunks.push(chunk);
    });
    process.stdin.on('error', () => {});
    process.once('close', code => {
      clearTimeout(timer);
      if (code !== 0) reject(new Error('Image decoding unavailable'));
      else resolve(Buffer.concat(chunks));
    });
    process.stdin.end(photo);
  });
}

export async function prepareMotorImage(photo, mime, { ffmpegPath = process.env.FFMPEG_PATH || 'ffmpeg' } = {}) {
  let decodedPhoto = photo;
  if (mime === 'image/jpeg') {
    try { decodedPhoto = await decodeJpeg(photo, ffmpegPath); }
    catch { return { enhanced: null, enhancement: { applied: false, method: 'none', originalPreserved: true, reason: 'Local JPEG enhancement unavailable; original still assessed.' } }; }
  }
  try {
    const decoded = decodePng(decodedPhoto);
    if (!decoded) return { enhanced: null, enhancement: { applied: false, method: 'none', originalPreserved: true } };
    const { low, high, meanLuminance, pixelRange } = pixelSummary(decoded);
    const enhance = (meanLuminance < 110 || pixelRange < 100) && pixelRange >= 4;
    return {
      enhanced: enhance ? grayscalePng(decoded, low, high) : null,
      enhancement: { applied: enhance, method: enhance ? 'global_luminance_stretch_gamma' : 'none', originalPreserved: true },
      lineDetection: detectMotorLines(decoded),
      markCount: countMotorMarks(decoded),
    };
  } catch {
    return { enhanced: null, enhancement: { applied: false, method: 'none', originalPreserved: true } };
  }
}
