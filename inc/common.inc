#!/bin/sh
set -e -u


NEWLINE=$( printf '\n_' ); NEWLINE=${NEWLINE%_}
readonly NEWLINE


abspath( )
(
	cd "$1" && pwd
)


compDirectories( )
(
	dir1=$( abspath "$1" )
	dir2=$( abspath "$2" )
	[ "$dir1" = "$dir2" ]
)


if [ -n "$dirProj" ] && [ -d "$dirProj" ]
then
	dirProj=$( abspath "$dirProj" )
fi


error( )
{
	printf '\nError: %s!\n' "$1" >&2
	exit 1
}


if [ -n "$dirBuild" ] && compDirectories "$dirProj" "$dirBuild"
then
	error "Project cannot be built from within the project directory"
fi


syntaxError( )
{
	printf '\nSyntax Error: %s!\n' "$1" >&2
	printHelp 1
}


quote( )
{
	case $1 in
		*[\ \']*)
			printf "'%s'" "$( printf "%s" "$1" | sed "s/'/'\\\\''/g")"
		;;
		*) printf '%s' "$1"
	esac
}


# $1 - startPath - Where to start looking for flags (file or folder).
# $2 - stopDir - Stop looking once you've hit this directory.
findCompileFlags( )
(
	startPath=$1
	stopDir=$2

	flagsdir=
	if [ -d "$startPath" ]
	then
		flagsdir=$startPath
	else
		flagsdir=$( dirname "$startPath" )
	fi

	while :
	do
		if [ -f "$flagsdir/compile_flags.txt" ]
		then
			printf %s "$flagsdir/compile_flags.txt"
			return 0
		fi
		if [ "$flagsdir" = "$stopDir" ]
		then
			echo "compile_flags.txt not found for \"$startPath\"" >&2
			return 1
		fi
		flagsdir=$( dirname "$flagsdir" )
	done
)



# $1 - compareTo - File or folder whose date to use as reference
# $* - List of paths (files and folders) to search for newer files
anyFileIsNewerThan( )
(
	compareTo=$1; shift
	[ -z "${1-}" ] && return 0
	[ -n "$( find "$@" -newer "$compareTo" -type f )" ]
)


# $1 - Path to build settings file
#
# OPTIONAL:
# $2 - negative grep filter, extended regex, matching lines are removed!
parseBuildSettingsFile( )
(
	grepFilter=${2-}

	settings=
	while IFS= read -r line
	do
		[ -z "$line" ] && continue
		printf '%s' "$line"| grep -q -e '^ *#' && continue

		if [ -n "$grepFilter" ]
		then
			printf '%s' "$line"| grep -q -E -e "$grepFilter" && continue
		fi

		settings="$settings $( quote "$line" )"
	done <"$1"
	printf '%s' "$settings"
)


# $1 - srcFile - Source file to create dependency list for
#
# OPTIONAL:
# $2 - parsedFlagsFile - Flags file parsed with parseBuildSettingsFile()
# $3 - flagsFileDir - Where was the flags file found?
deplistForSourceFile( )
(
	srcFile=$1
	parsedFlagsFile=${2-}
	flagsFileDir=${3-}

	[ -n "$flagsFileDir" ] && cd "$flagsFileDir"

	if ! depList=$( eval "clang -MM $parsedFlagsFile \"$srcFile\"" )
	then
		return 1
	fi

	depList=$(
		printf '%s' "$depList" | xargs -n1 \
		| grep -v -e '^$' -e '\.o:$' \
		| sed 's/\(.*\)/"\1" /' | tr -d '\n'
	)
	[ -z "$depList" ] && return 1
	printf '%s' "$depList"
)


# $1 - objFile - Object file itself
# $2 - srcFile - Source file for the object file
#
# OPTIONAL:
# $2 - parsedFlagsFile - Flags file parsed with parseBuildSettingsFile()
# $3 - flagsFileDir - Where was the flags file found?
objectFileIsOutdated( )
(
	objFile=$1
	srcFile=$2
	parsedFlagsFile=$3
	flagsFileDir=$4

	# If the file does not exist, it's always outdated
	[ -f "$objFile" ] || return 0

	(
		[ -n "$flagsFileDir" ] && cd "$flagsFileDir"
		if ! depList=$( deplistForSourceFile "$srcFile" "$parsedFlagsFile" )
		then
			return 1
		fi

		[ -n "$depList" ] || return 1
		eval "anyFileIsNewerThan \"$objFile\" $depList"
	)
)


# $1 - Build arguments
useiOSSDK( )
{
	case $1 in
		*'-miphoneos-version-min='*) return 0
	esac
	return 1
}


# $1 - Build arguments
shouldLinkAddressSanitizer( )
{
	case $1 in
		*'-fsanitize=address'*) return 0
	esac
	return 1
}


# $1 - Path to strip from
# $2 - Prefix to strip
relativePath( )
{
	printf '%s' "${1#"$2/"}"
}