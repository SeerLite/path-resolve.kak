provide-module resolve-path %{
	declare-option str cwd
	declare-option str pretty_cwd
	declare-option str buffile
	declare-option str bufname
	declare-option -hidden str-list resolve_path_edit_args

	# Use parent shell $PWD
	hook -once global ClientCreate .* %{
		set-option global cwd %sh{
			cwd="$kak_client_env_PWD"
			if [ "$cwd" -ef "$PWD" ]; then
				printf '%s' "$cwd"
			else
				printf '%s' "$PWD"
			fi
		}
		set-option buffer buffile %val{client_env_KAKOUNE_RESOLVE_PATH_BUFFILE}
	}

	hook global BufSetOption (buffile|cwd)=.* %{
		set-option buffer bufname %sh{
			if [ -n "$kak_opt_buffile" ]; then
				bufname="$(realpath -s --relative-to="$kak_opt_cwd" "$kak_opt_buffile")"
			else
				bufname="$kak_bufname"
			fi

			# Abbreviate $HOME as ~
			[ "${bufname#$HOME}" != "$bufname" ] && bufname="~/${bufname#$HOME}"

			printf '%s' "$bufname"
		}
	}

	hook global GlobalSetOption cwd=(.*) %{
		set-option global pretty_cwd %sh{
			pretty_cwd="$kak_hook_param_capture_1"

			# Abbreviate $HOME as ~
			[ "${pretty_cwd#$HOME}" != "$pretty_cwd" ] && pretty_cwd="~${pretty_cwd#$HOME}"

			printf '%s' "$pretty_cwd"
		}
	}

	# FIXME: dir completions?
	define-command -file-completion -params ..1 resolve-path-change-directory %{
		evaluate-commands %sh{
			case "$1" in
				"")
					directory="$HOME"
					;;
				/*)
					directory="$1"
					;;
				~*)
					directory="${HOME}${1#\~}" # Expand ~ to $HOME
					;;
				*)
					directory="${kak_opt_cwd}/${1}"
					;;
			esac
			cd "$directory" || printf 'fail "unable cd into ""%s"""' "$directory"
			printf 'set-option global cwd "%s"' "$PWD"
		}
		change-directory %opt{cwd}
	}

	define-command -file-completion -params 1..10 resolve-path-edit %{
		evaluate-commands %sh{
			# Loop all paramters passed to :edit and add them to temporary window-scope
			# resolve_path_edit_args.
			# Resolve the first non-flag parameter.
			#
			# If you know of a better way to do this, let me know.
			while [ $# -gt 0 ]; do
				case "$1" in
					-*)
						printf 'set-option -add window resolve_path_edit_args "%s";' "$1"
						shift
						;;
					*)
						case "$1" in
							"")
								echo "fail"
								;;
							/*)
								file="$1"
								;;
							~*)
								file="${HOME}${1#\~}" # Expand ~ to $HOME
								;;
							*)
								file="${kak_opt_cwd}/${1}"
								;;
						esac
						shift
						cd "$(dirname "$file")" || printf 'fail "unable to cd into ""%s"""' "$(dirname "$file")"
						file="$PWD/$(basename "$file")"

						# Remove double '/' when editing file at /
						[ "${file#//}" != "${file}" ] && file="/${file#//}"

						printf 'set-option window buffile "%s";' "$file"
						printf 'set-option -add window resolve_path_edit_args "%s" %s;' "$file" "$@"
						break
						;;
				esac
			done
		}

		# Pass the current window-scope buffile to the buffer-scope of the buffer once it's created.
		hook global -once BufCreate %sh{realpath "$kak_opt_buffile"} "set-option buffer buffile %opt{buffile}"

		edit %opt{resolve_path_edit_args}
	}

	define-command resolve-path-modelinefmt-replace -params 1 %{
		set-option %arg{1} modelinefmt %sh{
			printf '%s' "$kak_opt_modelinefmt" | sed 's/%val{\(bufname\|buffile\)}/%opt{\1}/g'
		}
	}
}
