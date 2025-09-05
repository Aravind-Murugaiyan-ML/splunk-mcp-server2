# Makefile for Python Environment Setup for Splunk MCP Server

# Environment Configuration
VENV_DIR = splunk-mcp-env
PYTHON_VERSION = 3.13
PROJECT_DIR = $(shell pwd)

# Python and pip commands
PYTHON = $(VENV_DIR)/bin/python
PIP = $(PYTHON) -m pip

# Determine Python executable
PYTHON_EXEC = python3.13
ifeq (, $(shell which $(PYTHON_EXEC) 2>/dev/null))
  PYTHON_EXEC = python3
endif

# Shell configuration file (default to .bashrc, can be overridden for .zshrc)
SHELL_CONFIG_FILE ?= ~/.bashrc

# Load environment variables from .env file if it exists
ifneq (,$(wildcard ./.env))
  include .env
  export
endif

.PHONY: all install-pyenv setup-venv install-packages verify-install run-test check-venv clean clean-claude-config help

# Default target
all: setup-venv install-packages verify-install ## Setup and verify complete Python environment

install-pyenv: ## Install pyenv, Python 3.13.7, and configure shell
	@echo "Installing pyenv and Python 3.13.7..."
	@if command -v pyenv >/dev/null 2>&1; then \
		echo "✅ pyenv is already installed"; \
	else \
		echo "Installing pyenv..."; \
		curl https://pyenv.run | bash; \
		echo "✅ pyenv installed"; \
	fi
	@echo "Configuring shell for pyenv..."
	@if ! grep -q 'pyenv init' $(SHELL_CONFIG_FILE); then \
		echo 'export PATH="$$HOME/.pyenv/bin:$$PATH"' >> $(SHELL_CONFIG_FILE); \
		echo 'eval "$$(pyenv init --path)"' >> $(SHELL_CONFIG_FILE); \
		echo 'eval "$$(pyenv init -)"' >> $(SHELL_CONFIG_FILE); \
		echo 'eval "$$(pyenv virtualenv-init -)"' >> $(SHELL_CONFIG_FILE); \
		echo "✅ Added pyenv configuration to $(SHELL_CONFIG_FILE)"; \
	else \
		echo "✅ pyenv configuration already exists in $(SHELL_CONFIG_FILE)"; \
	fi
	@echo "Installing Python 3.13.7..."
	@export PATH="$$HOME/.pyenv/bin:$$PATH"; \
	if ! $$HOME/.pyenv/bin/pyenv versions | grep -q "3.13.7"; then \
		$$HOME/.pyenv/bin/pyenv install 3.13.7 || { \
			echo "❌ Failed to install Python 3.13.7. Check /tmp/python-build.*.log for details."; \
			echo "Ensure build dependencies are installed (e.g., sudo apt install build-essential libssl-dev zlib1g-dev)"; \
			exit 1; \
		}; \
		echo "✅ Python 3.13.7 installed"; \
	else \
		echo "✅ Python 3.13.7 already installed"; \
	fi
	@$$HOME/.pyenv/bin/pyenv global 3.13.7 || { \
		echo "❌ Failed to set Python 3.13.7 as global version."; \
		exit 1; \
	}
	@echo "✅ Set Python 3.13.7 as global version"
	@echo "⚠️ Please run 'source $(SHELL_CONFIG_FILE)' to apply shell changes or restart your terminal"

setup-venv: ## Create Python virtual environment
	@echo "Creating Python virtual environment..."
	@if ! command -v $(PYTHON_EXEC) >/dev/null 2>&1; then \
		echo "❌ Python executable ($(PYTHON_EXEC)) not found. Please ensure Python $(PYTHON_VERSION).x is installed."; \
		echo "Run 'make install-pyenv' to install Python 3.13.7 via pyenv."; \
		exit 1; \
	fi
	@if ! $(PYTHON_EXEC) --version | grep -q "^Python $(PYTHON_VERSION)"; then \
		echo "❌ Python version $(PYTHON_VERSION).x required. Found: $$($(PYTHON_EXEC) --version)"; \
		echo "Try installing Python $(PYTHON_VERSION).x (e.g., via 'make install-pyenv') or update PYTHON_EXEC in the Makefile."; \
		exit 1; \
	fi
	@$(PYTHON_EXEC) -m venv $(VENV_DIR)
	@echo "✅ Virtual environment created: $(VENV_DIR)"
	@echo "Current environment: $$($(VENV_DIR)/bin/python --version)"

