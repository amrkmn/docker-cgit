#!/usr/bin/env python3
"""
Mirror sync logging utilities with automatic rotation
Handles structured logging for repository mirror synchronization
"""

import os
import sys
from datetime import datetime
import glob

# Default paths
LOG_DIR = os.getenv("MIRROR_LOG_DIR", "/opt/cgit/data/logs")
LOG_FILE = os.path.join(LOG_DIR, "mirror-sync.log")
MAX_LOG_SIZE = 10 * 1024 * 1024  # 10MB
MAX_ROTATED_LOGS = 3  # Keep only 3 rotated logs


class MirrorLogger:
    """Logger with automatic rotation for mirror sync operations"""
    
    def __init__(self, log_file=LOG_FILE):
        self.log_file = log_file
        self.log_dir = os.path.dirname(log_file)
        self._ensure_log_dir()
    
    def _ensure_log_dir(self):
        """Create log directory if it doesn't exist"""
        if not os.path.exists(self.log_dir):
            os.makedirs(self.log_dir, mode=0o755, exist_ok=True)
    
    def _rotate_if_needed(self):
        """Rotate log file if it exceeds MAX_LOG_SIZE"""
        if not os.path.exists(self.log_file):
            return
        
        if os.path.getsize(self.log_file) >= MAX_LOG_SIZE:
            self._rotate_logs()
    
    def _rotate_logs(self):
        """Rotate log files: .log -> .log.1 -> .log.2 -> .log.3"""
        # Remove oldest log if it exists (.log.3)
        oldest_log = f"{self.log_file}.{MAX_ROTATED_LOGS}"
        if os.path.exists(oldest_log):
            os.remove(oldest_log)
        
        # Rotate existing logs: .log.2 -> .log.3, .log.1 -> .log.2
        for i in range(MAX_ROTATED_LOGS - 1, 0, -1):
            old_log = f"{self.log_file}.{i}"
            new_log = f"{self.log_file}.{i + 1}"
            if os.path.exists(old_log):
                os.rename(old_log, new_log)
        
        # Rotate current log: .log -> .log.1
        if os.path.exists(self.log_file):
            os.rename(self.log_file, f"{self.log_file}.1")
    
    def _log(self, level, message):
        """Write log entry with timestamp and level"""
        self._rotate_if_needed()
        
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        log_line = f"[{timestamp}] [{level}] {message}\n"
        
        with open(self.log_file, 'a') as f:
            f.write(log_line)
        
        # Also print to stdout for service logs
        sys.stdout.write(log_line)
        sys.stdout.flush()
    
    def info(self, message):
        """Log info message"""
        self._log("INFO", message)
    
    def success(self, message):
        """Log success message"""
        self._log("SUCCESS", message)
    
    def error(self, message):
        """Log error message"""
        self._log("ERROR", message)
    
    def warning(self, message):
        """Log warning message"""
        self._log("WARNING", message)
    
    def get_recent_logs(self, repo_name=None, limit=50):
        """
        Get recent log entries, optionally filtered by repo name
        
        Args:
            repo_name: Filter logs for this repository (optional)
            limit: Maximum number of log lines to return
        
        Returns:
            List of log lines
        """
        all_logs = []
        
        # Read current log
        if os.path.exists(self.log_file):
            with open(self.log_file, 'r') as f:
                all_logs.extend(f.readlines())
        
        # Read rotated logs (newest first)
        for i in range(1, MAX_ROTATED_LOGS + 1):
            rotated_log = f"{self.log_file}.{i}"
            if os.path.exists(rotated_log):
                with open(rotated_log, 'r') as f:
                    all_logs.extend(f.readlines())
        
        # Filter by repo name if provided
        if repo_name:
            all_logs = [line for line in all_logs if repo_name in line]
        
        # Return most recent entries (reverse chronological)
        return all_logs[-limit:] if limit else all_logs
    
    def clear_old_logs(self):
        """Remove all rotated logs beyond MAX_ROTATED_LOGS"""
        # Find all .log.N files
        log_pattern = f"{self.log_file}.*"
        log_files = glob.glob(log_pattern)
        
        for log_file in log_files:
            # Extract rotation number
            try:
                parts = log_file.split('.')
                if len(parts) > 2 and parts[-1].isdigit():
                    rotation_num = int(parts[-1])
                    if rotation_num > MAX_ROTATED_LOGS:
                        os.remove(log_file)
            except (ValueError, IndexError):
                pass


# Singleton instance
_logger = None

def get_logger():
    """Get the singleton MirrorLogger instance"""
    global _logger
    if _logger is None:
        _logger = MirrorLogger()
    return _logger


if __name__ == "__main__":
    # Test logging
    logger = get_logger()
    
    print("Testing mirror logger...")
    logger.info("Test info message")
    logger.success("Test success message")
    logger.warning("Test warning message")
    logger.error("Test error message")
    
    print(f"\nLog file: {logger.log_file}")
    print(f"Log directory: {logger.log_dir}")
    print(f"Max log size: {MAX_LOG_SIZE / (1024*1024)}MB")
    print(f"Max rotated logs: {MAX_ROTATED_LOGS}")
    
    print("\n✓ Mirror logger test complete!")
