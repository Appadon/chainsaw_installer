#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

print_header() {
	echo "================================================"
	echo "Chainsaw Setup Script"
	echo "================================================"
	echo ""
}

confirm_reinstall() {
	local directory=$1
	
	if [ -d "$directory" ]; then
		warning "Directory already exists: $directory"
		echo ""
		read -p "Remove and reinstall? (y/n) " -n 1 -r
		echo ""
		
		if [[ ! $REPLY =~ ^[Yy]$ ]]; then
			info "Installation cancelled"
			exit 0
		fi
		
		info "Removing existing directory..."
		rm -rf "$directory"
		success "Directory removed"
	fi
}

install_rust() {
	if ! command -v cargo &> /dev/null; then
		warning "Rust/Cargo not found. Installing..."
		
		if curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y; then
			success "Rust installed successfully"
			source "$HOME/.cargo/env"
			
			if command -v cargo &> /dev/null; then
				success "Cargo is now available: $(cargo --version)"
			else
				error "Rust installation completed but cargo is not in PATH"
				error "Please run: source \$HOME/.cargo/env"
				error "Then re-run this script"
				exit 1
			fi
		else
			error "Failed to install Rust"
			error "Please install manually from: https://rustup.rs/"
			exit 1
		fi
	else
		success "Rust already installed: $(cargo --version)"
	fi
}

clone_repository() {
	local repo_url=$1
	local target_dir=$2
	local repo_name=$3
	
	info "Cloning $repo_name repository..."
	
	if git clone "$repo_url" "$target_dir"; then
		success "$repo_name cloned successfully"
	else
		error "Failed to clone $repo_name repository"
		exit 1
	fi
}

build_chainsaw() {
	local chainsaw_dir=$1
	
	info "Building Chainsaw from source (this may take a few minutes)..."
	cd "$chainsaw_dir"
	
	if ! cargo build --release; then
		error "Failed to build Chainsaw"
		error "Check the output above for compilation errors"
		exit 1
	fi
	
	success "Chainsaw built successfully!"
	
	if [ ! -f "target/release/chainsaw" ]; then
		error "Build succeeded but binary not found at target/release/chainsaw"
		exit 1
	fi
	
	mkdir -p "$chainsaw_dir/bin"
	cp target/release/chainsaw "$chainsaw_dir/bin/"
	chmod +x "$chainsaw_dir/bin/chainsaw"
	success "Binary copied to $chainsaw_dir/bin/chainsaw"
	
	if "$chainsaw_dir/bin/chainsaw" --version &> /dev/null; then
		success "Chainsaw binary is working: $("$chainsaw_dir/bin/chainsaw" --version)"
	else
		warning "Binary exists but version check failed"
	fi
}

verify_sigma_rules() {
	local sigma_dir=$1
	
	if [ -d "$sigma_dir/rules" ]; then
		success "Sigma rules directory verified"
	else
		warning "Sigma rules directory not found at $sigma_dir/rules"
	fi
}

backup_bash_aliases() {
	local bash_aliases=$1
	
	if [ -f "$bash_aliases" ]; then
		local backup_file="$bash_aliases.backup.$(date +%Y%m%d_%H%M%S)"
		cp "$bash_aliases" "$backup_file"
		success "Backed up existing .bash_aliases to $backup_file"
	fi
}

remove_old_aliases() {
	local bash_aliases=$1
	sed -i '/# Chainsaw aliases - Auto-generated/,/# End Chainsaw aliases/d' "$bash_aliases"
}

