"""Memory management with file locking for learned preferences.

This module provides safe read/write operations for project memory files
with proper locking to prevent data corruption from concurrent access.
"""

import fcntl
import json
import logging
import os
import shutil
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List

logger = logging.getLogger(__name__)


def write_memory(project_path: str, preference: Dict[str, Any]) -> None:
    """Write a preference to project memory with file locking.

    Args:
        project_path: Path to the project directory
        preference: Preference dictionary to append to memory

    The function:
    - Uses fcntl.flock() for file locking
    - Creates backup before write
    - Uses atomic write (tmp file + rename)
    - Creates .data directory if it doesn't exist
    """
    data_dir = Path(project_path) / ".data"
    memory_file = data_dir / "memory.json"
    lock_file = data_dir / "memory.lock"
    backup_file = data_dir / "memory.json.backup"
    tmp_file = data_dir / "memory.json.tmp"

    # Create data directory if needed
    data_dir.mkdir(exist_ok=True)

    # Acquire lock
    with open(lock_file, 'w') as lock:
        try:
            fcntl.flock(lock.fileno(), fcntl.LOCK_EX)
            logger.debug(f"Acquired lock for {memory_file}")

            # Read current memory
            memory = _read_memory_unsafe(memory_file)

            # Create backup
            if memory_file.exists():
                shutil.copy2(memory_file, backup_file)
                logger.debug(f"Created backup at {backup_file}")

            # Add new preference with timestamp
            preference['added_at'] = datetime.now().isoformat()
            memory['preferences'].append(preference)
            memory['updated_at'] = datetime.now().isoformat()

            # Write to temp file
            with open(tmp_file, 'w') as f:
                json.dump(memory, f, indent=2)

            # Atomic rename
            os.replace(tmp_file, memory_file)
            logger.info(f"Wrote preference to {memory_file}")

        finally:
            fcntl.flock(lock.fileno(), fcntl.LOCK_UN)
            logger.debug(f"Released lock for {memory_file}")


def read_memory(project_path: str) -> Dict[str, Any]:
    """Read preferences from project memory with file locking.

    Args:
        project_path: Path to the project directory

    Returns:
        Dictionary containing preferences and metadata
    """
    data_dir = Path(project_path) / ".data"
    memory_file = data_dir / "memory.json"
    lock_file = data_dir / "memory.lock"

    # If no memory file exists, return empty memory
    if not memory_file.exists():
        return _empty_memory()

    # Create lock file if needed
    data_dir.mkdir(exist_ok=True)

    # Acquire lock
    with open(lock_file, 'w') as lock:
        try:
            fcntl.flock(lock.fileno(), fcntl.LOCK_EX)
            logger.debug(f"Acquired lock for {memory_file}")

            return _read_memory_unsafe(memory_file)

        finally:
            fcntl.flock(lock.fileno(), fcntl.LOCK_UN)
            logger.debug(f"Released lock for {memory_file}")


def _read_memory_unsafe(memory_file: Path) -> Dict[str, Any]:
    """Read memory file without locking (internal use only).

    Handles corrupted JSON by loading from backup.

    Args:
        memory_file: Path to memory.json file

    Returns:
        Dictionary containing preferences and metadata
    """
    if not memory_file.exists():
        return _empty_memory()

    try:
        with open(memory_file, 'r') as f:
            return json.load(f)
    except json.JSONDecodeError as e:
        logger.error(f"Corrupted memory.json: {e}")

        # Try to load from backup
        backup_file = memory_file.parent / "memory.json.backup"
        if backup_file.exists():
            logger.warning(f"Loading from backup: {backup_file}")
            try:
                with open(backup_file, 'r') as f:
                    return json.load(f)
            except json.JSONDecodeError:
                logger.error("Backup also corrupted, returning empty memory")

        return _empty_memory()


def _empty_memory() -> Dict[str, Any]:
    """Return an empty memory structure.

    Returns:
        Empty memory dictionary with default structure
    """
    return {
        'preferences': [],
        'created_at': datetime.now().isoformat(),
        'updated_at': datetime.now().isoformat(),
        'version': '1.0'
    }
