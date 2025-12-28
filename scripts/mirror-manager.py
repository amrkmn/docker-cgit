#!/usr/bin/env python3
"""
Mirror configuration management
Handles reading/writing mirror configuration in JSON format
"""

import os
import sys
import json
from datetime import datetime

# Add bundled libraries to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'lib'))

from croniter import croniter

# Default paths
CONFIG_FILE = os.getenv("MIRROR_CONFIG_FILE", "/opt/cgit/data/mirror-config.json")
DEFAULT_SCHEDULE = "0 */6 * * *"  # Every 6 hours
DEFAULT_TIMEOUT = 600  # 10 minutes
MAX_CONCURRENT = 3


class MirrorConfig:
    """Manager for mirror configuration"""
    
    def __init__(self, config_file=CONFIG_FILE):
        self.config_file = config_file
        self.config_dir = os.path.dirname(config_file)
        self._ensure_config_dir()
        self.config = self._load_or_create_config()
    
    def _ensure_config_dir(self):
        """Create config directory if it doesn't exist"""
        if not os.path.exists(self.config_dir):
            os.makedirs(self.config_dir, mode=0o755, exist_ok=True)
    
    def _load_or_create_config(self):
        """Load existing config or create new one"""
        if os.path.exists(self.config_file):
            try:
                with open(self.config_file, 'r') as f:
                    return json.load(f)
            except (json.JSONDecodeError, IOError) as e:
                print(f"Warning: Failed to load config: {e}", file=sys.stderr)
                print("Creating new config...", file=sys.stderr)
                return self._create_default_config()
        else:
            return self._create_default_config()
    
    def _create_default_config(self):
        """Create default configuration structure"""
        return {
            "version": "1.0",
            "defaults": {
                "schedule": DEFAULT_SCHEDULE,
                "timeout": DEFAULT_TIMEOUT,
                "max_concurrent": MAX_CONCURRENT
            },
            "mirrors": {}
        }
    
    def save(self):
        """Save configuration to file"""
        try:
            # Write to temp file first, then rename (atomic operation)
            temp_file = f"{self.config_file}.tmp"
            with open(temp_file, 'w') as f:
                json.dump(self.config, f, indent=2)
            os.rename(temp_file, self.config_file)
            return True
        except (IOError, OSError) as e:
            print(f"Error: Failed to save config: {e}", file=sys.stderr)
            return False
    
    def enable_mirror(self, repo_name, schedule=None, timeout=None):
        """
        Enable mirroring for a repository (idempotent)
        
        Args:
            repo_name: Repository name
            schedule: Cron expression (default: every 6 hours)
            timeout: Timeout in seconds (default: 600)
        
        Returns:
            True if successful, False otherwise
        """
        # Validate schedule if provided
        if schedule:
            try:
                croniter(schedule)
            except Exception as e:
                print(f"Error: Invalid cron schedule '{schedule}': {e}", file=sys.stderr)
                return False
        
        # Use defaults if not provided
        schedule = schedule or self.config["defaults"]["schedule"]
        timeout = timeout or self.config["defaults"]["timeout"]
        
        # Get existing mirror config or create new
        if repo_name in self.config["mirrors"]:
            mirror = self.config["mirrors"][repo_name]
            mirror["enabled"] = True
            mirror["schedule"] = schedule
            mirror["timeout"] = timeout
        else:
            self.config["mirrors"][repo_name] = {
                "enabled": True,
                "schedule": schedule,
                "timeout": timeout,
                "last_sync": None,
                "last_status": None,
                "last_error": None,
                "next_sync": self._calculate_next_sync(schedule)
            }
        
        return self.save()
    
    def disable_mirror(self, repo_name):
        """
        Disable mirroring for a repository (keeps in config)
        
        Args:
            repo_name: Repository name
        
        Returns:
            True if successful, False otherwise
        """
        if repo_name not in self.config["mirrors"]:
            print(f"Error: Repository '{repo_name}' not found in mirror config", file=sys.stderr)
            return False
        
        self.config["mirrors"][repo_name]["enabled"] = False
        return self.save()
    
    def get_mirror(self, repo_name):
        """
        Get mirror configuration for a repository
        
        Args:
            repo_name: Repository name
        
        Returns:
            Mirror config dict or None if not found
        """
        return self.config["mirrors"].get(repo_name)
    
    def list_mirrors(self, enabled_only=False):
        """
        List all mirrored repositories
        
        Args:
            enabled_only: Only return enabled mirrors
        
        Returns:
            List of (repo_name, mirror_config) tuples
        """
        mirrors = []
        for repo_name, mirror in self.config["mirrors"].items():
            if not enabled_only or mirror.get("enabled", False):
                mirrors.append((repo_name, mirror))
        return mirrors
    
    def update_sync_status(self, repo_name, status, error=None, duration=None):
        """
        Update sync status for a repository
        
        Args:
            repo_name: Repository name
            status: Status string ("success", "failed", "timeout", "error")
            error: Error message if failed (optional)
            duration: Sync duration in seconds (optional)
        
        Returns:
            True if successful, False otherwise
        """
        if repo_name not in self.config["mirrors"]:
            return False
        
        mirror = self.config["mirrors"][repo_name]
        mirror["last_sync"] = datetime.now().isoformat()
        mirror["last_status"] = status
        mirror["last_error"] = error
        
        if duration is not None:
            mirror["last_duration"] = duration
        
        # Calculate next sync time
        mirror["next_sync"] = self._calculate_next_sync(mirror["schedule"])
        
        return self.save()
    
    def _calculate_next_sync(self, schedule):
        """Calculate next sync time based on cron schedule"""
        try:
            cron = croniter(schedule, datetime.now())
            next_time = cron.get_next(datetime)
            return next_time.isoformat()
        except Exception:
            return None
    
    def get_due_mirrors(self):
        """
        Get list of mirrors that are due for sync
        
        Returns:
            List of (repo_name, mirror_config) tuples, sorted by last_sync (oldest first)
        """
        due_mirrors = []
        now = datetime.now()
        
        for repo_name, mirror in self.config["mirrors"].items():
            if not mirror.get("enabled", False):
                continue
            
            # Check if sync is due
            try:
                cron = croniter(mirror["schedule"], 
                               datetime.fromisoformat(mirror["last_sync"]) if mirror.get("last_sync") else now)
                next_sync = cron.get_next(datetime)
                
                if next_sync <= now:
                    due_mirrors.append((repo_name, mirror))
            except Exception:
                # If error parsing, include in due list (first sync or invalid schedule)
                if mirror.get("last_sync") is None:
                    due_mirrors.append((repo_name, mirror))
        
        # Sort by last_sync (oldest first, None values first)
        due_mirrors.sort(key=lambda x: x[1].get("last_sync") or "")
        
        return due_mirrors


