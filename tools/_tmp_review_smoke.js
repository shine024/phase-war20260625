// 审查页 v2（家族制·统一ID）交互冒烟：迁移/标注/持久化/导出/筛选/视角切换
const { chromium } = require('playwright');
const path = require('path');

(async () => {
  const browser = await chromium.launch();
  const ctx = await browser.newContext({ acceptDownloads: true });
  const page = await ctx.newPage();
  const errors = [];
  page.on('pageerror', e => errors.push('pageerror: ' + e.message));
  page.on('console', m => { if (m.type() === 'error') errors.push('console: ' + m.text()); });
  page.on('dialog', d => d.accept());

  // 预置 v1 旧标注（验证自动迁移：敌/我/平台 三种来源键）
  await page.addInitScript(() => {
    localStorage.setItem('card_anim_review_marks_v1', JSON.stringify({
      'enemies|foe_ww1_arm_rolls': { p: ['face'], r: 'yes', n: '旧敌标注' },
      'players|ww2_t34_85': { p: ['bg'], r: '', n: 't34身份疑点' },
      'platforms|void_mage_basic': { p: ['other'], r: 'no', n: '' },
      'captured|drop_smg_mk2': { p: ['clip'], r: 'yes', n: '旧缴获标注' },
      'platforms|void_mage_advanced': { p: ['other'], r: 'no', n: '补卡图' },
      'players|mod_air_apache_e': { p: [], r: 'no', n: '', a: 'alt:mod_arm_m1a1' },
    }));
  });

  const url = 'file:///' + path.resolve(__dirname, 'card_anim_review.html').replace(/\\/g, '/');
  await page.goto(url);
  await page.waitForTimeout(900);

  const t = async (name, fn) => {
    try { const v = await fn(); console.log('PASS', name, v === undefined ? '' : JSON.stringify(v)); }
    catch (e) { console.log('FAIL', name, e.message.slice(0, 200)); process.exitCode = 1; }
  };

  await t('rev columns = 209', async () => {
    const n = await page.locator('.card .rev').count();
    if (n !== 209) throw new Error('got ' + n); return n;
  });
  await t('rev column = rsel+rnote only, no pb/okb', async () => {
    const pb = await page.locator('.pb').count();
    const okb = await page.locator('.okb').count();
    const rsel = await page.locator('.rsel').count();
    const rnote = await page.locator('.rnote').count();
    if (pb !== 0 || okb !== 0) throw new Error('pb=' + pb + ' okb=' + okb);
    if (rsel !== 209 || rnote !== 209) throw new Error('rsel=' + rsel + ' rnote=' + rnote);
    const nopts = await page.locator('#selMark option').count();
    if (nopts !== 4) throw new Error('selMark options=' + nopts); // 全部/已标记/需重做/不重做
    return 'ok';
  });
  await t('fam cards = 140 with dual icons', async () => {
    const n = await page.locator('.card[data-sec="fam"]').count();
    if (n !== 140) throw new Error('fam=' + n);
    const dual = await page.locator('.card[data-sec="fam"] .icons .icon').count();
    if (dual !== 280) throw new Error('icons=' + dual);
    return dual / 2;
  });
  await t('migration: enemy key → fam', async () => {
    const c = page.locator('.card[data-key="fam|ww1_arm_rolls"]');
    const r = await c.locator('.rsel').inputValue();
    const n = await c.locator('.rnote').inputValue();
    const marked = await c.getAttribute('data-marked');
    if (r !== 'yes' || n !== '旧敌标注' || marked !== '1') throw new Error('r=' + r + ' n=' + n + ' marked=' + marked);
    return 'ok';
  });
  await t('migration: player t34_85 → sherman fam', async () => {
    const marked = await page.locator('.card[data-key="fam|ww2_arm_sherman"]').getAttribute('data-marked');
    if (marked !== '1') throw new Error('marked=' + marked);
    return 'ok';
  });
  await t('migration: captured drop → drop sec', async () => {
    const marked = await page.locator('.card[data-key="drop|drop_smg_mk2"]').getAttribute('data-marked');
    if (marked !== '1') throw new Error('marked=' + marked);
    return 'ok';
  });
  await t('migration: r=no 删除、a 拍板壳保留', async () => {
    const vm = await page.locator('.card[data-key="plat|void_mage_advanced"]').getAttribute('data-marked');
    if (vm === '1') throw new Error('r=no 未删除 marked=' + vm);
    const ap = await page.locator('.card[data-key="fam|mod_air_apache_e"]').getAttribute('data-marked');
    if (ap !== '1') throw new Error('a 壳丢失 marked=' + ap);
    const stored = await page.evaluate(() => localStorage.getItem('card_anim_review_marks_v3'));
    if (stored !== null) throw new Error('旧 v2 键未清除');
    return 'ok';
  });
  await t('mark chips: 与烘入标注一致', async () => {
    await page.waitForTimeout(300);
    const seed = require('./card_anim_review_marks (要修改的).json').marks;
    // v1 夹具迁移键优先于 seed；合并总数 = seed + 迁移存活且 seed 没有的键（r=no 无 a 的被删）
    const survive = ['fam|ww1_arm_rolls', 'fam|ww2_arm_sherman', 'drop|drop_smg_mk2', 'fam|mod_air_apache_e']; // void_mage_advanced r=no 无 a → 已删
    const expect = Object.keys(seed).length + survive.filter(k => !seed[k]).length;
    const txt = await page.locator('#markIssues').textContent();
    const m = txt.match(/已标记\s*(\d+)/);
    if (!m || +m[1] !== expect) throw new Error(txt.slice(0, 160));
    if (/undefined/.test(txt)) throw new Error('chip 出现 undefined: ' + txt.slice(0, 160));
    return 'marked=' + expect;
  });
  await t('sus chips present', async () => page.locator('.chip.sus').count());

  // ── 家族卡视角切换 ──
  await t('flip toggle 我→敌', async () => {
    const c = page.locator('.card[data-key="fam|ww1_arm_rolls"]');
    const fb = c.locator('.flipb');
    await fb.click();
    const after = await fb.textContent();
    if (!after.includes('视角:敌')) throw new Error(after);
    await fb.click(); // 复原
    return after;
  });

  // ── 新标注 + 持久化 ──（烘入标注可能已含该卡状态：先读现值再定向操作，勿盲点）
  await t('mark on ind card persists', async () => {
    const c = page.locator('.card[data-key="ind|ww1_lanchest"]');
    const r0 = await c.locator('.rsel').inputValue();
    if (r0 !== 'yes') await c.locator('.rsel').selectOption('yes');
    await page.reload(); await page.waitForTimeout(900);
    const c2 = page.locator('.card[data-key="ind|ww1_lanchest"]');
    const r = await c2.locator('.rsel').inputValue();
    if (r !== 'yes') throw new Error('r=' + r);
    return 'ok';
  });

  // ── 筛选 ──（预期从顶栏 chips 实读，不写死数字）
  await t('filter redo matches chip count', async () => {
    const txt = await page.locator('#markIssues').textContent();
    const want = +(txt.match(/需重做\s*(\d+)/) || [])[1];
    await page.locator('#selMark').selectOption('redo');
    const n = await page.locator('.card:not(.hidden)').count();
    await page.locator('#selMark').selectOption('');
    if (want === undefined || n !== want) throw new Error('chip=' + want + ' cards=' + n);
    return n;
  });
  await t('filter clean matches chip count', async () => {
    const txt = await page.locator('#markIssues').textContent();
    const want = +(txt.match(/不重做\s*(\d+)/) || [])[1];
    await page.locator('#selMark').selectOption('clean');
    const n = await page.locator('.card:not(.hidden)').count();
    await page.locator('#selMark').selectOption('');
    if (want === undefined || n !== want) throw new Error('chip=' + want + ' cards=' + n);
    return n;
  });
  await t('sus chip click marks redo', async () => {
    const c = page.locator('.card:has(.chip.sus)').first();
    const key = await c.getAttribute('data-key');
    const r0 = await c.locator('.rsel').inputValue();
    if (r0 !== 'yes') {
      await c.locator('.chip.sus').first().click();
      await page.waitForTimeout(200);
      const r1 = await c.locator('.rsel').inputValue();
      if (r1 !== 'yes') throw new Error('r1=' + r1);
      const stored = await page.evaluate(k => (JSON.parse(localStorage.getItem('card_anim_review_marks_v3'))[k] || {}).r, key);
      if (stored !== 'yes') throw new Error('stored=' + stored);
    }
    return key;
  });
  await t('search by joined card id', async () => {
    await page.locator('#q').fill('ww2_t34_85');
    const n = await page.locator('.card:not(.hidden)').count();
    const key = await page.locator('.card:not(.hidden)').first().getAttribute('data-key');
    await page.locator('#q').fill('');
    if (n !== 1 || key !== 'fam|ww2_arm_sherman') throw new Error('n=' + n + ' key=' + key);
    return key;
  });
  await t('compat appendix visible', async () => {
    const n = await page.locator('#sec-compat .compat').count();
    const txt = await page.locator('#sec-compat').textContent();
    if (n !== 1 || !txt.includes('platform_ww1_light')) throw new Error(txt.slice(0, 80));
    return 'ok';
  });

  // ── 导出/导入 ──
  await t('export downloads json', async () => {
    const [dl] = await Promise.all([
      page.waitForEvent('download', { timeout: 5000 }),
      page.locator('#btnExport').click(),
    ]);
    const fp = path.join(__dirname, '_tmp_marks_export.json');
    await dl.saveAs(fp);
    const j = require(fp);
    if (!j.marks['fam|ww1_arm_rolls'] || j.marks['fam|ww1_arm_rolls'].r !== 'yes')
      throw new Error('bad export: ' + JSON.stringify(Object.keys(j.marks)));
    return 'marked=' + j.marked;
  });
  await t('clear then import restores', async () => {
    await page.locator('#btnClear').click();
    await page.waitForTimeout(300);
    const n0 = await page.locator('.card[data-marked="1"]').count();
    if (n0 !== 0) throw new Error('clear left ' + n0);
    await page.locator('#fileImport').setInputFiles(path.join(__dirname, '_tmp_marks_export.json'));
    await page.waitForTimeout(300);
    const c2 = page.locator('.card[data-key="fam|ww1_arm_rolls"]');
    const r = await c2.locator('.rsel').inputValue();
    if (r !== 'yes') throw new Error('import lost redo: ' + r);
    return 'ok';
  });

  // ── 弹窗（家族卡：统一ID meta + 双图）──
  await t('modal shows unified meta + dual icons', async () => {
    await page.locator('.card[data-key="fam|ww2_arm_sherman"]').locator('.info .nm').click();
    await page.waitForTimeout(400);
    const html = await page.locator('#mbox').innerHTML();
    await page.keyboard.press('Escape');
    if (!html.includes('统一ID') || !html.includes('敌方原图') || !html.includes('挂接我方卡'))
      throw new Error('meta missing parts');
    return 'ok';
  });

  // ── 选用动画按钮（候选动画切换 + 拍板记录）──
  await t('selector bar only on multi-set rows', async () => {
    const noAltKey = await page.evaluate(() => {
      const r = DATA.sections.flatMap(s => s.rows).find(r => r.anim && !r.alt_anims && !r.extra_anims);
      return r ? (r.sec + '|' + r.id) : '';
    });
    if (!noAltKey) throw new Error('no single-set row found');
    const nBar = await page.locator('.card[data-key="' + noAltKey + '"] .asetbtns').count();
    if (nBar !== 0) throw new Error(noAltKey + ' has bar');
    const nAlt = await page.locator('.card[data-key="fam|mod_arm_abrams_mk2"] .aset').count();
    if (nAlt < 2) throw new Error('abrams_mk2 aset=' + nAlt);
    return 'single=' + noAltKey + ' abrams=' + nAlt;
  });
  await t('choose alt anim on card + persists', async () => {
    const key = 'fam|mod_arm_abrams_mk2';
    let c = page.locator('.card[data-key="' + key + '"]');
    const btns = c.locator('.aset');
    const altLabel = await btns.nth(1).textContent();
    await btns.nth(1).click();
    await page.waitForTimeout(400);
    const on = await c.locator('.aset.on').textContent();
    if (on !== altLabel) throw new Error('on=' + on + ' want ' + altLabel);
    const canv = await c.locator('.animcol canvas').count();
    if (canv < 1) throw new Error('animcol lost canvases');
    const a = await page.evaluate(k => (JSON.parse(localStorage.getItem('card_anim_review_marks_v3'))[k] || {}).a, key);
    if (a !== 'alt:mod_arm_m1a1') throw new Error('a=' + a);
    await page.reload(); await page.waitForTimeout(900);
    c = page.locator('.card[data-key="' + key + '"]');
    const on2 = await c.locator('.aset.on').textContent();
    if (on2 !== altLabel) throw new Error('not persisted: ' + on2);
    // 复原回现行（避免污染后续用例）
    await c.locator('.aset').first().click();
    await page.waitForTimeout(300);
    const a2 = await page.evaluate(k => (JSON.parse(localStorage.getItem('card_anim_review_marks_v3'))[k] || {}).a, key);
    if (a2 !== 'main') throw new Error('restore a=' + a2);
    return altLabel;
  });
  await t('modal strip previews + records choice', async () => {
    const key = 'fam|mod_arm_abrams_mk2';
    await page.locator('.card[data-key="' + key + '"]').locator('.info .nm').click();
    await page.waitForTimeout(400);
    let html = await page.locator('#mbox').innerHTML();
    // 当前拍板=main：无预览行，但选择条在
    if (html.includes('预览动画')) throw new Error('preview row should be absent on main');
    if (await page.locator('#mbox .aset').count() < 2) throw new Error('modal strip missing');
    // 弹窗内切候选 → 预览行出现，卡面同步
    await page.locator('#mbox .aset').nth(1).click();
    await page.waitForTimeout(400);
    html = await page.locator('#mbox').innerHTML();
    if (!html.includes('预览动画')) throw new Error('no preview row after strip switch');
    const cardOn = await page.locator('.card[data-key="' + key + '"] .aset.on').textContent();
    if (!cardOn.includes('候选')) throw new Error('card not synced: ' + cardOn);
    // 切回现行 → 预览行消失
    await page.locator('#mbox .aset').first().click();
    await page.waitForTimeout(400);
    html = await page.locator('#mbox').innerHTML();
    if (html.includes('预览动画')) throw new Error('preview row should vanish on main');
    await page.keyboard.press('Escape');
    await page.waitForTimeout(200);
    if (await page.locator('#modal.open').count() !== 0) throw new Error('Escape did not close modal');
    const a = await page.evaluate(k => (JSON.parse(localStorage.getItem('card_anim_review_marks_v3'))[k] || {}).a, key);
    if (a !== 'main') throw new Error('modal did not record: ' + a);
    return 'ok';
  });

  await t('zero page errors', async () => {
    if (errors.length) throw new Error(errors.join(' | '));
    return 0;
  });

  // 清理测试标记
  await page.locator('#btnClear').click();
  await page.waitForTimeout(200);
  const ls = await page.evaluate(() => localStorage.getItem('card_anim_review_marks_v3'));
  if (ls !== '{}') throw new Error('cleanup failed: ' + ls);

  await browser.close();
  console.log('SMOKE DONE');
})();
