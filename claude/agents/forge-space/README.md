# Forge Space Claude Subagents

> **Specialized AI agents for the Forge Space ecosystem**  
> **Domain expertise for pattern libraries, MCP services, and web applications**

---

## 🤖 **Available Subagents**

### **🔧 forge-patterns-expert**
**Specialization**: Pattern library and shared configurations
- **Repository**: forge-patterns
- **Expertise**: Pattern validation, security compliance, MCP context server
- **Use Cases**: Pattern development, security validation, ecosystem standards
- **Tools**: read, write, bash, search, edit

### **🌐 mcp-gateway-specialist**
**Specialization**: Central hub for MCP aggregation and routing
- **Repository**: forge-mcp-gateway
- **Expertise**: MCP protocol, API gateway, authentication, service integration
- **Use Cases**: API development, service integration, security implementation
- **Tools**: read, write, bash, search, edit, network

### **🎨 uiforge-mcp-architect**
**Specialization**: AI-powered UI generation and template management
- **Repository**: uiforge-mcp
- **Expertise**: UI generation, AI integration, template systems, frontend architecture
- **Use Cases**: Component generation, AI integration, template development
- **Tools**: read, write, bash, search, edit, browser

### **💻 webapp-developer**
**Specialization**: Management interface and full-stack development
- **Repository**: uiforge-webapp
- **Expertise**: React development, Supabase integration, UI/UX design
- **Use Cases**: Frontend development, database design, user experience
- **Tools**: read, write, bash, search, edit, browser

### **🎯 ecosystem-coordinator**
**Specialization**: Master coordinator for cross-repository tasks
- **Scope**: Entire Forge Space ecosystem
- **Expertise**: Agent orchestration, integration management, release coordination
- **Use Cases**: Cross-repository features, ecosystem architecture, coordinated releases
- **Tools**: read, write, bash, search, edit, network

---

## 🚀 **Getting Started**

### **Automatic Discovery**
All subagents in this directory are automatically discovered by Claude Code and available in any Forge Space project.

### **Manual Invocation**
Use the `/agents` command in Claude Code to:
- List available agents
- Select an appropriate specialist
- Provide task context and requirements

### **Automatic Delegation**
Claude Code will automatically delegate to the appropriate specialist based on:
- Task domain and complexity
- Repository context
- Required expertise and tools

---

## 🔄 **Usage Patterns**

### **Single-Specialist Tasks**
```bash
# Direct agent invocation
/agents
Select: forge-patterns-expert
Task: "Validate security compliance for new pattern"
```

### **Multi-Specialist Coordination**
```bash
# Use ecosystem coordinator for complex tasks
/agents
Select: ecosystem-coordinator
Task: "Implement cross-repository feature with UI generation and API changes"
```

### **Automatic Delegation**
```bash
# Claude will automatically choose the best agent
"Add authentication to the MCP gateway"
→ Automatically delegates to mcp-gateway-specialist

"Generate a new React component with AI integration"
→ Automatically delegates to uiforge-mcp-architect
```

---

## 🛡️ **Security & Compliance**

### **Zero-Secrets Policy**
All agents respect the Forge Space zero-secrets policy:
- **No secrets** in repository or generated code
- **Placeholder format**: `REPLACE_WITH_[TYPE]` for sensitive values
- **Security validation**: Automated scanning and validation
- **Audit logging**: Security events tracked and logged

### **Quality Standards**
Each agent maintains Forge Space quality standards:
- **Test Coverage**: ≥80% for all generated code
- **Type Safety**: Full TypeScript coverage where applicable
- **Documentation**: Comprehensive documentation for all APIs
- **Performance**: Optimized code following best practices

### **Security Validation**
- **Input Sanitization**: All inputs validated and sanitized
- **Output Filtering**: Generated code filtered for security issues
- **Dependency Scanning**: Generated dependencies validated for vulnerabilities
- **Compliance**: All code follows security compliance requirements

---

## 🔗 **Ecosystem Integration**

### **Cross-Agent Collaboration**
Agents can collaborate on complex tasks:
- **ecosystem-coordinator** orchestrates multi-agent workflows
- **Shared Context**: MCP context server provides shared knowledge
- **Integration Points**: Well-defined interfaces between domains
- **Quality Gates**: Consistent quality validation across agents

### **Repository Integration**
Each agent has deep knowledge of its target repository:
- **Code Structure**: Understanding of repository organization
- **Development Standards**: Repository-specific patterns and conventions
- **CI/CD Integration**: Knowledge of build and deployment processes
- **Testing Strategies**: Repository-specific testing approaches

### **Tool Integration**
Agents have access to relevant MCP resources:
- **Brave Search**: Web search and research capabilities
- **Exa**: Code examples and documentation lookup
- **Memory**: Knowledge graph and context storage
- **Sequential Thinking**: Complex problem-solving
- **Tavily**: Web crawling and content extraction

---

## 📋 **Best Practices**

### **Choosing the Right Agent**
- **Domain-Specific Tasks**: Choose the specialist for that domain
- **Cross-Cutting Concerns**: Use ecosystem-coordinator for multi-domain tasks
- **Simple Tasks**: Let Claude automatically delegate
- **Complex Tasks**: Manually select appropriate specialists

### **Task Preparation**
- **Clear Requirements**: Provide clear, specific task requirements
- **Context Information**: Include relevant repository and context information
- **Quality Standards**: Specify any additional quality requirements
- **Security Considerations**: Highlight any security-specific requirements

### **Collaboration Patterns**
- **Sequential Work**: Use ecosystem-coordinator for multi-step workflows
- **Parallel Tasks**: Agents can work independently on parallel tasks
- **Integration Points**: Plan integration between specialist outputs
- **Quality Validation**: Ensure final output meets all quality standards

---

## 🎯 **Success Metrics**

### **Agent Performance**
- **Task Completion**: 95%+ tasks completed successfully
- **Quality Consistency**: 95%+ consistent quality across agents
- **Security Compliance**: 100% security compliance maintained
- **User Satisfaction**: 90%+ user satisfaction with agent outputs

### **Ecosystem Impact**
- **Development Velocity**: 25%+ improvement in development speed
- **Error Reduction**: 30%+ reduction in development errors
- **Knowledge Transfer**: 50%+ improvement in team knowledge sharing
- **Consistency**: 95%+ consistency across ecosystem components

---

## 🔧 **Configuration**

### **Agent Permissions**
Each agent has appropriate tool permissions:
- **read**: File and directory reading
- **write**: File editing and creation
- **bash**: Command execution for build/test tasks
- **search**: Code and documentation search
- **edit**: Advanced file editing capabilities
- **network**: Network operations for API testing
- **browser**: Web browser automation for testing

### **Customization**
Agents can be customized by:
- **System Prompts**: Modify agent behavior and expertise
- **Tool Permissions**: Adjust available tools based on requirements
- **Domain Knowledge**: Update with latest repository changes
- **Quality Standards**: Modify quality requirements and validation

---

*This collection of specialized subagents provides comprehensive coverage of the Forge Space ecosystem, enabling efficient development, consistent quality, and expert knowledge transfer across all components.*