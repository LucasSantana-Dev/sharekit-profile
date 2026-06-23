# Workflow And Constraints

## When to use this skill

이 스킬을 트리거해야 하는 구체적인 상황을 나열합니다:

- **새 기능 개발**: TDD(Test-Driven Development) 방식으로 테스트 먼저 작성
- **API 엔드포인트 추가**: REST API의 성공/실패 케이스 테스트
- **버그 수정**: 회귀 방지를 위한 테스트 추가
- **리팩토링 전**: 기존 동작을 보장하는 테스트 작성
- **CI/CD 설정**: 자동화된 테스트 파이프라인 구축

## 입력 형식 (Input Format)

사용자로부터 받아야 할 입력의 형식과 필수/선택 정보:

### 필수 정보
- **프레임워크**: Express, Django, FastAPI, Spring Boot 등
- **테스트 도구**: Jest, Pytest, Mocha/Chai, JUnit 등
- **테스트 대상**: API 엔드포인트, 비즈니스 로직, DB 작업 등

### 선택 정보
- **데이터베이스**: PostgreSQL, MySQL, MongoDB (기본값: in-memory DB)
- **모킹 라이브러리**: jest.mock, sinon, unittest.mock (기본값: 프레임워크 내장)
- **커버리지 목표**: 80%, 90% 등 (기본값: 80%)
- **E2E 도구**: Supertest, TestClient, RestAssured (선택)

### 입력 예시

```
Express.js API의 사용자 인증 엔드포인트를 테스트해줘:
- 프레임워크: Express + TypeScript
- 테스트 도구: Jest + Supertest
- 대상: POST /auth/register, POST /auth/login
- DB: PostgreSQL (테스트용 in-memory)
- 커버리지: 90% 이상
```

## Instructions

단계별로 정확하게 따라야 할 작업 순서를 명시합니다.

### Step 1: 테스트 환경 설정

테스트 프레임워크 및 도구를 설치하고 설정합니다.

**작업 내용**:
- 테스트 라이브러리 설치
- 테스트 데이터베이스 설정 (in-memory 또는 별도 DB)
- 환경변수 분리 (.env.test)
- jest.config.js 또는 pytest.ini 설정

**예시** (Node.js + Jest + Supertest):
```bash
npm install --save-dev jest ts-jest @types/jest supertest @types/supertest
```

**jest.config.js**:
```javascript
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  roots: ['<rootDir>/src'],
  testMatch: ['**/__tests__/**/*.test.ts'],
  collectCoverageFrom: [
    'src/**/*.ts',
    '!src/**/*.d.ts',
    '!src/__tests__/**'
  ],
  coverageThreshold: {
    global: {
      branches: 80,
      functions: 80,
      lines: 80,
      statements: 80
    }
  },
  setupFilesAfterEnv: ['<rootDir>/src/__tests__/setup.ts']
};
```

**setup.ts** (테스트 전역 설정):
```typescript
import { db } from '../database';

// 각 테스트 전 DB 초기화
beforeEach(async () => {
  await db.migrate.latest();
  await db.seed.run();
});

// 각 테스트 후 정리
afterEach(async () => {
  await db.migrate.rollback();
});

// 모든 테스트 완료 후 연결 종료
afterAll(async () => {
  await db.destroy();
});
```

### Step 2: Unit Test 작성 (비즈니스 로직)

개별 함수/클래스의 단위 테스트를 작성합니다.

**작업 내용**:
- 순수 함수 테스트 (의존성 없음)
- 모킹을 통한 의존성 격리
- Edge case 테스트 (경계값, 예외)
- AAA 패턴 (Arrange-Act-Assert)

**판단 기준**:
- 외부 의존성(DB, API) 없음 → 순수 Unit Test
- 외부 의존성 있음 → Mock/Stub 사용
- 복잡한 로직 → 다양한 입력 케이스 테스트

