extends RefCounted
class_name GamePerformanceProbe

# Explicit wall timers for diagnostic runs only. Samples include native engine
# work, synchronization and scheduler delays; nested scopes are not additive.
# The benchmark must call start() after its barrier/warm-up and stop() before
# teardown. Merely passing the flag never includes initialization in a sample.
const SAMPLE_LIMIT:=600

class Series extends RefCounted:
	var durations:=PackedInt64Array()
	var elapsed:=PackedInt64Array()
	var cursor:=0
	var count:=0
	var total_usec:=0
	var maximum_usec:=0
	var maximum_at_usec:=0
	func _init() -> void:
		durations.resize(SAMPLE_LIMIT);elapsed.resize(SAMPLE_LIMIT)

static var _enabled_known:=false
static var _enabled:=false
static var _sampling:=false
static var _started_usec:=0
static var _stopped_usec:=0
static var _metadata: Dictionary={}
static var _series: Dictionary={}

static func is_enabled() -> bool:
	if not _enabled_known:
		_enabled_known=true
		_enabled="--performance-probe" in OS.get_cmdline_user_args()
	return _enabled

static func start(metadata: Dictionary={}) -> bool:
	_sampling=false;_series.clear();_metadata=metadata.duplicate(true)
	_started_usec=0;_stopped_usec=0
	if not is_enabled(): return false
	_started_usec=Time.get_ticks_usec();_sampling=true
	return true

static func stop() -> void:
	if _sampling: _stopped_usec=Time.get_ticks_usec()
	_sampling=false

static func begin(_scope: StringName) -> int:
	if not _sampling: return 0
	return Time.get_ticks_usec()

static func end(scope: StringName,started: int) -> void:
	if started<=0 or not _sampling: return
	var finished:=Time.get_ticks_usec()
	var duration:=maxi(0,finished-started)
	var samples: Series=_series.get(scope)
	if samples==null:
		samples=Series.new();_series[scope]=samples
	samples.durations[samples.cursor]=duration
	samples.elapsed[samples.cursor]=finished-_started_usec
	samples.cursor=(samples.cursor+1)%SAMPLE_LIMIT
	samples.count+=1;samples.total_usec+=duration
	if duration>samples.maximum_usec:
		samples.maximum_usec=duration;samples.maximum_at_usec=finished-_started_usec

static func report() -> Dictionary:
	var result: Dictionary={"enabled":is_enabled(),"sampling":_sampling,"sample_limit_per_scope":SAMPLE_LIMIT,"sample_policy":"latest 600 calls; count/mean/max cover all sampled calls","measurement":"inclusive wall time; includes native engine work, synchronization and scheduling; nested scopes are not additive","metadata":_metadata.duplicate(true),"scopes":{}}
	var until:=_stopped_usec if _stopped_usec>0 else Time.get_ticks_usec()
	result.duration_ms=(until-_started_usec)*.001 if _started_usec>0 else 0.
	for scope: StringName in _series:
		var samples: Series=_series[scope]
		var retained:=mini(samples.count,SAMPLE_LIMIT)
		var durations: Array[int]=[];var elapsed: Array[int]=[]
		for offset in retained:
			var index: int=(samples.cursor+offset)%SAMPLE_LIMIT if samples.count>=SAMPLE_LIMIT else offset
			durations.append(samples.durations[index]);elapsed.append(samples.elapsed[index])
		var ordered:=durations.duplicate();ordered.sort()
		var p50: int=ordered[mini(retained-1,maxi(0,ceili(retained*.50)-1))] if retained>0 else 0
		var p95: int=ordered[mini(retained-1,maxi(0,ceili(retained*.95)-1))] if retained>0 else 0
		result.scopes[str(scope)]={"calls":samples.count,"mean_ms":samples.total_usec*.001/maxi(1,samples.count),"max_ms":samples.maximum_usec*.001,"max_elapsed_ms":samples.maximum_at_usec*.001,"retained_calls":retained,"retained_p50_ms":p50*.001,"retained_p95_ms":p95*.001,"durations_usec":durations,"elapsed_usec":elapsed}
	return result
