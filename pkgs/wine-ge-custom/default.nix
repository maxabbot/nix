{
  lib,
  stdenvNoCC,
  fetchzip,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "wine-ge-custom";
  version = "GE-Proton8-26";

  src = fetchzip {
    url = "https://github.com/GloriousEggroll/wine-ge-custom/releases/download/${finalAttrs.version}/wine-lutris-${finalAttrs.version}-x86_64.tar.xz";
    hash = "sha256-qVqmq57tNLqWJTs83lLuzKDRRM2lC5SChpQ0NkdaDgg=";
  };

  dontConfigure = true;
  dontBuild = true;
  dontFixup = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -a "$src/." "$out/"
    runHook postInstall
  '';

  meta = {
    description = "Wine-GE custom build with VKD3D-Proton, for use with Lutris";
    homepage = "https://github.com/GloriousEggroll/wine-ge-custom";
    license = lib.licenses.lgpl21Plus;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