**예시** (비밀번호 검증 함수):
```typescript
// src/utils/password.ts
export function validatePassword(password: string): { valid: boolean; errors: string[] } {
  const errors: string[] = [];

  if (password.length < 8) {
    errors.push('Password must be at least 8 characters');
  }

  if (!/[A-Z]/.test(password)) {
    errors.push('Password must contain uppercase letter');
  }

  if (!/[a-z]/.test(password)) {
    errors.push('Password must contain lowercase letter');
  }

  if (!/\d/.test(password)) {
    errors.push('Password must contain number');
  }

  if (!/[!@#$%^&*]/.test(password)) {
    errors.push('Password must contain special character');
  }

  return { valid: errors.length === 0, errors };
}

// src/__tests__/utils/password.test.ts
import { validatePassword } from '../../utils/password';

describe('validatePassword', () => {
  it('should accept valid password', () => {
    const result = validatePassword('Password123!');
    expect(result.valid).toBe(true);
    expect(result.errors).toHaveLength(0);
  });

  it('should reject password shorter than 8 characters', () => {
    const result = validatePassword('Pass1!');
    expect(result.valid).toBe(false);
    expect(result.errors).toContain('Password must be at least 8 characters');
  });

  it('should reject password without uppercase', () => {
    const result = validatePassword('password123!');
    expect(result.valid).toBe(false);
    expect(result.errors).toContain('Password must contain uppercase letter');
  });

  it('should reject password without lowercase', () => {
    const result = validatePassword('PASSWORD123!');
    expect(result.valid).toBe(false);
    expect(result.errors).toContain('Password must contain lowercase letter');
  });

  it('should reject password without number', () => {
    const result = validatePassword('Password!');
    expect(result.valid).toBe(false);
    expect(result.errors).toContain('Password must contain number');
  });

  it('should reject password without special character', () => {
    const result = validatePassword('Password123');
    expect(result.valid).toBe(false);
    expect(result.errors).toContain('Password must contain special character');
  });

  it('should return multiple errors for invalid password', () => {
    const result = validatePassword('pass');
    expect(result.valid).toBe(false);
    expect(result.errors.length).toBeGreaterThan(1);
  });
});
```

### Step 3: Integration Test (API 엔드포인트)

API 엔드포인트의 통합 테스트를 작성합니다.

**작업 내용**:
- HTTP 요청/응답 테스트
- 성공 케이스 (200, 201)
- 실패 케이스 (400, 401, 404, 500)
- 인증/권한 테스트
- 입력 검증 테스트

**확인 사항**:
- [x] Status code 확인
- [x] Response body 구조 검증
- [x] Database 상태 변화 확인
- [x] 에러 메시지 검증

**예시** (Express.js + Supertest):
```typescript
// src/__tests__/api/auth.test.ts
import request from 'supertest';
import app from '../../app';
import { db } from '../../database';

describe('POST /auth/register', () => {
  it('should register new user successfully', async () => {
    const response = await request(app)
      .post('/api/auth/register')
      .send({
        email: 'test@example.com',
        username: 'testuser',
        password: 'Password123!'
      });

    expect(response.status).toBe(201);
    expect(response.body).toHaveProperty('user');
    expect(response.body).toHaveProperty('accessToken');
    expect(response.body.user.email).toBe('test@example.com');

    // DB에 실제로 저장되었는지 확인
    const user = await db.user.findUnique({ where: { email: 'test@example.com' } });
    expect(user).toBeTruthy();
    expect(user.username).toBe('testuser');
  });

  it('should reject duplicate email', async () => {
    // 첫 번째 사용자 생성
    await request(app)
      .post('/api/auth/register')
      .send({
        email: 'test@example.com',
        username: 'user1',
        password: 'Password123!'
      });

    // 같은 이메일로 두 번째 시도
    const response = await request(app)
      .post('/api/auth/register')
      .send({
        email: 'test@example.com',
        username: 'user2',
        password: 'Password123!'
      });

    expect(response.status).toBe(409);
    expect(response.body.error).toContain('already exists');
  });

  it('should reject weak password', async () => {
    const response = await request(app)
      .post('/api/auth/register')
      .send({
        email: 'test@example.com',
        username: 'testuser',
        password: 'weak'
      });

    expect(response.status).toBe(400);
    expect(response.body.error).toBeDefined();
  });

  it('should reject missing fields', async () => {
    const response = await request(app)
      .post('/api/auth/register')
      .send({
        email: 'test@example.com'
        // username, password 누락
      });

    expect(response.status).toBe(400);
  });
});

describe('POST /auth/login', () => {
  beforeEach(async () => {
    // 테스트용 사용자 생성
    await request(app)
      .post('/api/auth/register')
      .send({
        email: 'test@example.com',
        username: 'testuser',
        password: 'Password123!'
      });
  });

  it('should login with valid credentials', async () => {
    const response = await request(app)
      .post('/api/auth/login')
      .send({
        email: 'test@example.com',
        password: 'Password123!'
      });

    expect(response.status).toBe(200);
    expect(response.body).toHaveProperty('accessToken');
    expect(response.body).toHaveProperty('refreshToken');
    expect(response.body.user.email).toBe('test@example.com');
  });

  it('should reject invalid password', async () => {
    const response = await request(app)
      .post('/api/auth/login')
      .send({
        email: 'test@example.com',
        password: 'WrongPassword123!'
      });

    expect(response.status).toBe(401);
    expect(response.body.error).toContain('Invalid credentials');
  });

  it('should reject non-existent user', async () => {
    const response = await request(app)
      .post('/api/auth/login')
      .send({
        email: 'nonexistent@example.com',
        password: 'Password123!'
      });

    expect(response.status).toBe(401);
  });
});
```

