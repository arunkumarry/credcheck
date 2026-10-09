import { defineConfig, loadEnv } from 'vite'
import { resolve } from 'path'

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '')
  
  return {
    publicDir: false,
    define: {
      'import.meta.env.VITE_API_BASE_URL': JSON.stringify(env.VITE_API_BASE_URL || 'http://localhost:3000')
    },
    build: {
      outDir: 'dist-extension',
      emptyOutDir: true,
      rollupOptions: {
        input: {
          popup: resolve(__dirname, 'checkcred-extension/popup.js'),
          content: resolve(__dirname, 'checkcred-extension/content.js'),
        },
        output: {
          entryFileNames: `[name].js`,
          chunkFileNames: `[name].js`,
          assetFileNames: `[name].[ext]`
        }
      }
    }
  }
})
