#!/usr/bin/env bash
# Checks changed widget code against the rules in the rmlui skill.
#
# Scope is changed lines, because the widgets in this tree predate the doctrine
# and the skill does not ask for them to be migrated. Run --all only to triage.
#
# Rules, each a mechanical restatement of a rule stated in prose in the skill.
# The message names the document that states it; this script does not restate.
#
# The markup rules follow the markup, not the file extension. A widget that
# builds RML in a Lua string is checked the same way as a .rml file, and quote
# style is either, since generated markup often flips it. Lua line comments are
# skipped, because widgets tend to describe the anti-pattern in a comment above
# the code that avoids it. A --[[ block comment is not detected.
#
#   R1 error    markup  inline on*="widget:" handler
#   R2 error    .lua    DOM call with no rml-dom-escape marker on the line or
#                       the two above it. The window is deliberately short: the
#                       skill prescribes an adjacent marker. A marker further up
#                       a multi-line call chain will be reported.
#   R3 error    .rcss   rgba() with a fractional alpha. RmlUi parses alpha as a
#                       0-255 integer with atoi(), so 0.7 becomes 0, fully
#                       transparent.
#   R4 warning  .rcss   px where dp is meant. A warning, not an error: the
#                       shared sheet defines .border-px, so px is sometimes
#                       intended.
#   R5 error    markup  {{ inside a comment. The tokens are reserved anywhere.
#   R6 warning  markup  data-model on <body> instead of a wrapper div.
#                       Convention, not correctness, so it does not fail a run.
#
# Not checked, because a regex cannot decide them: heights on repeated rows,
# whether flex use is one of the two justified cases, hard-coded colours (the
# palette is not in this tree), whether a class group earns its place, and
# whether an rml-dom-escape reason is honest — a marker on a class toggle
# passes R2 while violating the rule it cites.
#
# There is no suppression comment. For R2 the marker is the mechanism; if any
# other rule needs an escape, the rule is wrong and belongs in this header.
#
# Usage: .github/rml-widgets/scripts/lint-widgets.sh [--all] [-h] [path ...]

set -uo pipefail

DOM_API='GetElementById|QuerySelectorAll|QuerySelector|SetClass|SetAttribute|SetProperty|inner_rml|AppendChild|RemoveChild|InsertBefore'
WIDGETS='luaui/RmlWidgets'

usage() {
	awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"
	echo
	echo "  (no args)   changed lines, against the merge-base with master"
	echo "  --all       every widget file, all lines. Expect ~1000 findings in"
	echo "              this tree today; the baseline is not a migration target."
	echo "  path ...    those files, all lines"
	exit 0
}

all=0
paths=()
for arg in "$@"; do
	case $arg in
		--all) all=1 ;;
		-h | --help) usage ;;
		-*) echo "unknown option: $arg" >&2; exit 2 ;;
		*) paths+=("$arg") ;;
	esac
done

root=$(git rev-parse --show-toplevel) || exit 2
cd "$root" || exit 2

# --- file set ----------------------------------------------------------------

