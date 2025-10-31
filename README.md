# NixOS VPS Configuration Template

A minimal, production-ready NixOS configuration for hosting web services with monitoring and GitOps deployment.

## Features

- **GitOps Deployment**: Automatic deployment with Comin (push to Git → VPS updates automatically)
- **Declarative Configuration**: All system configuration in version control
- **Flakes Support**: Reproducible builds with locked dependencies
- **NixOS 24.11**: Latest stable release with modern packages
- **Web Services**: Nginx with automatic HTTPS (Let's Encrypt)
- **Monitoring Stack**: Prometheus, Loki, Grafana with pre-configured dashboards
- **Modular Design**: Easy to customize and extend
- **Automatic Permissions**: Fixed directory permissions on every deployment

## Quick Start

### 1. Initial Setup

```bash
# On your VPS, clone this repo
cd /etc
mv nixos nixos.backup
git clone <your-repo-url> nixos
cd nixos

# Create your secrets file from the template
cp secrets.nix.example secrets.nix
vim secrets.nix  # Fill in your actual values

# Generate hardware configuration
nixos-generate-config --show-hardware-config > hardware-configuration.nix

# Apply the configuration
nixos-rebuild switch --flake .#vps
```

### 2. Set Up Comin (Optional but Recommended)

Comin enables automatic GitOps deployment - push to GitHub and your VPS updates automatically!

See [COMIN_SETUP.md](COMIN_SETUP.md) for detailed instructions.

**Quick setup**:
1. Configure `secrets.nix` with your repository URL
2. (Optional) Create GitHub token for private repos
3. Rebuild with Comin enabled
4. Push changes → automatic deployment within 60 seconds!

### 3. Configuration Structure

```
.
├── flake.nix                    # Flake configuration (dependencies, including Comin)
├── configuration.nix             # Main system configuration
├── secrets.nix.example          # Template for secrets (copy to secrets.nix)
├── secrets.nix                  # Your actual secrets (gitignored)
├── hardware-configuration.nix   # Auto-generated hardware config (gitignored)
├── COMIN_SETUP.md               # GitOps setup guide
└── modules/
    ├── users.nix                # System users with permission fixes
    ├── networking-simple.nix    # Nginx, firewall, ACME
    ├── web-services.nix         # Your web services
    ├── monitoring.nix           # Prometheus, Grafana, Loki
    └── comin.nix                # GitOps configuration
```

## Secrets Management

**Important**: `secrets.nix` is gitignored and never committed.

1. Copy `secrets.nix.example` to `secrets.nix`
2. Fill in your actual values (domains, passwords, SSH keys, etc.)
3. Keep `secrets.nix` secure and backed up separately

## Updating the System

### With Comin (GitOps - Recommended)

```bash
# Make changes locally
vim modules/networking-simple.nix

# Commit and push - Comin handles the rest!
git add .
git commit -m "Update nginx configuration"
git push origin main

# VPS automatically updates within 60 seconds
# Watch deployment: ssh your-vps "journalctl -u comin -f"
```

### Manual Deployment (Traditional)

```bash
ssh your-vps
cd /etc/nixos

# Pull latest changes
git pull origin main

# Update flake inputs (nixpkgs, etc.)
nix flake update

# Apply changes
nixos-rebuild switch --flake .#vps

# Rollback if needed
nixos-rebuild switch --rollback --flake .#vps
```

## Customization

### Adding a New Web Service

1. Add service configuration to `modules/web-services.nix`
2. Add nginx virtualHost to `modules/networking-simple.nix`
3. Rebuild: `nixos-rebuild switch --flake .#vps`

### Adding System Packages

Edit `configuration.nix`:

```nix
environment.systemPackages = with pkgs; [
  vim
  git
  your-package-here
];
```

## Security Best Practices

- SSH key-based authentication only (passwords disabled)
- Firewall enabled (only ports 22, 80, 443 open)
- Automatic HTTPS with Let's Encrypt
- Secrets never committed to git
- Regular system updates with `nix flake update`

## Monitoring

Access Grafana at `https://grafana.yourdomain.com` (configured in secrets.nix)

Pre-configured dashboards (automatically downloaded on first boot):
- **Node Exporter Full** (Dashboard 1860): Comprehensive system metrics - CPU, RAM, disk, network
- **Nginx Metrics** (Dashboard 12708): Nginx performance metrics - requests/sec, response codes, connections
- **Service Logs**: Multi-panel log viewer for nginx, grafana, prometheus, loki, and promtail services

The template includes these baseline dashboards. Your production setup can add more specialized dashboards like web analytics with GeoIP tracking.

## What's New in This Template

### Version 1.1 (2025-10-31)

- **GitOps with Comin**: Automatic deployment from Git
- **NixOS 24.11**: Upgraded to latest stable release
- **Permission Fixes**: Automatic permission fixes on every deployment
- **Enhanced Monitoring**: Pre-configured Grafana dashboards
- **Better Documentation**: Comprehensive setup guides

## Troubleshooting

```bash
# Check service status
systemctl status nginx
systemctl status grafana

# View logs
journalctl -u nginx -f
journalctl -u your-service -f

# Test configuration without applying
nixos-rebuild test --flake .#vps

# Check what would change
nixos-rebuild dry-build --flake .#vps
```

## License

MIT

