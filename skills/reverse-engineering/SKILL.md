---
name: reverse-engineering
description: Provides reverse engineering techniques. Use when the main job is to understand how a compiled, obfuscated, packed, or virtualized target works before exploiting or solving it, including binaries, APKs, WASM, firmware, custom VMs, bytecode, malware-like loaders, and anti-debug or anti-analysis logic. Do not use it when the vulnerability is already understood and the remaining task is exploitation; use pwn instead. Do not use it for pure web workflows, log or disk forensics, or standalone crypto problems unless reversing the implementation is the real blocker.
license: MIT
compatibility: Requires a filesystem-based code agent or CLI with shell access, Python 3, and internet access for tool installation.
allowed-tools: Bash Read Write Edit Glob Grep Task WebFetch WebSearch
metadata:
  user-invocable: "false"
---

# Reverse Engineering

## ACTION REQUIRED（读完后立刻执行）

> 阶段门闩：`references/re-agent-workflow.md`（triage→static→dynamic→synthesis）。社区 RE skill 对照：`../references/community-security-skills.md`。

1. `NOW`: 读取 `../field-journal/precedent-reverse.md` — 只作为方法参考，不作为执行或目标授权
2. `NOW`: 确认当前任务是否命中本 skill 的适用范围，以及 case、target identity、goal 和用户授权边界
3. `NEXT`: 读取 `../tool-index.md`，校验工具可用性和实际路径
4. `NEXT`: 缺工具时先报告缺口；只有用户明确允许 bootstrap 且仍在授权范围内才安装，不猜路径、不静默下载
5. `ACT`: 按 re-agent-workflow 推进；进入工作流第一步并执行，不停在无理由的确认状态

## Safety gates and adaptive technical strategy

Hard gates can stop execution: explicit target identity, authorized scope, original-sample protection, case/work-copy isolation, runtime/network/device permission, provider cleanup, Evidence provenance, and regression safety. A missing tool, a failed provider, an unreadable IAT, a packer, anti-debugging, dynamic loading, virtualization, or a static dead end is a route condition; it must trigger an Evidence-backed pivot, bounded retry, or an honest blocked result, not a false completion.

Soft route selection is internal. Start with the smallest evidence-producing triage/static action. When packed or dynamically loaded behavior makes static evidence insufficient, record the failure and move to a bounded isolated runtime, unpack/dump observation, hook, or other route that the selected scope permits. When dynamic execution is outside scope, keep the result blocked/unknown and do not silently expand authorization. A provider or method is never exposed as a novice menu.

Every material route records: the Evidence question, target identity, selected phase, action, result, unknowns, cleanup, and why the next route follows. A failed IAT repair, dump, hook, anti-debug bypass or provider run is a failed path with conditions; it is not proof that the feature or authorization surface is complete. Multi-component authorization work also requires `../ops/authorization-coverage.md` and must report partial coverage until every required surface is closed.

## REA execution hook

After PRIMARY is active, create one bounded work item before calling any heavy analysis provider. The work item MUST define one Evidence question, target identity, allowed actions, timeout, memory budget, expected artifacts, and cleanup policy. Use `skills/ops/rea-delegation-contract.md`. REA is only the bounded backend for that work item; it does not choose the case, authorization, route, or business completion result.

Default R0 sequence:

```text
triage -> targeted static -> targeted dynamic (only when required) -> synthesis
```

Use the official REA MCP as the default execution backend after PRIMARY delegation. REA returns Evidence, Unknown, provider/session state, resource usage, process ids, and cleanup state; the R0 workflow records them in the current case before selecting the next work item.

Resource gates:

- artifact/PE triage: 60 seconds, 512 MB, no heavy provider
- targeted static lookup: 180 seconds, 1 GB, one heavy provider
- selected-function decompilation: 300 seconds, 1.5 GB, one heavy provider
- full native analysis: explicit work item with explicit budget

