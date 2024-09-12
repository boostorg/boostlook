Asciidoctor::Extensions.register do
  postprocessor do
    process do |doc, output|
      output = output.sub(/<body(.*?)>/, '<body\\1><div class="boostlook">')
      output = output.sub(/<\/body>/, "</div></body>")

      output = output.sub(/(<div id="toc".*?>)/, '<button id="toggle-toc" title="Toggle Table of Contents" aria-expanded="true" aria-controls="toc">Toggle TOC</button>\\1')
      output = output.sub(/(<div id="footer".*?>)/, '</div>\\1')

      inline_script = <<~SCRIPT
        <script>
        (function() {
          if (localStorage.getItem('tocVisible') === 'false') {
            document.documentElement.classList.add('toc-hidden');
          }
        })();
        </script>
      SCRIPT
      output = output.sub(/<\/head>/, "#{inline_script}</head>")

      script = <<~SCRIPT
        <script>
          document.addEventListener('DOMContentLoaded', (event) => {
          const tocButton = document.getElementById('toggle-toc');
          const toc = document.getElementById('toc');
          const html = document.documentElement;
          
          if (tocButton && toc) {
            const tocVisible = !html.classList.contains('toc-hidden');
            updateTocVisibility(tocVisible);
            
            tocButton.addEventListener('click', () => {
              const newState = html.classList.contains('toc-hidden');
              updateTocVisibility(newState);
              localStorage.setItem('tocVisible', newState);
            });
          }
          
          function updateTocVisibility(visible) {
            html.classList.toggle('toc-hidden', !visible);
            toc.style.display = visible ? 'block' : 'none';
            tocButton.setAttribute('aria-expanded', visible);
            tocButton.textContent = visible ? 'Hide TOC' : 'Show TOC';
            tocButton.setAttribute('title', visible ? 'Hide Table of Contents' : 'Show Table of Contents');
          }
        });
        </script>
      SCRIPT
      output = output.sub(/<\/body>/, "#{script}</body>")

      output
    end
  end
end