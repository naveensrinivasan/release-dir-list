# Release Directory Listing

This repository hosts a directory listing of GitHub releases for use with Nexus proxy.

## Setup

1. **Enable GitHub Pages**:
   - Go to repository Settings → Pages
   - Set source to "GitHub Actions"

2. **Create Releases**:
   - Go to Releases → Create a new release
   - Tag versions like `v1.0.0`, `v1.1.0`, etc.
   - Upload files to each release

3. **Workflow Triggers**:
   - Automatically triggers on new version tags (`v*.*.*`)
   - Can be manually triggered via Actions tab

## Usage

The directory listing will be available at:
```
https://naveensrinivasan.github.io/release-dir-list/
```

## Nexus Proxy Configuration

Point your Nexus proxy to the GitHub Pages URL above to access the directory listing.
