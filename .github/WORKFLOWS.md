# GitHub Actions Workflows

This document describes the automated CI/CD pipeline for the PostgreSQL GDExtension project.

## Workflow Overview

### 🔨 Build Workflow (`build.yml`)
**Triggers:** Push to main/master/develop, Pull Requests, Releases, Manual dispatch

**Features:**
- **Multi-platform builds:** Linux (x86_64, ARM64), Windows (x86_64), macOS (Universal)
- **Build caching:** SCons cache for faster subsequent builds
- **Artifact management:** Automatic upload of build artifacts
- **Release automation:** Automatic package creation and release uploads
- **Build testing:** Verification of build outputs

**Build Matrix:**
```yaml
Linux:   x86_64 (debug/release), ARM64 (release only)
Windows: x86_64 (debug/release)
macOS:   Universal (debug/release)
```

**Outputs:**
- Linux: `.so` shared libraries
- Windows: `.dll` dynamic libraries  
- macOS: `.framework` bundles
- Cross-platform `.gdextension` configuration

### 🌙 Nightly Builds (`nightly.yml`)
**Triggers:** Daily at 2 AM UTC, Manual dispatch

**Purpose:**
- Continuous integration testing
- Early detection of build issues
- Bleeding-edge builds for testing

**Retention:** 7 days

### 🧪 Test Workflow (`test.yml`)
**Triggers:** Push to main branches, Pull Requests, Manual dispatch

**Test Categories:**
- **Static Analysis:** cppcheck, code formatting
- **Build Testing:** Verify build scripts work correctly
- **Dependency Security:** Check for vulnerable dependencies
- **Documentation:** Validate documentation completeness

### 📊 Status Workflow (`status.yml`)
**Triggers:** Every 6 hours, Manual dispatch

**Monitoring:**
- Repository health metrics
- Build status tracking
- Feature completion status
- Platform support overview

## Workflow Configuration

### Environment Variables
```yaml
GODOT_VERSION: "4.4"
SCONS_CACHE_SIZE: "7168"
```

### Build Dependencies

#### Linux (Ubuntu)
```bash
sudo apt-get install -y libpqxx-dev libpq-dev build-essential pkg-config
pip install scons
```

#### Windows
```powershell
# PostgreSQL binaries downloaded automatically
# Visual Studio Build Tools required
pip install scons
```

#### macOS
```bash
brew install libpqxx postgresql pkg-config
pip install scons
```

## Artifact Management

### Build Artifacts
- **Retention:** 7 days for regular builds, 30 days for release packages
- **Naming:** `{platform}-{arch}-{target}` (e.g., `linux-x86_64-template_release`)
- **Contents:** Platform binaries + GDExtension configuration

### Release Packages
- **Format:** `.tar.gz` and `.zip` archives
- **Contents:** All platform binaries, documentation, demo files
- **Checksums:** SHA256 verification files included
- **Metadata:** Version info, build timestamp, commit hash

## Manual Workflow Triggers

### Build Workflow
```bash
# Trigger via GitHub CLI
gh workflow run build.yml

# With custom build type
gh workflow run build.yml -f build_type=release
```

### Test Workflow
```bash
gh workflow run test.yml
```

### Nightly Build
```bash
gh workflow run nightly.yml
```

## Workflow Badges

Add these badges to your README for status visibility:

```markdown
![Build Status](https://github.com/yourusername/PostgrePlugin/workflows/Build%20PostgreSQL%20GDExtension/badge.svg)
![Tests](https://github.com/yourusername/PostgrePlugin/workflows/Test%20PostgreSQL%20Extension/badge.svg)
![Nightly](https://github.com/yourusername/PostgrePlugin/workflows/Nightly%20Builds/badge.svg)
```

## Security Considerations

### Secrets Management
- No sensitive data in workflows
- PostgreSQL credentials not stored (test databases would use environment variables)
- GitHub token automatically provided for releases

### Dependency Security
- Regular dependency updates via Dependabot (recommended)
- Security scanning in test workflow
- Minimal external dependencies

## Performance Optimization

### Build Caching
- SCons cache enabled for faster rebuilds
- godot-cpp binaries cached per platform/target
- Cache keys include relevant file hashes

### Parallel Building
- Uses all available CPU cores: `-j$(nproc)` (Linux), `-j%NUMBER_OF_PROCESSORS%` (Windows)
- Matrix builds run in parallel across platforms
- Artifact uploads happen concurrently

### Resource Management
- Builds use appropriate runner sizes
- Artifact retention policies prevent storage bloat
- Conditional workflows (only run on relevant changes)

## Troubleshooting

### Common Issues

#### Build Failures
1. Check dependency installation logs
2. Verify PostgreSQL library availability
3. Review SCons build output
4. Check platform-specific requirements

#### Artifact Upload Failures
1. Verify artifact paths exist
2. Check file permissions
3. Ensure artifacts aren't empty

#### Release Upload Issues
1. Verify `GITHUB_TOKEN` permissions
2. Check release trigger conditions
3. Validate package creation steps

### Debug Workflow Runs
```bash
# Download artifacts for inspection
gh run download <run-id>

# View workflow logs
gh run view <run-id> --log

# Re-run failed jobs
gh run rerun <run-id> --failed
```

## Workflow Customization

### Adding New Platforms
1. Update build matrix in `build.yml`
2. Add platform-specific dependency installation
3. Create corresponding build script
4. Update artifact paths and naming

### Modifying Build Targets
1. Update strategy matrix
2. Adjust artifact collection paths
3. Update documentation

### Custom Test Scenarios
1. Add new job to `test.yml`
2. Define test dependencies
3. Implement test verification steps

## Maintenance

### Regular Updates
- Update action versions (monthly)
- Review and update dependencies
- Monitor workflow performance
- Update documentation

### Monitoring
- Review workflow run history
- Check artifact storage usage
- Monitor build times for performance regressions
- Validate cross-platform compatibility

This CI/CD pipeline ensures reliable, automated builds across all supported platforms while maintaining code quality and providing comprehensive testing.