(function () {
  const data = window.HEX_ARAM;
  const pinyin = window.HEX_PINYIN;
  const listEl = document.getElementById("list");
  const hintEl = document.getElementById("hint");
  const picksEl = document.getElementById("picks");
  const tabsEl = document.getElementById("tabs");
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

  const mapNote = data.meta.mapNote;
  const buildsMeta = window.HEX_BUILDS && window.HEX_BUILDS.meta;
  document.getElementById("lede").textContent =
    "补丁 " + data.meta.patch + "，" + data.meta.fetchedAt + " 抓取自 " + data.meta.sourceName +
    "。海克斯和英雄整体胜率来自这个来源。" + mapNote +
    "装备页也是海克斯大乱斗，来自 arammayhem.com，补丁 " +
    (buildsMeta ? buildsMeta.patch : "26.21") + "，页面数据日期 " +
    (buildsMeta ? buildsMeta.dataDate : "") +
    "。出门装、鞋子、核心各按登场率从高到低最多列 3 套。技能加点分开写 arammayhem.com 和 OP.GG，不合成一套。Mayhem:Meta 没有购买顺序，所以装备不从那边取。不是国服。";

  const ageDays = (Date.now() - Date.parse(data.meta.fetchedAt + "T00:00:00Z")) / 86400000;
  if (ageDays > data.meta.staleAfterDays) {
    staleBanner.hidden = false;
    staleBanner.textContent =
      "这批数字抓取于 " + data.meta.fetchedAt + "，已经超过 " + data.meta.staleAfterDays +
      " 天。进游戏前先看 Mayhem:Meta 是不是还在补丁 " + data.meta.patch + "。";
  }

  let pickedKey = "";
  let current = [];
  let pane = "hex";
  let hexSort = "win";
  let hexRarity = "all";
  let hexSample = "all";

  tabsEl.addEventListener("click", (event) => {
    const button = event.target.closest("button.tab");
    if (!button) return;
    pane = button.dataset.pane;
    render();
  });

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
    const sort = event.target.closest("[data-hex-sort]");
    const rarity = event.target.closest("[data-hex-rarity]");
    const sample = event.target.closest("[data-hex-sample]");
    if (sort || rarity || sample) {
      if (sort) hexSort = sort.dataset.hexSort;
      if (rarity) hexRarity = rarity.dataset.hexRarity;
      if (sample) hexSample = sample.dataset.hexSample;
      render();
      return;
    }
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
    tabsEl.hidden = true;
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
      const rows = takeHex(byChamp[champ.key] || []);
      const band = window.HEX_MATCH.band(champ);
      picksEl.innerHTML = (champHits.length > 1
        ? '<button type="button" class="pick" data-key=""><b>换一个英雄</b><span>' + champHits.length + " 个对上简称</span></button>"
        : "") + champStatus(champ);
      tabsEl.hidden = false;
      tabsEl.querySelectorAll(".tab").forEach((button) => {
        button.setAttribute("aria-selected", button.dataset.pane === pane ? "true" : "false");
      });
      if (pane === "items") {
        hintEl.textContent = champ.title + " · " + champ.given + " 的装备。海克斯大乱斗。出门装、鞋子、核心按登场率各最多三套。";
        renderBuild(champ);
        return;
      }
      if (pane === "skills") {
        hintEl.textContent = champ.title + " · " + champ.given + " 的加点。两套分开列，不合成。";
        renderSkills(champ);
        return;
      }
      hintEl.textContent = champ.title + " · " + champ.given + " 整体胜率 " + rateText(champ) + "，" + window.HEX_MATCH.label(band) + "。下面按" + sortLabel() + "留前 " + rows.length + "。不足 100 场会标出来。";
      current = rows;
      renderRows(rows, false, true);
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
      const rows = takeHex(merged);
      const names = hexHits.slice(0, 3).map((augment) => augment.zh).join("、");
      hintEl.textContent = "海克斯对上 " + names + (hexHits.length > 3 ? " 等" : "") + "，按" + sortLabel() + "留前 " + rows.length + " 条。";
      current = rows;
      renderRows(rows, true, true);
      return;
    }

    hintEl.textContent = "没有对上的英雄或海克斯。";
    listEl.innerHTML = '<div class="empty-state"><strong>没有结果</strong><p>换个简称。这里不列没有胜率的搭配。</p></div>';
  }

  function renderBuild(champ) {
    const pack = window.HEX_BUILDS;
    if (!pack || !pack.champions) {
      listEl.innerHTML = '<div class="empty-state"><strong>出装数据没有读到</strong><p>确认 builds.js 和页面在同一目录。</p></div>';
      return;
    }
    const build = pack.champions[champ.key];
    const meta = pack.meta;
    if (!build || (!build.starter && !build.boots && !build.core)) {
      listEl.innerHTML = '<div class="empty-state"><strong>暂无数据</strong><p>这个英雄在海克斯大乱斗出装页上没有出门装，也没有后续顺序。</p></div>';
      return;
    }
    listEl.innerHTML =
      '<article class="build">' +
      '<p class="build-warn">' + esc(meta.modeLabel) + "</p>" +
      '<p class="build-scope">来源 ' + esc(meta.sourceName) + "，补丁 " + esc(meta.patch) +
      "，页面数据日期 " + esc(meta.dataDate) + "，" + esc(meta.fetchedAt) + " 打开。" +
      esc(meta.region) + "。" + esc(meta.mapNote) +
      (window.HEX_ITEM_ICONS && window.HEX_ITEM_ICONS.note ? esc(window.HEX_ITEM_ICONS.note) : "") +
      "</p>" +
      '<p class="build-sub">' + esc(meta.rule) + "</p>" +
      setsBlock("出门装", build.starter, "来源没有出门装。") +
      setsBlock("鞋子", build.boots, "来源没有鞋子这一步。") +
      setsBlock("核心", build.core, "来源没有后续核心顺序。") +
      "</article>";
  }

  function setsBlock(title, block, emptyText) {
    const sets = block && block.sets ? block.sets : [];
    if (!sets.length) {
      return "<h3>" + title + "</h3>" + '<p class="build-sub">' + emptyText + "</p>";
    }
    const listed = block.listed || sets.length;
    const note = listed > sets.length
      ? "来源共 " + listed + " 套，这里按登场率留前 " + sets.length + " 套。"
      : "来源这一栏有 " + listed + " 套。";
    return "<h3>" + title + "</h3>" +
      '<p class="build-sub">' + note + "</p>" +
      sets.map(function (set, index) {
        return '<div class="set" data-set="' + (index + 1) + '">' +
          '<p class="set-no">' + setLabel(index) + "</p>" +
          itemRow(set.items) +
          '<p class="build-sub">登场率 ' + esc(set.pick) + "，胜率 " + esc(set.win) + "。</p>" +
          "</div>";
      }).join("");
  }

  function setLabel(index) {
    const names = ["第一套", "第二套", "第三套"];
    return names[index] || ("第" + (index + 1) + "套");
  }

  function itemRow(items) {
    return '<div class="item-row">' + items.map(function (name, index) {
      return (index ? '<span class="item-arrow" aria-hidden="true">→</span>' : "") + itemChip(name);
    }).join("") + "</div>";
  }

  function itemChip(name) {
    const icons = window.HEX_ITEM_ICONS;
    const file = icons && icons.files ? icons.files[name] : "";
    if (!file || !icons.base) {
      return '<span class="item item-missing"><b>' + esc(name) + '</b><span class="miss">缺图</span></span>';
    }
    return '<span class="item"><img src="' + esc(icons.base + file) + '" alt="' + esc(name) +
      '" width="48" height="48"><span class="item-name">' + esc(name) + "</span></span>";
  }

  function takeHex(rows) {
    const list = rows.filter((row) => {
      if (hexRarity !== "all" && row.augment.rarityZh !== hexRarity) return false;
      if (hexSample === "100" && row.games < 100) return false;
      return true;
    });
    list.sort(compareHex);
    return list.slice(0, 10);
  }

  function compareHex(a, b) {
    if (hexSort === "games") return b.games - a.games || b.win - a.win;
    if (hexSort === "delta") return (b.delta - a.delta) || b.games - a.games;
    return b.win - a.win || b.games - a.games;
  }

  function sortLabel() {
    if (hexSort === "games") return "场次";
    if (hexSort === "delta") return "相对未选取";
    return "胜率";
  }

  function hexTools() {
    const sorts = [["win", "胜率"], ["delta", "相对未选取"], ["games", "场次"]];
    const rarities = [["all", "稀有度不限"], ["棱彩阶", "棱彩"], ["黄金阶", "黄金"], ["白银阶", "白银"]];
    const samples = [["all", "场次不限"], ["100", "至少 100 场"]];
    return '<div class="filters">' +
      chipRow("hex-sort", sorts, hexSort) +
      chipRow("hex-rarity", rarities, hexRarity) +
      chipRow("hex-sample", samples, hexSample) +
      '<p class="filter-note">相对未选取来自 Mayhem:Meta：选取时胜率减去未选取时的对照胜率。页面不计算 Hexdata 的 HexScore，也不估算海斗分。</p></div>';
  }

  function chipRow(attr, items, current) {
    return '<div class="filter-row">' + items.map(function (item) {
      const on = item[0] === current ? " on" : "";
      return '<button type="button" class="chip' + on + '" data-' + attr + '="' + esc(item[0]) + '">' + item[1] + "</button>";
    }).join("") + "</div>";
  }

  function renderRows(rows, showChamp, withTools) {
    const tools = withTools ? hexTools() : "";
    if (!rows.length) {
      listEl.innerHTML = tools + '<div class="empty-state"><strong>这个筛选下没有海克斯</strong><p>来源里没有同时满足稀有度、场次，并且写了胜率的搭配。换一个筛选再看。</p></div>';
      return;
    }
    listEl.innerHTML = tools + rows.map((row, index) => {
      const small = row.games < 100;
      const delta = Number.isFinite(row.delta)
        ? '<span class="delta">相对未选取 ' + signed(row.delta) + " 个百分点</span>"
        : "";
      return '<button type="button" class="card" data-index="' + index + '">' +
        '<span class="rank">' + (index + 1) + "</span>" +
        "<span><span class=\"who\">" + esc(showChamp ? row.champ.title + " · " + row.champ.given + " + " + row.augment.zh : row.augment.zh) + "</span>" +
        '<span class="hex">' + esc(row.augment.rarityZh) + (showChamp ? "" : " · " + esc(row.champ.title)) +
        (small ? ' · <span class="sample-tag">不足 100 场</span>' : "") + "</span>" +
        delta + "</span>" +
        '<span class="win">' + pct(row.win) + "</span>" +
        '<span class="games">' + num(row.games) + " 场</span></button>";
    }).join("");
  }

  function renderSkills(champ) {
    const pack = window.HEX_SKILLS;
    const row = pack && pack.champions ? pack.champions[champ.key] : null;
    if (!row || (!row.aram && !row.opgg)) {
      listEl.innerHTML = '<div class="empty-state"><strong>暂无数据</strong><p>这个英雄没有分开的加点来源。</p></div>';
      return;
    }
    const meta = pack.meta || {};
    listEl.innerHTML =
      '<article class="build">' +
      '<p class="build-warn">技能加点</p>' +
      '<p class="build-sub">' + esc(meta.note || "") + "</p>" +
      skillBlock(row.aram, "aram") +
      skillBlock(row.opgg, "opgg") +
      "</article>";
  }

  function skillBlock(block, kind) {
    if (!block) {
      return "<h3>来源</h3>" + '<p class="build-sub">来源没有加点。</p>';
    }
    const scope = kind === "opgg"
      ? esc(block.sourceName) + "，补丁 " + esc(block.patch) + "。页面没有登场率或胜率。"
      : esc(block.sourceName) + "，补丁 " + esc(block.patch) + "，页面数据日期 " + esc(block.dataDate) + "。";
    let body = "<h3>" + esc(block.sourceName) + "</h3>" + '<p class="build-sub">' + scope + "</p>";
    if (block.priority) {
      body += '<p class="set-no">主升</p><p class="starter">' + arrows(block.priority) + "</p>" +
        '<p class="build-sub">登场率 ' + esc(block.pick) + "，胜率 " + esc(block.win) + "。</p>";
    }
    if (block.sequence) {
      const label = kind === "opgg" ? "逐级顺序" : "登场率最高的逐级顺序";
      body += '<p class="set-no">' + label + '</p><p class="starter">' + arrows(block.sequence) + "</p>";
      if (block.sequencePick) {
        body += '<p class="build-sub">登场率 ' + esc(block.sequencePick) + "，胜率 " + esc(block.sequenceWin) + "。</p>";
      }
    }
    return body;
  }

  function arrows(order) {
    return String(order).split(/[\s>]+/).filter(Boolean).map(esc).join(" → ");
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
      '<div class="note"><p>选取时胜率 ' + pct(row.win) + "，未选取时 " + pct(row.base) + "，差 " + signed(row.delta) + " 个百分点。" +
      (row.games < 100 ? " 这一条不足 100 场。" : "") + "</p>" +
      "<p>来源 <a href=\"" + page + "\" target=\"_blank\" rel=\"noreferrer\">" + esc(page) + "</a>。补丁 " +
      data.meta.patch + "，抓取 " + data.meta.fetchedAt + "。" + esc(mapNote) + "</p></div></div>";
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
