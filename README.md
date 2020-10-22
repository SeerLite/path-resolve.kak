# resolve-path.kak
Non-dereferencing directory structure tracker plugin for the [Kakoune](https://kakoune.org) code editor.
```
[~/dir/dir/symlink/dir] ../../dir/dir/symlink/symlink.txt [+] 1 sel - client0@[413612]
```

resolve-path.kak provides alternative `:change-directory` and `:edit` commands and exposes `buffile` and `bufname` options as non-dereferencing variants to their builtin `%val` values.

Additionally, the options `cwd` and `pretty_cwd` exist for your scripting/modeline needs.
They're pretty much what you can imagine: `/home/you/projects` vs `~/projects`. See [Configuration/Modeline](#modeline).

You can use `%opt{bufname}` and `%opt{buffile}` in most places where you'd use the builtin `%val` values. The only difference is that `%opt{buffile}` won't fall back to the value of `opt{bufname}` like the builtin one would.

**Note:** Options aren't set until the first client has connected to the server (i.e. after `kakrc` is sourced) so if you want to use them at startup you should do so inside a `ClientCreate` hook:
```kak
hook -once ClientCreate .* %{
	# ...
}
```
**Warning:** Changing any of the plugin's options manually can mess up its functionality. Prefer using them as read-only values.

## Installation
[alexherbo2's plug.kak](https://github.com/alexherbo2/plug.kak)
```kak
plug resolve-path "https://github.com/SeerLite/resolve-path.kak" %{
	unalias global cd change-directory
	unalias global e edit
	alias global cd resolve-path-change-directory
	alias global e resolve-path-edit
}
```
or clone the repo into `autoload/` and require+configure manually in `kakrc`:
```kak
require-module resolve-path
unalias global cd change-directory
unalias global e edit
alias global cd resolve-path-change-directory
alias global e resolve-path-edit
```
**Note:** With the above, the default `change-directory` and `edit` commands are untouched. Only the `cd` and `e` aliases are replaced with the `resolve-path-` variants.
This should be good enough to work inside Kakoune. But you may also want to [set up the modeline](#modeline) or [avoid dereferencing the file path when passed from the command line](dont-dereference-file-path-when-passed-from-the-command-line).

## Configuration
### Modeline
resolve-path.kak provides the `resolve-path-modelinefmt` command which replaces occurrences of `%val{buffile}` and `%val{bufname}` in the `modelinefmt` with resolve-path.kak's option variants.
```kak
resolve-path-modeline-fmt-replace global
```
The `pretty_cwd` option is also a good candidate to place in the modeline if you want to know in what directory you're in.
```kak
set-option global modelinefmt "[%%opt{pretty_cwd}] %opt{modelinefmt}"
# or
set-option global modelinefmt "%%opt{pretty_cwd} %opt{modelinefmt}"
```
### Don't dereference file path when passed from the command line
When the file you want to edit is (inside) a symlink and you pass it as an argument for `kak`, Kakoune will open the file directly and it'll be too late for resolve-path.kak to do anything.
```sh
kak .config/symlink/file.txt
```
As a workaround, we can setup a wrapper for `kak` and use that instead of the real `kak` binary:
```sh
#!/bin/sh

for i; do
	case "$i" in
		-c | -e | -E | -s | -p | -f | -i | -ui | -debug)
			continue 2
			;;
		-*)
			;;
		*)
			cd "$(dirname "$i")"
			file="$PWD/$(basename "$i")"
			cd "$OLDPWD"
			export KAKOUNE_RESOLVE_PATH_BUFFILE="$file" # read by resolve-path.kak
			break
			;;
	esac
done

exec /usr/bin/kak "$@" # or just 'exec kak "$@"' if your wrapper isn't called "kak".
```
Copy it to somewhere in your `$PATH` and you should be good to go!

As an alternative, you can set it up as a function in `.bashrc`/`.zshrc`:
```sh
kak() {
	for i; do
		case "$i" in
			-c | -e | -E | -s | -p | -f | -i | -ui | -debug)
				continue 2
				;;
			-*)
				;;
			*)
				cd "$(dirname "$i")"
				file="$PWD/$(basename "$i")"
				cd "$OLDPWD"
				export KAKOUNE_RESOLVE_PATH_BUFFILE="$file" # read by resolve-path.kak
				break
				;;
		esac
	done

	/usr/bin/kak "$@" # or just 'kak "$@"' if your function isn't called "kak".

	unset KAKOUNE_RESOLVE_PATH_BUFFILE
}
```

## Examples
### Cycle between file location and project root
```kak
declare-option str project_root
hook -once global ClientCreate .* %{
	set-option global project_root %opt{cwd}
}

define-command cycle-location-root %{
	evaluate-commands %sh{
		if [ "$kak_opt_cwd" != "$(dirname "$kak_opt_buffile")" ]; then
			printf 'cd "%s"' "$(dirname "$kak_opt_buffile")"
		else
			printf 'cd "%s"' "$kak_opt_project_root"
		fi
	}
}

map global normal <a-Q> ': cycle-location-root<ret>'
```

### desktopdirs
_Coming soon._

## TODO
* Non-dereferencing completions for `cd` and `e`.
* Docstrings for commands.
