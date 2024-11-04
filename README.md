<!-- gdasset: exclude -->

Godot External Files plugin
===========================

Poor man's portable symlinks for Godot.

**Table of Contents**

- [Installation](#installation)
    - [Asset Library](#asset-library)
    - [Manual installation from GitHub](#manual-installation-from-github)
    - [(Advanced) Git clone](#advanced-git-clone)
- [Usage](#usage)
    - [Quick start](#quick-start)
    - [Syntax](#syntax)
    - [Ignoring copied files](#ignoring-copied-files)

<!-- gdasset: include -->

Godot External Files plugin is a partial substitute for symlinks, allowing referencing files outside of the project dir.

The intended use-case is a pretty specific situation, where some assets might live outside of the Godot project directory, but still need to be accessed by Godot, such as for example when porting a game from Ren'Py in parallel to the Ren'Py version still being actively worked on.

Unlike just copying the files, the referenced external files will be kept up to date, and will also not bloat your repository. And unlike symlinks, the plugin doesn't need OS support and thus can be run easily on Windows, or with version control systems like Mercurial, which do not support symlinks at all (again, due to their lack of portability).

<!-- gdasset: markdown
For full documentation, click "View files" to visit the plugin's home page.

-->
<!-- gdasset: changelog
     items: 3
     heading: Changes -->
<!-- gdasset: exclude -->

Installation
============

Asset Library
-------------
The easiest way to install the plugin is to use Godot's built-in Asset Library browser. Just click <kbd>Download</kbd>, then <kbd>Install</kbd>, making sure `Ignore asset root` is checked.

Manual installation from GitHub
-------------------------------
You can also install the plugin manually, using a zip from the GitHub repository (i.e. this page). Click the green "Code" button at the top, then select "Download ZIP". Open the zip file, then extract `addons/external_files` to your project's `addons/` directory. 

> **IMPORTANT**: Make sure you're unpacking things in the right directory, exactly as described above. Double check you see the plugin's folder in your project's `addons/`. An easy mistake to make is unpacking everything under `addons/`, so you end up with `addons/addons/external_files`. This will **NOT** work.

(Advanced) Git clone
--------------------
This is a more advanced scenario, but you can also clone the repo directly from GitHub. In that case, you will likely want to clone it to a separate location, then symlink / copy just the `external_files` directory to your project's `addons/`. Please note that you can't just clone it directly into your project, since it will conflict if you have any other plugins, as they all need to live under `addons/`. This is a general shortcoming of Godot's (lack of) plugin distribution method.

If you wish to contribute to this plugin in any way, Git clone is the recommended method.
<!-- gdasset: include -->

Usage
=====

> **IMPORTANT**: Make sure to enable the plugin under <kbd>Project</kbd> → <kbd>Project Settings...</kbd> → <kbd>Plugin</kbd> after installing!

Quick start
-----------

To use the plugin, you will need to create some files which will instruct it what files to copy whenever your Godot project is opened.

First determine what assets need to be shared. For example, let's assume your project's repository looks like this:


    my_game/
    ├── godot/
    │   ├── assets/
    │   │   └── sprites/
    │   └── project.godot
    └── renpy/
        └── game/
            └── images/
                └── sprites/
                    ├── some_sprite.png
                    ├── other_sprite.png
                    └── ...


And you'd like to have all PNG files from `renpy/game/images/sprites/` available under `godot/assets/sprites/`.

To do that, create a file called `godot/assets/sprites/.external_files`, then put the following lines in it:

    ## root: ../renpy/game/images/sprites
    syntax: glob
    
    *.png

Now reload your Godot project, or click <kbd>Project</kbd> → <kbd>Tools</kbd> → <kbd>External files</kbd> → <kbd>Re-scan</kbd>. You will see that `godot/assets/sprites/some_sprite.png` has been automatically copied and imported by Godot.

Depending on the number of files, it might take a while for all the files to be copied and imported. This is a one-time operation; the next time the project will open instantly and not copy anything, unless some files have changed.

<!-- gdasset: markdown
For full usage information and description of the syntax, click "View files" to visit the plugin's home page.
-->
<!-- gdasset: exclude -->

Syntax
------

The syntax of `.external_files` is the same as Mercurial's [`.hgignore` files](https://www.mercurial-scm.org/doc/hgignore.5.html) (except that includes are not supported). If you're familiar with Git ignore patterns, they're identical to Mercurial's "glob" syntax (see below).
Like with Mercurial, all paths should use Unix path separators (`/`), and not Windows separators (`\`).

The only mandatory element of an `.external_files` file is the _anchor_: a special comment telling the plugin what external directory to look in for files to copy. It must appear before any patterns:

```gitignore
## root: ../directory/relative/to/where/project.godot/is/located/
```

The `../` above means it's a relative path, and is interpreted relative to the directory where `project.godot` is located (_not_ relative to where `.external_files` file itself is located).

> **NOTE**: Although absolute paths are accepted, it is strongly recommended to keep them relative; otherwise the resulting files will not be portable and will likely break if you move them to a different machine (or even copy the directory they live in).

It is legal and useful to have more than one anchor per file. Every anchor applies to patterns that follow it in the file. This means it's possible to pick assets form multiple external locations and put them all in the same directory in the Godot project.

Mercurial ignores by default use regexp syntax. You can use that if you wish, but since glob syntax is typically preferred (a'la `.gitignore`), the second line will usually be a syntax directive:

```
syntax: glob
```

The lines that follow can be any number patterns and comments. Every pattern will be interpreted following the usual rules of `hgignore`, and matched against all files contained in the directories specified by the anchor(s), as well as their subdirectories, recursively. If a file's name matches, it will be copied to the location where the `.external_files` file is located, _preserving the path relative to the anchor_. That is, if the anchor is `../foo/`, and a file called `foo/bar/baz/something.png` is present, it will be copied as `bar/baz/something.png`.

For more information on the `hgignore` syntax, please refer to [official Mercurial documentation](https://www.mercurial-scm.org/doc/hgignore.5.html)

Ignoring copied files
---------------------

Since it's assumed you're using this plugin together with a version control system like Mercurial, it is important to inform it that the copied files should not be stored.

If you're using Mercurial, then it can be accomplished directly, by adding the following line in your `.hgignore`:

    subinclude:godot/assets/sprites/.external_files

(Of course, substitute the file path to whatever `.external_files` files you actually added). Make sure you're using `subinclude:` specifically; there are other include directives Mercurial supports, but those will not work properly with `.external_files`.

Otherwise, if you're using Git (or another version control system), you will need to ignore the copied files manually, using a command such as

    $ git ignore 'godot/assets/sprites/*.png'
    
> **NOTE**: Regardless of what method of ignoring you use, _all_ files matching the pattern will be ignored, even the ones that weren't copied by the plugin. It's recommended never to mix external and local files in a single location. Otherwise you're very likely to end up forgetting to track valuable files. For example, you could dedicate `godot/assets/external/` to shared external assets, and keep assets exclusive to your Godot project directly under `godot/assets/`
