# src/config.ts (entire file)
1  export const config = {
2    appName: "relay-mini",
3    port: 8080,
4    logLevel: "info",
5    // seconds
6    requestTimeout: 30,
7    retries: 2,
8  };
No other file reads requestTimeout except src/http.ts line 14 (`config.requestTimeout * 1000`).
