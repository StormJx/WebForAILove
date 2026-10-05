(function () {
  const data = window.HEX_ARAM;
  const pinyin = window.HEX_PINYIN;
  const match = window.HEX_MATCH;
  const overEl = document.getElementById("over");
  const underEl = document.getElementById("under");
  const noneEl = document.getElementById("none");
  const hintEl = document.getElementById("hint");
  const qEl = document.getElementById("q");

  if (!data || !pinyin || !match) {
    overEl.innerHTML = '<p class="empty-note">数据文件没有读到。</p>';
    return;
  }

  const mapNote = data.meta.maps.join("、");
  document.getElementById("lede").textContent =
    "补丁 " + data.meta.patch + "，" + data.meta.fetchedAt + " 抓取自 " + data.meta.sourceName +
    "。这是海克斯大乱斗的英雄整体胜率，三张地图合在一起：" + mapNote +
    "。站点未按单张地图拆开，也没有标成国服。没有胜率的英雄只出现在「没有数据」。";

  qEl.addEventListener("input", render);
  render();

  function render() {
    const query = match.normalize(qEl.value);
    const list = query ? match.champions(data, pinyin, query) : data.champions.slice();
    const groups = { over: [], under: [], none: [] };
    list.forEach(function (champ) {
      groups[match.band(champ)].push(champ);
    });
    groups.over.sort(byRate);
    groups.under.sort(byRate);
    groups.none.sort(function (a, b) { return a.title.localeCompare(b.title, "zh"); });

    hintEl.textContent = query
      ? "对上 " + list.length + " 个英雄。超过 50% 的 " + groups.over.length + " 个，未超过的 " + groups.under.length + " 个，没有数据的 " + groups.none.length + " 个。"
      : "全部有记录的英雄都在下面，按整体胜率从高到低。";

    document.getElementById("over-title").textContent = "超过 50% · " + groups.over.length;
    document.getElementById("under-title").textContent = "未超过 50% · " + groups.under.length;
    document.getElementById("none-title").textContent = "没有数据 · " + groups.none.length;
    fill(overEl, groups.over, "这侧没有对上的英雄。");
    fill(underEl, groups.under, "这侧没有对上的英雄。");
    fill(noneEl, groups.none, "这批英雄都有整体胜率，没有人被放进这里。");
  }

  function fill(el, champs, emptyText) {
    if (!champs.length) {
      el.innerHTML = '<p class="empty-note">' + emptyText + "</p>";
      return;
    }
    el.innerHTML = champs.map(function (champ) {
      const band = match.band(champ);
      const rate = band === "none" ? "没有数据" : pct(champ.winRate);
      const games = champ.games == null ? "" : '<span class="sub">' + Number(champ.games).toLocaleString("zh-CN") + " 场</span>";
      return '<article class="hero ' + band + '"><div><b>' + esc(champ.title) + " · " + esc(champ.given) + "</b>" + games + "</div>" +
        '<span class="band">' + esc(match.label(band)) + "<strong>" + rate + "</strong></span></article>";
    }).join("");
  }

  function byRate(a, b) {
    return Number(b.winRate) - Number(a.winRate);
  }
  function pct(value) { return Number(value).toFixed(2) + "%"; }
  function esc(value) {
    return String(value).replace(/[&<>"']/g, function (char) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[char];
    });
  }
})();
