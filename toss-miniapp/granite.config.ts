import { defineConfig } from '@apps-in-toss/web-framework/config'

export default defineConfig({
  appName: 'jnews',
  brand: {
    displayName: '지음뉴스',
    primaryColor: '#1b2a4a',
    icon: 'https://backend-ruby-chi-85.vercel.app/icon.png',
  },
  permissions: [],
  web: {
    host: 'localhost',
    port: 5173,
    commands: {
      dev: 'vite',
      build: 'vite build',
    },
  },
  outdir: 'dist',
})
