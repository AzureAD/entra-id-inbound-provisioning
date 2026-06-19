#!/usr/bin/env bash
set -e

echo ""
echo "  ============================================"
echo "   Entra ID Provisioning Client - Local Setup"
echo "  ============================================"
echo ""

# Check Node.js
if ! command -v node &> /dev/null; then
    echo "  [ERROR] Node.js is not installed."
    echo "  Please install Node.js 18+ from https://nodejs.org"
    exit 1
fi

NODE_MAJOR=$(node -v | cut -d. -f1 | tr -d 'v')
if [ "$NODE_MAJOR" -lt 18 ]; then
    echo "  [ERROR] Node.js 18+ is required. Current: $(node -v)"
    echo "  Please update from https://nodejs.org"
    exit 1
fi

echo "  [OK] Node.js found: $(node -v)"
echo ""

# Install dependencies
echo "  [1/3] Installing server dependencies..."
npm install

echo ""
echo "  [2/3] Installing client dependencies..."
cd client
npm install

echo ""
echo "  [3/3] Building client..."
npx react-scripts build

cd ..

echo ""
echo "  ============================================"
echo "   Setup complete!"
echo "  ============================================"
echo ""
echo "   To start the app, run:"
echo "     npm start"
echo ""
echo "   Then open http://localhost:3001 in your browser."
echo ""
echo "   All credentials stay on your local machine."
echo "   No data is sent to any cloud service until"
echo "   you explicitly click 'Send' in the final step."
echo ""
