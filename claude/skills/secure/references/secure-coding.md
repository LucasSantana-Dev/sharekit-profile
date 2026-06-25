# Secure Coding Guidelines

Language-specific and vulnerability-specific secure coding practices covering OWASP Top 10 and CWE categories. Use when reviewing or writing code that handles user input, databases, file operations, cryptography, or infrastructure.

**Quick reference:** Read the table of contents, find your vulnerability category, then check the language-specific examples.

## How to use this reference

1. **Proactive mode:** When writing code, check the relevant category below based on what the code does (handles input? queries a DB? reads files? cryptography?).
2. **Reactive mode:** When the user asks about security, find the relevant section, then review the vulnerable vs. secure patterns.
3. **By language:** Use the priority table to determine which rules to check first for your language.

## Language-Specific Priority Rules

| Language | Priority Rules |
|----------|---|
| **Python** | SQL injection, Command injection, Path traversal, Code injection, SSRF, Insecure crypto |
| **JavaScript/TypeScript** | XSS, Prototype pollution, Code injection, Insecure transport, CSRF |
| **Java** | SQL injection, XXE, Insecure deserialization, Insecure crypto, SSRF |
| **Go** | SQL injection, Command injection, Path traversal, Insecure transport |
| **C/C++** | Memory safety, Unsafe functions, Command injection, Buffer overflow |
| **Ruby** | SQL injection, Command injection, Code injection, Insecure deserialization |
| **PHP** | SQL injection, XSS, Command injection, Code injection, Path traversal |
| **Infrastructure (HCL/YAML)** | Terraform (AWS/Azure/GCP), Kubernetes, Docker, GitHub Actions |

---

## Critical Vulnerabilities

### 1. SQL Injection

Attackers manipulate database queries via user input, leading to data theft/deletion.

**Vulnerable patterns:** String concatenation (+), format strings (.format(), %, f-strings, String.Format()), template literals with variables.

#### Python

**Incorrect:**
```python
def get_user(user_input):
    cur.execute("SELECT * FROM users WHERE name = '" + user_input + "'")  # Concatenation
    cur.execute(f"SELECT * FROM users WHERE id = {user_input}")            # f-string
    cur.execute("SELECT * FROM users WHERE id = {}".format(user_input))    # format()
```

**Correct:**
```python
def get_user(user_input):
    cur.execute("SELECT * FROM users WHERE name = %s", [user_input])  # Parameterized
```

#### JavaScript

**Incorrect:**
```javascript
const sql = `SELECT * FROM users WHERE id = ${userId}`;       // Template literal
const sql = "SELECT * FROM users WHERE id = " + userId;       // Concatenation
const { rows } = await pool.query(sql);
```

**Correct:**
```javascript
const sql = 'SELECT * FROM users WHERE id = $1';
const { rows } = await pool.query(sql, [userId]);  // Parameterized
```

#### Java

**Incorrect:**
```java
Statement stmt = connection.createStatement();
String sql = "SELECT * FROM users WHERE name = '" + input + "'";  // Concatenation
stmt.executeQuery(sql);
```

**Correct:**
```java
PreparedStatement pstmt = connection.prepareStatement(
    "SELECT * FROM users WHERE name = ?");
pstmt.setString(1, input);
pstmt.executeQuery();
```

#### Go

**Incorrect:**
```go
query := "SELECT * FROM users WHERE name = '" + userInput + "'"  // Concatenation
query := fmt.Sprintf("SELECT * FROM users WHERE email = '%s'", email)  // Sprintf
db.Query(query)
```

**Correct:**
```go
db.Query("SELECT * FROM users WHERE name = $1", userInput)  // Parameterized
```

---

### 2. Command Injection

Untrusted input passed to OS commands allows arbitrary command execution.

#### Python

**Incorrect:**
```python
import subprocess
subprocess.run("ping " + ip, shell=True)  # Shell=true + user input = RCE
```

