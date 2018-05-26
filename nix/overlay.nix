self: super: {
  proot = (import ./proot) super;
  apk-tools-static = (import ./apk-tools-static) super;
}
