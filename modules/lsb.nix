{ config, pkgs, lib, ... }:
# Based on work by matthewbauer <matthewbauer.us>
{

  options = {
    environment.lsb.enable = lib.mkOption {
      type = lib.types.bool;
      description = ''
        Enable approximate LSB binary compatibility. This allows
        binaries that run on other distros to run on NixOS.
      '';
      default = false;
    };

    environment.lsb.enableDesktop = lib.mkOption {
      type = lib.types.bool;
      description = ''
        Enable LSB Desktop extensions.
      '';
      default = true;
    };

    environment.lsb.support32Bit = lib.mkOption {
      type = lib.types.bool;
      description = ''
        Enable LSB binary compatibility.
      '';
      default = false;
    };

  };

  config =
    let
      # extracted from
      # https://github.com/NixOS/nixpkgs/blob/nixos-23.11/pkgs/games/steam/fhsenv.nix#L298

      woyCommonTargetPkgs = pkgs: with pkgs; [
        # Needed for operating system detection until
        # https://github.com/ValveSoftware/steam-for-linux/issues/5909 is resolved
        lsb-release
        # Errors in output without those
        pciutils
        # Games' dependencies
        xorg.xrandr
        which
        # Needed by gdialog, including in the steam-runtime
        perl
        # Open URLs
        xdg-utils
        iana-etc
        # Steam Play / Proton
        python3
        # Steam VR
        procps
        usbutils

        # It tries to execute xdg-user-dir and spams the log with command not founds
        xdg-user-dirs

        # electron based launchers need newer versions of these libraries than what runtime provides
        mesa
        sqlite
      ];

      woyMultiPkgs = pkgs: with pkgs; [
        # These are required by steam with proper errors
        xorg.libXcomposite
        xorg.libXtst
        xorg.libXrandr
        xorg.libXext
        xorg.libX11
        xorg.libXfixes
        libGL
        libva
        pipewire

        # steamwebhelper
        harfbuzz
        libthai
        pango

        lsof # friends options won't display "Launch Game" without it
        file # called by steam's setup.sh

        # dependencies for mesa drivers, needed inside pressure-vessel
        mesa.llvmPackages.llvm.lib
        vulkan-loader
        expat
        wayland
        xorg.libxcb
        xorg.libXdamage
        xorg.libxshmfence
        xorg.libXxf86vm
        libelf
        (lib.getLib elfutils)

        # Without these it silently fails
        xorg.libXinerama
        xorg.libXcursor
        xorg.libXrender
        xorg.libXScrnSaver
        xorg.libXi
        xorg.libSM
        xorg.libICE
        gnome2.GConf
        curlWithGnuTls
        nspr
        nss
        cups
        libcap
        SDL2
        libusb1
        dbus-glib
        gsettings-desktop-schemas
        libudev0-shim

        # Verified games requirements
        fontconfig
        freetype
        xorg.libXt
        xorg.libXmu
        libogg
        libvorbis
        SDL
        SDL2_image
        glew110
        libdrm
        libidn
        tbb
        zlib

        # SteamVR
        udev
        dbus

        # Other things from runtime
        glib
        gtk2
        bzip2
        flac
        freeglut
        libjpeg
        libpng
        libpng12
        libsamplerate
        libmikmod
        libtheora
        libtiff
        pixman
        speex
        SDL_image
        SDL_ttf
        SDL_mixer
        SDL2_ttf
        SDL2_mixer
        libappindicator-gtk2
        libdbusmenu-gtk2
        libindicator-gtk2
        libcaca
        libcanberra
        libgcrypt
        libunwind
        libvpx
        librsvg
        xorg.libXft
        libvdpau

        # required by coreutils stuff to run correctly
        # Steam ends up with LD_LIBRARY_PATH=<bunch of runtime stuff>:/usr/lib:<etc>
        # which overrides DT_RUNPATH in our binaries, so it tries to dynload the
        # very old versions of stuff from the runtime.
        # FIXME: how do we even fix this correctly
        attr
      ];

      # based on LSB 5.0
      # reference: http://refspecs.linuxfoundation.org/LSB_5.0.0/LSB-Common/LSB-Common/requirements.html#RLIBRARIES

      libsFromPkgs = pkgs:
        with pkgs;
        [
          # Core
          glibc
          gcc.cc
          zlib
          ncurses5
          linux-pam
          nspr
          nspr
          nss
          openssl

          # Runtime Languages
          libxml2
          libxslt

          # Bonus (not in LSB)
          bzip2
          curl
          expat
          libusb1
          libcap
          dbus
          libuuid

        ] ++ lib.optionals config.environment.lsb.enableDesktop [
          # desktop

          ## Graphics Libraries (X11)
          xorg.libX11
          xorg.libxcb
          xorg.libSM
          xorg.libICE
          xorg.libXt
          xorg.libXft
          xorg.libXrender
          xorg.libXext
          xorg.libXi
          xorg.libXtst
          xorg.libXcursor
          xorg.libXcomposite
          xorg.libXfixes
          xorg.libXdamage
          xorg.libXrandr
          xorg.libXScrnSaver
          xorg.libXfixes
          libxkbcommon

          ## OpenGL Libraries
          libGL
          libGLU

          ## Misc. desktop
          libpng12
          libjpeg
          fontconfig
          freetype
          libtiff
          cairo
          pango
          atk

          ## GTK+ Stack Libraries
          gtk2
          gdk-pixbuf
          glib
          dbus-glib
          at-spi2-core
          at-spi2-atk

          ## Qt Libraries
          #qt6.qt5compat

          ## Sound libraries
          alsaLib
          openal

          ## SDL
          SDL
          SDL_image
          SDL_mixer
          SDL_ttf
          SDL2
          SDL2_image
          SDL2_mixer
          SDL2_ttf

          # Imaging
          cups
          sane-backends

          # Trial Use
          libpng
          gtk3

        ]
        ++ woyCommonTargetPkgs pkgs
        ++ woyMultiPkgs pkgs
        ++ [
          fuse
          e2fsprogs
          libgpg-error
          libjack2
          libselinux
          libxcrypt-legacy
          libxcrypt
        ]
      ;

      base-libs32 = pkgs.buildEnv {
        name = "fhs-base-libs32";
        paths = map lib.getLib (libsFromPkgs pkgs.pkgsi686Linux);
        extraOutputsToInstall = [ "lib" ];
        pathsToLink = [ "/lib" ];
        ignoreCollisions = true;
      };

      base-libs64 = pkgs.buildEnv {
        name = "fhs-base-libs64";
        paths = map lib.getLib (libsFromPkgs pkgs);
        extraOutputsToInstall = [ "lib" ];
        pathsToLink = [ "/lib" "/share" ];
        ignoreCollisions = true;
        nativeBuildInputs = [ pkgs.wrapGAppsHook ];
        postBuild = ''
          echo $GSETTINGS_SCHEMAS_PATH > $out/GSETTINGS_SCHEMAS_PATH
        '';
      };
    in
    lib.mkIf config.environment.lsb.enable (lib.mkMerge [
      {
        environment.sessionVariables.LD_LIBRARY_PATH_AFTER = "${base-libs64}/lib${
          lib.optionalString config.environment.lsb.support32Bit
          ":${base-libs32}/lib"
        }";

        environment.sessionVariables.XDG_DATA_DIRS = lib.mkIf config.environment.fhs.setSchemaPaths (
          [ ":${lib.removeSuffix "\n" (builtins.readFile (base-libs64 + "/GSETTINGS_SCHEMAS_PATH"))}:" ]
        );

        environment.etc."lsb".source = pkgs.symlinkJoin {
          name = "lsb-combined";
          paths = [
            base-libs64
            base-libs32
          ];
        };

        environment.systemPackages = with pkgs;
          [
            # Core
            bc
            gnum4
            man
            lsb-release
            file
            psmisc
            ed
            gettext
            utillinux

            # Languages
            #python2
            perl
            python3

            # Misc.
            pciutils
            which
            usbutils

            # Bonus
            bzip2
          ] ++ lib.optionals config.environment.lsb.enableDesktop [
            # Desktop
            xdg_utils
            xorg.xrandr
            fontconfig
            cups

            # Imaging
            foomatic-filters
            ghostscript
          ] ++ libsFromPkgs pkgs
          ++ lib.optionals (config.environment.lsb.support32Bit)
            (libsFromPkgs pkgs.pkgsi686Linux);

        # environment.ld-linux = true;
      }
      (lib.mkIf config.environment.lsb.enableDesktop {
        hardware.opengl.enable = lib.mkDefault true;
        hardware.pulseaudio.enable = lib.mkDefault true;
      })
      (lib.mkIf (config.environment.lsb.support32Bit && config.environment.lsb.enableDesktop) {
        hardware.opengl.driSupport32Bit = lib.mkDefault true;
        hardware.pulseaudio.support32Bit = lib.mkDefault true;
      })
    ]);

}
