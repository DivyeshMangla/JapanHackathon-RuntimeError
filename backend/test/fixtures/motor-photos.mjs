import { deflateSync } from 'node:zlib';

function chunk(type, bytes) {
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

export function drawingPhoto({ background = 240, ink = 20 } = {}) {
  const width = 320, height = 240, header = Buffer.alloc(13);
  header.writeUInt32BE(width); header.writeUInt32BE(height, 4); header[8] = 8;
  const rows = Buffer.alloc((width + 1) * height, background);
  for (let y = 0; y < height; y++) {
    rows[y * (width + 1)] = 0;
    if ([60, 61, 120, 121, 180, 181].includes(y)) rows.fill(ink, y * (width + 1) + 40, y * (width + 1) + 280);
  }
  return Buffer.concat([Buffer.from([137,80,78,71,13,10,26,10]), chunk('IHDR', header), chunk('IDAT', deflateSync(rows)), chunk('IEND', Buffer.alloc(0))]);
}
