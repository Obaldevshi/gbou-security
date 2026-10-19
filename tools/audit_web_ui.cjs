// Render the isolated web_visual_main.dart build, never a production session.
const {chromium}=require(process.env.GBOU_PLAYWRIGHT_PATH || 'playwright');
const fs=require('node:fs/promises'),path=require('node:path'),http=require('node:http');
const assert=require('node:assert/strict');
const root=path.resolve(__dirname,'..'), build=path.join(root,'release/qa-web');
const output=path.join(root,'artifacts/web-ui-audit');
const mime={'.html':'text/html','.js':'text/javascript','.json':'application/json','.wasm':'application/wasm','.css':'text/css','.svg':'image/svg+xml','.otf':'font/otf','.ttf':'font/ttf','.png':'image/png'};
const server=http.createServer(async(req,res)=>{
  const requested=decodeURIComponent(new URL(req.url,'http://localhost').pathname);
  const target=path.resolve(build,'.'+(requested==='/'?'/index.html':requested));
  if(!target.startsWith(build+path.sep)){res.writeHead(403);res.end();return;}
  try{const bytes=await fs.readFile(target);res.setHeader('Content-Type',mime[path.extname(target)]||'application/octet-stream');res.end(bytes);}
  catch{res.writeHead(404);res.end();}
});
async function main(){
  await fs.mkdir(output,{recursive:true});
  await new Promise(r=>server.listen(0,'127.0.0.1',r));
  const origin=`http://127.0.0.1:${server.address().port}`;
  const browser=await chromium.launch({channel:'chrome',headless:true});
  const errors=[],shots=[],blockedFonts=[];let currentCase='startup';
  const context=await browser.newContext();
  const page=await context.newPage();
  page.on('pageerror',e=>errors.push(e.stack||e.message));
  page.on('console',m=>{if(m.type()==='error' && /overflowed|EXCEPTION CAUGHT|Error:/.test(m.text()))errors.push(currentCase+': '+m.text().slice(0,6000));});
  await page.route('**/*',async r=>{
    if(new URL(r.request().url()).origin!==origin){
      const url=new URL(r.request().url());
      if(url.hostname==='fonts.gstatic.com')blockedFonts.push(url.pathname);
      else errors.push('External request blocked: '+url.origin+url.pathname);
      await r.abort();
    }
    else await r.continue();
  });
  async function open(role,route,width,height,dark=false){
    currentCase=`${width}x${height} ${role} ${route}`;
    await page.setViewportSize({width,height});
    await page.goto(`${origin}/?auditRole=${role}&dark=${dark?'1':'0'}#${route}`);
    await page.locator('flutter-view').waitFor({timeout:90000});
    const placeholder=page.locator('flt-semantics-placeholder');
    await placeholder.or(page.getByRole('button').first()).first().waitFor({state:'attached',timeout:60000});
    if(await placeholder.count())await placeholder.evaluate(e=>e.click());
    await page.getByRole('button').first().waitFor({timeout:60000});
    await page.waitForTimeout(1800);
  }
  async function shot(name){await page.screenshot({path:path.join(output,`${name}.png`)});shots.push(name);assert.deepEqual(errors,[]);}
  try{
    for(const [width,height] of [[390,844],[800,480],[1440,900]]){
      for(const [role,route] of [['','/login'],['teacher.demo','/teacher/request'],['guard.demo','/guard/queue'],['school.admin','/school/students'],['superadmin','/system/schools']]){
        await open(role,route,width,height);await shot(`${width}-${role||'login'}`);
      }
    }
    await open('teacher.demo','/teacher/request',390,844);
    await page.getByRole('button',{name:/Выберите учеников/}).click();
    const done=page.getByRole('button',{name:/Готово · выбрано/});await done.waitFor();
    await page.getByRole('button',{name:'Выбрать всех',exact:true}).click();
    await shot('mobile-picker-35');
    await done.click();
    await open('teacher.demo','/teacher/students',390,844);
    const add=page.getByRole('button',{name:'Добавить ученика',exact:true});
    await add.click();await page.getByText('Новый ученик',{exact:true}).waitFor();
    await shot('mobile-add-student');
    await open('teacher.demo','/teacher/request',390,844,true);await shot('mobile-teacher-dark');
    assert.deepEqual(errors,[]);
    await fs.writeFile(path.join(output,'report.json'),JSON.stringify({shots,errors,blockedFonts,synthetic:true},null,2));
    console.log(JSON.stringify({passed:shots.length,synthetic:true}));
  }catch(e){
    await page.screenshot({path:path.join(output,'failure.png')});
    console.error(JSON.stringify({errors,dom:(await page.locator('body').innerHTML()).slice(-3500)}));
    throw e;
  }finally{await browser.close();server.close();}
}
main().catch(e=>{console.error(e);server.close();process.exitCode=1;});