**Correct:**
```python
subprocess.run(["ping", ip])  # Array form, no shell expansion
```

#### JavaScript

**Incorrect:**
```javascript
const { exec } = require('child_process');
exec(`cat ${userInput}`, (error, stdout) => {});  // Shell expansion
```

**Correct:**
```javascript
const { spawn } = require('child_process');
const proc = spawn('cat', [userInput]);  // No shell
proc.stdout.on('data', (data) => {});
```

#### Java

**Incorrect:**
```java
String[] cmd = {"/bin/bash", "-c", userInput};  // Shell execution
ProcessBuilder builder = new ProcessBuilder(cmd);
```

**Correct:**
```java
ProcessBuilder builder = new ProcessBuilder("cat", filename);  // No shell
```

#### Go

**Incorrect:**
```go
cmd := exec.Command("bash")
cmdWriter.Write([]byte(fmt.Sprintf("echo %s", userInput)))  // Shell
```

**Correct:**
```go
cmd := exec.Command("cat", filename)  // Direct execution
output, _ := cmd.Output()
```

---

### 3. Cross-Site Scripting (XSS)

Unescaped user input in HTML leads to client-side code execution and session hijacking.

#### JavaScript

**Incorrect:**
```javascript
document.body.innerHTML = '<div>' + userInput + '</div>';  // Direct HTML
```

**Correct:**
```javascript
const div = document.createElement('div');
div.textContent = userInput;  // Text content, auto-escaped
document.body.appendChild(div);
```

#### Python (Flask)

**Incorrect:**
```python
from flask import make_response, request
query = request.args.get("q")
return make_response(f"Results for: {query}")  # Unescaped
```

**Correct:**
```python
from markupsafe import escape
return make_response(f"Results for: {escape(query)}")  # Escaped
```

#### Java

**Incorrect:**
```java
String name = req.getParameter("name");
resp.getWriter().write("<h1>Hello " + name + "</h1>");  // Unescaped
```

**Correct:**
```java
import org.owasp.encoder.Encode;
resp.getWriter().write("<h1>Hello " + Encode.forHtml(name) + "</h1>");
```

---

### 4. Path Traversal

User input in file paths allows access to files outside intended directories ("../../../etc/passwd").

#### Python

**Incorrect:**
```python
def unsafe(request):
    filename = request.POST.get('filename')
    f = open(filename, 'r')  # User controls path
```

**Correct:**
```python
def safe(request):
    filename = "/tmp/data.txt"  # Hardcoded or whitelisted
    f = open(filename, 'r')
```

#### JavaScript

**Incorrect:**
```javascript
const fs = require('fs');
function readUserFile(fileName) {
    fs.readFile(fileName, (err, data) => {});  // No validation
}
```

**Correct:**
```javascript
function readConfigFile() {
    fs.readFile('config/settings.json', (err, data) => {});  // Literal path
}
```

#### Go

**Incorrect:**
```go
filename := filepath.Clean(r.URL.Path)
filename = filepath.Join(root, strings.Trim(filename, "/"))  // Clean doesn't prevent traversal
```

**Correct:**
```go
filename := path.Clean("/" + r.URL.Path)  // Prefix with / before Clean
filename = filepath.Join(root, strings.Trim(filename, "/"))
```

---

### 5. Code Injection (eval, exec)

Direct code evaluation with user input leads to remote code execution.

#### Python

**Incorrect:**
```python
def unsafe(request):
    code = request.POST.get('code')
    eval(code)  # Arbitrary code execution
```

**Correct:**
```python
eval("x = 1; x = x + 2")  # Static string only
```

#### JavaScript

**Incorrect:**
```javascript
let dynamic = window.prompt()
eval(dynamic + 'possibly malicious code');  // User-controlled eval

function evalSomething(something) {
    eval(something);  // Function parameter = user input
}
```

**Correct:**
```javascript
eval('var x = "static strings are okay";');  // Static string
```

