# AI & Agents Skills

`adt-multi-agent` for orchestrating parallel agent teams. `smart-model-select` before any multi-agent or long-running job. `trigger-*` skills for Trigger.dev-based durable workflows. `adt-eval` to measure LLM output quality systematically.

---

## /adt-multi-agent

Orchestrate teams of agents — DAG execution, routing, state sharing, failure recovery.

**Capabilities:**
- **DAG execution:** Directed acyclic graph of dependent tasks
- **Routing:** Agent selection based on task type
- **State sharing:** Pass state between agents
- **Failure recovery:** Retry logic, fallback agents
- **Monitoring:** Track progress + resource usage

**When to use:** Complex multi-agent coordination

**Output:** Agent orchestration configuration

---

## /ai-sdk

Answer questions about the AI SDK and help build AI-powered features.

**Covers:**
- API client setup
- Message formatting
- Tool use + structured outputs
- Streaming responses
- Prompt caching
- Token counting

**When to use:** Claude API / AI SDK integration

**Output:** SDK guidance + code samples

---

## /adt-model-serving

Choose and configure inference servers (vLLM, TGI, Ollama) — quantization, batching, scaling.

**Servers:**
- **vLLM:** Fast inference server for LLaMA, Mistral, etc.
- **TGI:** Hugging Face Text Generation Inference
- **Ollama:** Local LLM inference (single GPU-friendly)

**Topics:**
- Quantization (GPTQ, GGUF, QLoRA)
- Batching + request queueing
- Multi-GPU scaling
- Caching strategies

**When to use:** Self-hosted LLM inference

**Output:** Model serving configuration

---

## /adt-eval

Evaluate LLM outputs systematically — benchmarks, automated metrics, human preference, regression tracking.

**Methods:**
- **Benchmarks:** Standard datasets (MMLU, HumanEval, GSM8K)
- **Automated metrics:** BERTScore, ROUGE, BLEU for text
- **Human preference:** Manual evaluation + scoring
- **Regression tracking:** Track scores across model versions

**When to use:** Measuring LLM model quality; before shipping model

**Output:** Evaluation report + scores

---

## /adt-smart-model-route

Auto-classify prompt complexity and inject model routing hints. Wired as a UserPromptSubmit hook.

**Classification:**
- **Simple:** Haiku (fast + cheap)
- **Moderate:** Sonnet (balanced)
- **Complex:** Opus (powerful)
- **Xcomplex:** Opus extended thinking

**Hint format:** Injected as system prompt classifier

**When to use:** Automatic model tier selection

**Output:** Model routing hints

---

## /smart-model-select

Pick the lightest model or reasoning tier that can do the task well.

**Decision factors:**
- Task complexity (reasoning depth needed?)
- Cost budget
- Latency requirements
- Output quality requirements

**Options:**
- **Haiku:** Mechanical tasks, fast
- **Sonnet:** General-purpose (default)
- **Opus:** Complex reasoning
- **Extended thinking:** Deep analysis

**When to use:** Before multi-agent or long-running work; uncertain model choice

**Output:** Recommended model tier + reasoning

---

## /agent-browser

Run ref-based browser automation with `agent-browser` for quick navigation and scraping.

**Capabilities:**
- Navigate to URLs
- Fill forms + submit
- Extract text + HTML
- Take screenshots
- Click elements
- Keyboard input

**When to use:** Browser automation; web scraping

**Output:** Browser interaction results

---

## /agent-box-dispatch

Submit async jobs to the agent-box Docker container for background execution.

**Use cases:**
- Long-running tasks (don't block main session)
- Parallel batch work (multiple jobs)
- Resource-intensive operations

**When to use:** Offload work to background container

**Output:** Job ID + status tracking

---

## /openclaw-opencode-control

Operate a locked-down OpenClaw gateway as a control plane over opencode-autopilot.

**Operations:**
- Submit code generation requests
- Monitor autopilot progress
- Retrieve generated code
- Control execution policies

**When to use:** Autonomous code generation via OpenClaw

**Output:** Generated code + execution log

---

## /trigger-agents

AI agent patterns with Trigger.dev — orchestration, parallelization, routing, evaluator-optimizer, human-in-the-loop.

**Patterns:**
- **Orchestration:** Sequential or DAG-based agent tasks
- **Parallelization:** Run agents in parallel
- **Routing:** Dynamic agent selection
- **Evaluator-optimizer:** Agent produces + evaluator scores + optimizer refines
- **Human-in-the-loop:** Pause for human approval

**When to use:** Durable agent workflows via Trigger.dev

**Output:** Agent workflow configuration

---

## /trigger-tasks

Build AI agents, workflows, and durable background tasks with Trigger.dev.

**Capabilities:**
- Define tasks (functions + schedule)
- Handle errors + retries
- Monitor execution
- Integrate with external services

**When to use:** Durable background tasks; scheduled workflows

**Output:** Trigger.dev task configuration + deployment

---

## /trigger-realtime

Subscribe to Trigger.dev task runs in real-time from frontend and backend.

**Features:**
- Task status updates
- Progress streaming
- Real-time logs
- WebSocket subscriptions

**When to use:** Frontend needs to display task progress

**Output:** Real-time subscription integration

---

## /trigger-setup

Set up and configure Trigger.dev in your project — trigger.config.ts, initialization, build extensions.

**Setup steps:**
1. Install `@trigger.dev/sdk`
2. Create `trigger.config.ts`
3. Define tasks
4. Deploy to Trigger.dev
5. Integrate into application

**When to use:** First-time Trigger.dev setup

**Output:** Trigger.dev configuration + ready to deploy

---

**Last updated:** 2026-06-25
