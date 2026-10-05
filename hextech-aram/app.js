(function () {
  const data = window.HEX_ARAM;
  const pinyin = window.HEX_PINYIN;
  const listEl = document.getElementById("list");
  const hintEl = document.getElementById("hint");
  const picksEl = document.getElementById("picks");
  const qEl = document.getElementById("q");
  const dialog = document.getElementById("detail");
  const detailBody = document.getElementById("detail-body");
  const staleBanner = document.getElementById("stale-banner");

  if (!data || !Array.isArray(data.combos) || !pinyin) {
    listEl.innerHTML = '<div class="empty-state"><strong>数据文件没有读到</strong><p>确认 index.html、data.js、pinyin.js 在同一目录后再打开。</p></div>';
    return;
  }
  if (data.combos.length !== data.meta.comboCount) {
    listEl.innerHTML = '<div class="empty-state"><strong>数据文件不完整</strong><p>组合条数和文件里的记录对不上，这页先停用。</p></div>';
    return;
  }

  const champs = Object.fromEntries(data.champions.map((champ) => [champ.key, champ]));
  const augments = Object.fromEntries(data.augments.map((augment) => [augment.id, augment]));
  const byChamp = {};
  const byAugment = {};

  data.combos.forEach((combo) => {
    if (combo[6] !== 1 || combo[2] == null || combo[3] == null) return;
    const row = {
      champ: champs[combo[0]],
      augment: augments[combo[1]],
      win: combo[2],
      games: combo[3],
      pick: combo[4],
      base: combo[5],
      delta: round2(combo[2] - combo[5]),
    };
    (byChamp[row.champ.key] || (byChamp[row.champ.key] = [])).push(row);
    (byAugment[row.augment.id] || (byAugment[row.augment.id] = [])).push(row);
  });
  Object.values(byChamp).forEach(sortByWin);
  Object.values(byAugment).forEach(sortByWin);

  const mapNote = data.meta.maps.join("、");
  document.getElementById("lede").textContent =
    "补丁 " + data.meta.patch + "，" + data.meta.fetchedAt + " 抓取自 " + data.meta.sourceName +
    "。组合胜率把 " + mapNote + " 合在一起算，站点未按单张地图拆开，也没有标成国服。下面只给出有胜率、且来源记为本补丁选过的海克斯，按胜率从高到低，最多 10 条。";

  const ageDays = (Date.now() - Date.parse(data.meta.fetchedAt + "T00:00:00Z")) / 86400000;
  if (ageDays > data.meta.staleAfterDays) {
    staleBanner.hidden = false;
    staleBanner.textContent =
      "这批数字抓取于 " + data.meta.fetchedAt + "，已经超过 " + data.meta.staleAfterDays +
      " 天。进游戏前先看 Mayhem:Meta 是不是还在补丁 " + data.meta.patch + "。";
  }

  let pickedKey = "";
  let current = [];

  qEl.addEventListener("input", () => {
    pickedKey = "";
    render();
  });
  picksEl.addEventListener("click", (event) => {
    const button = event.target.closest("button.pick");
    if (!button) return;
    pickedKey = button.dataset.key;
    render();
  });
  listEl.addEventListener("click", (event) => {
    const card = event.target.closest(".card");
    if (!card) return;
    openDetail(current[Number(card.dataset.index)]);
  });
  document.getElementById("close").addEventListener("click", () => dialog.close());
  dialog.addEventListener("click", (event) => {
    if (event.target === dialog) dialog.close();
  });

  function render() {
    const query = normalize(qEl.value);
    picksEl.innerHTML = "";
    current = [];

    if (!query) {
      hintEl.textContent = "输入过程中就会出结果。亚索可以打 ys，疾风剑豪可以打 jfjh。";
      listEl.innerHTML = '<div class="empty-state"><strong>先打一个简称</strong><p>打出唯一英雄后，直接给他胜率最高的 10 个海克斯。简称撞车时先点英雄。</p></div>';
      return;
    }

    const champHits = matchChampions(query);
    if (champHits.length > 1 && !pickedKey) {
      hintEl.textContent = "这个简称对上 " + champHits.length + " 个英雄。点之前先看整体胜率：绿标是超过 50%，灰标是未超过 50%。";
      picksEl.innerHTML = champHits.map(pickButton).join("");
      listEl.innerHTML = "";
      return;
    }

    const champ = champHits.length === 1 ? champHits[0] : champs[pickedKey];
    if (champ && champHits.some((item) => item.key === champ.key)) {
      const rows = (byChamp[champ.key] || []).slice(0, 10);
      const band = window.HEX_MATCH.band(champ);
      hintEl.textContent = champ.title + " · " + champ.given + " 整体胜率 " + rateText(champ) + "，" + window.HEX_MATCH.label(band) + "。下面是海克斯胜率前 " + rows.length + "。";
      picksEl.innerHTML = (champHits.length > 1
        ? '<button type="button" class="pick" data-key=""><b>换一个英雄</b><span>' + champHits.length + " 个对上简称</span></button>"
        : "") + champStatus(champ);
      current = rows;
      renderRows(rows, false);
      return;
    }

    const hexHits = matchAugments(query);
    if (hexHits.length) {
      const merged = [];
      const seen = new Set();
      hexHits.forEach((augment) => {
        (byAugment[augment.id] || []).forEach((row) => {
          const id = row.champ.key + ":" + row.augment.id;
          if (seen.has(id)) return;
          seen.add(id);
          merged.push(row);
        });
      });
      sortByWin(merged);
      const rows = merged.slice(0, 10);
      const names = hexHits.slice(0, 3).map((augment) => augment.zh).join("、");
      hintEl.textContent = "海克斯对上 " + names + (hexHits.length > 3 ? " 等" : "") + "，胜率前 " + rows.length + " 条。";
      current = rows;
      renderRows(rows, true);
      return;
    }

    hintEl.textContent = "没有对上的英雄或海克斯。";
    listEl.innerHTML = '<div class="empty-state"><strong>没有结果</strong><p>换个简称。这里不列没有胜率的搭配。</p></div>';
  }

  function renderRows(rows, showChamp) {
    if (!rows.length) {
      listEl.innerHTML = '<div class="empty-state"><strong>这个英雄没有可列出的海克斯</strong><p>来源里没有他在本补丁选过、且写了胜率的海克斯。</p></div>';
      return;
    }
    listEl.innerHTML = rows.map((row, index) => (
      '<button type="button" class="card" data-index="' + index + '">' +
      '<span class="rank">' + (index + 1) + "</span>" +
      "<span><span class=\"who\">" + esc(showChamp ? row.champ.title + " · " + row.champ.given + " + " + row.augment.zh : row.augment.zh) + "</span>" +
      '<span class="hex">' + esc(row.augment.rarityZh) + (showChamp ? "" : " · " + esc(row.champ.title)) + "</span></span>" +
      '<span class="win">' + pct(row.win) + "</span>" +
      '<span class="games">' + num(row.games) + " 场</span></button>"
    )).join("");
  }

  function matchChampions(query) {
    return window.HEX_MATCH.champions(data, pinyin, query);
  }

  function pickButton(champ) {
    const band = window.HEX_MATCH.band(champ);
    return '<button type="button" class="pick ' + band + '" data-key="' + esc(champ.key) + '">' +
      "<b>" + esc(champ.title) + " · " + esc(champ.given) + "</b>" +
      bandMark(champ) + "</button>";
  }

  function champStatus(champ) {
    const band = window.HEX_MATCH.band(champ);
    return '<div class="champ-line ' + band + '">' +
      "<b>" + esc(champ.title) + " · " + esc(champ.given) + "</b>" +
      bandMark(champ) + "</div>";
  }

  function bandMark(champ) {
    const band = window.HEX_MATCH.band(champ);
    const rate = band === "none" ? "没有数据" : pct(champ.winRate);
    return '<span class="band">' + esc(window.HEX_MATCH.label(band)) + "<strong>" + rate + "</strong></span>";
  }

  function rateText(champ) {
    return window.HEX_MATCH.band(champ) === "none" ? "没有数据" : pct(champ.winRate);
  }

  function matchAugments(query) {
    return data.augments
      .map((augment) => ({ augment, rank: augmentRank(augment, query) }))
      .filter((item) => item.rank >= 0)
      .sort((a, b) => a.rank - b.rank)
      .map((item) => item.augment);
  }

  function augmentRank(augment, query) {
    const py = pinyin.augments[String(augment.id)];
    if (!py) return -1;
    if (py.zhInit === query || py.zhFull === query || augment.zh.toLowerCase() === query) return 0;
    if (py.en === query || py.enInit === query) return 1;
    const keys = [py.zhInit, py.zhFull, py.en, py.enInit, augment.zh.toLowerCase(), augment.en.toLowerCase()];
    return keys.some((key) => key && key.startsWith(query)) ? 2 : -1;
  }

  function openDetail(row) {
    const page = "https://mayhemmeta.com/champions/" + row.champ.key;
    detailBody.innerHTML =
      '<div class="detail"><h3>' + esc(row.champ.title) + " · " + esc(row.champ.given) + " + " + esc(row.augment.zh) + "</h3>" +
      '<p class="sub">' + esc(row.champ.en) + " + " + esc(row.augment.en) + " · " + esc(row.augment.rarityZh) + "</p>" +
      '<div class="stats">' +
      stat("组合胜率", pct(row.win)) +
      stat("样本量", num(row.games) + " 场") +
      stat("选取率", pct(row.pick)) +
      stat("未选取时对照胜率", pct(row.base)) +
      "</div>" +
      '<div class="note"><p>选取时胜率 ' + pct(row.win) + "，未选取时 " + pct(row.base) + "，差 " + signed(row.delta) + " 个百分点。</p>" +
      "<p>来源 <a href=\"" + page + "\" target=\"_blank\" rel=\"noreferrer\">" + esc(page) + "</a>。补丁 " +
      data.meta.patch + "，抓取 " + data.meta.fetchedAt + "。样本把 " + esc(mapNote) +
      " 合在一起，站点未按单张地图拆开。</p></div></div>";
    if (!dialog.open) dialog.showModal();
  }

  render();

  function sortByWin(rows) {
    rows.sort((a, b) => b.win - a.win || b.games - a.games);
  }
  function stat(label, value) {
    return '<div class="stat"><span>' + label + "</span><b>" + value + "</b></div>";
  }
  function normalize(value) {
    return value.trim().toLowerCase().replace(/\s+/g, "");
  }
  function pct(value) { return Number(value).toFixed(2) + "%"; }
  function signed(value) { const n = round2(value); return (n > 0 ? "+" : "") + n.toFixed(2); }
  function num(value) { return Number(value).toLocaleString("zh-CN"); }
  function round2(value) { return Math.round(value * 100) / 100; }
  function esc(value) {
    return String(value).replace(/[&<>"']/g, (char) => ({
      "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;",
    }[char]));
  }
})();
