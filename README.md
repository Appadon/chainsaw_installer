# Chainsaw Setup Script

Automated installation script for [Chainsaw](https://github.com/WithSecureLabs/chainsaw) - A powerful forensic tool for searching and hunting through Windows event logs.

## Features

- 🦀 Automatic Rust/Cargo installation
- 📦 Builds Chainsaw from source
- 🎯 Clones and configures Sigma detection rules
- ⚡ Creates convenient bash aliases for rapid hunting
- 🔄 Idempotent - safe to run multiple times
- 🛡️ Comprehensive error handling

## Prerequisites

- Linux/Unix-based system (tested on Ubuntu, Arch Linux)
- Git
- curl
- Internet connection

## Quick Start

```bash
chmod +x setup_chainsaw.sh
./setup_chainsaw.sh
```

The script will:
1. Install Rust (if not present)
2. Clone Chainsaw repository
3. Build from source (~5 minutes)
4. Clone Sigma rules repository
5. Configure bash aliases
6. Update your PATH

After installation, reload your shell:
```bash
source ~/.bash_aliases
```

Or restart your terminal.

## Installation Details

### Directory Structure

```
~/enviros/chainsaw/
├── bin/
│   └── chainsaw          # Binary
├── sigma/
│   └── rules/            # Sigma detection rules
└── target/
    └── release/          # Build artifacts
```

### Environment Variables

The script configures the following environment variables:

- `CHAINSAW_HOME` - Points to installation directory
- `SIGMA_RULES` - Points to Sigma rules directory
- `PATH` - Updated to include Chainsaw binary

## Available Commands

### Core Commands

| Command | Description |
|---------|-------------|
| `chainsaw` | Main Chainsaw binary |
| `chainsaw-hunt` | Hunt with automatic Sigma path expansion |
| `chainsaw-search` | Search events |
| `chainsaw-analyse` | Analyse events |
| `chainsaw-dump` | Dump events |

### Sigma Rule Utilities

| Command | Description |
|---------|-------------|
| `goto-sigma` | Navigate to Sigma rules directory |
| `list-sigma` | List available rule categories |
| `find-sigma <term>` | Search for specific rules |
| `count-sigma` | Count total rules |

### Maintenance

| Command | Description |
|---------|-------------|
| `update-chainsaw` | Update Chainsaw and Sigma rules |

## Usage Examples

### Basic Event Hunting

```bash
chainsaw hunt /path/to/logs/*.evtx -s sigma/windows/process_creation/
```

### Using Simplified Hunt Command

```bash
chainsaw-hunt ./logs/*.evtx sigma/windows/process_creation/
```

The `sigma/` prefix automatically expands to the full path!

### Search for Specific Events

```bash
chainsaw search ./logs/*.evtx -t "EventID: 4624"
```

### Find Sigma Rules

```bash
find-sigma mimikatz
find-sigma powershell
find-sigma suspicious
```

### List Rule Categories

```bash
list-sigma
```

### Update Everything

```bash
update-chainsaw
```

## Advanced Usage

### Custom Sigma Mappings

```bash
chainsaw-hunt ./logs/ sigma/windows/ --mapping mappings/sigma-event-logs.yml
```

### Multiple Rule Directories

```bash
chainsaw hunt ./logs/*.evtx -s $SIGMA_RULES/windows/process_creation/ -s $SIGMA_RULES/windows/network/
```

### JSON Output

```bash
chainsaw hunt ./logs/*.evtx -s sigma/windows/ -o json
```

## Idempotent Reinstallation

If you need to reinstall or update:

```bash
./setup_chainsaw.sh
```

The script will prompt you to remove the existing installation before proceeding. This ensures a clean reinstall.

## Troubleshooting

### Rust Not in PATH

If you see "cargo: command not found" after installation:

```bash
source $HOME/.cargo/env
./setup_chainsaw.sh
```

### Aliases Not Working

Ensure `.bashrc` sources `.bash_aliases`:

```bash
echo 'if [ -f ~/.bash_aliases ]; then . ~/.bash_aliases; fi' >> ~/.bashrc
source ~/.bashrc
```

### Build Failures

Ensure you have sufficient disk space and memory:

```bash
df -h ~
free -h
```

Rust builds can require 2-4 GB of disk space.

### Manual Build

If automatic build fails:

```bash
cd ~/enviros/chainsaw
cargo build --release
mkdir -p bin
cp target/release/chainsaw bin/
```

## Uninstallation

To completely remove Chainsaw:

```bash
rm -rf ~/enviros/chainsaw
sed -i '/# Chainsaw aliases - Auto-generated/,/# End Chainsaw aliases/d' ~/.bash_aliases
```

To also remove Rust (if installed by this script):

```bash
rustup self uninstall
```

## Security Considerations

- The script installs Rust from the official rustup installer
- Source code is cloned from official GitHub repositories
- All builds are performed locally from source
- No pre-compiled binaries are downloaded

## Contributing

Contributions are welcome! Please ensure:

- Code is self-documenting (no inline comments)
- Functions have single responsibilities
- Error handling is comprehensive
- Script remains idempotent

## Resources

- [Chainsaw GitHub](https://github.com/WithSecureLabs/chainsaw)
- [Sigma Rules GitHub](https://github.com/SigmaHQ/sigma)
- [Chainsaw Documentation](https://github.com/WithSecureLabs/chainsaw/wiki)
- [Sigma Documentation](https://github.com/SigmaHQ/sigma/wiki)

## License

This setup script is provided as-is for convenience. Chainsaw and Sigma have their own respective licenses - please review them in their repositories.

## Acknowledgments

- [WithSecure Labs](https://github.com/WithSecureLabs) for Chainsaw
- [Sigma HQ](https://github.com/SigmaHQ) for Sigma rules
- The forensics and threat hunting community
