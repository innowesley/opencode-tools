# Fix: `install_kilo` `stripJsonc` shell-escaping bug

## Problem
`plan-it install kilo` fails with `SyntaxError: Invalid or unexpected token` in the inline `node -e` JavaScript on line 706.

**Root cause**: Two escaping errors in the `stripJsonc` function inside the `install_kilo` section's `node -e "..."` block:

1. `'\\'` should be `'\\\\'` — shell `"..."` converts `\\` → `\`, so JS receives `'\''` (matching `'`), not `'\\'` (matching `\`).
2. `"'"` should be `\"'\"` — the unescaped `"` closes the outer bash `"..."` string prematurely, mangling the JS.

The `uninstall_kilo` section (line 868) already has the correct escaping.

## Fix
Replace line 706's broken `stripJsonc` with the correct version from line 868:

**Line 706 (before):**
```
function stripJsonc(t){let out='',i=0,s=!1,c='';for(;i<t.length;i++){const ch=t[i];if(s){out+=ch;if(ch==='\\'){i++;out+=t[i];continue}if(ch===c)s=!1;continue}if(ch==='"'||ch==="'"){s=!0;c=ch;out+=ch;continue}if(ch==='/'&&t[i+1]==='/'){while(i<t.length&&t[i]!=='\n')i++;continue}if(ch==='/'&&t[i+1]==='*'){i+=2;while(i<t.length-1&&!(t[i]==='*'&&t[i+1]==='/'))i++;i+=2;continue}out+=ch}return out}
```

**Line 706 (after) — match line 868's escaping:**
```
function stripJsonc(t){let out='',i=0,s=!1,c='';for(;i<t.length;i++){const ch=t[i];if(s){out+=ch;if(ch==='\\\\'){i++;out+=t[i];continue}if(ch===c)s=!1;continue}if(ch==='"'||ch===\"'\"){s=!0;c=ch;out+=ch;continue}if(ch==='/'&&t[i+1]==='/'){while(i<t.length&&t[i]!=='\n')i++;continue}if(ch==='/'&&t[i+1]==='*'){i+=2;while(i<t.length-1&&!(t[i]==='*'&&t[i+1]==='/'))i++;i+=2;continue}out+=ch}return out}
```

## Verification
- `bash -n plan-it` (syntax check unaffected by string content)
- Run `curl -fsSL https://raw.githubusercontent.com/innowesley/opencode-tools/main/plan-it | bash -s install kilo` to verify
- Run `curl ... install opencode` to ensure no regression
