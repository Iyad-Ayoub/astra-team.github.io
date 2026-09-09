// Filter existing static rows; no requests, framework, or DOM reconstruction.
document.addEventListener("DOMContentLoaded", () => {
  const archive = document.querySelector(".astra-publications");
  if (!archive) return;
  const input = archive.querySelector("#bibsearch");
  const year = archive.querySelector("#publication-year");
  const type = archive.querySelector("#publication-type");
  const count = archive.querySelector("#publication-count");
  const empty = archive.querySelector("#publication-empty");
  const normalize = value => value.toLocaleLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "");
  const groups = [...archive.querySelectorAll(".publication-year")].map(section => ({
    section,
    count: section.querySelector(".publication-year-count"),
    records: [...section.querySelectorAll(".publication-record")].map(record => ({
      record,
      row: record.closest("li"),
      text: normalize(record.querySelector(".publication-main").textContent + " " + record.dataset.keywords),
    })),
  }));
  const total = groups.reduce((sum, group) => sum + group.records.length, 0);
  const plural = n => n === 1 ? "publication" : "publications";
  function filter() {
    const words = normalize(input.value.trim()).split(/\s+/).filter(Boolean);
    let visible = 0;
    groups.forEach(group => {
      let matches = 0;
      group.records.forEach(({ record, row, text }) => {
        const show = (!year.value || record.dataset.year === year.value) &&
          (!type.value || record.dataset.type === type.value) &&
          words.every(word => text.includes(word));
        row.hidden = !show;
        if (show) matches++;
      });
      group.section.hidden = matches === 0;
      group.count.textContent = matches === group.records.length
        ? `${matches} ${plural(matches)}`
        : `${matches} of ${group.records.length} publications`;
      visible += matches;
    });
    const active = input.value.trim() || year.value || type.value;
    count.textContent = active ? `${visible} of ${total} publications` : `${total} ${plural(total)}`;
    empty.hidden = visible !== 0;
  }
  let timer;
  input.addEventListener("input", () => { clearTimeout(timer); timer = setTimeout(filter, 120); });
  year.addEventListener("change", filter);
  type.addEventListener("change", filter);
  function fromHash() {
    let hash;
    try { hash = decodeURIComponent(location.hash.slice(1)); } catch { hash = ""; }
    // Preserve citation-key anchors as anchors, and legacy author/search hashes as searches.
    const target = document.getElementById(hash);
    const anchor = target && archive.contains(target);
    input.value = anchor ? "" : hash;
    year.value = "";
    type.value = "";
    filter();
    if (anchor) target.scrollIntoView();
  }
  window.addEventListener("hashchange", fromHash);
  archive.querySelector(".publication-controls").hidden = false;
  fromHash();
});