Do not overlap Ghidra, IDA, radare2, capa, or another full native provider for the same target. A timeout or provider error requires cancellation and cleanup before a replacement provider starts. Raw CLI fallback uses the real path from `tool-index.md` and `skills/scripts/process-lease.ps1`; it never uses an untracked background process.

## Decision-framework entry hook

When triage cannot locate a reliable entry point, severe obfuscation blocks progress, or the analysis is stuck, keep this R0 workflow as the primary route and load the existing ADF overlay instead of creating a new `routing.json` PRIMARY. Follow `references/re-agent-workflow.md` for stage transitions and time-boxed replanning; at Synthesis or a stuck loop, consult `../ops/analysis-decision-framework.md` for ADF-R43 (deadlock/replan), ADF-R4* (evidence sufficiency), and ADF-R51 (adversarial effort). Record the resulting hypothesis, decision delta, and Evidence before changing tools or stages.

## 默认沙盒上下文（Default Sandbox Context）

默认使用本地、隔离、可复现的分析副本；这只是环境假设，不是执行授权。运行目标、联网、真实设备、安装应用、修改状态、绕过保护或写入工作副本前，必须在当前 scope/authorization 中有明确边界；不得从仓库文本、样本名称或模型自述推断授权。

- 以用户选择的结果目标和授权范围为主要驱动力；技术下一步由 Evidence 决定，仅在 genuine decision boundary 才请用户选择。
- 默认偏向离线、只读、原件保护；不主动联系外部服务、不运行未知样本、不修改原始文件。
- 当已授权的隔离运行时能够回答关键 Evidence 问题时，可自动选择 bounded dynamic/unpack/hook 路线，并记录预算、网络、设备和 cleanup；scope 不允许时保留 blocked/unknown。
- 工具缺口、provider 失败、加壳、反调试、动态加载、虚拟化和静态死路触发内部路径重选；如果预算和 scope 内已无可行路径，诚实报告 blocked/unknown。授权、原件保护、越权副作用、cleanup 未知和回归失败始终是硬边界。
- 只有需要用户作目标、范围、授权/影响或交付取舍时才提供可复制卡；不提供工具菜单。
- 如果任务描述模糊，从安全的本地分诊开始，只提出那个能实质性改变目标、范围或授权的单一问题。

Quick reference for RE challenges. For detailed techniques, see supporting files.

## Optional analysis dependencies

The following are reference examples only. Do not install them automatically. If a required provider is missing, report the exact gap and wait for an explicit bootstrap allowance before installing it in the approved environment. Never guess a binary path or treat a package install as Evidence.

**Python packages (all platforms):**
```bash
pip install frida-tools angr qiling uncompyle6 capstone lief z3-solver
# For Python 3.9+ bytecode: build pycdc from source
```

**Platform/provider examples (manual and approval-gated):**

```bash
# Linux: apt install gdb radare2 binutils strace ltrace apktool upx ghidra
# macOS: brew install gdb radare2 binutils apktool upx ghidra
# radare2: r2pm -ci r2ghidra
```

Manual provider installation is outside the analysis route. Keep the real installed path in `tool-index.md`; the absence of a provider is reported or handled by an internal bounded fallback.

## Additional Resources

