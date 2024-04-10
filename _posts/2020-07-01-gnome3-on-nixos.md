---
layout: post
title:  "Gnome 3 on NixOS"
date:   2020-07-01 21:58:00
categories: nix nixos gnome linux dconf home-manager
github_comments_issueid: "9"
---

[NixOS](https://nixos.org/) can be configured to run any desktop environment you want and [Gnome 3](https://www.gnome.org/gnome-3/) is not an exception. However, it comes with some caveats so keep reading if you are interested in making this duo work seamlessly.

Users who enjoy a graphical environment normally like to tweak it with their own preferences as well. E.g. installing new [extensions](https://extensions.gnome.org/), changing the background image, changing the dock, etc. These are some of the tasks that [Gnome Tweaks](https://wiki.gnome.org/Apps/Tweaks) makes possible in Gnome 3.

Except, if you are in NixOS, I'm guessing you'd like to have all these tweaks declared in a configuration file so the next time you rebuild your system they are preserved, am I right?

### NixOS configuration

First of all, we want to enable Gnome 3 as our default desktop manager in our `/etc/nixos/configuration.nix` file.

{% highlight nix %}
services = {
  xserver = {
    enable = true;
    layout = "us";
    displayManager.gdm.enable = true;
    displayManager.gdm.wayland = false;
    desktopManager.gnome3.enable = true;
  };

  dbus.packages = [ pkgs.gnome3.dconf ];
  udev.packages = [ pkgs.gnome3.gnome-settings-daemon ];
};
{% endhighlight %}

[Wayland](https://wayland.freedesktop.org/) is a modern replacement for [X](https://www.x.org/wiki/). I tried it out for a while and it worked pretty well but unfortunately some functionality like screen-sharing is broken, reason why I have it disabled.

Additionally, you need `dconf` and `gnome-settings-daemon` running as a service to configure Gnome 3. This is all we need at the system level.

### Home Manager

[Home Manager](https://github.com/rycee/home-manager) is a great tool that manages all the software you want to install at the user level and all the configuration that comes with it. For example, Vim, Fish shell, Tmux, etc.

It can also manage Gnome extensions for us. Here's an example:

{% highlight nix %}
{ config, pkgs, stdenv, lib, ... }:

{
  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    # gnome3 apps
    gnome3.eog    # image viewer
    gnome3.evince # pdf reader

    # desktop look & feel
    gnome3.gnome-tweak-tool

    # extensions
    gnomeExtensions.appindicator
    gnomeExtensions.dash-to-dock
  ];
{% endhighlight %}

After running `home-manager switch`, if the build succeeded, you will see these extensions installed in Gnome Tweaks. Now we can go ahead, turn them on and configure each extension as we like. Next day we install another extension, say `gnomeExtensions.battery-status`, and again run `home-manager switch`. You will find out that all the three extensions are now installed but that you have lost the changes made to the configuration of the extensions!

As I previously mentioned, Gnome 3's configuration is managed by `dconf`. You can get a description of the configuration by running the following command:

{% highlight bash %}
$ dconf dump / > dconf.settings
{% endhighlight %}

It will have content similar to the one below.

{% highlight bash %}
[ org/gnome/desktop/peripherals/mouse ]
natural-scroll=false
speed=-0.5

[ org/gnome/desktop/peripherals/touchpad ]
tap-to-click=false
two-finger-scrolling-enabled=true

[org/gnome/desktop/input-sources]
current=uint32 0
sources=[('xkb', 'us')]
xkb-options=[' terminate:ctrl_alt_bksp ', ' lv3:ralt_switch ', ' caps:ctrl_modifier ']

[ org/gnome/desktop/screensaver ]
picture-uri=' file:///home/gvolpe/Pictures/nixos.png '
{% endhighlight %}

Home Manager provides a [dconf.settings](https://rycee.gitlab.io/home-manager/options.html#opt-dconf.settings) option we can use to configure `dconf`. However, we need to write it in Nix instead. The configuration above will look as follows:

{% highlight nix %}
{ lib, ... }:

let
  mkTuple = lib.hm.gvariant.mkTuple;
in
{
  dconf.settings = {
    "org/gnome/desktop/peripherals/mouse" = {
      "natural-scroll" = false;
      "speed" = -0.5;
    };

    "org/gnome/desktop/peripherals/touchpad" = {
      "tap-to-click" = false;
      "two-finger-scrolling-enabled" = true;
    };

    "org/gnome/desktop/input-sources" = {
      "current" = "uint32 0";
      "sources" = [ (mkTuple [ "xkb" "us" ]) ];
      "xkb-options" = [ "terminate:ctrl_alt_bksp" "lv3:ralt_switch" "caps:ctrl_modifier" ];
    };

    "org/gnome/desktop/screensaver" = {
      "picture-uri" = "file:///home/gvolpe/Pictures/nixos.png";
    };
  };
}
{% endhighlight %}

As we can see, it is a bit tedious to write all of this manually.

### dconf2nix

So I recently made available a tool called [dconf2nix](https://github.com/gvolpe/dconf2nix), which automates this conversion. It is written in a few lines of Haskell, thanks to the expressiveness of parser combinators.

Once you get the dump of the `dconf` configuration, you're just a command away from getting it in the Nix format as expected by Home Manager.

{% highlight bash %}
$ dconf2nix -i dconf.settings -o dconf.nix
{% endhighlight %}

To keep the modularity, it is a good practice to keep the `dconf.nix` as is, and import it in your `home.nix` file instead.

{% highlight nix %}
{ config, pkgs, stdenv, lib, ... }:

{
  programs.home-manager.enable = true;

  imports = [ ./dconf.nix ];
}
{% endhighlight %}

And that's it! Next time you make changes in the UI, make sure to also update the `dconf.nix` file. For instance, you may want to enable some extensions by default.

{% highlight nix %}
"org/gnome/shell" = {
  command-history = [ "gnome-tweaks" ];
  enabled-extensions = [
    "horizontal-workspaces@gnome-shell-extensions.gcampax.github.com"
    "dash-to-dock@micxgx.gmail.com"
  ];
  favorite-apps = [
    "chromium-browser.desktop"
    "spotify.desktop"
    "org.gnome.tweaks.desktop"
  ];
};
{% endhighlight %}

You can have a look at my [NixOS configuration](https://github.com/gvolpe/nix-config), where I have also configured some custom Gnome extensions and a bunch of other stuff.

Have fun with Nix! And if you happen to find any issue with [dconf2nix](https://github.com/gvolpe/dconf2nix), please report it, as it is quite new and there might be some missing edge cases.

Cheers,
Gabriel.
