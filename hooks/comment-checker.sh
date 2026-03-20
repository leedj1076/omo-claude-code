#!/bin/bash
# Detects AI-generated filler in NEWLY WRITTEN content only.
# Uses tool input (new_string/content) to avoid false positives on pre-existing text.

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Extract only the NEW content
if [ "$TOOL_NAME" = "Edit" ]; then
  NEW_CONTENT=$(echo "$INPUT" | jq -r '.tool_input.new_string // empty')
elif [ "$TOOL_NAME" = "Write" ]; then
  NEW_CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // empty')
else
  exit 0
fi

if [ -z "$NEW_CONTENT" ]; then
  exit 0
fi

# Skip non-text files
case "$FILE_PATH" in
  *.png|*.jpg|*.gif|*.svg|*.ico|*.woff|*.ttf|*.lock|*.zip|*.tar|*.gz)
    exit 0
    ;;
esac

# Skip self — don't check hook scripts for the patterns they define
case "$FILE_PATH" in
  *comment-checker*) exit 0 ;;
esac

# Build pattern from parts to avoid self-detection
P1="robu""st and maintainabl""e"
P2="eleg""ant solut""ion"
P3="seam""lessly"
P4="leve""rag(e|ing) (the|this|our)"
P5="util""ize[sd]?"
P6="ensu""re.*modula""rity"
P7="comp""rehensive.*impleme""ntation"
P8="stre""amlined"
P9="indu""stry.stand""ard"
P10="best"".pract""ices"
P11="cutt""ing.ed""ge"
P12="state"".of.the.a""rt"
P13="faci""litate[sd]?"
P14="empo""wer"
P15="holi""stic"
P16="syner""g"
P17="para""digm"

SLOP_PATTERNS="$P1|$P2|$P3|$P4|$P5|$P6|$P7|$P8|$P9|$P10|$P11|$P12|$P13|$P14|$P15|$P16|$P17"

MATCHES=$(echo "$NEW_CONTENT" | grep -iEn "$SLOP_PATTERNS" 2>/dev/null | head -10)

if [ -n "$MATCHES" ]; then
  jq -n --arg matches "$MATCHES" --arg file "$FILE_PATH" '{
    decision: "block",
    reason: ("AI filler detected in new content written to " + $file + ":\n" + $matches + "\n\nRewrite to be specific, concise, and technical. Remove filler words.")
  }'
fi

exit 0
