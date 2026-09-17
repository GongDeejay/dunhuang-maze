(() => {
  'use strict';
  const overlay = document.getElementById('status');
  document.body.classList.add('intro-open');
  const key = 'dunhuang-intro-v1';
  const chapters = [
    ['一起出发', '那天，我们一起\n走进敦煌。', '爸爸、妈妈和两个孩子，沿着金色山谷慢慢前行。风很轻，阳光正好，大家约好：下一站，一起去看沙漠。', '敦煌 · 风起之前', '移动', '电脑：WASD 或方向键移动。手机：轻触方向键，也可以在地图上滑动。'],
    ['风暴突至', '一阵风，\n吹散了四个人。', '天边忽然扬起黄沙，熟悉的山谷转眼被风暴吞没。呼喊声消失在风里，再睁开眼时，身边的家人已经不见了。', '敦煌 · 黄沙遮住了归路', '即时战斗', '敌人不会等你行动。朝相邻敌人的方向移动即可攻击；留意箭头预警，及时避让。电脑按 P / Esc，手机点“暂停”可暂停战斗。'],
    ['寻找家人', '风停之后，\n我们一定要团聚。', '你决定沿着古道出发，寻找走散的家人。穿过迷途，留意沿路的补给与指引——这趟旅程，要一家人一起走完。', '敦煌 · 旅途从这里开始', '补给与目标', '寻找家人、收集补给。电脑用 1–5 选道具、E 使用；手机点“换”“用”。集齐当前关卡的家人后，跟随指引前往出口。'],
  ];
  let seen = false;
  try { seen = localStorage.getItem(key) === 'seen'; } catch (_) { /* Private storage may be unavailable. */ }
  let chapter = 0;
  let ready = false;
  let failed = false;
  let skip = seen;
  let auto = !matchMedia('(prefers-reduced-motion: reduce)').matches;
  const $ = id => document.getElementById(id);
  const enter = $('intro-enter');
  let timer;
  let slowTimer;

  function stop() { clearInterval(timer); }
  function render() {
    const c = chapters[chapter];
    overlay.dataset.chapter = String(chapter);
    $('intro-chapter').textContent = `0${chapter + 1} / 03 · ${c[0]}`;
    $('intro-title').textContent = c[1];
    $('intro-title').style.whiteSpace = 'pre-line';
    $('intro-copy').textContent = c[2];
    overlay.querySelector('.intro-caption').textContent = c[3];
    $('intro-tip-label').textContent = `旅途指南 · ${c[4]}`;
    $('intro-tip').textContent = c[5];
    $('intro-page').textContent = `0${chapter + 1} — 03`;
    $('intro-prev').disabled = chapter === 0;
    $('intro-next').disabled = chapter === chapters.length - 1;
    $('intro-auto').textContent = auto ? '暂停播放' : '自动播放';
    overlay.dataset.paused = String(!auto);
  }
  function schedule() {
    stop();
    if (auto && !skip) timer = setInterval(() => {
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
  $('intro-skip').addEventListener('click', () => {
    skip = !skip;
    overlay.dataset.returning = String(skip);
    $('intro-skip').textContent = skip ? '重看序章' : '跳过剧情';
    if (skip) { stop(); if (ready) dismiss(); }
    else schedule();
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
      $('intro-network').textContent = '现在可以启程，也可以继续翻阅剧情与操作指南。';
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
  render(); schedule();
  slowTimer = setTimeout(() => {
    if (!ready && !failed) $('intro-network').textContent = '网络较慢，资源仍在后台加载。可以继续翻阅剧情和操作指南。';
  }, 25000);
})();
