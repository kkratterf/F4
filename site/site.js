// F4 website: the few interactions of the page (the same shape as Maramao's site.js).

(function () {
  "use strict";

  var still = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  // A sticker that fails to load (Google Fonts down or blocked) leaves its
  // coloured tile instead of a broken-image icon.
  document.addEventListener("error", function (e) {
    var img = e.target;
    if (img && img.tagName === "IMG" && img.closest(".f4p-cell, .pasted, .clip")) img.style.visibility = "hidden";
  }, true);
  document.addEventListener("load", function (e) {
    var img = e.target;
    if (img && img.tagName === "IMG") img.style.visibility = "";
  }, true);
  document.querySelectorAll(".f4p-cell img, .pasted img, .clip img").forEach(function (img) {
    if (img.complete && img.getAttribute("src") && !img.naturalWidth) img.style.visibility = "hidden";
  });

  // Tabs: one screen on stage at a time. Images in hidden panels are lazy,
  // so they load only once their tab is picked.
  document.querySelectorAll("[data-tabs]").forEach(function (box) {
    var tabs = Array.prototype.slice.call(box.querySelectorAll('[role="tab"]'));
    function select(tab, focus) {
      tabs.forEach(function (t) {
        var on = t === tab;
        t.setAttribute("aria-selected", on ? "true" : "false");
        t.tabIndex = on ? 0 : -1;
        document.getElementById(t.getAttribute("aria-controls")).hidden = !on;
      });
      if (focus) tab.focus();
    }
    tabs.forEach(function (tab, i) {
      tab.addEventListener("click", function () { select(tab); });
      tab.addEventListener("keydown", function (e) {
        var step = { ArrowDown: 1, ArrowRight: 1, ArrowUp: -1, ArrowLeft: -1 }[e.key];
        if (!step) return;
        e.preventDefault();
        select(tabs[(i + step + tabs.length) % tabs.length], true);
      });
    });
  });

  // The hero Mac: a chat, then F4 opens over it, a few letters find a
  // sticker, Enter pastes it into the chat, and again. Only the selected
  // sticker plays, like in the app. With reduced motion it stays on the open panel.
  var demo = document.querySelector("[data-demo]");
  if (demo && !still) {
    var query = demo.querySelector("[data-demo-query]");
    var picked = demo.querySelector("[data-demo-picked]");
    var hint = demo.querySelector("[data-demo-hint]");
    var pasted = demo.querySelector("[data-demo-pasted]");
    var cells = Array.prototype.slice.call(demo.querySelectorAll("[data-demo-grid] .f4p-cell"));
    var words = ["joy", "dai", "skull", "basito", "party", "nope"];
    var step = 0;
    var later = function (ms) { return new Promise(function (r) { setTimeout(r, ms); }); };
    var setState = function (s) { demo.setAttribute("data-state", s); };

    // Fuzzy, like F4Core's FuzzySearch: the letters in order, gaps allowed.
    var matches = function (name, q) {
      var i = 0;
      for (var c = 0; c < name.length && i < q.length; c++) if (name[c] === q[i]) i++;
      return i === q.length;
    };
    var select = function (q) {
      var first = null;
      cells.forEach(function (cell) {
        var hit = matches(cell.dataset.name, q);
        cell.classList.toggle("dim", !hit);
        if (hit && !first) first = cell;
      });
      cells.forEach(function (cell) {
        var on = cell === first;
        cell.classList.toggle("on", on);
        // Text stickers are drawn in CSS and have no image to swap.
        var img = cell.querySelector("img");
        if (!img || !cell.dataset.anim) return;
        var src = on ? cell.dataset.anim : cell.dataset.still;
        if (img.getAttribute("src") !== src) img.src = src;
      });
      if (first) picked.textContent = first.dataset.name;
      return first;
    };
    var type = function (word) {
      query.textContent = "";
      var n = 0;
      return new Promise(function (done) {
        var t = setInterval(function () {
          n++;
          query.textContent = word.slice(0, n);
          select(query.textContent);
          if (n >= word.length) { clearInterval(t); done(); }
        }, 150);
      });
    };
    var loop = function () {
      var word = words[step];
      step = (step + 1) % words.length;
      setState("chat");
      query.textContent = "";
      hint.textContent = demo.dataset.copy;
      return later(1400)
        .then(function () { setState("panel"); return later(500); })
        .then(function () { return type(word); })
        .then(function () { return later(1300); })
        .then(function () {
          var hit = select(word);
          hint.textContent = demo.dataset.copied;
          if (hit) {
            pasted.innerHTML = hit.innerHTML;
            var img = pasted.querySelector("img");
            if (img && hit.dataset.anim) img.src = hit.dataset.anim;
          }
          return later(700);
        })
        .then(function () { setState("paste"); return later(3400); })
        .then(loop);
    };
    select("joy");
    later(2200).then(loop);
  }

  // FAQ accordion: every answer is open without JavaScript. With it they
  // start closed and slide open.
  document.querySelectorAll("[data-accordion] .acc-trigger").forEach(function (btn) {
    var panel = document.getElementById(btn.getAttribute("aria-controls"));
    if (!panel) return;
    btn.setAttribute("aria-expanded", "false");
    panel.hidden = true;
    btn.addEventListener("click", function () {
      var open = btn.getAttribute("aria-expanded") === "true";
      btn.setAttribute("aria-expanded", open ? "false" : "true");
      if (still) { panel.hidden = open; return; }
      if (!open) {
        panel.hidden = false;
        var h = panel.scrollHeight;
        panel.style.height = "0px";
        requestAnimationFrame(function () { panel.style.height = h + "px"; });
      } else {
        panel.style.height = panel.scrollHeight + "px";
        requestAnimationFrame(function () { panel.style.height = "0px"; });
      }
      panel.addEventListener("transitionend", function done() {
        panel.removeEventListener("transitionend", done);
        if (btn.getAttribute("aria-expanded") === "false") panel.hidden = true;
        panel.style.height = "";
      });
    });
  });

  // The Download buttons link releases/latest/download/F4.dmg, which always
  // serves the newest DMG. The GitHub API only fills in the version number.
  var api = "https://api.github.com/repos/kkratterf/f4";
  var json = function (url) {
    return fetch(url, { headers: { Accept: "application/vnd.github+json" } }).then(function (r) { return r.ok ? r.json() : null; });
  };
  var versions = document.querySelectorAll("[data-version]");
  if (versions.length && window.fetch) {
    json(api + "/releases/latest")
      .then(function (release) {
        if (!release || !release.tag_name) return;
        versions.forEach(function (el) { el.textContent = release.tag_name.replace(/^v/, ""); });
      })
      .catch(function () {});
  }

  // GitHub button: just the icon until the repository has 10 stars.
  var stars = document.querySelectorAll("[data-stars]");
  if (stars.length && window.fetch) {
    json(api)
      .then(function (repo) {
        var n = repo && repo.stargazers_count;
        if (!n || n < 10) return;
        var label = n >= 1000 ? (n / 1000).toFixed(n >= 10000 ? 0 : 1).replace(/\.0$/, "") + "k" : String(n);
        stars.forEach(function (el) {
          var span = document.createElement("span");
          span.textContent = label;
          el.appendChild(span);
          el.setAttribute("aria-label", el.getAttribute("aria-label") + ", " + n + " ★");
        });
      })
      .catch(function () {});
  }
})();
