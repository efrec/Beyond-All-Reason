#!/usr/bin/env bash
# Checks every repo path named in the rmlui skill.
#
#   Repo — must exist here; a miss is an error.
#   Base — lives in the designer base; absent here is expected, present
#          means the base landed and the claims attached to it are due
#          for re-verification.
#
# Usage: .github/rmlui/verify.sh [-v]

set -uo pipefail

verbose=0
[ "${1:-}" = "-v" ] && verbose=1

root=$(git rev-parse --show-toplevel) || exit 2
dir=$(cd "$(dirname "$0")" && pwd)
cd "$root" || exit 2

# Recursive brace expansion: a{b,c}d -> abd acd
expand() {
	local t=$1
	if [[ $t == *'{'*'}'* ]]; then
		local pre=${t%%\{*} rest=${t#*\{} inner post
		inner=${rest%%\}*}
		post=${rest#*\}}
		local IFS=','
		local opt
		for opt in $inner; do
			expand "$pre$opt$post"
		done
	else
		printf '%s\n' "$t"
	fi
}

exists() {
	local p=$1
	[ -e "$p" ] && return 0
	[[ $p == *'*'* ]] && compgen -G "$p" > /dev/null && return 0
	return 1
}

missing_repo=()
present_base=()
absent_base=()

for md in "$dir"/*.md; do
	base_region=0
	while IFS= read -r line; do
		# Section tracking: the Base list in SKILL.md, the Base table in key-files.md
		case $line in
			'## Base'*) base_region=1 ;;
			'Base:') base_region=1 ;;
			'## '*) base_region=0 ;;
			'Repo:') base_region=0 ;;
		esac

		[[ $line == *'Base:'* ]] && base_region=1
		[[ $line == *'Repo:'* ]] && base_region=0
		line_base=$base_region

		# Path tokens, minus trailing punctuation and :line-range suffixes
		for tok in $(grep -oE 'luaui/[A-Za-z0-9_./*{},-]+' <<< "$line"); do
			[[ $tok == *widget_name* ]] && continue   # template placeholder
			tok=${tok%%:*}
			tok=${tok%.}
			tok=${tok%,}
			for p in $(expand "$tok"); do
				if exists "$p"; then
					[ "$line_base" = 1 ] && present_base+=("$p")
					[ "$verbose" = 1 ] && [ "$line_base" = 0 ] && echo "ok      $p"
				else
					if [ "$line_base" = 1 ]; then
						absent_base+=("$p")
					else
						missing_repo+=("$p  ($(basename "$md"))")
					fi
				fi
			done
		done
	done < "$md"
done

uniq_sorted() { printf '%s\n' "$@" | sort -u; }

if [ ${#absent_base[@]} -gt 0 ] && [ "$verbose" = 1 ]; then
	echo "base, absent as expected:"
	uniq_sorted "${absent_base[@]}" | sed 's/^/  /'
fi

if [ ${#present_base[@]} -gt 0 ]; then
	echo "base paths now present — re-verify the claims that cite them:"
	uniq_sorted "${present_base[@]}" | sed 's/^/  /'
fi

if [ ${#missing_repo[@]} -gt 0 ]; then
	echo "repo paths missing:"
	uniq_sorted "${missing_repo[@]}" | sed 's/^/  /'
	exit 1
fi

echo "repo paths ok"
