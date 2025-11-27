# Zsh Startup Performance Analysis

**Date:** November 27, 2025
**Goal:** Optimize zsh shell startup time for near-instant responsiveness

---

## Executive Summary

### Current Performance
- **Startup Time:** 100.1ms ± 4.0ms (mean from 30 runs)
- **User Time:** 53.7ms
- **System Time:** 33.6ms
- **Range:** 96.2ms - 113.7ms

### Optimization Progress
| Stage | Startup Time | Improvement |
|-------|--------------|-------------|
| **Initial** | ~150ms | Baseline |
| **After brew prefix cache** | ~104ms | 31% faster |
| **After compinit optimization** | ~100ms | 33% faster |
| **After vcs_info removal** | ~100ms | Same startup, instant prompt |
| **Target** | <50ms | 70% faster |

---

## Detailed Benchmark Results

### 1. Overall Startup Cost

```
Command: zsh -i -c exit
Time (mean ± σ):     100.1 ms ±   4.0 ms
Range (min … max):    96.2 ms … 113.7 ms
Runs: 30
```

**Breakdown:**
- Bare zsh: 1.8ms
- .zshrc loading: 86.4ms
- Interactive mode overhead: ~12ms

### 2. Component Cost Analysis

Individual component overhead (measured with hyperfine):

| Component | Time | Relative | Impact |
|-----------|------|----------|--------|
| Baseline (minimal config) | 23.8ms | 1.00x | - |
| + try.rb eval | 69.6ms | 2.93x | **+45.8ms** 🔴 |
| + fnm env | 23.8ms base | - | ~23.8ms 🟡 |
| + Syntax highlighting | 30.4ms | 1.28x | **+6.6ms** 🟡 |
| + compinit -C | 28.6ms | 1.20x | **+4.8ms** ✅ |
| + zoxide init | 25.9ms | 1.09x | **+2.1ms** 🟢 |
| + autosuggestions | 26.0ms | 1.09x | **+2.2ms** 🟢 |
| + FZF | 25.3ms | 1.06x | **+1.1ms** 🟢 |

**Legend:**
- 🔴 Critical bottleneck (>20ms)
- 🟡 Significant impact (5-20ms)
- ✅ Optimized already
- 🟢 Minor impact (<3ms)

### 3. Full Component Benchmark Table

```markdown
| Command | Mean [ms] | Min [ms] | Max [ms] | Relative |
|:---|---:|---:|---:|---:|
| `zsh -c "source /tmp/minimal.zsh"` | 23.8 ± 0.5 | 22.6 | 25.4 | 1.00 |
| `... + compinit -C` | 28.6 ± 1.4 | 26.4 | 38.6 | 1.20 ± 0.06 |
| `... + zoxide init` | 25.9 ± 0.5 | 25.0 | 27.6 | 1.09 ± 0.03 |
| `... + syntax-highlighting` | 30.4 ± 1.4 | 28.5 | 39.1 | 1.28 ± 0.06 |
| `... + autosuggestions` | 26.0 ± 1.0 | 24.1 | 30.5 | 1.09 ± 0.05 |
```

### 4. Interactive vs Non-Interactive

```markdown
| Command | Mean [ms] | Relative |
|:---|---:|---:|
| `zsh -c "HOMEBREW_PREFIX=/opt/homebrew; source ~/.zshrc"` | 88.4 ± 2.3 | 1.00 |
| `zsh -i -c exit` | 102.0 ± 3.1 | 1.15 ± 0.05 |
```

**Finding:** Interactive mode adds ~13.6ms overhead (cannot be optimized)

---

## Zprof Analysis (Function-Level Profiling)

### Before Optimization (155ms total)

| Function | Time | % | Calls | Issue |
|----------|------|---|-------|-------|
| compinit | 155.62ms | 98.05% | 1 | No caching |
| ├─ compdump | 47.61ms | 30.00% | 1 | Writing cache |
| ├─ compdef | 45.81ms | 28.86% | 797 | Many completions |
| └─ compaudit | 14.23ms | 8.96% | 2 | Security checks |

