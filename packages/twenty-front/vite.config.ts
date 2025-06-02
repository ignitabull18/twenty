import react from '@vitejs/plugin-react-swc';
import { defineConfig, loadEnv } from 'vite';
import checker from 'vite-plugin-checker';
import svgr from 'vite-plugin-svgr';
import tsconfigPaths from 'vite-tsconfig-paths';
import { UserConfig } from 'vite';
import { lingui } from '@lingui/vite-plugin';

type Checkers = Parameters<typeof checker>[0];

// https://vitejs.dev/config/
export default defineConfig(({ command, mode }) => {
  const env = loadEnv(mode, process.cwd(), '');

  const { DEV_SERVER_PORT: port = '3001' } = env;

  const isBuildCommand = command === 'build';

  const tsConfigPath = isBuildCommand
    ? 'tsconfig.build.json'
    : 'tsconfig.json';

  const checkers: Checkers = {
    typescript: {
      tsconfigPath: tsConfigPath,
    },
    overlay: false,
  };

  const config: UserConfig = {
    root: __dirname,
    cacheDir: '../../node_modules/.vite/packages/twenty-front',

    server: {
      port: parseInt(port),
      host: process.env.VITE_HOST,
    },

    plugins: [
      react({
        jsxImportSource: '@emotion/react',
        plugins: [
          ['@swc/plugin-emotion', {}],
          ['@lingui/swc-plugin', {}],
        ],
      }),
      tsconfigPaths({
        projects: ['packages/twenty-front/tsconfig.json'],
      }),
      svgr(),
      !isBuildCommand && !env.VITE_DISABLE_TYPESCRIPT_CHECKER
        ? checker(checkers)
        : undefined,
      // Conditionally add Lingui plugin - disable in Docker builds
      process.env.DOCKER_BUILD !== 'true' ? lingui() : undefined,
    ].filter(Boolean),

    optimizeDeps: {
      exclude: ['node_modules/.vite', 'node_modules/.cache'],
    },

    build: {
      outDir: 'build',
      sourcemap: process.env.VITE_BUILD_SOURCEMAP === 'true',
    },

    envPrefix: 'REACT_APP_',

    define: {
      'process.env': {
        NODE_ENV: `'${mode}'`,
      },
    },
    css: {
      modules: {
        localsConvention: 'camelCaseOnly',
      },
    },
  };

  return config;
});