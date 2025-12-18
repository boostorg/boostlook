#!/usr/bin/env ruby

require 'listen'
require 'fileutils'
require 'logger'
require 'pathname'
require 'open3'
require 'digest/md5'

# BoostlookAntoraSpecimenPreview handles building the Antora specimen site and monitoring changes
class BoostlookAntoraSpecimenPreview
  # Define relevant paths
  PATHS = {
    source_css: 'boostlook.css',
    source_rb: 'boostlook.rb',
    antora_dir: 'doc/antora_specimen',
    build_dir: 'doc/antora_specimen/build/site',
    build_css: 'doc/antora_specimen/build/site/_/css/site.css',
    playbook: 'doc/antora_specimen/playbook.yml'
  }.freeze

  # OS-specific commands to open the default web browser
  OS_BROWSER_COMMANDS = {
    /darwin/       => 'open',       # macOS
    /linux/        => 'xdg-open',   # Linux
    /mingw|mswin/  => 'start'       # Windows
  }.freeze

  def initialize
    # Initialize the logger
    @logger = Logger.new($stdout)
    @logger.level = Logger::INFO
    @logger.formatter = ->(_, _, _, msg) { "#{msg}\n" }

    @file_opened = false          # Flag to prevent multiple browser openings
    @shutdown_requested = false   # Flag to handle graceful shutdown
    @antora_version = nil         # Will store the detected Antora version
    @last_css_hash = nil          # Store the last CSS file hash to avoid loops
    @last_rb_hash = nil           # Store the last Ruby file hash
    @processing_change = false    # Flag to prevent recursive change detection
  end

  # Entry point to run the preview
  def run
    check_dependencies
    ensure_site_built
    setup_signal_traps
    watch_files
  end

  private

  # Check if Antora is installed and get its version
  def check_dependencies
    stdout, status = Open3.capture2('npx antora --version 2>/dev/null')

    unless status.success?
      @logger.error("'npx antora' command failed. Please install Antora: npm i @antora/cli @antora/site-generator")
      exit 1
    end

    # Extract version number
    @antora_version = stdout.strip
    @logger.info("Using Antora version: #{@antora_version}")

    # Check if source files exist
    unless File.exist?(PATHS[:source_css])
      @logger.error("Source CSS file not found: #{PATHS[:source_css]}")
      exit 1
    end

    unless File.exist?(PATHS[:source_rb])
      @logger.error("Source Ruby extension not found: #{PATHS[:source_rb]}")
      exit 1
    end

    # Check if playbook exists
    unless File.exist?(PATHS[:playbook])
      @logger.error("Antora playbook not found: #{PATHS[:playbook]}")
      exit 1
    end
  end

  # Ensures the Antora site is built
  def ensure_site_built
    # If build directory doesn't exist or is empty, build the site
    unless File.directory?(PATHS[:build_dir]) && !Dir.empty?(PATHS[:build_dir])
      @logger.info("Build directory not found or empty. Building Antora site...")
      build_antora_site
    else
      @logger.info("Using existing build. Run with --rebuild to force a fresh build.")
    end

    # Store initial file hashes
    @last_css_hash = calculate_file_hash(PATHS[:source_css])
    @last_rb_hash = calculate_file_hash(PATHS[:source_rb])

    open_in_browser
  end

  # Builds the Antora site
  def build_antora_site
    @logger.info("Building Antora site with official Boost.URL content...")

    Dir.chdir(PATHS[:antora_dir]) do
      # Use --fetch since we're pulling remote content
      cmd = 'npx antora --fetch playbook.yml'
      @logger.info("Fetching remote Boost.URL content and building site...")

      unless system(cmd)
        @logger.error("Antora site build failed")
        exit 1
      end
    end

    @logger.info("Antora site built successfully with boostlook styling applied")
    # Copy current boostlook.css to override the one from UI bundle
    copy_current_css
    true
  end

  # Copy current boostlook.css to the built site
  def copy_current_css
    target_css = File.join(PATHS[:build_dir], '_/css/boostlook.css')

    if File.exist?(target_css)
      @logger.info("Copying current #{PATHS[:source_css]} to built site...")
      FileUtils.cp(PATHS[:source_css], target_css)
      @logger.info("Updated built site with current boostlook.css")
    else
      @logger.warn("Target CSS file not found: #{target_css}")
    end
  end

  # Calculate MD5 hash of a file
  def calculate_file_hash(file_path)
    Digest::MD5.hexdigest(File.read(file_path))
  end

  # Rebuilds the entire site (useful when Ruby extension changes)
  def rebuild_site
    @logger.info("Rebuilding entire site due to boostlook.rb changes...")
    FileUtils.rm_rf(PATHS[:build_dir]) if File.exist?(PATHS[:build_dir])
    build_antora_site
  end

  # Opens the generated HTML file in the default web browser
  def open_in_browser
    return if @file_opened

    index_file = File.join(PATHS[:build_dir], 'index.html')

    unless File.exist?(index_file)
      @logger.error("Site index not found: #{index_file}")
      return
    end

    cmd = OS_BROWSER_COMMANDS.find { |platform, _| RUBY_PLATFORM =~ platform }&.last
    if cmd
      system("#{cmd} #{index_file}")
      @file_opened = true
      @logger.info("Opened site in browser: #{index_file}")
    else
      @logger.warn("Unsupported OS. Please open #{index_file} manually")
    end
  end

  # Sets up file listeners to watch for changes and trigger updates
  def watch_files
    @logger.info("Watching for changes in boostlook files...")

    @listener = Listen.to('.', latency: 0.5, only: /\.(css|rb)$/) do |modified, added, _|
      # Skip if we're already processing a change to avoid loops
      next if @processing_change

      files = modified + added

      css_changed = files.any? { |file| File.basename(file) == File.basename(PATHS[:source_css]) }
      rb_changed = files.any? { |file| File.basename(file) == File.basename(PATHS[:source_rb]) }

      if css_changed || rb_changed
        @processing_change = true

        if rb_changed
          # Ruby extension changed - need full rebuild
          current_rb_hash = calculate_file_hash(PATHS[:source_rb])
          if current_rb_hash != @last_rb_hash
            @logger.info("#{PATHS[:source_rb]} changed, rebuilding site...")
            rebuild_site
            @last_rb_hash = current_rb_hash
            @last_css_hash = calculate_file_hash(PATHS[:source_css]) # Update CSS hash too
          end
        elsif css_changed
          # CSS changed - just rebuild (CSS is processed by Ruby extension)
          current_css_hash = calculate_file_hash(PATHS[:source_css])
          if current_css_hash != @last_css_hash
            @logger.info("#{PATHS[:source_css]} changed, rebuilding site...")
            rebuild_site
            @last_css_hash = current_css_hash
          end
        end

        @processing_change = false
      end
    end

    @listener.start

    # Print instructions for the user
    print_instructions

    # Keep the script running until shutdown is requested
    until @shutdown_requested
      sleep 1
    end

    shutdown
  end

  # Prints usage instructions
  def print_instructions
    build_url = "file://#{File.expand_path(PATHS[:build_dir])}/index.html"

    @logger.info("")
    @logger.info("=== Boostlook Antora Specimen Preview ===")
    @logger.info("Watching boostlook.css and boostlook.rb for changes")
    @logger.info("Testing against official Boost.URL documentation")
    @logger.info("")
    @logger.info("Changes detected will trigger automatic rebuilds:")
    @logger.info("  • #{PATHS[:source_css]} → Full rebuild (CSS processed by extension)")
    @logger.info("  • #{PATHS[:source_rb]} → Full rebuild (Ruby extension changed)")
    @logger.info("")
    @logger.info("To view the styled site, open this URL in your browser:")
    @logger.info("  #{build_url}")
    @logger.info("")
    @logger.info("Press Ctrl+C to stop the preview")
    @logger.info("========================================")
    @logger.info("")
  end

  # Sets up signal traps to handle graceful shutdown on interrupt or terminate signals
  def setup_signal_traps
    Signal.trap("INT") { @shutdown_requested = true }
    Signal.trap("TERM") { @shutdown_requested = true }
  end

  # Performs shutdown procedures, such as stopping the file listener
  def shutdown
    @logger.info("Shutting down...")
    @listener&.stop
    exit
  end
end

# Handle command line arguments
if __FILE__ == $0
  # Check for --rebuild flag
  if ARGV.include?('--rebuild')
    FileUtils.rm_rf('doc/antora_specimen/build') if File.exist?('doc/antora_specimen/build')
    puts "Build directory cleared. Starting fresh build..."
  end

  BoostlookAntoraSpecimenPreview.new.run
end
