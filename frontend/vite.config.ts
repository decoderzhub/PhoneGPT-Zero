import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  
  server: {
    port: 9989,
    host: '0.0.0.0',
    allowedHosts: [
      'localhost',
      '127.0.0.1',
      '192.168.68.76',
      'phonegpt.systemd.diskstation.me',
      'phoneGPT-webhook.systemd.diskstation.me',
      'systemd.diskstation.me'
    ],
    proxy: {
      '/api': {
        target: process.env.REACT_APP_API_URL || 'http://localhost:8112',
        changeOrigin: true,
        rewrite: (path) => path
      }
    }
  },

  build: {
    target: 'ES2020',
    outDir: 'dist',
    assetsDir: 'assets',
    sourcemap: false,
    minify: 'terser',
    rollupOptions: {
      output: {
        manualChunks: {
          react: ['react', 'react-dom'],
          lucide: ['lucide-react'],
          axios: ['axios']
        }
      }
    }
  },

  // Environment variables
  define: {
    'process.env': {}
  },

  // Optimize dependencies
  optimizeDeps: {
    include: ['react', 'react-dom', 'axios', 'lucide-react']
  }
})