{ stdenv
, fetchzip
, autoPatchelfHook
, gtk3
, glib
, cairo
, pango
, gdk-pixbuf
, # X11 and System libs
  xorg
, libxkbcommon
, fontconfig
, libpng
, zlib
, curl
, pigpio
, wrapGAppsHook3
}:

stdenv.mkDerivation {
  name = "rocrail";

  src = fetchzip {
    url = "https://www.rocrail.online/rocrail-snapshot/Rocrail-PiOS11-ARM64.zip";
    hash = "sha256-ALbKw4SmL3oLrICuHUVWuFZAP4YYoFXutuPCUBhWu8Q=";
    stripRoot = false;
  };

  strictDeps = true;

  nativeBuildInputs = [
    autoPatchelfHook
    wrapGAppsHook3
  ];
  buildInputs = [
    stdenv.cc.cc.lib
    gtk3
    glib
    cairo
    pango
    gdk-pixbuf

    # X11 and System libs
    xorg.libX11
    xorg.libSM
    libxkbcommon
    fontconfig
    libpng
    zlib
    curl

    # Specialized Raspberry Pi hardware lib
    pigpio
  ];

  autoPatchelfIgnoreNotFound = false;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin $out/lib $out/plugins

    # 1. Copy everything to bin first
    cp bin/* $out/bin/

    # 2. MOVE the .so files to a temporary 'plugins' folder
    # so autoPatchelfHook doesn't add an interpreter to them.
    mv $out/bin/*.so $out/plugins/

    # 3. Create our pigpio shim
    ln -s ${pigpio}/lib/libpigpio.so $out/lib/libpigpio.so.1

    runHook postInstall
  '';

  postFixup = ''
    # 4. Move the .so files BACK to bin now that patching is done
    mv $out/plugins/*.so $out/bin/
    rmdir $out/plugins

    # 5. Wrap the main binary
    wrapProgram $out/bin/rocrail \
      --add-flags "-l $out/bin"
  '';

  meta = {
    description = "Model Railroad Control System";
    homepage = "https://wiki.rocrail.net";
    platforms = [ "aarch64-linux" ];
  };
}