base=""
if [ ${#paths[@]} -gt 0 ]; then
	files=("${paths[@]}")
elif [ "$all" = 1 ]; then
	mapfile -t files < <(git ls-files "$WIDGETS/*.lua" "$WIDGETS/*.rml" "$WIDGETS/*.rcss")
else
	base=$(git merge-base HEAD master 2>/dev/null) || base=$(git rev-parse HEAD)
	mapfile -t files < <({
		git diff --name-only "$base" -- "$WIDGETS"
		git ls-files --others --exclude-standard -- "$WIDGETS"
	} | sort -u | grep -E '\.(lua|rml|rcss)$')
fi

[ ${#files[@]} -eq 0 ] && { echo "no widget files to check"; exit 0; }

# --- changed-line filter -----------------------------------------------------

# Added line numbers for a file, one per line. Empty output means every line
# counts (explicit paths, --all, or a file git does not track yet).
changed_lines() {
	[ -n "$base" ] || return 0
	git ls-files --error-unmatch "$1" > /dev/null 2>&1 || return 0
	git diff --unified=0 "$base" -- "$1" | awk '
		/^@@/ {
			match($0, /\+[0-9]+(,[0-9]+)?/)
			spec = substr($0, RSTART + 1, RLENGTH - 1)
			split(spec, a, ",")
			start = a[1] + 0
			count = (2 in a) ? a[2] + 0 : 1
			for (i = 0; i < count; i++) print start + i
		}'
}

errors=0
warnings=0
declare -A keep
declare -A tally

report() { # file line id level message doc
	local f=$1 l=$2 id=$3 lvl=$4 msg=$5 doc=$6
	[ ${#keep[@]} -eq 0 ] || [ -n "${keep[$l]:-}" ] || return 0
	printf '%s:%s: %s %s: %s — %s\n' "$f" "$l" "$id" "$lvl" "$msg" "$doc"
	# Keyed by the words the finding itself uses, so the two read against each other.
	local key="$lvl: $msg"
	tally[$key]=$(( ${tally[$key]:-0} + 1 ))
	[ "$lvl" = error ] && errors=$((errors + 1)) || warnings=$((warnings + 1))
	return 0
}

# Set per file, to skip matches inside a line comment of the host language.
comment_re=""

scan() { # file pattern id level message doc
	local f=$1 pat=$2 ln text
	while IFS= read -r line; do
		ln=${line%%:*}
		text=${line#*:}
		[ -n "$ln" ] || continue
		[ -n "$comment_re" ] && [[ $text =~ $comment_re ]] && continue
		report "$f" "$ln" "$3" "$4" "$5" "$6"
	done < <(grep -nE "$pat" "$f" 2>/dev/null)
}

# --- rules -------------------------------------------------------------------

# RML, whether it is a .rml file or markup built in a Lua string.
markup_rules() {
	local f=$1
	scan "$f" 'on[a-z]+=[\"'\'']widget:' R1 error \
		'inline widget handler, bind it with data-event-*' 'SKILL.md § The model is king'
	scan "$f" '<!--[^>]*\{\{' R5 error \
		'{{ inside a comment, the tokens are reserved' 'data-binding.md § Gotchas'
	scan "$f" '<body[^>]*data-model' R6 warning \
		'data-model on <body>, use a wrapper div' 'file-structure.md § widget_name.rml'
}

rcss_rules() {
	local f=$1
	scan "$f" 'rgba\([0-9]+, *[0-9]+, *[0-9]+, *[0-9]*\.[0-9]+\)' R3 error \
		'fractional rgba alpha, alpha is 0-255' 'styling.md § Colors'
	scan "$f" '[0-9]+px' R4 warning \
		'px unit, size in dp' 'SKILL.md § Styling'
}

lua_rules() {
	local f=$1
	while IFS=: read -r ln _; do
		[ -n "$ln" ] && report "$f" "$ln" R2 error \
			'DOM call without rml-dom-escape marker' 'SKILL.md § The model is king'
	done < <(awk -v api="$DOM_API" '
		$0 ~ api && p1 !~ /rml-dom-escape/ && p2 !~ /rml-dom-escape/ && $0 !~ /rml-dom-escape/ {
			print NR ":"
		}
		{ p2 = p1; p1 = $0 }' "$f")
}

for f in "${files[@]}"; do
	[ -f "$f" ] || continue

	keep=()
	while read -r n; do [ -n "$n" ] && keep[$n]=1; done < <(changed_lines "$f")

	comment_re=""
	case $f in
		*.rml) markup_rules "$f" ;;
		*.rcss) rcss_rules "$f" ;;
		*.lua)
			comment_re='^[[:space:]]*--'
			markup_rules "$f"
			comment_re=""
			lua_rules "$f"
			;;
	esac
done

# --- summary -----------------------------------------------------------------

plural() { [ "$1" = 1 ] && printf '%d %s' "$1" "$2" || printf '%d %ss' "$1" "$2"; }

scope="changed lines"
[ "$all" = 1 ] && scope="all lines, ${#files[@]} files"
[ ${#paths[@]} -gt 0 ] && scope="${#files[@]} file(s), all lines"

printf '\n%s, %s — %s\n' "$(plural "$errors" error)" "$(plural "$warnings" warning)" "$scope"
for key in "${!tally[@]}"; do
	case $key in
		error:*) sev=0 ;;
		*) sev=1 ;;
	esac
	printf '%d	%d	%s
' "$sev" "${tally[$key]}" "$key"
done | sort -k1,1n -k2,2nr | while IFS=$'	' read -r _ n key; do
	printf '%6d  %s
' "$n" "$key"
done

[ "$errors" -gt 0 ] && exit 1
exit 0