### Step 4: 인증/권한 테스트

JWT 토큰 및 권한 기반 접근 제어를 테스트합니다.

**작업 내용**:
- 토큰 없이 접근 시 401 확인
- 유효한 토큰으로 접근 성공 확인
- 만료된 토큰 처리 테스트
- Role-based 권한 테스트

**예시**:
```typescript
describe('Protected Routes', () => {
  let accessToken: string;
  let adminToken: string;

  beforeEach(async () => {
    // 일반 사용자 토큰
    const userResponse = await request(app)
      .post('/api/auth/register')
      .send({
        email: 'user@example.com',
        username: 'user',
        password: 'Password123!'
      });
    accessToken = userResponse.body.accessToken;

    // 관리자 토큰
    const adminResponse = await request(app)
      .post('/api/auth/register')
      .send({
        email: 'admin@example.com',
        username: 'admin',
        password: 'Password123!'
      });
    // DB에서 role을 'admin'으로 변경
    await db.user.update({
      where: { email: 'admin@example.com' },
      data: { role: 'admin' }
    });
    // 다시 로그인해서 새 토큰 받기
    const loginResponse = await request(app)
      .post('/api/auth/login')
      .send({
        email: 'admin@example.com',
        password: 'Password123!'
      });
    adminToken = loginResponse.body.accessToken;
  });

  describe('GET /api/auth/me', () => {
    it('should return current user with valid token', async () => {
      const response = await request(app)
        .get('/api/auth/me')
        .set('Authorization', `Bearer ${accessToken}`);

      expect(response.status).toBe(200);
      expect(response.body.user.email).toBe('user@example.com');
    });

    it('should reject request without token', async () => {
      const response = await request(app)
        .get('/api/auth/me');

      expect(response.status).toBe(401);
    });

    it('should reject request with invalid token', async () => {
      const response = await request(app)
        .get('/api/auth/me')
        .set('Authorization', 'Bearer invalid-token');

      expect(response.status).toBe(403);
    });
  });

  describe('DELETE /api/users/:id (Admin only)', () => {
    it('should allow admin to delete user', async () => {
      const targetUser = await db.user.findUnique({ where: { email: 'user@example.com' } });

      const response = await request(app)
        .delete(`/api/users/${targetUser.id}`)
        .set('Authorization', `Bearer ${adminToken}`);

      expect(response.status).toBe(200);
    });

    it('should forbid non-admin from deleting user', async () => {
      const targetUser = await db.user.findUnique({ where: { email: 'user@example.com' } });

      const response = await request(app)
        .delete(`/api/users/${targetUser.id}`)
        .set('Authorization', `Bearer ${accessToken}`);

      expect(response.status).toBe(403);
    });
  });
});
```

### Step 5: Mocking 및 테스트 격리

외부 의존성을 모킹하여 테스트를 격리합니다.

**작업 내용**:
- 외부 API 모킹
- 이메일 발송 모킹
- 파일 시스템 모킹
- 시간 관련 함수 모킹

