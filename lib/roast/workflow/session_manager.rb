# frozen_string_literal: true

module Roast
  module Workflow
    # Manages session creation, timestamping, and directory management
    class SessionManager
      TARGETLESS_FILE_PATH = "notarget"

      def initialize
        @session_mutex = Mutex.new
        @session_timestamps = {}
      end

      # Get or create a session directory for the workflow
      def ensure_session_directory(workflow_id, session_name, file_path, timestamp: nil)
        @session_mutex.synchronize do
          # Create or get the workflow directory
          workflow_dir = workflow_directory(session_name, file_path)
          FileUtils.mkdir_p(workflow_dir)

          # Ensure .gitignore exists
          gitignore_path = File.join(workflow_dir, ".gitignore")
          File.write(gitignore_path, "*") unless File.exist?(gitignore_path)

          # Get or create session timestamp
          session_timestamp = timestamp || @session_timestamps[workflow_id] || create_new_session(workflow_id)

          # Create session directory
          session_dir = File.join(workflow_dir, session_timestamp)
          FileUtils.mkdir_p(session_dir)
          session_dir
        end
      end

      # Find a session directory for the workflow
      def find_session_directory(session_name, file_path, timestamp = nil)
        workflow_dir = workflow_directory(session_name, file_path)
        return unless File.directory?(workflow_dir)

        if timestamp
          session_dir = File.join(workflow_dir, timestamp)
          File.directory?(session_dir) ? session_dir : nil
        else
          find_latest_session_directory(workflow_dir)
        end
      end

      # Get the session timestamp for a workflow
      def session_timestamp(workflow_id)
        @session_timestamps[workflow_id]
      end

      # Set the session timestamp for a workflow
      def set_session_timestamp(workflow_id, timestamp)
        @session_timestamps[workflow_id] = timestamp
      end

      # Create a new session for a workflow
      def create_new_session(workflow_id)
        timestamp = Time.now.utc.strftime("%Y%m%d_%H%M%S_%L")
        @session_timestamps[workflow_id] = timestamp
        timestamp
      end

      private

      def workflow_directory(session_name, file_path)
        file_path ||= TARGETLESS_FILE_PATH
        workflow_dir_name = session_name.parameterize.underscore
        # For targetless sessions we don't have a file_path
        file_id = Digest::MD5.hexdigest(file_path || Dir.pwd)
        file_basename = File.basename(file_path || Dir.pwd).parameterize.underscore
        human_readable_id = "#{file_basename}_#{file_id[0..7]}"
        File.join(Dir.pwd, ".roast", "sessions", workflow_dir_name, human_readable_id)
      end

      def find_latest_session_directory(workflow_dir)
        sessions = Dir.children(workflow_dir).sort.reverse
        sessions.empty? ? nil : File.join(workflow_dir, sessions.first)
      end
    end
  end
end
