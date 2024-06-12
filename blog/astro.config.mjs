import { defineConfig } from 'astro/config';

export default defineConfig({
  site: 'https://justinmoon.com',
  output: 'static',
  image: {
    service: {
      entrypoint: 'astro/assets/services/noop'
    }
  }
});
