#!/usr/bin/env python3
"""Background learning worker for Amplicode plugin.

This worker polls the global learning queue and processes events
in the background without blocking Claude Code sessions.

Features:
- Polls ~/.claude/learning_queue.jsonl every 1 second
- Processes stop, session_start, session_end events
- Writes heartbeat every iteration
- Auto-restarts after 100 events (prevents memory leaks)
- Handles crashes with exponential backoff
- Self-watchdog kills worker if stuck >2min
"""

import fcntl
import json
import logging
import os
import sys
import time
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional

# Add scripts directory to path for local imports
sys.path.insert(0, str(Path(__file__).parent))

from health_monitor import HealthMonitor
from learning_extractor import extract_correction, extract_preference, classify_scope
from learning_memory import write_memory, read_memory


# Configuration
CLAUDE_DIR = Path.home() / ".claude"
QUEUE_FILE = CLAUDE_DIR / "learning_queue.jsonl"
HEARTBEAT_FILE = CLAUDE_DIR / "worker_heartbeat.json"
LOG_FILE = CLAUDE_DIR / "worker.log"
RESTART_STATE_FILE = CLAUDE_DIR / "worker_restart_state.json"
MAX_EVENTS_BEFORE_RESTART = 100

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    handlers=[
        logging.FileHandler(LOG_FILE),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)


class LearningWorker:
    """Main worker class that processes learning events."""

    def __init__(self):
        """Initialize the learning worker."""
        self.health_monitor = HealthMonitor(timeout_seconds=120)
        self.events_processed = 0
        self.queue_position = 0  # Track position in queue file
        self._ensure_directories()

    def _ensure_directories(self) -> None:
        """Ensure required directories exist."""
        CLAUDE_DIR.mkdir(exist_ok=True)
        if not QUEUE_FILE.exists():
            QUEUE_FILE.touch()

    def run(self) -> None:
        """Main worker loop."""
        logger.info("Starting learning worker")
        self.health_monitor.start()

        try:
            while True:
                # Write heartbeat
                self._write_heartbeat()
                self.health_monitor.update_activity()

                # Poll queue
                events = self._poll_queue(limit=10)

                # Process each event
                for event in events:
                    try:
                        self._process_event(event)
                        self.events_processed += 1
                        self.health_monitor.update_activity()
                    except Exception as e:
                        logger.error(f"Error processing event: {e}", exc_info=True)

                # Write heartbeat after processing
                self._write_heartbeat()

                # Auto-restart after 100 events to prevent memory leaks
                if self.events_processed >= MAX_EVENTS_BEFORE_RESTART:
                    logger.info(f"Processed {self.events_processed} events, restarting for freshness")
                    sys.exit(0)

                # Sleep before next poll
                time.sleep(1)

        except KeyboardInterrupt:
            logger.info("Received interrupt, shutting down")
        except Exception as e:
            logger.error(f"Fatal error in worker: {e}", exc_info=True)
            sys.exit(1)
        finally:
            self.health_monitor.stop()

    def _write_heartbeat(self) -> None:
        """Write heartbeat to indicate worker is alive."""
        heartbeat = {
            'timestamp': time.time(),
            'timestamp_human': datetime.now().isoformat(),
            'pid': os.getpid(),
            'events_processed': self.events_processed,
            'queue_position': self.queue_position
        }

        try:
            tmp_file = HEARTBEAT_FILE.with_suffix('.tmp')
            with open(tmp_file, 'w') as f:
                json.dump(heartbeat, f, indent=2)
            os.replace(tmp_file, HEARTBEAT_FILE)
        except Exception as e:
            logger.error(f"Failed to write heartbeat: {e}")

    def _poll_queue(self, limit: int = 10) -> List[Dict]:
        """Poll the queue file for new events.

        Args:
            limit: Maximum number of events to return

        Returns:
            List of event dictionaries
        """
        if not QUEUE_FILE.exists():
            return []

        events = []
        lock_file = CLAUDE_DIR / "learning_queue.lock"

        try:
            # Acquire lock
            with open(lock_file, 'w') as lock:
                fcntl.flock(lock.fileno(), fcntl.LOCK_EX)

                # Read events from our current position
                with open(QUEUE_FILE, 'r') as f:
                    # Skip to our position
                    for _ in range(self.queue_position):
                        f.readline()

                    # Read new events
                    for _ in range(limit):
                        line = f.readline()
                        if not line:
                            break

                        try:
                            event = json.loads(line.strip())
                            events.append(event)
                            self.queue_position += 1
                        except json.JSONDecodeError as e:
                            logger.error(f"Invalid JSON in queue: {e}")

                fcntl.flock(lock.fileno(), fcntl.LOCK_UN)

        except Exception as e:
            logger.error(f"Error polling queue: {e}")

        if events:
            logger.debug(f"Polled {len(events)} events from queue")

        return events

    def _process_event(self, event: Dict) -> None:
        """Process a single event from the queue.

        Args:
            event: Event dictionary
        """
        event_type = event.get('event_type', 'unknown')
        project = event.get('project', '')

        logger.info(f"Processing event: {event_type} for project {project}")

        # Switch to project directory if needed
        original_cwd = os.getcwd()
        if project and os.path.isdir(project):
            os.chdir(project)

        try:
            if event_type == 'stop':
                self._process_stop_event(event)
            elif event_type == 'session_start':
                self._process_session_start_event(event)
            elif event_type == 'session_end':
                self._process_session_end_event(event)
            else:
                logger.warning(f"Unknown event type: {event_type}")

        finally:
            # Restore original directory
            os.chdir(original_cwd)

    def _process_stop_event(self, event: Dict) -> None:
        """Process a stop event (potential correction).

        Args:
            event: Stop event dictionary
        """
        # For now, just log. In the future, we'll:
        # 1. Load recent transcript
        # 2. Call extract_correction()
        # 3. If correction found, call extract_preference()
        # 4. Call classify_scope()
        # 5. Write to appropriate memory file

        logger.debug(f"Stop event: {event}")
        # TODO: Implement transcript loading and correction detection

    def _process_session_start_event(self, event: Dict) -> None:
        """Process a session start event.

        Args:
            event: Session start event dictionary
        """
        project = event.get('project', '')
        if project:
            # Load and log preferences for this project
            memory = read_memory(project)
            pref_count = len(memory.get('preferences', []))
            logger.info(f"Session started - {pref_count} preferences loaded for {project}")

    def _process_session_end_event(self, event: Dict) -> None:
        """Process a session end event.

        Args:
            event: Session end event dictionary
        """
        # For now, just log. In the future, we'll:
        # 1. Analyze entire session
        # 2. Look for patterns
        # 3. Extract session-level insights

        logger.info(f"Session ended: {event.get('project', '')}")
        # TODO: Implement session analysis


