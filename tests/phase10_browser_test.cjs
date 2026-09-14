// Targeted production-artifact QA; reuse Playwright, no new test framework.
const {chromium} = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const http = require('node:http');
const path = require('node:path');
const root = path.resolve(process.env.PHASE10_SITE || '_site');
const base = process.env.PHASE10_BASEURL || '';
const routes = ['/', '/research/', '/research/cooperative/', '/team/', '/about/', '/info/', '/legal/', '/privacy/', '/accessibility/', '/projects/tirrex/', '/news/ieee-iv-2025/', '/publications/'];
const staging = process.env.ASTRA_BUILD_CONTEXT === 'staging' || (!process.env.ASTRA_BUILD_CONTEXT && !!base);
const analytics = /googletagmanager|google-analytics|analytics\.google|cdn\.panelbear\.com|\bgtag\b/i;
const mime = {'.html':'text/html','.css':'text/css','.js':'application/javascript','.png':'image/png','.jpg':'image/jpeg','.webp':'image/webp','.svg':'image/svg+xml'};
const server = http.createServer((req,res)=>{
  let url = decodeURIComponent(new URL(req.url,'http://localhost').pathname);
  if(base && !(url === base || url.startsWith(base+'/'))){res.writeHead(404).end();return;}
  url=url.slice(base.length);
  let file=path.resolve(root,'.'+url);
  if(file!==root&&!file.startsWith(root+path.sep)){res.writeHead(403).end();return;}
  if(fs.existsSync(file)&&fs.statSync(file).isDirectory())file=path.join(file,'index.html');
  if(!fs.existsSync(file)){res.writeHead(404).end();return;}
  res.setHeader('Content-Type',mime[path.extname(file)]||'application/octet-stream');
  fs.createReadStream(file).pipe(res);
});
(async()=>{
  await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  const origin='http://127.0.0.1:'+server.address().port;
  const browser=await chromium.launch({executablePath:process.env.CHROMIUM_EXECUTABLE,headless:true,args:['--no-sandbox']});
  const context=await browser.newContext(); const page=await context.newPage();
  const hosts=new Set();
  const requests=[]; context.on('request',r=>{hosts.add(new URL(r.url()).hostname);if(analytics.test(r.url()))requests.push(r.url());});
  async function containment(){
    const result=await page.evaluate(()=>{
      const cards=[...document.querySelectorAll('.astra-home .astra-research-card')];
      const rects=cards.map(e=>e.getBoundingClientRect());
      const childrenContained=cards.every((e,i)=>[...e.children].every(c=>{const r=c.getBoundingClientRect();return r.bottom<=rects[i].bottom+1&&r.right<=rects[i].right+1&&r.left>=rects[i].left-1;}));
      const aligned=rects.every((r,i)=>rects.every((s,j)=>Math.abs(r.top-s.top)>1||Math.abs(r.bottom-s.bottom)<1));
      const next=document.querySelector('.astra-research-grid + p').getBoundingClientRect();
      const grid=document.querySelector('.astra-research-grid').getBoundingClientRect();
      const news=document.querySelector('.astra-news').getBoundingClientRect();
      return {count:cards.length,childrenContained,aligned,gap:next.top-grid.bottom,newsGap:news.top-next.bottom,clipping:cards.some(e=>['hidden','clip'].includes(getComputedStyle(e).overflowY)),summary:cards[3].querySelector('p').textContent};
    });
    assert.equal(result.count,4);assert.ok(result.childrenContained,JSON.stringify(result));assert.ok(result.aligned);
    assert.ok(result.gap>=16);assert.ok(result.newsGap>=16);assert.equal(result.clipping,false);return result;
  }
  try{
    for(const width of [1440,1024,768,390,320]){
      await page.setViewportSize({width,height:1000});
      for(const route of routes){
        const response=await page.goto(origin+base+route,{waitUntil:'networkidle'});
        assert.equal(response.status(),200);
        await page.waitForTimeout(200); // Observe requests after initial render as well.
        assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth),false);
        assert.equal(await page.locator('link[rel="canonical"]').count(),1);
        assert.equal(await page.locator('link[rel="canonical"]').getAttribute('href'),'https://astra-team.github.io'+(route==='/info/'?'/about/':route));
        assert.deepEqual(await page.locator('meta[name="robots"]').evaluateAll(nodes=>nodes.map(n=>n.content)),staging?['noindex, follow']:[]);
        assert.equal(await page.locator('.astra-footer-links a').count(),3);
        const footer = await page.locator('footer').boundingBox();
        assert.ok(footer.height < 200, 'Footer should remain compact');
        if(['/legal/','/privacy/','/accessibility/'].includes(route)){
          assert.equal(await page.locator('.astra-legal h1').count(),1);
          assert.ok(await page.locator('.astra-legal p').first().evaluate(e=>parseFloat(getComputedStyle(e).fontSize)>=16));
        }
        assert.equal(requests.length,0,'Analytics request detected');
        assert.deepEqual((await context.cookies()).filter(c=>/^_ga(?:_|$)|^_gid$|^_gat/.test(c.name)),[]);
        const storage=await page.evaluate(()=>({local:Object.keys(localStorage),session:Object.keys(sessionStorage)}));
        assert.equal([...storage.local,...storage.session].some(k=>/_ga|gtag|analytics/i.test(k)),false);
        if(route==='/'){
          await page.locator('.astra-research-card').last().scrollIntoViewIfNeeded();
          await page.waitForFunction(()=>{const i=document.querySelector('.astra-research-card:last-child img');return i.complete&&i.naturalWidth>0;});
          assert.equal(await page.locator('.astra-research-card > p').count(),4);
          await containment();
          if(process.env.PHASE10_SCREENSHOTS)await page.screenshot({path:path.join(process.env.PHASE10_SCREENSHOTS,'cards-'+width+'.png')});
          if(process.env.PHASE10_SCREENSHOTS){
            await page.locator('footer').scrollIntoViewIfNeeded();
            await page.screenshot({path:path.join(process.env.PHASE10_SCREENSHOTS,'footer-'+width+'.png')});
          }
          // Stress longer content without editing the repository or accepted copy.
          await page.locator('.astra-research-card').last().evaluate(e=>{for(const s of ['h3','p'])e.querySelector(s).textContent+=' '+e.querySelector(s).textContent;});
          await containment();
        }else if(process.env.PHASE10_SCREENSHOTS){
          await page.screenshot({path:path.join(process.env.PHASE10_SCREENSHOTS,route.replaceAll('/','_')+'-'+width+'.png'),fullPage:['/legal/','/privacy/','/accessibility/','/about/','/info/'].includes(route)});
        }
        console.log('PASS '+base+route+' '+width+'px; GA requests/cookies=0; storage='+JSON.stringify(storage));
      }
    }
    console.log('Observed request hosts: '+[...hosts].sort().join(', '));
    console.log('Final fresh-context cookies: '+JSON.stringify((await context.cookies()).map(c=>({name:c.name,domain:c.domain}))));
  }finally{await browser.close();await new Promise(resolve=>server.close(resolve));}
})().catch(e=>{console.error(e);server.close();process.exitCode=1;});