#### Java

**Incorrect:**
```java
ScriptEngineManager sem = new ScriptEngineManager();
ScriptEngine se = sem.getEngineByExtension("js");
Object result = se.eval("test=1;" + userInput);  // Concatenated user input
```

**Correct:**
```java
ScriptEngine se = sem.getEngineByExtension("js");
String code = "var test=3;test=test*2;";  // Static code
Object result = se.eval(code);
```

---

### 6. Insecure Deserialization

Deserializing untrusted data can lead to remote code execution (Python pickle, Java ObjectInputStream, Ruby Marshal, PHP unserialize).

#### Python

**Incorrect:**
```python
import pickle
user_obj = request.cookies.get('uuid')
return pickle.loads(b64decode(user_obj))  # Untrusted deserialization
```

**Correct:**
```python
import json
user_data = json.loads(request.data)  # Use JSON instead
# OR load from trusted local file:
data = pickle.load(open('./config/settings.dat', "rb"))
```

#### Java

**Incorrect:**
```java
ObjectInputStream in = new ObjectInputStream(receivedData);
return in.readObject();  // Untrusted data
```

**Correct:**
```java
ObjectMapper mapper = new ObjectMapper();
return mapper.readValue(data, MyClass.class);  // Use JSON
```

#### Ruby

**Incorrect:**
```ruby
obj = Marshal.load(data)  # Untrusted data
config = YAML.load(yaml_data)  # Untrusted data
```

**Correct:**
```ruby
config = YAML.safe_load(params['yaml'])  # Safe YAML
obj = JSON.parse(params['data'])  # Use JSON instead
```

---

### 7. Hardcoded Secrets

Credentials, API keys, and tokens in source code are exposed via version control.

#### Python

**Incorrect:**
```python
import boto3
s3 = boto3.resource(
    "s3",
    aws_access_key_id="AKIAxxxxxxxxxxxxxxxx",
    aws_secret_access_key="jWnyxxxxxxxxxxxxxxxxX7ZQxxxxxxxxxxxxxxxx"
)
```

**Correct:**
```python
import os
s3 = boto3.resource(
    "s3",
    aws_access_key_id=os.environ.get("AWS_ACCESS_KEY_ID"),
    aws_secret_access_key=os.environ.get("AWS_SECRET_ACCESS_KEY")
)
```

#### JavaScript

**Incorrect:**
```javascript
const token = jsonwt.sign(payload, 'my-secret-key');
const client = stripe('sk_test_20cbqx6v2hpftsbq203r36yqccazez');
```

**Correct:**
```javascript
const token = jsonwt.sign(payload, process.env.JWT_SECRET);
const client = stripe(process.env.STRIPE_SECRET_KEY);
```

---

### 8. XXE (XML External Entity)

Weakly configured XML parsers allow file access, SSRF, and DoS attacks.

#### Java

**Incorrect:**
```java
DocumentBuilderFactory dbf = DocumentBuilderFactory.newInstance();
dbf.newDocumentBuilder();  // XXE enabled by default
```

**Correct:**
```java
dbf.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true);
dbf.newDocumentBuilder();
```

#### Python

**Incorrect:**
```python
from xml.etree import ElementTree
tree = ElementTree.parse('data.xml')  # Vulnerable to XXE
```

**Correct:**
```python
from defusedxml.etree import ElementTree
tree = ElementTree.parse('data.xml')  # Safe parser
```

---

### 9. Memory Safety (C/C++)

Buffer overflow, use-after-free, and double-free lead to code execution.

#### C

**Incorrect:**
```c
void bad_code(char *user_input) {
    char buffer[64];
    strcpy(buffer, user_input);  // No bounds check = buffer overflow
}
```

**Correct:**
```c
void safe_code(char *user_input) {
    char buffer[64];
    strncpy(buffer, user_input, sizeof(buffer) - 1);
    buffer[sizeof(buffer) - 1] = '\0';  // Null terminate
}
```

