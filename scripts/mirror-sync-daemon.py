#!/usr/bin/env python3
"""
Mirror Sync Daemon - Background service for automatic repository synchronization

This daemon runs continuously and synchronizes mirrored repositories on their
configured schedules. It uses croniter for schedule parsing and supports
parallel syncing with configurable concurrency limits.

Features:
- Cron-based scheduling with croniter
- Parallel sync up to max_concurrent limit (default: 3)
- Timeout enforcement per repository
- Low priority execution (nice -n 19)
- Graceful shutdown on SIGTERM
- Automatic status tracking and logging
"""

import sys
import os
import time
import signal
import subprocess
import json
from datetime import datetime
from concurrent.futures import ThreadPoolExecutor, as_completed

# Add bundled library path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'lib'))
from croniter import croniter

# Configuration
CONFIG_FILE = "/opt/cgit/data/mirror-config.json"
LOG_FILE = "/opt/cgit/data/logs/mirror-sync.log"
LOG_DIR = "/opt/cgit/data/logs"
MAX_LOG_SIZE = 10 * 1024 * 1024  # 10MB
MAX_ROTATED_LOGS = 3

# Global flag for graceful shutdown
shutdown_requested = False


class SimpleLogger:
    """Simplified logger for the daemon"""
    
    def __init__(self):
        os.makedirs(LOG_DIR, exist_ok=True)
        self.check_rotation()
    
    def check_rotation(self):
        """Check and rotate log file if needed"""
        if not os.path.exists(LOG_FILE):
            return
            
        if os.path.getsize(LOG_FILE) >= MAX_LOG_SIZE:
            # Rotate existing logs
            import glob
            existing_logs = sorted(glob.glob(f"{LOG_FILE}.*"), reverse=True)
            
            # Delete old logs beyond max count
            for old_log in existing_logs[MAX_ROTATED_LOGS-1:]:
                try:
                    os.remove(old_log)
                except OSError:
                    pass
            
            # Rotate numbered logs
            for old_log in existing_logs[:MAX_ROTATED_LOGS-1]:
                try:
                    num = int(old_log.split('.')[-1])
                    new_path = f"{LOG_FILE}.{num + 1}"
                    os.rename(old_log, new_path)
                except (ValueError, OSError):
                    pass
            
            # Move current log to .1
            try:
                os.rename(LOG_FILE, f"{LOG_FILE}.1")
            except OSError:
                pass
    
    def _log(self, level, message):
        """Write log message"""
        self.check_rotation()
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        log_line = f"[{timestamp}] [{level}] {message}\n"
        
        # Write to file
        with open(LOG_FILE, 'a') as f:
            f.write(log_line)
        
        # Write to stdout
        sys.stdout.write(log_line)
        sys.stdout.flush()
    
    def info(self, message):
        self._log("INFO", message)
    
    def success(self, message):
        self._log("SUCCESS", message)
    
    def warning(self, message):
        self._log("WARNING", message)
    
    def error(self, message):
        self._log("ERROR", message)


class SimpleConfigManager:
    """Simplified config manager for the daemon"""
    
    def __init__(self):
        self.config_file = CONFIG_FILE
        self.config = self.load_config()
    
    def load_config(self):
        """Load configuration from file"""
        if not os.path.exists(self.config_file):
            return {
                "version": "1.0",
                "defaults": {
                    "schedule": "0 */6 * * *",
                    "timeout": 600,
                    "max_concurrent": 3
                },
                "mirrors": {}
            }
        
        try:
            with open(self.config_file, 'r') as f:
                return json.load(f)
        except Exception:
            return {
                "version": "1.0",
                "defaults": {
                    "schedule": "0 */6 * * *",
                    "timeout": 600,
                    "max_concurrent": 3
                },
                "mirrors": {}
            }
    
    def save_config(self):
        """Save configuration to file"""
        os.makedirs(os.path.dirname(self.config_file), exist_ok=True)
        with open(self.config_file, 'w') as f:
            json.dump(self.config, f, indent=2)
    
    def get_due_mirrors(self):
        """Get list of mirrors that are due for sync"""
        now = datetime.now()
        due_mirrors = []
        
        for repo_name, mirror in self.config.get("mirrors", {}).items():
            if not mirror.get("enabled", True):
                continue
            
            # Parse the schedule
            schedule = mirror.get("schedule", self.config["defaults"]["schedule"])
            last_sync_str = mirror.get("last_sync")
            
            try:
                if last_sync_str:
                    last_sync = datetime.fromisoformat(last_sync_str.replace('Z', '+00:00'))
                    # Remove timezone info for croniter
                    last_sync = last_sync.replace(tzinfo=None)
                else:
                    # Never synced, use a time in the past
                    last_sync = datetime(2000, 1, 1)
                
                # Calculate next sync time
                cron = croniter(schedule, last_sync)
                next_sync = cron.get_next(datetime)
                
                if next_sync <= now:
                    due_mirrors.append({
                        'name': repo_name,
                        'timeout': mirror.get('timeout', self.config["defaults"]["timeout"]),
                        'last_sync': last_sync_str
                    })
            except Exception as e:
                logger.error(f"{repo_name}: Error calculating next sync: {str(e)}")
                continue
        
        # Sort by last_sync (oldest first)
        due_mirrors.sort(key=lambda x: x['last_sync'] or '')
        return due_mirrors
    
    def update_sync_status(self, repo_name, status, error_message):
        """Update sync status for a repository"""
        if repo_name not in self.config.get("mirrors", {}):
            return
        
        mirror = self.config["mirrors"][repo_name]
        mirror["last_sync"] = datetime.now().isoformat() + 'Z'
        mirror["last_status"] = status
        mirror["last_error"] = error_message
        
        # Calculate next sync time
        try:
            schedule = mirror.get("schedule", self.config["defaults"]["schedule"])
            cron = croniter(schedule, datetime.now())
            next_sync = cron.get_next(datetime)
            mirror["next_sync"] = next_sync.isoformat() + 'Z'
        except Exception:
            pass
        
        self.save_config()


