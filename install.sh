#!/bin/sh
set -e

echo "[gfd] Compiling release build with Odin..."
odin build . -out:gfd -opt:3

INSTALL_DIR="$HOME/.local/bin"
mkdir -p "$INSTALL_DIR"

mv gfd "$INSTALL_DIR/gfd"
echo "[gfd] Installed binary to $INSTALL_DIR/gfd"

# Verify if INSTALL_DIR is in the current PATH
case ":$PATH:" in
    *":$INSTALL_DIR:"*) ;;
    *)
        echo ""
        echo "⚠️  WARNING: $INSTALL_DIR is not in your PATH."
        echo "Add it to your shell profile (~/.zshrc or ~/.bashrc):"
        echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
        ;;
esac

echo "[gfd] Installation complete! You can now run 'gfd' anywhere."
