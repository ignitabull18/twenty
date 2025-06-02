const { defineConfig } = require('@lingui/conf');
const { formatter } = require('@lingui/format-po');

// Simple fallback configuration for Docker builds
module.exports = defineConfig({
  sourceLocale: 'en',
  locales: ['en'],
  pseudoLocale: 'pseudo-en',
  fallbackLocales: {
    'pseudo-en': 'en',
    default: 'en',
  },
  catalogs: [
    {
      path: '<rootDir>/packages/twenty-front/src/locales/{locale}',
      include: ['packages/twenty-front/src'],
    },
  ],
  catalogsMergePath: '<rootDir>/packages/twenty-front/src/locales/generated/{locale}',
  compileNamespace: 'ts',
  format: formatter({ lineNumbers: false, printLinguiId: true }),
});
