.PHONY: setup-git setup-ssh setup-config setup-remote test-connection all clean help

# Default target
all: setup-git

# Complete git setup
setup-git: setup-ssh setup-config setup-remote test-connection
	@echo "Git setup completed successfully!"


setup-ssh-wsl: ## Start SSH agent and add key for WSL
	@echo "Setting up SSH agent and adding key..."
	@eval "$$(ssh-agent -s)" && ssh-add ~/.ssh/id_gitHub_wsl_ubuntu_22_04_aravind_maple_lab
	@echo "SSH key added successfully"

setup-ssh-agent-vSphere: ## Start SSH agent and add key for vSphere
	@echo "Setting up SSH agent and adding key..."
	@eval "$$(ssh-agent -s)" && ssh-add ~/.ssh/id_gitHub_vcenter_vm_ubnuntu_20_04_aravind_maple_lab
	@echo "SSH key added successfully"


setup-config: ## Configure git user settings (both local and global)
	@echo "Configuring git user settings..."
	@git config user.name "Aravind-Murugaiyan-ML"
	@git config user.email "aravind.murugaiyan@xoriant.com"
	@git config --global user.name "Aravind-Murugaiyan-ML"
	@git config --global user.email "aravind.murugaiyan@xoriant.com"
	@echo "Git configuration updated"


setup-remote: ## Set remote URL
	@echo "Setting remote URL..."
	@git remote set-url origin git@github-Aravind-Murugaiyan-ML:Aravind-Murugaiyan-ML/splunk-mcp-server2.git
	@echo "Remote URL updated"


test-connection: ## Test SSH connection
	@echo "Testing SSH connection..."
	@ssh -T git@github-Aravind-Murugaiyan-ML || true
	@echo "Connection test completed"

show-config: ## Show current git configuration
	@echo "Current Git Configuration:"
	@echo "=========================="
	@echo "Local config:"
	@git config user.name || echo "No local user.name set"
	@git config user.email || echo "No local user.email set"
	@echo ""
	@echo "Global config:"
	@git config --global user.name || echo "No global user.name set"
	@git config --global user.email || echo "No global user.email set"
	@echo ""
	@echo "Remote URL:"
	@git remote -v


clean: ## Clean up (reset to default settings)
	@echo "Resetting git configuration..."
	@git config --unset user.name || true
	@git config --unset user.email || true
	@echo "Local git config cleared"


# Display help information
help: ## Display help information
	@echo "Splunk Universal Forwarder Configuration and Verification Commands"
	@echo "=========================="
	@echo ""
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*##.*$$' $(lastword $(MAKEFILE_LIST)) | sort | cut -d: -f1 | while read target; do \
                desc=$$(grep "^$$target:.*##" $(lastword $(MAKEFILE_LIST)) | sed 's/.*##[[:space:]]*//'); \
                printf "  \033[32m%-25s\033[0m %s\n" "$$target" "$$desc"; \
					done
	@echo ""