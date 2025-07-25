SCRIPTS := $(wildcard *.sh)
TARGET_DIR := $(HOME)/bin

.PHONY: install clean

install:
	@echo "Installing scripts to $(TARGET_DIR)..."
	@mkdir -p $(TARGET_DIR)
	@for script in $(SCRIPTS); do \
		install -m 755 $$script $(TARGET_DIR)/$$(basename $$script); \
	done
	@echo "Done."

clean:
	@echo "Removing installed scripts from $(TARGET_DIR)..."
	@for script in $(SCRIPTS); do \
		rm -f $(TARGET_DIR)/$$(basename $$script); \
	done
	@echo "Cleaned."