**예시** (외부 API 모킹):
```typescript
// src/services/emailService.ts
export async function sendVerificationEmail(email: string, token: string): Promise<void> {
  const response = await fetch('https://api.sendgrid.com/v3/mail/send', {
    method: 'POST',
    headers: { 'Authorization': `Bearer ${process.env.SENDGRID_API_KEY}` },
    body: JSON.stringify({
      to: email,
      subject: 'Verify your email',
      html: `<a href="https://example.com/verify?token=${token}">Verify</a>`
    })
  });

  if (!response.ok) {
    throw new Error('Failed to send email');
  }
}

// src/__tests__/services/emailService.test.ts
import { sendVerificationEmail } from '../../services/emailService';

// fetch 모킹
global.fetch = jest.fn();

describe('sendVerificationEmail', () => {
  beforeEach(() => {
    (fetch as jest.Mock).mockClear();
  });

  it('should send email successfully', async () => {
    (fetch as jest.Mock).mockResolvedValueOnce({
      ok: true,
      status: 200
    });

    await expect(sendVerificationEmail('test@example.com', 'token123'))
      .resolves
      .toBeUndefined();

    expect(fetch).toHaveBeenCalledWith(
      'https://api.sendgrid.com/v3/mail/send',
      expect.objectContaining({
        method: 'POST'
      })
    );
  });

  it('should throw error if email sending fails', async () => {
    (fetch as jest.Mock).mockResolvedValueOnce({
      ok: false,
      status: 500
    });

    await expect(sendVerificationEmail('test@example.com', 'token123'))
      .rejects
      .toThrow('Failed to send email');
  });
});
```

## Output format

결과물이 따라야 할 정확한 형식을 정의합니다.

### 기본 구조

```
프로젝트/
├── src/
│   ├── __tests__/
│   │   ├── setup.ts                 # 테스트 전역 설정
│   │   ├── utils/
│   │   │   └── password.test.ts     # Unit tests
│   │   ├── services/
│   │   │   └── emailService.test.ts
│   │   └── api/
│   │       ├── auth.test.ts         # Integration tests
│   │       └── users.test.ts
│   └── ...
├── jest.config.js
└── package.json
```

### 테스트 실행 스크립트 (package.json)

```json
{
  "scripts": {
    "test": "jest",
    "test:watch": "jest --watch",
    "test:coverage": "jest --coverage",
    "test:ci": "jest --ci --coverage --maxWorkers=2"
  }
}
```

### 커버리지 리포트

```bash
$ npm run test:coverage

--------------------------|---------|----------|---------|---------|
File                      | % Stmts | % Branch | % Funcs | % Lines |
--------------------------|---------|----------|---------|---------|
All files                 |   92.5  |   88.3   |   95.2  |   92.8  |
 auth/                    |   95.0  |   90.0   |  100.0  |   95.0  |
  middleware.ts           |   95.0  |   90.0   |  100.0  |   95.0  |
  routes.ts               |   95.0  |   90.0   |  100.0  |   95.0  |
 utils/                   |   90.0  |   85.0   |   90.0  |   90.0  |
  password.ts             |   90.0  |   85.0   |   90.0  |   90.0  |
--------------------------|---------|----------|---------|---------|
```

## Constraints

반드시 지켜야 할 규칙과 금지 사항을 명시합니다.

### 필수 규칙 (MUST)

1. **테스트 격리**: 각 테스트는 독립적으로 실행 가능해야 함
   - beforeEach/afterEach로 상태 초기화
   - 테스트 순서에 의존하지 않음

2. **명확한 테스트명**: 테스트가 무엇을 검증하는지 이름에서 알 수 있어야 함
   - ✅ 'should reject duplicate email'
   - ❌ 'test1'

3. **AAA 패턴**: Arrange(준비) - Act(실행) - Assert(검증) 구조
   - 가독성 향상
   - 테스트 의도 명확화

### 금지 사항 (MUST NOT)

1. **프로덕션 DB 사용 금지**: 테스트는 별도 DB 또는 in-memory DB 사용
   - 실제 데이터 손실 위험
   - 테스트 격리 불가

2. **실제 외부 API 호출 금지**: 외부 서비스는 모킹
   - 네트워크 의존성 제거
   - 테스트 속도 향상
   - 비용 절감

3. **Sleep/Timeout 남용 금지**: 시간 기반 테스트는 가짜 타이머 사용
   - jest.useFakeTimers()
   - 테스트 속도 저하 방지

### 보안 규칙

- **민감정보 하드코딩 금지**: 테스트 코드에도 API 키, 비밀번호 하드코딩 금지
- **환경변수 분리**: .env.test 파일 사용
