# boostlook.rb — Asciidoctor postprocessor for Boostlook 2.0 (boostlook.css)
#
# Wraps rendered output in <div class="boostlook"> — the scope every v3 selector
# lives under — and injects the client-side behavior the CSS expects, so docs get
# it automatically without a per-document docinfo footer:
#   * keeps the left TOC visible/pinned
#   * turns the Asciidoctor :toc: into a collapsible nav-tree matching the Antora
#     nav: caret toggles, collapsed by default, current path expanded,
#     open sections persisted, and scroll-spy active-link highlighting.
#
# Caret/collapse styling lives in boostlook.css (src/css/12-asciidoctor.css).
#
# Usage:  asciidoctor -r ./boostlook.rb ... doc.adoc

Asciidoctor::Extensions.register do
  postprocessor do
    process do |doc, output|
      # Wrap the body content in the .boostlook scope (footer kept outside).
      output = output.sub(/(<body[^>]*>)/, '\1<div class="boostlook">')
      output = output.sub('</body>', '</div></body>')
      output = output.sub(/(<body.*?<div[^>]*id="footer"[^>]*>)/m, '</div>\1')

      scripts = <<~'HTML'
        <script>
        (function () {
          var html = document.documentElement;
          html.classList.add('toc-visible', 'toc-pinned');
          html.classList.remove('toc-hidden');
        })();
        </script>
        <script>
        /*
         * Collapsible TOC — mirrors the Antora nav-tree (01-nav.js): parent items
         * get .nav-item + a .nav-item-toggle caret, branches are collapsed by
         * default (.is-active expands them), the current section's path is
         * expanded, open sections persist, and the section in view is highlighted
         * via .is-active-link. Caret/collapse styling lives in boostlook.css.
         */
        (function () {
          function init() {
            var toc = document.querySelector('#toc');
            if (!toc) return;

            var labelOf = function (li) {
              var a = li.querySelector(':scope > a');
              return a ? a.textContent.trim() : null;
            };
            var setOpen = function (li, open) {
              li.classList.toggle('is-active', open);
              var btn = li.querySelector(':scope > .nav-item-toggle');
              if (btn) btn.setAttribute('aria-expanded', open ? 'true' : 'false');
            };
            var expandPath = function (li) {
              for (var n = li; n && n !== toc; n = n.parentNode) {
                if (n.classList && n.classList.contains('nav-item')) setOpen(n, true);
              }
            };

            // Decorate every parent item with .nav-item + a caret toggle.
            Array.prototype.forEach.call(toc.querySelectorAll('li'), function (li) {
              if (!li.querySelector(':scope > ul')) return;
              li.classList.add('nav-item');
              var btn = document.createElement('button');
              btn.type = 'button';
              btn.className = 'nav-item-toggle';
              btn.setAttribute('aria-label', 'Toggle section');
              btn.setAttribute('aria-expanded', 'false');
              li.insertBefore(btn, li.firstChild);
            });

            var navItems = Array.prototype.slice.call(toc.querySelectorAll('.nav-item'));

            // Persist open sections (like Antora's nav-open-sections).
            var KEY = 'boostlook-toc-open:' + (document.title || 'doc');
            var save = function () {
              try {
                localStorage.setItem(KEY, JSON.stringify(
                  navItems.filter(function (li) { return li.classList.contains('is-active'); })
                    .map(labelOf).filter(Boolean)
                ));
              } catch (e) {}
            };
            var hadSaved = false;
            try {
              var saved = JSON.parse(localStorage.getItem(KEY));
              if (saved && saved.length) {
                navItems.forEach(function (li) {
                  if (saved.indexOf(labelOf(li)) !== -1) setOpen(li, true);
                });
                hadSaved = true;
              }
            } catch (e) {}

            // Click the row (not the link or a nested list) to toggle.
            navItems.forEach(function (li) {
              li.addEventListener('click', function (e) {
                if (e.target.closest('a')) return;
                var sub = li.querySelector(':scope > ul');
                if (sub && sub.contains(e.target)) return;
                setOpen(li, !li.classList.contains('is-active'));
                save();
              });
            });

            // Scroll-spy: highlight the section in view (.is-active-link). The
            // .boostlook wrapper is the scroll container (html has overflow:hidden),
            // and on mobile it's the window — so listen on every plausible scroller
            // and measure with viewport-relative rects.
            var links = Array.prototype.slice.call(toc.querySelectorAll('a[href^="#"]'));
            var byId = {};
            links.forEach(function (a) {
              var id = decodeURIComponent(a.getAttribute('href').slice(1));
              if (id && document.getElementById(id)) byId[id] = a;
            });
            var headings = Object.keys(byId).map(function (id) { return document.getElementById(id); });
            var activeLi = null;
            var spyLock = false, spyTimer; // ignore scroll-spy during click-driven scroll
            var relock = function () {
              spyLock = true;
              clearTimeout(spyTimer);
              spyTimer = setTimeout(function () { spyLock = false; }, 150);
            };
            var setActive = function () {
              if (spyLock) return;
              var line = 130, current = null;
              headings.forEach(function (h) {
                if (h.getBoundingClientRect().top - line <= 0) current = h;
              });
              if (!current && headings.length) current = headings[0];
              links.forEach(function (a) { a.classList.remove('is-active-link'); });
              if (current && byId[current.id]) {
                byId[current.id].classList.add('is-active-link');
                activeLi = byId[current.id].closest('li');
              }
            };
            var ticking = false;
            var onScroll = function () {
              if (spyLock) { relock(); return; } // keep the lock through the click-scroll
              if (!ticking) { ticking = true; requestAnimationFrame(function () { ticking = false; setActive(); }); }
            };
            [document.querySelector('.boostlook'),
             document.querySelector('.article.toc2.toc-left'),
             window].forEach(function (el) {
              if (el) el.addEventListener('scroll', onScroll, { passive: true });
            });
            // A click highlights exactly the clicked link; lock the spy through the
            // scroll that follows so it can't bump the highlight to the next heading.
            links.forEach(function (a) {
              a.addEventListener('click', function () {
                relock();
                links.forEach(function (l) { l.classList.remove('is-active-link'); });
                a.classList.add('is-active-link');
                var li = a.closest('li');
                if (li) { activeLi = li; expandPath(li); }
              });
            });
            setActive();

            // On first load (no saved state) expand the current section's path so
            // the tree isn't fully collapsed; otherwise honor what was open.
            if (!hadSaved) {
              var hashLink = location.hash && toc.querySelector('a[href="' + location.hash + '"]');
              var startLi = (hashLink && hashLink.closest('li')) || activeLi || (navItems[0] || null);
              if (startLi) expandPath(startLi);
            }
          }
          if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
          else init();
        })();
        </script>
      HTML

      # Theme init — mirror the Antora UI (head-scripts.hbs + 00-theme-toggle.js)
      # so standalone AsciiDoctor docs follow the user's OS theme. Injected at the
      # top of <head> so html.dark is set before first paint (no flash). Honors a
      # saved 'antora-theme' choice if present, otherwise prefers-color-scheme, and
      # live-updates on OS changes unless the user has pinned a theme. Skipped when
      # embedded in an iframe (the host page controls the theme there).
      theme = <<~'HTML'
        <script>
        (function () {
          if (window.self !== window.top) return;
          var html = document.documentElement;
          function prefersDark() {
            return !!(window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches);
          }
          try {
            var saved = localStorage.getItem('antora-theme');
            html.classList.toggle('dark', saved ? saved === 'dark' : prefersDark());
          } catch (e) {
            if (prefersDark()) html.classList.add('dark');
          }
          if (window.matchMedia) {
            var mq = window.matchMedia('(prefers-color-scheme: dark)');
            var onChange = function (e) {
              try { if (localStorage.getItem('antora-theme')) return; } catch (_) {}
              html.classList.toggle('dark', e.matches);
            };
            if (mq.addEventListener) mq.addEventListener('change', onChange);
            else if (mq.addListener) mq.addListener(onChange);
          }
        })();
        </script>
      HTML

      output = output.sub(/<head[^>]*>/) { |m| m + theme }
      output.sub('</body>', "#{scripts}</body>")
    end
  end
end