install-packages: setup-venv ## Install required Python packages (requests, urllib3)
	@echo "Installing Python packages..."
	@$(PIP) install requests urllib3
	@echo "✅ Packages installed successfully"
	@echo "Installed packages:"
	@$(PIP) list | grep -E "(requests|urllib3)"

verify-install: install-packages ## Verify package installations
	@echo "Verifying package installations..."
	@$(PYTHON) -c "import requests; print('✅ requests installed successfully')"
	@$(PYTHON) -c "import urllib3; print('✅ urllib3 installed successfully')"
	@echo "Python version: $$($(PYTHON) --version)"

run-test: verify-install ## Run test_splunk_connection.py in the virtual environment
	@echo "Running test_splunk_connection.py in virtual environment ($(VENV_DIR))..."
	@if [ ! -f ./scripts/test_splunk_connection.py ]; then \
		echo "❌ test_splunk_connection.py not found in $(PROJECT_DIR)/scripts"; \
		exit 1; \
	fi
	@$(PYTHON) ./scripts/test_splunk_connection.py
	@echo "✅ Test script executed"
	@echo "Note: To run scripts manually in the virtual environment, activate it with:"
	@echo "  source $(VENV_DIR)/bin/activate"
	@echo "  python ./scripts/test_splunk_connection.py"
	@echo "  deactivate"

check-venv: ## Display instructions to activate the virtual environment
	@echo "To activate the virtual environment ($(VENV_DIR)) manually:"
	@echo "  source $(VENV_DIR)/bin/activate"
	@echo "  python --version  # Should show Python 3.13.7"
	@echo "  python test_splunk_connection.py"
	@echo "To deactivate, run:"
	@echo "  deactivate"
	@echo "Alternatively, use 'make run-test' to run scripts in the virtual environment without activation."

clean: ## Remove virtual environment
	@echo "Removing virtual environment..."
	@rm -rf $(VENV_DIR)
	@echo "✅ Virtual environment removed"

clean-claude-config: ## Remove Claude configuration file if it exists
	@echo "Checking for Claude configuration file..."
	@if [ -f ~/claude.json ]; then \
		rm -rf ~/claude.json; \
		echo "✅ Claude configuration file removed"; \
	else \
		echo "ℹ️ Claude configuration file (~/claude.json) does not exist or has already been deleted"; \
	fi

remove-splunk-local-config: ## Remove local MCP server configuration from Claude
	@cd $(PROJECT_DIR) && claude mcp remove splunk-local || echo "ℹ️ splunk-local MCP server not found in Claude configuration"	

list-mcp-servers: ## List configured MCP servers
	@cd $(PROJECT_DIR) && claude mcp list

check-mcp-server-port: ## Check if port 8008 is in use
	@echo "Checking if port 8008 is in use..."
	@if sudo lsof -i :8008 >/dev/null 2>&1; then \
		echo "❌ Port 8008 is currently in use by the following process(es):"; \
		sudo lsof -i :8008; \
		echo "Please stop the process using port 8008 or choose a different port in the .env file."; \
		echo "Do you want to kill the process using port 8008? (y/n)"; \
		read answer; \
		if [ "$$answer" = "y" ]; then \
			sudo lsof -t -i :8008 | xargs sudo kill -9; \
			echo "✅ Process using port 8008 has been killed."; \
		fi; \
	else \
		echo "✅ Port 8008 is free to use."; \
	fi
	@echo "You can manually check with the command:"
	@echo "sudo lsof -i :8008"