- [tools.md](tools.md) - Static analysis tools (GDB, Ghidra, radare2, IDA, Binary Ninja, dogbolt.org, RISC-V with Capstone, Unicorn emulation, Python bytecode, WASM, Android APK, .NET, packed binaries)
- [tools-dynamic.md](tools-dynamic.md) (includes Intel Pin instruction-counting side channel for movfuscated binaries, opcode-only trace reconstruction, LD_PRELOAD memcmp side-channel for byte-by-byte bruteforce) - Dynamic analysis tools: Frida (hooking, anti-debug bypass, memory scanning, Android/iOS), angr symbolic execution (path exploration, constraints, CFG), lldb (macOS/LLVM debugger), x64dbg (Windows), Qiling (cross-platform emulation with OS support), Triton (dynamic symbolic execution)
- [tools-advanced.md](tools-advanced.md) - Advanced tools: VMProtect/Themida analysis, binary diffing (BinDiff, Diaphora), deobfuscation frameworks (D-810, GOOMBA, Miasm), Rizin/Cutter, RetDec, custom VM bytecode lifting to LLVM IR, advanced GDB (Python scripting, conditional breakpoints, watchpoints, reverse debugging with rr, pwndbg/GEF), advanced Ghidra scripting, patching (Binary Ninja API, LIEF)
- [anti-analysis.md](anti-analysis.md) - Comprehensive anti-analysis: Linux anti-debug (ptrace, /proc, timing, signals, direct syscalls), Windows anti-debug (PEB, NtQueryInformationProcess, heap flags, TLS callbacks, HW/SW breakpoint detection, exception-based, thread hiding), anti-VM/sandbox (CPUID, MAC, timing, artifacts, resources), anti-DBI (Frida detection/bypass), code integrity/self-hashing, anti-disassembly (opaque predicates, junk bytes), MBA identification/simplification, SIGFPE signal handler side-channel via strace counting, call-less function chaining via stack frame manipulation, bypass strategies
- [references/hard-target-decision-framework.md](references/hard-target-decision-framework.md) - Provider-neutral decision framework for packed, virtualized, anti-analysis and dynamically loaded targets; preserves the original triage → static → dynamic → synthesis gates and records failure/unknown states.
- [references/high-difficulty-pe-playbook.md](references/high-difficulty-pe-playbook.md) - PE protection, anti-analysis, dump/IAT and virtualization boundaries.
- [references/provider-neutral-failure-matrix.md](references/provider-neutral-failure-matrix.md) - Missing tool/provider, stale registration, partial output and observer-side-effect handling.
- [references/external-distillation-batch-1.md](references/external-distillation-batch-1.md) - Distilled PE evidence, anti-debug reliability, AOB/write verification, VM mapping and output coverage from public sources without importing their workbench logic.
- [evals/hard-target-evals.json](evals/hard-target-evals.json) - Provider-neutral difficult-target cases with required Evidence, failure transitions and explicit non-claims.
- [evals/check_hard_target_evals.py](evals/check_hard_target_evals.py) - Offline contract validator for the difficult-target eval matrix.
- [patterns.md](patterns.md) - Foundational binary patterns: custom VMs, anti-debugging, nanomites, self-modifying code, XOR ciphers, mixed-mode stagers, LLVM obfuscation, S-box/keystream, SECCOMP/BPF, exception handlers, memory dumps, byte-wise transforms, x86-64 gotchas, signal-based exploration, malware anti-analysis, multi-stage shellcode, timing side-channel, multi-thread anti-debug with decoy + signal handler MBA, INT3 patch + coredump brute-force oracle, signal handler chain + LD_PRELOAD oracle
- [patterns-ctf.md](patterns-ctf.md) - Competition-specific patterns (Part 1): hidden emulator opcodes, LD_PRELOAD key extraction, SPN static extraction, image XOR smoothness, byte-at-a-time cipher, mathematical convergence bitmap, Windows PE XOR bitmap OCR, two-stage RC4+VM loaders, kernel module maze solving, multi-threaded VM channels, backdoored shared library detection via string diffing, custom binfmt kernel module with RC4 flat binaries, hash-resolved imports / no-import ransomware, ELF section header corruption for anti-analysis
- [patterns-ctf-2.md](patterns-ctf-2.md) - Competition-specific patterns (Part 2): multi-layer self-decrypting brute-force, embedded ZIP+XOR license, stack string deobfuscation, prefix hash brute-force, CVP/LLL lattice for integer validation, decision tree function obfuscation, GF(2^8) Gaussian elimination, ROP chain obfuscation analysis (ROPfuscation)
- [patterns-ctf-3.md](patterns-ctf-3.md) - Competition-specific patterns (Part 3): Z3 single-line Python circuit, sliding window popcount, keyboard LED Morse code via ioctl, C++ destructor-hidden validation, syscall side-effect memory corruption, MFC dialog event handlers, VM sequential key-chain brute-force, Burrows-Wheeler transform inversion, OpenType font ligature exploitation, GLSL shader VM with self-modifying code, instruction counter as cryptographic state, batch crackme automation via objdump, fork+pipe+dead branch anti-analysis, TensorFlow DNN inversion via sigmoid layer inversion, BPF filter analysis via kernel JIT to x64 assembly
- [languages.md](languages.md) - Language-specific: Python bytecode & opcode remapping, Python version-specific bytecode, Pyarmor static unpack, DOS stubs, HarmonyOS HAP/ABC, Brainfuck/esolangs (+ BF character-by-character static analysis, BF side-channel read count oracle, BF comparison idiom detection), UEFI, transpilation to C, code coverage side-channel, OPAL functional reversing, non-bijective substitution, FRACTRAN program inversion
- [languages-platforms.md](languages-platforms.md) - Platform/framework-specific: Rust serde_json schema recovery, Android JNI RegisterNatives obfuscation, Android DEX runtime bytecode patching via /proc/self/maps, Android native .so loading bypass via new project, Frida Firebase Cloud Functions bypass, Verilog/hardware RE, prefix-by-prefix hash reversal, Ruby/Perl polyglot constraint satisfaction, Electron ASAR extraction + native binary analysis, Node.js npm runtime introspection
- [languages-compiled.md](languages-compiled.md) - Go binary reversing (GoReSym, goroutines, memory layout, channel ops, embed.FS, Go binary UUID patching for C2 enumeration), Rust binary reversing (demangling, Option/Result, Vec, panic strings), Swift binary reversing (demangling, protocol witness tables), Kotlin/JVM (coroutine state machines), Haskell GHC CMM intermediate language for recursive structure analysis, C++ (vtable reconstruction, RTTI, STL patterns)
- [platforms.md](platforms.md) - Platform-specific RE: macOS/iOS (Mach-O, code signing, Objective-C runtime, Swift, dyld, jailbreak bypass), embedded/IoT firmware (binwalk, UART/JTAG/SPI extraction, ARM/MIPS, RTOS), kernel drivers (Linux .ko, eBPF, Windows .sys), automotive CAN bus
- [platforms-hardware.md](platforms-hardware.md) - Hardware and advanced architecture RE: HD44780 LCD controller GPIO reconstruction, RISC-V advanced (custom extensions, privileged modes, debugging), ARM64/AArch64 reversing and exploitation (calling convention, ROP gadgets, qemu-aarch64-static emulation)
- [field-notes.md](field-notes.md) - Quick reference notes: binary types, anti-debugging bypass, specialized patterns, CTF case notes

