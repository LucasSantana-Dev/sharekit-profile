# Web Application and Infrastructure Security Best Practices

Reference guide for implementing security best practices across web applications and infrastructure. Covers OWASP Top 10, authentication, API security, and deployment hardening.

## When to use this reference

- Adding authentication or session management to a web app
- Securing APIs (HTTPS, CORS, CSRF, rate limiting)
- Implementing security policies (GDPR, PCI-DSS compliance)
- Auditing existing web application security

## 1. HTTPS and Secure Transport

**Core principle:** All production traffic must use HTTPS with proper certificate validation.

### HTTPS enforcement

```typescript
import express from 'express';

const app = express();

// Redirect HTTP to HTTPS in production
app.use((req, res, next) => {
  if (process.env.NODE_ENV === 'production' && !req.secure) {
    return res.redirect(301, `https://${req.headers.host}${req.url}`);
  }
  next();
});
```

### HSTS (HTTP Strict Transport Security)

Use Helmet middleware to enforce HTTPS and set security headers:

```typescript
import helmet from 'helmet';

app.use(helmet({
  hsts: {
    maxAge: 31536000,    // 1 year in seconds
    includeSubDomains: true,
    preload: true        // Submit to HSTS preload list
  }
}));
```

## 2. Security Headers via Helmet

Content Security Policy (CSP), X-Frame-Options, and other security headers prevent common attacks:

```typescript
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'", "'unsafe-inline'", "https://trusted-cdn.com"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      imgSrc: ["'self'", "data:", "https:"],
      connectSrc: ["'self'", "https://api.example.com"],
      fontSrc: ["'self'", "https:", "data:"],
      objectSrc: ["'none'"],
      mediaSrc: ["'self'"],
      frameSrc: ["'none'"],
    },
  },
  hsts: {
    maxAge: 31536000,
    includeSubDomains: true,
    preload: true
  },
  frameguard: { action: 'deny' },           // X-Frame-Options: DENY
  xssFilter: true,                          // X-XSS-Protection
  noSniff: true,                            // X-Content-Type-Options
  referrerPolicy: { policy: 'strict-origin-when-cross-origin' }
}));
```

## 3. CORS Configuration

Restrict CORS origins to prevent cross-origin attacks:

```typescript
import cors from 'cors';

// Whitelist approach (safer)
const allowedOrigins = [
  'https://example.com',
  'https://app.example.com'
];

app.use(cors({
  origin: (origin, callback) => {
    if (!origin || allowedOrigins.includes(origin)) {
      callback(null, true);
    } else {
      callback(new Error('Not allowed by CORS'));
    }
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));

// Never use this:
// app.use(cors({ origin: '*' }));  // INSECURE
```

## 4. CSRF Protection

Prevent Cross-Site Request Forgery attacks using CSRF tokens:

```typescript
import csrf from 'csurf';
import cookieParser from 'cookie-parser';

app.use(cookieParser());

const csrfProtection = csrf({ cookie: true });

// Provide CSRF token to client
app.get('/api/csrf-token', csrfProtection, (req, res) => {
  res.json({ csrfToken: req.csrfToken() });
});

// Protect all state-changing requests
app.post('/api/*', csrfProtection, (req, res, next) => {
  // CSRF token is validated automatically by middleware
  next();
});

// Client-side usage:
// fetch('/api/users', {
//   method: 'POST',
//   headers: {
//     'CSRF-Token': csrfToken,
//     'Content-Type': 'application/json'
//   },
//   body: JSON.stringify(data)
// });
```

## 5. Rate Limiting (DDoS Protection)

Limit request rates per IP to prevent brute-force and DoS attacks:

```typescript
import rateLimit from 'express-rate-limit';

// General API limiter
const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,  // 15 minutes
  max: 100,                   // 100 requests per window
  message: 'Too many requests, please try again later',
  standardHeaders: true,
  legacyHeaders: false,
});

// Stricter limiter for authentication endpoints
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 5,                      // 5 attempts per 15 minutes
  skipSuccessfulRequests: true // Don't count successful logins
});

app.use('/api/', apiLimiter);
app.post('/api/auth/login', authLimiter, (req, res) => {
  // Login route logic
});
```

## 6. Input Validation

Always validate and sanitize user input to prevent injection attacks:

```typescript
import Joi from 'joi';
import DOMPurify from 'isomorphic-dompurify';

const userSchema = Joi.object({
  email: Joi.string().email().required(),
  password: Joi.string()
    .min(8)
    .pattern(/^(?=.*[A-Z])(?=.*[a-z])(?=.*\d)(?=.*[@$!%*?&])/)
    .required(),
  name: Joi.string().min(2).max(50).required()
});

