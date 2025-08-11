# Define the root folders for our files.
SYSTEM_SCRIPT_DIR := system
USER_SCRIPT_DIR := user
SYSTEMD_UNIT_DIR := systemd

# Define the scripts that need systemd units.
SYSTEMD_MANAGED_SCRIPTS := apt-refresh-with-notification.sh needrestart-check.sh clone-pi.sh
USER_SCRIPTS := $(patsubst %,$(USER_SCRIPT_DIR)/%, automated-rpi-clone.sh discord_startup.sh)
SYSTEM_SCRIPTS := $(patsubst %,$(SYSTEM_SCRIPT_DIR)/%, $(filter-out $(SYSTEMD_MANAGED_SCRIPTS), $(notdir $(wildcard $(SYSTEM_SCRIPT_DIR)/*.sh))))

# Use a separate variable for services that don't have an associated timer.
ADDITIONAL_SERVICES := $(patsubst %,$(SYSTEMD_UNIT_DIR)/%, discord-startup.service)

# Automatically generate the full path to the systemd units.
SYSTEMD_SERVICES := $(patsubst %.sh,$(SYSTEMD_UNIT_DIR)/%.service, $(SYSTEMD_MANAGED_SCRIPTS))
SYSTEMD_TIMERS := $(patsubst %.sh,$(SYSTEMD_UNIT_DIR)/%.timer, $(SYSTEMD_MANAGED_SCRIPTS))

# Define the installation directories.
BIN_DIR := /usr/local/bin
USER_BIN_DIR := $(HOME)/bin
SYSTEMD_TARGET_DIR := /etc/systemd/system

# Combine all services and timers into a single variable for easier management.
ALL_SERVICES := $(SYSTEMD_SERVICES) $(ADDITIONAL_SERVICES)
ALL_TIMERS := $(SYSTEMD_TIMERS)

.PHONY: all install uninstall clean

# The main 'install' target handles all installations.
install: install-system-scripts install-user-scripts install-systemd

install-system-scripts:
	echo "Installing system scripts to $(BIN_DIR)..."
	sudo install -m 755 $(SYSTEM_SCRIPTS) $(BIN_DIR)
	echo "System scripts installation finished."

install-user-scripts:
	echo "Installing user scripts to $(USER_BIN_DIR)..."
	mkdir -p $(USER_BIN_DIR)
	install -m 755 $(USER_SCRIPTS) $(USER_BIN_DIR)
	echo "User scripts installation finished."

install-systemd:
	echo "Installing systemd units to $(SYSTEMD_TARGET_DIR)..."
	sudo install -m 644 $(ALL_SERVICES) $(ALL_TIMERS) $(SYSTEMD_TARGET_DIR)
	echo "Systemd units installed."
	echo "Reloading systemd daemon..."
	sudo systemctl daemon-reload
	echo "Enabling and starting timers and services..."
	$(foreach unit, $(notdir $(ALL_SERVICES) $(ALL_TIMERS)), sudo systemctl enable --now $(unit);)
	echo "Systemd installation finished."

uninstall: uninstall-systemd uninstall-user-scripts uninstall-system-scripts

uninstall-systemd:
	echo "Stopping and disabling timers and services..."
	$(foreach unit, $(notdir $(ALL_SERVICES) $(ALL_TIMERS)), sudo systemctl stop $(unit); sudo systemctl disable $(unit);)
	echo "Removing systemd units..."
	sudo rm -f $(addprefix $(SYSTEMD_TARGET_DIR)/,$(notdir $(ALL_SERVICES) $(ALL_TIMERS)))
	echo "Systemd uninstallation finished."

uninstall-user-scripts:
	echo "Removing user scripts from $(USER_BIN_DIR)..."
	rm -f $(addprefix $(USER_BIN_DIR)/,$(notdir $(USER_SCRIPTS)))
	echo "User scripts uninstallation finished."

uninstall-system-scripts:
	echo "Removing system scripts from $(BIN_DIR)..."
	sudo rm -f $(addprefix $(BIN_DIR)/,$(notdir $(SYSTEM_SCRIPTS)))
	echo "System scripts uninstallation finished."

clean: uninstall
