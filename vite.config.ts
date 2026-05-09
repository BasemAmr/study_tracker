import { defineConfig } from 'vite';
import { svelte } from '@sveltejs/vite-plugin-svelte';
import path from 'path';

export default defineConfig({
  plugins: [
    svelte(),
    {
      name: 'favicon-ico-redirect',
      configureServer(server) {
        server.middlewares.use((req, res, next) => {
          if (req.url === '/favicon.ico' || req.url?.startsWith('/favicon.ico?')) {
            res.writeHead(302, { Location: '/favicon.svg' });
            res.end();
            return;
          }
          next();
        });
      },
      configurePreviewServer(server) {
        server.middlewares.use((req, res, next) => {
          if (req.url === '/favicon.ico' || req.url?.startsWith('/favicon.ico?')) {
            res.writeHead(302, { Location: '/favicon.svg' });
            res.end();
            return;
          }
          next();
        });
      }
    }
  ],
  clearScreen: false,
  resolve: {
    // Prefer `.ts` over stale sibling `.js` files in `src/` (legacy compiled copies).
    extensions: ['.ts', '.tsx', '.mts', '.cts', '.js', '.mjs', '.cjs', '.jsx', '.json'],
    alias: {
      '@': path.resolve(__dirname, 'src')
    }
  },
  server: {
    port: 1420,
    strictPort: true
  },
  build: {
    // Suppress the "chunk is larger than 1000 kB" warning (bundled SQLite driver)
    chunkSizeWarningLimit: 1500,
    rollupOptions: {
      output: {
        manualChunks: {
          // Svelte runtime
          svelte: ['svelte'],
          // Chart libraries (if used)
          charts: ['chart.js'],
        }
      }
    }
  }
});

