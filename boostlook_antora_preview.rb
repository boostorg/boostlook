#!/usr/bin/env ruby

require 'listen'
require 'fileutils'
require 'logger'
require 'pathname'
require 'open3'
require 'digest/md5'

# BoostlookAntoraPreview handles building the Antora specimen site and monitoring CSS changes
class BoostlookAntoraPreview
  # Define relevant paths
  PATHS = {
    source_css: 'boostlook.css',
    antora_dir: 'doc/antora_specimen',
    build_dir: 'doc/antora_specimen/build/site',
    build_css: 'doc/antora_specimen/build/site/_/css/boostlook.css',
    playbook: 'doc/antora_specimen/playbook.yml',
    ui_bundle: 'doc/antora_specimen/ui/ui-bundle.zip'
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

    # Check if source CSS exists
    unless File.exist?(PATHS[:source_css])
      @logger.error("Source CSS file not found: #{PATHS[:source_css]}")
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
    end

    # After building, copy the current CSS to the build directory
    if File.exist?(PATHS[:build_css])
      @logger.info("Copying current CSS to build directory...")
      # Store the initial CSS hash
      @last_css_hash = calculate_file_hash(PATHS[:source_css])
      copy_css_file
      open_in_browser
    else
      @logger.error("Build CSS path not found after site build: #{PATHS[:build_css]}")
      exit 1
    end
  end

  # Builds the Antora site
  def build_antora_site
    @logger.info("Building Antora site...")

    Dir.chdir(PATHS[:antora_dir]) do
      cmd = 'npx antora playbook.yml'

      # Add --fetch flag if UI bundle is configured as a remote URL in playbook
      if ui_bundle_is_remote?
        cmd = 'npx antora --fetch playbook.yml'
        @logger.info("Remote UI bundle detected, using --fetch flag")
      end

      if system(cmd)
        @logger.info("Antora site built successfully")
        true
      else
        @logger.error("Antora site build failed")
        exit 1
      end
    end
  end

  # Check if the UI bundle in the playbook is configured as a remote URL
  def ui_bundle_is_remote?
    return false unless File.exist?(PATHS[:playbook])

    content = File.read(PATHS[:playbook])
    ui_bundle_line = content.match(/^\s*ui:\s*$.*?^\s*bundle:\s*$.*?^\s*url:\s*(.+?)$/m)

    return false unless ui_bundle_line

    url = ui_bundle_line[1].strip
    # Consider it remote if it starts with http://, https://, or git://
    url.start_with?('http://', 'https://', 'git://')
  end

  # Calculate MD5 hash of a file
  def calculate_file_hash(file_path)
    Digest::MD5.hexdigest(File.read(file_path))
  end

  # Copies the CSS file to the build directory
  def copy_css_file
    begin
      FileUtils.cp(PATHS[:source_css], PATHS[:build_css])
      @logger.info("CSS file updated: #{PATHS[:build_css]}")
      true
    rescue => e
      @logger.error("Failed to copy CSS file: #{e.message}")
      false
    end
  end

  # Opens the generated HTML file in the default web browser
  def open_in_browser
    return if @file_opened

    cmd = OS_BROWSER_COMMANDS.find { |platform, _| RUBY_PLATFORM =~ platform }&.last
    if cmd
      system("#{cmd} #{PATHS[:build_dir]}/index.html")
      @file_opened = true
      @logger.info("Opened site in browser: #{PATHS[:build_dir]}/index.html")
    else
      @logger.warn("Unsupported OS. Please open #{PATHS[:build_dir]}/index.html manually")
    end
  end

  # Sets up file listeners to watch for changes and trigger updates
  def watch_files
    @logger.info("Watching for changes in #{PATHS[:source_css]}...")

    @listener = Listen.to(File.dirname(PATHS[:source_css]), latency: 0.5) do |modified, added, _|
      # Skip if we're already processing a change to avoid loops
      next if @processing_change

      files = modified + added
      css_file_changed = files.any? { |file| File.basename(file) == File.basename(PATHS[:source_css]) }

      if css_file_changed
        # Calculate the new hash
        current_hash = calculate_file_hash(PATHS[:source_css])

        # Only process if the hash has actually changed
        if current_hash != @last_css_hash
          @processing_change = true
          @logger.info("#{PATHS[:source_css]} changed, updating build directory...")
          copy_css_file
          @last_css_hash = current_hash
          @processing_change = false
        end
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
    @logger.info("=== Boostlook Antora Preview ===")
    @logger.info("CSS file is being watched for changes")
    @logger.info("Any changes to #{PATHS[:source_css]} will be automatically copied to the build directory")
    @logger.info("")
    @logger.info("To view the site, open this URL in your browser:")
    @logger.info("  #{build_url}")
    @logger.info("")
    @logger.info("Press Ctrl+C to stop the preview")
    @logger.info("================================")
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

# Run the preview
if __FILE__ == $0
  BoostlookAntoraPreview.new.run
end
