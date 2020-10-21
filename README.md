# path-resolve.kak
Non-dereferencing directory structure tracker plugin for the [Kakoune](https://kakoune.org) code editor.
```
[~/dir/dir/symlink/dir] ../../dir/dir/symlink/symlink.txt [+] 1 sel - client0@[413612]
```

path-resolve.kak provides alternative `:change-directory` and `:edit` commands and exposes `buffile` and `bufname` options as non-dereferencing counterparts to their builtin `%val` values.

Additionally, the options `cwd` and `pretty_cwd` exist for your scripting/modeline needs.
They're pretty much what you can imagine: `/home/you/projects` vs `~/projects`. See [Optional Configuration/Modeline](#modeline).

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
plug path-resolve %{
	unalias global cd change-directory
	unalias global e edit
	alias global cd path-resolve-change-directory
	alias global e path-resolve-edit
}
```
**Note:** With the above, the default `change-directory` and `edit` commands are untouched. Only the `cd` and `e` aliases are replaced with the `path-resolve-` variants.

## Optional configuration examples
### Modeline
path-resolve.kak provides the `path-resolve-modelinefmt` command which replaces occurrences of `%val{buffile}` and `%val{bufname}` in the `modelinefmt` with path-resolve.kak's option counterparts.
```kak
path-resolve-modeline-fmt-replace global
```
The `pretty_cwd` option is also a good candidate to place in the modeline if you want to know in what directory you're in.
```kak
set-option global modelinefmt "[%%opt{pretty_cwd}] %opt{modelinefmt}"
# or
set-option global modelinefmt "%%opt{pretty_cwd} %opt{modelinefmt}"
```

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
* Instructions for wrapper/`$KAK_PATH_RESOLVE_BUFFILE`.
