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
    const enhance = meanLuminance < 110 && pixelRange >= 4;
    return {
      enhanced: enhance ? grayscalePng(decoded, low, high) : null,
      enhancement: { applied: enhance, method: enhance ? 'global_luminance_stretch_gamma' : 'none', originalPreserved: true },
    };
  } catch {
    return { enhanced: null, enhancement: { applied: false, method: 'none', originalPreserved: true } };
  }
}
