extends Node

@warning_ignore_start("unused_signal")
signal reanalyze_requested()
signal stall_limits_fwd_changed(min_val: float, max_val: float)
signal stall_limits_bwd_changed(min_val: float, max_val: float)
signal config_updated(new_config)
