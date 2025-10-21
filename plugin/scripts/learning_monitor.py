#!/usr/bin/env python3
"""
Amplicode Learning Monitor

Lightweight worker that:
- Monitors queue size every 30 seconds
- Triggers Claude Code to process when threshold reached (10+ events)
- Archives old events
- Much simpler than full worker - just monitoring and triggering
"""

import json
import logging
import os
import subprocess
import time
from datetime import datetime, timedelta
from pathlib import Path

# Configuration
CLAUDE_DIR = Path.home() / ".claude"
QUEUE_FILE = CLAUDE_DIR / "learning_queue.jsonl"
ARCHIVE_FILE = CLAUDE_DIR / "learning_queue_archive.jsonl"
HEARTBEAT_FILE = CLAUDE_DIR / "monitor_heartbeat.json"
LOG_FILE = CLAUDE_DIR / "monitor.log"
TRIGGER_SCRIPT = Path(__file__).parent / "trigger_claude_learning.sh"

TRIGGER_THRESHOLD = 10  # Trigger when 10+ events queued
CHECK_INTERVAL = 30      # Check every 30 seconds
ARCHIVE_AGE_DAYS = 7     # Archive events older than 7 days

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


def count_queue_events() -> int:
    """Count events in queue file."""
    if not QUEUE_FILE.exists():
        return 0

    try:
        with open(QUEUE_FILE, 'r') as f:
            return sum(1 for line in f if line.strip())
    except Exception as e:
        logger.error(f"Error counting queue: {e}")
        return 0


def get_latest_project() -> str:
    """Get the most recent project from queue events."""
    if not QUEUE_FILE.exists():
        return str(Path.cwd())

    try:
        with open(QUEUE_FILE, 'r') as f:
            lines = f.readlines()
            if not lines:
                return str(Path.cwd())

            # Get last event
            last_event = json.loads(lines[-1])
            return last_event.get('project', str(Path.cwd()))
    except Exception as e:
        logger.error(f"Error reading queue: {e}")
        return str(Path.cwd())


def trigger_claude_processing(project_dir: str):
    """Trigger Claude Code to process learning queue."""
    logger.info(f"Triggering Claude Code to process queue (project: {project_dir})")

    try:
        # Make trigger script executable
        os.chmod(TRIGGER_SCRIPT, 0o755)

        # Call trigger script
        result = subprocess.run(
            [str(TRIGGER_SCRIPT), project_dir, "/amplicode-process"],
            capture_output=True,
            text=True,
            timeout=10
        )

        if result.returncode == 0:
            logger.info("✅ Successfully triggered Claude Code")
            logger.info(result.stdout)
        else:
            logger.warning(f"Trigger script returned {result.returncode}")
            logger.warning(result.stderr)

    except subprocess.TimeoutExpired:
        logger.error("Trigger script timed out")
    except Exception as e:
        logger.error(f"Error triggering Claude Code: {e}")


def archive_old_events():
    """Archive events older than ARCHIVE_AGE_DAYS."""
    if not QUEUE_FILE.exists():
        return

    try:
        cutoff_time = datetime.now().timestamp() - (ARCHIVE_AGE_DAYS * 24 * 60 * 60)
        events_to_keep = []
        events_to_archive = []

        with open(QUEUE_FILE, 'r') as f:
            for line in f:
                if not line.strip():
                    continue

                try:
                    event = json.loads(line)
                    event_time = event.get('timestamp', 0)

                    if event_time < cutoff_time:
                        events_to_archive.append(line)
                    else:
                        events_to_keep.append(line)
                except json.JSONDecodeError:
                    # Keep invalid JSON in queue for debugging
                    events_to_keep.append(line)

        # Write archived events
        if events_to_archive:
            with open(ARCHIVE_FILE, 'a') as f:
                f.writelines(events_to_archive)

            logger.info(f"Archived {len(events_to_archive)} old events")

        # Rewrite queue with remaining events
        with open(QUEUE_FILE, 'w') as f:
            f.writelines(events_to_keep)

    except Exception as e:
        logger.error(f"Error archiving events: {e}")


def write_heartbeat(queue_size: int, last_trigger: Optional[datetime] = None):
    """Write heartbeat file for monitoring."""
    try:
        heartbeat = {
            "timestamp": time.time(),
            "timestamp_human": datetime.now().isoformat(),
            "pid": os.getpid(),
            "queue_size": queue_size,
            "last_trigger": last_trigger.isoformat() if last_trigger else None,
            "trigger_threshold": TRIGGER_THRESHOLD
        }

        # Atomic write
        tmp_file = HEARTBEAT_FILE.with_suffix('.tmp')
        with open(tmp_file, 'w') as f:
            json.dump(heartbeat, f, indent=2)
        tmp_file.replace(HEARTBEAT_FILE)

    except Exception as e:
        logger.error(f"Error writing heartbeat: {e}")


def main():
    """Main monitor loop."""
    logger.info("Starting Amplicode Learning Monitor")
    logger.info(f"Trigger threshold: {TRIGGER_THRESHOLD} events")
    logger.info(f"Check interval: {CHECK_INTERVAL} seconds")

    # Ensure directories exist
    CLAUDE_DIR.mkdir(parents=True, exist_ok=True)

    last_trigger_time = None
    iteration = 0

    while True:
        try:
            iteration += 1

            # Count events in queue
            queue_size = count_queue_events()

            # Write heartbeat
            write_heartbeat(queue_size, last_trigger_time)

            logger.info(f"Queue size: {queue_size}")

            # Check if we should trigger processing
            if queue_size >= TRIGGER_THRESHOLD:
                # Don't trigger too frequently (at least 5 minutes between triggers)
                if last_trigger_time is None or \
                   (datetime.now() - last_trigger_time).seconds > 300:

                    project_dir = get_latest_project()
                    trigger_claude_processing(project_dir)
                    last_trigger_time = datetime.now()

                else:
                    logger.info(f"Queue at threshold but waiting before next trigger")

            # Archive old events every 10 iterations (~5 minutes)
            if iteration % 10 == 0:
                archive_old_events()

            # Sleep
            time.sleep(CHECK_INTERVAL)

        except KeyboardInterrupt:
            logger.info("Received interrupt, shutting down...")
            break
        except Exception as e:
            logger.error(f"Error in main loop: {e}", exc_info=True)
            time.sleep(CHECK_INTERVAL)

    logger.info("Monitor stopped")


if __name__ == "__main__":
    main()
