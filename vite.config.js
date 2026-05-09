import { defineConfig } from 'vite';
import { svelte } from '@sveltejs/vite-plugin-svelte';
import path from 'path';
export default defineConfig({
    plugins: [svelte()],
    clearScreen: false,
    resolve: {
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
