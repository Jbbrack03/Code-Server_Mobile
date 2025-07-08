// Jest setup file for VS Code extension tests
import { jest } from '@jest/globals';

// Global test setup
beforeEach(() => {
  jest.clearAllMocks();
});

afterEach(() => {
  jest.restoreAllMocks();
});

// Custom matchers or global test utilities can be added here
declare global {
  namespace jest {
    interface Matchers<R> {
      toBeValidTerminalId(): R;
    }
  }
}

// Make the global declaration available
declare module '@jest/expect' {
  interface Matchers<R> {
    toBeValidTerminalId(): R;
  }
}

// Add custom matcher for terminal ID validation
expect.extend({
  toBeValidTerminalId(received: string) {
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[4][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
    const pass = typeof received === 'string' && uuidRegex.test(received);
    
    return {
      message: () => `expected ${received} to be a valid UUID v4 terminal ID`,
      pass,
    };
  },
});