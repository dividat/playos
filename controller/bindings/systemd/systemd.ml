open Lwt
open Sexplib.Std
open Systemd_interfaces

module Manager =
struct

  type t = OBus_proxy.t

  let connect () =
    let%lwt system_bus = OBus_bus.system () in
    let peer = OBus_peer.make system_bus "org.freedesktop.systemd1" in
    OBus_proxy.make peer ["org"; "freedesktop"; "systemd1"]
    |> return

  type system_state =
    | Initializing
    | Starting
    | Running
    | Degraded
    | Maintenance
    | Stopping
    | Offline
    | Unknown
  [@@deriving sexp]

  let get_system_state proxy =
    let system_state_of_string s =
      match s with
      | "initializing" -> Initializing
      | "starting" -> Starting
      | "running" -> Running
      | "degraded" -> Degraded
      | "maintenance" -> Maintenance
      | "stopping" -> Stopping
      | "offline" -> Offline
      | "unknown" -> Unknown
      | _ -> failwith (Format.sprintf "unexpected system state (%s)" s)
    in
    OBus_property.make
      Org_freedesktop_systemd1_Manager.p_SystemState proxy
    |> OBus_property.get
    >|= system_state_of_string

end

module Org_freedesktop_systemd1_Manager =
struct
  open Org_freedesktop_systemd1_Manager


  let version proxy =
    OBus_property.make p_Version proxy

  let features proxy =
    OBus_property.make p_Features proxy

  let virtualization proxy =
    OBus_property.make p_Virtualization proxy

  let architecture proxy =
    OBus_property.make p_Architecture proxy

  let tainted proxy =
    OBus_property.make p_Tainted proxy

  let firmware_timestamp proxy =
    OBus_property.make p_FirmwareTimestamp proxy

  let firmware_timestamp_monotonic proxy =
    OBus_property.make p_FirmwareTimestampMonotonic proxy

  let loader_timestamp proxy =
    OBus_property.make p_LoaderTimestamp proxy

  let loader_timestamp_monotonic proxy =
    OBus_property.make p_LoaderTimestampMonotonic proxy

  let kernel_timestamp proxy =
    OBus_property.make p_KernelTimestamp proxy

  let kernel_timestamp_monotonic proxy =
    OBus_property.make p_KernelTimestampMonotonic proxy

  let init_rdtimestamp proxy =
    OBus_property.make p_InitRDTimestamp proxy

  let init_rdtimestamp_monotonic proxy =
    OBus_property.make p_InitRDTimestampMonotonic proxy

  let userspace_timestamp proxy =
    OBus_property.make p_UserspaceTimestamp proxy

  let userspace_timestamp_monotonic proxy =
    OBus_property.make p_UserspaceTimestampMonotonic proxy

  let finish_timestamp proxy =
    OBus_property.make p_FinishTimestamp proxy

  let finish_timestamp_monotonic proxy =
    OBus_property.make p_FinishTimestampMonotonic proxy

  let security_start_timestamp proxy =
    OBus_property.make p_SecurityStartTimestamp proxy

  let security_start_timestamp_monotonic proxy =
    OBus_property.make p_SecurityStartTimestampMonotonic proxy

  let security_finish_timestamp proxy =
    OBus_property.make p_SecurityFinishTimestamp proxy

  let security_finish_timestamp_monotonic proxy =
    OBus_property.make p_SecurityFinishTimestampMonotonic proxy

  let generators_start_timestamp proxy =
    OBus_property.make p_GeneratorsStartTimestamp proxy

  let generators_start_timestamp_monotonic proxy =
    OBus_property.make p_GeneratorsStartTimestampMonotonic proxy

  let generators_finish_timestamp proxy =
    OBus_property.make p_GeneratorsFinishTimestamp proxy

  let generators_finish_timestamp_monotonic proxy =
    OBus_property.make p_GeneratorsFinishTimestampMonotonic proxy

  let units_load_start_timestamp proxy =
    OBus_property.make p_UnitsLoadStartTimestamp proxy

  let units_load_start_timestamp_monotonic proxy =
    OBus_property.make p_UnitsLoadStartTimestampMonotonic proxy

  let units_load_finish_timestamp proxy =
    OBus_property.make p_UnitsLoadFinishTimestamp proxy

  let units_load_finish_timestamp_monotonic proxy =
    OBus_property.make p_UnitsLoadFinishTimestampMonotonic proxy

  let log_level proxy =
    OBus_property.make p_LogLevel proxy

  let log_target proxy =
    OBus_property.make p_LogTarget proxy

  let nnames proxy =
    OBus_property.map_r
      (fun x -> Int32.to_int x)
      (OBus_property.make p_NNames proxy)

  let nfailed_units proxy =
    OBus_property.map_r
      (fun x -> Int32.to_int x)
      (OBus_property.make p_NFailedUnits proxy)

  let njobs proxy =
    OBus_property.map_r
      (fun x -> Int32.to_int x)
      (OBus_property.make p_NJobs proxy)

  let ninstalled_jobs proxy =
    OBus_property.map_r
      (fun x -> Int32.to_int x)
      (OBus_property.make p_NInstalledJobs proxy)

  let nfailed_jobs proxy =
    OBus_property.map_r
      (fun x -> Int32.to_int x)
      (OBus_property.make p_NFailedJobs proxy)

  let progress proxy =
    OBus_property.make p_Progress proxy

  let environment proxy =
    OBus_property.make p_Environment proxy

  let confirm_spawn proxy =
    OBus_property.make p_ConfirmSpawn proxy

  let show_status proxy =
    OBus_property.make p_ShowStatus proxy

  let unit_path proxy =
    OBus_property.make p_UnitPath proxy

  let default_standard_output proxy =
    OBus_property.make p_DefaultStandardOutput proxy

  let default_standard_error proxy =
    OBus_property.make p_DefaultStandardError proxy

  let runtime_watchdog_usec proxy =
    OBus_property.make p_RuntimeWatchdogUSec proxy

  let shutdown_watchdog_usec proxy =
    OBus_property.make p_ShutdownWatchdogUSec proxy

  let service_watchdogs proxy =
    OBus_property.make p_ServiceWatchdogs proxy

  let control_group proxy =
    OBus_property.make p_ControlGroup proxy

  let system_state proxy =
    OBus_property.make p_SystemState proxy

  let exit_code proxy =
    OBus_property.make p_ExitCode proxy

  let default_timer_accuracy_usec proxy =
    OBus_property.make p_DefaultTimerAccuracyUSec proxy

  let default_timeout_start_usec proxy =
    OBus_property.make p_DefaultTimeoutStartUSec proxy

  let default_timeout_stop_usec proxy =
    OBus_property.make p_DefaultTimeoutStopUSec proxy

  let default_restart_usec proxy =
    OBus_property.make p_DefaultRestartUSec proxy

  let default_start_limit_interval_usec proxy =
    OBus_property.make p_DefaultStartLimitIntervalUSec proxy

  let default_start_limit_burst proxy =
    OBus_property.map_r
      (fun x -> Int32.to_int x)
      (OBus_property.make p_DefaultStartLimitBurst proxy)

  let default_cpuaccounting proxy =
    OBus_property.make p_DefaultCPUAccounting proxy

  let default_block_ioaccounting proxy =
    OBus_property.make p_DefaultBlockIOAccounting proxy

  let default_memory_accounting proxy =
    OBus_property.make p_DefaultMemoryAccounting proxy

  let default_tasks_accounting proxy =
    OBus_property.make p_DefaultTasksAccounting proxy

  let default_limit_cpu proxy =
    OBus_property.make p_DefaultLimitCPU proxy

  let default_limit_cpusoft proxy =
    OBus_property.make p_DefaultLimitCPUSoft proxy

  let default_limit_fsize proxy =
    OBus_property.make p_DefaultLimitFSIZE proxy

  let default_limit_fsizesoft proxy =
    OBus_property.make p_DefaultLimitFSIZESoft proxy

  let default_limit_data proxy =
    OBus_property.make p_DefaultLimitDATA proxy

  let default_limit_datasoft proxy =
    OBus_property.make p_DefaultLimitDATASoft proxy

  let default_limit_stack proxy =
    OBus_property.make p_DefaultLimitSTACK proxy

  let default_limit_stacksoft proxy =
    OBus_property.make p_DefaultLimitSTACKSoft proxy

  let default_limit_core proxy =
    OBus_property.make p_DefaultLimitCORE proxy

  let default_limit_coresoft proxy =
    OBus_property.make p_DefaultLimitCORESoft proxy

  let default_limit_rss proxy =
    OBus_property.make p_DefaultLimitRSS proxy

  let default_limit_rsssoft proxy =
    OBus_property.make p_DefaultLimitRSSSoft proxy

  let default_limit_nofile proxy =
    OBus_property.make p_DefaultLimitNOFILE proxy

  let default_limit_nofilesoft proxy =
    OBus_property.make p_DefaultLimitNOFILESoft proxy

  let default_limit_as proxy =
    OBus_property.make p_DefaultLimitAS proxy

  let default_limit_assoft proxy =
    OBus_property.make p_DefaultLimitASSoft proxy

  let default_limit_nproc proxy =
    OBus_property.make p_DefaultLimitNPROC proxy

  let default_limit_nprocsoft proxy =
    OBus_property.make p_DefaultLimitNPROCSoft proxy

  let default_limit_memlock proxy =
    OBus_property.make p_DefaultLimitMEMLOCK proxy

  let default_limit_memlocksoft proxy =
    OBus_property.make p_DefaultLimitMEMLOCKSoft proxy

  let default_limit_locks proxy =
    OBus_property.make p_DefaultLimitLOCKS proxy

  let default_limit_lockssoft proxy =
    OBus_property.make p_DefaultLimitLOCKSSoft proxy

  let default_limit_sigpending proxy =
    OBus_property.make p_DefaultLimitSIGPENDING proxy

  let default_limit_sigpendingsoft proxy =
    OBus_property.make p_DefaultLimitSIGPENDINGSoft proxy

  let default_limit_msgqueue proxy =
    OBus_property.make p_DefaultLimitMSGQUEUE proxy

  let default_limit_msgqueuesoft proxy =
    OBus_property.make p_DefaultLimitMSGQUEUESoft proxy

  let default_limit_nice proxy =
    OBus_property.make p_DefaultLimitNICE proxy

  let default_limit_nicesoft proxy =
    OBus_property.make p_DefaultLimitNICESoft proxy

  let default_limit_rtprio proxy =
    OBus_property.make p_DefaultLimitRTPRIO proxy

  let default_limit_rtpriosoft proxy =
    OBus_property.make p_DefaultLimitRTPRIOSoft proxy

  let default_limit_rttime proxy =
    OBus_property.make p_DefaultLimitRTTIME proxy

  let default_limit_rttimesoft proxy =
    OBus_property.make p_DefaultLimitRTTIMESoft proxy

  let default_tasks_max proxy =
    OBus_property.make p_DefaultTasksMax proxy

  let timer_slack_nsec proxy =
    OBus_property.make p_TimerSlackNSec proxy

  let get_unit proxy x1 =
    let%lwt (context, x1) = OBus_method.call_with_context m_GetUnit proxy x1 in
    let x1 = OBus_proxy.make (OBus_context.sender context) x1 in
    return x1

  let get_unit_by_pid proxy x1 =
    let x1 = Int32.of_int x1 in
    let%lwt (context, x1) = OBus_method.call_with_context m_GetUnitByPID proxy x1 in
    let x1 = OBus_proxy.make (OBus_context.sender context) x1 in
    return x1

  let get_unit_by_invocation_id proxy x1 =
    let%lwt (context, x1) = OBus_method.call_with_context m_GetUnitByInvocationID proxy x1 in
    let x1 = OBus_proxy.make (OBus_context.sender context) x1 in
    return x1

  let get_unit_by_control_group proxy x1 =
    let%lwt (context, x1) = OBus_method.call_with_context m_GetUnitByControlGroup proxy x1 in
    let x1 = OBus_proxy.make (OBus_context.sender context) x1 in
    return x1

  let load_unit proxy x1 =
    let%lwt (context, x1) = OBus_method.call_with_context m_LoadUnit proxy x1 in
    let x1 = OBus_proxy.make (OBus_context.sender context) x1 in
    return x1

  let start_unit proxy x1 x2 =
    let%lwt (context, x1) = OBus_method.call_with_context m_StartUnit proxy (x1, x2) in
    let x1 = OBus_proxy.make (OBus_context.sender context) x1 in
    return x1

  let start_unit_replace proxy x1 x2 x3 =
    let%lwt (context, x1) = OBus_method.call_with_context m_StartUnitReplace proxy (x1, x2, x3) in
    let x1 = OBus_proxy.make (OBus_context.sender context) x1 in
    return x1

  let stop_unit proxy x1 x2 =
    let%lwt (context, x1) = OBus_method.call_with_context m_StopUnit proxy (x1, x2) in
    let x1 = OBus_proxy.make (OBus_context.sender context) x1 in
    return x1

  let reload_unit proxy x1 x2 =
    let%lwt (context, x1) = OBus_method.call_with_context m_ReloadUnit proxy (x1, x2) in
    let x1 = OBus_proxy.make (OBus_context.sender context) x1 in
    return x1

  let restart_unit proxy x1 x2 =
    let%lwt (context, x1) = OBus_method.call_with_context m_RestartUnit proxy (x1, x2) in
    let x1 = OBus_proxy.make (OBus_context.sender context) x1 in
    return x1

  let try_restart_unit proxy x1 x2 =
    let%lwt (context, x1) = OBus_method.call_with_context m_TryRestartUnit proxy (x1, x2) in
    let x1 = OBus_proxy.make (OBus_context.sender context) x1 in
    return x1

  let reload_or_restart_unit proxy x1 x2 =
    let%lwt (context, x1) = OBus_method.call_with_context m_ReloadOrRestartUnit proxy (x1, x2) in
    let x1 = OBus_proxy.make (OBus_context.sender context) x1 in
    return x1

  let reload_or_try_restart_unit proxy x1 x2 =
    let%lwt (context, x1) = OBus_method.call_with_context m_ReloadOrTryRestartUnit proxy (x1, x2) in
    let x1 = OBus_proxy.make (OBus_context.sender context) x1 in
    return x1

  let kill_unit proxy x1 x2 x3 =
    let x3 = Int32.of_int x3 in
    OBus_method.call m_KillUnit proxy (x1, x2, x3)

  let reset_failed_unit proxy x1 =
    OBus_method.call m_ResetFailedUnit proxy x1

  let set_unit_properties proxy x1 x2 x3 =
    OBus_method.call m_SetUnitProperties proxy (x1, x2, x3)

  let ref_unit proxy x1 =
    OBus_method.call m_RefUnit proxy x1

  let unref_unit proxy x1 =
    OBus_method.call m_UnrefUnit proxy x1

  let start_transient_unit proxy x1 x2 x3 x4 =
    let%lwt (context, x1) = OBus_method.call_with_context m_StartTransientUnit proxy (x1, x2, x3, x4) in
    let x1 = OBus_proxy.make (OBus_context.sender context) x1 in
    return x1

  let get_unit_processes proxy x1 =
    let%lwt x1 = OBus_method.call m_GetUnitProcesses proxy x1 in
    let x1 = List.map (fun (x1, x2, x3) -> (x1, Int32.to_int x2, x3)) x1 in
    return x1

  let attach_processes_to_unit proxy x1 x2 x3 =
    let x3 = List.map Int32.of_int x3 in
    OBus_method.call m_AttachProcessesToUnit proxy (x1, x2, x3)

  let get_job proxy x1 =
    let x1 = Int32.of_int x1 in
    let%lwt (context, x1) = OBus_method.call_with_context m_GetJob proxy x1 in
    let x1 = OBus_proxy.make (OBus_context.sender context) x1 in
    return x1

  let get_job_after proxy x1 =
    let x1 = Int32.of_int x1 in
    let%lwt (context, x1) = OBus_method.call_with_context m_GetJobAfter proxy x1 in
    let x1 = List.map (fun (x1, x2, x3, x4, x5, x6) -> (Int32.to_int x1, x2, x3, x4, OBus_proxy.make (OBus_context.sender context) x5, OBus_proxy.make (OBus_context.sender context) x6)) x1 in
    return x1

  let get_job_before proxy x1 =
    let x1 = Int32.of_int x1 in
    let%lwt (context, x1) = OBus_method.call_with_context m_GetJobBefore proxy x1 in
    let x1 = List.map (fun (x1, x2, x3, x4, x5, x6) -> (Int32.to_int x1, x2, x3, x4, OBus_proxy.make (OBus_context.sender context) x5, OBus_proxy.make (OBus_context.sender context) x6)) x1 in
    return x1

  let cancel_job proxy x1 =
    let x1 = Int32.of_int x1 in
    OBus_method.call m_CancelJob proxy x1

  let clear_jobs proxy =
    OBus_method.call m_ClearJobs proxy ()

  let reset_failed proxy =
    OBus_method.call m_ResetFailed proxy ()

  let list_units proxy =
    let%lwt (context, x1) = OBus_method.call_with_context m_ListUnits proxy () in
    let x1 = List.map (fun (x1, x2, x3, x4, x5, x6, x7, x8, x9, x10) -> (x1, x2, x3, x4, x5, x6, OBus_proxy.make (OBus_context.sender context) x7, Int32.to_int x8, x9, OBus_proxy.make (OBus_context.sender context) x10)) x1 in
    return x1

  let list_units_filtered proxy x1 =
    let%lwt (context, x1) = OBus_method.call_with_context m_ListUnitsFiltered proxy x1 in
    let x1 = List.map (fun (x1, x2, x3, x4, x5, x6, x7, x8, x9, x10) -> (x1, x2, x3, x4, x5, x6, OBus_proxy.make (OBus_context.sender context) x7, Int32.to_int x8, x9, OBus_proxy.make (OBus_context.sender context) x10)) x1 in
    return x1

  let list_units_by_patterns proxy x1 x2 =
    let%lwt (context, x1) = OBus_method.call_with_context m_ListUnitsByPatterns proxy (x1, x2) in
    let x1 = List.map (fun (x1, x2, x3, x4, x5, x6, x7, x8, x9, x10) -> (x1, x2, x3, x4, x5, x6, OBus_proxy.make (OBus_context.sender context) x7, Int32.to_int x8, x9, OBus_proxy.make (OBus_context.sender context) x10)) x1 in
    return x1

  let list_units_by_names proxy x1 =
    let%lwt (context, x1) = OBus_method.call_with_context m_ListUnitsByNames proxy x1 in
    let x1 = List.map (fun (x1, x2, x3, x4, x5, x6, x7, x8, x9, x10) -> (x1, x2, x3, x4, x5, x6, OBus_proxy.make (OBus_context.sender context) x7, Int32.to_int x8, x9, OBus_proxy.make (OBus_context.sender context) x10)) x1 in
    return x1

  let list_jobs proxy =
    let%lwt (context, x1) = OBus_method.call_with_context m_ListJobs proxy () in
    let x1 = List.map (fun (x1, x2, x3, x4, x5, x6) -> (Int32.to_int x1, x2, x3, x4, OBus_proxy.make (OBus_context.sender context) x5, OBus_proxy.make (OBus_context.sender context) x6)) x1 in
    return x1

  let subscribe proxy =
    OBus_method.call m_Subscribe proxy ()

  let unsubscribe proxy =
    OBus_method.call m_Unsubscribe proxy ()

  let dump proxy =
    OBus_method.call m_Dump proxy ()

  let dump_by_file_descriptor proxy =
    OBus_method.call m_DumpByFileDescriptor proxy ()

  let reload proxy =
    OBus_method.call m_Reload proxy ()

  let reexecute proxy =
    OBus_method.call m_Reexecute proxy ()

  let exit proxy =
    OBus_method.call m_Exit proxy ()

  let reboot proxy =
    OBus_method.call m_Reboot proxy ()

  let power_off proxy =
    OBus_method.call m_PowerOff proxy ()

  let halt proxy =
    OBus_method.call m_Halt proxy ()

  let kexec proxy =
    OBus_method.call m_KExec proxy ()

  let switch_root proxy x1 x2 =
    OBus_method.call m_SwitchRoot proxy (x1, x2)

  let set_environment proxy x1 =
    OBus_method.call m_SetEnvironment proxy x1

  let unset_environment proxy x1 =
    OBus_method.call m_UnsetEnvironment proxy x1

  let unset_and_set_environment proxy x1 x2 =
    OBus_method.call m_UnsetAndSetEnvironment proxy (x1, x2)

  let list_unit_files proxy =
    OBus_method.call m_ListUnitFiles proxy ()

  let list_unit_files_by_patterns proxy x1 x2 =
    OBus_method.call m_ListUnitFilesByPatterns proxy (x1, x2)

  let get_unit_file_state proxy x1 =
    OBus_method.call m_GetUnitFileState proxy x1

  let enable_unit_files proxy x1 x2 x3 =
    OBus_method.call m_EnableUnitFiles proxy (x1, x2, x3)

  let disable_unit_files proxy x1 x2 =
    OBus_method.call m_DisableUnitFiles proxy (x1, x2)

  let reenable_unit_files proxy x1 x2 x3 =
    OBus_method.call m_ReenableUnitFiles proxy (x1, x2, x3)

  let link_unit_files proxy x1 x2 x3 =
    OBus_method.call m_LinkUnitFiles proxy (x1, x2, x3)

  let preset_unit_files proxy x1 x2 x3 =
    OBus_method.call m_PresetUnitFiles proxy (x1, x2, x3)

  let preset_unit_files_with_mode proxy x1 x2 x3 x4 =
    OBus_method.call m_PresetUnitFilesWithMode proxy (x1, x2, x3, x4)

  let mask_unit_files proxy x1 x2 x3 =
    OBus_method.call m_MaskUnitFiles proxy (x1, x2, x3)

  let unmask_unit_files proxy x1 x2 =
    OBus_method.call m_UnmaskUnitFiles proxy (x1, x2)

  let revert_unit_files proxy x1 =
    OBus_method.call m_RevertUnitFiles proxy x1

  let set_default_target proxy x1 x2 =
    OBus_method.call m_SetDefaultTarget proxy (x1, x2)

  let get_default_target proxy =
    OBus_method.call m_GetDefaultTarget proxy ()

  let preset_all_unit_files proxy x1 x2 x3 =
    OBus_method.call m_PresetAllUnitFiles proxy (x1, x2, x3)

  let add_dependency_unit_files proxy x1 x2 x3 x4 x5 =
    OBus_method.call m_AddDependencyUnitFiles proxy (x1, x2, x3, x4, x5)

  let get_unit_file_links proxy x1 x2 =
    OBus_method.call m_GetUnitFileLinks proxy (x1, x2)

  let set_exit_code proxy x1 =
    OBus_method.call m_SetExitCode proxy x1

  let lookup_dynamic_user_by_name proxy x1 =
    let%lwt x1 = OBus_method.call m_LookupDynamicUserByName proxy x1 in
    let x1 = Int32.to_int x1 in
    return x1

  let lookup_dynamic_user_by_uid proxy x1 =
    let x1 = Int32.of_int x1 in
    OBus_method.call m_LookupDynamicUserByUID proxy x1

  let get_dynamic_users proxy =
    let%lwt x1 = OBus_method.call m_GetDynamicUsers proxy () in
    let x1 = List.map (fun (x1, x2) -> (Int32.to_int x1, x2)) x1 in
    return x1

  let unit_new proxy =
    OBus_signal.map_with_context
      (fun context (x1, x2) ->
         let x2 = OBus_proxy.make (OBus_context.sender context) x2 in
         (x1, x2))
      (OBus_signal.make s_UnitNew proxy)

  let unit_removed proxy =
    OBus_signal.map_with_context
      (fun context (x1, x2) ->
         let x2 = OBus_proxy.make (OBus_context.sender context) x2 in
         (x1, x2))
      (OBus_signal.make s_UnitRemoved proxy)

  let job_new proxy =
    OBus_signal.map_with_context
      (fun context (x1, x2, x3) ->
         let x1 = Int32.to_int x1 in
         let x2 = OBus_proxy.make (OBus_context.sender context) x2 in
         (x1, x2, x3))
      (OBus_signal.make s_JobNew proxy)

  let job_removed proxy =
    OBus_signal.map_with_context
      (fun context (x1, x2, x3, x4) ->
         let x1 = Int32.to_int x1 in
         let x2 = OBus_proxy.make (OBus_context.sender context) x2 in
         (x1, x2, x3, x4))
      (OBus_signal.make s_JobRemoved proxy)

  let startup_finished proxy =
    OBus_signal.make s_StartupFinished proxy

  let unit_files_changed proxy =
    OBus_signal.make s_UnitFilesChanged proxy

  let reloading proxy =
    OBus_signal.make s_Reloading proxy
end
