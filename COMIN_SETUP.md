# Comin GitOps Setup Guide

This guide explains how to set up and use Comin for automatic GitOps deployments on your NixOS VPS.

## What is Comin?

Comin is a service that automatically:
- Monitors your Git repository for changes
- Pulls new commits from the main branch
- Rebuilds your NixOS configuration
- Applies changes to your VPS

**Result**: Push to GitHub → VPS automatically updates within ~60 seconds!

## Prerequisites

1. Your NixOS configuration in a Git repository (GitHub/GitLab)
2. SSH access to your VPS
3. (Optional) GitHub personal access token if repo is private

## Setup Instructions

### 1. Update Your secrets.nix

Edit your `secrets.nix` file on the VPS:

```bash
ssh your-vps
nano /etc/nixos/secrets.nix
```

Add the following section:

```nix
  # Comin - GitOps Configuration
  comin = {
    # Your NixOS configuration repository URL
    repoUrl = "https://github.com/YOURUSERNAME/nixos-config";

    # Optional: For private repositories only
    # tokenPath = "/root/.github-token";
  };
```

Replace `YOURUSERNAME/nixos-config` with your actual repository URL.

### 2. (Optional) Set Up GitHub Token for Private Repos

If your repository is **private**, create a GitHub personal access token:

#### Create Token:
1. Go to GitHub Settings → Developer settings → Personal access tokens
2. Click "Fine-grained tokens" or "Tokens (classic)"
3. Generate new token with these permissions:
   - **Fine-grained**: "Contents: Read-only" for your nixos-config repo
   - **Classic**: `repo` scope (read access)
4. Copy the token (starts with `ghp_...`)

#### Save Token on VPS:
```bash
ssh your-vps
echo "ghp_YOUR_TOKEN_HERE" > /root/.github-token
chmod 600 /root/.github-token
```

#### Update secrets.nix:
```nix
  comin = {
    repoUrl = "https://github.com/YOURUSERNAME/nixos-config";
    tokenPath = "/root/.github-token";  # Uncomment this line
  };
```

Then update `modules/comin.nix` to uncomment the auth line:
```nix
        # Uncomment if your repo is private
        auth.access_token_path = secrets.comin.tokenPath;
```

### 3. Deploy Comin Configuration

From your **local machine**:

```bash
cd /path/to/your/nixos-config

# Commit the Comin configuration
git add flake.nix configuration.nix modules/comin.nix
git commit -m "Add Comin GitOps configuration"
git push origin main

# Deploy to VPS
ssh your-vps "cd /etc/nixos && git pull origin main && nixos-rebuild switch --flake /etc/nixos#vps"
```

### 4. Verify Comin is Running

Check the service status:

```bash
ssh your-vps "systemctl status comin"
```

You should see:
```
● comin.service - Comin - GitOps for NixOS
     Loaded: loaded
     Active: active (running)
```

View logs:
```bash
ssh your-vps "journalctl -u comin -f"
```

You'll see messages like:
```
Polling repository: origin
Checking for updates...
```

### 5. Test Automatic Deployment

Make a small change to test:

```bash
cd /path/to/your/nixos-config

# Make a harmless change (e.g., add a comment)
echo "# Test comment" >> configuration.nix

# Commit and push
git add configuration.nix
git commit -m "Test Comin automatic deployment"
git push origin main

# Watch the magic happen!
ssh your-vps "journalctl -u comin -f"
```

Within ~60 seconds, you should see Comin detect the change, pull it, and rebuild.

## How Comin Works

1. **Polling**: Every 60 seconds, Comin checks your repository for new commits
2. **Pull**: If new commits found, pulls latest changes
3. **Rebuild**: Runs `nixos-rebuild switch --flake /etc/nixos#vps`
4. **Apply**: New configuration is activated immediately
5. **Repeat**: Continues monitoring

## Configuration Options

### Change Polling Interval

Edit `modules/comin.nix`:

