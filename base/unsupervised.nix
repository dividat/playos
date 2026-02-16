{config, pkgs, lib, ... }:
let
  cfg = config.playos.unsupervised;
in
{
  options = {
    playos.unsupervised = with lib; {
      enable = mkEnableOption "Enable recovery mechanisms for unsupervised 24/7 operation";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.kernel.sysctl = {
      # reboot only after 60 s to possibly allow onsite personal to catch screenshot
      "kernel.panic" = 30;

      # Detect and recover from lockups, leaving watchdog_thresh at 10 s default
      # softlockup panic triggers if a CPU core is stuck in kernel mode for 2*watchdog_thresh
      # hardlockup panic triggers if a CPU core is unresponsive to interrupts for watchdog_thresh
      "kernel.nmi_watchdog" = 1;
      "kernel.softlockup_panic" = 1;
      "kernel.hardlockup_panic" = 1;

      # panic if a task is in TASK_UNINTERRUPTIBLE state (waiting for I/O) for more than 5 mins
      "kernel.hung_task_panic" = 1;
      "kernel.hung_task_timeout_secs" = 300;

      # EXPLICITLY DISABLED
      # An oops in a driver may leave the system operational, we avoid panicking to allow
      # enough time for systems with minor hardware/driver compatibility issues to update.
      "kernel.panic_on_oops" = 0;
      # The kernel docs recommend to enable this for scientific computing, but warns about
      # false positives from some hardware.
      "kernel.panic_on_unrecovered_nmi" = 0;
      # Probably not worth it
      "kernel.unknown_nmi_panic" = 0;
      "kernel.panic_on_io_nmi" = 0;

    };
  };
}
