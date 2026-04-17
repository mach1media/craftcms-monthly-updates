import ViteRestart from 'vite-plugin-restart';

export default ({ command }) => ({
  base: command === 'serve' ? '' : '/dist/',
  logLevel: 'info',
  css: {
    preprocessorOptions: {
      scss: {
        api: 'modern-compiler',
        silenceDeprecations: ['import', 'global-builtin', 'color-functions', 'if-function', 'slash-div'],
      },
    },
  },
  build: {
    emptyOutDir: false,
    manifest: true,
    outDir: '../web/dist/',
    target: 'esnext',
    rollupOptions: {
      input: {
        app: './js/app.js',
      },
    },
  },
  plugins: [
    ViteRestart({
      reload: ['../templates/**/*'],
    }),
  ],
  server: {
    host: '0.0.0.0',
    port: 3000,
    strictPort: true,
    origin: `${process.env.DDEV_PRIMARY_URL}:3000`,
    cors: {
      origin: /https?:\/\/([A-Za-z0-9\-\.]+)?(\.ddev\.site)(?::\d+)?$/,
    },
  },
});