allow-specified-ip-on-mcp-port-fw: ## Allow traffic from specified IP to port 8008
	@echo "Checking for ufw installation..."
	@if ! command -v ufw >/dev/null 2>&1; then \
		echo "❌ ufw is not installed. Please install it with 'sudo apt install ufw'."; \
		exit 1; \
	fi
	@echo "Checking ALLOWED_IP..."
	@if [ -z "$(ALLOWED_IP)" ]; then \
		echo "❌ ALLOWED_IP is not set. Please set it in .env or pass it as ALLOWED_IP=<ip>."; \
		exit 1; \
	fi
	@if ! echo "$(ALLOWED_IP)" | grep -E '^([0-9]{1,3}\.){3}[0-9]{1,3}$$' >/dev/null 2>&1; then \
		echo "❌ Invalid IP address: $(ALLOWED_IP). Please set a valid ALLOWED_IP in .env or pass it as ALLOWED_IP=<ip>."; \
		exit 1; \
	fi
	@echo "Checking if ufw rule exists for $(ALLOWED_IP) to port 8008..."
	@if sudo ufw status | grep -E "$(ALLOWED_IP).*8008" >/dev/null 2>&1; then \
		echo "✅ ufw rule already exists for $(ALLOWED_IP) to port 8008"; \
	else \
		echo "Adding ufw rule to allow traffic from $(ALLOWED_IP) to port 8008..."; \
		if sudo ufw allow from $(ALLOWED_IP) to any port 8008; then \
			echo "✅ Successfully added ufw rule for $(ALLOWED_IP) to port 8008"; \
		else \
			echo "❌ Failed to add ufw rule. Check ufw status and permissions."; \
			exit 1; \
		fi; \
	fi

list-firewall-rules: ## List all ufw rules with indices
	@echo "Checking for ufw installation..."
	@if ! command -v ufw >/dev/null 2>&1; then \
		echo "❌ ufw is not installed. Please install it with 'sudo apt install ufw'."; \
		exit 1; \
	fi
	@echo "Listing ufw rules..."
	@if sudo ufw status numbered; then \
		echo "✅ Successfully listed ufw rules"; \
	else \
		echo "❌ Failed to list ufw rules. Check ufw status and permissions."; \
		exit 1; \
	fi

delete-firewall-rule: ## Delete a ufw rule by index 
	@echo "Checking for ufw installation..."
	@if ! command -v ufw >/dev/null 2>&1; then \
		echo "❌ ufw is not installed. Please install it with 'sudo apt install ufw'."; \
		exit 1; \
	fi
	@echo "Please enter the ufw rule number to delete (run 'make list-firewall-rules' to see indices):"
	@read RULE_NUMBER; \
	if [ -z "$$RULE_NUMBER" ]; then \
		echo "❌ No rule number provided. Please enter a valid rule number."; \
		exit 1; \
	fi; \
	if ! echo "$$RULE_NUMBER" | grep -E '^[0-9]+$$' >/dev/null 2>&1; then \
		echo "❌ Invalid rule number: $$RULE_NUMBER. Please enter a positive integer."; \
		exit 1; \
	fi; \
	if [ $$RULE_NUMBER -eq 0 ]; then \
		echo "❌ Rule number must be greater than 0. Run 'make list-firewall-rules' to see valid rule numbers."; \
		exit 1; \
	fi; \
	if sudo ufw --force delete $$RULE_NUMBER; then \
		echo "✅ Successfully deleted ufw rule number $$RULE_NUMBER"; \
	else \
		echo "❌ Failed to delete ufw rule. Run 'make list-firewall-rules' to verify the rule number."; \
		exit 1; \
	fi

help: ## Display help information
	@echo "Python Environment Setup for Splunk MCP Server"
	@echo "======================================="
	@echo ""
	@echo "Environment Variables:"
	@echo "  VENV_DIR=$(VENV_DIR)"
	@echo "  PYTHON_VERSION=$(PYTHON_VERSION)"
	@echo "  PROJECT_DIR=$(PROJECT_DIR)"
	@echo "  PYTHON_EXEC=$(PYTHON_EXEC)"
	@echo "  SHELL_CONFIG_FILE=$(SHELL_CONFIG_FILE)"
	@echo "  ALLOWED_IP - IP address for allow-specified-ip-on-mcp-port-fw (required)"
	@echo ""
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?##.*$$' $(MAKEFILE_LIST) | sed 's/.*:\([a-zA-Z_-]\+\)\([[:space:]]*:.*\|\)##\(.*\)/\1##\3/' | \
		awk 'BEGIN {FS = "##"}; {printf "  \033[32m%-30s\033[0m %s\n", $$1, $$2}'