window.HEX_MATCH = {
  normalize: function (value) {
    return String(value || "").trim().toLowerCase().replace(/\s+/g, "");
  },
  band: function (champ) {
    if (champ.winRate == null || champ.winRate === "") return "none";
    return Number(champ.winRate) > 50 ? "over" : "under";
  },
  label: function (band) {
    if (band === "over") return "超过 50%";
    if (band === "under") return "未超过 50%";
    return "没有数据";
  },
  champions: function (data, pinyin, query) {
    return data.champions
      .map(function (champ) {
        return { champ: champ, rank: rank(champ, pinyin, query) };
      })
      .filter(function (item) { return item.rank >= 0; })
      .sort(function (a, b) {
        return a.rank - b.rank || (Number(b.champ.winRate) || -1) - (Number(a.champ.winRate) || -1);
      })
      .map(function (item) { return item.champ; });
  },
};

function rank(champ, pinyin, query) {
  const py = pinyin.champions[champ.key];
  if (!py || !query) return -1;
  if (py.givenInit === query || py.givenFull === query || champ.given.toLowerCase() === query) return 0;
  if (py.titleInit === query || py.titleFull === query || champ.title.toLowerCase() === query) return 1;
  if (py.en === query || py.enInit === query || champ.key === query) return 2;
  const keys = [py.givenInit, py.givenFull, py.titleInit, py.titleFull, py.en, py.enInit, champ.key, champ.given.toLowerCase(), champ.title.toLowerCase()];
  return keys.some(function (key) { return key && key.startsWith(query); }) ? 3 : -1;
}
