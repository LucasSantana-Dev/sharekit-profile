# Practice And Troubleshooting

## Best practices

### 품질 향상

1. **TDD (Test-Driven Development)**: 코드 작성 전에 테스트 먼저
   - 요구사항 명확화
   - 설계 개선
   - 높은 커버리지 자연스럽게 달성

2. **Given-When-Then 패턴**: BDD 스타일로 테스트 작성
   ```typescript
   it('should return 404 when user not found', async () => {
     // Given: 존재하지 않는 사용자 ID
     const nonExistentId = 'non-existent-uuid';

     // When: 해당 사용자 조회 시도
     const response = await request(app).get(`/users/${nonExistentId}`);

     // Then: 404 응답
     expect(response.status).toBe(404);
   });
   ```

3. **Test Fixtures**: 재사용 가능한 테스트 데이터
   ```typescript
   const validUser = {
     email: 'test@example.com',
     username: 'testuser',
     password: 'Password123!'
   };
   ```

### 효율성 개선

- **병렬 실행**: Jest의 `--maxWorkers` 옵션으로 테스트 속도 향상
- **Snapshot Testing**: UI 컴포넌트나 JSON 응답 스냅샷 저장
- **Coverage 임계값**: jest.config.js에서 최소 커버리지 강제

## 자주 발생하는 문제 (Common Issues)

### 문제 1: 테스트 간 상태 공유로 인한 실패

**증상**: 개별 실행은 성공하지만 전체 실행 시 실패

**원인**: beforeEach/afterEach 누락으로 DB 상태 공유

**해결방법**:
```typescript
beforeEach(async () => {
  await db.migrate.rollback();
  await db.migrate.latest();
});
```

### 문제 2: "Jest did not exit one second after the test run"

**증상**: 테스트 완료 후 프로세스가 종료되지 않음

**원인**: DB 연결, 서버 등이 정리되지 않음

**해결방법**:
```typescript
afterAll(async () => {
  await db.destroy();
  await server.close();
});
```

### 문제 3: 비동기 테스트 타임아웃

**증상**: "Timeout - Async callback was not invoked"

**원인**: async/await 누락 또는 Promise 미처리

**해결방법**:
```typescript
// ❌ 나쁜 예
it('should work', () => {
  request(app).get('/users');  // Promise 미처리
});

// ✅ 좋은 예
it('should work', async () => {
  await request(app).get('/users');
});
```

## References

### 공식 문서
- [Jest Documentation](https://jestjs.io/docs/getting-started)
- [Pytest Documentation](https://docs.pytest.org/)
- [Supertest GitHub](https://github.com/visionmedia/supertest)

### 학습 자료
- [Testing JavaScript with Kent C. Dodds](https://testingjavascript.com/)
- [Test-Driven Development by Example (Kent Beck)](https://www.amazon.com/Test-Driven-Development-Kent-Beck/dp/0321146530)

### 도구
- [Istanbul/nyc](https://istanbul.js.org/) - 코드 커버리지
- [nock](https://github.com/nock/nock) - HTTP 모킹
- [faker.js](https://fakerjs.dev/) - 테스트 데이터 생성

## Metadata

### 버전
- **현재 버전**: 1.0.0
- **최종 업데이트**: 2025-01-01
- **호환 플랫폼**: Claude, ChatGPT, Gemini

### 관련 스킬
- [api-design](../api-design/SKILL.md): API와 함께 테스트 설계
- [authentication-setup](../authentication/SKILL.md): 인증 시스템 테스트

### 태그
`#testing` `#backend` `#Jest` `#Pytest` `#unit-test` `#integration-test` `#TDD` `#API-test`