app.post('/api/users', async (req, res) => {
  // 1. Validate input schema
  const { error, value } = userSchema.validate(req.body);
  if (error) {
    return res.status(400).json({ error: error.details[0].message });
  }

  // 2. Use parameterized queries (see code-security reference)
  const user = await db.query(
    'SELECT * FROM users WHERE email = $1',
    [value.email]
  );

  // 3. Sanitize output for HTML context
  const sanitized = DOMPurify.sanitize(userInput);
  
  res.json({ user: sanitized });
});
```

## 7. Authentication Security

Use strong, time-limited tokens with rotation:

```typescript
import jwt from 'jsonwebtoken';

// Access Token: short-lived (15 minutes)
const accessToken = jwt.sign(
  { userId: user.id },
  process.env.ACCESS_TOKEN_SECRET,
  { expiresIn: '15m' }
);

// Refresh Token: long-lived (7 days), stored in DB
const refreshToken = jwt.sign(
  { userId: user.id },
  process.env.REFRESH_TOKEN_SECRET,
  { expiresIn: '7d' }
);

await db.refreshToken.create({
  userId: user.id,
  token: refreshToken,
  expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000)
});

// Refresh Token Rotation: issue new tokens on each refresh
app.post('/api/auth/refresh', async (req, res) => {
  const { refreshToken } = req.body;
  
  try {
    const payload = jwt.verify(refreshToken, process.env.REFRESH_TOKEN_SECRET);
    
    // Invalidate old token
    await db.refreshToken.delete({ where: { token: refreshToken } });
    
    // Issue new tokens
    const newAccessToken = jwt.sign(
      { userId: payload.userId },
      process.env.ACCESS_TOKEN_SECRET,
      { expiresIn: '15m' }
    );
    
    const newRefreshToken = jwt.sign(
      { userId: payload.userId },
      process.env.REFRESH_TOKEN_SECRET,
      { expiresIn: '7d' }
    );
    
    res.json({ accessToken: newAccessToken, refreshToken: newRefreshToken });
  } catch (err) {
    res.status(401).json({ error: 'Invalid refresh token' });
  }
});
```

## 8. Secrets Management

Never hardcode secrets; always use environment variables or secret managers:

```typescript
// ✅ Correct: Load from environment
const dbUrl = process.env.DATABASE_URL;
const jwtSecret = process.env.JWT_SECRET;
const apiKey = process.env.API_KEY;

if (!dbUrl || !jwtSecret) {
  throw new Error('Required environment variables not set');
}

// ❌ NEVER do this:
// const dbUrl = 'postgresql://user:password@localhost/mydb';
// const apiKey = 'sk_test_xxx';
```

For Kubernetes:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: myapp-secrets
type: Opaque
stringData:
  database-url: postgresql://user:password@postgres:5432/mydb
  jwt-secret: your-super-secret-key-32-chars-min
  api-key: sk_test_xxx
```

## 9. OWASP Top 10 Checklist

Use this checklist when securing a web application:

```markdown
- [ ] A01: Broken Access Control
  → Implement RBAC, validate permissions on every request
  
- [ ] A02: Cryptographic Failures
  → Use HTTPS, encrypt sensitive data, rotate keys regularly
  
- [ ] A03: Injection
  → Use parameterized queries, input validation, ORM libraries
  
- [ ] A04: Insecure Design
  → Threat modeling, secure by default, principle of least privilege
  
- [ ] A05: Security Misconfiguration
  → Use Helmet, disable debug modes in production, default passwords
  
- [ ] A06: Vulnerable Components
  → Keep dependencies updated, run npm audit regularly
  
- [ ] A07: Authentication Failures
  → Strong passwords, MFA, token rotation, secure sessions
  
- [ ] A08: Data Integrity Failures
  → Cryptographic signatures, CSRF tokens, secure serialization
  
- [ ] A09: Logging & Monitoring Failures
  → Log security events, monitor for anomalies, alert on critical events
  
- [ ] A10: SSRF
  → Validate/whitelist URLs, use allowlists for external requests
```

## 10. Key Principles

**Principle of Least Privilege:** Grant minimum required permissions.  
**Defense in Depth:** Multiple security layers; don't rely on a single control.  
**Security by Design:** Consider security from the start, not as an afterthought.  
**Regular Audits:** Perform periodic security reviews and penetration testing.

## Related references

See `/code-security` for language-specific vulnerable patterns (SQL injection, XSS, command injection, etc.)  
See `/secure` skill for secret/credential handling and operational security checks.
