# frozen_string_literal: true

require "json"

module Roast
  module Workflow
    # SQLite-based implementation of StateRepository
    # Provides structured, queryable session storage with better performance
    class SqliteStateRepository < StateRepository
      def initialize(db_path: nil, session_manager: SessionManager.new)
        super()

        # Lazy load sqlite3 only when actually using SQLite storage
        begin
          require "sqlite3"
        rescue LoadError
          raise LoadError, "SQLite storage requires the 'sqlite3' gem. Please add it to your Gemfile or install it: gem install sqlite3"
        end

        # Priority order
        paths = [
          db_path,
          Roast::SESSION_DB_PATH,
          Roast::XDGMigration.new.legacy_sessions_db_path,
        ]

        # If multiple options exist, prefer the first one that exists
        @db_path = paths.find { |path| path && File.exist?(path) }
        # If no options exist as paths, use the first one that is not nil
        @db_path ||= paths.find { |path| !path.nil? }
        @session_manager = session_manager
        ensure_database
      end

      def save_state(workflow, step_name, state_data)
        workflow.session_timestamp ||= @session_manager.create_new_session(workflow.object_id)

        session_id = ensure_session(workflow)

        @db.execute(<<~SQL, [session_id, state_data[:order], step_name, state_data.to_json])
          INSERT INTO session_states (session_id, step_index, step_name, state_data)
          VALUES (?, ?, ?, ?)
        SQL

        # Update session's current step
        @db.execute(<<~SQL, [state_data[:order], session_id])
          UPDATE sessions#{" "}
          SET current_step_index = ?, updated_at = CURRENT_TIMESTAMP
          WHERE id = ?
        SQL
      rescue => e
        $stderr.puts "Failed to save state for step #{step_name}: #{e.message}"
      end

      def load_state_before_step(workflow, step_name, timestamp: nil)
        session_id = find_session_id(workflow, timestamp)
        return false unless session_id

        # Find the state before the target step
        result = @db.execute(<<~SQL, [session_id, step_name])
          SELECT state_data, step_name
          FROM session_states
          WHERE session_id = ?
            AND step_index < (
              SELECT MIN(step_index)#{" "}
              FROM session_states#{" "}
              WHERE session_id = ? AND step_name = ?
            )
          ORDER BY step_index DESC
          LIMIT 1
        SQL

        if result.empty?
          # Try to find the latest state if target step doesn't exist
          result = @db.execute(<<~SQL, [session_id])
            SELECT state_data, step_name
            FROM session_states
            WHERE session_id = ?
            ORDER BY step_index DESC
            LIMIT 1
          SQL

          if result.empty?
            $stderr.puts "No state found for session"
            return false
          end
        end

        state_data = JSON.parse(result[0][0], symbolize_names: true)
        loaded_step = result[0][1]
        $stderr.puts "Found state from step: #{loaded_step} (will replay from here to #{step_name})"

        # If no timestamp provided and workflow has no session, create new session and copy states
        if !timestamp && workflow.session_timestamp.nil?
          copy_states_to_new_session(workflow, session_id, step_name)
        end

        state_data
      end

      def save_final_output(workflow, output_content)
        return if output_content.empty?

        session_id = ensure_session(workflow)

        @db.execute(<<~SQL, [output_content, session_id])
          UPDATE sessions#{" "}
          SET final_output = ?, status = 'completed', updated_at = CURRENT_TIMESTAMP
          WHERE id = ?
        SQL

        session_id
      rescue => e
        $stderr.puts "Failed to save final output: #{e.message}"
        nil
      end

      # Additional query methods for the new capabilities

      def list_sessions(status: nil, workflow_name: nil, older_than: nil, limit: 100)
        conditions = []
        params = []

        if status
          conditions << "status = ?"
          params << status
        end

        if workflow_name
          conditions << "workflow_name = ?"
          params << workflow_name
        end

        if older_than
          conditions << "created_at < datetime('now', ?)"
          params << "-#{older_than}"
        end

        where_clause = conditions.empty? ? "" : "WHERE #{conditions.join(" AND ")}"

        @db.execute(<<~SQL, params)
          SELECT id, workflow_name, workflow_path, status, current_step_index,#{" "}
                 created_at, updated_at
          FROM sessions
          #{where_clause}
          ORDER BY created_at DESC
          LIMIT #{limit}
        SQL
      end

      def get_session_details(session_id)
        session = @db.execute(<<~SQL, [session_id]).first
          SELECT * FROM sessions WHERE id = ?
        SQL

        return unless session

        states = @db.execute(<<~SQL, [session_id])
          SELECT step_index, step_name, created_at
          FROM session_states
          WHERE session_id = ?
          ORDER BY step_index
        SQL

        events = @db.execute(<<~SQL, [session_id])
          SELECT event_name, event_data, received_at
          FROM session_events
          WHERE session_id = ?
          ORDER BY received_at
        SQL

        {
          session: session,
          states: states,
          events: events,
        }
      end

      def cleanup_old_sessions(older_than)
        count = @db.changes
        @db.execute(<<~SQL, ["-#{older_than}"])
          DELETE FROM sessions
          WHERE created_at < datetime('now', ?)
        SQL
        @db.changes - count
      end

      def add_event(workflow_path, session_id, event_name, event_data = nil)
        # Find the session if session_id not provided
        unless session_id
          workflow_name = File.basename(File.dirname(workflow_path))
          result = @db.execute(<<~SQL, [workflow_name, "waiting"])
            SELECT id FROM sessions
            WHERE workflow_name = ? AND status = ?
            ORDER BY created_at DESC
            LIMIT 1
          SQL

          raise "No waiting session found for workflow: #{workflow_name}" if result.empty?

          session_id = result[0][0]
        end

        # Add the event
        @db.execute(<<~SQL, [session_id, event_name, event_data&.to_json])
          INSERT INTO session_events (session_id, event_name, event_data)
          VALUES (?, ?, ?)
        SQL

        # Update session status
        @db.execute(<<~SQL, [session_id])
          UPDATE sessions#{" "}
          SET status = 'running', updated_at = CURRENT_TIMESTAMP
          WHERE id = ?
        SQL

        session_id
      end

      private

      def ensure_database
        FileUtils.mkdir_p(File.dirname(@db_path))
        @db = SQLite3::Database.new(@db_path)
        @db.execute("PRAGMA foreign_keys = ON")
        create_schema
      end

      def create_schema
        @db.execute_batch(<<~SQL)
          CREATE TABLE IF NOT EXISTS sessions (
            id TEXT PRIMARY KEY,
            workflow_name TEXT NOT NULL,
            workflow_path TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'running',
            current_step_index INTEGER,
            final_output TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
          );

          CREATE TABLE IF NOT EXISTS session_states (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id TEXT NOT NULL,
            step_index INTEGER NOT NULL,
            step_name TEXT NOT NULL,
            state_data TEXT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE CASCADE
          );

          CREATE TABLE IF NOT EXISTS session_events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id TEXT NOT NULL,
            event_name TEXT NOT NULL,
            event_data TEXT,
            received_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE CASCADE
          );

          CREATE TABLE IF NOT EXISTS session_variables (
            session_id TEXT NOT NULL,
            key TEXT NOT NULL,
            value TEXT NOT NULL,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (session_id, key),
            FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE CASCADE
          );

          -- Indexes for common queries
          CREATE INDEX IF NOT EXISTS idx_sessions_status ON sessions(status);
          CREATE INDEX IF NOT EXISTS idx_sessions_workflow_name ON sessions(workflow_name);
          CREATE INDEX IF NOT EXISTS idx_sessions_created_at ON sessions(created_at);
          CREATE INDEX IF NOT EXISTS idx_session_states_session_id ON session_states(session_id);
          CREATE INDEX IF NOT EXISTS idx_session_events_session_id ON session_events(session_id);
        SQL
      end

      def ensure_session(workflow)
        session_id = generate_session_id(workflow)

        # Check if session exists
        existing = @db.execute("SELECT id FROM sessions WHERE id = ?", [session_id]).first
        return session_id if existing

        # Create new session
        workflow_name = workflow.session_name || "unnamed"
        workflow_path = workflow.file || "notarget"

        @db.execute(<<~SQL, [session_id, workflow_name, workflow_path])
          INSERT INTO sessions (id, workflow_name, workflow_path)
          VALUES (?, ?, ?)
        SQL

        session_id
      end

      def find_session_id(workflow, timestamp)
        if timestamp
          # Find by exact timestamp
          generate_session_id(workflow, timestamp)
        else
          # Find latest session for this workflow
          workflow_name = workflow.session_name || "unnamed"
          workflow_path = workflow.file || "notarget"

          result = @db.execute(<<~SQL, [workflow_name, workflow_path])
            SELECT id FROM sessions
            WHERE workflow_name = ? AND workflow_path = ?
            ORDER BY created_at DESC
            LIMIT 1
          SQL

          result.empty? ? nil : result[0][0]
        end
      end

      def generate_session_id(workflow, timestamp = nil)
        timestamp ||= workflow.session_timestamp || @session_manager.create_new_session(workflow.object_id)
        workflow_name = workflow.session_name || "unnamed"
        workflow_path = workflow.file || "notarget"

        # Generate a unique session ID based on workflow info and timestamp
        file_hash = Digest::MD5.hexdigest(workflow_path)[0..7]
        "#{workflow_name.parameterize.underscore}_#{file_hash}_#{timestamp}"
      end

      def copy_states_to_new_session(workflow, source_session_id, target_step_name)
        # Create new session
        new_timestamp = @session_manager.create_new_session(workflow.object_id)
        workflow.session_timestamp = new_timestamp
        new_session_id = ensure_session(workflow)

        # Copy states up to the target step
        @db.execute(<<~SQL, [new_session_id, source_session_id, target_step_name, source_session_id])
          INSERT INTO session_states (session_id, step_index, step_name, state_data)
          SELECT ?, step_index, step_name, state_data
          FROM session_states
          WHERE session_id = ?
            AND step_index < COALESCE(
              (SELECT MIN(step_index) FROM session_states WHERE session_id = ? AND step_name = ?),
              999999
            )
        SQL

        true
      end
    end
  end
end
