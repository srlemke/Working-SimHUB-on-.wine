#!/usr/bin/env bash
set -euo pipefail

# Select and existin Proton prefix 
PFX0="$HOME/.steam/steam/steamapps/compatdata/0/pfx" # This is Proton GE
PFX1493710="$HOME/.steam/steam/steamapps/compatdata/1493710/pfx" # This is Proton Experimental

if [[ -d "$PFX0" ]]; then
    SOURCE="$PFX0"
elif [[ -d "$PFX1493710" ]]; then
    SOURCE="$PFX1493710"
else
    echo "ERROR: No valid Proton prefix found. "
    echo "Checked:"
    echo "  Proton GE"
    echo "  Proton Experimental"
    echo "  Installing a game will Install a Proton Prefix"

    exit 1
fi

TARGET="$HOME/.wine"

BACKUP_DIR="$HOME/.wine-backups"
TIMESTAMP="$(date '+%Y%m%d-%H%M%S')"
DEST="$BACKUP_DIR/wine-backup-$TIMESTAMP"

SIMHUB_URL="https://github.com/SHWotever/SimHub/releases/download/9.11.5/SimHub.9.11.5.zip"
SIMHUB_DIR="$HOME/SimHub"
SIMHUB_ZIP="$SIMHUB_DIR/SimHub.9.11.5.zip"

echo "==========================================================================="
echo " You are about to REPLACE your current ~/.wine directory with the Proton"
echo " prefix located at:"
echo
echo "     $SOURCE"
echo
echo " This Proton prefix generally provides BETTER compatibility with SimHub"
echo " because Proton includes a more complete and stable .NET Framework 4.8"
echo " implementation than vanilla Wine. This reduces crashes and improves"
echo " plugin stability."
echo
echo " NOTE: Installing dotnet48 may take around 5 minutes. This is normal."
echo "       The installer may appear to 'hang' — do not interrupt it."
echo
echo " Before replacing ~/.wine, your existing directory will be backed up to:"
echo
echo "     $DEST"
echo "==========================================================================="
echo
read -r -p "Press ENTER to proceed, or type anything and press ENTER to cancel: " CONFIRM

if [[ -n "$CONFIRM" ]]; then
    echo "Cancelled. No changes made."
    exit 0
fi

# Check source
if [[ ! -d "$SOURCE" ]]; then
    echo "ERROR: Source directory does not exist:"
    echo "       $SOURCE"
    exit 1
fi

# Backup existing ~/.wine if present
if [[ -d "$TARGET" ]]; then
    mkdir -p "$BACKUP_DIR"
    echo "Backing up existing ~/.wine to $DEST ..."
    cp -a -- "$TARGET" "$DEST"
    echo "Backup complete."
else
    echo "No existing ~/.wine directory found — skipping backup."
fi

# Replace ~/.wine
echo "Replacing ~/.wine with a full copy of the Proton prefix..."
rm -rf -- "$TARGET"
cp -a -- "$SOURCE" "$TARGET"

echo "New ~/.wine created."

# Set the prefix for this session
export WINEPREFIX="$TARGET"

echo "Using WINEPREFIX: $WINEPREFIX"

# ---------------------------------------------------------------------------
# Clean registry BEFORE installing dotnet48 (non-fatal)
# ---------------------------------------------------------------------------
echo "Clearing Steam .NET registry stubs BEFORE dotnet48 installation..."
wineserver -k || true

wine reg delete "HKLM\\Software\\Microsoft\\NET Framework Setup\\NDP\\v4" /f >/dev/null 2>&1 || true
wine reg delete "HKLM\\Software\\Wow6432Node\\Microsoft\\NET Framework Setup\\NDP\\v4" /f >/dev/null 2>&1 || true

echo "Registry cleanup complete (non-fatal)."

# ---------------------------------------------------------------------------
# Install dotnet48 (silent) with result checking
# ---------------------------------------------------------------------------
echo "Running winetricks -q -f dotnet48 ..."
echo "(This may take around 5 minutes — please be patient.)"

winetricks -q -f dotnet48 > /dev/null 2>&1
install_result=$?

if [[ $install_result -ne 0 ]]; then
    echo "ERROR: dotnet48 installation failed with exit code $install_result"
    echo "Your prefix is still intact, but dotnet48 is NOT installed."
    exit 1
fi

echo "dotnet48 installation completed successfully."

# ---------------------------------------------------------------------------
# Download SimHub
# ---------------------------------------------------------------------------
echo "Preparing to download SimHub 9.11.5 ..."

mkdir -p "$SIMHUB_DIR"

if command -v wget >/dev/null 2>&1; then
    echo "Using wget to download SimHub..."
    wget -q -O "$SIMHUB_ZIP" "$SIMHUB_URL"
elif command -v curl >/dev/null 2>&1; then
    echo "Using curl to download SimHub..."
    curl -s -L -o "$SIMHUB_ZIP" "$SIMHUB_URL"
else
    echo "ERROR: Neither wget nor curl is installed. Cannot download SimHub."
    exit 1
fi

echo "SimHub downloaded to:"
echo "  $SIMHUB_ZIP"

# ---------------------------------------------------------------------------
# Extract SimHub ZIP
# ---------------------------------------------------------------------------
echo "Extracting SimHub..."

SIMHUB_EXTRACT_DIR="$SIMHUB_DIR/SimHub"
mkdir -p "$SIMHUB_EXTRACT_DIR"

if command -v unzip >/dev/null 2>&1; then
    unzip -o "$SIMHUB_ZIP" -d "$SIMHUB_EXTRACT_DIR" > /dev/null 2>&1
    extract_result=$?
elif command -v bsdtar >/dev/null 2>&1; then
    bsdtar -xf "$SIMHUB_ZIP" -C "$SIMHUB_EXTRACT_DIR" > /dev/null 2>&1
    extract_result=$?
else
    echo "ERROR: Neither unzip nor bsdtar is installed. Cannot extract SimHub."
    exit 1
fi

if [[ $extract_result -ne 0 ]]; then
    echo "ERROR: Failed to extract SimHub ZIP (exit code $extract_result)"
    exit 1
fi

echo "SimHub extracted to:"
echo "  $SIMHUB_EXTRACT_DIR"

# ---------------------------------------------------------------------------
# Run SimHub installer
# ---------------------------------------------------------------------------

SIMHUB_SETUP_EXE="$SIMHUB_EXTRACT_DIR/SimHubSetup_9.11.5.exe"

if [[ ! -f "$SIMHUB_SETUP_EXE" ]]; then
    echo "ERROR: SimHubSetup_9.11.5.exe not found in extracted directory:"
    echo "       $SIMHUB_SETUP_EXE"
    exit 1
fi

echo ""
echo "=========================================="
echo "IMPORTANT TIPS BEFORE INSTALLATION"
echo "=========================================="
echo ""
echo "1. The SimHub installer will now launch in Wine/Proton"
echo ""
echo "2. Enable ONLY the following two options:"
echo "   - Open Windows Firewall port (for web browser & handy access)"
echo "   - Default dashes (optional)"
echo ""
echo "   You may enable other device options if you actually use them."
echo "   Just make sure NOT to install .NET via the SimHub installer."
echo ""
echo "=========================================="
echo ""
printf "Press Enter to start the SimHub installer..."
read -r dummy
echo ""

echo "Installing SimHub..."

wine "$SIMHUB_SETUP_EXE"
installer_result=$?

if [[ $installer_result -eq 0 ]]; then
    echo "SimHub installation completed successfully!"
else
    echo "SimHub installation may have failed or is still running."
fi
