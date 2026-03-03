Asciidoctor::Extensions.register do
  postprocessor do
    process do |doc, output|
      output = output.sub(/(<body[^>]*>)/, '\1<div class="boostlook">')
      output = output.sub('</body>', '</div></body>')
      # Comment out toggle button - TOC should always be visible
      # output = output.sub(/(<body.*?<div[^>]*id="toc"[^>]*>)/m, '\1<button id="toggle-toc" title="Show Table of Contents" aria-expanded="false" aria-controls="toc">☰</button>')
      output = output.sub(/(<body.*?<div[^>]*id="footer"[^>]*>)/m, '</div>\1')

      script_tag = <<~SCRIPT
        <script>
        (function() {
          var html = document.documentElement;
          // Always show TOC - no toggle functionality needed
          html.classList.add('toc-visible');
          html.classList.add('toc-pinned');
          html.classList.remove('toc-hidden');

          document.addEventListener("DOMContentLoaded", function() {
            // Collapsible TOC sections
            var toc = document.getElementById('toc');
            if (!toc) return;
            // Only apply to Asciidoctor TOC (has sectlevel lists, no nav-container)
            if (toc.classList.contains('nav-container')) return;

            var items = toc.querySelectorAll('li');
            var collapsibleItems = [];
            for (var i = 0; i < items.length; i++) {
              var childUl = items[i].querySelector(':scope > ul');
              if (childUl) collapsibleItems.push(items[i]);
            }
            if (collapsibleItems.length === 0) return;

            // Build storage key from page title
            var tocTitle = document.getElementById('toctitle');
            var storageKey = 'boostlook-toc-state:' + (tocTitle ? tocTitle.textContent.trim() : document.title);

            function getItemLabel(li) {
              var a = li.querySelector(':scope > a');
              return a ? a.textContent.trim() : '';
            }

            function saveState() {
              var activeLabels = [];
              for (var i = 0; i < collapsibleItems.length; i++) {
                if (collapsibleItems[i].classList.contains('is-active')) {
                  activeLabels.push(getItemLabel(collapsibleItems[i]));
                }
              }
              try {
                localStorage.setItem(storageKey, JSON.stringify(activeLabels));
              } catch(e) {}
            }

            function restoreState() {
              var saved;
              try {
                saved = JSON.parse(localStorage.getItem(storageKey));
              } catch(e) { return false; }
              if (!saved || !Array.isArray(saved)) return false;
              for (var i = 0; i < collapsibleItems.length; i++) {
                var label = getItemLabel(collapsibleItems[i]);
                if (saved.indexOf(label) !== -1) {
                  collapsibleItems[i].classList.add('is-active');
                }
              }
              return true;
            }

            function expandForHash() {
              var hash = window.location.hash;
              if (!hash) return;
              var target = toc.querySelector('a[href="' + hash + '"]');
              if (!target) return;
              var parent = target.closest('li.nav-item');
              while (parent) {
                parent.classList.add('is-active');
                parent = parent.parentElement.closest('li.nav-item');
              }
            }

            // Inject toggle buttons and set up click handlers
            for (var i = 0; i < collapsibleItems.length; i++) {
              (function(li) {
                var btn = document.createElement('button');
                btn.className = 'nav-item-toggle';
                btn.setAttribute('aria-label', 'Toggle section');
                li.insertBefore(btn, li.firstChild);
                li.classList.add('nav-item');
                li.style.cursor = 'pointer';

                li.addEventListener('click', function(e) {
                  if (e.target.closest('a')) return;
                  var childUl = li.querySelector(':scope > ul');
                  if (childUl && childUl.contains(e.target)) return;
                  li.classList.toggle('is-active');
                  saveState();
                });
              })(collapsibleItems[i]);
            }

            // Restore saved state, or use defaults (all collapsed)
            var hadSaved = restoreState();
            // Always expand section matching current hash
            expandForHash();
            // If no saved state and no hash, leave all collapsed (default)

            // Re-expand on hash change
            window.addEventListener('hashchange', function() {
              expandForHash();
              saveState();
            });
          });
        })();
        </script>
      SCRIPT

      output = output.sub('</body>', "#{script_tag}</body>")

      output
    end
  end
end