**Incorrect (Use-after-free):**
```c
char *var = malloc(sizeof(char) * 10);
free(var);
var->data = 5;  // Use-after-free
```

**Correct:**
```c
free(var);
var = NULL;  // Prevent accidental reuse
```

---

## High Impact Vulnerabilities

### 10. Insecure Cryptography

Weak hashing (MD5, SHA1) or encryption (DES, RC4) compromises data confidentiality.

#### Python

**Incorrect:**
```python
import hashlib
hash_val = hashlib.md5(data).hexdigest()      # Weak
hash_val = hashlib.sha1(data).hexdigest()     # Weak
cipher = DES.new(key, DES.MODE_CTR)           # Weak cipher
```

**Correct:**
```python
hash_val = hashlib.sha256(data).hexdigest()   # Strong
cipher = AES.new(key, AES.MODE_EAX, nonce=nonce)  # Strong cipher
```

#### JavaScript

**Incorrect:**
```javascript
crypto.createHash("md5").update(pwtext).digest("hex");     // Weak
```

**Correct:**
```javascript
crypto.createHash("sha256").update(pwtext).digest("hex");  // Strong
```

#### Java

**Incorrect:**
```java
MessageDigest md5 = MessageDigest.getInstance("MD5");  // Weak
Cipher c = Cipher.getInstance("DES/ECB/PKCS5Padding");  // Weak
```

**Correct:**
```java
MessageDigest sha512 = MessageDigest.getInstance("SHA-512");  // Strong
Cipher c = Cipher.getInstance("AES/GCM/NoPadding");  // Strong
```

---

### 11. Insecure Transport

Cleartext transmission (HTTP) or disabled certificate verification exposes data to MITM attacks.

#### JavaScript

**Incorrect:**
```javascript
const http = require('http');
http.get('http://nodejs.org/dist/index.json');  // Cleartext
```

**Correct:**
```javascript
const https = require('https');
https.get('https://nodejs.org/dist/index.json');  // Encrypted
```

#### Python

**Incorrect:**
```python
import requests
requests.get("http://example.com")             # Cleartext
requests.get("https://example.com", verify=False)  # No certificate validation
```

**Correct:**
```python
requests.get("https://example.com")  // Certificate validation enabled
```

#### Go

**Incorrect:**
```go
resp, _ := http.Get("http://example.com")  // Cleartext
TLSClientConfig: &tls.Config{InsecureSkipVerify: true}  // No validation
```

**Correct:**
```go
resp, _ := http.Get("https://example.com")  // Encrypted
TLSClientConfig: &tls.Config{InsecureSkipVerify: false}  // Validate
```

---

### 12. SSRF (Server-Side Request Forgery)

User input in URLs allows the server to make requests to internal systems or cloud metadata endpoints.

#### Python

**Incorrect:**
```python
host = request.POST.get('host')
response = requests.get(f"https://{host}/api/users/{user_id}")  // User controls host
```

**Correct:**
```python
response = requests.get(f"https://api.example.com/users/{user_id}")  // Fixed host
```

#### JavaScript

**Incorrect:**
```javascript
const url = req.query.url;
const response = await axios.get(url);  // User-controlled URL
```

