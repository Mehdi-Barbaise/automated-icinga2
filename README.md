# automated-icinga2
-- Author: G3ngh1s

I was tired of installing everything manually for my labs, so I automated the installation and the uninstallation of Icinga2.

/!\ Warning: This script was made for personal use, it might not suits your needs. It only automates the basic installation based on the official documentation, if you want further security settings and configuration, for example, you'll have to configure them yourself.

Tested on Debian 12 and 13. Should work on any Debian based Linux Distro using "apt" as a package manager.

Feel free to adapt it as you want.

Usage:

$ ./icinga_install.sh
Or, to uninstall and purge everything related to icinga (including databases):
$ ./icinga_uninst.sh

To be Launched as root (or with sudo).