def signal_handler(signum, frame):
    """Handle SIGTERM/SIGINT for graceful shutdown"""
    global shutdown_requested, logger
    if logger:
        logger.info(f"Received signal {signum}, initiating graceful shutdown...")
    shutdown_requested = True


def sync_repository(repo_name, timeout, log):
    """
    Synchronize a single repository with timeout enforcement
    
    Args:
        repo_name: Name of the repository to sync
        timeout: Timeout in seconds
        log: Logger instance
        
    Returns:
        tuple: (repo_name, success, duration, error_message)
    """
    start_time = time.time()
    repo_path = os.path.join("/opt/cgit/data/repositories", f"{repo_name}.git")
    
    if not os.path.isdir(repo_path):
        error = f"Repository path does not exist: {repo_path}"
        log.error(f"{repo_name}: {error}")
        return (repo_name, False, 0, error)
    
    log.info(f"{repo_name}: Starting sync (timeout: {timeout}s)")
    
    try:
        # Run git remote update with timeout
        result = subprocess.run(
            ["git", "-C", repo_path, "remote", "update", "--prune"],
            timeout=timeout,
            capture_output=True,
            text=True
        )
        
        duration = time.time() - start_time
        
        if result.returncode == 0:
            log.success(f"{repo_name}: Synced successfully ({duration:.1f}s)")
            return (repo_name, True, duration, None)
        else:
            error = f"Git command failed (exit {result.returncode}): {result.stderr.strip()}"
            log.error(f"{repo_name}: {error}")
            return (repo_name, False, duration, error)
            
    except subprocess.TimeoutExpired:
        duration = time.time() - start_time
        error = f"Timeout after {timeout}s"
        log.error(f"{repo_name}: {error}")
        return (repo_name, False, duration, error)
        
    except Exception as e:
        duration = time.time() - start_time
        error = f"Unexpected error: {str(e)}"
        log.error(f"{repo_name}: {error}")
        return (repo_name, False, duration, error)


def sync_cycle(cfg, log):
    """
    Perform one sync cycle: check due repositories and sync them
    
    Args:
        cfg: Config manager instance
        log: Logger instance
    
    Returns:
        int: Number of repositories synced
    """
    try:
        # Reload config to pick up any changes
        cfg.config = cfg.load_config()
        
        # Get repositories that are due for sync
        due_mirrors = cfg.get_due_mirrors()
        
        if not due_mirrors:
            return 0
        
        log.info(f"Found {len(due_mirrors)} repositories due for sync")
        
        max_concurrent = cfg.config.get("defaults", {}).get("max_concurrent", 3)
        synced_count = 0
        
        # Sync repositories in parallel (up to max_concurrent)
        with ThreadPoolExecutor(max_workers=max_concurrent) as executor:
            # Submit all sync tasks
            future_to_repo = {}
            for mirror in due_mirrors:
                repo_name = mirror['name']
                timeout = mirror['timeout']
                future = executor.submit(sync_repository, repo_name, timeout, log)
                future_to_repo[future] = repo_name
            
            # Process results as they complete
            for future in as_completed(future_to_repo):
                repo_name, success, duration, error = future.result()
                
                # Update sync status in config
                if success:
                    cfg.update_sync_status(repo_name, "success", None)
                else:
                    cfg.update_sync_status(repo_name, "failed", error)
                
                synced_count += 1
        
        if synced_count > 0:
            log.info(f"Sync cycle complete: {synced_count} repositories processed")
        
        return synced_count
        
    except Exception as e:
        log.error(f"Error in sync cycle: {str(e)}")
        return 0


def main():
    """Main daemon loop"""
    global logger
    
    logger = SimpleLogger()
    config_manager = SimpleConfigManager()
    
    # Register signal handlers
    signal.signal(signal.SIGTERM, signal_handler)
    signal.signal(signal.SIGINT, signal_handler)
    
    logger.info("Mirror sync daemon starting...")
    logger.info(f"Check interval: 60 seconds")
    
    defaults = config_manager.config.get("defaults", {})
    logger.info(f"Max concurrent syncs: {defaults.get('max_concurrent', 3)}")
    logger.info(f"Default schedule: {defaults.get('schedule', '0 */6 * * *')}")
    logger.info(f"Default timeout: {defaults.get('timeout', 600)}s")
    
    cycle_count = 0
    
    while not shutdown_requested:
        try:
            # Perform sync cycle
            sync_cycle(config_manager, logger)
            cycle_count += 1
            
            # Sleep for 60 seconds (wake up every minute)
            # Use small sleep intervals to allow faster shutdown
            for _ in range(60):
                if shutdown_requested:
                    break
                time.sleep(1)
                
        except Exception as e:
            logger.error(f"Unexpected error in main loop: {str(e)}")
            time.sleep(60)  # Sleep before retrying
    
    logger.info(f"Daemon shutdown complete (processed {cycle_count} cycles)")


if __name__ == "__main__":
    main()
