# Compiler and flags
FPC = fpc
FLAGS = -O2
DEBUGFLAGS = -gl -Cr -Co -Ci -Sa

# Target and source files
TARGET = objex
SRC_DIR = src
TARGET_SRC = $(SRC_DIR)/objex.pas
UNIT_SRC = $(wildcard $(SRC_DIR)/*.pas)
UNITS = $(filter-out $(TARGET_SRC), $(UNIT_SRC))

# Output directories
BUILD_DIR = build
BIN_DIR = bin

# Ensure directories exist
setup:
	mkdir -p $(BUILD_DIR) $(BIN_DIR)

# Compile units to .ppu and .o files (FPC auto-detects unit vs program)
$(BUILD_DIR)/%.ppu $(BUILD_DIR)/%.o: $(SRC_DIR)/%.pas | setup
	$(FPC) $(FLAGS) -FE$(BIN_DIR) -FU$(BUILD_DIR) $<

# Compile the main program into an executable
$(BIN_DIR)/$(TARGET): $(TARGET_SRC) $(UNIT_SRC) | setup
	$(FPC) $(FLAGS) -FE$(BIN_DIR) -FU$(BUILD_DIR) -o$(BIN_DIR)/$(TARGET) $(TARGET_SRC)

# Default build target
all: $(BIN_DIR)/$(TARGET)

# Clean up object files, units, and binary
clean:
	rm -rf $(BUILD_DIR) $(BIN_DIR)

# Optional: Install the binary to /usr/local/bin
install: all
	cp $(BIN_DIR)/$(TARGET) /usr/local/bin/

# Run the program
run: all
	./$(BIN_DIR)/$(TARGET)

# Declare phony targets
.PHONY: all setup clean install run