### After Optimization (5ms total)

| Function | Time | % | Calls | Status |
|----------|------|---|-------|--------|
| syntax highlighting | 2.39ms | 47.94% | 1 | Can lazy-load |
| compinit | 2.19ms | 43.98% | 1 | ✅ Optimized |
| add-zsh-hook | 0.11ms | 2.21% | 4 | Minor |
| autosuggestions | 0.07ms | 1.50% | 1 | Minor |

**Note:** zprof only shows ~5ms because it doesn't capture:
- `eval` commands (fnm, zoxide, try.rb)
- File sourcing overhead
- Shell initialization

---

## Critical Bottlenecks Identified

### 1. Ruby try.rb Evaluation ⚠️ CRITICAL
**Cost:** 45.4ms (44% of total startup time)

```zsh
# Current (line 104-106):
if [[ -f "$HOME/.local/try.rb" ]]; then
  eval "$(ruby ~/.local/try.rb init ~/src/tries)"
fi
```

**Impact:** Starting Ruby interpreter and evaluating output is extremely expensive

**Solution:** Lazy-load with function wrapper
```zsh
try() {
  if [ -z "$TRY_LOADED" ]; then
    eval "$(ruby ~/.local/try.rb init ~/src/tries)"
    export TRY_LOADED=1
  fi
  command try "$@"
}
```
**Savings:** ~45ms → startup would be ~55ms

### 2. FNM Environment Initialization
**Cost:** ~23.8ms (23% of total startup time)

```zsh
# Current (line 63):
eval "$(fnm env --use-on-cd)"
```

**Impact:** Evaluating fnm shell integration on every startup

**Solution:** Lazy-load node/npm/npx commands
```zsh
fnm() {
  unfunction fnm node npm npx
  eval "$(command fnm env --use-on-cd)"
  fnm "$@"
}
```
**Savings:** ~24ms → startup would be ~76ms (or ~31ms combined with try.rb)

### 3. Syntax Highlighting
**Cost:** 6.6ms (6% of total)

**Solution:** Load after first prompt renders (async)
**Savings:** ~7ms

### 4. vcs_info (Git Branch Display)
**Cost:** 43ms per prompt render (not startup, but perceived lag)

```zsh
# Was running on every prompt:
precmd() { vcs_info }
```

**Status:** ✅ **FIXED** - Removed git branch display completely
**Impact:** Eliminated 43ms delay before prompt appears

---

## Optimizations Implemented

### ✅ 1. Cache Homebrew Prefix
**Savings:** ~46ms

```zsh
# Before: 3 calls to $(brew --prefix) = ~150ms
# After: 1 call cached in variable
HOMEBREW_PREFIX="$(brew --prefix)"
```

### ✅ 2. Optimize Compinit Caching
**Savings:** ~50ms (from 155ms → 2ms)

```zsh
# Date-based cache check (once per day)
if [ "$(date +'%j')" != "$(stat -f '%Sm' -t '%j' ~/.zcompdump 2>/dev/null)" ]; then
  compinit
else
  compinit -C  # Skip security checks
fi

# Compile dump file in background
{
  zcompdump="${ZDOTDIR:-$HOME}/.zcompdump"
  if [[ -s "$zcompdump" && (! -s "${zcompdump}.zwc" || "$zcompdump" -nt "${zcompdump}.zwc") ]]; then
    zcompile "$zcompdump"
  fi
} &!
```

### ✅ 3. Remove vcs_info (Git Branch)
**Impact:** Instant prompt rendering (was 43ms delay)

```zsh
# Before:
autoload -Uz vcs_info
precmd() { vcs_info }
PROMPT='... ${vcs_info_msg_0_} ...'

# After:
precmd() { printf '\e[2 q' }
PROMPT='%(?.%F{green}✓%f.%F{red}✗%f) %F{green}%n@%m%f %F{blue}%40<...<%~%<<%f
%F{red}❯%f '
```

