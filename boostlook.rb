Asciidoctor::Extensions.register do
  postprocessor do
    process do |doc, output|
      output = output.sub(/<body(.*?)>/, '<body\\1><div class="boostlook">')
      output = output.sub(/<\/body>/, "</div></body>")
      output = output.sub(/(<div id="toc".*?>)/, '<button id="toggle-toc" title="Show Table of Contents" aria-expanded="false" aria-controls="toc">☰</button>\\1')

      output = output.sub(/(<div id="footer".*?>)/, '</div>\\1')

      inline_script = <<~SCRIPT
        <script>
        (function() {
          var isVisible = localStorage.getItem('tocVisible') === 'true';
          var isPinned = localStorage.getItem('tocPinned') === 'true';
          document.documentElement.classList.toggle('toc-visible', isVisible);
          document.documentElement.classList.toggle('toc-hidden', !isVisible);
          document.documentElement.classList.toggle('toc-pinned', isPinned);
        })();
        </script>
      SCRIPT
      output = output.sub(/<\/head>/, "#{inline_script}</head>")

      script_tag = <<~SCRIPT
        <script>
        document.addEventListener("DOMContentLoaded", (event) => {
          const tocButton = document.getElementById("toggle-toc");
          const toc = document.getElementById("toc");
          const html = document.documentElement;

          let isVisible = localStorage.getItem("tocVisible") === "true";
          let isPinned = localStorage.getItem("tocPinned") === "true";

          function updateTocVisibility(visible) {
            html.classList.toggle("toc-visible", visible);
            html.classList.toggle("toc-hidden", !visible);
            tocButton.setAttribute("aria-expanded", visible);
            tocButton.textContent = visible ? "×" : "☰";
            tocButton.setAttribute("title", visible ? "Hide Table of Contents" : "Show Table of Contents");
          }

          function updateTocPinned(pinned) {
            html.classList.toggle("toc-pinned", pinned);
            localStorage.setItem("tocPinned", pinned);
          }

          tocButton.addEventListener("click", () => {
            isVisible = !isVisible;
            isPinned = !isPinned;
            updateTocVisibility(isVisible);
            updateTocPinned(isPinned);
            localStorage.setItem("tocVisible", isVisible);
            localStorage.setItem("tocPinned", isPinned);
          });

          tocButton.addEventListener("mouseenter", () => {
            if (!isVisible) {
              updateTocVisibility(true);
            }
          });

          toc.addEventListener("mouseleave", () => {
            if (!isVisible) {
              updateTocVisibility(false);
            }
          });

          updateTocVisibility(isVisible);
        });
        </script>
      SCRIPT
      output = output.sub(/<\/body>/, "#{script_tag}</body>")

      output
    end
  end
end
