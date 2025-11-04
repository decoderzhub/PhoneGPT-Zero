#!/bin/bash

echo "🚀 Starting PhoneGPT MentraOS TypeScript Backend"
echo ""

# Check if .env exists
if [ ! -f .env ]; then
    echo "⚠️  .env file not found! Creating from .env.example..."
    cp .env.example .env
    echo ""
    echo "📝 Please edit .env file with your MentraOS credentials:"
    echo "   - PACKAGE_NAME (from console.mentra.glass)"
    echo "   - MENTRAOS_API_KEY (from console.mentra.glass)"
    echo ""
    echo "Then run this script again."
    exit 1
fi

# Check if node_modules exists
if [ ! -d node_modules ]; then
    echo "📦 Installing dependencies..."
    npm install
    echo ""
fi

# Start the development server
echo "🎬 Starting development server..."
npm run dev
