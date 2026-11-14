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

  // "Try it here": a working copy of the panel. Type to search (fuzzy, like
  // F4Core's FuzzySearch), arrows move the selection, Enter or a click copies
  // the sticker (as a PNG, where the browser allows it) and closes the panel
  // with the "Copied to Clipboard" pill; a click opens it again. ⌘K opens the
  // actions (Copy, Favourites, Trash), with their shortcuts. The sticker just
  // copied moves to the front, like the app's Stickers tab. Once the panel
  // was clicked, the keys go to it wherever the focus is, until a click lands
  // outside it.
  (function () {
    var sim = document.querySelector("[data-sim]");
    if (!sim) return;
    var input = sim.querySelector("[data-sim-input]");
    var grid = sim.querySelector("[data-sim-grid]");
    var none = grid.querySelector(".sim-none");
    var picked = sim.querySelector("[data-sim-picked]");
    var toast = sim.querySelector("[data-sim-toast]");
    var pal = sim.querySelector("[data-sim-pal]");
    var palTitle = sim.querySelector("[data-sim-pal-title]");
    var palInput = sim.querySelector("[data-sim-pal-input]");
    var palNone = pal.querySelector(".sim-pal-none");
    var acts = Array.prototype.slice.call(pal.querySelectorAll(".sim-act"));
    var favAct = pal.querySelector('[data-act="fav"]');
    var all = Array.prototype.slice.call(grid.querySelectorAll(".sim-cell"));
    var shown = all.slice();
    var current = 0;
    var palShown = acts.slice();
    var palCurrent = 0;
    var toastTimer = null;
    var lastPointer = null;
    var active = false;

    var isOpen = function () { return sim.dataset.open !== "false"; };
    var palOpen = function () { return !pal.hidden; };
    var fuzzy = function (name, q) {
      var i = 0;
      for (var c = 0; c < name.length && i < q.length; c++) if (name[c] === q[i]) i++;
      return i === q.length;
    };
    var columns = function () {
      return getComputedStyle(grid).gridTemplateColumns.split(" ").length;
    };
    var select = function (i, scroll) {
      if (!shown.length) { picked.textContent = ""; return; }
      current = Math.max(0, Math.min(shown.length - 1, i));
      shown.forEach(function (cell, k) { cell.setAttribute("aria-selected", k === current ? "true" : "false"); });
      picked.textContent = shown[current].dataset.name;
      if (scroll) shown[current].scrollIntoView({ block: "nearest" });
    };
    var filter = function () {
      var q = input.value.trim().toLowerCase();
      shown = all.filter(function (cell) {
        var hit = !q || fuzzy(cell.dataset.name, q);
        cell.hidden = !hit;
        return hit;
      });
      none.hidden = shown.length > 0;
      select(0);
    };
    var focusInput = function () {
      (palOpen() ? palInput : input).focus({ preventScroll: true });
    };
    var closePalette = function () {
      pal.hidden = true;
      if (isOpen()) input.focus({ preventScroll: true });
    };
    var selectAction = function (i) {
      if (!palShown.length) return;
      palCurrent = (i + palShown.length) % palShown.length;
      acts.forEach(function (a) { a.classList.toggle("on", a === palShown[palCurrent]); });
    };
    var filterActions = function () {
      var q = palInput.value.trim().toLowerCase();
      palShown = acts.filter(function (a) {
        var hit = !q || a.textContent.toLowerCase().indexOf(q) !== -1;
        a.hidden = !hit;
        return hit;
      });
      palNone.hidden = palShown.length > 0;
      selectAction(0);
    };
    var openPalette = function () {
      var cell = shown[current];
      if (!cell || !isOpen()) return;
      palTitle.textContent = cell.dataset.name;
      favAct.querySelector("span").textContent = cell.classList.contains("fav") ? favAct.dataset.on : favAct.dataset.off;
      palInput.value = "";
      pal.hidden = false;
      filterActions();
      palInput.focus({ preventScroll: true });
    };
    var setOpen = function (open) {
      sim.dataset.open = open ? "true" : "false";
      pal.hidden = true;
      if (open) {
        input.value = "";
        filter();
        grid.scrollTop = 0;
        input.focus({ preventScroll: true });
      } else {
        input.blur();
        palInput.blur();
      }
    };
    var copyImage = function (img) {
      // Browsers put PNG on the clipboard, not WebP: redraw the sticker first.
      try {
        if (!navigator.clipboard || !window.ClipboardItem || !img.naturalWidth) return;
        var canvas = document.createElement("canvas");
        canvas.width = img.naturalWidth;
        canvas.height = img.naturalHeight;
        canvas.getContext("2d").drawImage(img, 0, 0);
        var blob = new Promise(function (done) { canvas.toBlob(done, "image/png"); });
        navigator.clipboard.write([new ClipboardItem({ "image/png": blob })]).catch(function () {});
      } catch (e) { /* the pill still shows: this is a demo */ }
    };
    var copy = function () {
      var cell = shown[current];
      if (!cell) return;
      copyImage(cell.querySelector("img"));
      grid.insertBefore(cell, grid.firstChild);
      all.splice(all.indexOf(cell), 1);
      all.unshift(cell);
      setOpen(false);
      toast.classList.add("on");
      clearTimeout(toastTimer);
      toastTimer = setTimeout(function () { toast.classList.remove("on"); }, 1600);
    };
    var favourite = function () {
      var cell = shown[current];
      if (cell) cell.classList.toggle("fav");
      closePalette();
    };
    var trash = function () {
      var cell = shown[current];
      if (!cell) return;
      all.splice(all.indexOf(cell), 1);
      cell.remove();
      closePalette();
      filterKeep();
    };
    // After a sticker leaves, keep the selection where it was.
    var filterKeep = function () {
      var at = current;
      filter();
      select(Math.min(at, shown.length - 1));
    };
    var run = function (act) {
      if (act === "copy") copy();
      else if (act === "fav") favourite();
      else if (act === "trash") trash();
    };

    // Every key of the panel, wherever the focus is while it is active.
    var onKey = function (e) {
      if (!isOpen()) return false;
      var mod = e.metaKey || e.ctrlKey;
      if (mod && (e.key === "k" || e.key === "K")) {
        if (palOpen()) closePalette(); else openPalette();
        return true;
      }
      if (palOpen()) {
        if (e.key === "ArrowDown") selectAction(palCurrent + 1);
        else if (e.key === "ArrowUp") selectAction(palCurrent - 1);
        else if (e.key === "Enter") { if (palShown[palCurrent]) run(palShown[palCurrent].dataset.act); }
        else if (e.key === "Escape") closePalette();
        else return false;
        return true;
      }
      if (mod && (e.key === "d" || e.key === "D")) { favourite(); return true; }
      if (mod && e.key === "Backspace") { trash(); return true; }
      var cols = columns();
      var step = { ArrowRight: 1, ArrowLeft: -1, ArrowDown: cols, ArrowUp: -cols }[e.key];
      if (step) {
        var next = current + step;
        if (next >= 0 && next < shown.length) select(next, true);
        else if (e.key === "ArrowDown" && current < shown.length - 1) select(shown.length - 1, true);
        return true;
      }
      if (e.key === "Enter") { copy(); return true; }
      if (e.key === "Escape") { setOpen(false); return true; }
      return false;
    };
    document.addEventListener("keydown", function (e) {
      var inside = e.target === input || e.target === palInput;
      if (!inside && !active) return;
      if (e.isComposing) return;
      if (onKey(e)) { e.preventDefault(); return; }
      // A letter typed while the focus is elsewhere goes to the search field.
      if (!inside && isOpen() && e.key.length === 1 && !e.metaKey && !e.ctrlKey && !e.altKey) focusInput();
    });
    document.addEventListener("pointerdown", function (e) {
      active = sim.contains(e.target);
    });

    input.addEventListener("input", filter);
    palInput.addEventListener("input", filterActions);
    // Like the app, the mouse selects a sticker only once it really moves.
    grid.addEventListener("mousemove", function (e) {
      var here = e.screenX + "," + e.screenY;
      if (here === lastPointer) return;
      lastPointer = here;
      if (palOpen()) return;
      var cell = e.target.closest(".sim-cell");
      if (cell && shown.indexOf(cell) !== current) select(shown.indexOf(cell));
    });
    grid.addEventListener("click", function (e) {
      var cell = e.target.closest(".sim-cell");
      if (!cell) return;
      if (palOpen()) { closePalette(); return; }
      select(shown.indexOf(cell));
      copy();
    });
    pal.addEventListener("mousemove", function (e) {
      var a = e.target.closest(".sim-act");
      if (a && palShown.indexOf(a) !== -1) selectAction(palShown.indexOf(a));
    });
    pal.addEventListener("click", function (e) {
      var a = e.target.closest(".sim-act");
      if (a) run(a.dataset.act);
    });
    sim.querySelector("[data-sim-copy]").addEventListener("click", copy);
    sim.querySelector("[data-sim-actions]").addEventListener("click", function () {
      if (palOpen()) closePalette(); else openPalette();
    });
    // Clicks never take the keyboard away from the search fields.
    sim.querySelector("[data-sim-panel]").addEventListener("mousedown", function (e) {
      if (e.target !== input && e.target !== palInput) { e.preventDefault(); focusInput(); }
    });
    // A click on the desktop opens the panel, or closes it, as F4 hides
    // when another app is clicked.
    sim.querySelector("[data-sim-desk]").addEventListener("click", function () {
      setOpen(!isOpen());
    });
    filter();
  })();

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
    var words = ["risata", "boh", "shock", "triste", "ti prego", "bleh"];
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
    select("boh");
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
