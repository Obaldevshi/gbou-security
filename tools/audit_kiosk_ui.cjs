// Isolated Chromium UI audit: real kiosk assets, synthetic loopback API only.
// Run with GBOU_PLAYWRIGHT_PATH pointing at the installed Playwright package.
const { chromium } = require(process.env.GBOU_PLAYWRIGHT_PATH || 'playwright');
const fs = require('node:fs/promises');
const path = require('node:path');
const http = require('node:http');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '..');
const output = path.join(root, 'artifacts', 'kiosk-ui-audit');
const assets = new Map([
  ['/', ['index.html', 'text/html']], ['/app.css', ['app.css', 'text/css']],
  ['/app.js', ['app.js', 'text/javascript']], ['/version.js', ['version.js', 'text/javascript']],
]);
const server = http.createServer(async (req, res) => {
  const asset = assets.get(req.url);
  if (!asset) { res.writeHead(404); res.end(); return; }
  res.setHeader('Content-Type', `${asset[1]}; charset=utf-8`);
  res.end(await fs.readFile(path.join(root, 'init-kiosk/web', asset[0])));
});
async function main() {
  await fs.mkdir(output, {recursive: true});
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const origin = `http://127.0.0.1:${server.address().port}`;
  const browser = await chromium.launch({headless: true, channel: 'chrome'});
  const errors = [], checks = [];
  const page = await browser.newPage({viewport: {width:800, height:480}, hasTouch:true});
  let devicePhase = 'idle', queueCalls = 0, releaseCalls = 0;
  let queue = Array.from({length:18}, (_,i) => ({id:i+1,
    student_full_name:`Демонстрационный Ученик ${i+1} Проверочный`, class_name:'1А',
    teacher_full_name:'Вымышленный педагог', reason_type:'parent_note',
    scheduled_at:'2026-10-20T08:00:00Z'}));
  let history = [];
  page.on('pageerror', e => errors.push(e.message));
  await page.route('**/*', async route => {
    const req = route.request(), url = new URL(req.url());
    if (url.origin !== origin) { errors.push('External network attempt blocked'); await route.abort(); return; }
    if (assets.has(url.pathname)) { await route.continue(); return; }
    let data = {}, status=200;
    switch(url.pathname) {
      case '/favicon.ico': status=404; break;
      case '/local/device': data={phase:devicePhase, hostname:'fixture.invalid', message:'Тестовое устройство',
        ...(devicePhase==='qr' ? {code:'123456',qr:Buffer.from('<svg xmlns="http://www.w3.org/2000/svg" width="224" height="224"><rect width="224" height="224" fill="white"/><text x="12" y="115">TEST FIXTURE ONLY</text></svg>').toString('base64')} : {})}; break;
      case '/local/pairing': data={available:false}; break;
      case '/local/version': data={version:await page.evaluate(()=>globalThis.GBOU_KIOSK_UI_VERSION)}; break;
      case '/local/wifi/networks': data={networks:[{ssid:'Тестовая сеть',signal:80,secure:true,active:true}]}; break;
      case '/api/login':
        if (req.postDataJSON().login!=='guard.demo') {status=403;data={message:'Разрешён только вход охранника'};}
        else data={data:{access_token:'synthetic-ui-only',user:{role:'guard',full_name:'Тестовый пост'}}}; break;
      case '/api/queue': queueCalls++; data={data:queue}; break;
      case '/api/history': data={data:history}; break;
      default:
        if (/^\/api\/requests\/\d+\/release$/.test(url.pathname)) {
          releaseCalls++; const id=Number(url.pathname.split('/')[3]);
          history.push({...queue.find(q=>q.id===id),released_at:'2026-10-20T08:01:00Z'});
          queue=queue.filter(q=>q.id!==id); data={data:{}};
        } else {status=404; errors.push(`Unexpected fixture endpoint: ${url.pathname}`);}
    }
    await route.fulfill({status,contentType:'application/json',body:JSON.stringify(data)});
  });
  const visible = async selector => page.locator(selector).waitFor({state:'visible'});
  const shot = async name => {await page.screenshot({path:path.join(output,`${name}.png`)});checks.push(name);};
  const noPageScroll = async () => assert(await page.evaluate(()=>document.documentElement.scrollHeight<=innerHeight), 'No page scrollbar on login');
  const keyboardHidden = async () => assert(await page.locator('#keyboard').isHidden(),'Field focus must not open keyboard');
  const aboveKeyboard = async selector => {
    const a=await page.locator(selector).boundingBox(), k=await page.locator('#keyboard').boundingBox();
    assert(a && k && a.y+a.height<=k.y+1,`${selector} must stay above keyboard`);
  };
  try {
    await page.goto(origin); await noPageScroll(); await shot('01-login-800x480');
    await page.locator('#password').click(); await keyboardHidden();
    await page.locator('#keyboard-toggle').click(); await visible('#keyboard');
    await page.getByRole('button',{name:'а',exact:true}).click();
    assert.equal(await page.locator('#password').inputValue(),'а');
    await page.getByRole('button',{name:'Символы',exact:true}).click();
    await page.getByRole('button',{name:'!',exact:true}).click();
    assert.equal(await page.locator('#password').inputValue(),'а!');
    await page.getByRole('button',{name:'Символы',exact:true}).click();
    await aboveKeyboard('#password'); await aboveKeyboard('#login-button');
    await shot('02-password-keyboard-manual');
    await page.getByRole('button',{name:'Скрыть',exact:true}).click();
    await page.locator('#login').click(); await keyboardHidden(); await noPageScroll();
    await page.locator('#wifi-open').click(); await page.locator('#wifi-password').click();
    await keyboardHidden(); await page.locator('#keyboard-toggle').click();
    await page.getByRole('button',{name:'б',exact:true}).click();
    assert.equal(await page.locator('#wifi-password').inputValue(),'б');
    await aboveKeyboard('#wifi-password'); await shot('03-wifi-manual-keyboard');
    await page.keyboard.press('Escape'); await keyboardHidden();
    await page.locator('#wifi-close').click();
    await page.locator('#device-open').click(); await visible('#device-form');
    await page.locator('#device-password').click(); await keyboardHidden();
    await page.locator('#keyboard-toggle').click();
    await page.getByRole('button',{name:'в',exact:true}).click();
    assert.equal(await page.locator('#device-password').inputValue(),'в');
    await aboveKeyboard('#device-password'); await shot('04-device-manual-keyboard');
    await page.locator('#keyboard-toggle').click(); await keyboardHidden();
    await page.locator('#device-close').click();
    await page.locator('#login').fill('teacher.demo'); await page.locator('#password').fill('fixture');
    await page.locator('#login-button').click(); await page.locator('#login-error').filter({hasText:'только'}).waitFor();
    await page.locator('#login').fill('guard.demo'); await page.locator('#login-button').click();
    await visible('#guard-view'); await page.locator('.request-card').first().waitFor();
    await shot('05-guard-queue');
    const before=queueCalls; await page.waitForTimeout(3400); assert(queueCalls>before,'Automatic 3-second refresh');
    const start=await page.locator('#guard-view').evaluate(e=>e.scrollTop);
    await page.mouse.move(120,395); await page.mouse.down();
    await page.mouse.move(120,245,{steps:10}); await page.mouse.up();
    assert(await page.locator('#guard-view').evaluate(e=>e.scrollTop)>start,'Finger drag scrolls queue');
    await page.locator('#guard-view').evaluate(e=>e.scrollTop=0);
    const cdp=await page.context().newCDPSession(page);
    await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x:150,y:395}]});
    for (let y=380;y>=245;y-=15) await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x:150,y}]});
    await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
    assert(await page.locator('#guard-view').evaluate(e=>e.scrollTop)>0,'Touch drag scrolls queue');
    await page.locator('#guard-view').evaluate(e=>e.scrollTop=0);
    await page.locator('.release').first().click(); assert.equal(releaseCalls,1);
    await page.waitForFunction(()=>document.querySelectorAll('.request-card').length===17);
    await page.locator('[data-tab="history"]').click(); await page.getByText('Выпущен',{exact:false}).waitFor();
    await shot('06-release-history');
    await page.locator('#logout').click(); await noPageScroll();
    devicePhase='qr'; await page.locator('#device-open').click(); await visible('#device-qr');
    await shot('07-qr-fixture-800x480');
    await page.locator('#device-close').click();
    await page.setViewportSize({width:1024,height:600}); await noPageScroll(); await shot('08-login-1024x600');
    assert.deepEqual(errors,[]);
    await fs.writeFile(path.join(output,'report.json'),JSON.stringify({checks,queueCalls,releaseCalls,errors,synthetic:true},null,2));
    console.log(JSON.stringify({passed:checks.length,queueCalls,releaseCalls,synthetic:true}));
  } finally {await browser.close(); server.close();}
}
main().catch(e=>{console.error(e);server.close();process.exitCode=1;});
