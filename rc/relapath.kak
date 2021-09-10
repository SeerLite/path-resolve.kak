provide-module relapath %{
	declare-option str cwd
	declare-option str pretty_cwd
	declare-option -hidden str real_buffile
	declare-option str buffile
	declare-option str bufname

	evaluate-commands -buffer '*debug*' %{
		set-option buffer buffile %val{buffile}
		set-option buffer bufname %val{bufname}
	}

	# Use parent shell $PWD
	hook -once global ClientCreate .* %{
		evaluate-commands %sh{
			cwd="$kak_client_env_PWD"
			if [ "$cwd" -ef "$PWD" ]; then
				printf 'set-option global cwd "%s";' "$cwd"
			else
				printf 'set-option global cwd "%s";' "$PWD"
			fi

			if [ -n "$KAKOUNE_RELAPATH_BUFFILE" ] && [ "$kak_buffile" = "$(realpath "$KAKOUNE_RELAPATH_BUFFILE")" ]; then
				printf 'set-option buffer real_buffile "%s"' "$KAKOUNE_RELAPATH_BUFFILE"
			fi
		}
	}

	hook global BufSetOption (real_buffile|cwd)=.* %{
		set-option buffer bufname %sh{
			if [ -n "$kak_opt_real_buffile" ]; then
				bufname="$(realpath -s --relative-to="$kak_opt_cwd" "$kak_opt_real_buffile")"
			else
				bufname="$kak_bufname"
			fi

			# Abbreviate $HOME as ~
			[ "${bufname#$HOME}" != "$bufname" ] && bufname="~/${bufname#$HOME}"

			printf '%s' "$bufname"
		}
	}

	# So that %opt{buffile} falls back to %opt{bufname} like the builtin %vals
	hook global BufSetOption real_buffile=(.*) %{
		set-option buffer buffile %sh{
			real_buffile="$kak_hook_param_capture_1"
			if [ -n "$real_buffile" ]; then
				printf '%s' "$real_buffile"
			else
				printf '%s' "$kak_opt_bufname"
			fi
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

	# TODO: dir completions?
	define-command -file-completion -params ..1 relapath-change-directory %{
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

			dirname="$(dirname "$file")"
			if [ ! -d "$dirname" ]; then
				printf 'fail "unable to cd to ""%s"""\n' "$dirname"
				exit 1
			fi

			cd "$dirname"
			printf 'set-option global cwd "%s"' "$PWD"
		}
		change-directory %opt{cwd}
	}

	define-command -file-completion -params .. relapath-edit %{
		edit %arg{@}
		evaluate-commands %sh{
			# Loop all parameters passed to :edit until finding one that matches same path as buffile
			for arg in "$@"; do
				if [ "$(realpath -- "$arg")" = "$kak_buffile" ]; then
					file="$arg"
					dirname="$(dirname "$file")"
					if [ ! -d "$dirname" ]; then
						printf 'fail "unable to cd to ""%s"""\n' "$dirname"
						exit 1
					fi

					cd "$dirname"
					file="$PWD/$(basename "$file")"

					# Remove double '/' when editing file at /
					[ "${file#//}" != "${file}" ] && file="/${file#//}"

					# printf 'hook -once global WinDisplay "%s" %%{ set-option buffer real_buffile "%s" };' "$(realpath "$file")" "$file"
					printf 'set-option buffer real_buffile "%s"' "$file"
					break
				fi
			done
		}
	}

	define-command relapath-modelinefmt-replace -params 1 %{
		set-option %arg{1} modelinefmt %sh{
			printf '%s' "$kak_opt_modelinefmt" | sed 's/%val{\(bufname\|buffile\)}/%opt{\1}/g'
		}
	}
}