create_bash_aliases() {
	local bash_aliases=$1
	
	cat >> "$bash_aliases" << 'EOF'

# Chainsaw aliases - Auto-generated
export CHAINSAW_HOME="$HOME/enviros/chainsaw"
export SIGMA_RULES="$CHAINSAW_HOME/sigma/rules"
export PATH="$CHAINSAW_HOME/bin:$PATH"

chainsaw() {
	local CHAINSAW_BIN="$CHAINSAW_HOME/bin/chainsaw"
	
	if [ ! -f "$CHAINSAW_BIN" ]; then
		echo "Error: Chainsaw binary not found at $CHAINSAW_BIN"
		echo "Please run the setup script again or build manually with:"
		echo "  cd $CHAINSAW_HOME && cargo build --release"
		return 1
	fi
	
	"$CHAINSAW_BIN" "$@"
}

chainsaw-hunt() {
	if [ $# -lt 2 ]; then
		echo "Usage: chainsaw-hunt <evtx-path> <sigma-rule-path> [additional-options]"
		echo ""
		echo "Examples:"
		echo "  chainsaw-hunt ./logs/*.evtx sigma/windows/process_creation"
		echo "  chainsaw-hunt ./logs/ sigma/windows/ --mapping mappings/sigma-event-logs.yml"
		echo "  chainsaw-hunt ./logs/*.evtx \$SIGMA_RULES/windows/process_creation/"
		return 1
	fi
	
	local evtx_path="$1"
	local sigma_path="$2"
	shift 2
	
	if [[ "$sigma_path" == sigma/* ]]; then
		sigma_path="$SIGMA_RULES/${sigma_path#sigma/}"
	fi
	
	if [ ! -e "$sigma_path" ]; then
		echo "Error: Sigma path not found: $sigma_path"
		echo "Available categories:"
		ls -1 "$SIGMA_RULES" 2>/dev/null | head -10
		return 1
	fi
	
	chainsaw hunt "$evtx_path" -s "$sigma_path" "$@"
}

chainsaw-search() {
	chainsaw search "$@"
}

chainsaw-analyse() {
	chainsaw analyse "$@"
}

chainsaw-dump() {
	chainsaw dump "$@"
}

goto-sigma() {
	if [ -d "$SIGMA_RULES" ]; then
		cd "$SIGMA_RULES"
	else
		echo "Error: Sigma rules directory not found at $SIGMA_RULES"
		return 1
	fi
}

list-sigma() {
	if [ -d "$SIGMA_RULES" ]; then
		echo "Available Sigma rule categories in $SIGMA_RULES:"
		ls -1 "$SIGMA_RULES" | grep -v "^\\." | column
	else
		echo "Error: Sigma rules directory not found at $SIGMA_RULES"
		return 1
	fi
}

find-sigma() {
	if [ $# -eq 0 ]; then
		echo "Usage: find-sigma <search-term>"
		echo ""
		echo "Examples:"
		echo "  find-sigma mimikatz"
		echo "  find-sigma powershell"
		echo "  find-sigma suspicious"
		return 1
	fi
	
	if [ -d "$SIGMA_RULES" ]; then
		echo "Searching for Sigma rules matching: '$1'"
		echo ""
		find "$SIGMA_RULES" -type f -name "*.yml" -exec grep -l -i "$1" {} \; 2>/dev/null | \
			sed "s|$SIGMA_RULES/||g" | \
			while read -r rule; do
				echo "  - $rule"
			done
	else
		echo "Error: Sigma rules directory not found at $SIGMA_RULES"
		return 1
	fi
}

count-sigma() {
	if [ -d "$SIGMA_RULES" ]; then
		local count=$(find "$SIGMA_RULES" -type f -name "*.yml" | wc -l)
		echo "Total Sigma rules: $count"
	else
		echo "Error: Sigma rules directory not found at $SIGMA_RULES"
		return 1
	fi
}

update-chainsaw() {
	echo "Updating Chainsaw..."
	cd "$CHAINSAW_HOME"
	
	if git pull; then
		echo "Rebuilding Chainsaw..."
		if cargo build --release; then
			cp target/release/chainsaw "$CHAINSAW_HOME/bin/"
			echo "Chainsaw updated successfully!"
		else
			echo "Error: Build failed"
			return 1
		fi
	else
		echo "Error: Git pull failed"
		return 1
	fi
	
	echo ""
	echo "Updating Sigma rules..."
	cd "$CHAINSAW_HOME/sigma"
	
	if git pull; then
		echo "Sigma rules updated successfully!"
	else
		echo "Error: Git pull failed"
		return 1
	fi
}
# End Chainsaw aliases
EOF

	success "Bash aliases configured"
}

ensure_bashrc_sources_aliases() {
	local bashrc="$HOME/.bashrc"
	local bash_aliases="$HOME/.bash_aliases"
	
	if [ -f "$bashrc" ] && grep -q "\.bash_aliases" "$bashrc"; then
		success ".bashrc already sources .bash_aliases"
	else
		warning ".bashrc may not source .bash_aliases automatically"
		info "Adding source command to .bashrc..."
		echo "" >> "$bashrc"
		echo "if [ -f ~/.bash_aliases ]; then" >> "$bashrc"
		echo "    . ~/.bash_aliases" >> "$bashrc"
		echo "fi" >> "$bashrc"
		success "Added .bash_aliases sourcing to .bashrc"
	fi
}

print_summary() {
	local chainsaw_dir=$1
	local sigma_dir=$2
	
	echo ""
	echo "================================================"
	echo "Setup Complete!"
	echo "================================================"
	echo ""
	success "Installation Summary:"
	echo "  ✓ Rust/Cargo: $(cargo --version)"
	echo "  ✓ Chainsaw Directory: $chainsaw_dir"
	echo "  ✓ Chainsaw Binary: $chainsaw_dir/bin/chainsaw"
	echo "  ✓ Chainsaw Version: $("$chainsaw_dir/bin/chainsaw" --version 2>/dev/null || echo 'Unknown')"
	echo "  ✓ Sigma Rules: $sigma_dir"
	
	if [ -d "$sigma_dir/rules" ]; then
		echo "  ✓ Sigma Rule Count: $(find "$sigma_dir/rules" -name "*.yml" 2>/dev/null | wc -l) rules"
	fi
	
	echo ""
	success "Available Commands:"
	echo "  • chainsaw              - Main chainsaw command"
	echo "  • chainsaw-hunt         - Hunt with sigma rules (auto-expands 'sigma/' paths)"
	echo "  • chainsaw-search       - Search events"
	echo "  • chainsaw-analyse      - Analyse events"
	echo "  • chainsaw-dump         - Dump events"
	echo "  • goto-sigma            - Navigate to sigma rules directory"
	echo "  • list-sigma            - List sigma rule categories"
	echo "  • find-sigma            - Search for specific sigma rules"
	echo "  • count-sigma           - Count total sigma rules"
	echo "  • update-chainsaw       - Update chainsaw and sigma rules"
	echo ""
	success "Environment Variables:"
	echo "  • CHAINSAW_HOME         - $chainsaw_dir"
	echo "  • SIGMA_RULES           - $sigma_dir/rules"
	echo "  • PATH                  - Updated to include chainsaw binary"
	echo ""
	success "Usage Examples:"
	echo "  chainsaw --help"
	echo "  chainsaw hunt /path/to/logs/*.evtx -s sigma/windows/process_creation/"
	echo "  chainsaw-hunt ./logs/*.evtx sigma/windows/process_creation/"
	echo "  find-sigma mimikatz"
	echo "  list-sigma"
	echo ""
	warning "To activate aliases in current session, run:"
	echo "  source ~/.bash_aliases"
	echo ""
	warning "Or simply restart your terminal"
	echo ""
	success "Setup completed successfully!"
}

main() {
	print_header
	
	ENVIROS_DIR="$HOME/enviros"
	CHAINSAW_DIR="$ENVIROS_DIR/chainsaw"
	SIGMA_DIR="$CHAINSAW_DIR/sigma"
	BASH_ALIASES="$HOME/.bash_aliases"
	
	info "Step 1/6: Preparing directories..."
	mkdir -p "$ENVIROS_DIR"
	confirm_reinstall "$CHAINSAW_DIR"
	success "Directory structure ready"
	
	info "Step 2/6: Checking Rust installation..."
	install_rust
	
	info "Step 3/6: Cloning Chainsaw repository..."
	clone_repository "https://github.com/WithSecureLabs/chainsaw.git" "$CHAINSAW_DIR" "Chainsaw"
	
	info "Step 4/6: Building Chainsaw..."
	build_chainsaw "$CHAINSAW_DIR"
	
	info "Step 5/6: Cloning Sigma ruleset..."
	clone_repository "https://github.com/SigmaHQ/sigma.git" "$SIGMA_DIR" "Sigma"
	verify_sigma_rules "$SIGMA_DIR"
	
	info "Step 6/6: Setting up bash aliases..."
	backup_bash_aliases "$BASH_ALIASES"
	touch "$BASH_ALIASES"
	remove_old_aliases "$BASH_ALIASES"
	create_bash_aliases "$BASH_ALIASES"
	ensure_bashrc_sources_aliases
	
	print_summary "$CHAINSAW_DIR" "$SIGMA_DIR"
}

main
