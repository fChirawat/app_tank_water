// ============================================
//  สคริปต์ทดสอบโหลด (Load Test)
//  จำลอง "คนหลายคนเปิดแอปพร้อมกัน" ยิงเข้า Edge Function จริง
//  แล้ววัดว่ารับได้กี่คนก่อนช้า/ล่ม
//
//  ยิงแค่ action อ่าน (ไม่สร้างข้อมูลขยะ ไม่กระทบข้อมูลจริง)
//
//  วิธีรัน:  node loadtest.mjs
// ============================================

// ----- ตั้งค่า -----
const SUPABASE_URL = 'https://qyvgtiotpgqucnrblwen.supabase.co';
const PUBLISHABLE_KEY = 'sb_publishable_ME27_NmPRnOT3Vc1o3PLwQ_rl5bg_49';

// endpoint ที่จะยิง (complaints + action me = คนเรียกตอนเปิดแอป)
const ENDPOINT = `${SUPABASE_URL}/functions/v1/complaints`;

// จำนวนคนที่จะจำลอง (ค่อยๆ เพิ่มทีละระดับ)
const LEVELS = [50, 100, 200, 350, 500, 750, 1000];

// ยิงกี่รอบต่อระดับ (เอาค่าเฉลี่ย)
const ROUNDS = 3;
// ----------------------

// ยิง 1 คำขอ วัดเวลา
async function oneRequest() {
  const start = Date.now();
  try {
    const res = await fetch(ENDPOINT, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${PUBLISHABLE_KEY}`,
        'apikey': PUBLISHABLE_KEY,
      },
      // ส่ง token ปลอม -> server จะตอบว่า auth ไม่ผ่าน
      // แต่เราวัดแค่ "server ตอบเร็วแค่ไหน" ไม่ได้สนว่าผ่านไหม
      body: JSON.stringify({ accessToken: 'loadtest-fake', action: 'me' }),
    });
    const ms = Date.now() - start;
    return { ok: res.status < 500, status: res.status, ms };
  } catch (e) {
    return { ok: false, status: 0, ms: Date.now() - start, err: String(e) };
  }
}

// ยิงพร้อมกัน N คำขอ
async function burst(n) {
  const jobs = [];
  for (let i = 0; i < n; i++) jobs.push(oneRequest());
  const results = await Promise.all(jobs);

  const times = results.map((r) => r.ms).sort((a, b) => a - b);
  const okCount = results.filter((r) => r.ok).length;
  const failCount = n - okCount;

  const avg = Math.round(times.reduce((s, t) => s + t, 0) / n);
  const min = times[0];
  const max = times[times.length - 1];
  // p95 = 95% ของคำขอเร็วกว่านี้ (ตัวชี้วัดประสบการณ์แย่สุดที่คนส่วนใหญ่เจอ)
  const p95 = times[Math.floor(n * 0.95)] ?? max;

  return { okCount, failCount, avg, min, max, p95 };
}

// รันหลายรอบต่อระดับ เอาค่าเฉลี่ย
async function testLevel(n) {
  let totalAvg = 0, totalP95 = 0, totalFail = 0, totalMax = 0;

  for (let r = 0; r < ROUNDS; r++) {
    const res = await burst(n);
    totalAvg += res.avg;
    totalP95 += res.p95;
    totalFail += res.failCount;
    totalMax = Math.max(totalMax, res.max);
    // พักสั้นๆ ระหว่างรอบ ไม่ให้ถูกมองว่าโจมตี
    await new Promise((r) => setTimeout(r, 800));
  }

  return {
    n,
    avgMs: Math.round(totalAvg / ROUNDS),
    p95Ms: Math.round(totalP95 / ROUNDS),
    maxMs: totalMax,
    failTotal: totalFail,
  };
}

// ===== เริ่มทดสอบ =====
console.log('='.repeat(60));
console.log('  ทดสอบโหลด: จำลองคนเปิดแอปพร้อมกัน');
console.log('  endpoint:', ENDPOINT);
console.log('='.repeat(60));
console.log('');

// อุ่นเครื่องก่อน (ปลุก server ให้ตื่น = ตัด cold start ออก)
process.stdout.write('อุ่นเครื่อง server ก่อน... ');
await oneRequest();
await new Promise((r) => setTimeout(r, 1500));
console.log('พร้อม');
console.log('');

console.log('คน   | เฉลี่ย   | p95      | ช้าสุด   | ล้มเหลว | สรุป');
console.log('-'.repeat(60));

for (const level of LEVELS) {
  const r = await testLevel(level);

  // ประเมินผล
  let verdict;
  if (r.failTotal > 0) verdict = '❌ เริ่มมีล้มเหลว';
  else if (r.p95Ms > 3000) verdict = '⚠️ ช้ามาก (>3วิ)';
  else if (r.p95Ms > 1500) verdict = '🟡 เริ่มช้า';
  else verdict = '✅ ลื่น';

  console.log(
    `${String(r.n).padStart(4)} | ` +
    `${String(r.avgMs).padStart(5)}ms | ` +
    `${String(r.p95Ms).padStart(5)}ms | ` +
    `${String(r.maxMs).padStart(5)}ms | ` +
    `${String(r.failTotal).padStart(6)} | ${verdict}`
  );

  // ถ้าเริ่มพังเยอะมาก (เกินครึ่ง) ค่อยหยุด
  if (r.failTotal > level * 0.5) {
    console.log('');
    console.log('>> หยุดทดสอบ: ระดับนี้ล้มเหลวเกิน 50% แล้ว (เจอเพดานแล้ว)');
    break;
  }
}

console.log('-'.repeat(60));
console.log('');
console.log('อ่านผล:');
console.log('  • เฉลี่ย = เวลาตอบเฉลี่ยทุกคำขอ');
console.log('  • p95    = 95% ของคนได้เร็วกว่านี้ (คนส่วนใหญ่เจอ)');
console.log('  • ล้มเหลว = คำขอที่ server ตอบ error 500+ หรือ timeout');
console.log('');
console.log('เกณฑ์คร่าวๆ:');
console.log('  ✅ p95 < 1.5วิ = ลื่น ใช้งานดี');
console.log('  🟡 p95 1.5-3วิ = เริ่มช้า แต่ยังใช้ได้');
console.log('  ⚠️ p95 > 3วิ   = ช้าจนน่ารำคาญ');
console.log('  ❌ มีล้มเหลว    = เกินที่ server รับไหว');
console.log('');
console.log('เลข "คน" ที่ยังเขียว ✅ = จำนวนที่กดพร้อมกันได้สบาย');
