provide-module path-resolve %{
	declare-option str cwd
	declare-option str pretty_cwd
	declare-option str buffile
	declare-option str bufname
	declare-option -hidden str-list path_resolve_edit_args

	# Use parent shell $PWD
	hook -once global ClientCreate .* %{
		set-option global cwd %val{client_env_PWD}
		set-option buffer buffile %val{client_env_KAK_PATH_RESOLVE_BUFFILE}
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

			echo "$bufname"
		}
	}

	hook global GlobalSetOption cwd=(.*) %{
		set-option global pretty_cwd %sh{
			echo "$kak_hook_param_capture_1" | sed "s|^$HOME|~|"
		}
	}

	# FIXME: dir completions?
	define-command -file-completion -params ..1 path-resolve-change-directory %{
		set-option global cwd %sh{
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
			cd "$directory" || echo "fail couldn't cd into '$directory'"
			echo "$PWD"
		}
		change-directory %opt{cwd}
	}

	define-command -file-completion -params 1..10 path-resolve-edit %{
		evaluate-commands %sh{
			# Loop all paramters passed to :edit and add them to temporary window-scope
			# path_resolve_edit_args.
			# Resolve the first non-flag parameter.
			#
			# If you know of a better way to do this, let me know.
			while [ $# -gt 0 ]; do
				case "$1" in
					-*)
						printf 'set-option -add window path_resolve_edit_args "%s";' "$1"
						shift
						;;
					*)
						case "$1" in
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
						cd "$(dirname "$file")" || echo "fail couldn't cd into '$directory'"
						file="$PWD/$(basename "$file")"

						# Remove double '/' when editing file at /
						[ "${file#//}" != "${file}" ] && file="/${file#//}"

						printf 'set-option window buffile "%s";' "$file"
						printf 'set-option -add window path_resolve_edit_args "%s" %s;' "$file" "$@"
						break
						;;
				esac
			done
		}

		# Pass the current window-scope buffile to the buffer-scope of the buffer once it's created.
		hook global -once BufCreate %sh{realpath "$kak_opt_buffile"} "set-option buffer buffile %opt{buffile}"

		edit %opt{path_resolve_edit_args}
	}

	define-command path-resolve-modelinefmt-replace -params 1 %{
		set-option %arg{1} modelinefmt %sh{
			echo "$kak_opt_modelinefmt" | sed 's/%val{\(bufname\|buffile\)}/%opt{\1}/g'
		}
	}
}
