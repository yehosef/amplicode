"""Health monitoring and self-watchdog for learning worker.

This module provides a watchdog thread that monitors worker activity
and forcefully kills the process if it becomes stuck.
"""

import logging
import os
import threading
import time
from typing import Optional

logger = logging.getLogger(__name__)


class HealthMonitor:
    """Self-watchdog that kills worker if stuck for >2 minutes."""

    def __init__(self, timeout_seconds: int = 120):
        """Initialize health monitor.

        Args:
            timeout_seconds: Maximum allowed time without activity before killing worker.
                            Default is 120 seconds (2 minutes).
        """
        self.timeout_seconds = timeout_seconds
        self.last_activity = time.time()
        self._watchdog_thread: Optional[threading.Thread] = None
        self._running = False

    def start(self) -> None:
        """Start the watchdog thread."""
        if self._running:
            logger.warning("Health monitor already running")
            return

        self._running = True
        self._watchdog_thread = threading.Thread(
            target=self._watchdog_loop,
            daemon=True,
            name="HealthMonitor"
        )
        self._watchdog_thread.start()
        logger.info(f"Health monitor started (timeout={self.timeout_seconds}s)")

    def update_activity(self) -> None:
        """Record activity timestamp. Call this regularly to prevent watchdog timeout."""
        self.last_activity = time.time()

    def _watchdog_loop(self) -> None:
        """Watchdog thread that checks for stuck worker every 10 seconds."""
        while self._running:
            time.sleep(10)

            idle_time = time.time() - self.last_activity
            if idle_time > self.timeout_seconds:
                logger.error(f"Worker stuck for {idle_time:.1f}s, forcing restart")
                self._dump_debug_info()
                logger.error("Killing worker process with os._exit(1)")
                os._exit(1)  # Force exit, bypass cleanup

    def _dump_debug_info(self) -> None:
        """Log debug information before killing worker."""
        try:
            import psutil
            process = psutil.Process()
            logger.error(f"Debug info - CPU: {process.cpu_percent()}%, "
                        f"Memory: {process.memory_info().rss / 1024 / 1024:.1f}MB, "
                        f"Threads: {process.num_threads()}")
        except Exception as e:
            logger.error(f"Failed to dump debug info: {e}")

    def stop(self) -> None:
        """Stop the watchdog thread."""
        self._running = False
        if self._watchdog_thread:
            self._watchdog_thread.join(timeout=1)
        logger.info("Health monitor stopped")
