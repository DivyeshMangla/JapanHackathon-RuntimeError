// Synthetic tones exercise transport and capture gates only; they are not
// speech and cannot validate recognition or clinical assessment accuracy.
export function toneWav({ sampleRate = 16000, duration = 0.5, amplitude = 0.2, clipped = false } = {}) {
  const samples = Math.round(sampleRate * duration);
  const wav = Buffer.alloc(44 + samples * 2);
  wav.write('RIFF'); wav.writeUInt32LE(wav.length - 8, 4); wav.write('WAVE', 8);
  wav.write('fmt ', 12); wav.writeUInt32LE(16, 16); wav.writeUInt16LE(1, 20); wav.writeUInt16LE(1, 22);
  wav.writeUInt32LE(sampleRate, 24); wav.writeUInt32LE(sampleRate * 2, 28); wav.writeUInt16LE(2, 32); wav.writeUInt16LE(16, 34);
  wav.write('data', 36); wav.writeUInt32LE(samples * 2, 40);
  for (let sample = 0; sample < samples; sample++) wav.writeInt16LE(clipped ? (sample % 2 ? 32767 : -32768) : Math.round(Math.sin(sample * 2 * Math.PI * 300 / sampleRate) * amplitude * 32767), 44 + sample * 2);
  return wav;
}