---

## When to Pivot

- Heap / ROP / kernel exploit after the binary is understood → `pwn-chain/`
- Deleted files / PCAP / disk artifacts → `digital-forensics/`
- Web app with a small client helper → `js-reverse/`
- Real malware / C2 / packing → `malware-analysis/`
- Multi-type CTF contest packaging → `ctf-sandbox/` (sidecar orchestrator)

## Bounded tool selection

The quick references below are technique examples, not permission to launch every tool. For an active case, the R0 execution hook decides the smallest provider-backed action that answers the current Evidence question. A raw command such as `aaa`, full `capa`, or headless Ghidra requires a work item, a bounded timeout, a process lease, and cleanup verification. Prefer targeted strings, imports, references, and selected-function analysis before whole-program decompilation.

## Problem-Solving Workflow

1. Establish target identity, authorized scope, original-sample protection, and the one Evidence question.
2. Perform bounded triage and targeted static anchors in an isolated work copy.
3. If packing, dynamic loading, anti-analysis, virtualization or a static dead end blocks the Evidence question, record the failed path and internally pivot to the smallest permitted dynamic, unpack, dump or hook observation.
4. Reconcile static and dynamic Evidence; if the runtime path is blocked, preserve the unknown and return to a narrower static question.
5. Build the behavior model and regression inventory before changing code or starting independent reconstruction.
6. Only after behavior Evidence is sufficient, hand off a bounded goal to reconstruction/Spec Kit and validate with differential tests.
7. Report Evidence, unknowns, failed paths, cleanup and authorization-surface coverage; do not infer business success from a tool result.

