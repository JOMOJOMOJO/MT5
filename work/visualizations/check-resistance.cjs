const {chromium}=require('C:/Users/windows/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const path=require('node:path');
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'});
 try{
  const page=await browser.newPage();const errors=[];page.on('pageerror',e=>errors.push(String(e)));
  await page.goto('file:///'+path.resolve('work/visualizations/wave33-resistance-preview.html').replaceAll('\\','/'));
  const frame=page.frameLocator('iframe');
  for(const width of [1024,360]){
   await page.setViewportSize({width,height:950});
   await frame.locator('#wave33-resistance-comparison svg').first().waitFor();
   await page.waitForTimeout(250);
   const state=await frame.locator('#wave33-resistance-comparison').evaluate(root=>({
    width:root.getBoundingClientRect().width,
    svg:[...root.querySelectorAll('svg')].map(s=>({w:s.getBoundingClientRect().width,h:s.getBoundingClientRect().height,labels:[...s.querySelectorAll('text')].map(t=>{const r=t.getBBox();return{text:t.textContent,x:r.x,y:r.y,w:r.width,h:r.height}})})),
    overflow:document.documentElement.scrollWidth>document.documentElement.clientWidth
   }));
   if(state.svg.length!==2||state.overflow)throw Error('Figure missing or overflow');
   for(const s of state.svg)for(const l of s.labels)if(l.x<0||l.x+l.w>s.w+1)throw Error('Clipped label: '+l.text);
   await frame.locator('#wave33-resistance-comparison').screenshot({path:`work/visualizations/resistance-${width}.png`});
   console.log(JSON.stringify({width,diagramWidths:state.svg.map(s=>s.w),overflow:state.overflow}));
  }
  if(errors.length)throw Error(errors.join('\n'));
 }finally{await browser.close()}
})().catch(e=>{console.error(e);process.exitCode=1});
