(function () {
  const data = window.HEX_ARAM;
  const listEl = document.getElementById("list");
  const countEl = document.getElementById("count");
  const moreBtn = document.getElementById("more");
  const hintEl = document.getElementById("hint");
  const staleBanner = document.getElementById("stale-banner");
  const dialog = document.getElementById("detail");
  const detailBody = document.getElementById("detail-body");

  if (!data || !Array.isArray(data.combos)) {
    listEl.innerHTML = '<div class="empty-state"><strong>数据文件没有读到</strong><p>确认 index.html 和 data.js 在同一目录后再打开。</p></div>';
    return;
  }
  if (data.combos.length !== data.meta.comboCount) {
    listEl.innerHTML = '<div class="empty-state"><strong>数据文件不完整</strong><p>组合条数和文件里的记录对不上，这页先停用，避免显示出残缺胜率。</p></div>';
    return;
  }

  const champs = Object.fromEntries(data.champions.map((champ) => [champ.key, champ]));
  const augments = Object.fromEntries(data.augments.map((augment) => [augment.id, augment]));
  const rows = data.combos.map((combo) => {
    const champ = champs[combo[0]];
    const augment = augments[combo[1]];
    const status = combo[6] === 1 ? "ok" : "no-data";
    const win = combo[2];
    const games = combo[3];
    const pick = combo[4];
    const base = combo[5];
    const delta = status === "ok" && win != null && base != null ? round2(win - base) : null;
    const blob = [champ.title, champ.given, champ.en, champ.key, augment.zh, augment.en]
      .join(" ")
      .toLowerCase();
    return { champ, augment, status, win, games, pick, base, delta, blob };
  });

  const statusLabel = {
    using: "使用中",
    stale: "来源过期",
    empty: "暂无数据",
    unused: "未采用",
  };

  const ageDays = (Date.now() - Date.parse(data.meta.fetchedAt + "T00:00:00Z")) / 86400000;
  const timeStale = ageDays > data.meta.staleAfterDays;

  document.getElementById("lede").textContent =
    "补丁 " + data.meta.patch + "（客户端 " + data.meta.clientPatch + "）。数字来自 " +
    data.meta.sourceName + " 在 " + data.meta.fetchedAt + " 的页面，首页样本 " +
    data.meta.gamesAnalyzedLabel + " 场。" + data.meta.region + "。";

  document.getElementById("chips").innerHTML = [
    chip("using", "使用中 · " + data.meta.sourceName + " · " + data.meta.patch + " · " + data.meta.fetchedAt),
    chip("stale", "来源过期 · 26.18 及更早补丁页，未采用胜率"),
    chip("empty", "暂无数据 · 官方和国服公开组合胜率"),
  ].join("");

  if (timeStale) {
    staleBanner.hidden = false;
    staleBanner.textContent =
      "来源可能过期：这批数字抓取于 " + data.meta.fetchedAt +
      "，距离今天已超过 " + data.meta.staleAfterDays + " 天。排队前先核对 Mayhem:Meta 是否仍是补丁 " +
      data.meta.patch + "。";
  }

  document.getElementById("source-list").innerHTML = data.sources.map((source) => {
    const link = source.url ? '<a href="' + esc(source.url) + '" target="_blank" rel="noreferrer">' + esc(source.url) + "</a>" : "";
    return (
      '<article class="source">' +
      '<div><span class="badge ' + esc(source.status) + '">' + statusLabel[source.status] + "</span>" +
      "<strong>" + esc(source.name) + "</strong> · " + esc(source.when) + "</div>" +
      "<p>" + esc(source.note) + "</p>" + link +
      "</article>"
    );
  }).join("");

  const qEl = document.getElementById("q");
  const sortEl = document.getElementById("sort");
  const rarityEl = document.getElementById("rarity");
  const tierEl = document.getElementById("tier");
  const statusEl = document.getElementById("status");
  const minEl = document.getElementById("min-games");
  let shown = 30;
  let current = [];

  function apply() {
    const query = qEl.value.trim().toLowerCase();
    const rarity = rarityEl.value;
    const tier = tierEl.value;
    const status = statusEl.value;
    const minGames = Math.max(0, Number(minEl.value) || 0);
    current = rows.filter((row) => {
      if (query && !row.blob.includes(query)) return false;
      if (rarity && row.augment.rarity !== rarity) return false;
      if (tier && row.champ.tier !== tier) return false;
      if (status === "ok" && row.status !== "ok") return false;
      if (status === "no-data" && row.status !== "no-data") return false;
      if (row.status === "ok" && row.games < minGames && status !== "no-data") return false;
      return true;
    });
    current.sort(sorter(sortEl.value));
    shown = 30;
    render();
    hintEl.textContent = status === "no-data"
      ? "这些海克斯在对应英雄页被标为本补丁没有选取记录。胜率和样本量留空，显示为暂无数据。"
      : "默认隐藏样本量低于输入值的组合。强度差等于选取时胜率减去未选取时的对照胜率，来源会在几乎每局都选它时把差值向 0 收缩。英雄梯度是来源英雄榜上的字母，不是官方段位。";
  }

  function render() {
    const slice = current.slice(0, shown);
    countEl.textContent = current.length
      ? "符合条件 " + current.length.toLocaleString("zh-CN") + " 条，当前显示 " + slice.length.toLocaleString("zh-CN") + " 条"
      : "";
    if (!current.length) {
      listEl.innerHTML = '<div class="empty-state"><strong>没有符合条件的组合</strong><p>换个名字，或把「数据」改成全部、把最少样本量改成 0。对不上的搭配不会被编成胜率。</p></div>';
    } else {
      listEl.innerHTML = slice.map((row, index) => cardHtml(row, index)).join("");
    }
    moreBtn.hidden = shown >= current.length || !current.length;
  }

  function cardHtml(row, index) {
      const has = row.status === "ok";
    return (
      '<button type="button" class="card" data-index="' + index + '">' +
      '<span class="tier" title="英雄梯度">' + esc(row.champ.tier) + "</span>" +
      '<span><span class="who">' + esc(row.champ.title) + " · " + esc(row.champ.given) + "</span>" +
      '<span class="hex">' + esc(row.augment.zh) + " · " + esc(row.augment.rarityZh) + "</span></span>" +
      '<span class="metrics">' +
      metric(value(has, pct(row.win)), "组合胜率") +
      metric(value(has, num(row.games)), "样本量") +
      metric(value(has, signed(row.delta)), "强度差") +
      "</span></button>"
    );
  }

  listEl.addEventListener("click", (event) => {
    const card = event.target.closest(".card");
    if (!card) return;
    openDetail(current[Number(card.dataset.index)]);
  });
  moreBtn.addEventListener("click", () => {
    shown += 30;
    render();
  });
  document.getElementById("reset").addEventListener("click", () => {
    qEl.value = "";
    sortEl.value = "win-desc";
    rarityEl.value = "";
    tierEl.value = "";
    statusEl.value = "ok";
    minEl.value = "100";
    apply();
  });
  [qEl, sortEl, rarityEl, tierEl, statusEl, minEl].forEach((el) => {
    el.addEventListener("input", apply);
    el.addEventListener("change", apply);
  });
  document.getElementById("close").addEventListener("click", () => dialog.close());
  dialog.addEventListener("click", (event) => {
    if (event.target === dialog) dialog.close();
  });
  dialog.addEventListener("close", () => {
    if (location.hash) history.replaceState(null, "", location.pathname + location.search);
  });

  function openDetail(row) {
    const page = "https://mayhemmeta.com/champions/" + row.champ.key;
    const augPage = "https://mayhemmeta.com/augments/" + row.augment.id;
    const has = row.status === "ok";
    detailBody.innerHTML =
      '<div class="detail"><h3>' + esc(row.champ.title) + " · " + esc(row.champ.given) + " + " + esc(row.augment.zh) + "</h3>" +
      '<p class="sub">' + esc(row.champ.en) + " + " + esc(row.augment.en) + " · " + esc(row.augment.rarityZh) + "</p>" +
      '<div class="stats">' +
      stat("组合胜率", has, pct(row.win)) +
      stat("样本量", has, num(row.games) + " 场") +
      stat("选取率", has, pct(row.pick)) +
      stat("未选取时对照胜率", has, pct(row.base)) +
      stat("强度差", has, signed(row.delta) + " 个百分点") +
      stat("英雄梯度", true, esc(row.champ.tier) + " · 榜上第 " + row.champ.rank + " / " + data.meta.championCount) +
      "</div>" +
      '<div class="note"><p>' + strengthText(row) + "</p>" +
      "<p>英雄整体胜率 " + pct(row.champ.winRate) + "，样本 " + num(row.champ.games) +
      " 场，选取率 " + pct(row.champ.pickRate) + "。梯度字母来自 Mayhem:Meta 英雄榜。</p>" +
      "<p>来源页面：<a href=\"" + page + "\" target=\"_blank\" rel=\"noreferrer\">" + esc(page) + "</a> ，海克斯页 <a href=\"" +
      augPage + "\" target=\"_blank\" rel=\"noreferrer\">" + row.augment.id + "</a>。补丁 " + data.meta.patch +
      "（客户端 " + data.meta.clientPatch + "），抓取日期 " + data.meta.fetchedAt + "。</p>" +
      "<p>样本范围：首页标注 " + esc(data.meta.gamesAnalyzedLabel) + " 场，地图为 " +
      data.meta.maps.map(esc).join("、") + "。" + esc(data.meta.region) +
      "。中文海克斯名来自客户端字符串，按同一个强化 id 对齐。普通极地大乱斗和斗魂竞技场的胜率没有写入这张表。</p></div></div>";
    if (!dialog.open) dialog.showModal();
    history.replaceState(null, "", "#c=" + row.champ.key + "&a=" + row.augment.id);
  }

  function strengthText(row) {
    if (row.status !== "ok") {
      return "暂无数据。来源把这个海克斯标成该英雄在补丁 " + data.meta.patch + " 没有选取记录，所以这里不写 0% 胜率，也不估一个梯度。";
    }
    return "选取「" + esc(row.augment.zh) + "」时胜率 " + pct(row.win) + "（" + num(row.games) +
      " 场）。未选取时的对照胜率是 " + pct(row.base) + "，差值 " + signed(row.delta) +
      " 个百分点。来源对这个差值的说明是：选取时胜率减去没选它时的胜率；几乎每局都点它时，差值会向 0 收缩。";
  }

  function findFromHash() {
    const match = location.hash.match(/^#c=([a-z0-9]+)&a=(\d+)$/);
    if (!match) return;
    const row = rows.find((item) => item.champ.key === match[1] && String(item.augment.id) === match[2]);
    if (row) openDetail(row);
  }

  apply();
  findFromHash();

  function sorter(mode) {
    const dir = mode.endsWith("asc") ? 1 : -1;
    const key = mode.startsWith("win") ? "win" : mode.startsWith("delta") ? "delta" : "games";
    return (a, b) => {
      const av = a.status === "ok" ? a[key] : null;
      const bv = b.status === "ok" ? b[key] : null;
      if (av == null && bv == null) return a.champ.title.localeCompare(b.champ.title, "zh");
      if (av == null) return 1;
      if (bv == null) return -1;
      if (av !== bv) return (av - bv) * dir;
      return (b.games || 0) - (a.games || 0);
    };
  }

  function metric(valueHtml, label) {
    return '<span class="metric">' + valueHtml + "<span>" + label + "</span></span>";
  }
  function value(has, text) {
    return has ? "<b>" + text + "</b>" : '<b class="missing">暂无数据</b>';
  }
  function stat(label, has, text) {
    return '<div class="stat"><span>' + label + "</span>" + value(has, text) + "</div>";
  }
  function chip(kind, text) { return '<span class="chip ' + kind + '">' + esc(text) + "</span>"; }
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
