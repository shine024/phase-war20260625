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
      'captured|drop_smg_mk2': { p: ['clip'], r: '', n: '旧缴获标注' },
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
  await t('pb buttons = 1254', async () => {
    const n = await page.locator('.pb').count();
    if (n !== 209 * 6) throw new Error('got ' + n); return n;
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
    const on = (await c.locator('.pb[data-p="face"]').getAttribute('class')).includes('on');
    const r = await c.locator('.rsel').inputValue();
    const n = await c.locator('.rnote').inputValue();
    if (!on || r !== 'yes' || n !== '旧敌标注') throw new Error('on=' + on + ' r=' + r + ' n=' + n);
    return 'ok';
  });
  await t('migration: player t34_85 → sherman fam', async () => {
    const c = page.locator('.card[data-key="fam|ww2_arm_sherman"]');
    const on = (await c.locator('.pb[data-p="bg"]').getAttribute('class')).includes('on');
    if (!on) throw new Error('bg not on');
    return 'ok';
  });
  await t('migration: captured drop → drop sec', async () => {
    const c = page.locator('.card[data-key="drop|drop_smg_mk2"]');
    const on = (await c.locator('.pb[data-p="clip"]').getAttribute('class')).includes('on');
    if (!on) throw new Error('clip not on');
    return 'ok';
  });
  await t('migration: platform key kept', async () => {
    const c = page.locator('.card[data-key="plat|void_mage_basic"]');
    const on = (await c.locator('.pb[data-p="other"]').getAttribute('class')).includes('on');
    if (!on) throw new Error('other not on');
    return 'ok';
  });
  await t('mark chips: marked=4 redo=1', async () => {
    await page.waitForTimeout(300);
    const txt = await page.locator('#markIssues').textContent();
    if (!/已标记\s*4/.test(txt) || !/需重做\s*1/.test(txt)) throw new Error(txt.slice(0, 120));
    return 'ok';
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

  // ── 新标注 + 持久化 ──
  await t('new mark on ind card persists', async () => {
    const c = page.locator('.card[data-key="ind|ww1_lanchest"]');
    await c.locator('.pb[data-p="size"]').click();
    await c.locator('.rsel').selectOption('yes');
    await page.reload(); await page.waitForTimeout(900);
    const c2 = page.locator('.card[data-key="ind|ww1_lanchest"]');
    const on = (await c2.locator('.pb[data-p="size"]').getAttribute('class')).includes('on');
    const r = await c2.locator('.rsel').inputValue();
    if (!on || r !== 'yes') throw new Error('on=' + on + ' r=' + r);
    return 'ok';
  });

  // ── 筛选 ──
  await t('filter redo', async () => {
    await page.locator('#selMark').selectOption('redo');
    const n = await page.locator('.card:not(.hidden)').count();
    await page.locator('#selMark').selectOption('');
    if (n !== 2) throw new Error('redo cards=' + n); // 旧迁移1 + 新标1
    return n;
  });
  await t('filter p:bg', async () => {
    await page.locator('#selMark').selectOption('p:bg');
    const n = await page.locator('.card:not(.hidden)').count();
    await page.locator('#selMark').selectOption('');
    if (n !== 1) throw new Error('got ' + n);
    return n;
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
    const a = await page.evaluate(k => (JSON.parse(localStorage.getItem('card_anim_review_marks_v2'))[k] || {}).a, key);
    if (a !== 'alt:mod_arm_m1a1') throw new Error('a=' + a);
    await page.reload(); await page.waitForTimeout(900);
    c = page.locator('.card[data-key="' + key + '"]');
    const on2 = await c.locator('.aset.on').textContent();
    if (on2 !== altLabel) throw new Error('not persisted: ' + on2);
    // 复原回现行（避免污染后续用例）
    await c.locator('.aset').first().click();
    await page.waitForTimeout(300);
    const a2 = await page.evaluate(k => (JSON.parse(localStorage.getItem('card_anim_review_marks_v2'))[k] || {}).a, key);
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
    const a = await page.evaluate(k => (JSON.parse(localStorage.getItem('card_anim_review_marks_v2'))[k] || {}).a, key);
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
  const ls = await page.evaluate(() => localStorage.getItem('card_anim_review_marks_v2'));
  if (ls !== '{}') throw new Error('cleanup failed: ' + ls);

  await browser.close();
  console.log('SMOKE DONE');
})();
