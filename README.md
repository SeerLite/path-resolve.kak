# relapath.kak
Non-dereferencing directory structure tracker plugin for the [Kakoune](https://kakoune.org) code editor.
```
[~/dir/dir/symlink/dir] ../../dir/dir/symlink/symlink.txt [+] 1 sel - client0@[413612]
```

relapath.kak provides alternative wrappers for the `:change-directory`, `:edit[!]` and even `rename-buffer` commands and exposes `buffile` and `bufname` options as non-dereferencing variants to their builtin `%val` values.

Additionally, the options `cwd` and `pretty_cwd` exist for your scripting/modeline needs.
They're pretty much what you can imagine: `/home/you/projects` vs `~/projects`. See [Configuration/Modeline](#modeline).

You can use `%opt{bufname}` and `%opt{buffile}` in places where you'd use the builtin `%val` values.

**Note:** Options aren't set until the first client has connected to the server (i.e. after `kakrc` is sourced) so if you want to use them at startup you should do so inside a `ClientCreate` hook:
```kak
hook -once ClientCreate .* %{
    # ...
}
```
**Warning:** Changing any of the plugin's options manually can mess up its functionality. Prefer using them as read-only values.

## Installation
[plug.kak](https://github.com/andreyorst/plug.kak):
```kak
plug "https://github.com/SeerLite/relapath.kak" demand relapath %{
    alias global cd relapath-change-directory
    alias global e relapath-edit
    alias global e! relapath-edit-bang

    # Necessary if you use change-directory/edit[!]/rename-buffer elsewhere (like other plugins)
    alias global change-directory relapath-change-directory
    alias global edit relapath-edit
    alias global edit! relapath-edit-bang
    alias global rename-buffer relapath-rename-buffer
}
```
or clone the repo into `autoload/` and require+configure manually in `kakrc`:
```kak
require-module relapath
alias global cd relapath-change-directory
alias global e relapath-edit
alias global e! relapath-edit-bang

# Necessary if you use change-directory/edit[!]/rename-buffer elsewhere (like other plugins)
alias global change-directory relapath-change-directory
alias global edit relapath-edit
alias global edit! relapath-edit-bang
alias global rename-buffer relapath-rename-buffer
```
**Note:** With the above, the builtin `change-directory`, `edit[!]` and `rename-buffer` commands are still available as `relapath-originalcmd-change-directory`, `relapath-originalcmd-edit[-bang]` and `relapath-originalcmd-rename-buffer`, respectively.
You can skip aliasing the long versions and alias only the short ones, but if you or other plugins use those commands elsewhere, relapath.kak won't be able to use their arguments.

This should be good enough to work inside Kakoune. But you may also want to [set up the modeline](#modeline) or [avoid dereferencing the file path when passed from the command line](#dont-dereference-file-path-when-passed-from-the-command-line).

## Configuration
### Modeline
relapath.kak provides the `relapath-modelinefmt` command which replaces occurrences of `%val{buffile}` and `%val{bufname}` in the `modelinefmt` with relapath.kak's option variants.
```kak
relapath-modeline-fmt-replace global
```
The `pretty_cwd` option is also a good candidate to place in the modeline if you want to know in what directory you're in.
```kak
set-option global modelinefmt "[%%opt{pretty_cwd}] %opt{modelinefmt}"
# or
set-option global modelinefmt "%%opt{pretty_cwd} %opt{modelinefmt}"
```
### Don't dereference file path when passed from the command line
When the file you want to edit is (inside) a symlink and you pass it as an argument for `kak`, Kakoune will open the file directly and it'll be too late for relapath.kak to do anything.

```sh
kak .config/symlink/file.txt
```

As a workaround, we can setup a wrapper for `kak` and use that instead of the real `kak` binary:
```sh
#!/bin/sh

export KAKOUNE_RELAPATH_KAK_ARGS_B64

for arg in "$@"; do
    KAKOUNE_RELAPATH_KAK_ARGS_B64="${KAKOUNE_RELAPATH_KAK_ARGS_B64}${sep}$(printf '%s' "$arg" | base64)"
    sep=" "
done

exec kak "$@"
```
relapath.kak will scan the encoded arguments in `$KAKOUNE_RELAPATH_KAK_ARGS_B64` and try to match the file you're editing.

**Note:** I'm using Base64 as it was the safest and easiest way I found to escape the arguments. Other solutions required meticulous parsing or the use of `eval`.
`base64` should be completely unnoticeable and cause no visible delay when starting Kakoune. Feel free to inform me if you know of a better way to pass these arguments to relapath.kak ;)

Put the above in a script in your `$PATH` and you should be good to go!
Just make sure it's called something different than `kak` to avoid a recursive exec. I personally call mine `k`.

As an alternative, you can set it up as a function in `.bashrc`/`.zshrc`:
```sh
kak() {
    export KAKOUNE_RELAPATH_KAK_ARGS_B64

    for arg in "$@"; do
        KAKOUNE_RELAPATH_KAK_ARGS_B64="${KAKOUNE_RELAPATH_KAK_ARGS_B64}${sep}$(printf '%s' "$arg" | base64)"
        sep=" "
    done

    command kak "$@"

    unset KAKOUNE_RELAPATH_KAK_ARGS_B64
}
```

Using `command kak` makes sure the `kak` in `$PATH` gets called instead of the function calling itself recursively.
You can use just `kak` if you name your function something else, like `k`.

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