def should_restart_worker() -> bool:
    """Check if worker should restart based on exponential backoff.

    Returns:
        True if worker should restart, False if in backoff period
    """
    if not RESTART_STATE_FILE.exists():
        return True

    try:
        with open(RESTART_STATE_FILE, 'r') as f:
            state = json.load(f)

        # Check if in backoff period
        backoff_until = state.get('backoff_until', 0)
        if time.time() < backoff_until:
            logger.warning(f"In backoff period until {datetime.fromtimestamp(backoff_until)}")
            return False

        # Give up after 5 consecutive crashes
        restart_count = state.get('restart_count', 0)
        if restart_count >= 5:
            logger.error("Worker crashed 5 times, giving up")
            return False

        return True

    except Exception as e:
        logger.error(f"Error reading restart state: {e}")
        return True


def update_restart_state() -> None:
    """Update restart state with exponential backoff."""
    state = {'restart_count': 0, 'backoff_until': 0}

    if RESTART_STATE_FILE.exists():
        try:
            with open(RESTART_STATE_FILE, 'r') as f:
                state = json.load(f)
        except Exception:
            pass

    # Increment restart count
    state['restart_count'] = state.get('restart_count', 0) + 1

    # Calculate exponential backoff: 2^n seconds, max 1 hour
    backoff_seconds = min(2 ** state['restart_count'], 3600)
    state['backoff_until'] = time.time() + backoff_seconds

    # Write state
    try:
        with open(RESTART_STATE_FILE, 'w') as f:
            json.dump(state, f, indent=2)
        logger.info(f"Updated restart state: {state['restart_count']} crashes, "
                   f"backoff for {backoff_seconds}s")
    except Exception as e:
        logger.error(f"Failed to write restart state: {e}")


def main() -> None:
    """Main entry point."""
    if not should_restart_worker():
        logger.warning("Worker restart suppressed by backoff")
        sys.exit(1)

    update_restart_state()

    worker = LearningWorker()
    worker.run()


if __name__ == "__main__":
    main()