def main():
    """CLI interface for mirror configuration management"""
    import argparse
    
    parser = argparse.ArgumentParser(description="Manage mirror configuration")
    subparsers = parser.add_subparsers(dest='command', help='Command')
    
    # Enable mirror
    enable_parser = subparsers.add_parser('enable', help='Enable mirroring for a repository')
    enable_parser.add_argument('repo_name', help='Repository name')
    enable_parser.add_argument('--schedule', help=f'Cron schedule (default: {DEFAULT_SCHEDULE})')
    enable_parser.add_argument('--timeout', type=int, help=f'Timeout in seconds (default: {DEFAULT_TIMEOUT})')
    
    # Disable mirror
    disable_parser = subparsers.add_parser('disable', help='Disable mirroring for a repository')
    disable_parser.add_argument('repo_name', help='Repository name')
    
    # List mirrors
    list_parser = subparsers.add_parser('list', help='List all mirrored repositories')
    list_parser.add_argument('--enabled-only', action='store_true', help='Only show enabled mirrors')
    
    # Get mirror info
    get_parser = subparsers.add_parser('get', help='Get mirror configuration')
    get_parser.add_argument('repo_name', help='Repository name')
    
    # Update sync status
    update_parser = subparsers.add_parser('update-status', help='Update sync status')
    update_parser.add_argument('repo_name', help='Repository name')
    update_parser.add_argument('status', choices=['success', 'failed', 'timeout', 'error'])
    update_parser.add_argument('--error', help='Error message')
    update_parser.add_argument('--duration', type=float, help='Duration in seconds')
    
    # Get due mirrors
    subparsers.add_parser('due', help='List mirrors due for sync')
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        return 1
    
    # Create config manager
    config = MirrorConfig()
    
    # Execute command
    if args.command == 'enable':
        if config.enable_mirror(args.repo_name, args.schedule, args.timeout):
            mirror = config.get_mirror(args.repo_name)
            print(f"✓ Mirror enabled for: {args.repo_name}")
            print(f"  Schedule: {mirror['schedule']}")
            print(f"  Timeout: {mirror['timeout']}s")
            print(f"  Next sync: {mirror.get('next_sync', 'pending')}")
            return 0
        else:
            return 1
    
    elif args.command == 'disable':
        if config.disable_mirror(args.repo_name):
            print(f"✓ Mirror disabled for: {args.repo_name}")
            return 0
        else:
            return 1
    
    elif args.command == 'list':
        mirrors = config.list_mirrors(args.enabled_only)
        if not mirrors:
            print("No mirrors configured" if not args.enabled_only else "No enabled mirrors")
            return 0
        
        print(f"Found {len(mirrors)} mirror(s):")
        for repo_name, mirror in mirrors:
            status = "✓ enabled" if mirror["enabled"] else "✗ disabled"
            last_sync = mirror.get("last_sync", "never")
            last_status = mirror.get("last_status", "N/A")
            print(f"  {repo_name}: {status}, last: {last_sync} ({last_status})")
        return 0
    
    elif args.command == 'get':
        mirror = config.get_mirror(args.repo_name)
        if not mirror:
            print(f"Error: Repository '{args.repo_name}' not found in mirror config", file=sys.stderr)
            return 1
        
        print(json.dumps(mirror, indent=2))
        return 0
    
    elif args.command == 'update-status':
        if config.update_sync_status(args.repo_name, args.status, args.error, args.duration):
            print(f"✓ Updated sync status for: {args.repo_name}")
            return 0
        else:
            return 1
    
    elif args.command == 'due':
        due_mirrors = config.get_due_mirrors()
        if not due_mirrors:
            print("No mirrors due for sync")
            return 0
        
        print(f"Found {len(due_mirrors)} mirror(s) due for sync:")
        for repo_name, mirror in due_mirrors:
            last_sync = mirror.get("last_sync", "never")
            print(f"  {repo_name} (last sync: {last_sync})")
        return 0
    
    return 0


if __name__ == "__main__":
    sys.exit(main())