```nix
services.comin = {
  enable = true;

  # Check every 5 minutes instead of 60 seconds
  interval = "5m";

  remotes = [ ... ];
};
```

### Watch Multiple Branches

```nix
remotes = [
  {
    name = "origin";
    url = secrets.comin.repoUrl;

    # Production branch
    branches.main.name = "main";

    # Staging branch
    branches.staging.name = "staging";
  }
];
```

### Disable Comin Temporarily

```bash
# Stop the service
ssh your-vps "systemctl stop comin"

# Re-enable later
ssh your-vps "systemctl start comin"
```

## Troubleshooting

### Comin Not Pulling Changes

**Check repository URL:**
```bash
ssh your-vps "cat /etc/nixos/secrets.nix | grep repoUrl"
```

**Check authentication (for private repos):**
```bash
ssh your-vps "cat /root/.github-token"
ssh your-vps "ls -la /root/.github-token"  # Should be 600 permissions
```

**Check logs for errors:**
```bash
ssh your-vps "journalctl -u comin -n 100"
```

### Authentication Failures

If you see "authentication failed" errors:

1. Verify token is valid: Test it manually:
   ```bash
   curl -H "Authorization: token $(cat /root/.github-token)" \
        https://api.github.com/repos/YOURUSERNAME/nixos-config
   ```

2. Check token permissions (must have `repo` or `Contents` read access)

3. Regenerate token if needed

### Comin Pulls But Doesn't Rebuild

Check for rebuild errors:
```bash
ssh your-vps "journalctl -u comin -n 200 | grep -A 10 error"
```

Test manual rebuild:
```bash
ssh your-vps "cd /etc/nixos && nixos-rebuild switch --flake /etc/nixos#vps"
```

### Roll Back Bad Configuration

If Comin deploys a broken configuration:

```bash
# Stop Comin temporarily
ssh your-vps "systemctl stop comin"

# Roll back to previous generation
ssh your-vps "nixos-rebuild switch --rollback --flake /etc/nixos#vps"

# Fix the issue in Git, then re-enable Comin
ssh your-vps "systemctl start comin"
```

## Security Considerations

### Public Repositories
- ✅ Safe to use without authentication
- ✅ Configuration structure is public (good for reproducibility)
- ⚠️ Never commit `secrets.nix` (it's gitignored)

### Private Repositories
- ✅ Additional security through obscurity
- ⚠️ Requires GitHub token stored on VPS
- ⚠️ Token has read-only access (minimal risk)
- ✅ Token file has 600 permissions (root only)

### Best Practices
1. Use **fine-grained tokens** with minimal permissions
2. Set token expiration (e.g., 90 days, then rotate)
3. Never commit tokens to Git
4. Test changes locally before pushing
5. Monitor Comin logs for unexpected rebuilds

## Advantages of Comin

✅ **No manual SSH needed**: Push and forget
✅ **Fast**: Updates within 60 seconds
✅ **Declarative**: Everything in Git
✅ **Rollback friendly**: Git history + NixOS generations
✅ **Auditable**: All changes in Git log

## Alternative: Manual Deployment

If you prefer manual control:

```bash
# Disable Comin
ssh your-vps "systemctl disable --now comin"

# Deploy manually (as before)
ssh your-vps "cd /etc/nixos && git pull && nixos-rebuild switch --flake .#vps"
```

## Next Steps

Now that Comin is set up:

1. Update your workflow: Just `git push` to deploy!
2. Use feature branches for testing: merge to main when ready
3. Consider setting up GitHub Actions for syntax checking
4. Add notifications (e.g., Slack/Discord) on deployment success/failure

## Resources

- Comin GitHub: https://github.com/nlewo/comin
- Comin Documentation: https://github.com/nlewo/comin/tree/main/docs
- NixOS Flakes: https://nixos.wiki/wiki/Flakes

---

**Last Updated**: 2025-10-31
**Status**: Template - Ready to use
