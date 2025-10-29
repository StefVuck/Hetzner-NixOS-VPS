# NixOS VPS Configuration Template

A minimal, production-ready NixOS configuration for hosting web services with monitoring.

## Features

- **Declarative Configuration**: All system configuration in version control
- **Flakes Support**: Reproducible builds with locked dependencies
- **Web Services**: Nginx with automatic HTTPS (Let's Encrypt)
- **Monitoring Stack**: Prometheus, Loki, Grafana
- **Modular Design**: Easy to customize and extend

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

### 2. Configuration Structure

```
.
├── flake.nix                    # Flake configuration (dependencies)
├── configuration.nix             # Main system configuration
├── secrets.nix.example          # Template for secrets (copy to secrets.nix)
├── secrets.nix                  # Your actual secrets (gitignored)
├── hardware-configuration.nix   # Auto-generated hardware config (gitignored)
└── modules/
    ├── users.nix                # System users
    ├── networking-simple.nix    # Nginx, firewall, ACME
    ├── web-services.nix         # Your web services
    └── monitoring.nix           # Prometheus, Grafana, Loki
```

## Secrets Management

**Important**: `secrets.nix` is gitignored and never committed.

1. Copy `secrets.nix.example` to `secrets.nix`
2. Fill in your actual values (domains, passwords, SSH keys, etc.)
3. Keep `secrets.nix` secure and backed up separately

## Updating the System

```bash
cd /etc/nixos

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

- ✅ SSH key-based authentication only (passwords disabled)
- ✅ Firewall enabled (only ports 22, 80, 443 open)
- ✅ Automatic HTTPS with Let's Encrypt
- ✅ Secrets never committed to git
- ✅ Regular system updates with `nix flake update`

## Monitoring

Access Grafana at `https://grafana.yourdomain.com` (configured in secrets.nix)

Default dashboards:
- System metrics (CPU, RAM, disk, network)
- Nginx metrics (requests, response codes)
- System logs via Loki

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

