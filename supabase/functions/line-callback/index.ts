// Edge Function: line-callback
// หน้าที่: เป็น "สะพาน" รับ code จาก LINE (ผ่าน https)
//         แล้วเด้งกลับเข้าแอปมือถือด้วย custom scheme (waterapp://)
//
// เหตุผลที่ต้องมี: LINE ยอมรับเฉพาะ Callback URL แบบ https
// แต่แอปมือถือดักจับได้เฉพาะ custom scheme
//
// วิธีที่ใช้: ส่ง HTTP 302 redirect ตรงๆ
// เพราะฝั่งแอปใช้ Chrome Auth Tab ซึ่งคอยดักการ redirect ไป scheme นี้อยู่แล้ว
// พอเจอมันจะปิดแท็บเองแล้วส่งค่ากลับแอปทันที (ไม่ต้องพึ่ง JavaScript)

Deno.serve((req) => {
  const url = new URL(req.url);

  // รับค่าที่ LINE ส่งกลับมา
  const code = url.searchParams.get('code');
  const state = url.searchParams.get('state');
  const error = url.searchParams.get('error');

  // สร้าง URL ที่จะเด้งกลับเข้าแอป
  const redirect = new URL('waterapp://callback');

  if (error) {
    redirect.searchParams.set('error', error);
  } else if (code) {
    redirect.searchParams.set('code', code);
    if (state) redirect.searchParams.set('state', state);
  } else {
    redirect.searchParams.set('error', 'no_code');
  }

  // 302 -> Auth Tab จับได้แล้วปิดแท็บเอง
  return new Response(null, {
    status: 302,
    headers: {
      Location: redirect.toString(),
      'Cache-Control': 'no-store',
    },
  });
});