---

## Recommended Next Steps

### Priority 1: Lazy-load try.rb (CRITICAL)
- **Expected savings:** ~45ms
- **Target startup:** ~55ms
- **Complexity:** Low
- **Risk:** Low (only loads when `try` command is used)

### Priority 2: Lazy-load fnm
- **Expected savings:** ~24ms
- **Target startup:** ~76ms (or ~31ms if combined with try.rb)
- **Complexity:** Medium (need to wrap node/npm/npx/fnm)
- **Risk:** Low

### Priority 3: Lazy-load syntax highlighting
- **Expected savings:** ~7ms
- **Target startup:** ~93ms
- **Complexity:** Medium (async loading)
- **Risk:** Medium (brief period without highlighting)

### Combined Impact
Implementing Priority 1 + 2 would achieve:
- **Startup time:** ~31ms (from 100ms)
- **Improvement:** 69% faster
- **User experience:** Near-instant shell

---

## Configuration Files

### Current Structure
```
zsh/
├── .zshrc (main config)
└── .config/zsh/
    ├── visual-enhancements.zsh
    └── aliases.zsh
```

### .zshrc Component Load Order
1. Environment variables (+ HOMEBREW_PREFIX cache)
2. History configuration
3. Prompt setup
4. FNM initialization (23.8ms)
5. Completion system (4.8ms, optimized)
6. FZF integration (1.1ms)
7. Zoxide initialization (2.1ms)
8. Autosuggestions (2.2ms)
9. try.rb initialization (45.4ms) ⚠️
10. Local env files
11. Config file sourcing (visual-enhancements.zsh, aliases.zsh)
    - Syntax highlighting (6.6ms)

---

## Benchmarking Methodology

### Tools Used
- **hyperfine:** Statistical benchmarking with warmup runs
- **zprof:** Zsh function-level profiling
- **time:** Basic timing measurements

### Commands
```bash
# Overall startup time
hyperfine --warmup 3 'zsh -i -c exit'

# Component isolation
hyperfine 'zsh -c "source /tmp/minimal.zsh"' \
          'zsh -c "source /tmp/minimal.zsh; component"'

# Profile functions
zsh -i -c 'zmodload zsh/zprof; source ~/.zshrc; zprof'
```

---

## References

### Best Practices Research
- [Speed up zsh compinit by only checking cache once a day](https://gist.github.com/ctechols/ca1035271ad134841284)
- [Speeding Up My ZSH Shell](https://scottspence.com/posts/speeding-up-my-zsh-shell)
- [Optimizing Zsh Init with ZProf](https://www.mikekasberg.com/blog/2025/05/29/optimizing-zsh-init-with-zprof.html)
- [Speed Matters: How I Optimized My ZSH Startup to Under 70ms](http://santacloud.dev/posts/optimizing-zsh-startup-performance/)
- [Improving zsh startup times](https://allandeutsch.com/notes/zsh-startup)
- [Improving Zsh Performance](https://www.dribin.org/dave/blog/archives/2024/01/01/zsh-performance/)
- [Faster and enjoyable ZSH](https://htr3n.github.io/2018/07/faster-zsh/)

### Key Techniques Discovered
1. Date-based compdump caching instead of file modification time
2. Using `compinit -C` to skip security checks
3. Compiling `.zcompdump` with `zcompile` for faster loading
4. Lazy-loading expensive eval commands
5. Removing git status checks from prompt for instant rendering

---

## Conclusion

Current performance is **100ms**, which is good but can be significantly improved. The primary bottleneck is **try.rb evaluation (45ms)** followed by **fnm initialization (24ms)**.

By implementing lazy-loading for these two components, startup time could be reduced to **~31ms**, achieving the target of sub-50ms startup for near-instant shell responsiveness.

The removal of `vcs_info` already eliminated the most noticeable user-facing lag (43ms delay before prompt), making the shell feel much snappier even though startup time remains similar.
