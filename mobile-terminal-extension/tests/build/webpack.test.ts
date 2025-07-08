import * as path from 'path';
import * as fs from 'fs';

describe('Webpack Configuration', () => {
  const webpackConfigPath = path.join(__dirname, '../../webpack.config.js');

  it('should have webpack.config.js file', () => {
    expect(fs.existsSync(webpackConfigPath)).toBe(true);
  });

  it('should have proper configuration structure', () => {
    // This test will fail until we create the webpack config
    const webpackConfig = require('../../webpack.config.js');
    
    expect(webpackConfig).toBeDefined();
    expect(webpackConfig.target).toBe('node');
    expect(webpackConfig.entry).toBe('./src/extension.ts');
    expect(webpackConfig.output).toBeDefined();
    expect(webpackConfig.output.filename).toBe('extension.js');
    expect(webpackConfig.output.libraryTarget).toBe('commonjs2');
    expect(webpackConfig.resolve).toBeDefined();
    expect(webpackConfig.resolve.extensions).toContain('.ts');
    expect(webpackConfig.module).toBeDefined();
    expect(webpackConfig.module.rules).toBeDefined();
  });

  it('should have TypeScript loader configured', () => {
    const webpackConfig = require('../../webpack.config.js');
    
    const tsRule = webpackConfig.module.rules.find((rule: any) => 
      rule.test && rule.test.test && rule.test.test('.ts')
    );
    
    expect(tsRule).toBeDefined();
    expect(Array.isArray(tsRule.use)).toBe(true);
    expect(tsRule.use[0].loader).toBe('ts-loader');
    expect(tsRule.exclude).toEqual(/node_modules/);
  });

  it('should externalize vscode module', () => {
    const webpackConfig = require('../../webpack.config.js');
    
    expect(webpackConfig.externals).toBeDefined();
    expect(webpackConfig.externals.vscode).toBe('commonjs vscode');
  });

  it('should have proper devtool for debugging', () => {
    const webpackConfig = require('../../webpack.config.js');
    
    expect(webpackConfig.devtool).toBe('nosources-source-map');
  });
});