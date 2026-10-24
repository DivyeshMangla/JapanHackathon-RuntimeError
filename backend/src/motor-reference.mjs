import { deflateSync } from 'node:zlib';

const references = new WeakMap();
const width = 600;
const height = 400;

function crc32(bytes) {
  let crc = 0xffffffff;
  for (const byte of bytes) {
    crc ^= byte;
    for (let bit = 0; bit < 8; bit++)
      crc = (crc >>> 1) ^ (crc & 1 ? 0xedb88320 : 0);
  }
  return (crc ^ 0xffffffff) >>> 0;
}

function chunk(type, bytes) {
  const name = Buffer.from(type);
  const length = Buffer.alloc(4);
  length.writeUInt32BE(bytes.length);
  const checksum = Buffer.alloc(4);
  checksum.writeUInt32BE(crc32(Buffer.concat([name, bytes])));
  return Buffer.concat([length, name, bytes, checksum]);
}

// A fixed reference image gives the vision model the same shapes as the guide.
export function motorReference(exercise) {
  const cached = references.get(exercise);
  if (cached) return cached;
  const pixels = Buffer.alloc((width + 1) * height, 255);
  for (let y = 0; y < height; y++) pixels[y * (width + 1)] = 0;
  const strokes = exercise.id === 'motor-letter'
    ? [0, 1, 2].flatMap(column => exercise.strokes.map(stroke =>
      stroke.map(([x, y]) => [(x - 0.3) * 0.3 + 0.12 + column * 0.31, y])))
    : exercise.strokes;
  const dot = (x, y) => {
    for (let dy = -3; dy <= 3; dy++) {
      for (let dx = -3; dx <= 3; dx++) {
        const px = Math.round(x) + dx, py = Math.round(y) + dy;
        if (dx * dx + dy * dy <= 9 && px >= 0 && px < width && py >= 0 && py < height)
          pixels[py * (width + 1) + px + 1] = 0;
      }
    }
  };
  for (const stroke of strokes) {
    for (let i = 1; i < stroke.length; i++) {
      const [x0, y0] = stroke[i - 1].map((v, axis) => v * (axis ? height : width));
      const [x1, y1] = stroke[i].map((v, axis) => v * (axis ? height : width));
      const steps = Math.max(1, Math.ceil(Math.max(Math.abs(x1 - x0), Math.abs(y1 - y0))));
      for (let step = 0; step <= steps; step++) {
        const t = step / steps;
        dot(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t);
      }
    }
  }
  const header = Buffer.alloc(13);
  header.writeUInt32BE(width, 0);
  header.writeUInt32BE(height, 4);
  header[8] = 8;
  const png = Buffer.concat([
    Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    chunk('IHDR', header), chunk('IDAT', deflateSync(pixels)), chunk('IEND', Buffer.alloc(0)),
  ]);
  references.set(exercise, png);
  return png;
}