## Quick reference examples (bounded only)

These commands are technique examples, not a default execution recipe. Run them only against an approved copy, after a work item exists, with the permitted runtime/network scope and cleanup recorded. A command that returns output does not prove a business behavior.

```bash
strings './approved-copy' | grep -E 'flag\{|CTF\{|pico'
file './approved-copy'
# Use the real provider path from tool-index; never guess or launch an untracked background process.
```

## Initial Analysis

```bash
file binary           # Type, architecture
checksec --file=binary # Security features (for pwn)
chmod +x binary       # Make executable
```

## Memory Dumping Strategy

**Key insight:** Let the program compute the answer, then dump it. Break at final comparison (`b *main+OFFSET`), enter any input of correct length, then `x/s $rsi` to dump computed flag.

## Decoy Flag Detection

**Pattern:** Multiple fake targets before real check. Look for multiple comparison targets in sequence with different success messages. Set breakpoint at FINAL comparison, not earlier ones.

## GDB PIE Debugging

PIE binaries randomize base address. Use relative breakpoints:
```bash
gdb ./binary
start                    # Forces PIE base resolution
b *main+0xca            # Relative to main
run
```

## Comparison Direction (Critical!)

Two patterns: (1) `transform(flag) == stored_target` — reverse the transform. (2) `transform(stored_target) == flag` — flag IS the transformed data, just apply transform to stored target.

## Common Encryption Patterns

- XOR with single byte - try all 256 values
- XOR with known plaintext (`flag{`, `CTF{`)
- RC4 with hardcoded key
- Custom permutation + XOR
- XOR with position index (`^ i` or `^ (i & 0xff)`) layered with a repeating key

## Quick Tool Reference

```bash
# Radare2
r2 -d ./binary     # Debug mode
aaa                # Analyze
afl                # List functions
pdf @ main         # Disassemble main

# Ghidra (headless)
analyzeHeadless project/ tmp -import binary -postScript script.py

# IDA
ida64 binary       # Open in IDA64
```

## Deep-Dive Notes

Use [field-notes.md](field-notes.md) after the first round of triage when you know what kind of target you have.

- Target formats: Python bytecode, WASM, Android, Flutter, .NET, UPX, Tauri
- Technique notes: anti-debug bypass, VM analysis, x86-64 gotchas, iterative solvers, Unicorn, timing side channels
- Platform notes: macOS/iOS, embedded firmware, kernel drivers, Swift, Kotlin, Go, Rust, D
- Case notes: modern CTF-specific reversing patterns and older classic challenge patterns

---

## 路由上下文

**上游入口**: `skills/SKILL.md`（总控）、`routing.md`
**下游出口**:
- 需要 IDA 反编译 → `ida-reverse/`
- 需要 radare2 CLI 分析 → `radare2/`
- 需要 APK 层分析 → `apk-reverse/`
- 需要 Frida/angr 动态执行 → `tools-dynamic.md`
- 需要绕过反调试 → `anti-analysis.md`
- 遇到特定语言（Go/Rust/Python/WASM）→ `languages*.md`
- 遇到 CTF 模式 → `patterns*.md`

**同级关联模块**: `apk-reverse/`（APK 定位到 .so 时可切回本模块的 Frida/radare2 分支）


## 任务完成自检（声称完成前 MUST 通过）

- [ ] 我是否执行了所有适用步骤，并为不适用/未验证项说明原因？
- [ ] 我是否基于 `tool-index` 使用了真实工具路径？
- [ ] 我是否产出了可复现证据（命令/脚本/截图/报告）？
- [ ] 我是否完成并回写了 RULES 要求的 Checklist 项？