**Correct:**
```javascript
const resourceId = req.query.id;
const response = await axios.get(`https://api.example.com/resources/${resourceId}`);
```

---

### 13. CSRF (Cross-Site Request Forgery)

Unprotected state-changing requests can be triggered from attacker-controlled sites.

**See best-practices.md § 4. CSRF Protection for token implementation details.**

---

### 14. JWT Issues

Decoding JWTs without verifying signatures allows token forgery and authentication bypass.

#### JavaScript

**Incorrect:**
```javascript
const decoded = jwt.decode(token, true);  // Decode without verify
if (decoded.isAdmin) getAdminData();
```

**Correct:**
```javascript
jwt.verify(token, secretKey);  // Verify first
const decoded = jwt.decode(token, true);
```

#### Python

**Incorrect:**
```python
decoded = jwt.decode(token, key, options={"verify_signature": False})  // No verify
```

**Correct:**
```python
decoded = jwt.decode(token, key, algorithms=["HS256"])  // Verify enabled
```

---

### 15. Prototype Pollution (JavaScript)

Unvalidated object keys in JavaScript can pollute the Object.prototype, affecting all objects.

#### JavaScript

**Incorrect:**
```javascript
function merge(target, source) {
    for (const key in source) {
        target[key] = source[key];  // __proto__ can pollute prototype
    }
}

const user = {};
merge(user, userInput);  // If userInput = {__proto__: {isAdmin: true}}
```

**Correct:**
```javascript
function merge(target, source) {
    for (const key in source) {
        if (Object.prototype.hasOwnProperty.call(source, key) && key !== '__proto__') {
            target[key] = source[key];  // Validate keys
        }
    }
}
```

---

## Infrastructure Security

### Terraform (AWS/Azure/GCP)

**Common issues:**
- Public access to databases/S3 buckets
- Unencrypted EBS volumes or S3 buckets
- Overly permissive IAM policies
- No encryption in transit (TLS disabled)

**Checklist:**
- [ ] Enable encryption at rest (KMS, SSL/TLS for S3)
- [ ] Restrict ingress/egress with security groups
- [ ] Use IAM roles with least privilege (not access keys)
- [ ] Enable versioning and logging
- [ ] Use VPC endpoints for private access

### Kubernetes

**Common issues:**
- Privileged containers or running as root
- No network policies
- Secrets stored in ConfigMaps
- No resource limits

**Checklist:**
- [ ] `runAsNonRoot: true` in pod spec
- [ ] No `privileged: true` or `allowPrivilegeEscalation: true`
- [ ] Use NetworkPolicies to restrict traffic
- [ ] Store secrets in Kubernetes Secrets, not ConfigMaps
- [ ] Set CPU/memory resource limits

### Docker

**Common issues:**
- Running as root
- Using latest image tags
- No healthchecks
- Large base images

**Checklist:**
- [ ] Create non-root user: `RUN useradd -m appuser`
- [ ] Use specific image versions: `FROM node:18.17.0`
- [ ] Add HEALTHCHECK
- [ ] Use minimal base images (alpine, distroless)
- [ ] Scan images with `docker scan`

### GitHub Actions

**Common issues:**
- Hardcoded secrets in workflows
- Untrusted action versions
- Overly permissive GITHUB_TOKEN permissions
- Script injection from user input

**Checklist:**
- [ ] Pin action versions: `actions/setup-node@v3` (not @latest)
- [ ] Limit GITHUB_TOKEN permissions: `permissions: { contents: read }`
- [ ] Use secrets for sensitive data: `${{ secrets.API_KEY }}`
- [ ] Escape user input in scripts: `${{ inputs.message | quote }}`

---

## Medium/Low Impact

### Regex DoS

Catastrophic backtracking in regex can cause denial of service.

**Incorrect:**
```javascript
const regex = /^(a+)+$/;  // Quadratic backtracking
if (regex.test(userInput)) {}  // Hangs on a...aaX
```

**Correct:**
```javascript
const regex = /^a+$/;  // No nested quantifiers
if (regex.test(userInput)) {}
```

---

## Summary

- **Always parameterize queries** (SQL, command execution)
- **Always escape output** (HTML, JavaScript, URLs)
- **Never eval() user input** or deserialize untrusted data
- **Never hardcode secrets** — use environment variables
- **Always use HTTPS** with certificate validation
- **Always validate file paths** and URLs
- **Use secure defaults:** secure cookies, rate limiting, CORS allowlists

For more detailed examples by language, see the full `code-security` rules directory.
