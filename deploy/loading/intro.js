(() => {
  'use strict';
  const overlay = document.getElementById('status');
  document.body.classList.add('intro-open');
  const key = 'dunhuang-intro-v1';
  const artwork = overlay.querySelector('.intro-art img');
  const illustrations = [
    [artwork.getAttribute('src'), artwork.alt],
    [artwork.dataset.stormSrc, '黄沙席卷敦煌山谷，一家四口在风暴中走散，彼此伸手寻找。'],
    [artwork.dataset.searchSrc, '风暴过后，爸爸独自沿着敦煌古道的脚印，出发寻找家人。'],
  ];
  let pendingArtwork = -1;
  const imageCache = new Map();
  const artStatus = document.getElementById('intro-art-status');
  const artRetry = document.getElementById('intro-art-retry');

  function loadArtwork(index) {
    const src = illustrations[index][0];
    if (imageCache.has(src)) return imageCache.get(src);
    const image = new Image();
    image.decoding = 'async';
    // These two images total only ~174 KiB. Give the visible story priority over WASM.
    image.fetchPriority = 'high';
    const entry = { image, state: 'loading', promise: null };
    entry.promise = new Promise(resolve => {
      image.onload = async () => {
        try { await image.decode(); } catch (_) { /* onload already confirms usable pixels. */ }
        entry.state = 'ready';
        resolve(true);
      };
      image.onerror = () => { entry.state = 'failed'; resolve(false); };
    });
    imageCache.set(src, entry);
    image.src = src;
    return entry;
  }

  function primeArtwork() {
    if (skip || !overlay.isConnected) return;
    // Start both later acts while the first is being read, not at the moment of flipping.
    loadArtwork(1);
    loadArtwork(2);
  }

  function renderArtwork() {
    if (pendingArtwork === chapter) return;
    pendingArtwork = chapter;
    const target = chapter;
    const [src, alt] = illustrations[target];
    artRetry.hidden = true;
    artStatus.hidden = true;
    overlay.querySelector('.intro-art').setAttribute('aria-busy', 'false');
    if (artwork.getAttribute('src') === src) return;
    const entry = loadArtwork(target);
    if (entry.state !== 'ready') {
      artStatus.textContent = `第 ${target + 1} 幕插图加载中，正文可先阅读`;
      artStatus.hidden = false;
      overlay.querySelector('.intro-art').setAttribute('aria-busy', 'true');
    }
    // Keep the last usable image; out-of-order responses cannot turn a page back.
    entry.promise.then(loaded => {
      if (chapter !== target || !overlay.isConnected) return;
      overlay.querySelector('.intro-art').setAttribute('aria-busy', 'false');
      if (!loaded) {
        artStatus.textContent = '本幕插图暂未载入，仍可阅读或进入游戏';
        artStatus.hidden = false;
        artRetry.hidden = false;
        return;
      }
      artwork.src = src;
      artwork.alt = alt;
      artStatus.hidden = true;
      artRetry.hidden = true;
    });
  }
  const chapters = [
    ['一起出发', '那天，我们一起\n走进敦煌。', '爸爸、妈妈和两个孩子，沿着金色山谷慢慢前行。风很轻，阳光正好，大家约好：下一站，一起去看沙漠。', '敦煌 · 风起之前', '移动', '电脑：WASD 或方向键移动。手机：轻触方向键，也可以在地图上滑动。'],
    ['风暴突至', '一阵风，\n吹散了四个人。', '天边忽然扬起黄沙，熟悉的山谷转眼被风暴吞没。呼喊声消失在风里，再睁开眼时，身边的家人已经不见了。', '敦煌 · 黄沙遮住了归路', '即时战斗', '敌人不会等你行动。朝相邻敌人的方向移动即可攻击；留意箭头预警，及时避让。电脑按 P / Esc，手机点“暂停”可暂停战斗。'],
    ['寻找家人', '风停之后，\n我们一定要团聚。', '你决定沿着古道出发，寻找走散的家人。穿过迷途，留意沿路的补给与指引——这趟旅程，要一家人一起走完。', '敦煌 · 旅途从这里开始', '补给与目标', '寻找家人、收集补给。电脑用 1–5 选道具、E 使用；手机点“换”“用”。集齐当前关卡的家人后，跟随指引前往出口。'],
  ];
  const places = [
    ['戈壁 · 古道上的足迹', '戈壁常见砾石与裸露地表，与起伏的沙丘有着不同的荒野风景。我们的旅途从敦煌周边古道开始，寻找家人的足迹。'],
    ['莫高窟 · 岩壁里的千年故事', '莫高窟以壁画和彩塑著称，留下丝绸之路上文化交流的印记。旅途中的图案与故事，提醒我们仔细观察、记住线索。'],
    ['三危山 · 风中的归路', '三危山遥对莫高窟。游戏将山谷与远处的营地化为最后一段归路：找到弟弟，让一家四口再次团聚。'],
  ];
  // Original short retellings, checked against the linked institutional sources.
  // Inline text only: reading never competes with the engine for another download.
  const lore = [
    ['壁画故事 · 第257窟', '救过的人，为什么反来捉它？', '九色鹿把落水人救上岸，对方却为了赏赐带人来捕鹿。这段壁画故事把救援、告密和对质画在同一条长卷里，情节从两端走向中间。读这幅画，可不能只从左看到右。', '数字敦煌 · 莫高窟第257窟', 'https://www.e-dunhuang.com/cave/10.0001/0001.0001.0257'],
    ['纹样奇趣 · 三兔共耳', '三只兔子，怎么只有三只耳朵？', '每只看起来都有两只耳朵，整幅图却只画了三只。“三兔共耳”让相邻兔子的耳朵巧妙共用，三只兔子追成一个圈。第407窟的窟顶就藏着这样的视觉小机关。', '敦煌研究院 · 三兔共耳图案', 'https://www.dha.ac.cn/info/1513/6191.htm'],
    ['建窟传说 · 三危山', '一道金光，留下了一个人', '古代《莫高窟记》讲过这样的故事：僧人乐僔来到敦煌，望见山间金光，仿佛有千佛显现，于是留下开窟。这则带着神异色彩的传说，把莫高窟的开端与三危山连在了一起。', '敦煌保护研究基金会 · 莫高窟记记载', 'https://www.dhafund.cn/cms/jjhdt/222.html'],
    ['文物发现 · 藏经洞', '一面墙后，藏着怎样的世界？', '1900年，一间藏在洞窟甬道侧壁后的密室被发现。里面不只有经卷，还有文书和绘画。如今人们称它为藏经洞：一间小小的洞室，竟为后人打开了认识古代社会的一扇窗。', '敦煌研究院 · 藏经洞的发现', 'https://www.dha.ac.cn/info/1159/2519.htm'],
    ['壁画趣闻 · 第112窟', '琵琶为什么跑到了背后？', '第112窟里，一位乐舞伎把琵琶举到背后，身体却仍在起舞。“反弹琵琶”把音乐与舞蹈凝在一个姿态里。石壁没有声音，却能让人想象出一场热闹的音乐会。', '敦煌研究院 · 盛唐古乐，惊艳千年', 'https://www.dha.ac.cn/info/1159/2723.htm'],
    ['壁画巧思 · 第61窟', '把一段旅程，画满一面墙', '敦煌的石窟里，竟画着远方的五台山。第61窟《五台山图》不仅有山路和寺院，还画了赶路、推磨、开店的人。神异景象与日常生活相遇，像一张可以慢慢读的古代旅行地图。', '敦煌研究院 · 莫高窟第61窟', 'https://www.dha.ac.cn/info/1425/3588.htm'],
  ];
  let seen = false;
  try { seen = localStorage.getItem(key) === 'seen'; } catch (_) { /* Private storage may be unavailable. */ }
  let chapter = 0;
  let ready = false;
  let failed = false;
  let skip = seen;
  let readingLore = false;
  let loreIndex = 0;
  let auto = !matchMedia('(prefers-reduced-motion: reduce)').matches;
  const $ = id => document.getElementById(id);
  const enter = $('intro-enter');
  let timer;
  let slowTimer;

  function stop() { clearInterval(timer); }
  function renderLore() {
    const [kind, title, copy, source, href] = lore[loreIndex];
    $('intro-lore-kind').textContent = kind;
    $('intro-lore-title').textContent = title;
    $('intro-lore-copy').textContent = copy;
    $('intro-lore-page').textContent = `${loreIndex + 1} / ${lore.length}`;
    $('intro-lore-link').textContent = source;
    $('intro-lore-link').href = href;
    $('intro-lore-source').open = false;
    $('intro-lore-prev').disabled = loreIndex === 0;
    $('intro-lore-next').textContent = loreIndex === lore.length - 1 ? '从头读 ↻' : '下一则 →';
    overlay.querySelector('.intro-reading').scrollTop = 0;
    if (readingLore && matchMedia('(max-width: 850px) and (max-height: 500px)').matches) {
      // In landscape, start on the actual story; the reading selector is a scroll above.
      $('intro-lore-kind').scrollIntoView({ block: 'start' });
    }
  }
  function showReading(loreSelected) {
    readingLore = loreSelected;
    overlay.dataset.reading = readingLore ? 'lore' : 'story';
    // Explicit reading always cancels returning-visitor auto-entry.
    skip = false;
    auto = false;
    overlay.dataset.returning = 'false';
    $('intro-skip').textContent = '跳过剧情';
    $('intro-story-view').hidden = readingLore;
    $('intro-lore-view').hidden = !readingLore;
    $('intro-show-story').setAttribute('aria-pressed', String(!readingLore));
    $('intro-show-lore').setAttribute('aria-pressed', String(readingLore));
    render(); renderLore(); schedule();
    if (!readingLore) primeArtwork();
  }
  function render() {
    const c = chapters[chapter];
    const changedChapter = overlay.dataset.chapter !== String(chapter);
    overlay.dataset.chapter = String(chapter);
    renderArtwork();
    $('intro-chapter').textContent = `0${chapter + 1} / 03 · ${c[0]}`;
    $('intro-title').textContent = c[1];
    $('intro-title').style.whiteSpace = 'pre-line';
    $('intro-copy').textContent = c[2];
    $('intro-place-title').textContent = places[chapter][0];
    $('intro-place-copy').textContent = places[chapter][1];
    overlay.querySelector('.intro-caption').textContent = c[3];
    $('intro-tip-label').textContent = `旅途指南 · ${c[4]}`;
    $('intro-tip').textContent = c[5];
    $('intro-page').textContent = `0${chapter + 1} — 03`;
    $('intro-prev').disabled = chapter === 0;
    $('intro-next').disabled = chapter === chapters.length - 1;
    $('intro-auto').textContent = auto ? '暂停播放' : '自动播放';
    overlay.dataset.paused = String(!auto);
    if (changedChapter) overlay.querySelector('.intro-reading').scrollTop = 0;
  }
  function schedule() {
    stop();
    if (auto && !skip && !readingLore) timer = setInterval(() => {
      if (document.hidden) return;
      if (chapter < chapters.length - 1) { chapter++; render(); }
      else stop();
    }, 9000);
  }
  function dismiss() {
    if (!ready || failed) return;
    stop(); clearTimeout(slowTimer);
    try { localStorage.setItem(key, 'seen'); } catch (_) { /* Loading must still work. */ }
    overlay.remove();
    document.body.classList.remove('intro-open');
    document.getElementById('canvas').focus();
  }
  $('intro-next').addEventListener('click', () => { auto = false; chapter = Math.min(2, chapter + 1); render(); schedule(); });
  $('intro-prev').addEventListener('click', () => { auto = false; chapter = Math.max(0, chapter - 1); render(); schedule(); });
  $('intro-auto').addEventListener('click', () => { auto = !auto; render(); schedule(); });
  $('intro-show-story').addEventListener('click', () => showReading(false));
  $('intro-show-lore').addEventListener('click', () => showReading(true));
  $('intro-lore-prev').addEventListener('click', () => { loreIndex = Math.max(0, loreIndex - 1); renderLore(); });
  $('intro-lore-next').addEventListener('click', () => { loreIndex = (loreIndex + 1) % lore.length; renderLore(); });
  $('intro-skip').addEventListener('click', () => {
    if (readingLore) {
      showReading(false);
      // Skip the reading experience, not just the original three acts.
      skip = false;
    }
    skip = !skip;
    overlay.dataset.returning = String(skip);
    $('intro-skip').textContent = skip ? '重看序章' : '跳过剧情';
    if (skip) { stop(); if (ready) dismiss(); }
    else { primeArtwork(); schedule(); }
  });
  artRetry.addEventListener('click', () => {
    imageCache.delete(illustrations[chapter][0]);
    pendingArtwork = -1;
    renderArtwork();
  });
  enter.addEventListener('click', dismiss);
  $('intro-retry').addEventListener('click', () => location.reload());
  // Keep tutorial keys out of the running canvas until the player chooses to enter.
  overlay.addEventListener('keydown', event => event.stopPropagation());
  window.dunhuangIntro = {
    ready() {
      if (failed) return;
      ready = true;
      clearTimeout(slowTimer);
      stop();
      $('status-detail').textContent = '旅途已准备就绪';
      overlay.querySelector('.intro-download').textContent = '加载完成';
      $('intro-network').textContent = '现在可以启程，也可以继续翻阅剧情、操作指南与敦煌异闻。';
      $('status-progress').value = 1;
      $('status-progress').max = 1;
      enter.disabled = false;
      enter.textContent = '启程 · 寻找家人';
      if (skip) dismiss();
      else if (!overlay.contains(document.activeElement)) enter.focus({ preventScroll: true });
    },
    fail(message) {
      failed = true;
      stop(); clearTimeout(slowTimer);
      enter.disabled = true;
      enter.textContent = '加载暂时中断';
      $('status-detail').textContent = message;
      overlay.querySelector('.intro-download').textContent = '需要重试';
      $('intro-network').textContent = '请检查网络连接。重试不会删除游戏存档。';
      $('intro-retry').hidden = false;
    },
  };
  overlay.dataset.returning = String(seen);
  if (seen) $('intro-skip').textContent = '重看序章';
  render(); renderLore(); schedule();
  function firstArtworkReady() {
    if (artwork.getAttribute('src') === illustrations[0][0] && artwork.naturalWidth > 0) {
      imageCache.set(illustrations[0][0], { image: artwork, state: 'ready', promise: Promise.resolve(true) });
    }
    primeArtwork();
  }
  if (artwork.complete && artwork.naturalWidth > 0) firstArtworkReady();
  else {
    artwork.addEventListener('load', firstArtworkReady, { once: true });
    artwork.addEventListener('error', primeArtwork, { once: true });
  }
  slowTimer = setTimeout(() => {
    if (!ready && !failed) $('intro-network').textContent = '网络较慢，资源仍在后台加载。可以点“敦煌异闻”，读几则旅途故事。';
  }, 25000);
})();
