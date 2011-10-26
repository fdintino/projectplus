ProjectPlus Plugin for TextMate
###############################

`Download ProjectPlus 1.54
<https://github.com/downloads/fdintino/projectplus/ProjectPlus-1.54.tmplugin.zip>`_.

ProjectPlus is a plugin for TextMate which extends the functionality of
project-related features. It offers an enhanced project drawer with the
following features:

- A more standard project drawer compatible with OS X Lion
- SCM badges for Git, Mercurial, SVN, Svk, and Bazaar
- The ability to sort the project drawer by extension, or with folders
  on top
- An optional Workspace view that replaces TextMate's standard tab view
- Preservation of project state
- Integration with Finder color labels

Requirements
============
- Mac OS X 10.6 or higher
- TextMate 1.5.10
- An Intel mac

Screenshot
==========

.. image:: http://fdintino.github.com/projectplus/screenshot.png

Release Notes
=============

Version 1.54
------------

- Fixed bug that caused frequent crashing of TextMate
- Updated Unversioned bookmark SCM icon to match the style of the others

Version 1.53
------------

- Fixed thread safety issues in Git SCM module

Version 1.52
------------

- Git enhancements and bug fixes

  - Implemented threading for the git SCM project reload method
  - Fixed bug where file status was occasionally lost when performing a
    refresh on a large project

Version 1.51
------------

- Bugfix, seems to fix occasional TM crash when using git

Version 1.5
-----------

- Avoid horizontal scrolling in outline view
- Support for Root ahead/behind remote repository indicator for git

Note for other SCMs: to show the ahead/behind markers, binary or a file
status with ``SCMIconsStatusAhead`` or ``SCMIconsStatusBehind``. Add
overlay images to the ``Resources`` folder named
``<scmName>(Ahead|Behind).<ext>``.

Version 1.4
-----------

- Much enhanced git support:

  - Works correctly in projects containing multiple git repositories
  - Folder icons show modified status if any file inside was modified or deleted
  - Folder containing repository root are marked
  - Un-versioned Files are highlighted 

- Added icons for ``SCMIconsStatusUnversioned`` state

Note for other SCMs: to highlight the repository root, make sure the
folder returns a status that is binary OR'd with the new
``SCMIconsStatusRoot`` state. Also add an overlay image named
``<scmName>Root.<ext>`` to the ``resources`` folder and add it to the
projects resources. ``<scmName>`` is the string returned by the
``-scmName`` method, ``<ext>`` is any image extension recognized by the
system.

Version 1.3
-----------

- Updated Subversion libraries to 1.6
- Preferences for default sorting options (thanks to Lakshmi Vya)

Version 1.2
-----------

- SCM Badges would not display in some cases

  - When a project was saved in a directory other than the project root,
    badges would not display.
  - Also fixes some other less common cases which would prevent badges
    from working.

Version 1.1
-----------

- Sidebar

  - TextMate does not load plug-ins until after the application is
    finished launching, which was causing problems when launching by
    double-clicking a project file (the project would open without a
    drawer or pane). This is now handled gracefully, but projects opened
    in this way will always have the drawer as they are opened before
    ProjectPlus is loaded.

- SCM Badges

  - Added support for Mercurial, Svk and Bazaar (these should be
    considered experimental – I don’t use them so please report issues)
  - Hopefully more to come, based on demand and how easy they are to
    implement
  - Since there are now quite a few, and some of them are expensive to
    have enabled (as all except SVN use shell execution), all of the SCM
    modules are disabled by default and you must selectively enable the
    ones you want
  - Fixed a memory leak that could occur when using SVN badging
  - Misc. performance improvements and bugfixes

- General

  - Added Sparkle for automatic updates to future versions
  - Added an icon (thanks to Oliver Busch)
  - Other miscellaneous tweaks and improvements